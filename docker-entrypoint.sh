#!/bin/sh

set -e

# wait for mongodb to be up

host=$(env | grep MONGODB_PORT | grep _TCP_ADDR | cut -d = -f 2)
port=$(env | grep MONGODB_PORT | grep _TCP_PORT | cut -d = -f 2)

MAX_TRIES=180

try=0

while ! nc -z $host $port; do
  try=`expr $try + 1`
  if [ "$try" -gt $MAX_TRIES ]; then
    echo "$(date) - ${host}:${port} not reachable in ${MAX_TRIES} tries, giving up"
    exit 1
  fi
  echo -n "\r$(date) - try ${try} - waiting for ${host}:${port}..."
  sleep 1
done

exec "$@"
