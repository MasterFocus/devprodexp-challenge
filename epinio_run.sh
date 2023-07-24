#!/bin/bash

# create dbname for postgres

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