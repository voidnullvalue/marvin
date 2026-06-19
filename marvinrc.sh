# Marvin terminal personality for interactive Bash.
# Useful telemetry, delivered by an exceptionally capable machine with no enthusiasm whatsoever.
[[ $- != *i* ]] && return
[[ ${_MARVIN_RC_LOADED:-0} == 1 ]] && return
_MARVIN_RC_LOADED=1

_MARVIN_SOURCE=$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || printf '%s' "${BASH_SOURCE[0]}")
_MARVIN_DIR=$(cd -- "$(dirname -- "$_MARVIN_SOURCE")" >/dev/null 2>&1 && pwd)

for _marvin_module in \
    "$_MARVIN_DIR/lib/core.sh" \
    "$_MARVIN_DIR/lib/state.sh" \
    "$_MARVIN_DIR/lib/phrases.sh" \
    "$_MARVIN_DIR/lib/mood.sh" \
    "$_MARVIN_DIR/lib/telemetry.sh" \
    "$_MARVIN_DIR/lib/weather.sh" \
    "$_MARVIN_DIR/lib/notifications.sh" \
    "$_MARVIN_DIR/lib/refusal.sh" \
    "$_MARVIN_DIR/lib/prompt.sh" \
    "$_MARVIN_DIR/lib/commands.sh"
do
    # shellcheck source=/dev/null
    source "$_marvin_module"
done
unset _marvin_module

_marvin_init
