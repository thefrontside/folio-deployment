#! /bin/bash
okapi_url="$OKAPI_SERVICE_HOST:$OKAPI_SERVICE_PORT"

tenant_id="$1"
shift
module_descriptors=$(echo "\"$@\"" | jq 'split(" ") | [.[] | {id:., action:"enable"}]')

tenant_response=$(
    curl -s -o /dev/null -w "%{http_code}" \
         "${okapi_url}/_/proxy/tenants/${tenant_id}")

if [ "$tenant_response" != 200 ]; then
    echo "Unable to find Okapi tenant \"${tenant_id}\""
    exit 2
fi

echo -n "Enabling FOLIO modules for tenant \"${tenant_id}\"..."

enable_modules_response=$(
    curl -s -o /dev/null -w "%{http_code}" \
         -X POST \
         -H "Content-type: application/json" \
         -d "${module_descriptors}" \
         "${okapi_url}/_/proxy/tenants/${tenant_id}/install")

if [ "$enable_modules_response" != 201 ]; then
    echo "Failed. ${enable_modules_response}"
else
    echo "OK"
fi
