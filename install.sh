#!/usr/bin/env bash
set -euo pipefail

repo="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
target_dir="$HOME/.local/lib"
target="$target_dir/marvinrc.sh"
source_line='[[ -r "$HOME/.local/lib/marvinrc.sh" ]] && source "$HOME/.local/lib/marvinrc.sh"'
stamp="$(date +%Y%m%d-%H%M%S)"

bash -n "$repo/marvinrc.sh" "$repo"/lib/*.sh
mkdir -p "$target_dir"

if [[ -e "$target" && ! -L "$target" ]]; then
    cp -a "$target" "$target.pre-repo-$stamp"
fi

ln -sfn "$repo/marvinrc.sh" "$target"

if ! grep -Fq 'source "$HOME/.local/lib/marvinrc.sh"' "$HOME/.bashrc" 2>/dev/null; then
    {
        printf '\n# Marvin terminal personality\n'
        printf '%s\n' "$source_line"
    } >> "$HOME/.bashrc"
fi

printf 'Installed: %s -> %s\n' "$target" "$(readlink "$target")"
printf 'Run: exec bash\n'
