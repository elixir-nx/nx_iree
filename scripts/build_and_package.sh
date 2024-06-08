#!/usr/bin/env bash

set -e
\
NUM_JOBS=-j$(($(nproc) - 2 ))

mkdir -p iree-runtime/artifacts

# for IREE_BUILD_TARGET in "host" "ios" "ios_simulator" "visionos" "visionos_simulator"
for IREE_BUILD_TARGET in "tvos" "tvos_simulator"
do

IREE_CMAKE_BUILD_DIR=iree-runtime/${IREE_BUILD_TARGET}/iree-build
IREE_RUNTIME_BUILD_DIR=iree-runtime/${IREE_BUILD_TARGET}/build
IREE_INSTALL_DIR=iree-runtime/${IREE_BUILD_TARGET}/install

echo "Building for target: ${IREE_BUILD_TARGET}"
make ${NUM_JOBS} compile IREE_GIT_REV=$(mix iree.version) IREE_INSTALL_DIR=${IREE_INSTALL_DIR} IREE_CMAKE_BUILD_DIR=${IREE_CMAKE_BUILD_DIR} IREE_RUNTIME_BUILD_DIR=${IREE_RUNTIME_BUILD_DIR} IREE_BUILD_TARGET=${IREE_BUILD_TARGET}

TAR_NAME=iree-runtime/artifacts/iree-runtime-${IREE_BUILD_TARGET}.tar.gz

echo "Packaging into ${TAR_NAME}"
tar -czf ${TAR_NAME} -C ${IREE_INSTALL_DIR} .

done