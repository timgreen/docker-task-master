#!/bin/bash

CONFIG=/config.yaml
TMUX_SESSION=task-master
YQ_BIN=$(which yq)

yq() {
  cat $CONFIG | $YQ_BIN -r "$@"
}

yq_service() {
  name=$1
  shift
  yq ".services | .\"$name\"$@"
}

list_service_names() {
  yq '.services | keys[]'
}

list_enabled_service_names() {
  list_service_names | while read serviceName; do
    is_service_enabled $serviceName && echo $serviceName
  done
}

is_service_enabled() {
  name=$1
  [[ "$(yq_service $name .enabled | tr 'A-Z' 'a-z')" == "true" ]]
}

is_service_one_off() {
  name=$1
  [[ "$(yq_service $name '."one-off"' | tr 'A-Z' 'a-z')" == "true" ]]
}

execute_service_in_tmux() {
  i=$1
  serviceName=$2

  echo "Execute service in tmux: $serviceName"

  # read config
  repo="$(yq_service $serviceName .repo)"
  entryPoint="$(yq_service $serviceName .\"entry-point\")"

  # clone repo
  if [[ "$repo" != "null" ]]; then
    [ -d "$WORKDIR/$serviceName" ] || git clone --depth 1 "$repo" "$WORKDIR/$serviceName"
  else
    mkdir -p "$WORKDIR/$serviceName"
  fi

  # run entry point in tmux
  waitForKey="$serviceName:$RANDOM"
  targetWindow="$TMUX_SESSION:$((i+1))"
  tmux new-window -t $targetWindow -n "$serviceName" -c "$WORKDIR/$serviceName"
  tmux send-keys -t $targetWindow -l "$entryPoint"
  is_service_one_off $serviceName && \
    tmux send-keys -t $targetWindow -l "; tmux wait-for -S '$waitForKey'"
  tmux pipe-pane -t $targetWindow "cat >> '$(log_file_for $serviceName)'"
  tmux send-keys -t $targetWindow enter

  # wait one-off service to finish
  # TODO: better way to resolve the dependencies via wait-for -L -U
  is_service_one_off $serviceName && \
    tmux wait-for "$waitForKey"
}

log_file_for() {
  serviceName=$1
  echo "$WORKDIR/$serviceName.log"
}

log_file_for_self() {
  echo "$WORKDIR/master.log"
}

try_to_execute() {
  i=$1
  serviceName="$2"
  # https://stackoverflow.com/questions/4069188/how-to-pass-an-associative-array-as-argument-to-a-function-in-bash
  eval "declare -A resolvedServices="${3#*=}

  [ ${resolvedServices[$serviceName]+_} ] && return 1
  for dependency in $(yq_service $serviceName '."run-after"?[]?'); do
    [ ${resolvedServices[$dependency]+_} ] || return 1
  done

  echo "$i: Run $serviceName"
  execute_service_in_tmux $i $serviceName 2>&1 | tee -a "$(log_file_for $serviceName)"
}

print_service_graph() {
  has_graph_easy || return

  {
    echo 'graph { flow: north; }'
    for serviceName in $(list_service_names); do
      if is_service_enabled "$serviceName"; then
        echo "[ $serviceName ] { border: double }"
      else
        echo "[ $serviceName ]"
      fi
    done
    for serviceName in $(list_service_names); do
      if is_service_enabled "$serviceName"; then
        edge='->'
      else
        edge='.>'
      fi
      for dependency in $(yq_service $serviceName '."run-after"?[]?'); do
        echo "[ $serviceName ] $edge [ "$dependency" ]"
      done
    done
  } | graph-easy --as boxart
}

run_services_in_tmux() {
  echo "Run services in tmux"
  enabledServiceNames=($(list_enabled_service_names))
  echo "  Enabled services: ${enabledServiceNames[@]}"
  print_service_graph

  declare -A resolvedServices=()
  for i in $(seq ${#enabledServiceNames[@]}); do
    # Try to execute a service
    success=false
    for serviceName in ${enabledServiceNames[@]}; do
      try_to_execute $i "$serviceName" "$(declare -p resolvedServices)" && {
        success=true
        resolvedServices[$serviceName]=true
        break;
      }
    done
    if [[ $success != true ]]; then
      echo 'Cannot execute all the services:'
      echo '  The config might contains circular dependency or enabled services depends on disabled ones.'
      echo 'Enabled services:'
      for serviceName in $(list_service_names); do
        echo -n "  $serviceName: "
        if [ ${resolvedServices[$serviceName]+_} ]; then
          echo 'DONE'
        elif [ ${resolvedServices[$serviceName]+_} ]; then
          echo
        else
          echo 'DISABLED'
        fi
      done
      exit 1
    fi
  done
}

has_papertrail() {
  which remote_syslog > /dev/null
}

has_papertrail_config() {
  [[ $(yq '.config.papertrail.host') != 'null' ]] \
    && [[ $(yq '.config.papertrail.port') != 'null' ]]
}

should_enable_papertrail() {
  has_papertrail && has_papertrail_config
}

has_graph_easy() {
  which graph-easy > /dev/null
}

setup_papertrail() {
  should_enable_papertrail || return
  echo "Setup Papertrail"
  cat << EOF > /etc/log_files.yml
destination:
  host: $(yq '.config.papertrail.host')
  port: $(yq '.config.papertrail.port')
  protocol: tls
files:
  - $WORKDIR/*.log
EOF
}

start_control_tmux() {
  echo "Start control tmux"
  tmux has-session -t $TMUX_SESSION && return

  tmux new-session -d -s $TMUX_SESSION

  # monitor
  tmux rename-window -t $TMUX_SESSION:1 monitor
  if should_enable_papertrail; then
    tmux split-window -h -t $TMUX_SESSION:1.1
    ## papertrail
    tmux send-keys -t $TMUX_SESSION:1.2 -l 'remote_syslog -D'
    tmux send-keys -t $TMUX_SESSION:1.2 enter
  fi
  ## logs
  tmux send-keys -t $TMUX_SESSION:1.1 -l "tail -f '$(log_file_for_self)'"
  tmux send-keys -t $TMUX_SESSION:1.1 enter
}

wait_until_tmux_quit() {
  # https://stackoverflow.com/questions/1058047/wait-for-any-process-to-finish
  tail --pid=$(tmux list-sessions -F '#{pid}') -f /dev/null
}

verify_config() {
  # Ensure dependencies type is one-off
  for serviceName in $(list_service_names); do
    for dependency in $(yq_service $serviceName '."run-after"?[]?'); do
      if ! is_service_one_off $dependency; then
        echo "$(tput setaf 1)Error$(tput sgr0): service '$(tput setaf 3)$serviceName$(tput sgr0)' depends on non one-off service '$(tput setaf 3)$dependency$(tput sgr0)', please fix."
        exit 1
      fi
    done
  done
}

# Commands

cmd_daemon() {
  if ! touch "$(log_file_for_self)"; then
    echo "$(tput setaf 1)Error: please make sure WORKDIR is writable: $(tput setaf 3)$WORKDIR$(tput sgr0)"
    exit 1
  fi

  {
    setup_papertrail
    echo
    echo "================================================================================"
    echo "Start Task Master: $(date --iso-8601=seconds)"
    echo "================================================================================"
    echo
    start_control_tmux
    run_services_in_tmux
    wait_until_tmux_quit
  } >> $(log_file_for_self)
}

cmd_tmux() {
  if ! tmux has-session -t $TMUX_SESSION; then
    echo "$(tput setaf 1)Error: tmux session no found, is daemon running?$(tput sgr0)"
    exit 1
  fi
  tmux attach -t $TMUX_SESSION
}

cmd_graph() {
  print_service_graph
}

cmd_list() {
  for serviceName in $(list_service_names); do
    if is_service_enabled $serviceName; then
      echo -n "$(tput setaf 2)ENABLED $(tput sgr0)"
    else
      echo -n "$(tput setaf 1)DISABLED$(tput sgr0)"
    fi

    if is_service_one_off $serviceName; then
      echo -n " $(tput setaf 3)one-off$(tput sgr0)"
    else
      echo -n " $(tput setaf 3)deamon $(tput sgr0)"
    fi

    echo " $serviceName"
  done
}

cmd_help() {
  cmd=$1
  if [[ "$cmd" != "" ]]; then
    echo "$(tput setaf 4)$(tput bold)Unknown command: $(tput sgr0)'$(tput setaf 1)$1$(tput sgr0)'"
    echo
  fi

  cat << EOF
Usage: s [cmd]

Available commands:
  daemon  start the daemon.
  tmux    attach to the control tmux.
  list    list services.
  graph   show services graph.
  bash    run bash.
  help    show this help message.
EOF
}

main() {
  verify_config

  case $1 in
    tmux)
      cmd_tmux
      ;;
    daemon)
      cmd_daemon
      ;;
    graph)
      cmd_graph
      ;;
    list)
      cmd_list
      ;;
    bash)
      bash
      ;;
    help)
      cmd_help
      ;;
    *)
      cmd_help "$*"
      exit 1
  esac
}

main "$*"
