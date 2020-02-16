package main

import "fmt"

func getHello() string {
	return "hello, world"
}
func main() {
	fmt.Printf("%s\n", getHello())
}
