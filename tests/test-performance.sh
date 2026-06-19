#!/usr/bin/env bash
set -euo pipefail

repo="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
marvin="$repo/marvinrc.sh"
tmp_root="$(mktemp -d /tmp/marvin-test-performance.XXXXXX)"
trap 'rm -rf "$tmp_root"' EXIT

home="$tmp_root/home"
mkdir -p "$home"
env -i HOME="$home" XDG_CACHE_HOME="$home/.cache" USER=test LOGNAME=test PATH="$PATH" \
    TERM=xterm-256color SHELL=/bin/bash MARVIN_LOGIN_REPORT=0 \
    bash --noprofile --norc -ic '
        source "$1"
        out=$(marvin benchmark)
        cached_ms=$(printf "%s\n" "$out" | awk -F= "/^cached_prompt_approx_ms/ {print \$2}")
        full_ms=$(printf "%s\n" "$out" | awk -F= "/^full_refresh_approx_ms/ {print \$2}")
        [[ $cached_ms == unknown || $cached_ms -le 100 ]]
        [[ $full_ms == unknown || $full_ms -le 1000 ]]
    ' _ "$marvin"
