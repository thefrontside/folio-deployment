#! /bin/bash

service_name="$1"
shift
module_descriptor_path="$1"
shift
enable_module_tenants="$@"

if [ ! -f "$module_descriptor_path" ]; then
    echo "Cannot find module descriptor at path \"${module_descriptor_path}\""
    exit 2
fi

module_id=$(cat $module_descriptor_path | jq -r '.id')

/usr/local/bin/folio/register_module.sh $module_id $(realpath $module_descriptor_path)
/usr/local/bin/folio/discover_service.sh $module_id $service_name

if [ "$enable_module_tenants" ]; then
    for tenant_id in $enable_module_tenants; do
        /usr/local/bin/folio/enable_tenant_modules.sh $tenant_id $module_id
    done
fi
