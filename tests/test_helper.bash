testImageName=task-master-test

docker_run_bash() {
  docker run --entrypoint bash $testImageName -c "$@"
}

docker_run() {
  docker run $testImageName "$@"
}

docker_test_begin() {
  docker run -d --name task-master-test --entrypoint bash $testImageName -c "touch /dev/shm/test.lock; inotifywait /dev/shm/test.lock"
}

docker_test_exec() {
  docker exec task-master-test bash -c "$@"
}

docker_test_exec_d() {
  docker exec -d task-master-test bash -c "$@"
}

docker_test_end() {
  docker_test_exec 'echo x > /dev/shm/test.lock'
}

docker_test_teardown() {
  docker rm -f task-master-test || true
}
