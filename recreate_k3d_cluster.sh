#!/bin/bash

echo
echo "@> Deleting all k3d clusters, wiping docker and kubeconfigs"
echo

k3d cluster delete --all
sleep 2

docker context use default
docker stop $(docker ps -a -q) 2>/dev/null || :
docker rmi $(docker images -a -q) 2>/dev/null || :
docker system prune -af || :
docker volume prune -f || :

rm -rf ~/.kube

echo
echo "@> Creating new k3d cluster called 'epinio'"
echo

k3d cluster create epinio

echo
echo "@> Waiting up to 60 seconds to get the Ingress IP address..."
SECONDS=0 # Reset bash's built-in variable before the loop
while : ; do
	# Command from https://docs.epinio.io/installation/dns_setup#ingress-controller-ip-address
	INGRESS_IP_ADDR=$(kubectl get svc -n kube-system traefik -o jsonpath={@.status.loadBalancer.ingress} 2>/dev/null | jq -r .[0].ip)
	echo $INGRESS_IP_ADDR | grep -sqP '\d+(\.\d+){3}' && break
	[ $SECONDS -gt 60 ] && echo 'Aborting after 60s waiting for IP' && exit 1
done
echo "@> Detected IP Address: $INGRESS_IP_ADDR"
# The cluster is still fresh, so trying the next installation steps can yield this error:
# "[...] couldn't get resource list for metrics.k8s.io/v1beta1: the server is currently unable to handle the request"
# To keep this error out of the console, I can simply wait a bit more.
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
echo "@>	--set global.dex.enabled=false" # I won't need https://docs.epinio.io/references/authentication_oidc
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
epinio info
echo

echo
echo '@> -~=* DONE *=~- <@'
echo
