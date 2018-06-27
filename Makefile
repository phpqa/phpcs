###
##. Configuration
###

THIS_MAKEFILE = $(lastword $(MAKEFILE_LIST))
THIS_MAKE = $(MAKE) --file $(THIS_MAKEFILE)
THIS_DIRECTORY = $(shell basename "$(shell pwd)")

DOCKER_REPO = local/$(shell basename "$(shell pwd)")
DOCKERFILE_PATH = Dockerfile
DOCKER_COMPOSE_FILE_PATH = docker-compose.test.yml
DOCKERFILE_VERSION := $(shell sed -n "s/ARG VERSION=\"\(.*\)\"/\1/p" $(DOCKERFILE_PATH))
DOCKERFILE_BASE_IMAGE := $(shell sed -n "s/ARG BASE_IMAGE=\"\(.*\)\"/\1/p" $(DOCKERFILE_PATH) | sed -e '1 s/:/-/; t')
DOCKERFILE_TAG := $(shell printf "$(DOCKERFILE_VERSION)-on-$(DOCKERFILE_BASE_IMAGE)")

COMMAND_SHORT_PROGRAM_ONLY = $(THIS_DIRECTORY)
COMMAND_LONG_PROGRAM_ONLY = /composer/vendor/bin/$(COMMAND_SHORT_PROGRAM_ONLY)
COMMAND_FLAG_ONLY = --version
COMMAND_SHORT_PROGRAM_WITH_FLAG = $(COMMAND_SHORT_PROGRAM_ONLY) $(COMMAND_FLAG_ONLY)
COMMAND_LONG_PROGRAM_WITH_FLAG = $(COMMAND_LONG_PROGRAM_ONLY) $(COMMAND_FLAG_ONLY)
COMMAND_FOR_VERSION = $(COMMAND_SHORT_PROGRAM_ONLY) --version

STYLE_RESET = \033[0m
STYLE_TITLE = \033[1;33m
STYLE_ERROR = \033[31m
STYLE_SUCCESS = \033[32m
STYLE_DIM = \033[2m

###
## About
###

.PHONY: help version
.DEFAULT_GOAL: help

# Print this documentation
help:

	@ \
		regexp=$$(                                                                                                     \
			$(THIS_MAKE) --print-data-base --no-builtin-rules --no-builtin-variables : 2>/dev/null                     \
			| awk '/^[a-zA-Z0-9_%-]+:/{ if (skipped) printf "|"; printf "^%s", $$1; skipped=1 }'                       \
		);                                                                                                             \
		awk -v pattern="$${regexp}" '                                                                                  \
			{ if (/^## /) { printf "\n%s\n",substr($$0,4); next } }                                                    \
			{ if ($$0 ~ pattern && doc) { gsub(/:.*/,"",$$1); printf "\033[36m%-40s\033[0m %s\n", $$1, doc; } }        \
			{ if (/^# /) { doc=substr($$0,3,match($$0"# TODO",/# TODO/)-3) } else { doc="No documentation" } }         \
			{ if (/^#\. /) { doc="" } }                                                                                \
			{ gsub(/#!/,"\xE2\x9D\x97 ",doc) }                                                                         \
		' $(THIS_MAKEFILE);
	@printf "\\n"

# Print the version
version:

	@date -r $(THIS_MAKEFILE) +"%d/%m/%Y %H:%M:%S"

###
## Build & Clean
###

.PHONY: master-branch-image clean-master-branch-image \
		tag-%-image clean-tag-%-image \
		docker-compose-test-image clean-docker-compose-test-image

# Build an image from the master branch
master-branch-image:

	@printf "$(STYLE_TITLE)Building an image from the master branch $(STYLE_RESET)\\n"
	@ \
		SOURCE_BRANCH="master" \
		SOURCE_COMMIT="this is not a commit" \
		COMMIT_MSG="this is not a commit message" \
		DOCKER_REPO="$(DOCKER_REPO)" \
		DOCKERFILE_PATH="$(DOCKERFILE_PATH)" \
		CACHE_TAG="" \
		IMAGE_NAME="$(DOCKER_REPO):latest" \
		sh ./hooks/build

# Clean the image from the master branch
clean-master-branch-image:

	@printf "$(STYLE_TITLE)Removing the image from the master branch $(STYLE_RESET)\\n"
	@docker rmi $(DOCKER_REPO):latest

# Build an image from the tag "%"
tag-%-image:

	$(eval $@_TAG := $(patsubst tag-%-image,%,$@))
	@printf "$(STYLE_TITLE)Building an image from the tag $($@_TAG) $(STYLE_RESET)\\n"
	@ \
		SOURCE_BRANCH="$($@_TAG)" \
		SOURCE_COMMIT="this is not a commit" \
		COMMIT_MSG="this is not a commit message" \
		DOCKER_REPO="$(DOCKER_REPO)" \
		DOCKERFILE_PATH="$(DOCKERFILE_PATH)" \
		CACHE_TAG="" \
		IMAGE_NAME="$(DOCKER_REPO):$($@_TAG)" \
		sh ./hooks/build

# Clean the image from the tag "%"
clean-tag-%-image:

	$(eval $@_TAG := $(patsubst clean-tag-%-image,%,$@))
	@printf "$(STYLE_TITLE)Removing the image from the tag $($@_TAG) $(STYLE_RESET)\\n"
	@docker rmi $(DOCKER_REPO):$($@_TAG)

# Build an image from the docker-compose.test.yml file
docker-compose-test-image:

	@printf "$(STYLE_TITLE)Building an image from the $(DOCKER_COMPOSE_FILE_PATH) file $(STYLE_RESET)\\n"
	@export IMAGE_NAME="$(DOCKER_REPO):$(DOCKERFILE_TAG)"; \
		docker-compose --file $(DOCKER_COMPOSE_FILE_PATH) --project-name $(THIS_DIRECTORY) build

	@printf "$(STYLE_TITLE)Running the image from the $(DOCKER_COMPOSE_FILE_PATH) file $(STYLE_RESET)\\n"
	@docker-compose --file $(DOCKER_COMPOSE_FILE_PATH) --project-name $(THIS_DIRECTORY) --no-ansi up --detach
	@docker logs -f $(THIS_DIRECTORY)_sut_1

# Clean the image from the docker-compose.test.yml file
clean-docker-compose-test-image:

	@printf "$(STYLE_TITLE)Removing the image from the $(DOCKER_COMPOSE_FILE_PATH) file $(STYLE_RESET)\\n"
	@docker-compose --file $(DOCKER_COMPOSE_FILE_PATH) --project-name $(THIS_DIRECTORY) down --rmi all --volumes

###
## Tests
###

.PHONY: test-master-branch-image test-tag-%-image test-docker-compose-image \
		tests-verbose tests

status_after_run = result="$$($(1) 2>&1)"; if test "$$?" = "0"; then printf '$(STYLE_SUCCESS)\342\234\224$(STYLE_RESET)\n'; else printf '$(STYLE_ERROR)\342\234\226$(STYLE_RESET)\n%s' "$${result}"; exit 1; fi

# Test the image from the master branch
test-master-branch-image:

	$(eval $@_TAG := latest)
	$(eval $@_IMAGE_NAME := $(DOCKER_REPO):$($@_TAG))

	@printf "$(STYLE_TITLE)Running tests for master branch $(STYLE_RESET)\\n"

	@printf "Image \"%s\" was built: " "$($@_IMAGE_NAME)"
	@$(call status_after_run, test -n "$$(docker image ls $($@_IMAGE_NAME) --quiet)")

	@printf "Image \"%s\" contains label \"org.label-schema.version\" with version \"$(DOCKERFILE_VERSION)\": " "$($@_IMAGE_NAME)"
	@$(call status_after_run, \
		docker inspect --format "{{ index .Config.Labels \"org.label-schema.version\" }}" $$(docker images $($@_IMAGE_NAME) --quiet) \
			| grep --quiet "\b$(DOCKERFILE_VERSION)\b" \
	)

	@printf "Image \"%s\" contains label \"org.label-schema.docker.cmd\" with tag \"$($@_TAG)\": " "$($@_IMAGE_NAME)"
	@$(call status_after_run, \
		docker inspect --format "{{ index .Config.Labels \"org.label-schema.docker.cmd\" }}" $$(docker images $($@_IMAGE_NAME) --quiet) \
			| grep --quiet "\b$($@_TAG)\b" \
	)

	@printf "Container understands full command with flag (%s): " \
		"docker run --rm $($@_IMAGE_NAME) $(COMMAND_LONG_PROGRAM_WITH_FLAG)"
	@$(call status_after_run, docker run --rm $($@_IMAGE_NAME) $(COMMAND_LONG_PROGRAM_WITH_FLAG))

	@printf "Container understands command with flag (%s): " \
		"docker run --rm $($@_IMAGE_NAME) $(COMMAND_SHORT_PROGRAM_WITH_FLAG)"
	@$(call status_after_run, docker run --rm $($@_IMAGE_NAME) $(COMMAND_SHORT_PROGRAM_WITH_FLAG))

	@printf "Container understands only a flag (%s): " \
		"docker run --rm $($@_IMAGE_NAME) $(COMMAND_FLAG_ONLY)"
	@$(call status_after_run, docker run --rm $($@_IMAGE_NAME) $(COMMAND_FLAG_ONLY))

	@printf "Container understands command in the label \"org.label-schema.docker.cmd\" (%s): " \
		"$$(docker inspect --format "{{ index .Config.Labels \"org.label-schema.docker.cmd\" }} $(COMMAND_SHORT_PROGRAM_WITH_FLAG)" $$(docker images $($@_IMAGE_NAME) --quiet))"
	@$(call status_after_run, \
		$$( \
			docker inspect --format "{{ index .Config.Labels \"org.label-schema.docker.cmd\" }} $(COMMAND_SHORT_PROGRAM_WITH_FLAG)" $$(docker images $($@_IMAGE_NAME) --quiet) \
				| sed 's#$${PWD}#$(pwd)#' \
		) \
	)

	@printf "Container understands other commands (%s): " \
		"docker run --rm $($@_IMAGE_NAME) test -f \"$(COMMAND_LONG_PROGRAM_ONLY)\""
	@$(call status_after_run, docker run --rm $($@_IMAGE_NAME) test -f "$(COMMAND_LONG_PROGRAM_ONLY)")

	@printf "Container understands entrypoint override (%s): " \
		"docker run --rm --entrypoint \"\" $($@_IMAGE_NAME) $(COMMAND_LONG_PROGRAM_WITH_FLAG)"
	@$(call status_after_run, docker run --rm --entrypoint "" $($@_IMAGE_NAME) $(COMMAND_LONG_PROGRAM_WITH_FLAG))

	@printf "Container version contains \"$(DOCKERFILE_VERSION)\": "
	@$(call status_after_run, \
		(docker run --rm $($@_IMAGE_NAME) $(COMMAND_FOR_VERSION) || true) 2>/dev/null \
			| grep --quiet "$(DOCKERFILE_VERSION)" \
	)

# Test the image from the tag "%"
test-tag-%-image:

	$(eval $@_TAG := $(patsubst test-tag-%-image,%,$@))
	$(eval $@_TAG_VERSION := $(shell printf "$($@_TAG)" | awk -F "-on-" '{print $$1}'))
	$(eval $@_IMAGE_NAME := $(DOCKER_REPO):$($@_TAG))

	@printf "$(STYLE_TITLE)Running tests for tag $($@_TAG) $(STYLE_RESET)\\n"

	@printf "Image \"%s\" was built: " "$($@_IMAGE_NAME)"
	@$(call status_after_run, test -n "$$(docker image ls $($@_IMAGE_NAME) --quiet)")

	@printf "Image \"%s\" contains label \"org.label-schema.version\" with version \"$($@_TAG_VERSION)\": " "$($@_IMAGE_NAME)"
	@$(call status_after_run, \
		docker inspect --format "{{ index .Config.Labels \"org.label-schema.version\" }}" $$(docker images $($@_IMAGE_NAME) --quiet) \
			| grep --quiet "\b$($@_TAG_VERSION)\b" \
	)

	@printf "Image \"%s\" contains label \"org.label-schema.docker.cmd\" with tag \"$($@_TAG)\": " "$($@_IMAGE_NAME)"
	@$(call status_after_run, \
		docker inspect --format "{{ index .Config.Labels \"org.label-schema.docker.cmd\" }}" $$(docker images $($@_IMAGE_NAME) --quiet) \
			| grep --quiet "\b$($@_TAG)\b" \
	)

	@printf "Container understands command with flag (%s): " \
		"docker run --rm $($@_IMAGE_NAME) $(COMMAND_LONG_PROGRAM_WITH_FLAG)"
	@$(call status_after_run, docker run --rm $($@_IMAGE_NAME) $(COMMAND_LONG_PROGRAM_WITH_FLAG))

	@printf "Container understands command with flag (%s): " \
		"docker run --rm $($@_IMAGE_NAME) $(COMMAND_SHORT_PROGRAM_WITH_FLAG)"
	@$(call status_after_run, docker run --rm $($@_IMAGE_NAME) $(COMMAND_SHORT_PROGRAM_WITH_FLAG))

	@printf "Container understands only a flag (%s): " \
		"docker run --rm $($@_IMAGE_NAME) $(COMMAND_FLAG_ONLY)"
	@$(call status_after_run, docker run --rm $($@_IMAGE_NAME) $(COMMAND_FLAG_ONLY))

	@printf "Container understands command in the label \"org.label-schema.docker.cmd\" (%s): " \
		"$$(docker inspect --format "{{ index .Config.Labels \"org.label-schema.docker.cmd\" }} $(COMMAND_SHORT_PROGRAM_WITH_FLAG)" $$(docker images $($@_IMAGE_NAME) --quiet))"
	@$(call status_after_run, \
		$$( \
			docker inspect --format "{{ index .Config.Labels \"org.label-schema.docker.cmd\" }} $(COMMAND_SHORT_PROGRAM_WITH_FLAG)" $$(docker images $($@_IMAGE_NAME) --quiet) \
				| sed 's#$${PWD}#$(pwd)#' \
		) \
	)

	@printf "Container understands other commands (%s): " \
		"docker run --rm $($@_IMAGE_NAME) test -f \"$(COMMAND_LONG_PROGRAM_ONLY)\""
	@$(call status_after_run, docker run --rm $($@_IMAGE_NAME) test -f "$(COMMAND_LONG_PROGRAM_ONLY)")

	@printf "Container understands entrypoint override (%s): " \
		"docker run --rm --entrypoint \"\" $($@_IMAGE_NAME) $(COMMAND_LONG_PROGRAM_WITH_FLAG)"
	@$(call status_after_run, docker run --rm --entrypoint "" $($@_IMAGE_NAME) $(COMMAND_LONG_PROGRAM_WITH_FLAG))

	@printf "Container version contains \"$($@_TAG_VERSION)\": "
	@$(call status_after_run, \
		(docker run --rm $($@_IMAGE_NAME) $(COMMAND_FOR_VERSION) || true) 2>/dev/null \
			| grep --quiet "$($@_TAG_VERSION)" \
	)

# Test the image from the docker-compose.test.yml file
test-docker-compose-image:

	@printf "$(STYLE_TITLE)Running tests for $(DOCKER_COMPOSE_FILE_PATH) $(STYLE_RESET)\\n"

	@printf "Image \"%s\" was built: " "$(THIS_DIRECTORY)_sut"
	@$(call status_after_run, test -n "$$(docker image ls $(THIS_DIRECTORY)_sut --quiet)")

	@printf "Container can run with the settings from $(DOCKER_COMPOSE_FILE_PATH): "
	@$(call status_after_run, docker wait $(THIS_DIRECTORY)_sut_1)

# Run all tests in verbose mode
tests-verbose:

	@$(THIS_MAKE) --quiet master-branch-image
	@$(THIS_MAKE) --quiet test-master-branch-image
	@$(THIS_MAKE) --quiet clean-master-branch-image

	@$(THIS_MAKE) --quiet tag-$(DOCKERFILE_TAG)-image
	@$(THIS_MAKE) --quiet test-tag-$(DOCKERFILE_TAG)-image
	@$(THIS_MAKE) --quiet clean-tag-$(DOCKERFILE_TAG)-image

	@$(THIS_MAKE) --quiet docker-compose-test-image
	@$(THIS_MAKE) --quiet test-docker-compose-image
	@$(THIS_MAKE) --quiet clean-docker-compose-test-image

# Run all tests
tests:

	@$(THIS_MAKE) --quiet master-branch-image 1> /dev/null
	@$(THIS_MAKE) --quiet test-master-branch-image
	@$(THIS_MAKE) --quiet clean-master-branch-image 1> /dev/null

	@$(THIS_MAKE) --quiet tag-$(DOCKERFILE_TAG)-image 1> /dev/null
	@$(THIS_MAKE) --quiet test-tag-$(DOCKERFILE_TAG)-image
	@$(THIS_MAKE) --quiet clean-tag-$(DOCKERFILE_TAG)-image 1> /dev/null

	@$(THIS_MAKE) --quiet docker-compose-test-image > /dev/null 2>&1
	@$(THIS_MAKE) --quiet test-docker-compose-image
	@$(THIS_MAKE) --quiet clean-docker-compose-test-image > /dev/null 2>&1
