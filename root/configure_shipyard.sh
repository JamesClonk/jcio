#!/bin/bash
set -e
set -u

# usage check
if [ $# -ne 2 ]; then
	echo "usage: $0 <USERNAME> <PASSWORD>"
	exit 1
fi

export USERNAME=$1
export PASSWORD=$2

# wait for shipyard to be ready
sleep 5
until nc -zvw 1 localhost 8080; do
	echo "."
	sleep 5
done

# get shipyard api access token
echo $(curl -X POST -H 'Content-Type: application/json' -d '{"username":"admin","password":"shipyard"}' http://localhost:8080/auth/login) > .shipyard_response
cat .shipyard_response | awk -F'"' '{print $4;}' > .shipyard_token
rm -f .shipyard_response
chmod 400 .shipyard_token

# TODO: add phobos and deimos as engines to shipyard (use API over HTTPS!) (http://shipyard-project.com/docs/api/)

# create new shipyard account and delete old admin account
curl -X POST -H "X-Access-Token: admin:$(cat .shipyard_token)" -H 'Content-Type: application/json' -d "{\"username\":\"${USERNAME}\",\"password\":\"${PASSWORD}\",\"role\":{\"name\": \"admin\"}}" http://localhost:8080/api/accounts
curl -X DELETE -H "X-Access-Token: admin:$(cat .shipyard_token)" -H 'Content-Type: application/json' -d '{"username":"admin"}' http://localhost:8080/api/accounts

exit 0
