#! /bin/bash
cd $HOME

echo "Cloning repo $REPO_NAME..."
git clone -q https://github.com/$REPO_NAME repo
cd repo

echo "Checking out $REPO_VERSION..."
git checkout -q $REPO_VERSION

echo "Installing with Maven..."
mvn install -DskipTests -q

if [ "$OKAPI_MODULE_DESCRIPTOR_PATH" ] && [ "$OKAPI_MODULE_SERVICE_NAME" ]; then
    /usr/local/bin/folio/auto_register_module.sh \
        $OKAPI_MODULE_SERVICE_NAME \
        $OKAPI_MODULE_DESCRIPTOR_PATH
fi

echo -e "Executing args...\n"
touch /tmp/health
exec "$@" &> >(tee -a /tmp/health)
