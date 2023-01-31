.DEFAULT_GOAL := help

SHELL                      = /bin/bash

ENV                        = need_to_specify
PLAYBOOK                   = need_to_specify
TAGS                       = all
TARGETS                    = all

DEPLOY_REQ_FILE            = ansible-python-requirements.txt
DEPLOY_REQ_SHA1            = $(shell sha1sum $(DEPLOY_REQ_FILE) | cut -f1 -d " " | sed -e 's/^\(.\{5\}\).*/\1/')
VENV_NAME                  = .ansible-venv-$(DEPLOY_REQ_SHA1)

ANSIBLE_HOST_FILE          = inventories/${ENV}/hosts
ANSIBLE_DEPLOY_PLAYBOOK    = playbooks/${PLAYBOOK}.yml
ANSIBLE_PLAYBOOK_CMD       = ${VENV_NAME}/bin/ansible-playbook \
                              --tags ${TAGS} \
                              -l ${TARGETS} \
                              -i ${ANSIBLE_HOST_FILE} \
                              ${ANSIBLE_DEPLOY_PLAYBOOK}

ANSIBLE_REQ_FILE            = ansible-requirements.yml
ANSIBLE_REQ_SHA1            = $(shell sha1sum $(ANSIBLE_REQ_FILE) | cut -f1 -d " " | sed -e 's/^\(.\{5\}\).*/\1/')
ANSIBLE_IMPORTED_ROLES_LINK = ./imported_roles
ANSIBLE_IMPORTED_ROLES_DIR  = ./.imported_roles-${ANSIBLE_REQ_SHA1}
ANSIBLE_IMPORTED_COLLECS_LINK = ./imported_collections
ANSIBLE_IMPORTED_COLLECS_DIR  = ./.imported_collections-${ANSIBLE_REQ_SHA1}
ANSIBLE_COLLECS_GALAXY_CMD  = ${VENV_NAME}/bin/ansible-galaxy \
                              collection install \
                                -f \
                                -p ${ANSIBLE_IMPORTED_COLLECS_DIR} \
                                -r ${ANSIBLE_REQ_FILE}
ANSIBLE_ROLES_GALAXY_CMD    = ${VENV_NAME}/bin/ansible-galaxy \
                              role install \
                                -f \
                                -p ${ANSIBLE_IMPORTED_ROLES_DIR} \
                                -r ${ANSIBLE_REQ_FILE}

################################################################################

##
## Misc commands
## -----
##

.PHONY: list
list: ## Generate basic list of all targets
	@grep '^[^\.#[:space:]].*:' Makefile | \
		grep -v "=" | \
		cut -d':' -f1

.PHONY: help
help: ## Makefile help
	@grep -E '(^[a-zA-Z_0-9%-]+:.*?##.*$$)|(^##)' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "\033[32m%-30s\033[0m %s\n", $$1, $$2}' | \
		sed -e 's/\[32m##/[33m/'

##
## Env management commands
## -----
##

.PHONY: clean
clean: ## Clean the ansible virtal env
	@rm -rf ${VENV_NAME}
	@rm -rf ${ANSIBLE_IMPORTED_ROLES_LINK}
	@rm -rf ${ANSIBLE_IMPORTED_ROLES_DIR}

.PHONY: set-env
set-env: ## Generate ansible virtual env
	if [ ! -d "${VENV_NAME}" ]; then \
		python3 -m venv ${VENV_NAME} && \
		${VENV_NAME}/bin/python3 -m pip install --upgrade pip setuptools && \
		${VENV_NAME}/bin/python3 -m pip install -r ${DEPLOY_REQ_FILE} ;\
	fi
	if [ ! -d "${ANSIBLE_IMPORTED_ROLES_DIR}" ]; then \
		${ANSIBLE_ROLES_GALAXY_CMD} && \
		rm -rf ${ANSIBLE_IMPORTED_ROLES_LINK} && \
		ln -s ${ANSIBLE_IMPORTED_ROLES_DIR} ${ANSIBLE_IMPORTED_ROLES_LINK}; \
	fi
	if [ ! -d "${ANSIBLE_IMPORTED_COLLECS_DIR}" ]; then \
		${ANSIBLE_COLLECS_GALAXY_CMD} && \
		rm -rf ${ANSIBLE_IMPORTED_COLLECS_LINK} && \
		ln -s ${ANSIBLE_IMPORTED_COLLECS_DIR} ${ANSIBLE_IMPORTED_COLLECS_LINK}; \
	fi

##
## Deploy commands
## -----
##

.PHONY: basic-checks
basic-checks: ## Add basic checks before launching ansible command
ifeq ("$(wildcard $(ANSIBLE_HOST_FILE))","")
	@echo "$(ANSIBLE_HOST_FILE) does not exist - please specify ENV, eg: make deploy ENV=prod PLAYBOOK=projectA"
	@echo "Current possible ENV values:"
	@find hosts/ -maxdepth 1 -mindepth 1 -type d -exec basename {} \;
	@exit 1
endif
ifeq ("$(wildcard $(ANSIBLE_DEPLOY_PLAYBOOK))","")
	@echo "$(ANSIBLE_DEPLOY_PLAYBOOK) does not exist - please specify PLAYBOOK, eg: make deploy ENV=prod PLAYBOOK=projectA"
	@echo "Current possible PLAYBOOK values:"
	@find playbooks/ -maxdepth 1 -mindepth 1 -type f -exec basename {} \; | sed -e "s/.yml$///g"
	@exit 1
endif

.PHONY: deploy
deploy: basic-checks set-env ## Launch the ansible deploy command
	${ANSIBLE_PLAYBOOK_CMD}
