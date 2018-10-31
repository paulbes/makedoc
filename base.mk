# Make your go project!
#
# The primary targets in this file are:
#
# all				Do everything
# check				Run all coherency and test targets
#
# -- Testing and coherency targets
#
# fmt				Format the go code
# imports			Format the go imports
# coverage			Create a report of current coverage
# lint				Do a linting of the go code
# test				Run all the go tests
# integration		Run all integration tests
#
# -- Binary targets
#
# release			Create a binary release
# install			Install the application binaries
#
# -- Container targets
#
# deps				Start all application container dependencies
# image  			Build a container image with the lastest application binary
# service		    Run a container from the built container image
# service-restart   Rebuild the container image and restart service, but keep dependencies running
# migrate           Run a migration target as part of the service initialisation
# shell-%           Create a shell to a docker-compose managed container, e.g., make shell-postgres
# logs-%			Fetch the logs to a docker-compose managed container, e.g., make logs-postgres
# up-%              Start the compose container with % name
# id-%              Get the container id for container with % name
#
# -- Publishing targets
#
# package			Create an installable package
# inspect           Inspect the installable package
# publish			Publish the package to artifactory
#
# -- Other targets
#
# vendor			Ensure that the go vendor dependencies exist
# vendor-update		Do an update of the go vendor dependencies
# clean				Stop all containers and clean the build directory
# list				List all available make targets
# show-%            Show the content of any variable, e.g., make show-RELEASE_VERSION
#
# In addition there are a number of variables that can be used to modify
# the way the various targets work:
#
# RELEASE_PLATFORMS			Override the default list of platforms to build a release for
# DEPS				Change the dependencies that are started before integration test or runs
#
# There are also some environment variables that change the behavior:
#
# TRAVIS_BRANCH		If this is set to something other than `master`
#					we will do more extensive linting
#
# Requirements:
#
#	Compose file requirements
#
# 	Need to use version 2.3 of docker compose file, and also
#   use the `healthcheck` section.
#
.DEFAULT_GOAL = all
SHELL         = bash

skip = $(info $@: skipping, target disabled)

check_defined = \
    $(strip $(foreach 1,$1, \
        $(call __check_defined,$1,$(strip $(value 2)))))
__check_defined = \
    $(if $(value $1),, \
      $(error Undefined $1$(if $2, ($2))))

# Go packages and files
#
# Some reusable variables for various go things
.ALLPKGS               = $(shell go list ./...)
.COVERAGE_PKGS_EXCLUDE = $(foreach e,$(COVERAGE_PKGS_EXCLUDE), | grep -v $(e))
.COVERAGE_PKGS         = $(shell go list ./... $(.COVERAGE_PKGS_EXCLUDE))
.INTEGRATION_PKGS      = $(shell go list ./... | grep $(INTEGRATION_DIR_BASE))
.DIRS                  = $(shell go list -f '{{ .Dir }}' ./...)
.GOFILES               = $(shell find . -name '.?*' -prune -o -name vendor -prune -o -name '*.go' -print)

# Git
#
# Provide some nice to use variables for the git
# repository state
COMMIT := $(shell git rev-parse HEAD)
BRANCH := $(shell git rev-parse --abbrev-ref HEAD)
SLUG   := $(shell git remote -v | grep "(fetch)" | awk '{print$$2}' | sed -E 's/^.*(\/|:)([^ ]*)\/([^ ]*)$$/\2\/\3/;s/\.git//')

# Directories
#
# All of the following directories can be
# overwritten. If this is done, it is
# only recommended to change the BUILD_DIR
# option.
BUILD_DIR     := build
RELEASE_DIR   := $(BUILD_DIR)/release
COVERAGE_DIR  := $(BUILD_DIR)/coverage
LINT_DIR      := $(BUILD_DIR)/lint
TEST_DIR      := $(BUILD_DIR)/test
IMAGE_DIR     := $(BUILD_DIR)/container
DIST_DIR      := $(BUILD_DIR)/dist
INT_DIR       := $(BUILD_DIR)/integration

$(BUILD_DIR):
	-mkdir $(BUILD_DIR)

$(RELEASE_DIR): | $(BUILD_DIR)
	-mkdir $(RELEASE_DIR)

$(COVERAGE_DIR): | $(BUILD_DIR)
	-mkdir $(COVERAGE_DIR)

$(LINT_DIR): | $(BUILD_DIR)
	-mkdir $(LINT_DIR)

$(TEST_DIR): | $(BUILD_DIR)
	-mkdir $(TEST_DIR)

$(IMAGE_DIR): | $(BUILD_DIR)
	-mkdir $(IMAGE_DIR)

$(DIST_DIR): | $(BUILD_DIR)
	-mkdir $(DIST_DIR)

$(INT_DIR): | $(BUILD_DIR)
	-mkdir $(INT_DIR)

# External binaries
#
# The following external binaries are required
# by this make file.
#
# We will abort any further commands if go
# is not installed.
#
# For docker, docker-compose, etc., we will
# only throw an error when evaluating targets
# that use that functionality and throw
# an error
BIN_DIR        := $(GOPATH)/bin
GOMETALINTER   := $(BIN_DIR)/gometalinter
DEP            := $(BIN_DIR)/dep
GOIMPORTS      := $(BIN_DIR)/goimports
GOCOVMERGE     := $(BIN_DIR)/gocovmerge
GOCOVXML       := $(BIN_DIR)/gocov-xml
GOCOV          := $(BIN_DIR)/gocov
GOJUNITREPORT  := $(BIN_DIR)/go-junit-report
RICHGO         := $(BIN_DIR)/richgo
MAKEDOC        := $(BIN_DIR)/makedoc

GO             := $(shell command -v go 2> /dev/null)
DOCKER         := $(shell command -v docker 2> /dev/null)
DOCKERCOMPOSE  := $(shell command -v docker-compose 2> /dev/null)
FPM            := $(shell command -v fpm 2> /dev/null)
JFROG          := $(shell command -v jfrog 2> /dev/null)
RPM            := $(shell command -v rpm 2> /dev/null)
DPKG           := $(shell command -v dpkg 2> /dev/null)

uname_v        := $(shell uname -v)

go:
	$(call check_defined, GO, go is required to perform this operation)
.PHONY: go

docker:
ifndef DOCKER
ifeq ($(findstring Darwin,$(uname_v)),Darwin)
	$(error docker is not available, please install: https://docs.docker.com/docker-for-mac/install/#download-docker-for-mac)
endif
	$(error docker is not available please install)
endif
.PHONY: docker

dockercompose:
ifndef DOCKERCOMPOSE
ifeq ($(findstring Darwin,$(uname_v)),Darwin)
	$(error docker-compose is not available, please install: https://docs.docker.com/docker-for-mac/install/#download-docker-for-mac)
else
	$(error docker-compose is not available, please install)
endif
else
	$(eval DOCKERCOMPOSE := $(DOCKERCOMPOSE) -p "sch_$(subst /,_,$(SLUG))")
endif
.PHONY: dockercompose

fpm:
	$(call check_defined, FPM, fpm cli is not available please install)
.PHONY: fpm

jfrog:
	$(call check_defined, JFROG, jfrog cli not available please install)
.PHONY: jfrog

rpm:
	$(call check_defined, RPM, rpm is not available please install)
.PHONY: rpm

dpkg:
	$(call check_defined, DPKG, dpkg is not available please install)
.PHONY: dpkg

$(GOMETALINTER): | go
	go get -u github.com/alecthomas/gometalinter
	$(GOMETALINTER) --install --debug

$(DEP): | go
	go get -u github.com/golang/dep/cmd/dep

$(GOIMPORTS): | go
	go get -u golang.org/x/tools/cmd/goimports

$(GOCOVMERGE): | go
	go get -u github.com/wadey/gocovmerge

$(GOCOVXML): | go
	go get -u github.com/AlekSi/gocov-xml

$(GOCOV): | go
	go get -u github.com/axw/gocov/gocov

$(GOJUNITREPORT): | go
	go get -u github.com/jstemmer/go-junit-report

$(RICHGO): | go
	go get -u github.com/kyoh86/richgo

$(MAKEDOC): | go
	go get -u github.com/paulbes/makedoc

## Run all reasonable targets
##
## This is centered on the end-user experience and will run all
## sanity checks for the project after which it will start the
## service itself (if enabled).
all: | check service
.PHONY: all

## Download the project dependencies
##
## This will fetch the pinned project dependencies
vendor: $(DEP)
	$(DEP) ensure -vendor-only
.PHONY: vendor

VENDOR_UPDATE_ENABLE ?= true

ifeq ($(TRAVIS),true)
$(info running in travis so disabling vendor-update)
VENDOR_UPDATE_ENABLE = false
endif

ifeq ($(VENDOR_UPDATE_ENABLE),true)
## Update the project dependencies
##
## This will updated all project dependencies
## to their latest versions.
##
## Warning: this can cause your project to
## stop functioning.
vendor-update: vendor
	$(DEP) ensure -update
else
vendor-update:
	$(skip)
endif
.PHONY: vendor-update

## Run all sanity checks on your project
##
## This is a useful command to run prior to pushing
## changes to a remote git repository.
check: | vendor fmt imports lint test coverage integration
.PHONY: check

TEST_JUNIT_XML    ?= $(TEST_DIR)/junit-report.xml
TEST_TAGS         ?= unit

## Run all go tests
##
## It is possible to change the way this target behaves:
##
## Override examples:
##
##	make TEST_TAGS="unit feature" test
##		Only test the packages that have these build tags
##	make TEST_JUNIT_XML=~/reports/junit-report.xml test
##		Write the report to the provided location
##
##
test: go $(RICHGO) $(GOJUNITREPORT) $(TEST_DIR) vendor
	go test -v ./... -tags $(TEST_TAGS) | tee >(RICHGO_FORCE_COLOR=1 $(RICHGO) testfilter) | tee /dev/tty | $(GOJUNITREPORT) > $(TEST_JUNIT_XML); test $${PIPESTATUS[0]} -eq 0
.PHONY: test

LINTERS     ?= golint vet gofmt
LINT_ARGS   ?= --deadline=50s --dupl-threshold=70 --vendor --enable-gc
LINT_REPORT ?= $(LINT_DIR)/report

ifeq "$(origin TRAVIS_BRANCH)" "environment"
ifneq ($(TRAVIS_BRANCH),master)
LINTERS = deadcode errcheck goconst golint gofmt gosimple ineffassign unconvert vet vetshadow
LINT_ARGS = --checkstyle --deadline=450s --dupl-threshold=70 --vendor --enable-gc
endif
endif

## Lint all go files
##
## It is possible to change the way this target behaves:
##
## Override examples:
##
##	make LINTERS=golint lint
##		Only use the `golint` linter
##
##   make LINT_ARGS="--deadline=120s --vendor --enable-gc" lint
##		Change the linter arguments, setting a higher deadline
##
##   TRAVIS_BRANCH=pr make LINT_REPORT=~/reports/lint.xml lint
##		Mimick travis behavior by setting the travis branch, and
##		write the input to a different location.
##
##
lint: $(GOMETALINTER) $(LINT_DIR)
	$(GOMETALINTER) --disable-all $(foreach linter,$(LINTERS),--enable $(linter)) \
		$(LINT_ARGS) $(.DIRS) | tee /dev/tty > $(LINT_REPORT); test $${PIPESTATUS[0]} -eq 0
.PHONY: lint

FMT_ENABLE ?= true

ifeq ($(TRAVIS),true)
$(info running in travis so disabling fmt)
FMT_ENABLE = false
endif

ifeq ($(FMT_ENABLE),true)
## Run go fmt
##
## Ensure that all go files have correct formatting
fmt: go
	go fmt $(.ALLPKGS)
else
fmt:
	$(skip)
endif
.PHONY: fmt

IMPORTS_ENABLE ?= true

ifeq ($(TRAVIS),true)
$(info running in travis so disabling imports)
IMPORTS_ENABLE = false
endif

ifeq ($(IMPORTS_ENABLE),true)
## Run goimports on all go files
##
## Ensure that all go imports are correctly ordered
imports: $(GOIMPORTS)
	$(foreach gofile,$(.GOFILES),$(GOIMPORTS) -w $(gofile) &&) true
else
imports:
	$(skip)
endif
.PHONY: imports

COVERAGE_MODE         ?= count
COVERAGE_PROFILE      ?= $(COVERAGE_DIR)/profile.out
COVERAGE_HTML         ?= $(COVERAGE_DIR)/index.html
COVERAGE_XML          ?= $(COVERAGE_DIR)/coverage.xml
COVERAGE_PKGS_EXCLUDE ?= /integration

## Run go test with coverage on
##
## This will collect and generate various
## coverage reports. It is possible to modify
## this targets behavior:
##
## Override examples:
##
##	make COVERAGE_MODE=atomic coverage
##		Change the coverage mode to `atomic`
##	make COVERAGE_XML=~/reports/coverage.xml
##		Write the coverage XML report to a different
##		location
coverage: vendor go $(COVERAGE_DIR) $(GOCOV) $(GOCOVXML) $(GOCOVMERGE) # Run go test with coverage
	-rm -f $(COVERAGE_DIR)/*.cover
	$(foreach pkg,$(.COVERAGE_PKGS), \
		go test -coverpkg=$(pkg) -covermode=$(COVERAGE_MODE) \
			-coverprofile="$(COVERAGE_DIR)/$(subst /,-,$(pkg)).cover" $(pkg) &&) true
	$(GOCOVMERGE) $(COVERAGE_DIR)/*.cover > $(COVERAGE_PROFILE)
	go tool cover -html=$(COVERAGE_PROFILE) -o $(COVERAGE_HTML)
	$(GOCOV) convert $(COVERAGE_PROFILE) | $(GOCOVXML) > $(COVERAGE_XML)
.PHONY: coverage

INTEGRATION_ENABLE    ?= false
INTEGRATION_JUNIT_XML ?= $(INT_DIR)/junit-report.xml
INTEGRATION_TAGS      ?= integration
INTEGRATION_DIR_BASE  ?= /integration

ifeq ($(INTEGRATION_ENABLE),true)
## Run all integration tests
##
## This will bring up the dependencies as docker
## containers first
##
## It is possible to disable integration tests by
## setting INTEGRATION_ENABLED to false
##
## Override examples:
##
##	make DEPS=postgres integration
##		Run the integration tests, but only bring
##		up the `postgres` dependency
##
##		NB: This override is handled by the `deps`
##		target, but added here as an example
##
integration: go $(GOJUNITREPORT) $(INT_DIR) deps
	go clean -testcache
	$(foreach pkg,$(.INTEGRATION_PKGS), \
		go test -p=1 -v $(pkg)/... -tags $(INTEGRATION_TAGS) | tee /dev/tty | $(GOJUNITREPORT) > $(INTEGRATION_JUNIT_XML); test $${PIPESTATUS[0]} -eq 0 &&) true
else
integration:
	$(skip)
endif
.PHONY: integration

RELEASE_ENABLE       ?= false
RELEASE_BINARIES     ?= $(shell find . -not \( -path "./vendor/*" -prune \) -name main.go)
RELEASE_PLATFORMS    ?= linux darwin
RELEASE_ARCH         ?= amd64
RELEASE_VERSION      ?= $(shell git describe --tags 2> /dev/null)
RELEASE_BUILD_NUMBER ?= $(shell git log --pretty=format:'' | wc -l | sed 's/[ \t]//g')
CGO_ENABLED          ?= 0

ifeq ($(RELEASE_VERSION),)
RELEASE_VERSION = 0.0.$(RELEASE_BUILD_NUMBER)
endif

.binary-name = $(shell basename `dirname $(abspath $(1))`)
os = $(word 1, $@)
$(RELEASE_PLATFORMS): go vendor $(RELEASE_DIR)
	$(foreach binary,$(RELEASE_BINARIES), \
		CGO_ENABLED=$(CGO_ENABLED) GOOS=$(os) GORELEASE_ARCH=$(RELEASE_ARCH) go build \
		-ldflags '-extldflags "-static"' \
		-o $(RELEASE_DIR)/$(call .binary-name,$(binary))-$(RELEASE_VERSION)-$(os)-$(RELEASE_ARCH) \
		$(binary) &&) true
.PHONY: $(RELEASE_PLATFORMS)

clean-releases:
	-rm -f $(RELEASE_DIR)/*
.PHONY: clean-releases

ifeq ($(RELEASE_ENABLE),true)
## Create binaries of all known commands
##
## It is possible to modify the behavior of this target:
##
## Override examples:
##
##	make RELEASE_BINARIES=~/src/app/main.go RELEASE_PLATFORMS=linux release
##		Only create a binary of the provided go file, and only
##		for the provided platform
##   make RELEASE_VERSION=0.1.0 release
##		Set a different version for the binary
##
release: | clean-releases $(RELEASE_PLATFORMS)
else
release:
	$(skip)
endif
.PHONY: release

RELEASE_PUBLISH_ENABLE         ?= false
RELEASE_PUBLISH_REMOTE_BASE    ?= libs-release-local
RELEASE_PUBLISH_REMOTE_PROJECT ?= $(SLUG)

ifeq ($(RELEASE_PUBLISH_ENABLE),true)
$(call check_defined, RELEASE_PUBLISH_REMOTE_BASE, release publish enabled but no remote base provided)
$(call check_defined, RELEASE_PUBLISH_REMOTE_PROJECT, release publish enabled but no remote project provided)

ifdef TRAVIS_PULL_REQUEST
ifneq ($(TRAVIS_PULL_REQUEST), false)
$(info disabling artifactory publish of binaries since this is a travis pull request)
RELEASE_PUBLISH_ENABLE = false
endif
endif

ifdef TRAVIS_BRANCH
ifneq ($(TRAVIS_BRANCH), master)
$(info disabling artifactory publish of binaries since the travis branch is not master)
RELEASE_PUBLISH_ENABLE = false
endif
endif
endif

.release      = $(subst -, ,$(notdir $(1)))
.release-name = $(word 1,$(call .release,$(1)))
.release-vers = $(word 2,$(call .release,$(1)))
.release-os   = $(word 3,$(call .release,$(1)))
.release-arch = $(word 4,$(call .release,$(1)))

ifeq ($(RELEASE_PUBLISH_ENABLE),true)
## Publish a release of your binaries to artifactory
release-publish: guard-ARTIFACTORY_USER guard-ARTIFACTORY_PWD jfrog | release
	JFROG_CLI_OFFER_CONFIG=false $(foreach r,$(wildcard $(RELEASE_DIR)/*),\
		jfrog rt u $(r) $(RELEASE_PUBLISH_REMOTE_BASE)/$(RELEASE_PUBLISH_REMOTE_PROJECT) \
		--build-name=$(call .release-name,$(r)) \
		--build-number=$(call .release-vers,$(r)) \
		--props=name=$(call .release-name,$(r))\;version=$(call .release-vers,$(r))\;os=$(call .release-os,$(r))\;arch=$(call .release-arch,$(r)) \
		--user=$(ARTIFACTORY_USER) --apikey=$(ARTIFACTORY_PWD) --url=$(ARTIFACTORY_URL) &&) true
else
release-publish:
	$(skip)
endif
.PHONY: release-publish

IMAGE_ENABLE             ?= false
IMAGE_NAME               ?=
IMAGE_FORCE_REBUILD      ?= true
IMAGE_DOCKERFILE     	 ?= $(IMAGE_DIR)/Dockerfile
IMAGE_CONTEXT            ?=

IMAGE_BASE               ?= alpine:latest
IMAGE_PLATFORM           ?= linux
IMAGE_START_FILE         ?= $(IMAGE_DIR)/start
IMAGE_START_CONTENT      ?=
IMAGE_DOCKERFILE_CONTENT ?=

IMAGE_COMMANDS           ?=
IMAGE_CUSTOM             ?=

IMAGE_ID_FILE            ?= $(IMAGE_DIR)/image_id

ifeq ($(IMAGE_ENABLE),true)
$(call check_defined, IMAGE_NAME, image enabled but no image name provided)
$(call check_defined, IMAGE_CONTEXT, image context is required to build the image)
endif

ifndef IMAGE_START_CONTENT
define IMAGE_START_CONTENT
#!/usr/bin/env sh

$(IMAGE_COMMANDS)
endef
export IMAGE_START_CONTENT
endif

# If you want to define your own custom content
# you can use the `override define IMAGE_DOCKERFILE_CONTENT`
# directive.
ifndef IMAGE_DOCKERFILE_CONTENT
define IMAGE_DOCKERFILE_CONTENT
FROM $(IMAGE_BASE)
RUN apk add --no-cache ca-certificates tzdata

$(IMAGE_CUSTOM)

COPY $(RELEASE_DIR)/*$(IMAGE_PLATFORM)* /opt/bin/
COPY start /opt/bin/start
WORKDIR /opt/bin
CMD /opt/bin/start
endef
export IMAGE_DOCKERFILE_CONTENT
endif

$(IMAGE_DOCKERFILE): $(IMAGE_DIR)
ifeq ($(IMAGE_FORCE_REBUILD),true)
	-rm -f $(STARTUP_FILE)
	echo "$$IMAGE_START_CONTENT" > $(IMAGE_START_FILE)
	chmod +x $(IMAGE_START_FILE)
	$(info Wrote container startup command content to: $(IMAGE_START_FILE))
	-rm -f $(IMAGE_DOCKERFILE)
	echo "$$IMAGE_DOCKERFILE_CONTENT" > $(IMAGE_DOCKERFILE)
	$(info Wrote container dockerfile content to: $(IMAGE_DOCKERFILE))
endif
.PHONY: $(IMAGE_DOCKERFILE)

ifeq ($(IMAGE_ENABLE),true)
## Create a container image
##
## This will create a container image of your go application
##
## Requirements:
##
##	IMAGE_NAME
##		The name of the built container image, this is the name you
##		can use to run containers, e.g., IMAGE_NAME:latest
##
##	IMAGE_DOCKERFILE
##		This is the Dockerfile for the image, you can either generate
##		it using the provided example patterns, or reference an image
##		in your repository
##
##	IMAGE_FORCE_REBUILD
##		The default is set to 'true' and the container image will
##		therefore always be rebuilt, this means the IMAGE_DOCKERFILE
##		will be removed and generated using IMAGE_DOCKERFILE_CONTENT
##		as a starting point for gathering the content.
##
## Generate:
##
##	In the definition below, we demonstrate how it is possible to generate
##	the dockerfile content by using a set of variables that are embedded
##	into a structure of define's. This allows us to use the output of
##	the release stage to dynamically create a container image. As such,
##	another option is to define the following sections:
##
##	Optional:
##
##	IMAGE_BASE
##		Populates the FROM section of the Dockerfile
##	Default: alpine
##
##	IMAGE_PLATFORM
##		Will copy in the binaries from the release directory that match
##		the provided architecture
##	Default: linux
##
##	IMAGE_START_FILE
##		The file that the start script content is written to
##	Default: IMAGE_DIR/start
##
##	IMAGE_START_CONTENT
##		A simple sh script for invoking the  commands
##	Default: see definition below
##
##	IMAGE_DOCKERFILE_CONTENT
##		Creates a generic Dockerfile structure, copying
##		in the binaries to well-known locations, etc.
##	Default: see definition below
##
##	Required:
##
##	IMAGE_COMMANDS
##		The content of this variable will be added to the start script
##		and makes it easier to run multiple commands before starting
##		the primary applicaion. Here you can make use of the RELEASE_VERSION,
##		RELEASE_ARCH and IMAGE_PLATFORM variables to reference your built binaries.
##
##	IMAGE_CUSTOM
##		Here you are free to use any of the Dockerfile commands that you
##		want to, e.g., COPY, ENV, etc.
##
## Override examples:
##
##	make IMAGE_FORCE_REBUILD=false IMAGE_DOCKERFILE=~/app/Dockerfile container
##		Skips generating the Dockerfile and rather uses the provided
##		Dockerfile. This will still invoke the 'release' target, so the
##		binaries will still be built
##
##	make IMAGE_NAME=test container
##		Will generate the Dockerfile, but give it a different name, this
##		can be combined with the previous example and the RELEASE_BINARIES command
##		for example to control the creation of various containers
##
##
image: RELEASE_PLATFORMS = $(IMAGE_PLATFORM)
image: $(IMAGE_DOCKERFILE) docker release
	$(foreach c,$(IMAGE_CONTEXT), \
		mkdir -p `dirname $(IMAGE_DIR)/$(c)` && cp -R $(c) $(IMAGE_DIR)/$(c) && ) true
	docker build --tag $(IMAGE_NAME) --file $(IMAGE_DOCKERFILE) --network bridge $(IMAGE_DIR)
	docker images -q $(IMAGE_NAME) > $(IMAGE_ID_FILE)
else
image:
	$(skip)
endif
.PHONY: image

up-%: dockercompose
	$(info starting compose container $(*))
	$(DOCKERCOMPOSE) up -d $(*)
.PHONY: up-%

## display the identifier of a docker-compose service name
##
## e.g., `make id-postgres`
id-%: dockercompose
	$(eval .COMPOSE_IDS := $(shell $(DOCKERCOMPOSE) ps -q $(*)))
	$(info compose container id $(*): $(.COMPOSE_IDS))
.PHONY: id-%

## check the docker-compose file to see if it is compatible
compose-config-check: dockercompose
	docker-compose config -q
.PHONY: compose-config-check

## stop all compose managed containers
compose-clean: dockercompose
	$(DOCKERCOMPOSE) stop && yes | $(DOCKERCOMPOSE) rm
.PHONY: compose-clean

.COMPOSE_IDS ?=

DEPS_ENABLE           ?= false
DEPS                  ?=
DEPS_HC_START_TIMEOUT ?= 10
DEPS_HC_ITERS         ?= 15
DEPS_HC_ITERS_TIMEOUT ?= 5

ifeq ($(DEPS_ENABLE),true)
$(call check_defined, DEPS, deps enabled but no deps provided)
endif

ifeq ($(DEPS_ENABLE),true)
## Start service container dependencies
##
## Requirements:
##
##	This depends on the presence of a docker compose file using
##	version 2.3 or higher, which supports the 'healthcheck' directive.
##
##	The dependencies are deemed to be up, when the status of the
##	healthcheck is in 'healthy' state
##
## Override examples:
##
##	make DEPS=postgres deps
##		Only bring up the postgres container dependency
##
##   make DEPS=elsearch DEPS_HC_START_TIMEOUT=30
##		Only bring up elasticsearch and give it a 30 second
##		start before polling the healthcheck
##
##
deps: | compose-config-check compose-clean compose-deps-up compose-dep-ids
	$(info Started compose dependencies: $(DEPS))
	$(info Checking health for: $(.COMPOSE_IDS))
	$(call check-health,$(DEPS_HC_START_TIMEOUT),$(DEPS_HC_ITERS),$(DEPS_HC_ITERS_TIMEOUT),$(.COMPOSE_IDS))
else
deps:
	$(skip)
endif
.PHONY: deps

compose-deps-up: dockercompose
	$(DOCKERCOMPOSE) up -d $(DEPS)
.PHONY: compose-deps-up

compose-dep-ids: dockercompose
	$(eval .COMPOSE_IDS := $(shell $(DOCKERCOMPOSE) ps -q $(DEPS)))
.PHONY: compose-dep-ids

# $(call check-health,startup_timeout,iterations,iteration_timeout,identifiers)
#	Inspect the health of the provided docker container identifiers
#   Returns false if the container hasn't reached a healthy state before
#	the iterations have completed.
define check-health
sleep $(1); \
all_healthy=true; \
for id in $(4); do \
	healthy=false; \
	for i in `seq -s " " $(2)`; do \
		if [[ `docker inspect --format='{{.State.Health.Status}}' $$id` == healthy ]]; then \
			healthy=true; \
			break; \
		else \
			sleep $(3); \
		fi; \
	done; \
	if [[ $$healthy == false ]]; then \
		all_healthy=false; \
		break; \
	fi; \
done; \
if [[ $$all_healthy == false ]]; then \
	false; \
fi
endef

MIGRATE_ENABLE ?= false
MIGRATE_NAME   ?=

ifeq ($(MIGRATE_ENABLE),true)
$(call check_defined, MIGRATE_NAME, migrate enabled but the migrate name is not defined)
endif

ifeq ($(MIGRATE_ENABLE),true)
## Do migrations as part of starting the service
migrate:
	$(DOCKERCOMPOSE) run $(MIGRATE_NAME)
else
migrate:
	$(skip)
endif
.PHONY: migrate

SERVICE_ENABLE           ?= false
SERVICE_NAME             ?=
SERVICE_HC_START_TIMEOUT ?= 30
SERVICE_HC_ITERS         ?= 15
SERVICE_HC_ITERS_TIMEOUT ?= 5
SERVICE_RESTART          ?=

ifeq ($(SERVICE_ENABLE),true)
$(call check_defined, SERVICE_NAME, service enabled but no name provided)
endif

ifeq ($(SERVICE_ENABLE),true)
## Restart the service
##
## This will build the binary again, package a new image
## and start the service with the updated binary, it
## will not touch the service dependencies, so any
## state they have recorded will remain.
##
## It is possible to check the SERVICE_RESTART
## variable to disable things downstream
## that you only want to have as part of the
## initial setup
service-restart: SERVICE_RESTART = true
service-restart: | image up-$(SERVICE_NAME) id-$(SERVICE_NAME)
	$(info Restarting service: $(SERVICE_NAME))
	$(info Checking health for: $(.COMPOSE_IDS))
	$(call check-health,$(SERVICE_HC_START_TIMEOUT),$(SERVICE_HC_ITERS),$(SERVICE_HC_ITERS_TIMEOUT),$(.COMPOSE_IDS))
else
service-restart:
	$(skip)
endif
.PHONY: service-restart

ifeq ($(SERVICE_ENABLE),true)
## Start the service container
##
## Requirements:
##
##	For this to work, you need to use the image built
##	by the 'container' command in your docker compose file,
##   e.g, the output of `make show-IMAGE_NAME` will tell you
##	what you need to call it. In addition, the SERVICE_NAME
##	below, must match the name of the service in the docker
##	compose file that uses that image.
##
## Override examples:
##
##	make SERVICE_HC_START_TIMEOUT=20 run
##		Run the service container and wait 20 seconds
##		before checking the health status
##
service: | deps migrate image up-$(SERVICE_NAME) id-$(SERVICE_NAME)
	$(info Started compose application: $(SERVICE_NAME))
	$(info Checking health for: $(.COMPOSE_IDS))
	$(call check-health,$(SERVICE_HC_START_TIMEOUT),$(SERVICE_HC_ITERS),$(SERVICE_HC_ITERS_TIMEOUT),$(.COMPOSE_IDS))
else
service:
	$(skip)
endif
.PHONY: service

SERVICE_REMOTE_ENABLE       ?= false
SERVICE_REMOTE_NAME         ?= $(SERVICE_NAME)
SERVICE_REMOTE_COMPOSE_FILE ?= docker-compose.yml
SERVICE_RM_HC_START_TIMEOUT ?= 10
SERVICE_RM_HC_ITERS         ?= 10
SERVICE_RM_HC_ITERS_TIMEOUT ?= 5

ifeq ($(SERVICE_REMOTE_ENABLE),true)
$(call check_defined, SERVICE_REMOTE_COMPOSE_FILE, service remote enabled but no base compose file provided)
$(call check_defined, SERVICE_REMOTE_NAME, service remote enabled but no name provided)
endif

ifeq ($(SERVICE_REMOTE_ENABLE),true)
## Run the service using the latest container image created by travis
##
## Instead of building and running a local container, this command will pull
## the latest image for your service from the docker registry you have defined.
##
## This requires that you use a base docker-compose.yml and use a
## docker-compose.override.yml file, where the later pulls from your local docker registry
## when using 'make service'.
service-remote: | deps migrate service-remote-pull service-remote-start service-remote-id
	$(call check-health,$(SERVICE_RM_HC_START_TIMEOUT),$(SERVICE_RM_HC_ITERS),$(SERVICE_RM_HC_ITERS_TIMEOUT),$(.COMPOSE_IDS))
	$(info service started)
else
service-remote:
	$(skip)
endif
.PHONY: service-remote

service-remote-pull:
	$(DOCKERCOMPOSE) -f $(SERVICE_REMOTE_COMPOSE_FILE) pull $(SERVICE_REMOTE_NAME)
.PHONY: service-remote-pull

service-remote-start:
	$(DOCKERCOMPOSE) -f $(SERVICE_REMOTE_COMPOSE_FILE) up -d $(SERVICE_REMOTE_NAME)
.PHONY: service-remote-start

service-remote-id:
	$(eval .COMPOSE_IDS := $(shell $(DOCKERCOMPOSE) -f $(SERVICE_REMOTE_COMPOSE_FILE) ps -q $(SERVICE_REMOTE_NAME)))
.PHONY: service-remote-id

ifeq ($(SERVICE_REMOTE_ENABLE),true)
## Stop the remote service and its dependencies
##
## This will stop and remove all running containers
## related to the service
service-remote-stop:
	$(DOCKERCOMPOSE) -f $(SERVICE_REMOTE_COMPOSE_FILE) down
else
service-remote-stop:
	$(skip)
endif
.PHONY: service-remote-stop

SERVICE_PUBLISH_ENABLE ?= false
SERVICE_PUBLISH_TAG    ?=
SERVICE_PUBLISH_URL    ?=
SERVICE_PUBLISH_USER   ?= $(ARTIFACTORY_USER)
SERVICE_PUBLISH_PWD    ?= $(ARTIFACTORY_PWD)

ifeq ($(SERVICE_PUBLISH_ENABLE),true)
$(call check_defined, SERVICE_PUBLISH_TAG, service publish enabled but no remote tag provided)
$(call check_defined, IMAGE_NAME, service publish enabled but no image name provided)
endif

ifdef TRAVIS_PULL_REQUEST
ifneq ($(TRAVIS_PULL_REQUEST), false)
$(info disabling service publish since this is a travis pull request)
SERVICE_PUBLISH_ENABLE = false
endif
endif

ifdef TRAVIS_BRANCH
ifneq ($(TRAVIS_BRANCH), master)
$(info disabling service publish since the travis branch is not master)
SERVICE_PUBLISH_ENABLE = false
endif
endif

ifeq ($(SERVICE_PUBLISH_ENABLE),true)
## Publish the image of the service to a docker registry
##
## This image can then be referenced in the base docker-compose.yml
## file of your project and used in conjunction with the 'make service-remote'
## command.
service-publish: guard-SERVICE_PUBLISH_USER guard-SERVICE_PUBLISH_PWD | image
	docker login -u $(SERVICE_PUBLISH_USER) -p $(SERVICE_PUBLISH_PWD) $(SERVICE_PUBLISH_URL)
	docker tag `cat $(IMAGE_ID_FILE)` $(SERVICE_PUBLISH_URL)/$(SERVICE_PUBLISH_TAG)
	docker push $(SERVICE_PUBLISH_URL)/$(SERVICE_PUBLISH_TAG)
else
service-publish:
	$(skip)
endif
.PHONY: service-publish

PACKAGE_ENABLE    ?= false
PACKAGE_TYPE      ?= rpm
PACKAGE_TIMESTAMP ?= $(shell git rev-list --max-count=1 --timestamp HEAD | awk '{print $$1}')
PACKAGE_NAME      ?=
PACKAGE_FILES     ?=
PACKAGE_DEPS      ?=
PACKAGE_AFTER     ?=

ifeq ($(PACKAGE_ENABLE),true)
$(call check_defined, PACKAGE_NAME, package enabled but no name provided)
$(call check_defined, PACKAGE_FILES, package enabled but no files will be added)
endif

ifeq "$(origin TRAVIS_BUILD_NUMBER)" "environment"
RELEASE_BUILD_NUMBER = $(TRAVIS_BUILD_NUMBER)
endif

# $(call .build_rpm, package_name, version, dist_dir, iteration, epoch, deps, after_install, files)
#	Create an RPM package using the provided inputs
define build_rpm
fpm -f -s dir  \
	--verbose \
	-t rpm -n $(1) \
	-v $(2) -p $(3) \
	--iteration $(4) \
	--epoch $(5) \
	-a x86_64 \
	$(foreach dep,$(6),-d $(dep)) \
	$(if $(7),--after-install $(7)) \
	$(foreach f,$(8),$(f))
endef

# $(call .build_deb)
#	Throw a not-implemented error
define build_deb
$(error building of a deb package hasn't been implemented)
endef

ifeq ($(PACKAGE_ENABLE),true)
## Create an installable package, e.g., deb or rpm
##
## Override examples:
##
##	make PACKAGE_TYPE=deb package
##		Create a debian package instead of the default rpm package
##
##	make PACKAGE_NAME=api package
##		Give the package a different name
##
##
package: $(DIST_DIR) fpm | release
	-rm -f $(DIST_DIR)/*.$(PACKAGE_TYPE)
ifeq ($(PACKAGE_TYPE),rpm)
	$(call build_rpm,$(PACKAGE_NAME),$(RELEASE_VERSION),$(DIST_DIR),\
	$(RELEASE_BUILD_NUMBER),$(PACKAGE_TIMESTAMP),$(PACKAGE_DEPS),$(PACKAGE_AFTER),$(PACKAGE_FILES))
else
ifeq ($(PACKAGE_TYPE),deb)
	$(call build_deb)
else
	$(error unknown package type)
endif
endif
else
package:
	$(skip)
endif
.PHONY: package

$(DIST_DIR)/%.rpm: rpm
	rpm -qlp $@
.PHONY: $(DIST_DIR)/%.rpm

$(DIST_DIR)/%.deb: dpkg
	dpkg-deb --info $@
.PHONY: $(DIST_DIR)/%.deb

## Show some basic information about the package content
##
## Override examples:
##
##	make PACKAGE_TYPE=deb inspect
##		Inspect built debian packages
##
##	make PACKAGE_TYPE=rpm inspect
##		Inspect built rpm packages
##
##
inspect: $(DIST_DIR)/*.$(PACKAGE_TYPE)
.PHONY: inspect

PUBLISH_ENABLE             ?= false
ARTIFACTORY_URL            ?=
ARTIFACTORY_REMOTE_PROJECT ?=
ARTIFACTORY_REMOTE_BASE    ?=
ARTIFACTORY_USER           ?=
ARTIFACTORY_PWD            ?=

ifndef ARTIFACTORY_REMOTE_BASE
ifeq ($(PACKAGE_TYPE),rpm)
ARTIFACTORY_REMOTE_BASE = yum-ephemeral
else
ifeq ($(PACKAGE_TYPE),deb)
ARTIFACTORY_REMOTE_BASE = debian-ephemeral
else
$(error unkown package type '$(PACKAGE_TYPE)' unable to set artifactory remote base)
endif
endif
endif

ifdef TRAVIS_PULL_REQUEST
ifneq ($(TRAVIS_PULL_REQUEST), false)
$(info disabling artifactory deploy since this is a travis pull request)
PUBLISH_ENABLE = false
endif
endif

ifdef TRAVIS_BRANCH
ifneq ($(TRAVIS_BRANCH), master)
$(info disabling artifactory deploy since the travis branch is not master)
PUBLISH_ENABLE = false
endif
endif

guard-%:
	@ if [ "${${*}}" = "" ]; then \
		echo "Environment variable $* not set"; \
		exit 1; \
	fi
.PHONY: guard-%

ifeq ($(PUBLISH_ENABLE),true)
## Upload a built artifact to artifactory
##
## Override examples:
##
##	make PACKAGE_TYPE=deb ARTIFACTORY_REMOTE_PROJECT=devrel/test publish
##		Create a debian package, and write it to devrel/test
##	make ARTIFACTORY_USER=someone@something.com ARTIFACTORY_PWD=password publish
##		Use the provided artifactory user and password
##
##
publish: guard-ARTIFACTORY_USER guard-ARTIFACTORY_PWD jfrog | package
	JFROG_CLI_OFFER_CONFIG=false jfrog rt u $(DIST_DIR)/*.$(PACKAGE_TYPE) $(ARTIFACTORY_REMOTE_BASE)/$(ARTIFACTORY_REMOTE_PROJECT) --user=$(ARTIFACTORY_USER) --apikey=$(ARTIFACTORY_PWD) --url=$(ARTIFACTORY_URL)
else
publish:
	$(skip)
endif
.PHONY: publish

## Bring down all containers and remove any content in the build directory
clean: go compose-config-check compose-clean
	-rm -rf $(BUILD_DIR)/*
	go clean
.PHONY: clean

INSTALL_ENABLE ?= false
INSTALL_FILES  ?=

ifeq ($(INSTALL_ENABLE),true)
$(call check_defined, INSTALL_FILES, install enabled but no files provided)
endif

ifeq ($(INSTALL_ENABLE),true)
## Install the provided commands
install: go $(GOPATH)
	$(foreach cmd,$(INSTALL_CMDS),go install -v $(cmd))
else
install:
	$(skip)
endif
.PHONY: install

## Show a list of all available targets
list:
	@$(MAKE) -rpn | sed -n -e '/^$$/ { n ; /^[^ .##][^ ]*:/ { s/:.*$$// ; p ; } ; }' | sort -u
.PHONY: list

## Print the content of an evaluated variable
##
## Examples:
##
##	make show-RELEASE_VERSION
##		Will print out the RELEASE_VERSION used throughout
##	make show-DIST_DIR
##		Print the default distribution directory
##
##
show-%:
	$(info $(*): $($(*)))
.PHONY: show-%

.container-id = $(shell $(DOCKERCOMPOSE) ps -q $(1))

## Get a shell to a running docker-compose container
##
## e.g., `make shell-api`
shell-%:
	docker exec -it $(call .container-id,$(*)) /bin/sh
.PHONY: shell-%

## Read the logs of a docker-compose container
##
## e.g., `make logs-api`
logs-%:
	docker logs $(call .container-id,$(*))
.PHONY: logs-%

## Print out help
##
## Display a short description for all targets
help: $(MAKEDOC)
	@echo "Go Project Targets"
	@echo ""
	@echo "Run 'make help-verbose' for verbose help for all targets"
	@echo "Run 'make help-[target]' for verbose help for a specific target"
	@echo ""
	@echo "Run 'make list' to show all targets, including those that aren't documented"
	@echo ""
	@$(MAKEDOC) -pretty $(MAKEFILE_LIST)
.PHONY: help

## Print help verbose
##
## Dumps the help including long descriptions
help-verbose: $(MAKEDOC)
	@$(MAKEDOC) -pretty -verbose $(MAKEFILE_LIST)
.PHONY: help-verbose

## Display an extensive description for a specific target
##
## Display more extensive help for a given target, e.g.,
## `make help-test`
help-%: $(MAKEDOC)
	@$(MAKEDOC) -pretty -verbose -target $(*) $(MAKEFILE_LIST)
.PHONY: help-%

## For help with debugging visit: https://github.com/paulbes/makedoc
help-debug:
	@echo "For help with debugging visit: https://github.com/paulbes/makedoc
.PHONY: help-debug

## Dump the list of make files that are used in this project
##
## In cases where you want to debug an error in a makefile, you can
## modify the corresponding files directly.
project-files:
	$(foreach f,$(MAKEFILE_LIST),$(info $(f)))
.PHONY: project-files
