# Deploying nameko-devex
![Airship Ltd](airship.png)

## Docker
### Prerequisites deployment to Docker
* [Docker](https://docs.docker.com/get-docker/). 
* Docker cli is working. eg: `docker-compose` - [Install instructions](https://docs.docker.com/compose/install/)

### Setup
* Deploy nameko microservice in docker
```sh
make deploy-docker
```
* Smoketest your landscape via `make smoke-test`, make sure you are in your _namekoexample_ conda environment 
* You could also performance test your landscape via `make perf-test`
* To undeploy/stop, Control-C above process

Please read the [Makefile](Makefile) for more details on the commands

## K8S using KinD
### Prerequisites deployment to K8S
* Docker (see above)
* Kubernetes in Docker - [KinD](https://kind.sigs.k8s.io/docs/user/quick-start/#installation)

### Setup
* Deploy nameko microservice in K8S
```sh
cd k8s
make deployK8
```
* Smoketest your landscape via `make smoke-test`, make sure you are in your _namekoexample_ conda environment 
* You could also performance test your landscape via `make perf-test`
* To undeploy, use `make undeployK8`

Please read the [Makefile](k8s/Makefile) for more details on the commands


## Epinio.io
### Prerequisites deployment to Epinio

* [Epinio cli](https://docs.epinio.io/installation/install_epinio_cli#from-homebrew-linux-and-mac)
* Install Epinio Landscape:
    - https://docs.epinio.io/installation/install_epinio

### Setup
Instruction below is using CloudFoundry/Heruku like.. assuming you have epinio stack install, your experience is similar to CF-like. Do you see how easy as compare to K8 and even docker.

* Login into CF account.

* Activate environment before running deployment script
```ssh
$ conda activate nameko-devex
```

* Deploy to CF via make
```ssh
(nameko-devex) CF_APP=<prefix> make deployCF
```
If prefix is `demo`, the above command will:
- Create the following free backing service instances
  * `demo_rabbitmq` for messaging
  * `demo_postgres` for postgres (Order service)
  * `demo_redis` for redis (Products service)

- Push `demo` app with _no-start_ option
- Bind `demo` app to each backing service
- Restage/restart `demo` app
- Note: We can use `manifest.yml` for deployment without above step assuming the backing service is create prior
  * URL: `demo.<CF_DOMAIN>`

For multiple app deployment, uncomment appropriately in `manifest.yml` 

* Undeploy apps from CF
```ssh
(nameko-devex) CF_APP=<PREFIX> make undeployCF <prefix>
```

* Verifying app works in CF
```ssh
(nameko-devex) test/nex-smoketest.sh <cf_url>
```

### CI/CD
Using Cloudfoundry CLI is so straightforward that creating automation for development in dev or production environment is trivial from developer point of view