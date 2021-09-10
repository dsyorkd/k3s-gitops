#!/bin/bash

REPO_ROOT=$(git rev-parse --show-toplevel)

need() {
    which "$1" &>/dev/null || die "Binary '$1' is missing but required"
}

need "kubectl"

message() {
  echo -e "\n######################################################################"
  echo "# $1"
  echo "######################################################################"
}

kapply() {
  if output=$(envsubst < "$@"); then
    printf '%s' "$output" | kubectl apply -f -
  fi
}

installManualObjects(){
  . "$REPO_ROOT"/setup/.env

  message "installing manual secrets and objects"

  ##########
  # secrets
  ##########
  kubectl -n kube-system create secret generic kms-vault --from-literal=account.json="$(echo $VAULT_KMS_ACCOUNT_JSON | base64 --decode)"
  kubectl -n kube-system create secret docker-registry registry-creds-secret --namespace kube-system --docker-username=$DOCKER_USERNAME --docker-password=$DOCKER_TOKEN --docker-email=$EMAIL

  ###################
  # ambassador
  ###################
  # for i in "$REPO_ROOT"/kube-system/ambassador/ambassador-external/*.txt
  # do
  #   kapply "$i"
  # done
  kustomize build ../cert-manager/crds > /tmp/build.yaml
  kustomize build ../monitoring/kube-prometheus-stack/crds >> /tmp/build.yaml
  kustomize build ../kube-system/ambassador/crds >> /tmp/build.yaml
  kustomize build ../system-upgrade/crds >> /tmp/build.yaml
  cat ../kube-system/vault-secrets-operator/crd.yaml >> /tmp/build.yaml
  cat ../kube-system/registry-creds/crds/crd.yaml >> /tmp/build.yaml 
  kubectl apply -f /tmp/build.yaml && rm -f /tmp/build.yaml

}

export KUBECONFIG="$REPO_ROOT/setup/kubeconfig"
installManualObjects

message "all done!"
