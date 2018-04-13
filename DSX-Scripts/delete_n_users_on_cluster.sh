#!/usr/bin/env bash


## Fill in the following values

# 1. DNS name/ip address of the external load balancer /v-ip
DNSName="xyz.amazonaws.com"

# 2. session id - Check your cookies and find your "ibm-private-cloud-session" ID and paste it here
sessionId="abc"

# 3. Set number of users you want to generate
numUsers=20

# 4. Set username prefix
usernamePrefix="user"


## Leave the following as is

APIEndpoint="https://$DNSName/api/v1/usermgmt/v1/user/"

for i in $(seq 1 $numUsers); do
  num=$(printf "%03d" $i)

  printf "\nDeleting user $num\n"
  curl "$APIEndpoint$usernamePrefix$num" -X DELETE -H "content-type: application/json;charset=UTF-8" -H "cookie: ibm-private-cloud-session=$sessionId" --compressed --insecure
done