#!/bin/bash

set -e

baseDir="$(dirname "$(readlink -f "$0")")"
rootDir="$(dirname "$baseDir")"

test_graph_easy() {
  echo test pass
}

main() {
  cd "$rootDir/docker"
  docker build -t task-master-test --build-arg BASE='docker' --build-arg BUILD_DATE='' --build-arg VCS_REF='' .

  test_graph_easy
}

main
