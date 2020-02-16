# hello-go
"Hello, World" in golang, with 100% unit test coverage, containerized build, static binary and "FROM scratch" release container image.

`make run` will build and run the code  
`make test` will run the tests and coverage  

## Quick start
The build and run process is containerized so there are very few prerequisites for your host.

On linux, install docker and remake

On macOS, install docker and then some GNU tools:
```
brew install remake coreutils
```

For all operating systems, I strongly recommend using remake isntead of make. remake is a patched version of make with extended error reporting, tracing, etc. After installing, either teach yourself to type remake instead of make, or add an alias to your profile: `alias make=remake`
