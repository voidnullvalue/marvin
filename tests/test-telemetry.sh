#!/usr/bin/env bash
set -euo pipefail

repo="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_root="$(mktemp -d /tmp/marvin-test-telemetry.XXXXXX)"
trap 'rm -rf "$tmp_root"' EXIT

export HOME="$tmp_root/home" XDG_CACHE_HOME="$tmp_root/home/.cache" USER=test PATH="$PATH"
mkdir -p "$HOME"
source "$repo/lib/core.sh"
source "$repo/lib/state.sh"
source "$repo/lib/phrases.sh"
source "$repo/lib/mood.sh"
source "$repo/lib/telemetry.sh"
_marvin_ensure_dirs
_marvin_state_load

_marvin_telemetry_refresh
[[ $_MARVIN_T_RAM =~ ^[0-9]+$ ]]
[[ $_MARVIN_T_DISK =~ ^[0-9]+$ ]]
[[ -n $_MARVIN_T_LOAD ]]
gitprompt="$tmp_root/gitprompt.out"
_marvin_git_prompt none >"$gitprompt"
[[ ! -s "$gitprompt" ]]

_MARVIN_TELEMETRY_CACHE_TIME=1
before=$_MARVIN_TELEMETRY_CACHE_TIME
_marvin_telemetry_refresh
[[ $_MARVIN_TELEMETRY_CACHE_TIME == "$before" ]]
