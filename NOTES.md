This is my attempt to modify the code in order to deploy it to Epinio instead of CloudFoundry:
- I originally thought I'd only have 2 days to complete the challenge (more on that later)
- The "first part" of the challenge was all done with Epinio 1.8.1
- I had never actually used `conda` before
- I had never heard of `CloudFoundry`, `Epinio`, `nameko` nor `paketo`

Machine used at first: `Linux 5.15.0-76-generic #83~20.04.1-Ubuntu SMP Wed Jun 21 20:23:31 UTC 2023 x86_64 x86_64 x86_64 GNU/Linux`

After some time checking files, reading documentations and installing things, I was able to execute everything in `README-DevEnv.md`.
- I already had [jq 1.6](https://jqlang.github.io/jq/) installed
- I used [Miniconda](https://docs.conda.io/en/latest/miniconda.html) (`conda 23.5.2`)
- I had to install Microsoft's Python extension in VS Code and use the correct "Python Debug: Connect" option

Next was the execution of the instructions in `README-DevOps.md` (adapting to Epinio).

I created a [k3d 5.5.1](https://k3d.io/) local cluster, followed [Epinio's instructions](https://docs.epinio.io/howtos/install_epinio_on_k3d) and also [installed its CLI](https://docs.epinio.io/installation/install_epinio_cli).
To easily get a fresh installation if I ever needed it, I wrote `recreate_k3d_cluster.sh`.
Check the contents of the script before executing: it **wipes any kubeconfigs**, recreates the k3d cluster and installs Epinio.

The Epinio section in `README-DevOps.md` actually uses the `Makefile` to execute CloudFoundry-related commands.

I started experimenting with `make`, duplicating the CF-related targets and writing additional ones:
- `epinio_cs_all`/`epinio_ds_all`: create/destroy all services at once
- `epinio_bind`: easily retry binding and restarting if these commands timeout after pushing the app
- `epinio_purge`: destroy the entire namespace

I wanted the `EPINIO_NS` and `EPINIO_APP` variables to be required by `make` accordingly, to avoid mistakes and provide flexibility.
Using a custom namespace may even improve parallelism, allowing developers to control how they separate their workloads within the cluster.

After some minor tweaks I attempted to deploy the app, but it didn't work.
When staging the app, part of Epinio's output was:
```
buildpack Paketo Buildpack for Python Start 0.14.11
buildpack   Assigning launch processes:
buildpack     Web (default): python
```

This is a mistake: simply executing "`python`" doesn't start the app.

I learned that [CF sees the manifest.yml file](https://docs.cloudfoundry.org/devguide/deploy-apps/manifest.html), which specifies the entrypoint command.
I tried to do the same thing for Epinio with `epinio.yml`, but its manifest [doesn't seem to have this option](https://docs.epinio.io/references/manifests).
When investigating more about Paketo, I discovered how [the oficial Python-related documentation suggests](https://paketo.io/docs/howto/python/#override-the-start-process-set-by-the-buildpack) overriding the start process.
The [Procfile buildpack](https://github.com/paketo-buildpacks/procfile) is included in the [Paketo Full Builder image](https://github.com/paketo-buildpacks/full-builder), which is [used by Epinio](https://docs.epinio.io/references/supported_applications#supported-buildpacks).
So, I'd just need to create a `Procfile` and adapt the command from `manifest.yml`.

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

With this approach, I was able to retrieve the logs in time, as the pod would simply complete its lifecycle after printing the message.
Using `epinio app logs` didn't yield any output, but `kubectl logs` (targeting the correct pod) did the trick and displayed "`hello world`".

Back to adapting from `manifest.yml`, I noticed `cf_run.sh` reads `VCAP_SERVICES` to create other environment variables required by `run.sh`.
This variable is [specific to CF](https://docs.cloudfoundry.org/devguide/deploy-apps/environment-variable.html#VCAP-SERVICES).

I started looking for ways to automatically retrieve the relevant URIs. Some official links like [this example repository](https://github.com/epinio/example-rails/tree/fc973eedf2697918f01cefe7206fa6840fdeee23) and [this tutorial section](https://docs.epinio.io/tutorials/custom_builder_go#create-and-bind-the-database) seem to suggest a manual approach (using `epinio service show` to get only the route).
[This official reference](https://docs.epinio.io/references/services) says the Helm chart used for the example doesn't write the hostname of the database in the generated secret because it wasn't created specifically for Epinio.

Following [this documentation](https://docs.epinio.io/howtos/create_custom_service), I attempted to create new a "`postgresql-custom`" service (based on `postgresql-dev`) with some changes:
- adding the value "`serviceBindings: true`" (see [L55](https://github.com/bitnami/charts/blob/3e6c4816902a5250fa97202590da88c65ffa2a94/bitnami/postgresql/templates/secrets.yaml#L55), [L1175](https://github.com/bitnami/charts/blob/3e6c4816902a5250fa97202590da88c65ffa2a94/bitnami/postgresql/values.yaml#L1175))
- adding the annotation "`application.epinio.io/catalog-service-secret-types: Opaque,servicebinding.io/postgresql`" (see [L70](https://github.com/bitnami/charts/blob/3e6c4816902a5250fa97202590da88c65ffa2a94/bitnami/postgresql/templates/secrets.yaml#L70))

I applied `service.yml` and followed [these instructions](https://docs.epinio.io/references/services), creating a "`sample`" app.
It didn't work, as `epinio configuration show` would still show only a single parameter called "`postgres-password`".
Double-checking with `epinio app exec sample` confirmed the absence of other secrets.

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

Some additional changes were made for testing. Commands in `Makefile` specially got quite messy and unsecure.
I'm not proud of it, but I take it as part of the learning process.

Nevertheless, the application within Epinio didn't crash anymore and `epinio app logs` showed a sensible error:
```
rmyapp-94e7d341f71ff6f43253f1c5e813057b22f91cda amqp.exceptions.AccessRefused:
	(0, 0): (403) ACCESS_REFUSED - Login was refused using authentication mechanism AMQPLAIN.
	For details see the broker logfile.
```

<hr>
<hr>

When starting this challenge, I had around 48 hours left with the notebook I was using to do it.
At this point, I wanted to deliver my partial results as I supposed my personal computer wouldn't handle a proper development environment.

Fortunately, I was given a chance to complete the challenge and my desktop - against all odds - didn't explode with a dual boot setup.
Coincidentally, Epinio released version 1.9.0 during this gap. It didn't affect any of my prior steps.

This is the machine used from this point onward: `Linux 5.19.0-50-generic #50-Ubuntu SMP PREEMPT_DYNAMIC Mon Jul 10 18:24:29 UTC 2023 x86_64 x86_64 x86_64 GNU/Linux`

<hr>
<hr>

Continuing the challenge, after some retries and checking `epinio app logs`, I noticed two important mistakes when I defined the URIs:
1. the username for RabbitMQ in this case is actually "`user`" (see [L134](https://github.com/bitnami/charts/blob/main/bitnami/rabbitmq/values.yaml#L134))
2. the username for PostgreSQL is "`postgres`", not "`postgresql`"
	- realized after getting the error "`psycopg2.OperationalError: FATAL:  password authentication failed for user "postgresql"`"

After also mofiying `test/nex-smoketest.sh` to use `curl -k`, the following code worked without problems:
```
epinio app manifest myapp temp.manifest
./test/nex-smoketest.sh "https://$(yq '.configuration.routes[0]' temp.manifest)"
rm -f temp.manifest
```

**SUCCESS! THE APP WAS WORKING!**

Now, I wanted to fix some things, specially to avoid exposing service passwords unnecessarily.

I decided to check again why the "`postgresql-custom`" service didn't work.
Well, turns out that value "`serviceBindings: true`" was wrong. The correct would be:
```
serviceBindings:
  enabled: true
```
So, I put this in `values.yml` and double-checked with `--dry-run` if that would be enough to create a second Secret:
```
helm install --create-namespace --namespace=pgsql-test --dry-run --generate-name oci://registry-1.docker.io/bitnamicharts/postgresql -f values.yml
```
Apparently, a new Secret resource with everything (username, password, host, etc.) would be created. But even after writing `merge.yml` and `create_pgsql_custom.sh`, it didn't work.
Binding an instance of this custom Service to an App didn't yield the desired Configuration and I couldn't even find the second Secret via `kubectl get secret -A`.
I eventually gave up on this "custom Service" idea and left these files just as references.

Going back to [that example repository](https://github.com/epinio/example-rails/tree/fc973eedf2697918f01cefe7206fa6840fdeee23), adapting some of its steps seemed like a good approach:
1. create the App, instead of pushing it right away (`epinio apps create`)
2. create the Service (`epinio service create`)
3. grab the Service host and port (`epinio service show | grep ...`)
4. bind Service and App (`epinio service bind`)
5. form the URI for the Service with all the relevant information, including a placeholder like "`%PASSWORD%`"
6. create a Configuration with the Service URI (`epinio configuration create myservice-config SVC_URI protocol://user:%PASS%@host:port/etc`)
7. finally push the App (`epinio push`)
	- immediately bind the Configuration (`-b myservice-config`)
	- make sure the app will have an environment variable like "`SVC_NAME`", so it can later access "`/configurations/$SVC_NAME/...`" easily

This would at least avoid exposing passwords. Steps 2-6 can be repeated when multiple services exist. Step 1 can actually come anywhere before step 4.

With such plan in mind, I decided to:
- remove the password-related section of `formURI.sh`
- modify `epinio_run.sh` to grab URIs and passwords directly from Configurations
- adapt `Makefile` accordingly
- delete `epinio.yml` (as I'd just manipulate everything via CLI)

After some attempts (with wrong variable names and other minor mistakes), I confirmed that using "`epinio push --env`" will overwrite the entire environment (instead of merging it).
More importantly, **this also applies to "`epinio push --bind`"**, which means that using "`epinio service bind ServiceA`" and then "`epinio push --bind ConfigB`" will cause **only "`ConfigB`"** to be bound.

As everything was fixed, the test started working again (check the `full-test.sh` file).
