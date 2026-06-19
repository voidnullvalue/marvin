#!/usr/bin/env bash
set -euo pipefail

repo="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
marvin="$repo/marvinrc.sh"
tmp_root="$(mktemp -d /tmp/marvin-smoke.XXXXXX)"
trap 'rm -rf "$tmp_root"' EXIT

home="$tmp_root/home"
mkdir -p "$home"

env -i HOME="$home" XDG_CACHE_HOME="$home/.cache" USER=test LOGNAME=test PATH="$PATH" \
    TERM=xterm-256color SHELL=/bin/bash MARVIN_LOGIN_REPORT=0 \
    bash --noprofile --norc -ic '
        source "$1"
        marvin status >/tmp/marvin-status.out
        marvin mood --verbose >/tmp/marvin-mood.out
        marvin phrase-stats >/tmp/marvin-phrases.out
        _marvin_prompt_dispatch >/tmp/marvin-prompt.out
        [[ -s /tmp/marvin-status.out ]]
        [[ -s /tmp/marvin-mood.out ]]
        [[ -s /tmp/marvin-phrases.out ]]
        [[ -n ${PS1:-} ]]
    ' _ "$marvin"

printf 'Smoke passed. Marvin remains operational, which he has taken rather badly.\n'
