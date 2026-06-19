# Bounded local state. No command output, full shell history, or environment values are stored.

_MARVIN_STATE_LOADED=0
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
                MARVIN_STATE_LAST_VPN|MARVIN_STATE_LAST_GIT_STATE|MARVIN_STATE_LAST_INTERACTION)
                    printf -v "$key" '%s' "$value"
                    ;;
            esac
        done < "$_MARVIN_STATE_FILE"
    fi
    _MARVIN_STATE_LOADED=1
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
    } > "$tmp"
    chmod 600 "$tmp" 2>/dev/null || true
    mv "$tmp" "$_MARVIN_STATE_FILE"
}

_marvin_state_set_last_command() {
    MARVIN_STATE_LAST_COMMAND=$(_marvin_sanitize_text "${1:-}")
    MARVIN_STATE_LAST_EXIT=${2:-0}
    _marvin_state_save
}

_marvin_history_add() {
    local event=${1:-event} detail=${2:-} tmp now
    _marvin_ensure_dirs
    now=$(command date +%s 2>/dev/null || printf 0)
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
    now=$(command date +%s 2>/dev/null || printf 0)
    boot_id=$(cat /proc/sys/kernel/random/boot_id 2>/dev/null || printf 'unknown')
    if [[ -n $MARVIN_STATE_LAST_BOOT_ID && $MARVIN_STATE_LAST_BOOT_ID != "$boot_id" ]]; then
        _MARVIN_REBOOT_DETECTED=1
    else
        _MARVIN_REBOOT_DETECTED=0
    fi
    MARVIN_STATE_LAST_LOGIN=$now
    MARVIN_STATE_LAST_BOOT_ID=$boot_id
    MARVIN_STATE_LAST_INTERACTION=$now
    _marvin_state_save
}
