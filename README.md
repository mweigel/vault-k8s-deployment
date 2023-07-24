# Deploy Vault in EKS

## Overview
 - HA Vault cluster
 - TLS enabled
 - Auto-unseal using AWS KMS and [IAM roles for Kubernetes service accounts](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)

## Cluster setup
### Create an EKS Cluster
```
./create-cluster.sh
```

### Enable EBS CSI plugin
```
./enable-ebs-cis-plugin.sh
```
References:

1. [Amazon EBS CSI driver
](https://docs.aws.amazon.com/eks/latest/userguide/ebs-csi.html)

### Deploy the AWS Load Balancer Controller add-on
```
./deploy-lb-controller.sh
```
References:

1. [Network load balancing on Amazon EKS
](https://docs.aws.amazon.com/eks/latest/userguide/network-load-balancing.html)


### Create a KMS key and IAM role to allow for auto-unsealing of Vault

References:

1. [IAM roles for service accounts](https://docs.aws.amazon.com/eks/latest/userguide/iam-roles-for-service-accounts.html)
1. [Understanding how EKS and IAM work together](https://www.padok.fr/en/blog/aws-eks-iam)

## Install and initialise Vault

Deploy the TLS certificates used by Vault.
```
kubectl create secret generic vault-ha-tls \
    --from-file=ca.crt=certs/ca.crt \
    --from-file=vault.crt=certs/vault.crt \
    --from-file=vault.key=certs/vault.key
```

Install Vault using Helm.
```
helm install vault ./vault-helm --values override-values-auto.yml
```

Initialise vault-0.
```
kubectl exec vault-0 -- vault operator init
```

Join vault-1 to the cluster.
```
kubectl exec -it vault-1 -- /bin/sh
vault operator raft join -address=https://vault-1.vault-internal:8200 \
    -leader-ca-cert="$(cat /vault/userconfig/vault-ha-tls/ca.crt)" \
    -leader-client-cert="$(cat /vault/userconfig/vault-ha-tls/vault.crt)" \
    -leader-client-key="$(cat /vault/userconfig/vault-ha-tls/vault.key)" \
    https://vault-0.vault-internal:8200
```

Join vault-2 to the cluster
```
kubectl exec -it vault-2 -- /bin/sh
vault operator raft join -address=https://vault-2.vault-internal:8200 \
    -leader-ca-cert="$(cat /vault/userconfig/vault-ha-tls/ca.crt)" \
    -leader-client-cert="$(cat /vault/userconfig/vault-ha-tls/vault.crt)" \
    -leader-client-key="$(cat /vault/userconfig/vault-ha-tls/vault.key)" \
    https://vault-0.vault-internal:8200
```

Check Vault status. All instances should report "Initialized true" and "Sealed false". One instance should report "HA Mode active" and the remaining two should report "HA Mode standby".
```
kubectl exec vault-0 -- vault status
kubectl exec vault-1 -- vault status
kubectl exec vault-2 -- vault status
```

### Test auto-unseal and HA functionality

Find the active node and delete it. Check that it's restarted and unsealed automatically and that one of the nodes is active and two are standby. Assuming vault-0 is the active node.
```
kubectl delete po vault-0
kubectl get po
kubectl exec vault-0 -- vault status
kubectl exec vault-1 -- vault status
kubectl exec vault-2 -- vault status
```

### Deploy an NLB

## Improvements

 - Avoid using Kubernetes secrets

## References

 - [Vault Installation to Minikube via Helm with Integrated Storage](https://developer.hashicorp.com/vault/tutorials/kubernetes/kubernetes-minikube-raft)
 - [Vault Installation to Minikube via Helm with TLS enabled](https://developer.hashicorp.com/vault/tutorials/kubernetes/kubernetes-minikube-tls)
