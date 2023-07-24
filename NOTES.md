This is my attempt to modify the code in order to deploy it to Epinio 1.8.1 instead of CloudFoundry:
- I spent 2 days with this challenge
- I had never actually used `conda` before
- I had never heard of `CloudFoundry`, `Epinio`, `nameko` nor `paketo`

Machine used: `Linux 5.15.0-76-generic #83~20.04.1-Ubuntu SMP Wed Jun 21 20:23:31 UTC 2023 x86_64 x86_64 x86_64 GNU/Linux`

After some time checking files, reading documentations and installing things, I was able to execute everything in `README-DevEnv.md`.
- I already had [jq 1.6](https://jqlang.github.io/jq/) so I didn't need [brew](https://brew.sh/)
- I used [Miniconda](https://docs.conda.io/en/latest/miniconda.html) (`conda 23.5.2`)
- I had to install Microsoft's Python extension in VS Code and use the correct "Python Debug: Connect" option

Next was the execution of the instructions in `README-DevOps.md`, so I installed [Epinio CLI](https://docs.epinio.io/installation/install_epinio_cli).

I created a [k3d 5.5.1](https://k3d.io/) local cluster and followed [Epinio's instructions](https://docs.epinio.io/howtos/install_epinio_on_k3d). To easily get a fresh installation if I ever needed it, I wrote `recreate_k3d_cluster.sh`. Check the contents of the script and _be careful_: it **WIPES DOCKER COMPLETELY**, recreates the k3d cluster and installs Epinio. For my local environment, this "nuclear" approach was acceptable.

The Epinio section in `README-DevOps.md` actually uses the `Makefile` to execute CloudFoundry-related commands.

I started experimenting with `make`, duplicating the CF-related targets and writing additional ones:
- `epinio_cs_all`/`epinio_ds_all`: create/destroy all services at once
- `epinio_bind`: easily retry binding and restarting if these commands timeout after pushing the app
- `epinio_purge`: destroy the entire namespace

I wanted the `EPINIO_NS` and `EPINIO_APP` variables to be required by `make` accordingly, to avoid mistakes and provide flexibility. Using a custom namespace may even improve parallelism, allowing developers to control how they separate their workloads within the cluster.

After some minor tweaks I attempted to deploy the app, but it didn't work. When staging the app, part of Epinio's output was:
```
buildpack Paketo Buildpack for Python Start 0.14.11
buildpack   Assigning launch processes:
buildpack     Web (default): python
```

This is a mistake: simply executing "`python`" doesn't start the app.

I learned that [CF sees the manifest.yml file](https://docs.cloudfoundry.org/devguide/deploy-apps/manifest.html), which specifies the entrypoint command. I tried to do the same thing for Epinio with `epinio.yml`, but its manifest [doesn't seem to have this option](https://docs.epinio.io/references/manifests). When investigating more about Paketo, I discovered how [the oficial Python-related documentation suggests](https://paketo.io/docs/howto/python/#override-the-start-process-set-by-the-buildpack) overriding the start process. The [Procfile buildpack](https://github.com/paketo-buildpacks/procfile) is included in the [Paketo Full Builder image](https://github.com/paketo-buildpacks/full-builder), which is [used by Epinio](https://docs.epinio.io/references/supported_applications#supported-buildpacks). So, I'd just need to create a `Procfile` and adapt the command from `manifest.yml`.

To validate the solution first, I changed a few things:
- the new `Procfile` would only contain "`web: echo hello world`"
- the `epinio.yml` manifest would now specify the configuration "`instances: 0`"
- the `Makefile` would not restart the app, but instead run "`epinio app update $(EPINIO_APP) --instances 1`"

The staging log now showed:
```
buildpack ===> DETECTING 
buildpack 5 of 8 buildpacks participating 
buildpack paketo-buildpacks/ca-certificates  3.6.3 
buildpack paketo-buildpacks/miniconda        0.8.4 
buildpack paketo-buildpacks/conda-env-update 0.7.11 
buildpack paketo-buildpacks/python-start     0.14.11 
buildpack paketo-buildpacks/procfile         5.6.4
...
buildpack Paketo Buildpack for Procfile 5.6.4 
buildpack   https://github.com/paketo-buildpacks/procfile 
buildpack   Process types: 
buildpack     web: echo hello world
```

With this approach, I was able to retrieve the logs in time, as the pod would simply complete its lifecycle after printing the message. Using `epinio app logs` didn't yield any output, but `kubectl logs` (targeting the correct pod) did the trick and displayed "`hello world`".

Back to adapting from `manifest.yml`, I noticed `cf_run.sh` reads `VCAP_SERVICES` to create other environment variables required by `run.sh`. This variable is [specific to CF](https://docs.cloudfoundry.org/devguide/deploy-apps/environment-variable.html#VCAP-SERVICES).

I started looking for ways to automatically retrieve the relevant URIs. Some official links like [this example repository](https://github.com/epinio/example-rails/tree/fc973eedf2697918f01cefe7206fa6840fdeee23) and [this tutorial section](https://docs.epinio.io/tutorials/custom_builder_go#create-and-bind-the-database) seem to suggest a manual approach (using `epinio service show` to get only the route). [This official reference](https://docs.epinio.io/references/services) says the Helm chart used for the example doesn't write the hostname of the database in the generated secret because it wasn't created specifically for Epinio.

Following [this documentation](https://docs.epinio.io/howtos/create_custom_service), I attempted to create new a "`postgresql-custom`" service (based on `postgresql-dev`) with some changes:
- adding the value "`serviceBindings: true`" (see [L55](https://github.com/bitnami/charts/blob/3e6c4816902a5250fa97202590da88c65ffa2a94/bitnami/postgresql/templates/secrets.yaml#L55), [L1175](https://github.com/bitnami/charts/blob/3e6c4816902a5250fa97202590da88c65ffa2a94/bitnami/postgresql/values.yaml#L1175))
- adding the annotation "`application.epinio.io/catalog-service-secret-types: Opaque,servicebinding.io/postgresql`" (see [L70](https://github.com/bitnami/charts/blob/3e6c4816902a5250fa97202590da88c65ffa2a94/bitnami/postgresql/templates/secrets.yaml#L70))

I applied `service.yml` and followed [these instructions](https://docs.epinio.io/references/services), creating a "`sample`" app. It didn't work, as `epinio configuration show` would still show only a single parameter called "`postgres-password`". Double-checking with `epinio app exec sample` confirmed the absence of other secrets.

After some testing, I decided to [install `yq`](https://github.com/mikefarah/yq/#install) and use `epinio app manifest` to retrieve the app's manifest, which contains the names of all bound configurations. With this, I wrote a very crude script called `formURI.sh` to aid in constructing the desired string:
```
# Assuming namespace "myns", app "myapp" and service "myapp_rabbitmq".
# Parameter 3 matches the end of the configuration name (avoids reading from "rabbitmq-config").
# Parameter 4 matches the end of the desired route (avoids reading from "rabbitmq-headless" and/or a wrong port).
# Parameter 5 is the template URI (should include "%PASS%" and "%HOST%").

$ ./formURI.sh \
	retrieved-manifest.yml \
	myapp_rabbitmq \
	'rabbitmq' \
	'rabbitmq.myns.svc.cluster.local:5672' \
	'amqp://username:%PASS%@%HOST%'

amqp://username:jHHRenxN1zrGej8r@x24be110700311b94ca12763b7e33-rabbitmq.myns.svc.cluster.local:5672
```

Some additional changes were made for testing. Commands in `Makefile` specially got quite messy and unsecure. I'm not proud of it, but I take it as part of the learning process. Perhaps a better automation can be achieved within Epinio somehow (using certain commands and/or modifying Helm charts), but I couldn't find any proper documentation. This naive approach shall be revised when I have more time and Epinio releases new versions.

Nevertheless, the application within Epinio doesn't crash anymore and `epinio app logs` shows a sensible error:
```
rmyapp-94e7d341f71ff6f43253f1c5e813057b22f91cda amqp.exceptions.AccessRefused:
	(0, 0): (403) ACCESS_REFUSED - Login was refused using authentication mechanism AMQPLAIN.
	For details see the broker logfile.
```
