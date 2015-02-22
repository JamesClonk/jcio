package main

import (
	"log"
	"os"
)

func main() {
	if len(os.Args) != 2 {
		log.Fatal("usage: ./shipyard <input-filename>")
	}

	client := NewClient("http://localhost:8080")
	if err := client.Login("admin", "shipyard"); err != nil {
		log.Fatal(err)
	}
	log.Println(client)
}
