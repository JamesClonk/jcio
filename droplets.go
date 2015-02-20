package main

import (
	"bufio"
	"fmt"
	"io/ioutil"
	"log"
	"os"
	"strings"
	"time"

	"code.google.com/p/goauth2/oauth"
	"github.com/digitalocean/godo"
)

var client *godo.Client

func main() {
	if len(os.Args) != 2 {
		log.Fatal("usage: droplets.go <input-filename>")
	}

	droplets := createDroplets(os.Args[1])
	for _, droplet := range droplets {
		ip := waitForIP(droplet)
		if err := ioutil.WriteFile(droplet.Name+".ip_address", []byte(ip), 0640); err != nil {
			log.Fatal(err)
		}
	}
}

func waitForIP(droplet *godo.Droplet) string {
	fmt.Printf("Waiting for droplet IP address (%v)", droplet.Name)

	var timoutCounter = 100
	var ip string
	for {
		d, _, err := client.Droplets.Get(droplet.ID)
		if err != nil {
			log.Fatal(err)
		}
		for _, network := range d.Droplet.Networks.V4 {
			if network.IPAddress != "0.0.0.0" &&
				network.Type == "public" {
				ip = network.IPAddress
			}
		}
		if ip != "" {
			break
		}
		fmt.Print(".")
		time.Sleep(3 * time.Second)

		timoutCounter--
		if timoutCounter <= 0 {
			log.Fatal("\nTimeout reached! Could not get IP address")
		}
	}
	fmt.Println()
	fmt.Printf("IP address: %v\n", ip)
	return ip
}

func createDroplets(filename string) []*godo.Droplet {
	in, err := os.Open(filename)
	if err != nil {
		log.Fatal(err)
	}
	defer in.Close()

	connect()
	key := setupSSHKey()

	var droplets []*godo.Droplet
	scanner := bufio.NewScanner(in)
	for scanner.Scan() {
		line := scanner.Text()
		args := strings.Fields(line)
		if len(args) != 4 {
			log.Fatalf("Invalid line in inputfile: %v\n", line)
		}
		name := args[0]
		region := args[1]
		size := args[2]
		image := args[3]

		droplet := setupDroplet(name, region, size, image, key)
		droplets = append(droplets, droplet)
	}
	if err := scanner.Err(); err != nil {
		log.Fatal(scanner.Err())
	}
	return droplets
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
	fmt.Println("Setup SSH public key")

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
			if d.Status != "new" && d.Status != "active" {
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
	fmt.Println("Create new droplet: " + name)

	request := &godo.DropletCreateRequest{
		Name:    name,
		Region:  region,
		Size:    size,
		Image:   image,
		SSHKeys: []interface{}{key.ID},
	}
	d, _, err := client.Droplets.Create(request)
	if err != nil {
		log.Fatal(err)
	}
	return d.Droplet
}

func startDroplet(droplet *godo.Droplet) {
	fmt.Println("Start droplet: " + droplet.Name)

	a, _, err := client.DropletActions.PowerOn(droplet.ID)
	if err != nil {
		log.Fatal(err)
	}
	if a.Status == "errored" {
		log.Fatalf("Could not start droplet: %v\n", a.String())
	}
}
