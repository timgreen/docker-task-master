#!/usr/bin/env bats

load test_helper

@test "Confirm entry-point.sh installation" {
  run docker_run_bash 'ls /entry-point.sh'
  [ "$status" -eq 0 ]
}

@test "Confirm alias s installation" {
  run docker_run_bash 'ls /usr/bin/s'
  [ "$status" -eq 0 ]
}
