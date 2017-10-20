testImageName=task-master-test

docker_run_bash() {
  docker run --entrypoint bash $testImageName -c "$@"
}

docker_run() {
  docker run $testImageName "$@"
}
