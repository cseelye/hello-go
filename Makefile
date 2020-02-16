.DEFAULT_GOAL := build
SHELL = bash -o pipefail
V ?= 0

ifeq ($(shell  test $(V) -le 0; echo $$?;),0)
.SILENT:
endif

SERVICE_NAME = hello-go
BUILD_IMAGE_NAME = $(SERVICE_NAME)-builder:latest
RELEASE_IMAGE_NAME = $(SERVICE_NAME):latest

BUILD_IMAGE_MARKER = .$(subst :,-,$(BUILD_IMAGE_NAME))
RELEASE_IMAGE_MARKER = .$(subst :,-,$(RELEASE_IMAGE_NAME))

GOLANG_SOURCES = $(shell find $(CURDIR) -name "*.go" -a -not -name "*test*")
GOLANG_TEST_SOURCES = $(shell find $(CURDIR) -name "*.go" -a -name "*test*")
BUILDER_GOPATH = /go

# Override command names with g-prefix on macOS, error if they are not installed
TOUCH = touch
MKTEMP = mktemp --tmpdir
uname=$(shell uname -s)
ifeq ($(uname),Darwin)
	TOUCH = gtouch
    MKTEMP = gmktemp --tmpdir=/tmp
endif
TOOLS = $(TOUCH) $(firstword $(MKTEMP))
K := $(foreach exec,$(TOOLS),\
	$(if $(shell which $(exec)),asdf,$(error "No $(exec) in PATH")))

# Create a file whose existance and modification date match a container image.
# This brings a container image into make's world and allows make to do its
# normal magic with dependencies, build avoidance, etc.
# $1 the image name
# $2 the marker filename
define create_image_marker
	time=$$(docker inspect --format '{{.Metadata.LastTagTime}}' $1 2>/dev/null | perl -pe 's/\s+[^\s]+$$//'); \
	if [[ $$? -eq 0 ]]; then \
		$(TOUCH) -d "$${time}" '$2'; \
	else\
		$(RM) '$2'; \
	fi
endef

# Idempotent deletion of a container instance
# $1 the container name
define delete_container
	if docker container inspect $1 &>/dev/null; then \
		docker container rm --force $1; \
	fi
endef

# Idempotent deletion of a container image
# $1 the image name
define delete_image
	if docker image inspect $1 &>/dev/null; then \
		docker image rm --force $1; \
	fi
endef

# Idempotent deletion of a container instance and image
# $1 the container name
# $2 the image name
define delete_container_and_image
	$(call delete_container,$1)
	$(call delete_image,$2)
endef

.PHONY: .create-build-image-marker
.create-build-image-marker:
	@$(call create_image_marker,$(BUILD_IMAGE_NAME),$(BUILD_IMAGE_MARKER))

.PHONY: .create-release-image-marker
.create-release-image-marker:
	@$(call create_image_marker,$(RELEASE_IMAGE_NAME),$(RELEASE_IMAGE_MARKER))

.PHONY: build-container
#: Generate the build container
build-container: $(BUILD_IMAGE_MARKER) | .create-build-image-marker

$(BUILD_IMAGE_MARKER): Dockerfile
	$(call delete_image,$(BUILD_IMAGE_NAME)) && \
	DOCKER_BUILDKIT=1 docker build --no-cache --force-rm --target=builder --tag=$(BUILD_IMAGE_NAME) .

.PHONY: build
#: Generate the static binary and the container image for it
build: $(RELEASE_IMAGE_MARKER) $(SERVICE_NAME) | .create-release-image-marker

$(RELEASE_IMAGE_MARKER): Dockerfile $(SERVICE_NAME)
	$(call delete_image,$(RELEASE_IMAGE_NAME)) && \
	DOCKER_BUILDKIT=1 docker build --no-cache --force-rm --target=release --tag=$(RELEASE_IMAGE_NAME) .

#: Build the project binary using the build container
$(SERVICE_NAME): $(GOLANG_SOURCES) Dockerfile | build-container
	docker run --rm \
		   --env GOPATH=$(BUILDER_GOPATH) \
		   --volume $(CURDIR):$(BUILDER_GOPATH)/src/$(SERVICE_NAME) \
		   --workdir $(BUILDER_GOPATH)/src/$(SERVICE_NAME) \
		   $(BUILD_IMAGE_NAME) \
		   go build -v -a -ldflags "-extldflags -static"

.PHONY: run
#: Run the binary inside the release container
run: build
	docker run --rm \
           --volume $(CURDIR)/$(SERVICE_NAME):/$(SERVICE_NAME) \
           $(RELEASE_IMAGE_NAME) \
		   /$(SERVICE_NAME)

.PHONY: test
#: Run the tests inside the build container
test: $(GOLANG_SOURCES) $(GOLANG_TEST_SOURCES) Dockerfile | build-container
	docker run --rm \
		   --env GOPATH=$(BUILDER_GOPATH) \
		   --volume $(CURDIR):$(BUILDER_GOPATH)/src/$(SERVICE_NAME) \
		   --workdir $(BUILDER_GOPATH)/src/$(SERVICE_NAME) \
		   $(BUILD_IMAGE_NAME) \
		   go test -v -cover ./...

.PHONY: clean
#: Delete the release container image and the binary
clean:
	$(call delete_container_and_image,$(SERVICE_NAME),$(RELEASE_IMAGE_NAME))
	$(RM) $(RELEASE_IMAGE_MARKER)
	$(RM) $(SERVICE_NAME)

.PHONY: clobber
#: Delete all artifacts
clobber: clean
	$(call delete_image,$(BUILD_IMAGE_NAME))
	$(RM) $(BUILD_IMAGE_MARKER)
