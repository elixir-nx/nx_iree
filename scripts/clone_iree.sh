#!/usr/bin/env bash

set -e

IREE_GIT_REV=$1
NX_IREE_SOURCE_DIR=$2

echo "Args:"
echo "  IREE_GIT_REV: ${IREE_GIT_REV}"
echo "  NX_IREE_SOURCE_DIR: ${NX_IREE_SOURCE_DIR}"

IREE_REPO=https://github.com/iree-org/iree

remove_stale_locks() {
  find . -name "index.lock" -type f -exec rm -f {} \;
}

if [ -d ${NX_IREE_SOURCE_DIR} ]; then
  echo "IREE directory already exists. Checking if it's up to date..."
  cd ${NX_IREE_SOURCE_DIR}

  # Fetch the latest changes
  git fetch origin

  # Check if the current commit matches the requested revision
  CURRENT_REV=$(git rev-parse HEAD)
  if git rev-parse --verify --quiet "refs/tags/${IREE_GIT_REV}"; then
    TARGET_REV=$(git rev-parse "refs/tags/${IREE_GIT_REV}")
  else
    TARGET_REV=$(git rev-parse origin/${IREE_GIT_REV})
  fi

  if [ "${CURRENT_REV}" != "${TARGET_REV}" ]; then
    echo "Directory is out of date. Resetting to the target revision ${IREE_GIT_REV}."
    git reset --hard origin/${IREE_GIT_REV}
  else
    echo "Directory is up to date."
  fi

  # Ensure submodules are also up to date
  remove_stale_locks

  git submodule update --init --recursive --depth 1

  exit 0;
fi

git clone --branch ${IREE_GIT_REV} --depth 1 ${IREE_REPO} ${NX_IREE_SOURCE_DIR}

cd ${NX_IREE_SOURCE_DIR}

git config --global submodule.recurse true
for submodule in $(git config --file .gitmodules --name-only --get-regexp path | sed 's/\.path$//'); do
    git config submodule.${submodule}.shallow true
    git config submodule.${submodule}.fetchRecurseSubmodules true
done

remove_stale_locks

git submodule update --init --recursive --depth 1