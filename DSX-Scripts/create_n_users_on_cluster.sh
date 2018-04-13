#!/usr/bin/env bash


## Fill in the following values

# 1. DNS name/ip address of the external load balancer /v-ip
DNSName="xyz.amazonaws.com"

# 2. session id - Check your cookies and find your "ibm-private-cloud-session" ID and paste it here
sessionId="abc"

# 3. Set number of users you want to generate
numUsers=20


## Leave the following as is

displayNamePrefix="user"
usernamePrefix="user"
email="email@email.com"
role="User"

APIEndpoint="https://$DNSName/api/v1/usermgmt/v1/user/"

for i in $(seq 1 $numUsers); do
  num=$(printf "%03d" $i)

  printf "\nCreating user $num\n"
  curl "$APIEndpoint" -H "content-type: application/json;charset=UTF-8" -H "cookie: ibm-private-cloud-session=$sessionId" --data-binary "{\"username\":\"$usernamePrefix$num\",\"displayName\":\"$displayNamePrefix$num\",\"email\":\"$email\",\"role\":\"$role\"}" --compressed --insecure
done

for i in $(seq 1 $numUsers); do
  num=$(printf "%03d" $i)

  printf "\nSetting password for user $num\n"
  curl "$APIEndpoint$usernamePrefix$num" -X PUT -H "content-type: application/json;charset=UTF-8" -H "cookie: ibm-private-cloud-session=$sessionId" --data-binary "{\"username\":\"$usernamePrefix$num\",\"displayName\":\"$displayNamePrefix$num\",\"email\":\"$email\",\"role\":\"$role\",\"approval_status\":\"approved\",\"password\":\"$usernamePrefix$num\"}" --compressed --insecure
done
