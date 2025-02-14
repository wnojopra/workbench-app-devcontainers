#!/bin/bash

# build.sh
#
# Populates a devcontainer template with default value and runs a docker container
# with devcontainer CLI.
# 
# Usage: build.sh <app>. The app templates must be located in src/ directory.

set -o errexit 
set -o nounset

readonly TEMPLATE_ID="$1"

# include hidden files because devcontainer configs
# are in .devcontainer/ or .devcontainer.json file.
shopt -s dotglob

readonly SRC_DIR="/tmp/${TEMPLATE_ID}"
cp -R "src/${TEMPLATE_ID}" "${SRC_DIR}"

pushd "${SRC_DIR}"

# Configure templates only if `devcontainer-template.json` contains the `options` property.
readonly OPTION_PROPERTY="$(jq -r '.options' devcontainer-template.json)"

if [[ "${OPTION_PROPERTY}" != "" ]] && [[ "${OPTION_PROPERTY}" != "null" ]]; then  
    readonly OPTIONS=( $(jq -r '.options | keys[]' devcontainer-template.json) )

    if [[ "${OPTIONS[0]}" != "" ]] && [[ "${OPTIONS[0]}" != "null" ]]; then
        echo "(!) Configuring template options for '${TEMPLATE_ID}'"
        for OPTION in "${OPTIONS[@]}"; do
            OPTION_KEY="\${templateOption:$OPTION}"
            OPTION_VALUE=$(jq -r ".options | .${OPTION} | .default" devcontainer-template.json)

            if [[ "${OPTION_VALUE}" == "" ]] || [[ "${OPTION_VALUE}" == "null" ]]; then
                echo "Template '${TEMPLATE_ID}' is missing a default value for option '${OPTION}'"
                exit 1
            fi

            echo "(!) Replacing '${OPTION_KEY}' with '${OPTION_VALUE}'"
            OPTION_VALUE_ESCAPED=$(sed -e 's/[]\/$*.^[]/\\&/g' <<<"${OPTION_VALUE}")
            find ./ -type f -print0 | xargs -0 sed -i "s/${OPTION_KEY}/${OPTION_VALUE_ESCAPED}/g"
        done
    fi
fi

popd

######################
# Sets up test folder
######################
readonly TEST_DIR="test"
echo "(*) Copying test folder"
readonly DEST_DIR="${SRC_DIR}/test-project"
mkdir -p "${DEST_DIR}"
cp -Rp "${TEST_DIR}"/* "${DEST_DIR}"
cp test/test-utils/test-utils.sh "${DEST_DIR}"

############################
# Install Devcontainer CLI
############################
export DOCKER_BUILDKIT=1
echo "(*) Installing @devcontainer/cli"
npm install -g @devcontainers/cli

#################################
# Workbench application specific
# Creates docker network 
#################################
docker network create -d bridge app-network

################################################
# Starts docker container using devcontainer CLI
################################################
echo "Building Dev Container"
readonly ID_LABEL="test-container=${TEMPLATE_ID}"
devcontainer up --id-label ${ID_LABEL} --workspace-folder "${SRC_DIR}"
