#!/bin/bash +e

ID_NAMESPACE=whatever-ns
ID_APPLICATION=whatever-app

#echo "YES" | ./recreate_k3d_cluster.sh
echo "y" | EPINIO_NS=${ID_NAMESPACE} make epinio_purge
echo; echo; echo

EPINIO_NS=${ID_NAMESPACE} EPINIO_APP=${ID_APPLICATION} make epinio_deploy
echo; echo; echo

epinio app logs ${ID_APPLICATION}
echo; echo; echo

TEMP_FILE=$(mktemp)
epinio app manifest ${ID_APPLICATION} ${TEMP_FILE}
./test/nex-smoketest.sh "https://$(yq '.configuration.routes[0]' ${TEMP_FILE})"
rm -f ${TEMP_FILE}
echo; echo; echo

echo "y" | EPINIO_NS=${ID_NAMESPACE} make epinio_purge
