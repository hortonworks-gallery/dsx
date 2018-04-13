#!/bin/bash

# Note: Run this script on the node of the cluster
kubectl get namespaces | grep dsxuser > 'activeuser.txt'

filename='activeuser.txt'
while read -r line
do
  id=$(cut -c-15 <<< $line)
  echo $id
  kubectl get deploy --all-namespaces| grep $id | awk '{system("kubectl delete deploy -n "$1" "$2)}'
  
done < $filename