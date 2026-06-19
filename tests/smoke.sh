#!/usr/bin/env bash
set -euo pipefail

repo="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
marvin="$repo/marvinrc.sh"

printf 'Checking Bash syntax...\n'
bash -n "$marvin"

printf 'Checking noninteractive loading...\n'
MARVIN_QUIET=1 bash --noprofile --norc -c 'source "$1"' _ "$marvin"

printf 'Checking public functions...\n'
MARVIN_QUIET=1 bash --noprofile --norc -c '
    source "$1"
    shift
    failed=0
    for name in "$@"; do
        if ! declare -F "$name" >/dev/null; then
            printf "Missing function: %s\\n" "$name" >&2
            failed=1
        fi
    done
    exit "$failed"
' _ "$marvin" \
    marvin status weather forecast thought sulk complain \
    marvindoctor marvinoff marvinon

printf 'Marvin remains operational. This has not improved his outlook.\n'
