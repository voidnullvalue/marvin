# DEBUG/PROMPT_COMMAND based timing and compact prompt rendering.

_MARVIN_ORIGINAL_PROMPT_COMMAND_KIND=none
_MARVIN_ORIGINAL_PROMPT_COMMAND_STRING=""
_MARVIN_ORIGINAL_PROMPT_COMMAND_ARRAY=()
_MARVIN_LAST_DURATION=0
_MARVIN_LAST_STATUS=0
_MARVIN_AT_PROMPT=1
_MARVIN_CMD_START=
_MARVIN_ORIGINAL_DEBUG_TRAP=""

_marvin_capture_original_prompt_command() {
    local decl
    decl=$(declare -p PROMPT_COMMAND 2>/dev/null || true)
    if [[ $decl == declare\ -a* || $decl == declare\ -ax* ]]; then
        _MARVIN_ORIGINAL_PROMPT_COMMAND_ARRAY=("${PROMPT_COMMAND[@]}")
        _MARVIN_ORIGINAL_PROMPT_COMMAND_KIND=array
    elif [[ -n ${PROMPT_COMMAND-} && ${PROMPT_COMMAND-} != _marvin_prompt_dispatch ]]; then
        _MARVIN_ORIGINAL_PROMPT_COMMAND_STRING=${PROMPT_COMMAND-}
        _MARVIN_ORIGINAL_PROMPT_COMMAND_KIND=string
    fi
}

_marvin_run_original_prompt_command() {
    local entry
    case "$_MARVIN_ORIGINAL_PROMPT_COMMAND_KIND" in
        array)
            for entry in "${_MARVIN_ORIGINAL_PROMPT_COMMAND_ARRAY[@]}"; do
                [[ $entry == _marvin_prompt_dispatch ]] && continue
                if [[ $entry =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] && declare -F "$entry" >/dev/null 2>&1; then
                    "$entry"
                fi
            done
            ;;
        string)
            if [[ $_MARVIN_ORIGINAL_PROMPT_COMMAND_STRING =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] && declare -F "$_MARVIN_ORIGINAL_PROMPT_COMMAND_STRING" >/dev/null 2>&1; then
                "$_MARVIN_ORIGINAL_PROMPT_COMMAND_STRING"
            else
                _marvin_debug "skipping complex PROMPT_COMMAND because it is not a simple function name"
            fi
            ;;
    esac
}

_marvin_preexec() {
    [[ $BASH_COMMAND == _marvin_prompt_dispatch* ]] && return 0
    [[ $BASH_COMMAND == _marvin_preexec* ]] && return 0
    [[ $_MARVIN_AT_PROMPT == 1 ]] || return 0
    _MARVIN_CURRENT_COMMAND=$(_marvin_sanitize_text "$BASH_COMMAND")
    _MARVIN_CMD_START=$SECONDS
    _MARVIN_AT_PROMPT=0
}

_marvin_update_command_state() {
    local rc=$1 duration=$2 command_line=${3:-} previous_rc previous_command
    previous_rc=${MARVIN_STATE_LAST_EXIT:-0}
    previous_command=${MARVIN_STATE_LAST_COMMAND:-}
    _MARVIN_SESSION_COMMAND_COUNT=$((_MARVIN_SESSION_COMMAND_COUNT + 1))
    _MARVIN_STATE_COMMANDS_SINCE_FLUSH=$((_MARVIN_STATE_COMMANDS_SINCE_FLUSH + 1))
    MARVIN_STATE_LAST_EXIT=$rc
    if [[ -n $command_line && $command_line == "$MARVIN_STATE_LAST_COMMAND" ]]; then
        MARVIN_STATE_REPEATED_COMMANDS=$((MARVIN_STATE_REPEATED_COMMANDS + 1))
    else
        MARVIN_STATE_REPEATED_COMMANDS=0
    fi
    if ((rc != 0)); then
        MARVIN_STATE_CONSECUTIVE_FAILURES=$((MARVIN_STATE_CONSECUTIVE_FAILURES + 1))
    else
        MARVIN_STATE_CONSECUTIVE_FAILURES=0
    fi
    if ((duration >= MARVIN_LONG_COMMAND_SECONDS)); then
        MARVIN_STATE_RECENT_LONG_COMMANDS=$((MARVIN_STATE_RECENT_LONG_COMMANDS + 1))
        ((MARVIN_STATE_RECENT_LONG_COMMANDS > 10)) && MARVIN_STATE_RECENT_LONG_COMMANDS=10
    elif ((MARVIN_STATE_RECENT_LONG_COMMANDS > 0)); then
        MARVIN_STATE_RECENT_LONG_COMMANDS=$((MARVIN_STATE_RECENT_LONG_COMMANDS - 1))
    fi
    MARVIN_STATE_LAST_COMMAND=$command_line
    MARVIN_STATE_LAST_INTERACTION=$(_marvin_now)
    if ((rc != 0)); then
        if ((MARVIN_STATE_CONSECUTIVE_FAILURES >= 2)); then
            _marvin_mood_apply_event repeated_failure
        else
            _marvin_mood_apply_event command_failure
        fi
        _marvin_history_add command "$command_line -> $rc/${duration}s"
    elif [[ -n $previous_command && $previous_rc != 0 && $previous_command != "$command_line" ]]; then
        _marvin_mood_apply_event command_fixed
        _marvin_history_add command_fixed "$command_line"
    elif ((duration >= MARVIN_LONG_COMMAND_SECONDS)); then
        _marvin_mood_apply_event long_success
        _marvin_history_add long_success "$command_line -> ${duration}s"
    else
        _marvin_mood_apply_event ordinary_success
    fi
    if ((MARVIN_STATE_REPEATED_COMMANDS >= 2)); then
        _marvin_mood_apply_event repeated_command
        _marvin_history_add repeated_command "$command_line"
    fi
    _marvin_state_mark_dirty
    if ((rc != 0 || duration >= MARVIN_LONG_COMMAND_SECONDS || MARVIN_STATE_REPEATED_COMMANDS >= 2)); then
        _marvin_state_flush_if_needed 1
    else
        _marvin_state_flush_if_needed 0
    fi
}

_marvin_comment_after_command() {
    local rc=$1 duration=$2 command_line=${3:-}
    if ((MARVIN_STATE_REPEATED_COMMANDS >= 2)); then
        _marvin_say repeated_command detail "$command_line"
    fi
    if ((rc != 0)); then
        if [[ ${_MARVIN_SUPPRESS_FAILURE_COMMENT:-0} == 1 ]]; then
            _MARVIN_SUPPRESS_FAILURE_COMMENT=0
            return
        fi
        if ((MARVIN_STATE_CONSECUTIVE_FAILURES >= 2)); then
            _marvin_say repeated_failure status "$rc"
            return
        fi
        case "$rc" in
            126) _marvin_say exit_126 status "$rc" ;;
            127) _marvin_say exit_127 status "$rc" ;;
            130) _marvin_say exit_130 status "$rc" ;;
            *) _marvin_say command_failure status "$rc" ;;
        esac
    elif ((duration >= MARVIN_LONG_COMMAND_SECONDS)); then
        _marvin_say long_success duration "$duration"
    elif ((duration == 0)); then
        _marvin_say fast_success
    else
        _marvin_say command_success
    fi
}

_marvin_idle_check() {
    local now last idle
    now=$(_marvin_now)
    last=${MARVIN_STATE_LAST_INTERACTION:-0}
    [[ $last =~ ^[0-9]+$ ]] || last=0
    idle=$((now - last))
    if ((idle >= 1800 && now - _MARVIN_LAST_IDLE_COMMENT >= 1800)); then
        _MARVIN_LAST_IDLE_COMMENT=$now
        _marvin_mood_apply_event idle_return
        _marvin_say operator_returning duration "$idle"
    fi
}

_marvin_prompt_dispatch() {
    local rc=$? now duration=0 ram bat load gitpart statuspart durpart host label cmd
    now=$SECONDS
    [[ -n ${_MARVIN_CMD_START:-} ]] && duration=$((now - _MARVIN_CMD_START))
    cmd=$_MARVIN_CURRENT_COMMAND
    _MARVIN_LAST_DURATION=$duration
    _MARVIN_LAST_STATUS=$rc

    _marvin_run_original_prompt_command
    _marvin_update_command_state "$rc" "$duration" "$cmd"
    _marvin_mood_refresh
    _marvin_comment_after_command "$rc" "$duration" "$cmd"
    _marvin_notify_command_done "$rc" "$duration" "$cmd"
    _marvin_telemetry_refresh
    _marvin_observe_state_changes
    _marvin_idle_check

    ram=$_MARVIN_T_RAM
    bat=$_MARVIN_T_BATTERY_PCT
    load=$_MARVIN_T_LOAD
    gitpart=$(_marvin_git_prompt "$_MARVIN_T_GIT")
    host=$(_marvin_host)
    [[ $bat == -1 ]] && bat='AC'
    label=$(_marvin_mood_label)

    if ((rc == 0)); then
        statuspart="${_MV_CYAN}${label}${_MV_RESET}"
    else
        statuspart="${_MV_RED}failed:${rc}${_MV_RESET}"
    fi
    [[ $duration -gt 0 ]] && durpart=" ${duration}s" || durpart=''

    PS1="\[${_MV_BLUE}\]┌─[${USER}@${host}]\[${_MV_RESET}\][bat:${bat}][ram:${ram}%][load:${load}]${gitpart}\n\[${_MV_BLUE}\]└─[${statuspart}${durpart}]\[${_MV_RESET}\] \[${_MV_GREY}\]›\[${_MV_RESET}\] "
    printf '\033]0;%s@%s:%s\007' "$USER" "$host" "${PWD/#$HOME/~}"

    _MARVIN_CMD_START=
    _MARVIN_CURRENT_COMMAND=
    _MARVIN_AT_PROMPT=1
}

_marvin_prompt_install() {
    _marvin_capture_original_prompt_command
    _MARVIN_ORIGINAL_DEBUG_TRAP=$(trap -p DEBUG)
    if [[ -n $_MARVIN_ORIGINAL_DEBUG_TRAP ]]; then
        _marvin_debug "existing DEBUG trap detected; Marvin timing will replace it for this shell"
    fi
    trap '_marvin_preexec' DEBUG
    if declare -p PROMPT_COMMAND 2>/dev/null | grep -q '^declare -a'; then
        PROMPT_COMMAND=(_marvin_prompt_dispatch)
    else
        PROMPT_COMMAND=_marvin_prompt_dispatch
    fi
    trap '_marvin_state_flush_on_exit' EXIT
}

_marvin_benchmark() {
    local i start end total avg
    _marvin_telemetry_refresh
    start=$(command date +%s%N 2>/dev/null || printf 0)
    for i in {1..25}; do
        _marvin_telemetry_refresh
        _marvin_git_prompt "$_MARVIN_T_GIT" >/dev/null
    done
    end=$(command date +%s%N 2>/dev/null || printf 0)
    if [[ $start =~ ^[0-9]+$ && $end =~ ^[0-9]+$ && $end -gt $start ]]; then
        total=$(((end - start) / 1000000))
        avg=$((total / 25))
        printf 'cached_prompt_approx_ms=%s\n' "$avg"
    else
        printf 'cached_prompt_approx_ms=unknown\n'
    fi
}
