#!/bin/bash

#------------------------------------------------------------------
## Dry-run command to check the pgsql chart
##helm install --create-namespace --namespace=pgsql-test --dry-run --generate-name oci://registry-1.docker.io/bitnamicharts/postgresql -f values.yml
#------------------------------------------------------------------
## Previous experiments with yq
##yq -i eval '.metadata.annotations."application.epinio.io/catalog-service-secret-types" = "Opaque,servicebinding.io/postgresql"' service.yml
##yq -i eval '.spec.name = "postgresql-custom"' service.yml
#------------------------------------------------------------------



kubectl delete services.application.epinio.io -n epinio postgresql-custom 2>/dev/null || :

sleep 3

# Using two separate "yq" commands to merge:
# https://mikefarah.gitbook.io/yq/operators/reduce#merge-all-yaml-files-together
# https://stackoverflow.com/q/75751284

kubectl get services.application.epinio.io -n epinio postgresql-dev -o yaml > pgsql.yml && \
    yq -i eval-all '. as $item ireduce ({}; . * $item )' pgsql.yml merge.yml && \
    yq -i eval-all '.spec.values = load_str("values.yml") + "\n" + .spec.values' pgsql.yml && \
    kubectl apply -f pgsql.yml || :

rm -f pgsql.yml

sleep 3

