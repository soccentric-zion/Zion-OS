IMAGE_NAME       ?= zion-esdk
IMAGE_TAG        ?= latest
ESDK_INSTALL_DIR ?= /opt/poky/esdk

.PHONY: all build clean

all: build

## Build the eSDK Docker image (esdk.sh must already be staged in this directory).
## Run 'make esdk-image' from the project root to execute the full build chain.
build:
	@test -f esdk.sh || \
	    { echo "ERROR: esdk.sh not found — run 'make esdk-image' from the project root"; exit 1; }
	docker build \
		--build-arg ESDK_INSTALL_DIR=$(ESDK_INSTALL_DIR) \
		--label "org.yocto.esdk.install-dir=$(ESDK_INSTALL_DIR)" \
		-t $(IMAGE_NAME):$(IMAGE_TAG) \
		.

clean:
	docker rmi -f $(IMAGE_NAME):$(IMAGE_TAG) 2>/dev/null || true
