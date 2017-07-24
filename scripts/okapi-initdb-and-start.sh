#!/bin/bash

# Calls Okapi's `initdatabase` when no `modules` or `tenants` table exists
# in the postgres database; then starts okapi with postgres variables set based
# on local environment variables.
#
# Usage:
#
# ```bash
# DB_HOST="localhost" \
# DB_PORT="9130" \
# DB_USERNAME="okapi" \
# DB_PASSWORD="okapi25" \
# DB_DATABASE="okapi" \
# OKAPI_URL=http://localhost:9130 \
# ./okapi-initdb-and-start.sh
# ```
#
# ```bash
# # if okapi needs to be started locally with in-memory storage
# OKAPI_ROLE=dev \
# OKAPI_URL=http://localhost:9130 \
# ./okapi-initdb-and-start.sh --in-memory
# ```


# Kubernetes environment variables for okapi
OKAPI_SERVICE_HOST="${OKAPI_CLUSTER_SERVICE_HOST:=localhost}"
OKAPI_SERVICE_PORT="${OKAPI_CLUSTER_SERVICE_PORT:=9130}"

# Default environment variables
DB_HOST="${DB_HOST:=localhost}"
DB_PORT="${DB_PORT:=5432}"
DB_USERNAME="${DB_USERNAME:=okapi}"
DB_PASSWORD="${DB_PASSWORD:=okapi25}"
DB_DATABASE="${DB_DATABASE:=okapi}"
OKAPI_URL="${OKAPI_URL:=http://$OKAPI_SERVICE_HOST:$OKAPI_SERVICE_PORT}"
OKAPI_JAR="${OKAPI_JAR:=okapi-core/target/okapi-core-fat.jar}"
OKAPI_ROLE="${OKAPI_ROLE:=cluster}"

# Set postgres params unless we want to use in-memory storage
if [ "$1" != '--in-memory' ]; then
    OKAPI_JAVA_DB_OPTS+=" -Dstorage=postgres"
    OKAPI_JAVA_DB_OPTS+=" -Dpostgres_host=${DB_HOST}"
    OKAPI_JAVA_DB_OPTS+=" -Dpostgres_port=${DB_PORT}"
    OKAPI_JAVA_DB_OPTS+=" -Dpostgres_user=${DB_USERNAME}"
    OKAPI_JAVA_DB_OPTS+=" -Dpostgres_password=${DB_PASSWORD}"
    OKAPI_JAVA_DB_OPTS+=" -Dpostgres_database=${DB_DATABASE}"
    OKAPI_JAVA_OPTS+=" ${OKAPI_JAVA_DB_OPTS}"
else
    OKAPI_JAVA_OPTS+=" -Dstorage=inmemory"
fi

# Tell Okapi its own official URL. This gets passed to the
# modules as X-Okapi-Url header, and the modules can use this
# to make further requests to Okapi. Defaults to 'http://localhost:9130'
# or whatever port specified. There should be no trailing slash.
OKAPI_JAVA_OPTS+=" -Dokapiurl=${OKAPI_URL}"

# Ensure our jar file exists
if [ ! -f "$OKAPI_JAR" ]; then
    echo "Unable to locate ${OKAPI_JAR}"
    exit 1
fi

# Initialize the Okapi database if necessary
if [ "$1" != '--in-memory' ]; then
    if hash psql 2>/dev/null; then
        psql postgresql://${DB_USERNAME}:${DB_PASSWORD}@${DB_HOST}:${DB_PORT}/${DB_DATABASE}  \
             -c "\dt" -t | cut -d \| -f 2 | grep -Eqw "modules|tenants"

        POSTGRES_RETVAL=$?
        if [ "$POSTGRES_RETVAL" != 0 ]; then
            echo -n "Initializing okapi database..."
            java ${OKAPI_JAVA_DB_OPTS} -jar "$OKAPI_JAR" initdatabase >/dev/null 2>&1

            INIT_RETVAL=$?
            if [ "$INIT_RETVAL" != 0 ]; then
                echo "Failed"
                exit 2
            else
                echo "OK"
            fi
        fi
    else
        echo "Postgres client not installed. Unable to test connectivity to postgres instance."
        exit 2
    fi
fi

# Start okapi
echo "Starting Okapi..."
exec java $OKAPI_JAVA_OPTS -jar "$OKAPI_JAR" $OKAPI_ROLE
