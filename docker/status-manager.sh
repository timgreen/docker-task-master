#!/bin/bash

STATUS_FILE=${WORKDIR:-/dev/shm}/resolved_services.txt

cmd_init() {
  echo > "$STATUS_FILE"
}

cmd_resolve() {
  serviceName="$1"
  echo "$serviceName" >> "$STATUS_FILE"
}

cmd_wait() {
  [[ "$1" == "" ]] && return

  PID="$$"
  {
    echo 'tick initial check'
    inotifywait -q -m -e modify "$STATUS_FILE"
  } | while read; do
    allGood=true
    for serviceName in "$@"; do
      grep -q -F -x $serviceName "$STATUS_FILE" || {
        allGood=false
        break
      }
    done
    if [[ "$allGood" == "true" ]]; then
      # tell inotifywait to quit
      kill -9 $(pgrep -P $(pgrep -P $PID | paste -sd "," -) -x inotifywait)
      exit
    fi
  done
}

main() {
  cmd=$1
  shift
  case "$cmd" in
    init)
      cmd_init
      ;;
    resolve)
      cmd_resolve "$1"
      ;;
    wait)
      cmd_wait "$@"
      ;;
    *)
      exit 1
  esac
}

main "$@" 2> /dev/null
