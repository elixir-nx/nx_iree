#!/usr/bin/env bash

set -e

BUILD_CACHE=$1
IREE_GIT_REV=$2
IREE_DIR=$3

echo "Args:"
echo "  BUILD_CACHE: ${BUILD_CACHE}"
echo "  IREE_GIT_REV: ${IREE_GIT_REV}"
echo "  IREE_DIR: ${IREE_DIR}"

mkdir -p ${BUILD_CACHE}

IREE_REPO=https://github.com/iree-org/iree

if [ -d ${IREE_DIR} ]; then
  echo "IREE directory already exists. Skipping clone."
  ls ${IREE_DIR}
else
  git clone --branch ${IREE_GIT_REV} --depth 1 ${IREE_REPO} ${IREE_DIR}
fi

cd ${IREE_DIR}

git config --global submodule.recurse true
for submodule in $(git config --file .gitmodules --name-only --get-regexp path | sed 's/\.path$//'); do
    git config submodule.${submodule}.shallow true
    git config submodule.${submodule}.fetchRecurseSubmodules true
done

git submodule update --init --recursive --depth 1