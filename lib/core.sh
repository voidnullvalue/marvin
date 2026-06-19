# Core configuration and small helpers.

: "${MARVIN_WEATHER_LOCATION:=}"
: "${MARVIN_LOGIN_REPORT:=1}"
: "${MARVIN_LONG_COMMAND_SECONDS:=10}"
: "${MARVIN_SUDO_COMMENTARY:=1}"
: "${MARVIN_PERSONALITY_LEVEL:=2}"
: "${MARVIN_COMMENT_RATE:=100}"
: "${MARVIN_REFUSAL:=1}"
: "${MARVIN_REFUSAL_RATE:=1}"
: "${MARVIN_DEBUG:=0}"
: "${MARVIN_TELEMETRY_TTL:=5}"
: "${MARVIN_NOTIFICATION_COOLDOWN:=45}"
: "${MARVIN_REFUSAL_STATUS:=75}"
: "${MARVIN_STATE_FLUSH_INTERVAL:=12}"
: "${MARVIN_REFUSAL_COOLDOWN_COMMANDS:=20}"
: "${MARVIN_REFUSAL_COOLDOWN_SECONDS:=1200}"
: "${MARVIN_REFUSAL_SESSION_MAX:=2}"
: "${MARVIN_FORCE_REFUSAL:=0}"

_MARVIN_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}/marvin-terminal"
_MARVIN_STATE_DIR="$_MARVIN_CACHE_HOME"
_MARVIN_STATE_FILE="$_MARVIN_STATE_DIR/state"
_MARVIN_HISTORY_FILE="$_MARVIN_STATE_DIR/history"
_MARVIN_PHRASE_FILE="$_MARVIN_STATE_DIR/phrases"
_MARVIN_SESSION_ID="${BASHPID:-$$}.$RANDOM"
_MARVIN_SESSION_STARTED_AT=$(command date +%s 2>/dev/null || printf 0)

_MV_RESET=$'\033[0m'
_MV_DIM=$'\033[2m'
_MV_BLUE=$'\033[1;34m'
_MV_CYAN=$'\033[0;36m'
_MV_RED=$'\033[1;31m'
_MV_YELLOW=$'\033[1;33m'
_MV_GREY=$'\033[38;5;245m'

_marvin_debug() {
    [[ ${MARVIN_DEBUG:-0} == 1 || ${_MARVIN_DEBUG:-0} == 1 ]] || return 0
    printf '[marvin debug] %s\n' "$*" >&2
}

_marvin_bool() {
    case "${1:-}" in
        1|yes|true|on|enabled) return 0 ;;
        *) return 1 ;;
    esac
}

_marvin_host() {
    local host=${HOSTNAME:-}
    [[ -n $host ]] || host=$(hostname 2>/dev/null || printf 'unknown-host')
    printf '%s' "${host%%.*}"
}

_marvin_hash() {
    local str="$*" h=5381 i c
    for ((i = 0; i < ${#str} && i < 128; i++)); do
        printf -v c '%d' "'${str:i:1}" 2>/dev/null || c=0
        h=$(( ((h << 5) + h) ^ c ))
        h=$(( h & 0x7FFFFFFF ))
    done
    printf '%d' "$h"
}

# Non-forking variant: writes hash into VARNAME.
_marvin_hash_v() {
    local _hvar=$1 str="${*:2}" h=5381 i c
    for ((i = 0; i < ${#str} && i < 128; i++)); do
        printf -v c '%d' "'${str:i:1}" 2>/dev/null || c=0
        h=$(( ((h << 5) + h) ^ c ))
        h=$(( h & 0x7FFFFFFF ))
    done
    printf -v "$_hvar" '%d' "$h"
}

# Set VARNAME to value clamped to [min,max] without a subshell.
_marvin_clamp_var() {
    local _v=${!1:-0} _min=${2:-0} _max=${3:-100}
    [[ $_v =~ ^-?[0-9]+$ ]] || _v=0
    ((_v < _min)) && _v=$_min
    ((_v > _max)) && _v=$_max
    printf -v "$1" '%d' "$_v"
}

_marvin_clamp() {
    local value=${1:-0} min=${2:-0} max=${3:-100}
    [[ $value =~ ^-?[0-9]+$ ]] || value=0
    ((value < min)) && value=$min
    ((value > max)) && value=$max
    printf '%s' "$value"
}

_marvin_now() {
    printf '%d' $(( _MARVIN_SESSION_STARTED_AT + SECONDS ))
}

_marvin_cols() {
    local n="${COLUMNS:-0}"
    [[ $n =~ ^[0-9]+$ && $n -gt 0 ]] || n=$(tput cols 2>/dev/null || printf '80')
    [[ $n =~ ^[0-9]+$ ]] || n=80
    ((n < 58)) && n=58
    ((n > 120)) && n=120
    printf '%s' "$n"
}

_marvin_rule() {
    local n="${1:-$(_marvin_cols)}" line
    printf -v line '%*s' "$n" ''
    printf '%s\n' "${line// /-}"
}

_marvin_wrap() {
    local cols text
    cols=$(_marvin_cols)
    text=$*
    if command -v fold >/dev/null 2>&1; then
        printf '%s\n' "$text" | fold -s -w "$cols"
    else
        printf '%s\n' "$text"
    fi
}

_marvin_sanitize_text() {
    local text=${1//$'\n'/ }
    text=${text//$'\r'/ }
    text=${text//$'\t'/ }
    text=$(printf '%s' "$text" | sed -E \
        -e 's/--?(password|passwd|token|secret|apikey|api-key|key|credential)(=|[[:space:]]+)[^[:space:]]+/\1=[redacted]/Ig' \
        -e 's/(password|passwd|token|secret|apikey|api-key|credential)=([^[:space:]]+)/\1=[redacted]/Ig')
    [[ ${#text} -gt 90 ]] && text="${text:0:87}..."
    printf '%s' "$text"
}

_marvin_command_label() {
    local cmd=${1:-}
    cmd=$(_marvin_sanitize_text "$cmd")
    [[ -n $cmd ]] || { printf 'the operation'; return; }
    printf '%s' "$cmd"
}

_marvin_is_interactive_tty() {
    [[ $- == *i* && -t 0 && -t 1 ]]
}

_marvin_personality_enabled() {
    [[ ${MARVIN_PERSONALITY_LEVEL:-2} =~ ^[0-3]$ ]] || MARVIN_PERSONALITY_LEVEL=2
    ((MARVIN_PERSONALITY_LEVEL > 0))
}

_marvin_comment_gate() {
    local event=${1:-generic} rate=${2:-${MARVIN_COMMENT_RATE:-100}} h=5381 i c str roll
    _marvin_personality_enabled || return 1
    [[ ${MARVIN_QUIET:-0} == 1 || -e $HOME/.marvinquiet ]] && return 1
    [[ $rate =~ ^[0-9]+$ ]] || rate=100
    ((rate <= 0)) && return 1
    ((rate >= 100)) && return 0
    # Inline djb2 hash to avoid $() subshell for _marvin_hash
    str="$event|$_MARVIN_SESSION_ID|$SECONDS|$RANDOM"
    for ((i = 0; i < ${#str} && i < 128; i++)); do
        printf -v c '%d' "'${str:i:1}" 2>/dev/null || c=0
        h=$(( ((h << 5) + h) ^ c ))
        h=$(( h & 0x7FFFFFFF ))
    done
    roll=$(( h % 100 ))
    ((roll < rate))
}

_marvin_ensure_dirs() {
    mkdir -p "$_MARVIN_STATE_DIR"
    chmod 700 "$_MARVIN_STATE_DIR" 2>/dev/null || true
    touch "$_MARVIN_STATE_FILE" "$_MARVIN_HISTORY_FILE" "$_MARVIN_PHRASE_FILE"
    chmod 600 "$_MARVIN_STATE_FILE" "$_MARVIN_HISTORY_FILE" "$_MARVIN_PHRASE_FILE" 2>/dev/null || true
}
