SHELL := /usr/bin/env bash -o pipefail
GOPKG ?= github.com/MrEhbr/golang-repo-template
DOCKER_IMAGE ?=	MrEhbr/golang-repo-template
GOBINS ?= .
PROTO_PATH := .
PROTOC_GEN_GO_OUT := .
PROTOC_GEN_GO_OPT := plugins=grpc

include rules.mk