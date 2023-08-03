#!/bin/bash

# Abort if receiving less than 3 parameters
[ -z "$3" ] && exit 1
SERVICE_NAME=$1 # format: "myapp_rabbitmq"
ROUTE_MATCHER=$2 # format: "rabbitmq.myns.svc.cluster.local:5672"
TEMPLATE_URI=$3 # format: "amqp://username:%PASS%@%HOST%"

# Grab at most 1 line from "epinio service show" containing the matching string
SERVICE_ROUTE="$(epinio service show $SERVICE_NAME | grep -soP -m 1 "\S+${ROUTE_MATCHER}")"
# Abort if no service route is found
[ -z "$SERVICE_ROUTE" ] && exit 1

# Form and print the final URI
FINAL_URI="${TEMPLATE_URI/\%HOST\%/$SERVICE_ROUTE}"
echo $FINAL_URI
