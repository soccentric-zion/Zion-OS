IMAGE_NAME      ?= zion-sdk
IMAGE_TAG       ?= latest
SDK_INSTALL_DIR ?= /opt/poky/sdk

.PHONY: all build clean

all: build

## Build the SDK Docker image (sdk.sh must already be staged in this directory).
## Run 'make sdk-image' from the project root to execute the full build chain.
build:
	@test -f sdk.sh || \
	    { echo "ERROR: sdk.sh not found — run 'make sdk-image' from the project root"; exit 1; }
	docker build \
		--build-arg SDK_INSTALL_DIR=$(SDK_INSTALL_DIR) \
		--label "org.yocto.sdk.install-dir=$(SDK_INSTALL_DIR)" \
		-t $(IMAGE_NAME):$(IMAGE_TAG) \
		.

clean:
	docker rmi -f $(IMAGE_NAME):$(IMAGE_TAG) 2>/dev/null || true
