SHELL := /bin/bash

SCRIPT_DIR := $(abspath scripts)
WORKDIR ?= /tmp/prism-build
IMAGE_RAW ?= $(WORKDIR)/prism-net.raw
ROOTFS_DIR ?= $(WORKDIR)/rootfs-net

.PHONY: help build validate clean

help:
	@echo "Available targets:"
	@echo "  make build     - builds the Net image"
	@echo "  make validate  - runs validation checks"
	@echo "  make clean     - removes build artifacts"
	@echo "  make help      - lists available targets"

build:
	WORKDIR="$(WORKDIR)" ROOTFS_DIR="$(ROOTFS_DIR)" IMAGE_RAW="$(IMAGE_RAW)" \
		bash "$(SCRIPT_DIR)/build-prism-net.sh"

validate:
	bash "$(SCRIPT_DIR)/validate-repo.sh"

clean:
	rm -rf "$(WORKDIR)"
