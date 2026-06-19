#!/usr/bin/env bash
set -euo pipefail

repo="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
tmp_root="$(mktemp -d /tmp/marvin-test-weather.XXXXXX)"
trap 'rm -rf "$tmp_root"' EXIT

export HOME="$tmp_root/home" XDG_CACHE_HOME="$tmp_root/home/.cache" USER=test PATH="$PATH"
mkdir -p "$HOME"
source "$repo/lib/core.sh"
source "$repo/lib/state.sh"
source "$repo/lib/phrases.sh"
source "$repo/lib/weather.sh"
_marvin_ensure_dirs

mkdir -p "$HOME/bin"
cat > "$HOME/bin/curl" <<'SCRIPT'
#!/usr/bin/env bash
exit 7
SCRIPT
chmod +x "$HOME/bin/curl"
PATH="$HOME/bin:$PATH"

set +e
_marvin_weather_line force >/tmp/weather.out 2>/tmp/weather.err
rc=$?
set -e
[[ $rc -ne 0 ]]

printf 'Nowhere|Overcast|10C|8C|70%%|3km/h|0mm\n' > "$XDG_CACHE_HOME/marvin-terminal/weather.txt"
_marvin_weather_line cached | grep -q "Nowhere: Overcast"
