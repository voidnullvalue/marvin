#!/usr/bin/env bash

set -u

repo="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
marvin="$repo/marvinrc.sh"

printf 'Checking Bash syntax...\n'
bash -n "$marvin" || exit 1

printf 'Checking interactive loading in a clean environment...\n'

env -i \
    HOME="$HOME" \
    USER="${USER:-void}" \
    LOGNAME="${LOGNAME:-${USER:-void}}" \
    PATH="$PATH" \
    TERM="${TERM:-xterm-256color}" \
    SHELL=/bin/bash \
    bash --noprofile --norc -ic '
        source "$1"

        required=(
            marvin
            status
            weather
            forecast
            thought
            sulk
            complain
            marvindoctor
            marvinoff
            marvinon
        )

        failed=0

        for name in "${required[@]}"; do
            if ! type "$name" >/dev/null 2>&1; then
                printf "Missing command: %s\n" "$name" >&2
                failed=1
            fi
        done

        exit "$failed"
    ' _ "$marvin"

result=$?

if ((result != 0)); then
    printf 'Interactive Marvin API check failed.\n' >&2
    exit "$result"
fi

printf 'Marvin remains functional. This has not improved his outlook.\n'
