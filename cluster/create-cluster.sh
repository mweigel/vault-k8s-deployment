#!/bin/bash

eksctl create cluster \
  --name cluster-03 \
  --region ap-southeast-2 \
  --with-oidc \
  --node-type 't3.large' \
  --nodes 3 \
  --ssh-access \
  --ssh-public-key 'id_rsa.pub' \
  --external-dns-access \
  --vpc-public-subnets 'subnet-1,subnet-2,subnet-3'
