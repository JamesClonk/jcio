#!/bin/bash

# read configuration
echo "Read configuration from .env"
export $(cat .env | xargs)
SSH_FILENAME=$(eval "echo ${SSH_PUB_KEY_FILE}")
export SSH_PUB_KEY=$(cat ${SSH_FILENAME})
export SSH_PUB_KEY_FINGERPRINT=$(ssh-keygen -lf ${SSH_FILENAME} | awk '{print $2;}')
echo ""

# create certs
./cert-gen.sh phobos.jamesclonk.com
./cert-gen.sh deimos.jamesclonk.com

# provision digitalocean droplets
echo "Provision DigitalOcean droplets"
go run droplets.go phobos.jamesclonk.com nyc3 512mb docker
#go run droplets.go deimos.jamesclonk.com ams2 512mb docker
echo ""
