#!/usr/bin/env bash
set -euo pipefail

repo="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"

for test_file in \
    test-loader.sh \
    test-state.sh \
    test-mood.sh \
    test-phrases.sh \
    test-prompt.sh \
    test-refusal.sh \
    test-commands.sh \
    test-telemetry.sh \
    test-weather.sh \
    test-installer.sh \
    test-performance.sh \
    smoke.sh
do
    printf '==> %s\n' "$test_file"
    bash "$repo/tests/$test_file"
done

printf 'All Marvin tests passed. He remains unconvinced this was worth doing.\n'
