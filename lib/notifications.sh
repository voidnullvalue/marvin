# Desktop notification personality with sanitization and cooldown.

_MARVIN_LAST_NOTIFICATION=0

_marvin_notify() {
    local event=$1 title=$2 body=$3 now elapsed
    shift 3 || true
    command -v notify-send >/dev/null 2>&1 || return 0
    [[ -n ${DISPLAY:-}${WAYLAND_DISPLAY:-} ]] || return 0
    now=$(command date +%s 2>/dev/null || printf 0)
    elapsed=$((now - _MARVIN_LAST_NOTIFICATION))
    ((elapsed < MARVIN_NOTIFICATION_COOLDOWN)) && return 0
    _MARVIN_LAST_NOTIFICATION=$now
    title=$(_marvin_sanitize_text "$title")
    body=$(_marvin_sanitize_text "$body")
    notify-send "$title" "$body" >/dev/null 2>&1 || true
    _marvin_history_add "notification:$event" "$title"
}

_marvin_notify_command_done() {
    local rc=$1 duration=$2 command_line=${3:-} event title body label
    ((duration >= MARVIN_LONG_COMMAND_SECONDS)) || return 0
    label=$(_marvin_command_label "$command_line")
    if ((rc == 0)); then
        event=notification_success
        title="An operation has concluded"
        body=$(_marvin_phrase notification_success detail "$label succeeded after ${duration}s")
    elif ((rc == 130)); then
        event=notification_interrupted
        title="An operation was interrupted"
        body=$(_marvin_phrase notification_interrupted detail "$label stopped after ${duration}s")
    else
        event=notification_failure
        title="An operation has failed"
        body=$(_marvin_phrase notification_failure detail "$label failed with status $rc after ${duration}s")
    fi
    _marvin_notify "$event" "$title" "$body"
}
