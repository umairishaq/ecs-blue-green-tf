
-include Makefile.env

SHELL := /bin/bash
.DEFAULT_GOAL := all

.PHONY: all
## all: (default) runs build-image
all: build-image

AWS_PROFILE?=
ROOT_PATH=$(PWD)
APP_DIR=$(ROOT_PATH)/src

.PHONY: build-image
## build-image: builds the docker image
build-image:
	docker build -t $(APP_NAME):$(GIT_COMMIT) $(APP_DIR)
