#!/usr/bin/env bash

for IREE_BUILD_TARGET in "host"
do

SCRIPT_DIR=$(dirname "$0")

${SCRIPT_DIR}/build_and_package.sh ${IREE_BUILD_TARGET}

done