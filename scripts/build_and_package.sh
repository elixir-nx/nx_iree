#!/usr/bin/env bash

set -e

get_nproc() {
    if [ "$(uname -s)" = "Darwin" ]; then
        sysctl -n hw.ncpu
    else
        nproc
    fi
}

# Initialize variable
build_host_flag=false

# Parse options
while [[ $# -gt 0 ]]; do
  case $1 in
    --target=*)
      IREE_BUILD_TARGET="${1#*=}"
      shift # Shift past the argument
      ;;
    --build-host)
      build_host_flag=true
      shift # Shift past the argument
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

NUM_JOBS=-j$(get_nproc)

mkdir -p iree-runtime/artifacts

HOST_ARCH=$(uname -s)-$(uname -m)

build() {
    local IREE_CMAKE_BUILD_DIR=iree-runtime/$1/iree-build
    local IREE_RUNTIME_BUILD_DIR=iree-runtime/$1/build
    local IREE_INSTALL_DIR=iree-runtime/$1/install

    if $2; then
        export IREE_HOST_INSTALL_DIR=iree-runtime/host/install
    fi

    echo "Building for target: $1"
    echo "IREE_HOST_INSTALL_DIR: ${IREE_HOST_INSTALL_DIR}"
    make ${NUM_JOBS} compile \
        IREE_GIT_REV=$(mix iree.version) \
        IREE_INSTALL_DIR=${IREE_INSTALL_DIR} \
        IREE_CMAKE_BUILD_DIR=${IREE_CMAKE_BUILD_DIR} \
        IREE_RUNTIME_BUILD_DIR=${IREE_RUNTIME_BUILD_DIR} \
        IREE_BUILD_TARGET=$1
}

if $build_host_flag; then
    echo "Building Host Runtime"
    build host true
fi

build $IREE_BUILD_TARGET false

TAR_NAME=iree-runtime/artifacts/nx_iree-${HOST_ARCH}-${IREE_BUILD_TARGET}.tar.gz

echo "Packaging into ${TAR_NAME}"
tar -czf ${TAR_NAME} -C ${IREE_INSTALL_DIR} .