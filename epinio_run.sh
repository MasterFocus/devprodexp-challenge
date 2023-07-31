#!/bin/bash

TEMPLATE_URI="$(cat /configurations/$POSTGRESQL_CFG/POSTGRES_URI)"
export POSTGRES_URI="${TEMPLATE_URI/\%PASS\%/$(cat /configurations/$POSTGRESQL_SVC/postgres-password)}"

TEMPLATE_URI="$(cat /configurations/$RABBITMQ_CFG/AMQP_URI)"
export AMQP_URI="${TEMPLATE_URI/\%PASS\%/$(cat /configurations/$RABBITMQ_SVC/rabbitmq-password)}"

TEMPLATE_URI="$(cat /configurations/$REDIS_CFG/REDIS_URI)"
export REDIS_URI="${TEMPLATE_URI/\%PASS\%/$(cat /configurations/$REDIS_SVC/redis-password)}"

python -c """
import psycopg2 as db
from urllib.parse import urlparse
result = urlparse('${POSTGRES_URI}')
username = result.username
password = result.password
database = result.path[1:]
hostname = result.hostname
port = result.port
con=db.connect(dbname='postgres',host=hostname,user=username,password=password)
con.autocommit=True;con.cursor().execute('CREATE DATABASE devex')
"""

./run.sh $@ 