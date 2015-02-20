# jcio-build

This builds the complete JCIO server and application setup on DigitalOcean
- :globe_with_meridians: mars.<domain>.<tld>
- :first_quarter_moon: phobos.<domain>.<tld>
- :last_quarter_moon: deimos.<domain>.<tld>

### Installation

Requirements:

* `bash`, `tput` / `ncurses`, `curl`, `git`, `openssl`, `openssh`, `go`

### Usage

Write the following configuration variables into a file named `.env`:

```sh
	DIGITALOCEAN_TOKEN=my_digitalocean_api_v2_token
	SSH_PUB_KEY_FILE=~/.ssh/id_rsa.pub
	JCIO_DOMAIN=my_domain.tld
	JCIO_USERNAME=my_username
	JCIO_PASSWORD=my_password
```

Run `provision.sh`

```sh
 $ ./provision.sh
```

#### Design notes

- mars is where haproxy, etcd-cluster and shipyard are running

- phobos and deimos themselves register to mars' etcd-cluster
- phobos and deimos apps/docker containers also register to mars' etcd cluster
- phobos and deimos app architecture: ->nginx->frontend->backend (what about status and ninja? :question:)

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
