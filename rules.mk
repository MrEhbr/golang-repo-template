
all: help

##
## Common helpers
##

rwildcard = $(foreach d,$(wildcard $1*),$(call rwildcard,$d/,$2) $(filter $(subst *,%,$2),$d))

##
## Maintainer
##

ifneq ($(wildcard .git/HEAD),)
.PHONY: generate.authors
generate.authors: AUTHORS
AUTHORS: .git/
	echo "# This file lists all individuals having contributed content to the repository." > AUTHORS
	echo "# For how it is generated, see 'https://github.com/MrEhbr/vacuum-cleaner/rules.mk'" >> AUTHORS
	echo >> AUTHORS
	git log --format='%aN <%aE>' | LC_ALL=C.UTF-8 sort -uf >> AUTHORS
GENERATE_STEPS += generate.authors
endif

##
## Golang
##

ifndef GOPKG
ifneq ($(wildcard go.mod),)
GOPKG = $(shell sed '/module/!d;s/^omdule\ //' go.mod)
endif
endif
ifdef GOPKG
GO ?= go
GOPATH ?= $(HOME)/go
GO_INSTALL_OPTS ?=
GO_APP ?=
GO_TEST_OPTS ?= -test.timeout=20m -v
GOMOD_DIR ?= .
GOCOVERAGE_FILE ?= ./coverage.txt

ifdef GOBINS
.PHONY: go.install
go.install:
	@set -e; for dir in $(GOBINS); do ( set -xe; \
	 	cd $$dir; \
		for bin in `find $$dir/cmd -type f -name "main.go" | sed 's@/[^/]*$$@@' | sed 's/.*\///' | sort | uniq`; do ( \
			[ -n "$(GO_APP)" ] && [ "$(GO_APP)" != $$bin ] && continue; \
			$(GO) install $(GO_INSTALL_OPTS) ./cmd/$$bin \
		); done \
	); done
INSTALL_STEPS += go.install

.PHONY: go.release
go.release:
	goreleaser --snapshot --skip-publish --rm-dist
	@echo -n "Do you want to release? [y/N] " && read ans && \
	  if [ $${ans:-N} = y ]; then set -xe; goreleaser --rm-dist; fi
RELEASE_STEPS += go.release
endif

.PHONY: go.unittest
go.unittest:
	@echo "mode: atomic" > /tmp/gocoverage
	@set -e; for dir in `find $(GOMOD_DIR) -type f -name "go.mod" | grep -v /vendor/ | sed 's@/[^/]*$$@@' | sort | uniq`; do (set -e; (set -xe; \
	  cd $$dir; \
	  $(GO) test $(GO_TEST_OPTS) -cover -coverprofile=/tmp/profile.out -covermode=atomic -race ./...); \
	  if [ -f /tmp/profile.out ]; then \
	    cat /tmp/profile.out | sed "/mode: atomic/d" >> /tmp/gocoverage; \
	    rm -f /tmp/profile.out; \
	  fi); done
	@mv /tmp/gocoverage $(GOCOVERAGE_FILE)

.PHONY: go.checkdoc
go.checkdoc:
	go doc $(GOMOD_DIR)

.PHONY: go.coverfunc
go.coverfunc: go.unittest
	go tool cover -func=$(GOCOVERAGE_FILE) | grep -v .pb.go: | grep -v .pb.gw.go:

.PHONY: go.lint
go.lint:
	@set -e; for dir in `find $(GOMOD_DIR) -type f -name "go.mod" | grep -v /vendor/ | sed 's@/[^/]*$$@@' | sort | uniq`; do ( set -xe; \
	  cd $$dir; \
	  golangci-lint run --verbose ./...; \
	); done

.PHONY: go.tidy
go.tidy:
	@set -e; for dir in `find $(GOMOD_DIR) -type f -name "go.mod" | grep -v /vendor/ | sed 's@/[^/]*$$@@' | sort | uniq`; do ( set -xe; \
	  cd $$dir; \
	  $(GO)	mod tidy; \
	); done

.PHONY: go.clean-cache
go.clean-cache:
	@set -e; for dir in `find $(GOMOD_DIR) -type f -name "go.mod" | grep -v /vendor/ | sed 's@/[^/]*$$@@' | sort | uniq`; do ( set -xe; \
	  cd $$dir; \
	  $(GO)	clean -cache; \
	); done

.PHONY: go.clean-testcache
go.clean-testcache:
	@set -e; for dir in `find $(GOMOD_DIR) -type f -name "go.mod" | grep -v /vendor/ | sed 's@/[^/]*$$@@' | sort | uniq`; do ( set -xe; \
	  cd $$dir; \
	  $(GO)	clean -testcache; \
	); done


.PHONY: go.build
go.build:
	@set -e; for dir in `find $(GOMOD_DIR) -type f -name "go.mod" | grep -v /vendor/ | sed 's@/[^/]*$$@@' | sort | uniq`; do ( set -xe; \
		cd $$dir; \
			for bin in `find $$dir/cmd -type f -name "main.go" | sed 's@/[^/]*$$@@' | sed 's/.*\///' | sort | uniq`; do ( \
				$(GO) build -o .bin/$$bin ./cmd/$$bin/...; \
			); done \
	); done

.PHONY: go.bump-deps
go.bumpdeps:
	@set -e; for dir in `find $(GOMOD_DIR) -type f -name "go.mod" | grep -v /vendor/ | sed 's@/[^/]*$$@@' | sort | uniq`; do ( set -xe; \
	  cd $$dir; \
	  $(GO)	get -u ./...; \
	); done

.PHONY: go.bump-deps
go.fmt:
	if ! command -v goimports &>/dev/null; then GO111MODULE=off go get golang.org/x/tools/cmd/goimports; fi
	@set -e; for dir in `find $(GOMOD_DIR) -type f -name "go.mod" | grep -v /vendor/ | sed 's@/[^/]*$$@@' | sort | uniq`; do ( set -xe; \
	  cd $$dir; \
	  goimports -w `go list -f '{{.Dir}}' ./...` \
	); done

.PHONY: go.generate
go.generate:
	@set -e; for dir in `find $(GOMOD_DIR) -type f -name "go.mod" | grep -v /vendor/ | sed 's@/[^/]*$$@@' | sort | uniq`; do ( set -xe; \
	  cd $$dir; \
	  $(GO) generate ./...; \
	); done
GENERATE_STEPS += go.generate

##
## proto
##


.PHONY: proto.lint
proto.lint:
	buf check lint
	buf check breaking --against-input '.git#branch=master'

# remote is what we run when testing in most CI providers
# this does breaking change detection against our remote git repository
#
.PHONY: proto.lint-remote
proto.lint-remote: $(BUF)
	buf check lint
	buf check breaking --against-input "$(shell git remote get-url origin)#branch=master"


.PHONY: proto.generate
proto.generate: $(BUF)
	./scripts/protoc_gen.bash \
		"--proto_path=$(PROTO_PATH)" \
		$(patsubst %,--proto_include_path=%,$(PROTO_INCLUDE_PATHS)) \
		"--plugin_name=go" \
		"--plugin_out=$(PROTOC_GEN_GO_OUT)" \
		"--plugin_opt=$(PROTOC_GEN_GO_OPT)"
GENERATE_STEPS += proto.generate


BUILD_STEPS += go.build
BUMPDEPS_STEPS += go.bumpdeps
TIDY_STEPS += go.tidy
LINT_STEPS += go.lint
ifneq ($(wildcard buf.yml),)
LINT_STEPS += proto.lint
endif
PRE_UNITTEST_STEPS += go.clean-testcache
UNITTEST_STEPS += go.unittest
FMT_STEPS += go.fmt
endif

##
## Docker
##

ifndef DOCKERFILE_PATH
DOCKERFILE_PATH = ./Dockerfile
endif
ifndef DOCKER_IMAGE
ifneq ($(wildcard Dockerfile),)
DOCKER_IMAGE = $(notdir $(PWD))
endif
endif
ifdef DOCKER_IMAGE
ifneq ($(DOCKER_IMAGE),none)
.PHONY: docker.build
docker.build:
	docker build \
	  --build-arg VCS_REF=`git rev-parse --short HEAD` \
	  --build-arg BUILD_DATE=`date -u +"%Y-%m-%dT%H:%M:%SZ"` \
	  --build-arg VERSION=`git describe --tags --always` \
	  -t $(DOCKER_IMAGE) -f $(DOCKERFILE_PATH) $(dir $(DOCKERFILE_PATH))

BUILD_STEPS += docker.build
endif
endif

##
## Common
##

TEST_STEPS += $(UNITTEST_STEPS)
TEST_STEPS += $(LINT_STEPS)
TEST_STEPS += $(TIDY_STEPS)

ifneq ($(strip $(TEST_STEPS)),)
.PHONY: test
test: $(PRE_TEST_STEPS) $(TEST_STEPS)
endif

ifdef INSTALL_STEPS
.PHONY: install
install: $(PRE_INSTALL_STEPS) $(INSTALL_STEPS)
endif

ifdef UNITTEST_STEPS
.PHONY: unittest
unittest: $(PRE_UNITTEST_STEPS) $(UNITTEST_STEPS)
endif

ifdef LINT_STEPS
.PHONY: lint
lint: $(PRE_LINT_STEPS) $(FMT_STEPS) $(LINT_STEPS)
endif

ifdef TIDY_STEPS
.PHONY: tidy
tidy: $(PRE_TIDY_STEPS) $(TIDY_STEPS)
endif

ifdef BUILD_STEPS
.PHONY: build
build: $(PRE_BUILD_STEPS) $(BUILD_STEPS)
endif

ifdef RELEASE_STEPS
.PHONY: release
release: $(PRE_RELEASE_STEPS) $(RELEASE_STEPS)
endif

ifdef BUMPDEPS_STEPS
.PHONY: bumpdeps
bumpdeps: $(PRE_BUMDEPS_STEPS) $(BUMPDEPS_STEPS)
endif

ifdef FMT_STEPS
.PHONY: fmt
fmt: $(PRE_FMT_STEPS) $(FMT_STEPS)
endif

ifdef GENERATE_STEPS
.PHONY: generate
generate: $(PRE_GENERATE_STEPS) $(GENERATE_STEPS)
endif

.PHONY: help
help:
	@echo "General commands:"
	@[ "$(BUILD_STEPS)" != "" ]     && echo "  build"     || true
	@[ "$(BUMPDEPS_STEPS)" != "" ]  && echo "  bumpdeps"  || true
	@[ "$(FMT_STEPS)" != "" ]       && echo "  fmt"       || true
	@[ "$(GENERATE_STEPS)" != "" ]  && echo "  generate"  || true
	@[ "$(INSTALL_STEPS)" != "" ]   && echo "  install"   || true
	@[ "$(LINT_STEPS)" != "" ]      && echo "  lint"      || true
	@[ "$(RELEASE_STEPS)" != "" ]   && echo "  release"   || true
	@[ "$(TEST_STEPS)" != "" ]      && echo "  test"      || true
	@[ "$(TIDY_STEPS)" != "" ]      && echo "  tidy"      || true
	@[ "$(UNITTEST_STEPS)" != "" ]  && echo "  unittest"  || true
	@# FIXME: list other commands
