#!/bin/bash

# Build the sandbox container image for task development environments.
# Usage: build-sandbox-image.sh
#
# Finds the Dockerfile relative to this script and builds
# the image tagged as "sandbox:latest".

set -e

# Resolve workarea root (same pattern as other bin scripts)
resolve_workarea_root() {
    local script_path="${BASH_SOURCE[0]}"
    local script_dir="$(dirname "$script_path")"

    if [ -L "$script_dir" ]; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            local link_dir="$(cd "$(dirname "$script_dir")" && pwd)"
            local link_target="$(readlink "$script_dir")"
            if [[ "$link_target" == /* ]]; then
                script_dir="$link_target"
            else
                script_dir="$link_dir/$link_target"
            fi
        else
            script_dir="$(readlink -f "$script_dir")"
        fi
    fi

    if [ -L "$script_path" ]; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            local link_dir="$(cd "$(dirname "$script_path")" && pwd)"
            local link_target="$(readlink "$script_path")"
            if [[ "$link_target" == /* ]]; then
                script_path="$link_target"
            else
                script_path="$link_dir/$link_target"
            fi
            script_dir="$(dirname "$script_path")"
        else
            script_path="$(readlink -f "$script_path")"
            script_dir="$(dirname "$script_path")"
        fi
    fi

    script_dir="$(cd "$script_dir" && pwd -P)"
    dirname "$script_dir"
}

WORKAREA_ROOT="$(resolve_workarea_root)"
DOCKERFILE_DIR="${WORKAREA_ROOT}/containers/sandbox"

if [ ! -f "${DOCKERFILE_DIR}/Dockerfile" ]; then
    echo "Error: Dockerfile not found at ${DOCKERFILE_DIR}/Dockerfile"
    exit 1
fi

echo "Building sandbox image from ${DOCKERFILE_DIR}/Dockerfile..."
container build -t sandbox:latest "${DOCKERFILE_DIR}"
echo "Done. Image tagged as sandbox:latest"
