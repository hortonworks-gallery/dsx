#/bin/bash

# This script checks if the all requirements are met for installing DSX

function checkRAM(){
    local size="$1"
    local limit="$2"
	if [[ ${size} -lt ${limit} ]]; then
		echo "WARNING: RAM size is ${size}GB, while requirement is ${limit}GB"  | tee -a ${OUTPUT} 
		return 1
	fi
}

function checkCPU(){
    local size="$1"
    local limit="$2"
	if [[ ${size} -lt ${limit} ]]; then
		echo "WARNING: CPU cores are ${size}, while requirement are ${limit}"  | tee -a ${OUTPUT} 
		return 1
	fi
}

function usage(){
	echo "This script checks if this node meets requirements to install DSX-Local. "
	echo "Arguments: "
	echo "--type=[9nodes_master|9nodes_storage|9nodes_compute|3nodes]     To specify a node type"
	echo "--help                                                          To see help "
}

function helper(){
	echo "########################################################################################## 
   Help:
    ./$(basename $0) --type=[9nodes_master|9nodes_storage|9nodes_compute|3nodes]  
    Specify a node type and start the validation  
    Checking preReq before DSX-local installation 
    Please run this script in all the nodes of your cluster
    Differnt node types have different RAM/CPU requirement
    List of validation: 
    CPU
	WARNING for 9node master cpu core < 8, 9node storage cpu core < 16, 9node compute cpu core < 32; for 3node cpu core < 8 
	WARNING for 3node cpu core < 8
    RAM
	WARNING for 9node master RAM < 16GB, 9node storage RAM < 32GB, 9node compute RAM size < 64GB; for 3node RAM size < 16GB 
	WARNING for 3node RAM < 16GB
    Disk latency test:
     	WARNING dd if=/dev/zero of=/root/testfile bs=512 count=1000 oflag=dsync The value should be less than 10s for copying 512 kB
     	ERROR: must be less than 60s for copying 512 kB, 
    Disk throughput test:
    	WARNING dd if=/dev/zero of=/root/testfile bs=1G count=1 oflag=dsync The value should be less than 5s for copying 1.1 GB
    	ERROR: must be less than 35s for copying 1.1 GB
    Chrony/NTP 
    	WARNING check is ntp/chrony is setup
    Firewall disabled
    	ERROR firewalled and iptable is disabled
    Disk
    	ERROR root directory should have at least 10 GB
    	WARNING partition for installer files should have one xfs disk formartted and mounted > ${INSTALLPATH_SIZE}GB
    	WARNING partition for data storage should have one xfs disk formartted and mounted > ${DATAPATH_SIZE}GB
    Cron job check
    	ERROR check whether this node has a cronjob changes ip route, hosts file or firewall setting during installation
    DSX Local 443 port check
    	ERROR check port 443 is open 
    SELinux check 
    	ERROR check SElinux is either in enforcing or permissive mode 
    Gateway check
    	ERROR check is gateway is setup 
    DNS check 
    	ERROR check is DNS service is setup which allow hostname map to ip
    Docker check
    	ERROR Check to confirm Docker is not installed
    Kubernetes check 
    	ERROR Check to confirm Kubernetes is not installed
  ##########################################################################################" 
}

function checkpath(){
	local mypath="$1"
	if [[  "$mypath" = "/"  ]]; then
		echo "ERROR: Can not use root path / as path" | tee -a ${OUTPUT}
		usage
		exit 1
	fi
	if [ ! -d "$mypath" ]; then
	    echo "ERROR: $mypath not found in node." | tee -a ${OUTPUT}
	    usage
	    exit 1
	fi
}

#for internal usage
MASTERONE="MASTERONE_PLACEHOLDER" #if master one internal run will not check docker since we already install it 
INSTALLPATH="INSTALLPATH_PLACEHOLDER"
DATAPATH="DATAPATH_PLACEHOLDER"
CPU=0
RAM=0

#Global parameter 
INSTALLPATH_SIZE=150
DATAPATH_SIZE=350

#setup output file
OUTPUT="/tmp/preInstallCheckResult"
rm -f ${OUTPUT}

WARNING=0
ERROR=0
LOCALTEST=0
USE_SUDO=""
[[ "$(whoami)" != "root" ]] && USE_SUDO="sudo"

#input check
if [[  $# -ne 1  ]]; then 
	if [[ "$INSTALLPATH" != "" ]]; then 
		# This mean internal call the script, the script has already edited the INSTALLPATH DATAPATH CPU RAM by sed cmd
		checkpath $INSTALLPATH
		if [[ "$DATAPATH" != "" ]]; then
			checkpath "$DATAPATH"
		fi
	else 
		usage
		exit 1 
	fi
else
	# This mean the user runs script, will prompt user to input the INSTALLPATH DATAPATH
	if [[  "$1" = "--help"  ]]; then 
		helper
		exit 1
	elif [ "$1" == "--type=9nodes_master" ] || [ "$1" == "--type=9nodes_storage" ] || [ "$1" == "--type=9nodes_compute" ] || [ "$1" == "--type=3nodes" ]; then

		echo "Please enter the path of partition for installer files"
		read INSTALLPATH
		checkpath "$INSTALLPATH"

		if [[ "$1" = "--type=9nodes_storage" ]]; then
			echo "Please enter the path of partition for data storage"
			read DATAPATH
			checkpath "$DATAPATH"
			CPU=16
			RAM=32
		elif [[ "$1" = "--type=9nodes_master" ]]; then
			CPU=8
			RAM=16
		elif [[ "$1" = "--type=9nodes_compute" ]]; then
			CPU=32
			RAM=64
		elif [[ "$1" = "--type=3nodes" ]]; then
			echo "Please enter the path of partition for data storage"
			read DATAPATH
			checkpath "$DATAPATH"
			CPU=32
			RAM=64	
		else
			echo "please only specify type among 9nodes_master/9nodes_storage/9nodes_compute/3nodes"
			exit 1
		fi
	else 
		echo "Sorry the argument is invalid"
		usage
		exit 1
	fi 
fi

echo "##########################################################################################" > ${OUTPUT} 2>&1 
echo "Checking Disk latency and Disk throughput" | tee -a ${OUTPUT}
${USE_SUDO} dd if=/dev/zero of=${INSTALLPATH}/testfile bs=512 count=1000 oflag=dsync &> output
res=$(cat output | tail -n 1 | awk '{print $6}')
# writing this since bc may not be default support in customer environment 
res_int=$(echo $res | grep -E -o "[0-9]+" | head -n 1)
if [[ $res_int -gt 60 ]]; then
	echo "ERROR: Disk latency test failed. By copying 512 kB, the time must be shorter than 60s, recommended to be shorter than 10s, validation result is ${res_int}s " | tee -a ${OUTPUT} 
	ERROR=1 
	LOCALTEST=1
elif [[ $res_int -gt 10 ]]; then
	echo "WARNING: Disk latency test failed. By copying 512 kB, the time recommended to be shorter than 10s, validation result is ${res_int}s " | tee -a ${OUTPUT} 
	WARNING=1 
	LOCALTEST=1
fi 


${USE_SUDO} dd if=/dev/zero of=${INSTALLPATH}/testfile bs=1G count=1 oflag=dsync &> output
res=$(cat output | tail -n 1 | awk '{print $6}')
# writing this since bc may not be default support in customer environment 
res_int=$(echo $res | grep -E -o "[0-9]+" | head -n 1)
if [[ $res_int -gt 35 ]]; then
	echo "ERROR: Disk throughput test failed. By copying 1.1 GB, the time must be shorter than 35s, recommended to be shorter than 5s, validation result is ${res_int}s " | tee -a ${OUTPUT} 
	ERROR=1
	LOCALTEST=1
elif [[ $res_int -gt 5 ]]; then
	echo "WARNING: Disk throughput test failed. By copying 1.1 GB, the time is recommended to be shorter than 5s, validation result is ${res_int}s " | tee -a ${OUTPUT} 
	WARNING=1
	LOCALTEST=1
fi 
rm -f output > /dev/null 2>&1 
rm -f ${INSTALLPATH}/testfile > /dev/null 2>&1 
if [[ ${LOCALTEST} -eq 0 ]]; then 
	echo "PASS" | tee -a ${OUTPUT}  
fi 
echo 
echo "##########################################################################################" >> ${OUTPUT} 2>&1 

LOCALTEST=0

echo "##########################################################################################" >> ${OUTPUT} 2>&1 
echo "Checking gateway" | tee -a ${OUTPUT} 

${USE_SUDO} ip route | grep "default" > /dev/null 2>&1 
if [[ $? -ne 0 ]]; then
	echo "ERROR: default gateway is not setup " | tee -a ${OUTPUT} 
	ERROR=1 
	LOCALTEST=1
fi 
if [[ ${LOCALTEST} -eq 0 ]]; then 
	echo "PASS" | tee -a ${OUTPUT}  
fi
echo  
echo "##########################################################################################" >> ${OUTPUT} 2>&1 

LOCALTEST=0

echo "##########################################################################################" >> ${OUTPUT} 2>&1 
echo "Checking DNS" | tee -a ${OUTPUT}

${USE_SUDO} cat /etc/resolv.conf  | grep  -E "nameserver [0-9]+.[0-9]+.[0-9]+.[0-9]+" &> /dev/null
if [[ $? -ne 0 ]]; then
	echo "ERROR: DNS is not properly setup " | tee -a ${OUTPUT} 
	ERROR=1 
	LOCALTEST=1
fi 
if [[ ${LOCALTEST} -eq 0 ]]; then 
	echo "PASS" | tee -a ${OUTPUT}  
fi 
echo 
echo "##########################################################################################" >> ${OUTPUT} 2>&1 

LOCALTEST=0

echo "##########################################################################################" >> ${OUTPUT} 2>&1  
echo "Checking chrony / ntp" | tee -a ${OUTPUT}

TIMESYNCON=1  # 1 for not sync 0 for sync
${USE_SUDO} systemctl status ntpd > /dev/null 2>&1 
if [[ $? -eq 0 || $? -eq 3 ]]; then     # 0 is active, 3 is active, both are ok here
	TIMESYNCON=0
fi 
${USE_SUDO} systemctl status chronyd > /dev/null 2>&1 
if [[ $? -eq 0 || $? -eq 3 ]]; then		# 0 is active, 3 is active, both are ok here
	TIMESYNCON=0 
fi 
if [[ ${TIMESYNCON} -ne 0 ]]; then
	echo "WARNING: NTP/Chronyc is not setup " | tee -a ${OUTPUT} 
	WARNING=1 
	LOCALTEST=1
fi 
if [[ ${LOCALTEST} -eq 0 ]]; then 
	echo "PASS" | tee -a ${OUTPUT}  
fi 
echo 
echo "##########################################################################################" >> ${OUTPUT} 2>&1 

LOCALTEST=0

echo "##########################################################################################" >> ${OUTPUT} 2>&1 
echo "Checking if firewall is shutdown" | tee -a ${OUTPUT}
${USE_SUDO} service iptables status > /dev/null 2>&1 
if [ $? -eq 0 ]; then		 
	echo "WARNING: iptable is not disabled" | tee -a ${OUTPUT} 
	LOCALTEST=1
	WARNING=1
fi
${USE_SUDO} service ip6tables status > /dev/null 2>&1 
if [ $? -eq 0 ]; then		 
	echo "WARNING: ip6table is not disabled" | tee -a ${OUTPUT} 
	LOCALTEST=1
	WARNING=1
fi
${USE_SUDO} systemctl status firewalld > /dev/null 2>&1
if [ $? -eq 0 ]; then		 
	echo "WARNING: firewalld is not disabled" | tee -a ${OUTPUT} 
	LOCALTEST=1
	WARNING=1
fi
if [[ ${LOCALTEST} -eq 0 ]]; then 
	echo "PASS" | tee -a ${OUTPUT}  
fi 
echo 
echo "##########################################################################################" >> ${OUTPUT} 2>&1 

LOCALTEST=0

echo "##########################################################################################" >> ${OUTPUT} 2>&1 
echo "Checking SELinux" | tee -a ${OUTPUT}

selinux_res="$(${USE_SUDO} getenforce 2>&1)"
if [[ ! "${selinux_res}" =~ ("Permissive"|"permissive"|"Enforcing"|"enforcing") ]]; then
	echo "ERROR: SElinux is not in enforcing or permissive mode"  | tee -a ${OUTPUT} 
	LOCALTEST=1
	ERROR=1
fi
if [[ ${LOCALTEST} -eq 0 ]]; then 
	echo "PASS" | tee -a ${OUTPUT}  
fi
echo 
echo "##########################################################################################" >> ${OUTPUT} 2>&1 

LOCALTEST=0

echo "##########################################################################################" >> ${OUTPUT} 2>&1  
echo "Checking pre-exsiting cronjob" | tee -a ${OUTPUT}
${USE_SUDO} crontab -l | grep -E "*" &> /dev/null
if [[ $? -eq 0 ]] ; then
	echo "WARNING: Found cronjob set up in background. Please make sure cronjob will not change ip route, hosts file or firewall setting during installation"  | tee -a ${OUTPUT} 
	LOCALTEST=1
	WARNING=1
fi
if [[ ${LOCALTEST} -eq 0 ]]; then 
	echo "PASS" | tee -a ${OUTPUT}  
fi
echo  
echo "##########################################################################################" >> ${OUTPUT} 2>&1 

LOCALTEST=0

echo "##########################################################################################" >> ${OUTPUT} 2>&1  
echo "Checking size of root partition" | tee -a ${OUTPUT}

ROOTSIZE=$(${USE_SUDO} df -k -BG "/" | awk '{print($4 " " $6)}' | grep "/" | cut -d' ' -f1 | sed 's/G//g')
if [[ $ROOTSIZE -lt 10 ]] ; then
	echo "ERROR: size of root partition is smaller than 10G"  | tee -a ${OUTPUT} 
	LOCALTEST=1
	ERROR=1
fi
if [[ ${LOCALTEST} -eq 0 ]]; then 
	echo "PASS" | tee -a ${OUTPUT}  
fi
echo 
echo "##########################################################################################" >> ${OUTPUT} 2>&1 

LOCALTEST=0

echo "##########################################################################################" >> ${OUTPUT} 2>&1  
echo "Checking if install path: ${INSTALLPATH} have enough space (${INSTALLPATH_SIZE}GB)" | tee -a ${OUTPUT}
PARTITION=$(${USE_SUDO} df -k -BG | grep  ${INSTALLPATH})
if [[ $? -ne 0 ]]; then 
	echo "ERROR: can not find the ${INSTALLPATH} partition you specified in install_path"  | tee -a ${OUTPUT} 
	LOCALTEST=1
	ERROR=1
else 
	PARTITION=$(echo $PARTITION | tail -n 1 |  awk '{print $2}' | sed 's/G//g')
	if [[ ${PARTITION} -lt ${INSTALLPATH_SIZE} ]]; then 
		echo "WARNING: size of install_path ${INSTALLPATH} is smaller than requirement (${INSTALLPATH_SIZE}GB)"  | tee -a ${OUTPUT} 
		LOCALTEST=1
		ERROR=1
	fi
fi
if [[ ${LOCALTEST} -eq 0 ]]; then 
	echo "PASS" | tee -a ${OUTPUT}  
fi 
echo 
echo "##########################################################################################" >> ${OUTPUT} 2>&1 

if [[ $DATAPATH != "" && $DATAPATH != "DATAPATH_PLACEHOLDER" ]]; then
	LOCALTEST=0
	echo "##########################################################################################" >> ${OUTPUT} 2>&1  
	echo "This is a storage node, checking if data path: ${DATAPATH} have enough space (${DATAPATH_SIZE}GB)" | tee -a ${OUTPUT}
	cmd='df -k -BG | grep  ${DATAPATH}'
	PARTITION=$(${USE_SUDO} df -k -BG | grep  ${DATAPATH})
	if [[ $? -ne 0 ]]; then 
		echo "ERROR: can not find the ${DATAPATH} partition you specified in data_path"  | tee -a ${OUTPUT} 
		LOCALTEST=1
		ERROR=1
	else 
		PARTITION=$(echo $PARTITION | tail -n 1 |  awk '{print $2}' | sed 's/G//g')
		if [[ ${PARTITION} -lt ${DATAPATH_SIZE} ]]; then 
			echo "WARNING: size of data_path ${DATAPATH} is smaller than requirement (${DATAPATH_SIZE}GB)"  | tee -a ${OUTPUT} 
			LOCALTEST=1
			ERROR=1
		fi
	fi
	if [[ ${LOCALTEST} -eq 0 ]]; then 
		echo "PASS" | tee -a ${OUTPUT}  
	fi 
	echo
	echo "##########################################################################################" >> ${OUTPUT} 2>&1 
fi

LOCALTEST=0

echo "##########################################################################################" >> ${OUTPUT} 2>&1  
echo "Checking if xfs is enabled" | tee -a ${OUTPUT}
${USE_SUDO} xfs_info ${INSTALLPATH} | grep "ftype=1" > /dev/null 2>&1 

if [[ $? -ne 0 ]] ; then
	echo "ERROR: xfs is not enabled, ftype=0, should be 1"  | tee -a ${OUTPUT} 
	LOCALTEST=1
	ERROR=1
fi
if [[ ${LOCALTEST} -eq 0 ]]; then 
	echo "PASS" | tee -a ${OUTPUT}  
fi 
echo 
echo "##########################################################################################" >> ${OUTPUT} 2>&1 

LOCALTEST=0

echo "##########################################################################################" >> ${OUTPUT} 2>&1 
echo "Checking CPU core numbers and RAM size" | tee -a ${OUTPUT}
# Get CPU numbers and min frequency

cpunum=$(${USE_SUDO} cat /proc/cpuinfo | grep '^processor' |wc -l | xargs)
if [[ ! ${cpunum} =~ ^[0-9]+$ ]]; then
    echo  "ERROR: Invalid cpu numbers '${cpunum}'" | tee -a ${OUTPUT} 
else 
    checkCPU ${cpunum} ${CPU}
    if [[ $? -eq 1 ]]; then
	LOCALTEST=1
	WARNING=1
    fi
fi
mem=$(${USE_SUDO} cat /proc/meminfo | grep MemTotal | awk '{print $2}')
# Get Memory info
mem=$(( $mem/1000000 ))
if [[ ! ${mem} =~ ^[0-9]+$ ]]; then
    echo "ERROR: Invalid memory size '${mem}'" | tee -a ${OUTPUT} 
else
    checkRAM ${mem} ${RAM}
    if [[ $? -eq 1 ]]; then
	LOCALTEST=1
	WARNING=1
    fi
fi
if [[ ${LOCALTEST} -eq 0 ]]; then 
	echo "PASS" | tee -a ${OUTPUT}  
fi 
echo 
echo "##########################################################################################" >> ${OUTPUT} 2>&1 


if [[ ${MASTERONE} = "NO" || $# -eq 1 ]]; then
	LOCALTEST=0
	echo "##########################################################################################" >> ${OUTPUT} 2>&1  
	echo "Checking to confirm docker is not installed " | tee -a ${OUTPUT}

    ${USE_SUDO} which docker > /dev/null 2>&1
    rc1=$?
	${USE_SUDO} systemctl status docker &> /dev/null
    rc2=$?
	if [[ ${rc1} -eq 0 ]] || [[ ${rc2} -eq 0 ]]; then
		echo "ERROR: Docker is already installed with a different version or settings, please uninstall Docker"  | tee -a ${OUTPUT} 
		LOCALTEST=1
		ERROR=1
	fi
	if [[ ${LOCALTEST} -eq 0 ]]; then 
		echo "PASS" | tee -a ${OUTPUT}  
	fi
	echo 
	echo "##########################################################################################" >> ${OUTPUT} 2>&1 
fi

LOCALTEST=0
echo "##########################################################################################" >> ${OUTPUT} 2>&1  
echo "Checking to confirm Kubernetes is not installed" | tee -a ${OUTPUT}

${USE_SUDO} systemctl status kubelet &> /dev/null
if [[ $? -eq 0 ]]; then
	echo "ERROR: Kubernetes is already installed with a different version or settings, please uninstall Kubernetes"  | tee -a ${OUTPUT} 
	LOCALTEST=1
	ERROR=1
else
	${USE_SUDO} which kubectl &> /dev/null
	if [[ $? -eq 0 ]]; then
		echo "ERROR: Kubernetes is already installed with a different version or settings, please uninstall Kubernetes"  | tee -a ${OUTPUT} 
		LOCALTEST=1
		ERROR=1
	fi	
fi 
if [[ ${LOCALTEST} -eq 0 ]]; then 
	echo "PASS" | tee -a ${OUTPUT}  
fi
echo 
echo "##########################################################################################" >> ${OUTPUT} 2>&1 

#log result
if [[ ${ERROR} -eq 1 ]]; then
	echo "Finished with ERROR, please check ${OUTPUT}"
    exit 2
elif [[ ${WARNING} -eq 1 ]]; then
	echo "Finished with WARNING, please check ${OUTPUT}"
    exit 1
else
	echo "Finished successfully! This node meets the requirement" | tee -a ${OUTPUT}
    exit 0
fi
