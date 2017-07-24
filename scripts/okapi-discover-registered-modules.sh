#!/bin/bash

# Loops over registered modules and if service environment variables are
# defined for the module, register the discovery endpoint with okapi
#
# Usage:
#
# ```bash
# # will discover the endpoint for a module with id "folio-mod-users"
# FOLIO_MOD_USERS_SERVICE_HOST=localhost \
# FOLIO_MOD_USERS_SERVICE_PORT=8081 \
# OKAPI_URL=localhost:9130 \
# ./okapi-discover-registered-modules.sh
# ```

# Kubernetes environment variables for okapi
OKAPI_SERVICE_HOST="${OKAPI_CLUSTER_SERVICE_HOST:-localhost}"
OKAPI_SERVICE_PORT="${OKAPI_CLUSTER_SERVICE_PORT:-9130}"

# Default environment variables
OKAPI_URL="${OKAPI_URL:=http://$OKAPI_SERVICE_HOST:$OKAPI_SERVICE_PORT}"

# Ensure the jq library is available
if ! hash jq 2>/dev/null; then
    echo 'This script requires the jq library.'
    echo 'https://stedolan.github.io/jq/'
    exit 2
fi

# Discover a module when environment variables for it's service exist
discover_module() {
    MOD_ID=$1

    MOD_PRE=$(echo "${MOD_ID//-/_}" | tr '[:lower:]' '[:upper:]')
    MOD_SERVICE_HOST="${MOD_PRE}_SERVICE_HOST"
    MOD_SERVICE_PORT="${MOD_PRE}_SERVICE_PORT"
    MOD_SERVICE_URL="http://${!MOD_SERVICE_HOST}:${!MOD_SERVICE_PORT}"

    if [ ! "${!MOD_SERVICE_HOST}" ]; then
        echo "Could not infer host for \"$MOD_ID\""
        return
    fi

    echo -n "Registering module \"$MOD_ID\"..."

    MOD_REGISTRATION_RESPONSE=$(
        curl -s -o /dev/null -w "%{http_code}" \
             -X POST \
             -H "Content-type: application/json" \
             -d "{
               \"srvcId\": \"$MOD_ID\",
               \"instId\": \"$MOD_ID\",
               \"url\": \"$MOD_SERVICE_URL\"
             }" \
             "${OKAPI_URL}/_/discovery/modules"
    )

    if [ "$MOD_REGISTRATION_RESPONSE" != 201 ]; then
        echo "Failed. ${MOD_REGISTRATION_RESPONSE}"
    else
        echo "OK"
    fi
}

# Loop over existing registered modules and rediscover them if neccessary
DISCOVERED=$(curl -s "${OKAPI_URL}/_/discovery/modules")

curl -s "${OKAPI_URL}/_/proxy/modules" | jq -r '.[].id' | while read MOD_ID ; do
    MOD_DISCOVERED=$(echo $DISCOVERED | jq "[.[].srvcId == \"$MOD_ID\"] | any")

    if [ "$MOD_DISCOVERED" != "true" ]; then
        discover_module $MOD_ID
    else
        echo "Already discovered \"$MOD_ID\""
    fi
done
