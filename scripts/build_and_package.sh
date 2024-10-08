#!/usr/bin/env bash

set -e

get_nproc() {
    if [ "$(uname -s)" = "Darwin" ]; then
        sysctl -n hw.ncpu
    else
        nproc
    fi
}

MAKE_RULE=install_runtime
BUILD_HOST_COMPILER=OFF

# Parse options
while [[ $# -gt 0 ]]; do
  case $1 in
    --target=*)
      IREE_BUILD_TARGET="${1#*=}"
      shift # Shift past the argument
      ;;
    --make-rule=*)
      MAKE_RULE="${1#*=}"
      shift # Shift past the argument
      ;;
    --build-compiler)
      BUILD_HOST_COMPILER=ON
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

install_dir() {
    echo "iree-runtime/$1/install"
}

build() {
    echo "Building for target: $1"
    local IREE_CMAKE_BUILD_DIR=iree-runtime/$1/iree-build
    local IREE_RUNTIME_BUILD_DIR=iree-runtime/$1/build
    local IREE_INSTALL_DIR=$(install_dir $1)

    export IREE_HOST_BUILD_DIR=iree-runtime/host-toolchain
    export IREE_HOST_INSTALL_DIR=${IREE_HOST_BUILD_DIR}/install
    export IREE_HOST_BIN_DIR=${IREE_HOST_BUILD_DIR}/install/bin

    echo "IREE_CMAKE_BUILD_DIR: $IREE_CMAKE_BUILD_DIR"
    echo "IREE_RUNTIME_BUILD_DIR: $IREE_RUNTIME_BUILD_DIR"
    echo "IREE_INSTALL_DIR: $IREE_INSTALL_DIR"
    echo "IREE_HOST_BIN_DIR: $IREE_HOST_BIN_DIR"
    echo "IREE_HOST_INSTALL_DIR: $IREE_HOST_INSTALL_DIR"

    if [ $1 = "webassembly" ]; then
      EMCMAKE=$(command -v emcmake)
      if command -v ${EMCMAKE} >/dev/null 2>&1; then
        echo "${EMCMAKE} is a valid executable."
      else
        echo "${EMCMAKE} is not a valid executable or not found."
        exit 1
      fi
    fi

    make ${NUM_JOBS} ${MAKE_RULE} \
        IREE_GIT_REV=$(mix iree.version) \
        IREE_INSTALL_DIR=${IREE_INSTALL_DIR} \
        IREE_HOST_BIN_DIR=${IREE_HOST_BIN_DIR} \
        IREE_CMAKE_BUILD_DIR=${IREE_CMAKE_BUILD_DIR} \
        IREE_RUNTIME_BUILD_DIR=${IREE_RUNTIME_BUILD_DIR} \
        IREE_BUILD_TARGET=$1 \
        BUILD_HOST_COMPILER=$2 \
        EMCMAKE=${EMCMAKE} \
        DEBUG=${DEBUG}
}

build $IREE_BUILD_TARGET $BUILD_HOST_COMPILER
IREE_INSTALL_DIR=$(install_dir $IREE_BUILD_TARGET)

TAR_NAME=iree-runtime/artifacts/nx_iree-embedded-macos-${IREE_BUILD_TARGET}.tar.gz

echo "Packaging into ${TAR_NAME}"
tar -czf ${TAR_NAME} -C ${IREE_INSTALL_DIR} .