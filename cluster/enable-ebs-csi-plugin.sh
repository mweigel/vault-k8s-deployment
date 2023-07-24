#!/bin/bash

eksctl create iamserviceaccount \
    --name ebs-csi-controller-sa \
    --namespace kube-system \
    --cluster cluster-03 \
    --role-name AmazonEKS_EBS_CSI_DriverRole \
    --role-only \
    --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
    --approve

eksctl create addon \
    --name aws-ebs-csi-driver \
    --cluster cluster-03 \
    --service-account-role-arn arn:aws:iam::${account}:role/AmazonEKS_EBS_CSI_DriverRole \
    --force
