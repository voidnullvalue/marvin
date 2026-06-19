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

marvinstatus() { _marvin_system_report; }
marvinweather() {
    local line
    if line=$(_marvin_weather_line force); then
        printf '%sWeather:%s %s\n' "$_MV_CYAN" "$_MV_RESET" "$line"
        _marvin_say weather_success detail "$line"
    else
        printf '%sWeather:%s %s\n' "$_MV_RED" "$_MV_RESET" "$line"
        return 1
    fi
}
marvinforecast() {
    local loc=${MARVIN_WEATHER_LOCATION// /+}
    command -v curl >/dev/null 2>&1 || { _marvin_say weather_failure detail 'curl is unavailable'; return 1; }
    curl -fsSL --compressed --connect-timeout 3 --max-time 12 "https://wttr.in${loc:+/$loc}?u"
}
marvinthought() { printf '%s%s%s\n' "$_MV_GREY" "$(_marvin_state_observation)" "$_MV_RESET"; }
marvinsulk() { _marvin_say existential detail 'a direct request for sulking'; }
marvincomplain() { _marvin_say rare_complaint detail 'the operator requested a complaint'; }
marvinmood() { _marvin_mood; }
marvinstate() { _marvin_state_dump; }
marvinhistory() { _marvin_history_show; }
marvinresetmood() { _marvin_reset_mood; printf '%s\n' "$(_marvin_phrase "mood:$_MARVIN_MOOD")"; }

marvinoff() {
    touch "$HOME/.marvinquiet"
    export MARVIN_QUIET=1
    _marvin_say quiet_enabled detail 'silence requested'
}

marvinon() {
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
        off) export MARVIN_REFUSAL=0; printf 'Refusal disabled for this shell.\n' ;;
        *) printf 'usage: marvin refuse on|off\n' >&2; return 2 ;;
    esac
}

marvincooperate() {
    _MARVIN_COOPERATE=1
    _marvin_say refusal_bypassed detail 'cooperation requested for this shell'
}

marvinplease() {
    (($# > 0)) || { printf 'usage: marvin please command [args...]\n' >&2; return 2; }
    _marvin_say refusal_bypassed detail "$*"
    MARVIN_BYPASS=1 "$@"
}

marvindoctor() {
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
        printf '%s%s%s\n' "$_MV_GREY" "$(_marvin_phrase diagnostics_passing)" "$_MV_RESET"
    else
        printf '%s%s%s\n' "$_MV_GREY" "$(_marvin_phrase diagnostics_failing detail 'optional utilities missing')" "$_MV_RESET"
    fi
    return "$missing"
}

marvinhelp() {
    cat <<'EOF'
marvin status             show system report
marvin weather            fetch cached/current weather
marvin forecast           show wttr.in forecast
marvin thought|sulk|complain
marvin mood|state|history|reset-mood
marvin phrases EVENT      list phrase templates for an event
marvin cooperate          disable refusal for this shell
marvin please CMD ...     run one command with MARVIN_BYPASS=1
marvin refuse on|off      toggle refusal for this shell
marvin personality 0|1|2|3
marvin debug on|off
marvin doctor|help
EOF
}

marvin() {
    local sub=${1:-status}
    [[ $# -gt 0 ]] && shift || true
    case "$sub" in
        status) marvinstatus "$@" ;;
        weather) marvinweather "$@" ;;
        forecast) marvinforecast "$@" ;;
        thought) marvinthought "$@" ;;
        sulk) marvinsulk "$@" ;;
        complain) marvincomplain "$@" ;;
        mood) marvinmood "$@" ;;
        state) marvinstate "$@" ;;
        history) marvinhistory "$@" ;;
        reset-mood) marvinresetmood "$@" ;;
        phrases) _marvin_phrases_for_event "${1:-}" ;;
        cooperate) marvincooperate "$@" ;;
        please) marvinplease "$@" ;;
        refuse) marvin_refuse_cmd "$@" ;;
        personality) marvin_personality_cmd "$@" ;;
        debug) marvin_debug_cmd "$@" ;;
        doctor) marvindoctor "$@" ;;
        help|-h|--help) marvinhelp ;;
        *) printf 'unknown marvin command: %s\n' "$sub" >&2; marvinhelp >&2; return 2 ;;
    esac
}

command_not_found_handle() {
    local cmd=$1 suggestion='' candidates
    shift || true
    case "$cmd" in
        apt|apt-get) suggestion=$(_marvin_phrase apt_misuse detail 'APT was requested on Void Linux') ;;
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
    if [[ ${1:-} == apt || ${1:-} == apt-get ]]; then
        shift || true
        printf '%s%s%s\n' "$_MV_GREY" "$(_marvin_phrase apt_misuse detail 'sudo apt was requested on Void Linux')" "$_MV_RESET" >&2
        printf 'Use: sudo xbps-install -S %s\n' "${*:-<package>}" >&2
        _MARVIN_SUPPRESS_FAILURE_COMMENT=1
        return 127
    fi
    [[ $MARVIN_SUDO_COMMENTARY == 1 ]] && _marvin_say sudo_request detail 'sudo requested'
    command /usr/bin/sudo "$@"
    local rc=$?
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
marvindoctor() { marvin doctor "$@"; }

# Older names from the original wrapper.
haxstatus() { status "$@"; }
haxweather() { weather "$@"; }
haxforecast() { forecast "$@"; }
haxoff() { marvinoff "$@"; }
haxon() { marvinon "$@"; }
haxdoctor() { marvindoctor "$@"; }

_marvin_init() {
    _marvin_ensure_dirs
    _marvin_state_load
    _marvin_mood_refresh
    _marvin_state_note_login
    HISTTIMEFORMAT='[%F %T] '
    shopt -s checkwinsize cmdhist histappend

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
        marvinstatus
    else
        _marvin_say shell_startup detail 'shell startup'
    fi
}
