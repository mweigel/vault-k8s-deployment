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