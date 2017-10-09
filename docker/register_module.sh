#! /bin/bash

okapi_url="$OKAPI_SERVICE_HOST:$OKAPI_SERVICE_PORT"

if [ ! -f "$2" ]; then
    echo "Cannot find module descriptor at path \"$2\""
    exit 2
fi

module_id="$1"
module_descriptor=$(cat "$2")
module_registered=$(curl -s "${okapi_url}/_/proxy/modules" | jq "[.[].id == \"$module_id\"] | any")

if [ "$module_registered" == "false" ]; then
    echo -n "Registering FOLIO module \"${module_id}\" with Okapi..."

    registration_response=$(
        curl -s -o /dev/null -w "%{http_code}" \
             -X POST \
             -H "Content-type: application/json" \
             -d "${module_descriptor}" \
             "${okapi_url}/_/proxy/modules")

    if [ "$registration_response" != 201 ]; then
        echo "Failed. ${registration_response}"
        exit 2
    else
        echo "OK"
    fi
else
    echo "FOLIO module \"${module_id}\" already registered with Okapi..."
fi
