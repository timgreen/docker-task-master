#!/usr/bin/env bats

load test_helper

@test "Graph::Easy installation" {
  run docker_run_bash 'echo [a] | graph-easy'
  [ "$status" -eq 0 ]
}

@test "yq installation" {
  run docker_run_bash 'yq -h'
  [ "$status" -eq 0 ]
}

@test "docker-compose installation" {
  docker_run_bash 'docker-compose -h'
  run docker_run_bash 'docker-compose -h'
  [ "$status" -eq 0 ]
}
