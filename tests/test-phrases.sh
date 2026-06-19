#!/usr/bin/env bash
set -euo pipefail

repo="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_root="$(mktemp -d /tmp/marvin-test-phrases.XXXXXX)"
trap 'rm -rf "$tmp_root"' EXIT

export HOME="$tmp_root/home" XDG_CACHE_HOME="$tmp_root/home/.cache" USER=test
mkdir -p "$HOME"
source "$repo/lib/core.sh"
source "$repo/lib/state.sh"
source "$repo/lib/phrases.sh"
_marvin_ensure_dirs
_marvin_phrases_load

[[ $(_marvin_phrase_count) -ge 600 ]]
printf '%s\n' "${_MARVIN_PHRASE_EVENTS[@]}" | sort -u | wc -l | awk '{exit !($1 >= 50)}'

for event in login command_failure repeated_failure command_not_found sudo_request apt_misuse long_success low_battery high_ram high_disk failed_services pending_updates operator_returning refusal; do
    count=$(printf '%s\n' "${_MARVIN_PHRASE_EVENTS[@]}" | awk -v e="$event" '$0==e {c++} END {print c+0}')
    [[ $count -ge 8 ]]
done

dupes=$(printf '%s\n' "${_MARVIN_PHRASE_TEXTS[@]}" | sort | uniq -d)
[[ -z $dupes ]]
! printf '%s\n' "${_MARVIN_PHRASE_TEXTS[@]}" | grep -Eq '\{[A-Za-z_][A-Za-z0-9_]*\}.*\{[A-Za-z_][A-Za-z0-9_]*\}.*\{[A-Za-z_][A-Za-z0-9_]*\}'
! printf '%s\n' "${_MARVIN_PHRASE_TEXTS[@]}" | grep -Eiq 'hax|leet|pwn|hackerman'
! printf '%s\n' "${_MARVIN_PHRASE_TEXTS[@]}" | awk 'length($0) > 180 {bad=1} END {exit bad}'

a=$(_marvin_phrase command_failure status 2)
b=$(_marvin_phrase command_failure status 2)
[[ -n $a && -n $b && $a != "$b" ]]
marvin_stats=$(_marvin_phrase_stats)
grep -q '^total_phrases=' <<<"$marvin_stats"
