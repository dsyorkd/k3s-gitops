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
  . "$REPO_ROOT"/scripts/.env
  CREDS=$(cat "$REPO_ROOT"/$VAULT_KMS_ACCOUNT_JSON)
  message "installing manual secrets and objects"

  ##########
  # secrets
  ##########
  kubectl -n kube-system create secret generic kms-vault --from-literal=account.json="$(echo $CREDS)"
  kubectl -n flux-system create secret generic discord-webook --from-literal=address="$(echo $DISCORD_FLUX_WEBHOOK_URL)"
  
  kubectl -n kube-system create secret docker-registry registry-creds-secret --namespace kube-system --docker-username=$DOCKER_USERNAME --docker-password=$DOCKER_TOKEN --docker-email=$EMAIL
  kubectl -n logs create secret generic loki-helm-values --from-literal=values.yaml="$(cat '../logs/loki/loki-helm-values.txt')"  ###################
  kustomize build -e .env 
  # ambassador
  ###################
  # for i in "$REPO_ROOT"/kube-system/ambassador/ambassador-external/*.txt
  # do
  #   kapply "$i"
  # done
  kustomize build ../cert-manager/crds > /tmp/build.yaml
  kustomize build ../monitoring/kube-prometheus-stack/crds >> /tmp/build.yaml
  kustomize build ../kube-system/ambassador/crds >> /tmp/build.yaml
  #kustomize build ../system-upgrade/crds >> /tmp/build.yaml
  cat ../kube-system/vault-secrets-operator/crd.yaml >> /tmp/build.yaml
  cat ../kube-system/registry-creds/crds/crd.yaml >> /tmp/build.yaml 
  kubectl apply -f /tmp/build.yaml && rm -f /tmp/build.yaml

}

export KUBECONFIG="$REPO_ROOT/scripts/kubeconfig"
installManualObjects

message "all done!"
