create_cert_secret() {
    kubectl create secret generic vault-ha-tls \
        --from-file=ca.crt=certs/ca.crt \
        --from-file=vault.crt=certs/vault.crt \
        --from-file=vault.key=certs/vault.key
}

install_vault(){
    helm install vault ./vault-helm --values override-values.yml
}

uninstall_vault(){
    helm uninstall vault
}

delete_pvcs(){
    for pvc in $(kubectl get pvc | grep data-vault | awk '{ print $1 }'); do
        kubectl delete pvc $pvc
    done
}

vault_init(){
    kubectl exec -it $1 -- vault operator init \
        -key-shares=1 \
        -key-threshold=1 \
        -format=json > cluster-keys.json
    
    export VAULT_UNSEAL_KEY=$(jq -r ".unseal_keys_b64[]" cluster-keys.json)
}

vault_unseal(){
    kubectl exec -it $1 -- vault operator unseal $VAULT_UNSEAL_KEY
}

vault_raft_join(){
    kubectl exec -it $1 -- vault operator raft join \
        -address="https://${1}.vault-internal:8200" \
        -leader-ca-cert="$(cat /vault/userconfig/vault-ha-tls/ca.crt)" \
        -leader-client-cert="$(cat /vault/userconfig/vault-ha-tls/vault.crt)" \
        -leader-client-key="$(cat /vault/userconfig/vault-ha-tls/vault.key)" \
        https://vault-0.vault-internal:8200
}