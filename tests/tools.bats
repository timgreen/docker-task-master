#!/usr/bin/env bats

@test "Graph::Easy installation" {
  run docker run --entrypoint bash task-master-test -c graph-easy --version
  [ "$status" -eq 0 ]
}
