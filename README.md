# jcio-build



### Installation

Requirements:

* `curl`, `git`, `openssl`, `openssh`

### Usage

Write the following configuration variables into a file `.env`:

```sh
	DIGITALOCEAN_TOKEN=bca87c487a8b7cab8a7bc8b7287b48bac82748a7c2487
	SSH_PUB_KEY_FILE=~/.ssh/id_rsa.pub
	JCIO_USERNAME=my_username
	JCIO_PASSWORD=my_password
```

Run `build.sh`

```sh
 $ ./build.sh
```
