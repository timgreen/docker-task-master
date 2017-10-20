#!/usr/bin/env bats

load test_helper

@test "Graph::Easy installation" {
  run docker_run_bash graph-easy --version
  [ "$status" -eq 0 ]
}
