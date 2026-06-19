#!/usr/bin/env bash
set -euo pipefail

repo="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
marvin="$repo/marvinrc.sh"
tmp_root="$(mktemp -d /tmp/marvin-test-commands.XXXXXX)"
trap 'rm -rf "$tmp_root"' EXIT

run_i() {
    local home="$tmp_root/home"
    mkdir -p "$home"
    env -i HOME="$home" XDG_CACHE_HOME="$home/.cache" USER=test LOGNAME=test PATH="$PATH" \
        TERM=xterm-256color SHELL=/bin/bash MARVIN_LOGIN_REPORT=0 \
        bash --noprofile --norc -ic "$1" _ "$marvin"
}

run_i '
    source "$1"
    out=$(marvin help)
    grep -q "marvin phrase-stats" <<<"$out"
    out=$(marvin phrase-stats)
    grep -q "^total_phrases=" <<<"$out"
    out=$(marvin phrases command_failure)
    grep -q "event=command_failure" <<<"$out"
    out=$(marvin mood --verbose)
    grep -q "^reason=" <<<"$out"
    marvin debug on >/dev/null
    marvin debug off >/dev/null
    marvin personality 0 >/dev/null
    [[ ${MARVIN_PERSONALITY_LEVEL:-} == 0 ]]
'

run_i '
    source "$1"
    xbps-query() { return 1; }
    set +e
    command_not_found_handle apt >/tmp/cnf.out 2>/tmp/cnf.err
    rc=$?
    set -e
    [[ $rc -eq 127 ]]
    grep -qi "XBPS" /tmp/cnf.err
'

run_i '
    source "$1"
    set +e
    false
    rc=$?
    set -e
    [[ $rc -eq 1 ]]
    _marvin_comment_after_command 130 0 "sleep"
'
