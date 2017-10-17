#!/bin/bash

STATUS_FILE=${WORKDIR:-/dev/shm}/resolved_services.txt

cmd_init() {
  echo -n > "$STATUS_FILE"
}

cmd_resolve() {
  serviceName="$1"
  echo "$serviceName" >> "$STATUS_FILE"
}

cmd_wait() {
  [[ "$1" == "" ]] && return
  [ -r "$STATUS_FILE" ] || exit 1

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
      # tell inotifywait in the sub process to quit
      pgrep -P $PID | while read subPid; do
        pgrep -P $subPid -x inotifywait
      done | xargs kill -9
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
