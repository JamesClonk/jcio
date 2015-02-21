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
# TODO: uncomment line below!
#go run droplets.go droplets_to_provision.dat

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

# update /etc/hosts
# TODO: add entries to /etc/hosts.. (but only if they dont exist there yet)

# update dnsimple entries
# TODO: modify DNSimple..

# update machines
header "Update virtual machines"
parallel -v --linebuffer ssh root@{1} "apt-get -q -y update" ::: ${MARS_IP} ${PHOBOS_IP} ${DEIMOS_IP}
parallel -v --linebuffer ssh root@{1} "apt-get -q -y upgrade" ::: ${MARS_IP} ${PHOBOS_IP} ${DEIMOS_IP}

# firewall setup
header "Setup firewall (ufw)"
parallel -v --linebuffer scp -r etc/default/ufw root@{1}:/etc/default/. ::: ${MARS_IP} ${PHOBOS_IP} ${DEIMOS_IP}
# ~~TODO~~: ufw reload (not needed, ufw is not active by default on DO docker image)

# upload certs to docker hosts
header "Upload certificates"
# mars wants to know about all certs
parallel -v --linebuffer scp -o StrictHostKeyChecking=no -r {1} root@${MARS_IP}:. ::: ${MARS_CERTS} ${PHOBOS_CERTS} ${DEIMOS_CERTS}
# phobos and deimos only need theirs
scp -r ${PHOBOS_CERTS} root@${PHOBOS_IP}:.
scp -r ${DEIMOS_CERTS} root@${DEIMOS_IP}:.

# setup docker
header "Setup docker"
# shutdown/kill all containers
parallel -v --linebuffer ssh root@{1} 'docker ps -a -q | xargs docker kill' ::: ${MARS_IP} ${PHOBOS_IP} ${DEIMOS_IP}
parallel -v --linebuffer ssh root@{1} 'docker ps -a -q | xargs docker rm' ::: ${MARS_IP} ${PHOBOS_IP} ${DEIMOS_IP}
# upload docker configuration to use TLS
parallel -v --linebuffer scp -r etc/default/docker root@{1}:/etc/default/. ::: ${MARS_IP} ${PHOBOS_IP} ${DEIMOS_IP}
ssh root@${MARS_IP} "cp -R ${MARS_CERTS} .docker"
ssh root@${PHOBOS_IP} "cp -R ${PHOBOS_CERTS} .docker"
ssh root@${DEIMOS_IP} "cp -R ${DEIMOS_CERTS} .docker"
# restart docker service
ssh root@${MARS_IP} "service docker restart"
ssh root@${PHOBOS_IP} "service docker restart"
ssh root@${DEIMOS_IP} "service docker restart"

# setup nginx on mars
header "Install nginx"
ssh root@${MARS_IP} "git clone https://github.com/JamesClonk/jcio-nginx-master"
ssh root@${MARS_IP} "cd jcio-nginx-master; ./build.sh ${MARS}"
ssh root@${MARS_IP} "docker run -d -p 80:80 -p 443:443 --name nginx-mars jcio-nginx-master"
# TODO: set nginx to HTTPS reverse proxy, permanent redirect of http to HTTPS

# setup shipyard on mars
header "Install shipyard"
ssh root@${MARS_IP} "docker run --rm -v /var/run/docker.sock:/var/run/docker.sock shipyard/deploy start"
# TODO: make sure nginx is setup as reverse proxy for HTTPS in front of shipyard
# TODO: add new admin account to shipyard (use API over HTTPS!) (http://shipyard-project.com/docs/api/)
# TODO: remove old admin account from shipyard (use API over HTTPS!) (http://shipyard-project.com/docs/api/)
# TODO: add phobos and deimos as engines to shipyard (use API over HTTPS!) (http://shipyard-project.com/docs/api/)
# TODO: add cpu- and memory-limit to "docker run" calls for containers.. for example 0.2 cpu, 64m for nginx?
# TODO: give containers meaningful names when making "docker run" calls.. (--name)

# setup haproxy and etcd on mars
# TODO: setup haproxy and etcd on mars

# setup nginx, frontend and backend on phobos and deimos
# TODO: setup nginx, frontend and backend on phobos and deimos

# cleanup
header "It's cleanup time"
rm -vf droplets_to_provision.dat
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
