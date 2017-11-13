# okubi
An Okapi deployment toolkit.

Automation for deploying a Okapi instance and its modules to a Kubernetes (k8s) cluster from a command line interface. The easy button is here.


## Why okubi?

Successfully standing up Okapi and its modules into a cluster requires that certain things that we are calling 'task' happen in a specific order. Doing so manually requires that the opertator remembers the list of task and their execution order which can be error-proned. In addition, this process can take a considerable amount of time as the operator needs to wait for a task to complete before proceeding to the next. Unfortunately task execution order is not the only knowledge needed for a deployment. 

Kubernetes presents terminology, tools, and techniques specific to Kubernetes that need to be learned before deploying to a cluster. This can be a tall order as Kubernetes and Devops in general cover a large surface area. Fortunately this `okubi` toolkit eleviates the need to learn Okapi task execution order, Kubernetes, and Devops straight out the gate.

Deploying Okapi and the modules to a new Kubernetes cluster just takes running a command such as `okubi deploy --environment sandbox`.

## Pre-deploy Caveat

Currently this toolkit is hard coded for use with Frontside's Google Container Engine (GKE) instances but can be tailored for use with another GKE instance wanting to deploy Okapi and the modules.

## Deploying Cluster
To run any commands you can `cd` (change directory) in the `scripts` folder from the root of these repo.

Commands available:
 * `okubi deploy --environment sandbox`
 Deploys a cluster to the development environment.
 * `okubi deploy --environment production`
 Deploys a cluster to the production environment.

Okubi in the process of deploying to a Kubernetes cluster will automate several task for you such as:
* Deploy Ingress
* Deploy Nginx Controllers + Default Backend
* Configure + Update DNS Record
* Deploy + Configure Kube Lego
* Verify TLS Certificate
* Deploy Okapi
* Create a Tenant
* Create List of Desired Modules based on list in `folio.conf`
  * An additional feature is the ability to add priority to the modules. 
    This will affect the order of which modules are deployed 
* Resolve Dependencies of modules from the desired modules and the available modules
* Deploy + Register resolved modules with Okapi
* Discover modules
* Enable modules for tenant
* Create an 'admin' User


## Destroying Cluster

!Imporant before running this command make sure you are in the correct cluster known as `context`!

To view you current current context you can run `kubectl config current-context` from the command line.

* `okubi destroy`
