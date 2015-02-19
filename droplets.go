package main

import (
	"log"
	"os"

	"code.google.com/p/goauth2/oauth"
	"github.com/digitalocean/godo"
)

var client *godo.Client

func main() {
	if len(os.Args) != 5 {
		log.Fatal("usage: droplets.go <FQDN> <region> <size> <image>")
	}
	name := os.Args[1]
	region := os.Args[2]
	size := os.Args[3]
	image := os.Args[4]

	connect()
	key := setupSSHKey()
	droplet := setupDroplet(name, region, size, image, key)
	log.Printf("Droplet: %+v\n", droplet)
}

func connect() {
	token := os.Getenv("DIGITALOCEAN_TOKEN")
	if token == "" {
		log.Fatal("DIGITALOCEAN_TOKEN is not set")
	}

	tr := &oauth.Transport{
		Token: &oauth.Token{AccessToken: token},
	}
	client = godo.NewClient(tr.Client())
}

func setupSSHKey() *godo.Key {
	log.Println("Setup SSH public key")

	pubKey := os.Getenv("SSH_PUB_KEY")
	if pubKey == "" {
		log.Fatal("SSH_PUB_KEY is not set")
	}
	fingerprint := os.Getenv("SSH_PUB_KEY_FINGERPRINT")
	if fingerprint == "" {
		log.Fatal("SSH_PUB_KEY_FINGERPRINT is not set")
	}

	// does JCIO key already exists?
	key, _, err := client.Keys.GetByFingerprint(fingerprint)
	if err != nil {
		// if not, upload new key
		request := &godo.KeyCreateRequest{
			Name:      "JCIO",
			PublicKey: pubKey,
		}
		key, _, err = client.Keys.Create(request)
		if err != nil {
			log.Fatal(err)
		}
	}
	return key
}

func setupDroplet(name, region, size, image string, key *godo.Key) *godo.Droplet {
	droplets := getDroplets()
	for _, d := range droplets {
		if d.Name == name {
			return &d
		}
	}

	d := createNewDroplet(name, region, size, image, key)
	return d.Droplet
}

func getDroplets() []godo.Droplet {
	list := []godo.Droplet{}
	opt := &godo.ListOptions{}
	for {
		droplets, resp, err := client.Droplets.List(opt)
		if err != nil {
			log.Fatal(err)
		}

		for _, d := range droplets {
			list = append(list, d)
		}
		if resp.Links.IsLastPage() {
			break
		}

		page, err := resp.Links.CurrentPage()
		if err != nil {
			log.Fatal(err)
		}
		opt.Page = page + 1
	}
	return list
}

func createNewDroplet(name, region, size, image string, key *godo.Key) *godo.DropletRoot {
	log.Println("Create new droplet: " + name)

	request := &godo.DropletCreateRequest{
		Name:    name,
		Region:  region,
		Size:    size,
		Image:   image,
		SSHKeys: []interface{}{key},
	}
	d, _, err := client.Droplets.Create(request)
	if err != nil {
		log.Fatal(err)
	}
	return d
}
