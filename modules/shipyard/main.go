package main

import (
	"bufio"
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
	if err := client.Login("admin", "shipyard"); err != nil {
		log.Fatal(err)
	}

	if err := client.AddAccount(config["username"], config["password"]); err != nil {
		log.Fatal(err)
	}

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
