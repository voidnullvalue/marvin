#!/usr/bin/env bash
set -euo pipefail

repo="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
marvin="$repo/marvinrc.sh"
tmp_root="$(mktemp -d /tmp/marvin-test-mood.XXXXXX)"
trap 'rm -rf "$tmp_root"' EXIT

run_i() {
    local home="$tmp_root/home"
    mkdir -p "$home"
    env -i HOME="$home" XDG_CACHE_HOME="$home/.cache" USER=test LOGNAME=test PATH="$PATH" \
        TERM=xterm-256color SHELL=/bin/bash MARVIN_LOGIN_REPORT=0 MARVIN_TEST_DATE=2026-06-19 \
        bash --noprofile --norc -ic "$1" _ "$marvin"
}

run_i '
    source "$1"
    a=$(_marvin_baseline_mood)
    b=$(_marvin_baseline_mood)
    [[ $a == "$b" && -n $a ]]
    _marvin_mood_apply_event command_failure
    _marvin_mood_apply_event repeated_failure
    [[ $MARVIN_STATE_IRRITATION -gt 20 ]]
    _marvin_mood_refresh
    [[ -n $_MARVIN_MOOD ]]
    marvin mood --verbose | grep -q "^irritation="
'

run_i '
    source "$1"
    MARVIN_STATE_COOPERATION=90
    MARVIN_STATE_IRRITATION=5
    _marvin_mood_refresh
    [[ $(_marvin_mood) == "unusually cooperative" ]]
    marvin reset-mood >/dev/null
    [[ $MARVIN_STATE_IRRITATION -eq 20 ]]
'
