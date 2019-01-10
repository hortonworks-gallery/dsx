# This script partly automates deployment of a 3-nodes DSX Local Cluster. 
# Following steps are involved in an end to end deployment.
#
# Step 1: Create a 3 node cluster on field cloud. 
# Note: You can reimage the nodes if you already have a 3 node cluster.
#
# Step 2: Set up password less ssh between all the nodes by -
#
# 1. invoking root login on each node : 
# sed -i '/^#PermitRootLogin.*/s/^#//' /etc/ssh/sshd_config
# cat /etc/ssh/sshd_config  | grep PermitRootLogin
#
# 2. Creating a ssh key
# ssh-keygen
#
# 3. Modify the authorized_key for all the nodes - copy authorized key from master node to all the other nodes.
#
#
# Step 4. List down all your nodes:
# Example: Large Cluster
# Node 1 - 172.26.227.199
# Node 2 - 172.26.227.200
# Node 3 - 172.26.227.198
# Virtual-IP - 172.26.228.121
# 
# Example: Medium Cluster
# Node 1 - 172.26.222.219
# Node 2 - 172.26.222.220
# Node 3 - 172.26.222.221
# Virtual-IP - 172.26.222.224
#
# ------------------------------------------------------------
# Step 5: Run the script below on each node of your cluster.
# ------------------------------------------------------------
# debug mode
set -x 

# confirm if this is a installer node
read -p "Is this node a Installer Node? y/n " response

if [ "$response" == "y" ]; then
    # set this node as installer node
    export is_installer_node=true
    # get the ip address for node 1
    read -p "Enter IP for Node 1 (Installer Node) - " node_1
    # get the ip address for node 2
    read -p "Enter IP for Node 2 - "  node_2
    # get the ip address for node 3
    read -p "Enter IP for Node 3 - "  node_3
    # get the virtual ip address for cluster
    read -p "Enter Virtual IP for Cluster - " v_ip

    # set location of installer.
    # Note: confirm the latest release and if needed this can be updated
    #export installer_location="https://iwm.dhe.ibm.com/sdfdl/1v2/regs2/kshivele/Xa.2/Xb.Vx9GKkx1a8TxajbK8-iKFKK7tt4Poa9YSDfK9giAjFE/Xc.dsxlocal_linux-x86_64/Xd./Xf.LPr.A6vr/Xg.9331193/Xi.mrs-idsel/XY.regsrvs/XZ.zro7C3Fr3-P2OB4eNHbE6Dpiy2U/dsxlocal_linux-x86_64"
    export installer_location="http://158.85.173.111/repos/dsx/DSX%20Local%20GAs/DSX-Local-1.1.2.2-final.tar"
    # install wget and screen
    yum install -y wget screen tar

else
   export is_installer_node=false
fi


# run the pre requisites needed on every node in the cluster

df -lh 

#unmount the partition
umount /mnt

#create new directories
#this should be 350G
mkdir /data 
# this should be ~300G
mkdir /install 


# create input file for fdisk
sudo tee fdisk_input.txt > /dev/null << EOF
n
p
1
2048
+350G
n
p
2
734005248
+290G
w
EOF

# run fdisk to partition /dev/vdb 
fdisk /dev/vdb < fdisk_input.txt

partprobe

# format both the partitions 
mkfs.xfs -f -n ftype=1 -i size=512 -n size=8192 /dev/vdb1 #data

mkfs.xfs -f -n ftype=1 -i size=512 -n size=8192 /dev/vdb2 #install

# mount
mount /dev/vdb1 /data 

mount /dev/vdb2 /install

# check that partitions have been created
df -lh 

echo "Check if partitions look good with /data=350G  & /install=~300G, else abort. Sleeping for 20 sec"

sleep 20

# run script to perform pre-installation checks
curl https://hipchat.hortonworks.com/files/1/2686/77bRMjN5gDJgWko/pre_install_check.sh  > pre_install_check.sh

chmod +x pre_install_check.sh 

# set parameters for preinstall check
sudo tee pre_install_check_input.txt > /dev/null << EOF
/install
/data
EOF

./pre_install_check.sh --type=3nodes < pre_install_check_input.txt

echo "Check the logs above for any error or warning. Abort in case of ERROR. Sleeping for 20 seconds"

sleep 20

echo "All prerequisites have been completed for this node"


# This section will be only executed for installer node
# Note: You can assume first node to be master node.
if [ "${is_installer_node}" = true  ]; then

   echo "Installer node specific installtion to proceed"    
   
   cd /install   

# set inputs for wdf.conf file
sudo tee wdp.conf > /dev/null << EOF
virtual_ip_address=${v_ip}
ssh_key=/root/.ssh/id_rsa
overlay_network=192.168.0.0/16
ssh_port=22
node_1=${node_1}
node_path_1=/install
node_data_1=/data
node_2=${node_2}
node_path_2=/install
node_data_2=/data
node_3=${node_3}
node_path_3=/install
node_data_3=/data
suppress_warning=true
EOF

    # download the installer
    wget ${installer_location}

    tar -xvf DSX-Local-*

    ls -al 

    echo "Check if the installer has been downloaded (size >20GB). Sleeping for 10 seconds"	

    sleep 20
    
    chmod +x DSX-Local-* 
    
    echo "Installer ready for installation, start screen before you kick off the installation by running /install/dsxlocal* --three-nodes"

fi

# Step 6: Kick off the installation by running /install/dsxlocal* --three-nodes. Make sure of following two things:
# 1. You have performed the required steps above for all the 3-nodes 
# 2. Turn on the screen command as this will help you trace the install.














