# Buildroot: development branch ("master"), pinned to a commit until the next release
BUILDROOT_REPO := https://gitlab.com/buildroot.org/buildroot.git
BUILDROOT_VER := d04496c8c14a84c6ff9f23a023eb70eea61c683a
# release (no SSH, no root shell, U-Boot console locked down) or debug
FLAVOR ?= release

DOCKER_IMAGE := riptidewave93/d200-buildroot-builder:latest
DOCKER_NAME := d200-buildroot-builder

REPO_DIR := $(shell dirname $(realpath $(firstword $(MAKEFILE_LIST))))
DOCKER_RUN := docker run --rm $(shell [ -t 0 ] && echo -it) \
	--user $(shell id -u):$(shell id -g) -e HOME=/tmp \
	-e FLAVOR=$(FLAVOR) -v "$(REPO_DIR)":/repo:Z -w /repo --name $(DOCKER_NAME) $(DOCKER_IMAGE)

.PHONY: build builder-build build-builder-docker shell clean reset

# Build everything inside the builder container: make [FLAVOR=debug]
build : build-builder-docker
	$(DOCKER_RUN) /repo/scripts/entrypoint.sh

# Runs inside the container
builder-build :
	./scripts/setup_builddir.sh $(BUILDROOT_REPO) $(BUILDROOT_VER)
	./scripts/start_build.sh $(FLAVOR)

build-builder-docker :
	docker build -f ./depends/builder.Dockerfile -t $(DOCKER_IMAGE) .

# Interactive shell in the builder (Buildroot tree in ./BuildEnv/buildroot, output in
# ./BuildEnv/output-<flavour>)
shell : build-builder-docker
	docker run --rm -it --user $(shell id -u):$(shell id -g) -e HOME=/tmp \
		-v "$(REPO_DIR)":/repo:Z -w /repo $(DOCKER_IMAGE) /bin/bash

# Rebuild one package from scratch and collect the images, e.g. after changing its patches or
# config: make uboot-rebuild, make linux-rebuild FLAVOR=debug, make busybox-rebuild
%-rebuild : build-builder-docker
	$(DOCKER_RUN) /repo/scripts/rebuild_package.sh $* $(FLAVOR)

clean :
	rm -rf ./BuildEnv ./output

# clean + drop the download cache and the builder image
reset : clean
	rm -rf ./preserve
	-docker image rm $(DOCKER_IMAGE)
