#!/usr/bin/env bash
set -euo pipefail

repo="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
marvin="$repo/marvinrc.sh"
tmp_root="$(mktemp -d /tmp/marvin-test-state.XXXXXX)"
trap 'rm -rf "$tmp_root"' EXIT

run_i() {
    local home="$tmp_root/home"
    mkdir -p "$home"
    env -i HOME="$home" XDG_CACHE_HOME="$home/.cache" USER=test LOGNAME=test PATH="$PATH" \
        TERM=xterm-256color SHELL=/bin/bash MARVIN_LOGIN_REPORT=0 MARVIN_STATE_FLUSH_INTERVAL=999 \
        bash --noprofile --norc -ic "$1" _ "$marvin"
}

run_i '
    source "$1"
    state_dir="$XDG_CACHE_HOME/marvin-terminal"
    [[ $(stat -c %a "$state_dir") == 700 ]]
    [[ $(stat -c %a "$state_dir/state") == 600 ]]
    grep -q "^MARVIN_STATE_IRRITATION=" "$state_dir/state"
    before=$(stat -c %Y "$state_dir/state")
    sleep 1
    _marvin_update_command_state 0 0 "true"
    after=$(stat -c %Y "$state_dir/state")
    [[ $before == "$after" ]]
    _marvin_state_flush_if_needed 1
    newer=$(stat -c %Y "$state_dir/state")
    [[ $newer -gt $after ]]
'

run_i '
    source "$1"
    for i in {1..120}; do _marvin_history_add test "entry-$i"; done
    [[ $(wc -l < "$XDG_CACHE_HOME/marvin-terminal/history") -le 80 ]]
'

run_i '
    source "$1"
    printf "MARVIN_STATE_IRRITATION=not-a-number\nMARVIN_STATE_DESPAIR=999\n" > "$XDG_CACHE_HOME/marvin-terminal/state"
    _marvin_state_load
    [[ $MARVIN_STATE_IRRITATION -eq 0 ]]
    [[ $MARVIN_STATE_DESPAIR -eq 100 ]]
'
