package main

import "testing"

func TestHello(t *testing.T) {
	want := "hello, world"
	got := getHello()
	if got != want {
		t.Errorf("%s != %s", got, want)
	}
}

func ExampleMain() {
	main()

	// Output: hello, world
}
