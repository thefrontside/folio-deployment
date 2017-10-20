# folio-deployment
Deploy Folio to our Infrastructure


# Deployment Instructions

Currently to deploy to production or development you need to update
certain files in the repo manually until the time as such a feature
lands to allow for passing a environment flag during the deployment.
Until such time here are the files that you need to check, update
before you attempt to stand up a new cluster.


## Deploy to Production Cluster:

1. Update url in

   File: `vendor/folio_deployment/lib/folio_deployment/cli/commands/base.rb`
   ```
    @okapi ||= Okapi::Client.new('https://okapi.frontside.io', 'fs', nil)
   ```

2. Change the cloudsql instance address. You can get the full address from the google container engine console dashboard under the sql tab if needed. 

   File: `kubernetes/okapi.yaml`
   ```
    host:
    - -instances=[cloudsql-instance-name-from-gke]:folio-v2=tcp:5432
   ```

3. Update the host, context and instance.

   File: `folio.conf`
    * `host: https://okapi.frontside.io`
    * `context: [project-name]_us-central1-a_okapi`
    * `instance: [project-name]:us-east1:folio-v2`

4. Update the hosts and host url.

   File: `kubernets/ingress/ingress-tls.yaml`
   ```
    hosts:
    - okapi.frontside.io
    rules:
    - host: okapi.frontside.io
   ```
5. Update host url.

    File: `kubernetes/ingress/ingress.yaml`
    * `host: okapi.frontside.io`


## Deploy to Development Cluster:
1. Update url in

   File: `vendor/folio_deployment/lib/folio_deployment/cli/commands/base.rb`
   ```
    @okapi ||= Okapi::Client.new('https://okapi-sandbox.frontside.io', 'fs', nil)
   ```

2. Change the cloudsql instance address. You can get the full address from the google container engine console dashboard under the sql tab if needed. 

   File: `kubernetes/okapi.yaml`

   ```
    host:
    - -instances=[cloudsql-instance-name-from-gke]:okapi-sandbox=tcp:5432
   ```

3. Update the host, context and instance.

   File: `folio.conf`

    * `host: https://okapi-sandbox.frontside.io`
    * `context: [project-name]_us-central1-a_okapi-sandbox`
    * `instance: [project-name]:us-east1:okapi-sandbox`

4. Update the hosts and host url.

   File: `kubernets/ingress/ingress-tls.yaml`

   ```
    hosts:
    - okapi-sandbox.frontside.io
    rules:
    - host: okapi-sandbox.frontside.io
   ```
5. Update host url.

    File: `kubernetes/ingress/ingress.yaml`
    * `host: okapi-sandbox.frontside.io`