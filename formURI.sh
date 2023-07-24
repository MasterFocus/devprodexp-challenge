#!/bin/bash

# Abort if receiving less than 5 parameters
[ -z "$5" ] && exit 1
MANIFEST_FILE=$1 # file path
SERVICE_NAME=$2 # format: "myapp_rabbitmq"
SERVICE_MATCHER=$3 # format: "rabbitmq" (matches end of string)
ROUTE_MATCHER=$4 # format: "rabbitmq.myns.svc.cluster.local:5672"
TEMPLATE_URI=$5 # format: "amqp://username:%PASS%@%HOST%"

# Grab a configuration if the end of its name matches the SERVICE_MATCHER string
EPINIO_CONF=$(yq '.configuration.configurations' $MANIFEST_FILE 2>/dev/null | colrm 1 2 | grep -sP "$SERVICE_MATCHER"'$')
# Abort if no configuration is found
[ -z "$EPINIO_CONF" ] && exit 1

# Grab relevant lines from "epinio configuration show", find at most 1 line contaning "password" and store only its value,
SERVICE_PASSWORD="$(epinio configuration show $EPINIO_CONF 2>/dev/null | grep -sP '^\|' | grep -s -m 1 password | awk '{print $4}' 2>/dev/null)"
# Abort if no password is found
[ -z "$SERVICE_PASSWORD" ] && exit 1

# Grab at most 1 line from "epinio service show" containing the matching string
SERVICE_ROUTE="$(epinio service show $SERVICE_NAME | grep -soP -m 1 "\S+${ROUTE_MATCHER}")"
# Abort if no service route is found
[ -z "$SERVICE_ROUTE" ] && exit 1

# Form and print the final URI
FINAL_URI="${TEMPLATE_URI/\%PASS\%/$SERVICE_PASSWORD}"
FINAL_URI="${FINAL_URI/\%HOST\%/$SERVICE_ROUTE}"
echo $FINAL_URI
