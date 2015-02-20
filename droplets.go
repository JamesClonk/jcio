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

func getEnv(key string) string {
	value := os.Getenv(key)
	if value == "" {
		log.Fatalf("%v is not set\n", key)
	}
	return value
}

func connect() {
	tr := &oauth.Transport{
		Token: &oauth.Token{
			AccessToken: getEnv("DIGITALOCEAN_TOKEN"),
		},
	}
	client = godo.NewClient(tr.Client())
}

func setupSSHKey() *godo.Key {
	log.Println("Setup SSH public key")

	// does JCIO key already exists?
	key, _, err := client.Keys.GetByFingerprint(getEnv("SSH_PUB_KEY_FINGERPRINT"))
	if err != nil {
		// if not, upload new key
		request := &godo.KeyCreateRequest{
			Name:      "JCIO",
			PublicKey: getEnv("SSH_PUB_KEY"),
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
			if d.Status != "new" || d.Status != "active" {
				startDroplet(&d)
			}
			return &d
		}
	}
	return createNewDroplet(name, region, size, image, key)
}

func getDroplets() []godo.Droplet {
	droplets := []godo.Droplet{}
	options := &godo.ListOptions{
		PerPage: 25,
	}
	for {
		ds, resp, err := client.Droplets.List(options)
		if err != nil {
			log.Fatal(err)
		}
		for _, d := range ds {
			droplets = append(droplets, d)
		}
		if resp.Links.IsLastPage() {
			break
		}

		page, err := resp.Links.CurrentPage()
		if err != nil {
			log.Fatal(err)
		}
		options.Page = page + 1
	}
	return droplets
}

func createNewDroplet(name, region, size, image string, key *godo.Key) *godo.Droplet {
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
	return d.Droplet
}

func startDroplet(droplet *godo.Droplet) {
	log.Println("Start droplet: " + droplet.Name)

	a, _, err := client.DropletActions.PowerOn(droplet.ID)
	if err != nil {
		log.Fatal(err)
	}
	if a.Status == "errored" {
		log.Fatalf("Could not start droplet: %v\n", a.String())
	}
}
