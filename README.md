# jcio

This builds the complete JCIO server and application setup on DigitalOcean
- :globe_with_meridians: mars.<domain>.<tld>
- :last_quarter_moon: phobos.<domain>.<tld>
- :first_quarter_moon: deimos.<domain>.<tld>

### Installation

Requirements:

* `bash`, `tput` / `ncurses`, `curl`, `nc`, `parallel`, `git`, `openssl`, `openssh`, `go`

### Usage

Write the following configuration variables into a file named `.env`:

```sh
	DIGITALOCEAN_TOKEN=my_digitalocean_api_v2_token
	DNSIMPLE_DOMAIN_TOKEN=my_dnsimple_domain_token
	SSH_PUB_KEY_FILE=~/.ssh/id_rsa.pub
	JCIO_DOMAIN=my_domain.tld
	JCIO_USERNAME=my_username
	JCIO_PASSWORD=my_password
	WEBSITE_PRIVATE_REPOSITORY_URL=git@123.456.789.0:/git/website.git
	PRIVATE_REPOSITORY_FRONTEND_FOLDER=frontend
	PRIVATE_REPOSITORY_BACKEND_FOLDER=backend
```

Run `provision.sh`

```sh
 $ ./provision.sh
```

#### Overview

![Overview](https://github.com/JamesClonk/jcio/raw/master/jcio.png "OVerview")

#### Design notes

- mars is where haproxy, etcd-cluster and shipyard are running
- use rancher instead of shipyard? :question:

- phobos and deimos themselves register to mars' etcd-cluster
- phobos and deimos apps/docker containers also register to mars' etcd cluster
- phobos and deimos app architecture: ->nginx->frontend->backend->rqlite (what about status and ninja? :question:)
- use docker-swarm for managing phobos-deimos together? :question:

- mars' haproxy reads from etcd-cluster to know how/where to route/proxy to
- mars' haproxy load balances to phobos and deimos nginx container
- mars' shipyard reads from etcd-cluster to know about phobos and deimos docker engines

##### Useful reads :warning:

- http://adetante.github.io/articles/service-discovery-with-docker-1/
- http://adetante.github.io/articles/service-discovery-with-docker-2/
- http://adetante.github.io/articles/service-discovery-haproxy/
- https://github.com/adetante/dockreg
- https://discovery.etcd.io/
- http://jasonwilder.com/blog/2014/07/15/docker-service-discovery/
- https://github.com/jwilder/docker-discover
