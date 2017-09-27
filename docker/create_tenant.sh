#! /bin/bash

okapi_url="http://$OKAPI_SERVICE_HOST:$OKAPI_SERVICE_PORT"

tenant_json="$1"
tenant_id=$(echo $tenant_json | jq -r ".id")
tenant_exists=$(curl -s "${okapi_url}/_/proxy/tenants" | jq "[.[].id == \"$tenant_id\"] | any")

if [ -z "$tenant_exists" ] || [ "$tenant_exists" == "false" ]; then
    echo -n "Creating Okapi tenant \"${tenant_id}\"..."

    create_tenant_response=$(
        curl -s -o /dev/null -w "%{http_code}" \
             -X POST \
             -H "Content-type: application/json" \
             -d "${tenant_json}" \
             "${okapi_url}/_/proxy/tenants")

    if [ "$create_tenant_response" != 201 ]; then
        echo "Failed. ${create_tenant_response}"
    else
        echo "OK"
    fi
else
    echo "Okapi tenant \"${tenant_id}\" already exists"
fi
