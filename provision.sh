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


# create certs for docker hosts
./cert-gen.sh ${MARS}
./cert-gen.sh ${PHOBOS}
./cert-gen.sh ${DEIMOS}


# provision droplets
header "Provision DigitalOcean droplets"
echo "${MARS} ams3 512mb docker" > droplets_to_provision.dat
echo "${PHOBOS} nyc3 512mb docker" >> droplets_to_provision.dat
echo "${DEIMOS} ams3 512mb docker" >> droplets_to_provision.dat
./modules/droplets/droplets droplets_to_provision.dat


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


# clone this repo to all hosts
header "Clone jcio repository"
parallel -v --linebuffer ssh root@{1} '"rm -rf jcio; git clone https://github.com/JamesClonk/jcio"' ::: ${MARS_IP} ${PHOBOS_IP} ${DEIMOS_IP}


# update /etc/hosts
# TODO: add entries to /etc/hosts.. (but only if they dont exist there yet)


# update dnsimple entries
# TODO: modify DNSimple..


# update machines
header "Update virtual machines"
# TODO: uncomment the lines below
#parallel -v --linebuffer ssh root@{1} "apt-get -q -y update" ::: ${MARS_IP} ${PHOBOS_IP} ${DEIMOS_IP}
#parallel -v --linebuffer ssh root@{1} "apt-get -q -y upgrade" ::: ${MARS_IP} ${PHOBOS_IP} ${DEIMOS_IP}
#parallel -v --linebuffer ssh root@{1} "apt-get -q -y install curl wget golang" ::: ${MARS_IP} ${PHOBOS_IP} ${DEIMOS_IP}


# firewall setup
header "Setup firewall (ufw)"
parallel -v --linebuffer scp -r etc/default/ufw root@{1}:/etc/default/. ::: ${MARS_IP} ${PHOBOS_IP} ${DEIMOS_IP}
# ~~TODO~~: ufw reload (not needed, ufw is not active by default on DO docker image)


# upload certs to docker hosts
header "Upload certificates"
# mars wants to know about all certs
parallel -v --linebuffer scp -o StrictHostKeyChecking=no -r {1} root@${MARS_IP}:. ::: ${MARS_CERTS} ${PHOBOS_CERTS} ${DEIMOS_CERTS}
# phobos and deimos only need theirs
parallel -v --xapply --linebuffer scp -r {1} root@{2}:. ::: ${PHOBOS_CERTS} ${DEIMOS_CERTS} ::: ${PHOBOS_IP} ${DEIMOS_IP}


# setup docker
header "Setup docker"
# shutdown/kill all containers
parallel -v --linebuffer ssh root@{1} 'docker run ubuntu /bin/echo "Docker ready!"' ::: ${MARS_IP} ${PHOBOS_IP} ${DEIMOS_IP}
parallel -v --linebuffer ssh root@{1} '"docker ps -a -q | xargs docker kill"' ::: ${MARS_IP} ${PHOBOS_IP} ${DEIMOS_IP}
parallel -v --linebuffer ssh root@{1} '"docker ps -a -q | xargs docker rm"' ::: ${MARS_IP} ${PHOBOS_IP} ${DEIMOS_IP}
# upload docker configuration to use TLS
parallel -v --linebuffer scp -r etc/default/docker root@{1}:/etc/default/. ::: ${MARS_IP} ${PHOBOS_IP} ${DEIMOS_IP}
parallel -v --xapply --linebuffer ssh root@{1} '"rm -rf .docker; cp -R {2} .docker"' ::: ${MARS_IP} ${PHOBOS_IP} ${DEIMOS_IP} ::: ${MARS_CERTS} ${PHOBOS_CERTS} ${DEIMOS_CERTS}
# restart docker service
parallel -v --linebuffer ssh root@{1} "service docker restart" ::: ${MARS_IP} ${PHOBOS_IP} ${DEIMOS_IP}


# setup shipyard on mars
header "Install shipyard"
ssh root@${MARS_IP} "docker run --rm -v /var/run/docker.sock:/var/run/docker.sock shipyard/deploy start"
# configure shipyard (accounts and engines)
export SHIPYARD_CONFIG_FILE=shipyard.conf
echo "username=${JCIO_USERNAME}" > modules/shipyard/${SHIPYARD_CONFIG_FILE}
echo "password=${JCIO_PASSWORD}" >> modules/shipyard/${SHIPYARD_CONFIG_FILE}
echo "engines=${PHOBOS};${DEIMOS}" >> modules/shipyard/${SHIPYARD_CONFIG_FILE}
scp -r modules/shipyard/${SHIPYARD_CONFIG_FILE} root@${MARS_IP}:jcio/modules/shipyard/.
ssh root@${MARS_IP} "cd jcio/modules/shipyard; ./configure_shipyard.sh ${SHIPYARD_CONFIG_FILE}"


# setup haproxy and etcd on mars
# TODO: setup haproxy and etcd on mars


# setup nginx, frontend and backend on phobos and deimos
# TODO: setup frontend and backend on phobos and deimos
header "Install nginx on Phobos and Deimos"
parallel -v --linebuffer ssh root@{1} '"rm -rf jcio-nginx-slave; git clone https://github.com/JamesClonk/jcio-nginx-slave"' ::: ${PHOBOS_IP} ${DEIMOS_IP}
parallel -v --xapply --linebuffer ssh root@{1} '"cd jcio-nginx-slave; ./build.sh {2}"' ::: ${PHOBOS_IP} ${DEIMOS_IP} ::: ${PHOBOS} ${DEIMOS}
parallel -v --xapply --linebuffer ssh root@{1} '"docker run -d -p 80:80 -p 443:443 --link frontend:frontend --link backend:backend --link rqlite:rqlite -c 512 -m 64m --name nginx-{2} jcio-nginx-slave"' ::: ${PHOBOS_IP} ${DEIMOS_IP} ::: ${PHOBOS} ${DEIMOS}


# setup nginx on mars (nginx must be last to run because it needs to link to other containers for reverse proxying)
header "Install nginx on Mars"
ssh root@${MARS_IP} "rm -rf jcio-nginx-master; git clone https://github.com/JamesClonk/jcio-nginx-master"
ssh root@${MARS_IP} "cd jcio-nginx-master; ./build.sh ${MARS}"
ssh root@${MARS_IP} "docker run -d -p 80:80 -p 443:443 --link shipyard:shipyard -c 512 -m 64m --name nginx-mars jcio-nginx-master"


# cleanup
header "It's cleanup time"
rm -vf droplets_to_provision.dat
rm -vf modules/shipyard/${SHIPYARD_CONFIG_FILE}
# TODO: uncomment lines below!
#rm -vf ${MARS}.ip_address
#rm -vf ${PHOBOS}.ip_address
#rm -vf ${DEIMOS}.ip_address
rm -vrf ${MARS_CERTS}
rm -vrf ${PHOBOS_CERTS}
rm -vrf ${DEIMOS_CERTS}


echo ""
success "All done!"
echo ""

trap "exit" INT TERM EXIT
exit 0
