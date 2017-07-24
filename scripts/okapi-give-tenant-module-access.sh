#!/bin/bash

# Grants a tenant access to all currently registered modules or a subset of them.
#
# Usage:
#
# ```bash
# OKAPI_URL=http://localhost:9130 \
# ./okapi-give-tenant-module-access.sh "fs"
# # optional json array of module ids
# # '["folio-mod-users"]'
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

# Tenant ID defaults to "fs"
TENANT_ID="${1:-fs}"

# Optional subset of module ids
for MOD_ID in "${@:2}"; do MOD_SUBSET+="\"$MOD_ID\", "; done
if [ "$MOD_SUBSET" ]; then MOD_SUBSET="[${MOD_SUBSET%??}]"; fi

# Ensure our tenant exists
TENANT_EXISTS=$(
    curl -s "${OKAPI_URL}/_/proxy/tenants" | \
    jq "[.[].id == \"$TENANT_ID\"] | any"
)

if [ "$TENANT_EXISTS" == "false" ]; then
    echo "Unknown tenant \"$TENANT_ID\""
    exit 1
fi

# Tenant module endpoint
OKAPI_TENANT_MODULE_ENDPOINT="${OKAPI_URL}/_/proxy/tenants/${TENANT_ID}/modules"

REGISTERED=$(curl -s "$OKAPI_TENANT_MODULE_ENDPOINT")

# Register a module with the tenant
register_module() {
    MOD_ID="$1"

    MOD_REGISTERED=$(echo $REGISTERED | jq "[.[].id == \"$MOD_ID\"] | any")

    if [ "$MOD_REGISTERED" == "false" ]; then
        echo -n "Registering module \"$MOD_ID\" with tenant \"$TENANT_ID\"..."

        MOD_REGISTRATION_RESPONSE=$(
            curl -s -o /dev/null -w "%{http_code}" \
                 -X POST \
                 -H "Content-type: application/json" \
                 -d "{ \"id\": \"$MOD_ID\" }" \
                 "$OKAPI_TENANT_MODULE_ENDPOINT"
        )

        if [ "$MOD_REGISTRATION_RESPONSE" != 201 ]; then
            echo "Failed. ${MOD_REGISTRATION_RESPONSE}"
        else
            echo "OK"
        fi
    else
        echo "Already registered \"$MOD_ID\" with tenant \"$TENANT_ID\""
    fi
}

# Loop over passed modules or existing registered modules
if [ "$MOD_SUBSET" ]; then
    echo $MOD_SUBSET | jq -r '.[]' | while read MOD_ID; do
        OKAPI_MOD_STATUS=$(curl -s -o /dev/null -w '%{http_code}' "${OKAPI_URL}/_/proxy/modules/${MOD_ID}")

        if [ "$OKAPI_MOD_STATUS" == "200" ]; then
            register_module $MOD_ID
        else
            echo "Unable to find module \"$MOD_ID\". ${OKAPI_MOD_STATUS}"
        fi
    done
else
    curl -s "${OKAPI_URL}/_/proxy/modules" | jq -r '.[].id' | while read MOD_ID; do
        register_module $MOD_ID
    done
fi

# Done
exit;
