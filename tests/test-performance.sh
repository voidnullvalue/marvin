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
        ms=$(marvin benchmark | awk -F= "/cached_prompt_approx_ms/ {print \$2}")
        [[ $ms == unknown || $ms -le 100 ]]
    ' _ "$marvin"
