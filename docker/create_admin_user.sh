#!/bin/bash

# Create ~/.pgpass file with appropriate credentials
echo "$DB_HOST:$DB_PORT:*:$DB_USERNAME:$DB_PASSWORD" > ~/.pgpass
chmod 600 ~/.pgpass

# Since this depends on the sidecar cloudsql container, it's
# possible that this will run before that container finishes initializing.
# We have the restartPolicy set to OnFailure for this job, so
# we want to throw a bad exit code if the DB isn't ready yet
# and then retry until this passes (note the use of `set -e` above).
pg_isready -h $DB_HOST -p $DB_PORT -U $DB_USERNAME;
while [ $? -ne 0 ]; do
    echo "Waiting for cloudsql"
    pg_isready -h $DB_HOST -p $DB_PORT -U $DB_USERNAME;
done
# Define the superuser attributes (TOOD: associative array?  pods seem to have bash 4.3)
superuser_username='admin'
superuser_password='admin'
superuser_hash='52DCA1934B2B32BEA274900A496DF162EC172C1E'
superuser_salt='483A7C864569B90C24A0A6151139FF0B95005B16'
superuser_perms_user_id='2408ae64-56ad-4177-9024-1e35fe5d895c'
superuser_permissions='"perms.all","users.all","login.all","configuration.all",users-bl.all'
superuser_id='1ad737b0-d847-11e6-bf26-cec0c932ce01'
superuser_firstname='FrontsideFirst'
superuser_lastname='FrontsideLast'
superuser_email='folio_admin@frontside.io'

# Insert admin user into fs_login_module.auth_credentials if not present
auth_creds_exist=$(
    psql -h $DB_HOST -p $DB_PORT -U $DB_USERNAME -qtwc \
         "select count(*) from fs_mod_login.auth_credentials \
         where jsonb @> '{\"userId\":\"${superuser_id}\"}'" \
         $DB_DATABASE | tr -d '[:space:]'
);

if [[ $auth_creds_exist == "0" ]]; then
    echo "[INFO] Inserting superuser into auth_credentials"
    psql -h $DB_HOST -p $DB_PORT -U $DB_USERNAME -qtwc \
         "insert into fs_mod_login.auth_credentials (jsonb) values \
         ('\
           {\
             \"userId\":\"${superuser_id}\",\
             \"hash\":\"${superuser_hash}\",\
             \"salt\":\"${superuser_salt}\"\
           }\
         ')" $DB_DATABASE
else
    echo "[INFO] Superuser already present in auth_credentials"
fi

# Insert admin user into fs_permissions_module.permissions_users if not present
perm_user_exist=$(
    psql -h $DB_HOST -p $DB_PORT -U $DB_USERNAME -qtwc \
         "select count(*) from fs_mod_permissions.permissions_users \
         where jsonb @> '{\"userId\":\"${superuser_id}\"}'" \
         $DB_DATABASE | tr -d '[:space:]'
);

if [[ $perm_user_exist == "0" ]]; then
    echo "[INFO] Inserting superuser into permissions_users"
    psql -h $DB_HOST -p $DB_PORT -U $DB_USERNAME -qtwc \
         "insert into fs_mod_permissions.permissions_users (jsonb) values \
         ('\
           {\
             \"id\":\"${superuser_perms_user_id}\",\
             \"userId\":\"${superuser_id}\",\
             \"permissions\":[\
               ${superuser_permissions}\
             ]\
           }\
         ')" $DB_DATABASE
else
    echo "[INFO] Superuser already present in permissions_users"
fi

# Insert admin into fs_mod_users.users if not present
user_exist=$(
    psql -h $DB_HOST -p $DB_PORT -U $DB_USERNAME -qtwc \
         "select count(*) from fs_mod_users.users \
         where jsonb @> '{\"username\":\"${superuser_username}\"}'" \
         $DB_DATABASE | tr -d '[:space:]'
);


if [[ $user_exist == "0" ]]; then
    echo "[INFO] Inserting superuser into users"
    psql -h $DB_HOST -p $DB_PORT -U $DB_USERNAME -qtwc \
         "insert into fs_mod_users.users (jsonb) values \
           ('\
             {\
               \"username\":\"${superuser_username}\",\
               \"id\":\"${superuser_id}\",\
               \"active\":true,\
               \"personal\":{\
                 \"lastName\":\"${superuser_lastname}\",\
                 \"firstName\":\"${superuser_firstname}\",\
                 \"email\":\"${superuser_email}\"\
               }\
             }\
           ')" $DB_DATABASE
else
    echo "[INFO] Superuser already present in users"
fi
