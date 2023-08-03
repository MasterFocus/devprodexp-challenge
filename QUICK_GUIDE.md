# Quick Guide

To quickly grab a project like the original one (see branch "`master`") and make it compatible with Epinio instead of Cloud Foundry, follow these steps.

**Use branch "`challenge`" as reference for any files mentioned here that you may need to copy and/or modify:**
- provide a **`Makefile`** that has all the relevant "`epinio_*`" targets
- the project must have a **`Procfile`** that calls the **`epinio_run.sh`** executable accordingly
- file **`./test/nex-smoketest.sh`** must be executable and must be modified to use "`curl -k`" for its requests
- for the next step, either be logged with Epinio CLI into an existing Epinio instance, or have `k3d` installed
- execute **`QUICK_DEPLOY.sh`** (the script will check for the necessary files and programs before proceeding)

When using "`./QUICK_DEPLOY.sh NAMESPACE APP_NAME`" for the first time, it is suggested to specify a new "_NAMESPACE_" just to see if it works without conflicting with existing resources.

More detailed instructions can be found in the `NOTES.md` file.
