#!/usr/bin/env bash

set -e

IREE_BUILD_TARGET=$1

get_nproc() {
    if [ "$(uname -s)" = "Darwin" ]; then
        sysctl -n hw.ncpu
    else
        nproc
    fi
}

NUM_JOBS=-j$(get_nproc)

mkdir -p iree-runtime/artifacts

IREE_CMAKE_BUILD_DIR=iree-runtime/${IREE_BUILD_TARGET}/iree-build
IREE_RUNTIME_BUILD_DIR=iree-runtime/${IREE_BUILD_TARGET}/build
IREE_INSTALL_DIR=iree-runtime/${IREE_BUILD_TARGET}/install
HOST_ARCH=$(uname -s)-$(uname -m)

echo "Building for target: ${IREE_BUILD_TARGET}"
make ${NUM_JOBS} compile IREE_GIT_REV=$(mix iree.version) IREE_INSTALL_DIR=${IREE_INSTALL_DIR} IREE_CMAKE_BUILD_DIR=${IREE_CMAKE_BUILD_DIR} IREE_RUNTIME_BUILD_DIR=${IREE_RUNTIME_BUILD_DIR} IREE_BUILD_TARGET=${IREE_BUILD_TARGET}

TAR_NAME=iree-runtime/artifacts/nx_iree-${HOST_ARCH}-${IREE_BUILD_TARGET}.tar.gz

echo "Packaging into ${TAR_NAME}"
tar -czf ${TAR_NAME} -C ${IREE_INSTALL_DIR} .