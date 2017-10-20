#!/bin/bash

set -e

baseDir="$(dirname "$(readlink -f "$0")")"
rootDir="$(dirname "$baseDir")"

build_docker() {
  docker build -t task-master-test --build-arg BASE='docker' --build-arg BUILD_DATE='' --build-arg VCS_REF='' "$rootDir/docker"
}

BATS_VERSION=0.4.0
BATS_PATH="$baseDir/bats/bats-$BATS_VERSION"
install_bats() {
  [ -d "$BATS_PATH" ] || {
    wget https://github.com/sstephenson/bats/archive/v${BATS_VERSION}.zip
    unzip v${BATS_VERSION}.zip -d bats
    rm -f v${BATS_VERSION}.zip
  }
}

main() {
  cd "$baseDir"
  build_docker
  install_bats
  # run bats tests
  "$BATS_PATH"/bin/bats "$@" *.bats
}

main
