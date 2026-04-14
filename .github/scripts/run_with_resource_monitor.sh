#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 2 ]; then
  echo "Usage: $0 <label> <command...>" >&2
  exit 64
fi

label="$1"
shift
interval="${RESOURCE_MONITOR_INTERVAL_SECONDS:-30}"
workspace="${GITHUB_WORKSPACE:-$PWD}"
command_pid=""
monitor_pid=""

print_disk_usage() {
  for path in "$workspace/data" "$workspace/out" "$workspace/osrs-wiki-maps/target"; do
    if [ -e "$path" ]; then
      du -sh "$path" || true
    fi
  done
}

print_process_details() {
  if [ -n "$command_pid" ] && kill -0 "$command_pid" 2>/dev/null; then
    ps -p "$command_pid" -o pid,ppid,%cpu,%mem,rss,vsz,etime,args || true
  else
    echo "Target process is not running."
  fi

  echo
  ps -eo pid,ppid,%cpu,%mem,rss,vsz,etime,args --sort=-rss | head -n 12 || true
}

report_snapshot() {
  local phase="$1"
  local timestamp
  timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

  echo "::group::resource snapshot [$label] [$phase] $timestamp"
  echo "RESOURCE label=$label phase=$phase timestamp=$timestamp"
  free -h || true
  echo
  df -h / "$workspace" || df -h || true
  echo
  df -i / "$workspace" || df -i || true
  echo
  swapon --show || true
  echo
  print_disk_usage
  echo
  print_process_details
  echo "::endgroup::"
}

handle_signal() {
  local signal="$1"
  report_snapshot "signal-$signal"

  if [ -n "$command_pid" ] && kill -0 "$command_pid" 2>/dev/null; then
    case "$signal" in
      INT)
        kill -INT "$command_pid" 2>/dev/null || true
        ;;
      TERM)
        kill -TERM "$command_pid" 2>/dev/null || true
        ;;
    esac
  fi

  exit 128
}

cleanup() {
  local status=$?
  trap - EXIT INT TERM

  if [ -n "$monitor_pid" ] && kill -0 "$monitor_pid" 2>/dev/null; then
    kill "$monitor_pid" 2>/dev/null || true
    wait "$monitor_pid" 2>/dev/null || true
  fi

  report_snapshot "final"
  exit "$status"
}

trap cleanup EXIT
trap 'handle_signal INT' INT
trap 'handle_signal TERM' TERM

report_snapshot "start"

"$@" &
command_pid=$!

(
  while kill -0 "$command_pid" 2>/dev/null; do
    sleep "$interval"

    if ! kill -0 "$command_pid" 2>/dev/null; then
      break
    fi

    report_snapshot "interval"
  done
) &
monitor_pid=$!

set +e
wait "$command_pid"
command_status=$?
set -e

exit "$command_status"
