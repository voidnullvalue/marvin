#!/usr/bin/env bash
set -euo pipefail

target="$HOME/.local/lib/marvinrc.sh"
source_line='[[ -r "$HOME/.local/lib/marvinrc.sh" ]] && source "$HOME/.local/lib/marvinrc.sh"'
begin_marker='# >>> marvin-terminal >>>'
end_marker='# <<< marvin-terminal <<<'

if [[ -L $target ]]; then
    rm -f "$target"
fi

if [[ -f $HOME/.bashrc ]]; then
    tmp=$(mktemp "${TMPDIR:-/tmp}/marvin-bashrc.XXXXXX")
    awk -v begin="$begin_marker" -v end="$end_marker" -v line="$source_line" '
        $0 == begin { skip=1; next }
        $0 == end { skip=0; next }
        skip == 1 { next }
        $0 == line { next }
        { print }
    ' "$HOME/.bashrc" > "$tmp"
    cat "$tmp" > "$HOME/.bashrc"
    rm -f "$tmp"
fi

printf 'Uninstalled Marvin source hook and managed symlink, if present.\n'
