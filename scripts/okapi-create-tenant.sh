#!/bin/bash

# Creates a new tenant. If no tenant is specified, use a default
# Frontside tenant instead.
#
# Usage:
#
# ```bash
# OKAPI_URL=http://localhost:9130 \
# ./okapi-create-tenant.sh \
# '{ "id": "fs", "name": "Frontside", "description": "Testing Library" }'
# ```

# Kubernetes environment variables for okapi
OKAPI_SERVICE_HOST="${OKAPI_CLUSTER_SERVICE_HOST:-localhost}"
OKAPI_SERVICE_PORT="${OKAPI_CLUSTER_SERVICE_PORT:-9130}"

# Default environment variables
OKAPI_URL="${OKAPI_URL:=http://$OKAPI_SERVICE_HOST:$OKAPI_SERVICE_PORT}"

# Default to FS tenant if none provided
TENANT_PAYLOAD=${1:-"{
  \"id\": \"fs\",
  \"name\": \"The Frontside Library\",
  \"description\": \"The Frontside Testing Library\"
}"}

# Ensure the jq library is available
if ! hash jq 2>/dev/null; then
    echo 'This script requires the jq library.'
    echo 'https://stedolan.github.io/jq/'
    exit 2
fi

# Extract tenant id
TENANT_ID=$(echo $TENANT_PAYLOAD | jq '.id')

# Create our tenant if they aren't already
TENANT_CREATED=$(
    curl -s "${OKAPI_URL}/_/proxy/tenants" | \
    jq "[.[].id == $TENANT_ID] | any"
)

if [ "$TENANT_CREATED" == "false" ]; then
    echo -n "Creating tenant $TENANT_ID..."

    CREATE_TENANT_RESPONSE=$(
        curl -s -o /dev/null -w "%{http_code}" \
             -X POST \
             -H "Content-type: application/json" \
             -d "$TENANT_PAYLOAD" \
             "${OKAPI_URL}/_/proxy/tenants"
    )

    if [ "$CREATE_TENANT_RESPONSE" != 201 ]; then
        echo "Failed. ${CREATE_TENANT_RESPONSE}"
        exit 2
    else
        echo "OK"
    fi
else
    echo "Tenant $TENANT_ID already exists"
fi
