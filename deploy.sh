#!/bin/bash

set -e

bash_escape() ( printf '\\033[%dm' $1; );
RESET=$(bash_escape 0); BLUE=$(bash_escape 34);
put_info() ( printf "${BLUE}[INFO]${RESET} $1\n");

# put_info "Getting jq"
# apt-get update; apt-get jq;

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

# clone folioorg/okapi
put_info "Cloning Okapi";
git clone https://github.com/folio-org/okapi.git;

put_info "Overriding Dockerfile";
cp ./scripts/okapi-initdb-and-start.sh ./okapi/okapi-initdb-and-start.sh;
cp ./scripts/okapi-register-and-discover-module.sh ./okapi/okapi-register-and-discover-module.sh;
cp ./Dockerfile ./okapi/Dockerfile;

put_info "Building Okapi";
cd ./okapi;
docker build .;

image=$(docker images --format="{{.ID}}" | head -n 1);

put_info "Tagging image '$image' as '$TRAVIS_COMMIT'";
docker tag "$image" ${DOCKER_IMAGE_NAME}:${TRAVIS_COMMIT};

put_info "Tagging image '$image' as 'latest'";
docker tag "$image" ${DOCKER_IMAGE_NAME}:latest;

put_info "Pushing Okapi to GCR";
gcloud docker -- push ${DOCKER_IMAGE_NAME};
