#!/usr/bin/env bash

# Run from your local terminal
## Fill in the following values

# 1. DNS name/ip address of the external load balancer /v-ip
DNSName="xyz.amazonaws.com"

# 2. session id - Check your cookies and find your "ibm-private-cloud-session" ID and paste it here
sessionId="abc"

# 3. Project Name you want to remove(Note: Project Name in a DSX Cluster is Unique)
projectname="dummy"


## Leave the following as is 

# Project API
ProjectAPI="https://$DNSName/v3/project/"


printf "\nDeleting project $num\n"
curl "$ProjectAPI$projectname" -X DELETE -H "content-type: application/json;charset=UTF-8" -H "cookie: ibm-private-cloud-session=$sessionId" --compressed --insecure