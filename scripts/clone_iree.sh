#!/usr/bin/env bash

set -e

IREE_GIT_REV=$1
NX_IREE_SOURCE_DIR=$2

echo "Args:"
echo "  IREE_GIT_REV: ${IREE_GIT_REV}"
echo "  NX_IREE_SOURCE_DIR: ${NX_IREE_SOURCE_DIR}"

IREE_REPO=https://github.com/iree-org/iree

if [ -d ${NX_IREE_SOURCE_DIR} ]; then
  echo "IREE directory already exists. Skipping clone."
  ls ${NX_IREE_SOURCE_DIR}
else
  git clone --branch ${IREE_GIT_REV} --depth 1 ${IREE_REPO} ${NX_IREE_SOURCE_DIR}
fi

cd ${NX_IREE_SOURCE_DIR}

git config --global submodule.recurse true
for submodule in $(git config --file .gitmodules --name-only --get-regexp path | sed 's/\.path$//'); do
    git config submodule.${submodule}.shallow true
    git config submodule.${submodule}.fetchRecurseSubmodules true
done

git submodule update --init --recursive --depth 1