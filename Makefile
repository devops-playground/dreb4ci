# Makefile: make(1) build file.

# Default task show help
default: help

.PHONY : clean clear-flags clobber info login logout pull \
	pull_or_build_if_changed push push_if_changed rebuild-all rmi test \
	test-dind usershell

# Normal account inside container
DOCKER_USER ?= dev
DOCKER_USER_UID ?= 8888
DOCKER_USER_GID ?= 8888

# Valid subuid group identifier or name for user namespace restriction
DOCKER_USERNS_GROUP ?= dock-g

# Get Docker info
DOCKER_INFO := $(shell docker info | tr "\n" '|')

# Docker registry settings (credential should be set in environment)
DOCKER_REGISTRY ?= $(shell \
	echo "$(DOCKER_INFO)" \
		| tr "\n" '|' \
		| sed -e 's~^.*|Registry: \(https\?://[^|]*\)|.*$$~\1~g' \
	)
DOCKER_REGISTRY_HOST ?= $(shell \
	echo "${DOCKER_REGISTRY}" \
		| sed -e 's|^https\?://||' -e 's|/.*$$||' \
	)
DOCKER_USERNAME ?= dumb
DOCKER_PASSWORD ?=

# Infer project root directory path and set project name if not defined
PROJECT_ROOT := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
PROJECT_NAME ?= $(notdir $(PROJECT_ROOT))
PROJECT_OWNER ?= ${DOCKER_USERNAME}

# Define working directory inside container
WORKING_DIR ?= /src/${PROJECT_NAME}

# Define Docker build tag to project name if not set
CURRENT_GIT_BRANCH = \
	$(shell basename $$(git symbolic-ref --short HEAD || printf ''))
DOCKER_BUILD_TAG_BASE = ${PROJECT_OWNER}/${PROJECT_NAME}
ifeq ($(CURRENT_GIT_BRANCH),)
	DOCKER_BUILD_TAG ?= ${DOCKER_BUILD_TAG_BASE}
else
	DOCKER_BUILD_TAG ?= ${DOCKER_BUILD_TAG_BASE}:${CURRENT_GIT_BRANCH}
endif

# Retrieve processor count (for Linux and OsX only)
UNAME = $(shell uname)
ifeq ($(UNAME),Darwin)
	NB_PROC ?= $(shell sysctl -n hw.ncpu)
else
	NB_PROC ?= $(shell nproc)
endif

# Docker build arguments
BUILD_ARGS = \
	--build-arg "DOCKER_USER=${DOCKER_USER}" \
	--build-arg "DOCKER_USER_GID=${DOCKER_USER_GID}" \
	--build-arg "DOCKER_USER_UID=${DOCKER_USER_UID}" \
	--build-arg "NB_PROC=${NB_PROC}"

# Docker run environment variables
ENV_VARS = \
	--env "MAKEFLAGS=-j ${NB_PROC}" \
	--env container=docker \
	--env LC_ALL=C.UTF-8

# Propagate TERM if defined
ifneq ($(TERM),)
	ENV_VARS += --env "TERM=${TERM}"
endif

# Other overridable build arguments
OVERRIDABLE_BUILD_ARGS := \
	DEB_COMPONENTS \
	DEB_DIST \
	DEB_DOCKER_GPGID \
	DEB_DOCKER_URL \
	DEB_MIRROR_URL \
	DEB_PACKAGES \
	DEB_SECURITY_MIRROR_URL \
	HTTP_PROXY

define add_to_build_args
	ifdef ${1}
		BUILD_ARGS += --build-arg "${1}=$(${1})"
	endif
endef

$(foreach v,$(OVERRIDABLE_BUILD_ARGS),$(eval $(call add_to_build_args,$v)))

# Other overridable environment variables
OVERRIDABLE_ENV_VARS := \
	CI \
	CIRCLECI \
	DOCKER_BUILD_TAG \
	DOCKER_PASSWORD \
	DOCKER_REGISTRY \
	DOCKER_USERNAME \
	GITLAB_CI \
	HTTP_PROXY \
	MAKEFLAGS \
	PROJECT_NAME \
	PROJECT_OWNER \
	TRAVIS \
	TZ \
	WORKING_DIR

define add_to_env_vars
	ifdef ${1}
		ENV_VARS += --env "${1}=$(${1})"
	endif
endef

$(foreach v,$(OVERRIDABLE_ENV_VARS),$(eval $(call add_to_env_vars,$v)))

# Normal account args
USER_MODE_ARG := \
	--user ${DOCKER_USER} \
	--env USER=${DOCKER_USER} \
	--env HOME=/home/${DOCKER_USER}

# Check if user namespace is activated
USERNS ?= $(shell \
	echo "$(DOCKER_INFO)" \
		| tr "\n" '|' \
		| sed -e 's/^.*| userns|.*$$/yes/g' \
	)

# Check if user is root
USER_UID := $(shell id -u)

# Set privileged if no user namespace remap and run docker with sudo if not root
DOCKER_SUDO :=
DOCKER_SUDO_S :=
ifneq ($(USERNS),yes)
	DOCKER_SUDO_S := sudo -S
	ifneq ($(USER_UID),0)
		DOCKER_SUDO := sudo
	endif
	USER_MODE_ARG += --privileged
endif

# Add overridable local rc files
LOCAL_RC_FILES ?= \
	.bashrc \
	.gitconfig \
	.inputrc \
	.nanorc \
	.tmux.conf \
	.vimrc

define add_rc_file
	$(eval RC_${1} := $(shell if [ -f "$(HOME)/${1}" ]; then echo Ok; fi))
	ifeq ($(RC_${1}),Ok)
		RC_ENV_VARS += --volume "$(HOME)/${1}:/home/$(DOCKER_USER)/${1}:ro"
	endif
endef

$(foreach f,$(LOCAL_RC_FILES),$(eval $(call add_rc_file,$f)))

# Define function to build Docker run command line
define docker_cmd
	${DOCKER_SUDO} docker run \
		--hostname ${PROJECT_NAME} \
		--rm \
		--workdir ${WORKING_DIR} \
		--volume ${PROJECT_ROOT}:${WORKING_DIR}:ro \
		--volume /var/run/docker.sock:/var/run/docker.sock:rw \
		${USER_MODE_ARG} \
		${ENV_VARS} \
		${1} \
		${DOCKER_BUILD_TAG} \
		${2}
endef

# Define function to pretty print (without password) and run Docker command line
define docker_run
	( \
		cmd='$(call docker_cmd,${1},${2})' ; \
		cmd=$$(echo $${cmd} | sed -e 's/^[[:space:]]*//g' | tr -d "\t") ; \
		pattern=$(shell printf "${DOCKER_PASSWORD}" | sed -e 's/\//\\/g') ; \
		if [ -n "${DOCKER_PASSWORD}" ]; then \
			printf "\n\033[33;1m$${cmd}\033[0m\n\n" \
			| sed -e "s/$${pattern}/hidden/g" ; \
		else \
			printf "\n\033[33;1m$${cmd}\033[0m\n\n" ; \
		fi ; \
		eval $${cmd} \
	)
endef

# Define function to check if Dockerfile has changed since last commit / master
define dockerfile_changed
	test -n "$$(git diff origin/master -- Dockerfile)" \
		-o -n "$$(git diff HEAD~1 -- Dockerfile)"
endef

# Check Docker daemon experimental features (for build squashing)
DOCKERD_EXPERIMENTAL := \
	$(shell docker version --format '{{ .Server.Experimental }}')

ifeq ($(DOCKERD_EXPERIMENTAL),true)
	BUILD_OPTS := --squash
else
	BUILD_OPTS :=
endif

acl: .acl_build ## Add nested ACLs rights (need sudo)
.acl_build:
	@if [ "$(USERNS)" = 'yes' ]; then \
		cmd='sudo setfacl -Rm g:$(DOCKER_USERNS_GROUP):rwX /var/run/docker.sock' \
			&& printf "\n\033[31;1m$${cmd}\033[0m\n\n" \
			&& $${cmd} ; \
		if [ "$(TMUX_CONF)" = 'Ok' ]; then \
			cmd='sudo setfacl -Rm g:$(DOCKER_USERNS_GROUP):r $(HOME)/.tmux.conf' \
			&& printf "\n\033[31;1m$${cmd}\033[0m\n\n" \
			&& $${cmd} ; \
		fi ; \
	fi
	touch .acl_build

build: .build ## Build project container
.build: Dockerfile
	docker build --rm $(BUILD_OPTS) $(BUILD_ARGS) -t $(DOCKER_BUILD_TAG) \
		--cache-from $(DOCKER_BUILD_TAG) .
	touch .build

clean: FLAG = acl_build
clean: clear-flags ## Clean acls
	find . -type f -name \*~ -delete

clear-flags:
	if [ -n "$(FLAG)" -a -f ".$(FLAG)" ]; then rm ".$(FLAG)"; fi
	if [ -n "$(FLAGS)" ]; then \
		for flag in $(FLAGS); do \
		if [ -f ".$${flag}" ]; then rm ".$${flag}"; fi ; \
		done ; \
	fi

clobber: FLAGS = acl_build build
clobber: clean rmi clear-flags ## Do clean, rmi, remove backup (*~) files
	find . -type f -name \*~ -delete

help: ## Show this help
	@printf '\033[32mtargets:\033[0m\n'
	@grep -E '^[a-zA-Z _-]+:.*?## .*$$' $(MAKEFILE_LIST) \
	| sort \
	| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n",$$1,$$2}'

info: MAKEFLAGS =
info: .build .acl_build ## Show Docker version and user id
	@if [ -n "$(DOCKER_SUDO_S)" ]; then \
		printf "${DOCKER_USER}\n\n" \
		| $(call docker_run,--interactive,$(DOCKER_SUDO_S) docker info) ; \
	else \
		$(call docker_run,,$(DOCKER_SUDO_S) docker info) ; \
	fi
	@$(call docker_run,,id)

login: ## Login to Docker registry
	@echo "login to registry $(DOCKER_USERNAME) @ ${DOCKER_REGISTRY}"
	@docker login \
		--username="$(DOCKER_USERNAME)" \
		--password="$(DOCKER_PASSWORD)" \
		$(DOCKER_REGISTRY) || ( \
			printf "\n\033[31;1mDOCKER_(USERNAME/PASSWORD) must be set\033[0m\n\n" ; \
			exit 2 \
		)

logout: ## Logout from Docker registry
	docker logout $(DOCKER_REGISTRY)

pull: ## Run 'docker pull' with image
	docker pull $(DOCKER_REGISTRY_HOST)/$(DOCKER_BUILD_TAG)
	docker tag $(DOCKER_REGISTRY_HOST)/$(DOCKER_BUILD_TAG) $(DOCKER_BUILD_TAG)
	touch .build

pull_or_build_if_changed:
	+if $(call dockerfile_changed); then \
		make build; \
	else \
		( make login && make pull ) || make build ; \
	fi

push: login .build ## Run 'docker push' with image
	docker tag $(DOCKER_BUILD_TAG) $(DOCKER_REGISTRY_HOST)/$(DOCKER_BUILD_TAG)
	docker push $(DOCKER_REGISTRY_HOST)/$(DOCKER_BUILD_TAG)

pull_then_push_to_latest: login
	@if [ "x${CURRENT_GIT_BRANCH}" != 'xbootstrap' \
		-a "x${CURRENT_GIT_BRANCH}" != 'xmaster' ]; then \
			exit 0 ; \
	fi
	@make --no-print-directory pull
	docker tag "$(DOCKER_REGISTRY_HOST)/${DOCKER_BUILD_TAG}" \
		"${DOCKER_BUILD_TAG_BASE}:latest"
	@DOCKER_BUILD_TAG="${DOCKER_BUILD_TAG_BASE}" make --no-print-directory push

rmi: FLAG = build
rmi: clear-flags ## Remove project container
	-docker rmi -f $(DOCKER_BUILD_TAG)

rebuild-all: MAKEFLAGS =
rebuild-all: ## Clobber all, build and run test
	@make --no-print-directory clobber
	@make --no-print-directory test

test-dind: .build .acl_build ## Run 'docker run hello-world' within image
	@if [ -n "$(DOCKER_SUDO_S)" ]; then \
		printf "${DOCKER_USER}\n\n" \
		| $(call docker_run,-i,$(DOCKER_SUDO_S) docker run hello-world) ; \
	else \
		$(call docker_run,,$(DOCKER_SUDO_S) docker run hello-world) ; \
	fi

test: MAKEFLAGS =
test: .build .acl_build ## Test (CI)
	@make --no-print-directory info
	@make --no-print-directory test-dind

usershell: .build .acl_build ## Run user shell
	$(call docker_run,-it --env SHELL=/bin/bash $(RC_ENV_VARS),/bin/bash --login)
