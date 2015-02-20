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
export MARS_CERTS="${MARS}_certificates"
export PHOBOS_CERTS="${PHOBOS}_certificates"
export DEIMOS_CERTS="${DEIMOS}_certificates"

# create certs for docker daemons and clients
./cert-gen.sh ${MARS_CERTS}
./cert-gen.sh ${PHOBOS_CERTS}
./cert-gen.sh ${DEIMOS_CERTS}

# provision droplets
header "Provision DigitalOcean droplets"
echo "${MARS} ams3 512mb docker" > droplets_to_provision.dat
echo "${PHOBOS} nyc3 512mb docker" >> droplets_to_provision.dat
echo "${DEIMOS} ams3 512mb docker" >> droplets_to_provision.dat
go run droplets.go droplets_to_provision.dat

# wait for ssh
header "Waiting for SSH"
export MARS_IP=$(cat "${MARS}.ip_address")
export PHOBOS_IP=$(cat "${PHOBOS}.ip_address")
export DEIMOS_IP=$(cat "${DEIMOS}.ip_address")
IP_ADDRESSES=(${MARS_IP} ${PHOBOS_IP} ${DEIMOS_IP})
for ip in ${IP_ADDRESSES[@]}; do
    until nc -zvw 1 ${ip} 22; do
		echo "."
		sleep 3
	done
done

# upload certs to docker hosts
header "Upload certificates for docker"
# mars wants to know about all certs
scp -o StrictHostKeyChecking=no -r ${MARS_CERTS} root@${MARS_IP}:.
scp -o StrictHostKeyChecking=no -r ${PHOBOS_CERTS} root@${MARS_IP}:.
scp -o StrictHostKeyChecking=no -r ${DEIMOS_CERTS} root@${MARS_IP}:.
# phobos and deimos only need theirs
scp -o StrictHostKeyChecking=no -r ${PHOBOS_CERTS} root@${PHOBOS_IP}:.
scp -o StrictHostKeyChecking=no -r ${DEIMOS_CERTS} root@${DEIMOS_IP}:.

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
rm -vrf ${MARS_CERTS}
rm -vrf ${PHOBOS_CERTS}
rm -vrf ${DEIMOS_CERTS}

echo ""
success "All done!"
echo ""

trap "exit" INT TERM EXIT
exit 0
