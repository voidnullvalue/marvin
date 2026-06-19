#!/usr/bin/env bash
set -euo pipefail

repo="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
marvin="$repo/marvinrc.sh"
tmp_root="$(mktemp -d /tmp/marvin-test-refusal.XXXXXX)"
trap 'rm -rf "$tmp_root"' EXIT

run_i() {
    local home="$tmp_root/home"
    mkdir -p "$home"
    env -i HOME="$home" XDG_CACHE_HOME="$home/.cache" USER=test LOGNAME=test PATH="$PATH" \
        TERM=xterm-256color SHELL=/bin/bash MARVIN_LOGIN_REPORT=0 \
        bash --noprofile --norc -ic "$1" _ "$marvin"
}

env -i HOME="$tmp_root/noninteractive" XDG_CACHE_HOME="$tmp_root/noninteractive/.cache" USER=test PATH="$PATH" TERM=xterm \
    bash -c 'source "$1"; ! type _marvin_should_refuse >/dev/null 2>&1' _ "$marvin"

run_i '
    source "$1"
    for protected in cd pwd exit logout jobs fg bg kill disown ssh scp rsync git sudo doas mount umount reboot shutdown sv xbps-install; do
        ! _marvin_should_refuse "$protected"
    done
'

run_i '
    export MARVIN_FORCE_REFUSAL=1
    source "$1"
    set +e
    ls >/tmp/refusal.out 2>/tmp/refusal.err
    rc=$?
    set -e
    [[ $rc -eq 75 ]]
    grep -q "Command was not executed" /tmp/refusal.err
    grep -q "MARVIN_BYPASS=1" /tmp/refusal.err
    MARVIN_BYPASS=1 ls >/dev/null
    marvin refusal-status | grep -q "^session_refusals="
'

run_i '
    source "$1"
    out=$(marvin please bash -c '"'"'printf "<%s>\n" "$@"'"'"' _ "two words" "semi;colon" '"'"'quote"mark'"'"')
    grep -q "<two words>" <<<"$out"
    grep -q "<semi;colon>" <<<"$out"
    grep -q "<quote\"mark>" <<<"$out"
'
