package main

import (
	"fmt"
	"log"
	"os"
)

func main() {
	if err := run(os.Args); err != nil {
		log.Fatalf("error: %v", err)
		os.Exit(1)
	}
}

// nolint:unparam
func run(args []string) error {
	fmt.Println("Hello World!", args)
	return nil
}
