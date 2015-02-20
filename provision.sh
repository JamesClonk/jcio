#!/bin/bash
set -e
set -u

# includes
source includes.sh

# error handling
trap "error \"Error!\"; exit" INT TERM EXIT

# read configuration
header "Read configuration from .env"
export $(cat .env | xargs)
SSH_FILENAME=$(eval "echo ${SSH_PUB_KEY_FILE}")
export SSH_PUB_KEY=$(cat ${SSH_FILENAME})
export SSH_PUB_KEY_FINGERPRINT=$(ssh-keygen -lf ${SSH_FILENAME} | awk '{print $2;}')
export MARS="mars.${JCIO_DOMAIN}"
export PHOBOS="phobos.${JCIO_DOMAIN}"
export DEIMOS="deimos.${JCIO_DOMAIN}"

# create certs for docker daemons and clients
./cert-gen.sh ${MARS}
./cert-gen.sh ${PHOBOS}
./cert-gen.sh ${DEIMOS}

# provision droplets
header "Provision DigitalOcean droplets"
echo "${MARS} ams3 512mb docker" > droplets_to_provision.dat
echo "${PHOBOS} nyc3 512mb docker" >> droplets_to_provision.dat
echo "${DEIMOS} ams3 512mb docker" >> droplets_to_provision.dat
go run droplets.go droplets_to_provision.dat

# wait for tcp
# header "Waiting for SSH"
# HOST_IP=$(cat ${MARS}.ip_address)
# until nc -zvw 1 ${HOST_IP} 22; do
# 	echo "."
# 	sleep 5
# done

# upload certs to docker hosts
# TODO: upload certs to docker hosts

# setup docker to use TLS
# TODO: setup docker to use TLS

# setup haproxy, etcd and shipyard on mars
# TODO: setup haproxy, etcd and shipyard on mars

# setup nginx, frontend and backend on phobos and deimos
# TODO: setup nginx, frontend and backend on phobos and deimos

# cleanup
header "It's cleanup time"
rm -vf droplets_to_provision.dat
rm -vf ${MARS}.ip_address
rm -vf ${PHOBOS}.ip_address
rm -vf ${DEIMOS}.ip_address
rm -vrf ${MARS}
rm -vrf ${PHOBOS}
rm -vrf ${DEIMOS}

echo ""
success "All done!"
echo ""

trap "exit" INT TERM EXIT
exit 0
