#!/usr/bin/env bash
set -euo pipefail

repo="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
marvin="$repo/marvinrc.sh"
tmp_root="$(mktemp -d /tmp/marvin-test-loader.XXXXXX)"
trap 'rm -rf "$tmp_root"' EXIT

run_i() {
    local home="$tmp_root/home"
    mkdir -p "$home"
    env -i HOME="$home" XDG_CACHE_HOME="$home/.cache" USER=test LOGNAME=test PATH="$PATH" \
        TERM=xterm-256color SHELL=/bin/bash MARVIN_LOGIN_REPORT=0 \
        bash --noprofile --norc -ic "$1" _ "$marvin"
}

while IFS= read -r file; do
    bash -n "$file"
done < <(find "$repo" -maxdepth 3 -type f \( -name '*.sh' -o -name 'marvinrc.sh' \) | sort)

env -i HOME="$tmp_root/noninteractive" XDG_CACHE_HOME="$tmp_root/noninteractive/.cache" \
    USER=test PATH="$PATH" TERM=xterm bash -c 'source "$1"; ! type marvin >/dev/null 2>&1' _ "$marvin"

run_i '
    source "$1"
    for name in marvin status weather forecast thought sulk complain mood; do
        type "$name" >/dev/null 2>&1 || exit 1
    done
    for old in marvinstatus marvinweather marvinforecast marvindoctor; do
        ! type "$old" >/dev/null 2>&1 || exit 1
    done
'

run_i '
    hook_ran=0
    old_hook() { hook_ran=1; }
    PROMPT_COMMAND=old_hook
    source "$1"
    _marvin_prompt_dispatch >/dev/null
    [[ $hook_ran -eq 1 ]]
'
