IMAGE_NAME  ?= zion-kas
IMAGE_TAG   ?= latest
KAS_VERSION ?= 4.5

.PHONY: all build clean

all: build

## Build the KAS Yocto build container
build:
	docker build \
		--build-arg KAS_VERSION=$(KAS_VERSION) \
		--label "org.yocto.kas.version=$(KAS_VERSION)" \
		-t $(IMAGE_NAME):$(IMAGE_TAG) \
		.

clean:
	docker rmi -f $(IMAGE_NAME):$(IMAGE_TAG) 2>/dev/null || true
