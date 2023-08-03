#!/bin/bash +e

# --------------------------------------------------------
# Check and assign parameters
# --------------------------------------------------------

if [ -z "$2" ]; then
    echo "Usage: $0 <NAMESPACE> <APP_NAME>"
    exit 1
fi
ID_NAMESPACE=$1
ID_APPLICATION=$2

# --------------------------------------------------------
# Ask about cluster creation with k3d
# --------------------------------------------------------

echo
echo "Do you wish to create a brand new local cluster with k3d?"
echo "(this will fail if you already have a k3d cluster called 'epinio')"
echo
read -p "Type 'YES' to create, anything else to skip: " answer
[ "${answer}" = "YES" ] && USE_K3D="k3d"
echo

# --------------------------------------------------------
# Check installed programs
# --------------------------------------------------------

NOT_INSTALLED=
PROGS_TO_CHECK="$USE_K3D kubectl epinio helm jq yq make curl"
for CHECK_PROG in $PROGS_TO_CHECK; do
    which $CHECK_PROG >/dev/null 2>&1 || NOT_INSTALLED="$NOT_INSTALLED $CHECK_PROG"
done
if [ -n "$NOT_INSTALLED" ]; then
    echo "[ERROR] These required programs don't seem to be installed:$NOT_INSTALLED"
    exit 1
fi

# --------------------------------------------------------
# Check files
# --------------------------------------------------------

if ! make -n EPINIO_NS=X EPINIO_APP=Y epinio_deploy >/dev/null 2>&1; then
    echo "[ERROR] Makefile doesn't seem to have the required 'epinio_deploy' target"
    exit 1
fi

[ ! -r Procfile      ] && echo "Required file 'Procfile' doesn't exist or is not accessible"      && exit 1
[ ! -x formURI.sh    ] && echo "Required file 'formURI.sh' doesn't exist or is not executable"    && exit 1
[ ! -x epinio_run.sh ] && echo "Required file 'epinio_run.sh' doesn't exist or is not executable" && exit 1

! grep -sq 'curl -k' ./test/nex-smoketest.sh && "Make sure file './test/nex-smoketest.sh' uses 'curl -k' to avoid certificate-related problems" && exit 1

# --------------------------------------------------------
# Use k3d to create a cluster called 'epinio'
# --------------------------------------------------------

if [ -n "$USE_K3D" ] && k3d cluster create epinio; then

    echo
    echo "@> Waiting up to 60 seconds to get the Ingress IP address..."
    SECONDS=0
    while : ; do
        INGRESS_IP_ADDR=$(kubectl get svc -n kube-system traefik -o jsonpath={@.status.loadBalancer.ingress} 2>/dev/null | jq -r .[0].ip)
        echo $INGRESS_IP_ADDR | grep -sqP '\d+(\.\d+){3}' && break
        [ $SECONDS -gt 60 ] && echo 'Aborting after 60s waiting for IP' && exit 1
    done
    echo "@> Detected IP Address: $INGRESS_IP_ADDR"
    echo "@> Sleeping 45 more seconds..."
    sleep 45
    echo

    echo
    echo "@> Installing cert-manager via Helm"
    echo

    helm repo update

    kubectl create namespace cert-manager
    helm repo add jetstack https://charts.jetstack.io
    helm install cert-manager --namespace cert-manager jetstack/cert-manager \
        --set installCRDs=true \
        --set extraArgs={--enable-certificate-owner-ref=true}

    echo
    echo "@> Installing epinio via Helm with config:"
    echo "@>	--set global.domain=$INGRESS_IP_ADDR.sslip.io"
    echo "@>	--set global.dex.enabled=false" # Not using OIDC - https://docs.epinio.io/references/authentication_oidc
    echo

    helm repo add epinio https://epinio.github.io/helm-charts
    helm install epinio -n epinio --create-namespace epinio/epinio \
    	--set global.domain=$INGRESS_IP_ADDR.sslip.io \
    	--set global.dex.enabled=false
    echo
    echo "@> Reminder: no auth was configured, see: https://docs.epinio.io/references/authorization"

    echo "@> WARNING: Logging in with default ADMIN credentials !!!"
    echo
    sleep 10
    epinio login https://epinio.$INGRESS_IP_ADDR.sslip.io --trust-ca -u admin -p password
    sleep 5
fi

# --------------------------------------------------------
# Check if we are now connected to an Epinio instance
# --------------------------------------------------------

echo "Executing 'epinio info' ..."
! epinio info && echo "[ERROR] Not logged into any Epinio instance" && exit 1
echo

# --------------------------------------------------------
# Deploy the application
# --------------------------------------------------------

EPINIO_NS=${ID_NAMESPACE} EPINIO_APP=${ID_APPLICATION} make epinio_deploy
echo; echo; echo

# --------------------------------------------------------
# Check logs, just in case
# --------------------------------------------------------

epinio app logs ${ID_APPLICATION}
echo; echo; echo

# --------------------------------------------------------
# Smoke test
# --------------------------------------------------------

TEMP_FILE=$(mktemp)
epinio app manifest ${ID_APPLICATION} ${TEMP_FILE}
./test/nex-smoketest.sh "https://$(yq '.configuration.routes[0]' ${TEMP_FILE})"
rm -f ${TEMP_FILE}
echo; echo; echo

# --------------------------------------------------------

echo '@> -~=********=~- <@'
echo '@> -~=* DONE *=~- <@'
echo '@> -~=********=~- <@'
echo
