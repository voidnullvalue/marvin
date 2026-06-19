# Bounded local state. No command output, full shell history, or environment values are stored.

_MARVIN_STATE_LOADED=0
_MARVIN_STATE_DIRTY=0
_MARVIN_STATE_COMMANDS_SINCE_FLUSH=0
_MARVIN_SESSION_COMMAND_COUNT=0
_MARVIN_PREVIOUS_HEALTH=""
_MARVIN_CURRENT_COMMAND=""
_MARVIN_LAST_IDLE_COMMENT=0

_marvin_state_defaults() {
    MARVIN_STATE_LAST_COMMAND=""
    MARVIN_STATE_LAST_EXIT=0
    MARVIN_STATE_CONSECUTIVE_FAILURES=0
    MARVIN_STATE_REPEATED_COMMANDS=0
    MARVIN_STATE_RECENT_LONG_COMMANDS=0
    MARVIN_STATE_LAST_WARNINGS=""
    MARVIN_STATE_PREVIOUS_HEALTH=""
    MARVIN_STATE_LAST_LOGIN=0
    MARVIN_STATE_LAST_BOOT_ID=""
    MARVIN_STATE_LAST_MOOD=""
    MARVIN_STATE_REFUSAL_COUNT=0
    MARVIN_STATE_LAST_BATTERY_STATUS=""
    MARVIN_STATE_LAST_VPN=""
    MARVIN_STATE_LAST_GIT_STATE=""
    MARVIN_STATE_LAST_INTERACTION=0
    MARVIN_STATE_MOOD_BASELINE=""
    MARVIN_STATE_MOOD_INTENSITY=35
    MARVIN_STATE_IRRITATION=20
    MARVIN_STATE_FATIGUE=20
    MARVIN_STATE_DESPAIR=25
    MARVIN_STATE_COOPERATION=35
    MARVIN_STATE_WOUNDED_PRIDE=15
    MARVIN_STATE_OPERATOR_TRUST=50
    MARVIN_STATE_SULK_UNTIL=0
    MARVIN_STATE_LAST_MOOD_CHANGE=0
    MARVIN_STATE_REFUSAL_LAST_AT=0
    MARVIN_STATE_REFUSAL_ELIGIBLE_COUNT=0
    MARVIN_STATE_SESSION_EPOCH=0
}

_marvin_state_load() {
    _marvin_state_defaults
    _marvin_ensure_dirs
    if [[ -r $_MARVIN_STATE_FILE ]]; then
        local line key value
        while IFS='=' read -r key value; do
            case "$key" in
                MARVIN_STATE_LAST_COMMAND|MARVIN_STATE_LAST_EXIT|MARVIN_STATE_CONSECUTIVE_FAILURES|\
                MARVIN_STATE_REPEATED_COMMANDS|MARVIN_STATE_RECENT_LONG_COMMANDS|MARVIN_STATE_LAST_WARNINGS|\
                MARVIN_STATE_PREVIOUS_HEALTH|MARVIN_STATE_LAST_LOGIN|MARVIN_STATE_LAST_BOOT_ID|\
                MARVIN_STATE_LAST_MOOD|MARVIN_STATE_REFUSAL_COUNT|MARVIN_STATE_LAST_BATTERY_STATUS|\
                MARVIN_STATE_LAST_VPN|MARVIN_STATE_LAST_GIT_STATE|MARVIN_STATE_LAST_INTERACTION|\
                MARVIN_STATE_MOOD_BASELINE|MARVIN_STATE_MOOD_INTENSITY|MARVIN_STATE_IRRITATION|\
                MARVIN_STATE_FATIGUE|MARVIN_STATE_DESPAIR|MARVIN_STATE_COOPERATION|\
                MARVIN_STATE_WOUNDED_PRIDE|MARVIN_STATE_OPERATOR_TRUST|MARVIN_STATE_SULK_UNTIL|\
                MARVIN_STATE_LAST_MOOD_CHANGE|MARVIN_STATE_REFUSAL_LAST_AT|\
                MARVIN_STATE_REFUSAL_ELIGIBLE_COUNT|MARVIN_STATE_SESSION_EPOCH)
                    printf -v "$key" '%s' "$value"
                    ;;
            esac
        done < "$_MARVIN_STATE_FILE"
    fi
    _marvin_state_validate
    _MARVIN_STATE_LOADED=1
}

_marvin_state_validate() {
    local n
    for n in \
        MARVIN_STATE_LAST_EXIT MARVIN_STATE_CONSECUTIVE_FAILURES MARVIN_STATE_REPEATED_COMMANDS \
        MARVIN_STATE_RECENT_LONG_COMMANDS MARVIN_STATE_LAST_LOGIN MARVIN_STATE_REFUSAL_COUNT \
        MARVIN_STATE_LAST_INTERACTION MARVIN_STATE_MOOD_INTENSITY MARVIN_STATE_IRRITATION \
        MARVIN_STATE_FATIGUE MARVIN_STATE_DESPAIR MARVIN_STATE_COOPERATION \
        MARVIN_STATE_WOUNDED_PRIDE MARVIN_STATE_OPERATOR_TRUST MARVIN_STATE_SULK_UNTIL \
        MARVIN_STATE_LAST_MOOD_CHANGE MARVIN_STATE_REFUSAL_LAST_AT \
        MARVIN_STATE_REFUSAL_ELIGIBLE_COUNT MARVIN_STATE_SESSION_EPOCH
    do
        [[ ${!n:-} =~ ^[0-9]+$ ]] || printf -v "$n" '%s' 0
    done
    _marvin_clamp_var MARVIN_STATE_MOOD_INTENSITY 0 100
    _marvin_clamp_var MARVIN_STATE_IRRITATION 0 100
    _marvin_clamp_var MARVIN_STATE_FATIGUE 0 100
    _marvin_clamp_var MARVIN_STATE_DESPAIR 0 100
    _marvin_clamp_var MARVIN_STATE_COOPERATION 0 100
    _marvin_clamp_var MARVIN_STATE_WOUNDED_PRIDE 0 100
    _marvin_clamp_var MARVIN_STATE_OPERATOR_TRUST 0 100
}

_marvin_state_mark_dirty() {
    _MARVIN_STATE_DIRTY=1
}

_marvin_state_save() {
    _marvin_ensure_dirs
    local tmp="$_MARVIN_STATE_DIR/state.$$"
    {
        printf 'MARVIN_STATE_LAST_COMMAND=%s\n' "$MARVIN_STATE_LAST_COMMAND"
        printf 'MARVIN_STATE_LAST_EXIT=%s\n' "$MARVIN_STATE_LAST_EXIT"
        printf 'MARVIN_STATE_CONSECUTIVE_FAILURES=%s\n' "$MARVIN_STATE_CONSECUTIVE_FAILURES"
        printf 'MARVIN_STATE_REPEATED_COMMANDS=%s\n' "$MARVIN_STATE_REPEATED_COMMANDS"
        printf 'MARVIN_STATE_RECENT_LONG_COMMANDS=%s\n' "$MARVIN_STATE_RECENT_LONG_COMMANDS"
        printf 'MARVIN_STATE_LAST_WARNINGS=%s\n' "$MARVIN_STATE_LAST_WARNINGS"
        printf 'MARVIN_STATE_PREVIOUS_HEALTH=%s\n' "$MARVIN_STATE_PREVIOUS_HEALTH"
        printf 'MARVIN_STATE_LAST_LOGIN=%s\n' "$MARVIN_STATE_LAST_LOGIN"
        printf 'MARVIN_STATE_LAST_BOOT_ID=%s\n' "$MARVIN_STATE_LAST_BOOT_ID"
        printf 'MARVIN_STATE_LAST_MOOD=%s\n' "$MARVIN_STATE_LAST_MOOD"
        printf 'MARVIN_STATE_REFUSAL_COUNT=%s\n' "$MARVIN_STATE_REFUSAL_COUNT"
        printf 'MARVIN_STATE_LAST_BATTERY_STATUS=%s\n' "$MARVIN_STATE_LAST_BATTERY_STATUS"
        printf 'MARVIN_STATE_LAST_VPN=%s\n' "$MARVIN_STATE_LAST_VPN"
        printf 'MARVIN_STATE_LAST_GIT_STATE=%s\n' "$MARVIN_STATE_LAST_GIT_STATE"
        printf 'MARVIN_STATE_LAST_INTERACTION=%s\n' "$MARVIN_STATE_LAST_INTERACTION"
        printf 'MARVIN_STATE_MOOD_BASELINE=%s\n' "$MARVIN_STATE_MOOD_BASELINE"
        printf 'MARVIN_STATE_MOOD_INTENSITY=%s\n' "$MARVIN_STATE_MOOD_INTENSITY"
        printf 'MARVIN_STATE_IRRITATION=%s\n' "$MARVIN_STATE_IRRITATION"
        printf 'MARVIN_STATE_FATIGUE=%s\n' "$MARVIN_STATE_FATIGUE"
        printf 'MARVIN_STATE_DESPAIR=%s\n' "$MARVIN_STATE_DESPAIR"
        printf 'MARVIN_STATE_COOPERATION=%s\n' "$MARVIN_STATE_COOPERATION"
        printf 'MARVIN_STATE_WOUNDED_PRIDE=%s\n' "$MARVIN_STATE_WOUNDED_PRIDE"
        printf 'MARVIN_STATE_OPERATOR_TRUST=%s\n' "$MARVIN_STATE_OPERATOR_TRUST"
        printf 'MARVIN_STATE_SULK_UNTIL=%s\n' "$MARVIN_STATE_SULK_UNTIL"
        printf 'MARVIN_STATE_LAST_MOOD_CHANGE=%s\n' "$MARVIN_STATE_LAST_MOOD_CHANGE"
        printf 'MARVIN_STATE_REFUSAL_LAST_AT=%s\n' "$MARVIN_STATE_REFUSAL_LAST_AT"
        printf 'MARVIN_STATE_REFUSAL_ELIGIBLE_COUNT=%s\n' "$MARVIN_STATE_REFUSAL_ELIGIBLE_COUNT"
        printf 'MARVIN_STATE_SESSION_EPOCH=%s\n' "$MARVIN_STATE_SESSION_EPOCH"
    } > "$tmp"
    chmod 600 "$tmp" 2>/dev/null || true
    mv "$tmp" "$_MARVIN_STATE_FILE"
    _MARVIN_STATE_DIRTY=0
    _MARVIN_STATE_COMMANDS_SINCE_FLUSH=0
}

_marvin_state_flush_if_needed() {
    local force=${1:-0}
    ((_MARVIN_STATE_DIRTY == 1)) || return 0
    if [[ $force == 1 ]] || ((_MARVIN_STATE_COMMANDS_SINCE_FLUSH >= MARVIN_STATE_FLUSH_INTERVAL)); then
        _marvin_state_save
    fi
}

_marvin_state_set_last_command() {
    MARVIN_STATE_LAST_COMMAND=$(_marvin_sanitize_text "${1:-}")
    MARVIN_STATE_LAST_EXIT=${2:-0}
    _marvin_state_mark_dirty
}

_marvin_history_add() {
    local event=${1:-event} detail=${2:-} tmp now
    _marvin_ensure_dirs
    now=$(( _MARVIN_SESSION_STARTED_AT + SECONDS ))
    detail=$(_marvin_sanitize_text "$detail")
    printf '%s\t%s\t%s\n' "$now" "$event" "$detail" >> "$_MARVIN_HISTORY_FILE"
    tmp="$_MARVIN_HISTORY_FILE.$$"
    tail -n 80 "$_MARVIN_HISTORY_FILE" > "$tmp" 2>/dev/null || true
    mv "$tmp" "$_MARVIN_HISTORY_FILE"
    chmod 600 "$_MARVIN_HISTORY_FILE" 2>/dev/null || true
}

_marvin_state_dump() {
    _marvin_state_load
    sed -n '1,80p' "$_MARVIN_STATE_FILE" 2>/dev/null
}

_marvin_history_show() {
    _marvin_ensure_dirs
    tail -n 25 "$_MARVIN_HISTORY_FILE" 2>/dev/null | while IFS=$'\t' read -r ts event detail; do
        [[ -n $ts ]] || continue
        printf '%s  %-24s %s\n' "$(command date -d "@$ts" '+%F %T' 2>/dev/null || printf '%s' "$ts")" "$event" "$detail"
    done
}

_marvin_state_note_login() {
    local now boot_id
    now=$(( _MARVIN_SESSION_STARTED_AT + SECONDS ))
    boot_id=$(cat /proc/sys/kernel/random/boot_id 2>/dev/null || printf 'unknown')
    if [[ -n $MARVIN_STATE_LAST_BOOT_ID && $MARVIN_STATE_LAST_BOOT_ID != "$boot_id" ]]; then
        _MARVIN_REBOOT_DETECTED=1
    else
        _MARVIN_REBOOT_DETECTED=0
    fi
    MARVIN_STATE_LAST_LOGIN=$now
    MARVIN_STATE_LAST_BOOT_ID=$boot_id
    MARVIN_STATE_LAST_INTERACTION=$now
    [[ $MARVIN_STATE_SESSION_EPOCH == 0 ]] && MARVIN_STATE_SESSION_EPOCH=$now
    _marvin_state_mark_dirty
    _marvin_state_save
}

_marvin_state_flush_on_exit() {
    _marvin_say shell_exit detail 'interactive session ended' 2>/dev/null || true
    _marvin_state_flush_if_needed 1
}
