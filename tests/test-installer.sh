#!/usr/bin/env bash
set -euo pipefail

repo="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_root="$(mktemp -d /tmp/marvin-test-installer.XXXXXX)"
trap 'rm -rf "$tmp_root"' EXIT

home="$tmp_root/home"
mkdir -p "$home"
printf 'export KEEP_ME=1\n' > "$home/.bashrc"

HOME="$home" bash "$repo/install.sh" >/tmp/install1.out
HOME="$home" bash "$repo/install.sh" >/tmp/install2.out
[[ $(grep -c 'marvinrc.sh' "$home/.bashrc") -eq 1 ]]
[[ -L "$home/.local/lib/marvinrc.sh" ]]

HOME="$home" bash "$repo/uninstall.sh" >/tmp/uninstall.out
! grep -q 'marvinrc.sh' "$home/.bashrc"
grep -q 'KEEP_ME=1' "$home/.bashrc"
[[ ! -e "$home/.local/lib/marvinrc.sh" ]]

HOME="$home" bash "$repo/uninstall.sh" >/tmp/uninstall2.out
