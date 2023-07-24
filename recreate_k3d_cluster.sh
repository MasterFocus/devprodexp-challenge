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

