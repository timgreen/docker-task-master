#!/usr/bin/env bats

load test_helper

@test "Confirm status-manager.sh installation" {
  run docker_run_bash 'ls /status-manager.sh'
  [ "$status" -eq 0 ]
}

teardown() {
  docker_test_teardown
}

@test "wait" {
  docker_test_begin
  docker_test_exec '/status-manager.sh init'
  docker_test_exec_d '/status-manager.sh wait A; touch /dev/shm/file'
  run docker_test_exec 'test -r /dev/shm/file'
  [ "$status" -eq 1 ]
  docker_test_exec '/status-manager.sh resolve A'
  run docker_test_exec 'test -r /dev/shm/file'
  [ "$status" -eq 0 ]
  docker_test_end
}

@test "wait multiple services" {
  docker_test_begin
  docker_test_exec '/status-manager.sh init'
  docker_test_exec_d '/status-manager.sh wait A B C; touch /dev/shm/file'
  run docker_test_exec 'test -r /dev/shm/file'
  [ "$status" -eq 1 ]
  docker_test_exec '/status-manager.sh resolve unknown'
  run docker_test_exec 'test -r /dev/shm/file'
  [ "$status" -eq 1 ]
  docker_test_exec '/status-manager.sh resolve C'
  run docker_test_exec 'test -r /dev/shm/file'
  [ "$status" -eq 1 ]
  docker_test_exec '/status-manager.sh resolve B'
  run docker_test_exec 'test -r /dev/shm/file'
  [ "$status" -eq 1 ]
  docker_test_exec '/status-manager.sh resolve A'
  run docker_test_exec 'test -r /dev/shm/file'
  [ "$status" -eq 0 ]
  docker_test_end
}

@test "wait accepts any chars" {
  docker_test_begin
  docker_test_exec '/status-manager.sh init'
  docker_test_exec_d '/status-manager.sh wait "asf-ASDF=!@#$|{}"; touch /dev/shm/file'
  run docker_test_exec 'test -r /dev/shm/file'
  [ "$status" -eq 1 ]
  docker_test_exec '/status-manager.sh resolve "asf-ASDF=!@#$|{}"'
  run docker_test_exec 'test -r /dev/shm/file'
  [ "$status" -eq 0 ]
  docker_test_end
}
