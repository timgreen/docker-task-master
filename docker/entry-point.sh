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

has_service() {
  name=$1
  [[ "$(yq_service $name .enabled)" != "null" ]]
}

is_service_enabled() {
  name=$1
  [[ "$(yq_service $name .enabled | tr 'A-Z' 'a-z')" == "true" ]]
}

is_service_one_off() {
  name=$1
  [[ "$(yq_service $name '."one-off"' | tr 'A-Z' 'a-z')" == "true" ]]
}

fire_service_in_tmux_tab() {
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
  targetWindow="$TMUX_SESSION:$((i+1))"
  tmux new-window -t $targetWindow -n "$serviceName" -c "$WORKDIR/$serviceName"
  # Wait service dependencies.
  tmux send-keys -t $targetWindow -l "/status-manager.sh wait $(yq_service $serviceName '."run-after"?[]?');"
  # Run entry point code.
  tmux send-keys -t $targetWindow -l "$entryPoint"
  # Notify other service if this task completed without error.
  tmux send-keys -t $targetWindow -l " && /status-manager.sh resolve $serviceName"
  tmux pipe-pane -t $targetWindow "cat >> '$(log_file_for $serviceName)'"
  tmux send-keys -t $targetWindow enter
}

log_file_for() {
  serviceName=$1
  echo "$WORKDIR/$serviceName.log"
}

log_file_for_self() {
  echo "$WORKDIR/master.log"
}

tsort_file() {
  echo "$WORKDIR/tsort_result"
}

tsort_error_file() {
  echo "$WORKDIR/tsort_error"
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

  # init status manager
  /status-manager.sh init
  # Fire services in tab
  for i in $(seq ${#enabledServiceNames[@]}); do
    serviceName=${enabledServiceNames[$((i - 1))]}
    fire_service_in_tmux_tab $i "$serviceName" 2>&1 | tee -a "$(log_file_for $serviceName)"
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

wait_for_all_enabled_services() {
  # Wait for all services to end.
  # Also means keep going if there are any deamon services.
  /status-manager.sh wait ${enabledServiceNames[@]}
}

verify_config() {
  # Check dependencies
  for serviceName in $(list_service_names); do
    for dependency in $(yq_service $serviceName '."run-after"?[]?'); do
      # Ensure dependency service exists.
      if ! has_service $dependency; then
        echo "$(tput setaf 1)Error$(tput sgr0): service '$(tput setaf 3)$serviceName$(tput sgr0)' depends non-exist service '$(tput setaf 3)$dependency$(tput sgr0)', please fix."
      fi
      # Ensure dependency service type is one-off.
      if ! is_service_one_off $dependency; then
        echo "$(tput setaf 1)Error$(tput sgr0): service '$(tput setaf 3)$serviceName$(tput sgr0)' depends on non one-off service '$(tput setaf 3)$dependency$(tput sgr0)', please fix."
        exit 1
      fi
      # Ensure enabled service dependency could be resolved.
      if is_service_enabled $serviceName; then
        if ! is_service_enabled $dependency; then
          echo "$(tput setaf 1)Error$(tput sgr0): enabled service '$(tput setaf 3)$serviceName$(tput sgr0)' depends on disabled service '$(tput setaf 3)$dependency$(tput sgr0)', please fix."
          exit 1
        fi
      fi
    done
  done

  # Ensure no circular dependency.
  {
    for serviceName in $(list_service_names); do
      for dependency in $(yq_service $serviceName '."run-after"?[]?'); do
        echo "$dependency $serviceName"
      done
    done
  } | tsort > $(tsort_file) 2> $(tsort_error_file) || {
    echo "$(tput setaf 1)Error$(tput sgr0): found circular dependency."
    tail +2 $(tsort_error_file) | cut -d: -f 2
    echo
    print_service_graph

    exit 1
  }
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
    wait_for_all_enabled_services
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
