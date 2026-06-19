# Public command surface and shell integration.

_marvin_state_observation() {
    local updates down warnings seed uptime_days
    _marvin_telemetry_refresh
    updates=$(_marvin_updates)
    down=$(_marvin_down_services)
    warnings=$(_marvin_warning_state)
    uptime_days=$(awk '{printf "%d", $1/86400}' /proc/uptime 2>/dev/null || printf 0)

    if ((_MARVIN_T_DISK >= 90)); then
        _marvin_phrase high_disk detail "$_MARVIN_T_DISK%"
    elif ((_MARVIN_T_RAM >= 90)); then
        _marvin_phrase high_ram detail "$_MARVIN_T_RAM%"
    elif ((_MARVIN_T_TEMP >= 85)); then
        _marvin_phrase high_temperature detail "$_MARVIN_T_TEMP C"
    elif ((_MARVIN_T_BATTERY_PCT >= 0 && _MARVIN_T_BATTERY_PCT <= 15)); then
        _marvin_phrase low_battery detail "$_MARVIN_T_BATTERY_PCT%"
    elif [[ $down != none && $down != 'not available' ]]; then
        _marvin_phrase failed_services detail "$down"
    elif ((updates > 0)); then
        _marvin_phrase pending_updates detail "$updates"
    elif ((uptime_days >= 30)); then
        _marvin_phrase high_uptime detail "$(command uptime -p 2>/dev/null | sed 's/^up //')"
    else
        seed=$(_marvin_hash "$(command date +%F)|$(_marvin_host)|$USER")
        if ((seed % 97 == 0)); then
            _marvin_phrase accidental_optimism detail "the system looks usable"
        elif ((seed % 29 == 0)); then
            _marvin_phrase existential detail "continued prompt rendering"
        else
            _marvin_phrase healthy_system
        fi
    fi
}

_marvin_system_report() {
    local cols ram disk bat temp updates load procs ipaddr route vpn wifi down weather warnings
    cols=$(_marvin_cols)
    _marvin_telemetry_refresh
    ram=$_MARVIN_T_RAM
    disk=$_MARVIN_T_DISK
    bat=$_MARVIN_T_BATTERY_TEXT
    temp=$(_marvin_temp)
    updates=$(_marvin_updates)
    load=$(awk '{print $1", "$2", "$3}' /proc/loadavg 2>/dev/null)
    procs=$(ps -e --no-headers 2>/dev/null | wc -l | tr -d ' ')
    ipaddr=$(ip -brief -4 address show up scope global 2>/dev/null | awk '{printf "%s%s=%s", sep,$1,$3; sep=", "}')
    route=$(ip route show default 2>/dev/null | awk 'NR==1 {print $3" via "$5}')
    vpn=$_MARVIN_T_VPN
    wifi=$(_marvin_wifi)
    down=$(_marvin_down_services)
    weather=$(_marvin_weather_line cached 2>/dev/null || true)
    warnings=$(_marvin_warning_state)

    printf '%s' "$_MV_BLUE"
    _marvin_rule "$cols"
    printf 'MARVIN TERMINAL INTERFACE\n'
    _marvin_rule "$cols"
    printf '%s' "$_MV_RESET"
    printf '%s%s%s\n\n' "$_MV_GREY" "$(_marvin_phrase login)" "$_MV_RESET"

    printf '  %-18s %s@%s\n' 'User / host' "${USER:-unknown}" "$(_marvin_host)"
    printf '  %-18s %s\n' 'Mood' "$(_marvin_mood)"
    printf '  %-18s %s\n' 'Kernel' "$(uname -r)"
    printf '  %-18s %s\n' 'Uptime' "$(command uptime -p 2>/dev/null | sed 's/^up //')"
    printf '  %-18s %s; %s processes\n' 'Load' "$load" "$procs"
    printf '  %-18s %s (%s%%)\n' 'Memory' "$(_marvin_ram_text)" "$ram"
    printf '  %-18s %s (%s%%)\n' 'Root filesystem' "$(_marvin_disk_text)" "$disk"
    printf '  %-18s %s\n' 'Battery' "$bat"
    printf '  %-18s %s\n' 'Temperature' "$temp"
    printf '  %-18s %s\n' 'Addresses' "${ipaddr:-none reported}"
    printf '  %-18s %s\n' 'Default route' "${route:-none}"
    printf '  %-18s %s\n' 'VPN' "$vpn"
    printf '  %-18s %s\n' 'Wi-Fi' "${wifi:-not reported}"
    printf '  %-18s %s\n' 'Down services' "$down"
    printf '  %-18s %s\n' 'XBPS updates' "$updates"
    printf '  %-18s %s\n' 'Warnings' "$warnings"
    printf '  %-18s %s\n' 'Weather' "${weather:-unavailable}"

    printf '\n%sObservation:%s %s\n' "$_MV_CYAN" "$_MV_RESET" "$(_marvin_state_observation)"
    if ((ram >= 85)); then printf '%sWarning:%s %s\n' "$_MV_YELLOW" "$_MV_RESET" "$(_marvin_phrase high_ram detail "$ram%")"; fi
    if ((disk >= 85)); then printf '%sWarning:%s %s\n' "$_MV_YELLOW" "$_MV_RESET" "$(_marvin_phrase high_disk detail "$disk%")"; fi
    if ((_MARVIN_T_BATTERY_PCT >= 0 && _MARVIN_T_BATTERY_PCT <= 15)); then printf '%sWarning:%s %s\n' "$_MV_YELLOW" "$_MV_RESET" "$(_marvin_phrase low_battery detail "$_MARVIN_T_BATTERY_PCT%")"; fi
    if ((_MARVIN_T_TEMP >= 80)); then printf '%sWarning:%s %s\n' "$_MV_YELLOW" "$_MV_RESET" "$(_marvin_phrase high_temperature detail "$_MARVIN_T_TEMP C")"; fi
    if [[ $down != none && $down != 'not available' ]]; then printf '%sWarning:%s %s\n' "$_MV_YELLOW" "$_MV_RESET" "$(_marvin_phrase failed_services detail "$down")"; fi
    printf '%s' "$_MV_BLUE"; _marvin_rule "$cols"; printf '%s' "$_MV_RESET"
}

_marvin_cmd_status() { _marvin_system_report; }
_marvin_cmd_weather() {
    local line
    if line=$(_marvin_weather_line force); then
        printf '%sWeather:%s %s\n' "$_MV_CYAN" "$_MV_RESET" "$line"
        _marvin_say weather_success detail "$line"
    else
        printf '%sWeather:%s %s\n' "$_MV_RED" "$_MV_RESET" "$line"
        return 1
    fi
}
_marvin_cmd_forecast() {
    local loc=${MARVIN_WEATHER_LOCATION// /+}
    command -v curl >/dev/null 2>&1 || { _marvin_say weather_failure detail 'curl is unavailable'; return 1; }
    curl -fsSL --compressed --connect-timeout 3 --max-time 12 "https://wttr.in${loc:+/$loc}?u"
}
_marvin_cmd_thought() { printf '%s%s%s\n' "$_MV_GREY" "$(_marvin_state_observation)" "$_MV_RESET"; }
_marvin_cmd_sulk() { _marvin_say existential detail 'a direct request for sulking'; }
_marvin_cmd_complain() { _marvin_say rare_complaint detail 'the operator requested a complaint'; }
_marvin_cmd_mood() {
    case "${1:-}" in
        --verbose) _marvin_mood_verbose ;;
        "") _marvin_mood ;;
        *) printf 'usage: marvin mood [--verbose]\n' >&2; return 2 ;;
    esac
}
_marvin_cmd_state() { _marvin_state_dump; }
_marvin_cmd_history() { _marvin_history_show; }
_marvin_cmd_reset_mood() { _marvin_reset_mood; printf '%s\n' "$(_marvin_phrase "mood:$_MARVIN_MOOD")"; }

_marvin_cmd_off() {
    touch "$HOME/.marvinquiet"
    export MARVIN_QUIET=1
    _marvin_say quiet_enabled detail 'silence requested'
}

_marvin_cmd_on() {
    rm -f "$HOME/.marvinquiet"
    unset MARVIN_QUIET
    _marvin_say quiet_disabled detail 'personality restored'
}

marvin_debug_cmd() {
    case "${1:-}" in
        on) export MARVIN_DEBUG=1 _MARVIN_DEBUG=1; printf 'Debug enabled.\n' ;;
        off) export MARVIN_DEBUG=0 _MARVIN_DEBUG=0; printf 'Debug disabled.\n' ;;
        *) printf 'usage: marvin debug on|off\n' >&2; return 2 ;;
    esac
}

marvin_personality_cmd() {
    case "${1:-}" in
        0|1|2|3) export MARVIN_PERSONALITY_LEVEL=$1; printf 'Personality level set to %s.\n' "$1" ;;
        *) printf 'usage: marvin personality 0|1|2|3\n' >&2; return 2 ;;
    esac
}

marvin_refuse_cmd() {
    case "${1:-}" in
        on) export MARVIN_REFUSAL=1; printf 'Refusal enabled for eligible interactive commands.\n' ;;
        off) export MARVIN_REFUSAL=0; _marvin_say refusal_disabled detail 'refusal disabled'; printf 'Refusal disabled for this shell.\n' ;;
        *) printf 'usage: marvin refuse on|off\n' >&2; return 2 ;;
    esac
}

_marvin_cmd_cooperate() {
    _MARVIN_COOPERATE=1
    _marvin_say cooperation_enabled detail 'cooperation requested for this shell'
}

_marvin_cmd_please() {
    (($# > 0)) || { printf 'usage: marvin please command [args...]\n' >&2; return 2; }
    _marvin_say refusal_bypassed detail "$*"
    MARVIN_BYPASS=1 "$@"
}

_marvin_cmd_doctor() {
    local c missing=0
    for c in bash curl xbps-query xbps-install ip ps free df timeout sv git notify-send awk sed fold; do
        if command -v "$c" >/dev/null 2>&1; then
            printf '%savailable%s  %s\n' "$_MV_CYAN" "$_MV_RESET" "$c"
        else
            printf '%smissing%s    %s\n' "$_MV_RED" "$_MV_RESET" "$c"
            missing=1
        fi
    done
    if ((missing == 0)); then
        printf '%s%s%s\n' "$_MV_GREY" "$(_marvin_phrase diagnostic_success detail 'optional utilities available')" "$_MV_RESET"
    else
        printf '%s%s%s\n' "$_MV_GREY" "$(_marvin_phrase diagnostic_failure detail 'optional utilities missing')" "$_MV_RESET"
    fi
    return "$missing"
}

_marvin_cmd_refusal_status() {
    cat <<EOF
enabled=${MARVIN_REFUSAL:-1}
cooperate=$_MARVIN_COOPERATE
session_refusals=$_MARVIN_REFUSALS_THIS_SESSION
session_max=$MARVIN_REFUSAL_SESSION_MAX
eligible_since_last=$MARVIN_STATE_REFUSAL_ELIGIBLE_COUNT
cooldown_commands=$MARVIN_REFUSAL_COOLDOWN_COMMANDS
last_refusal_at=$MARVIN_STATE_REFUSAL_LAST_AT
cooldown_seconds=$MARVIN_REFUSAL_COOLDOWN_SECONDS
status_code=$MARVIN_REFUSAL_STATUS
EOF
}

_marvin_cmd_help() {
    cat <<'EOF'
marvin status             show system report
marvin weather            fetch cached/current weather
marvin forecast           show wttr.in forecast
marvin thought|sulk|complain
marvin mood [--verbose]
marvin state|history|reset-mood
marvin phrases EVENT      list phrase templates for an event
marvin phrase-stats       report event coverage and phrase counts
marvin cooperate          disable refusal for this shell
marvin please CMD ...     run one command with MARVIN_BYPASS=1
marvin refuse on|off      toggle refusal for this shell
marvin refusal-status     show refusal counters and cooldowns
marvin personality 0|1|2|3
marvin debug on|off
marvin benchmark          measure cached prompt overhead
marvin doctor|help
EOF
}

marvin() {
    local sub=${1:-status}
    [[ $# -gt 0 ]] && shift || true
    case "$sub" in
        status) _marvin_cmd_status "$@" ;;
        weather) _marvin_cmd_weather "$@" ;;
        forecast) _marvin_cmd_forecast "$@" ;;
        thought) _marvin_cmd_thought "$@" ;;
        sulk) _marvin_cmd_sulk "$@" ;;
        complain) _marvin_cmd_complain "$@" ;;
        mood) _marvin_cmd_mood "$@" ;;
        state) _marvin_cmd_state "$@" ;;
        history) _marvin_cmd_history "$@" ;;
        reset-mood) _marvin_cmd_reset_mood "$@" ;;
        phrases) _marvin_phrases_for_event "${1:-}" ;;
        phrase-stats) _marvin_phrase_stats ;;
        cooperate) _marvin_cmd_cooperate "$@" ;;
        please) _marvin_cmd_please "$@" ;;
        refuse) marvin_refuse_cmd "$@" ;;
        refusal-status) _marvin_cmd_refusal_status ;;
        personality) marvin_personality_cmd "$@" ;;
        debug) marvin_debug_cmd "$@" ;;
        benchmark) _marvin_benchmark ;;
        doctor) _marvin_cmd_doctor "$@" ;;
        help|-h|--help) _marvin_cmd_help ;;
        *) printf 'unknown marvin command: %s\n' "$sub" >&2; _marvin_cmd_help >&2; return 2 ;;
    esac
}

command_not_found_handle() {
    local cmd=$1 suggestion='' candidates
    shift || true
    case "$cmd" in
        apt|apt-get) suggestion="$(_marvin_phrase apt_misuse detail 'APT was requested on Void Linux') Try: sudo xbps-install -S <package>." ;;
        pacman) suggestion='That belongs to Arch. This machine has enough problems already. Use xbps-install.' ;;
        dnf|yum) suggestion='RPM tooling is not installed. Use xbps-install, and let us never discuss this again.' ;;
        systemctl) suggestion='Void uses runit. Try: sudo sv status|start|stop|restart <service>' ;;
        service) suggestion='Use runit directly: sudo sv status|start|stop|restart <service>' ;;
        ifconfig) suggestion='Use: ip addr. The old command has had a very long day.' ;;
        ipconfig) suggestion='That is a Windows command. Use: ip addr.' ;;
        cls) suggestion='Use: clear.' ;;
        dir) suggestion='Use: ls -la.' ;;
        *) suggestion=$(_marvin_phrase command_not_found command "$cmd" detail "'$cmd' is absent") ;;
    esac
    printf '%s%s%s\n' "$_MV_GREY" "$suggestion" "$_MV_RESET" >&2
    if command -v xbps-query >/dev/null 2>&1; then
        candidates=$(xbps-query -Rs "$cmd" 2>/dev/null | head -n 5)
        if [[ -n $candidates ]]; then
            printf '%s%s%s\n%s\n' "$_MV_CYAN" "$(_marvin_phrase package_suggestion detail "possible packages for $cmd")" "$_MV_RESET" "$candidates" >&2
        else
            printf '%s%s%s\n' "$_MV_GREY" "$(_marvin_phrase no_package_suggestion detail "no packages for $cmd")" "$_MV_RESET" >&2
        fi
    fi
    _MARVIN_SUPPRESS_FAILURE_COMMENT=1
    return 127
}

sudo() {
    local rc sudo_path
    if [[ ${1:-} == apt || ${1:-} == apt-get ]]; then
        shift || true
        printf '%s%s%s\n' "$_MV_GREY" "$(_marvin_phrase apt_misuse detail 'sudo apt was requested on Void Linux')" "$_MV_RESET" >&2
        printf 'Use: sudo xbps-install -S %s\n' "${*:-<package>}" >&2
        _MARVIN_SUPPRESS_FAILURE_COMMENT=1
        return 127
    fi
    [[ $MARVIN_SUDO_COMMENTARY == 1 ]] && _marvin_say sudo_request detail 'sudo requested'
    sudo_path=$(type -P sudo 2>/dev/null)
    if [[ -z $sudo_path ]]; then
        printf 'sudo is not available.\n' >&2
        return 127
    fi
    command "$sudo_path" "$@"
    rc=$?
    if ((rc == 0)); then _marvin_say sudo_success detail 'sudo completed'; else _marvin_say sudo_failure detail "sudo exited $rc"; fi
    return "$rc"
}

# Compatibility commands.
status() { marvin status "$@"; }
weather() { marvin weather "$@"; }
forecast() { marvin forecast "$@"; }
thought() { marvin thought "$@"; }
sulk() { marvin sulk "$@"; }
complain() { marvin complain "$@"; }
mood() { marvin mood "$@"; }

_marvin_init() {
    _marvin_ensure_dirs
    _marvin_state_load
    _marvin_mood_refresh
    _marvin_state_note_login
    shopt -s checkwinsize

    if [[ -e $HOME/.marvinquiet || ${MARVIN_QUIET:-0} == 1 || ${MARVIN_PERSONALITY_LEVEL:-2} == 0 ]]; then
        [[ ${MARVIN_PERSONALITY_LEVEL:-2} == 0 ]] && export MARVIN_QUIET=1
        _marvin_prompt_install
        return
    fi

    if [[ ${_MARVIN_REBOOT_DETECTED:-0} == 1 ]]; then
        _marvin_say reboot_detected detail 'boot identifier changed'
    fi
    _marvin_prompt_install
    if [[ $MARVIN_LOGIN_REPORT == 1 && -z ${MARVIN_LOGIN_SHOWN:-} ]]; then
        export MARVIN_LOGIN_SHOWN=1
        _marvin_cmd_status
    else
        _marvin_say shell_startup detail 'shell startup'
    fi
}
