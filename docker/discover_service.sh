#! /bin/bash

okapi_url="$OKAPI_SERVICE_HOST:$OKAPI_SERVICE_PORT"

module_id="$1"
service_id="$2"
module_discovered=$(curl -s "${okapi_url}/_/discovery/modules" | jq "[.[].srvcId == \"$module_id\"] | any")

if [ "$module_discovered" == "false" ]; then
    service_prefix=$(echo "${service_id//-/_}" | tr '[:lower:]' '[:upper:]')
    service_host_var="${service_prefix}_SERVICE_HOST"
    service_port_var="${service_prefix}_SERVICE_PORT"
    service_url="http://${!service_host_var}:${!service_port_var}"

    if [ ! "${!service_host_var}" ]; then
        echo "Unable to infer environment variables for service \"${service_id}\""
        exit 2
    fi

    deployment_descriptor="{
        \"srvcId\": \"${module_id}\",
        \"instId\": \"${module_id}\",
        \"url\": \"${service_url}\"
    }"

    echo -n "Discovering FOLIO module \"${module_id}\"..."

    discovery_response=$(
        curl -s -o /dev/null -w "%{http_code}" \
             -X POST \
             -H "Content-type: application/json" \
             -d "${deployment_descriptor}" \
             "${okapi_url}/_/discovery/modules")

    if [ "$discovery_response" != 201 ]; then
        echo "Failed. ${discovery_response}"
        exit 2
    else
        echo "OK"
    fi
else
    echo "Already discovered FOLIO module \"${module_id}\""
fi
