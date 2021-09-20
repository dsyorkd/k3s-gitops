#!/bin/bash

REPO_ROOT=$(git rev-parse --show-toplevel)

need() {
    which "$1" &>/dev/null || die "Binary '$1' is missing but required"
}

need "kubectl"
need "helm"
need "flux"

message() {
  echo -e "\n######################################################################"
  echo "# $1"
  echo "######################################################################"
}

setNodeLabels() {
  message "label nodes missing agent label"
  for p in $(kubectl get node --selector='!node-role.kubernetes.io/master' -o  jsonpath='{.items[*].metadata.name}') 
  do
    kubectl label nodes $p node-role.kubernetes.io/agent=true 
  done

}

installFlux() {
  message "installing fluxv2"
  flux check --pre > /dev/null
  FLUX_PRE=$?
  if [ $FLUX_PRE != 0 ]; then
    echo -e "flux prereqs not met:\n"
    flux check --pre
    exit 1
  fi
  if [ -z "$GITHUB_TOKEN" ]; then
    echo "GITHUB_TOKEN is not set! Check $REPO_ROOT/scripts/.env"
    exit 1
  fi
  flux bootstrap github \
    --owner=dsyorkd \
    --repository=k3s-gitops \
    --branch master \
    --verbose \
    --personal \
    --network-policy=false

  FLUX_INSTALLED=$?
  if [ $FLUX_INSTALLED != 0 ]; then
    echo -e "flux did not install correctly, aborting!"
    exit 1
  fi
}

installFlux
"$REPO_ROOT"/scripts/bootstrap-objects.sh
"$REPO_ROOT"/scripts/bootstrap-vault.sh

message "all done!"
kubectl get nodes -o=wide
