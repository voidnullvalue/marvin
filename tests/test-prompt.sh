#!/usr/bin/env bash
set -euo pipefail

repo="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
marvin="$repo/marvinrc.sh"
tmp_root="$(mktemp -d /tmp/marvin-test-prompt.XXXXXX)"
trap 'rm -rf "$tmp_root"' EXIT

home="$tmp_root/home"
mkdir -p "$home"
env -i HOME="$home" XDG_CACHE_HOME="$home/.cache" USER=test LOGNAME=test PATH="$PATH" \
    TERM=xterm-256color SHELL=/bin/bash MARVIN_LOGIN_REPORT=0 \
    bash --noprofile --norc -ic '
        source "$1"
        curl() { echo network-called >&2; return 9; }
        _marvin_prompt_dispatch >/tmp/prompt.out
        [[ -n ${PS1:-} ]]
        [[ $PS1 == *"\\["* && $PS1 == *"\\]"* ]]
        ! grep -q network-called /tmp/prompt.out 2>/dev/null
        marvin benchmark | grep -q "^cached_prompt_approx_ms="
    ' _ "$marvin"
