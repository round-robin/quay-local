#!/bin/bash

if [ ! $(whoami) = "root" ]; then
    echo "This script must be run as root"
    exit 1
fi

QUAY=$(pwd)
CONTAINER_TOOL=docker

if [ ! -d "$QUAY/postgres" ]; then
  mkdir postgres
fi

setfacl -m u:26:-wx $QUAY/postgres
setfacl -m u:1001:-wx $QUAY/storage

$CONTAINER_TOOL run -d --rm --name quaydb -e POSTGRES_USER=quay -e POSTGRES_PASSWORD=quay -e POSTGRES_DB=quay -p 5432:5432 -v $QUAY/postgres:/var/lib/postgresql/data:Z postgres:10.12
sleep 15
$CONTAINER_TOOL exec -it quaydb /bin/bash -c 'echo "CREATE EXTENSION IF NOT EXISTS pg_trgm" | psql -d quay -U quay'
$CONTAINER_TOOL run -d --rm --name quay-redis -p 6379:6397 redis:5.0.7 --requirepass strongpassword
#$CONTAINER_TOOL run -it --rm --name quay-config -p 8081:8080 quay.io/projectquay/quay config secret
# Go to the web browser http://localhost:8081 and create a configuration of the service
$CONTAINER_TOOL run --rm -d -p 8081:8080 --name quay --privileged=true -v $QUAY/config:/conf/stack:Z -v $QUAY/storage:/datastorage:Z quay.io/projectquay/quay:latest
