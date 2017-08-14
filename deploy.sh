#!/bin/bash

set -e

bash_escape() ( printf '\\033[%dm' $1; );
RESET=$(bash_escape 0); BLUE=$(bash_escape 34);
put_info() ( printf "${BLUE}[INFO]${RESET} $1\n");

put_info "Authenticating to Google Cloud Services";
echo $GCLOUD_SERVICE_KEY | base64 --decode -i > ${HOME}/gcloud-service-key.json;
gcloud auth activate-service-account --key-file ${HOME}/gcloud-service-key.json;

put_info "Configuring Google Cloud Services";
gcloud --quiet config set project $PROJECT_ID;
gcloud --quiet config set container/cluster $CLUSTER_NAME;
gcloud --quiet config set compute/zone ${CLOUDSDK_COMPUTE_ZONE};
gcloud --quiet container clusters get-credentials $CLUSTER_NAME;

put_info "Kubernetes Cluster Info";
kubectl cluster-info;