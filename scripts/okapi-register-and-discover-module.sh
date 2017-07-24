#!/bin/bash

# Registers a module with okapi using a module descriptor and discovers
# it's endpoints via pod & service environment variables. If a deployment
# descriptor is provided as the second argument, it will be used as the
# payload for the discovery endpoint instead of the service.
#
# Usage:
#
# ```bash
# # will register and discover endpoints for a module named "folio-mod-users"
# POD_NAME=folio-mod-users \
# FOLIO_MOD_USERS_SERVICE_HOST=localhost \
# FOLIO_MOD_USERS_SERVICE_PORT=8081 \
# OKAPI_URL=localhost:9130 \
# ./okapi-register-and-discover-module.sh \
# "$(< mod-users/ModuleDescriptor.json)"
#
# # for local developement
# OKAPI_URL=localhost:9130 \
# ./okapi-register-and-discover-module.sh \
# "$(< ModuleDescriptor.json)" \
# "$(< DeploymentDescriptor.json)" \
# ```

# Kubernetes environment variables
OKAPI_SERVICE_HOST="${OKAPI_CLUSTER_SERVICE_HOST:-localhost}"
OKAPI_SERVICE_PORT="${OKAPI_CLUSTER_SERVICE_PORT:-9130}"

# Default environment variables
OKAPI_URL="${OKAPI_URL:=http://${OKAPI_SERVICE_HOST}:${OKAPI_SERVICE_PORT}}"

# Descriptor contents
MODULE_DESCRIPTOR=$1
DEPLOYMENT_DESCRIPTOR=$2

# Ensure we have a module descriptor
if [ ! "$MODULE_DESCRIPTOR" ]; then
    echo 'No module descriptor provided.'
    exit 2
fi

# Ensure the jq library is available
if ! hash jq 2>/dev/null; then
    echo 'This script requires the jq library.'
    echo 'https://stedolan.github.io/jq/'
    exit 2
fi

# If a pod name is provided, use it as the module id
if [ "$POD_NAME" ]; then
    MODULE_DESCRIPTOR=$(echo $MODULE_DESCRIPTOR | jq ".id = \"$POD_NAME\"")
    MODULE_ID=$POD_NAME
else
    MODULE_ID=$(echo $MODULE_DESCRIPTOR | jq -r '.id')
fi

# Default deployment descriptor uses environment variables
if [ ! "$DEPLOYMENT_DESCRIPTOR" ]; then
    MODULE_SERVICE_PRE=$(echo "${POD_NAME//-/_}" | tr '[:lower:]' '[:upper:]')
    MODULE_SERVICE_HOST_VAR="${MODULE_SERVICE_PRE}_SERVICE_HOST"
    MODULE_SERVICE_PORT_VAR="${MODULE_SERVICE_PRE}_SERVICE_PORT"
    MODULE_SERVICE_HOST="${!MODULE_SERVICE_HOST_VAR:-localhost}"
    MODULE_SERVICE_PORT="${!MODULE_SERVICE_PORT_VAR:-8081}"
    MODULE_SERVICE_URL="http://$MODULE_SERVICE_HOST:$MODULE_SERVICE_PORT"

    DEPLOYMENT_DESCRIPTOR="{ \
        \"srvcId\": \"$MODULE_ID\",
        \"instId\": \"$MODULE_ID\",
        \"url\": \"$MODULE_SERVICE_URL\"
    }"
fi

# Register the module if it hasn't been already
MODULE_EXISTS=$(
    curl -s "${OKAPI_URL}/_/proxy/modules" | \
    jq "[.[].id == \"$MODULE_ID\"] | any"
)

if [ "$MODULE_EXISTS" == "false" ]; then
    echo -n "Registering module \"$MODULE_ID\"..."

    REGISTRATION_RESPONSE=$(
        curl -s -o /dev/null -w "%{http_code}" \
             -X POST \
             -H "Content-type: application/json" \
             -d "$MODULE_DESCRIPTOR" \
             "${OKAPI_URL}/_/proxy/modules"
    )

    if [ "$REGISTRATION_RESPONSE" != 201 ]; then
        echo "Failed. ${REGISTRATION_RESPONSE}"
        exit 2
    else
        echo "OK"
    fi
else
    echo "Already registered \"$MODULE_ID\""
fi

# Discover the module if it hasn't been already
MODULE_DISCOVERED=$(
    curl -s "${OKAPI_URL}/_/discovery/modules" | \
    jq "[.[].srvcId == \"$MODULE_ID\"] | any"
)

if [ "$MODULE_DISCOVERED" == "false" ]; then
    echo -n "Discovering module \"$MODULE_ID\"..."

    DISCOVERY_RESPONSE=$(
        curl -s -o /dev/null -w "%{http_code}" \
             -X POST \
             -H "Content-type: application/json" \
             -d "$DEPLOYMENT_DESCRIPTOR" \
             "${OKAPI_URL}/_/discovery/modules"
    )

    if [ "$DISCOVERY_RESPONSE" != 201 ]; then
        echo "Failed. ${DISCOVERY_RESPONSE}"
        exit 2
    else
        echo "OK"
    fi
else
    echo "Already discovered \"$MODULE_ID\""
fi

# Done
exit $?
