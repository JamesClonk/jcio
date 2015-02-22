package main

import (
	"bufio"
	"io/ioutil"
	"log"
	"os"
	"strings"
)

var config map[string]string = make(map[string]string)

func main() {
	if len(os.Args) != 2 {
		log.Fatal("usage: ./shipyard <input-filename>")
	}
	readConfig(os.Args[1])

	client := NewClient("http://localhost:8080")
	log.Println("Login to shipyard")
	if err := client.Login("admin", "shipyard"); err != nil {
		log.Fatal(err)
	}

	addEngines()

	log.Println("Add account to shipyard: " + config["username"])
	if err := client.AddAccount(config["username"], config["password"]); err != nil {
		log.Fatal(err)
	}

	log.Println("Delete account from shipyard: " + admin)
	if err := client.DeleteAccount("admin"); err != nil {
		log.Fatal(err)
	}
}

func readConfig(filename string) {
	in, err := os.Open(filename)
	if err != nil {
		log.Fatal(err)
	}
	defer in.Close()

	scanner := bufio.NewScanner(in)
	for scanner.Scan() {
		line := scanner.Text()
		args := strings.SplitN(line, "=", 2)
		if len(args) != 2 {
			log.Fatalf("Invalid line in inputfile: %v\n", line)
		}
		config[args[0]] = args[1]
	}
}

func readEngines(filename string) {
	in, err := os.Open(filename)
	if err != nil {
		log.Fatal(err)
	}
	defer in.Close()

	scanner := bufio.NewScanner(in)
	for scanner.Scan() {
		line := scanner.Text()
		args := strings.SplitN(line, "=", 2)
		if len(args) != 2 {
			log.Fatalf("Invalid line in inputfile: %v\n", line)
		}
		config[args[0]] = args[1]
	}
}

func addEngines() {
	engines := strings.Split(config["engines"], ";")
	if len(engines) < 1 {
		log.Fatalf("No engines specified: %v\n", config["engines"])
	}

	for _, host := range engines {
		log.Println("Add engine to shipyard: " + host)
		id := getEngineId(host)
		url := "https://" + host + ":2376"
		sslcert := readPem(host, "cert.pem")
		sslkey := readPem(host, "key.pem")
		cacert := readPem(host, "ca.pem")
		cpu := 1.0
		memory := 416
		if err := client.AddEngine(id, sslcert, sslkey, cacert, url, cpu, memory); err != nil {
			log.Fatal(err)
		}
	}
}

func getEngineId(host string) string {
	idx := strings.Index(host, ".")
	return host[0:idx]
}

func readPem(host, filename string) string {
	data, err := ioutil.ReadFile("/root/" + host + "_certificates/" + filename)
	if err != nil {
		log.Fatal(err)
	}
	return string(data)
}
