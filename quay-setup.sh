#!/bin/bash

if [ ! $(whoami) = "root" ]; then
    echo "This script must be run as root"
    exit 1
fi

#Global variables

QUAY=$(pwd)
CONTAINER_TOOL=docker

clean() {
  $CONTAINER_TOOL rm -f quaydb quay-redis quay
}

configure() {
  
  echo -e "HOW TO USE THE CONFIG TOOL:"
  echo -e "Go to the web browser URL http://localhost:8081 and create a configuration of the registry.\nPress Ctrl+C to shut down the configurator when you are ready.\n"
  echo "Username: quayconfig"
  echo -e "Password: secret\n"
  $CONTAINER_TOOL run -it --rm --name quay-config -p 8081:8080 quay.io/projectquay/quay config secret 
}
  
if [ "$1" = "clean" ]; then
  clean
  exit
fi

if [ "$1" = "configure" ]; then
  configure
  exit
fi

# Deployment: directory layout and permissions

if [ ! -d "$QUAY/postgres" ]; then
  mkdir postgres
fi

if [ ! -d "$QUAY/storage" ]; then
  mkdir storage
fi

setfacl -m u:26:-wx $QUAY/postgres
setfacl -m u:1001:-wx $QUAY/storage

# Deployment: the required containers

$CONTAINER_TOOL run -d --rm --name quaydb -e POSTGRES_USER=quay -e POSTGRES_PASSWORD=quay -e POSTGRES_DB=quay -p 5432:5432 -v $QUAY/postgres:/var/lib/postgresql/data:Z docker.io/library/postgres:10.12

IP=$($CONTAINER_TOOL inspect -f "{{ .NetworkSettings.IPAddress }}" quaydb)
echo "DB IP => $IP"

sleep 15

$CONTAINER_TOOL exec -it quaydb /bin/bash -c 'echo "CREATE EXTENSION IF NOT EXISTS pg_trgm" | psql -d quay -U quay'
$CONTAINER_TOOL run -d --rm --name quay-redis -p 6379:6397 docker.io/library/redis:5.0.7 --requirepass strongpassword
IP=$($CONTAINER_TOOL inspect -f "{{ .NetworkSettings.IPAddress }}" quay-redis)
echo "Redis IP => $IP"

$CONTAINER_TOOL run --rm -d -p 8081:8080 --name quay --privileged=true -v $QUAY/config:/conf/stack:Z -v $QUAY/storage:/datastorage:Z quay.io/projectquay/quay:latest
