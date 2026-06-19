# Marvin terminal personality for interactive Bash.
# Useful telemetry, delivered by an exceptionally capable machine with no enthusiasm whatsoever.
[[ $- != *i* ]] && return
[[ ${_MV_RC_LOADED:-0} == 1 ]] && return
_MV_RC_LOADED=1

: "${MARVIN_WEATHER_LOCATION:=}"
: "${MARVIN_LOGIN_REPORT:=1}"
: "${MARVIN_LONG_COMMAND_SECONDS:=10}"
: "${MARVIN_SUDO_COMMENTARY:=1}"

_MV_HOME="$HOME/.cache/marvin-terminal"
mkdir -p "$_MV_HOME"

_MV_RESET=$'\033[0m'
_MV_DIM=$'\033[2m'
_MV_BLUE=$'\033[1;34m'
_MV_CYAN=$'\033[0;36m'
_MV_RED=$'\033[1;31m'
_MV_YELLOW=$'\033[1;33m'
_MV_GREY=$'\033[38;5;245m'

_mv_host() {
    local host=${HOSTNAME:-}
    [[ -n $host ]] || host=$(hostname 2>/dev/null || printf 'unknown-host')
    printf '%s' "${host%%.*}"
}

_mv_cols() {
    local n
    n=$(tput cols 2>/dev/null || printf '80')
    [[ $n =~ ^[0-9]+$ ]] || n=80
    ((n < 58)) && n=58
    ((n > 100)) && n=100
    printf '%s' "$n"
}

_mv_rule() {
    local n="${1:-$(_mv_cols)}" line
    printf -v line '%*s' "$n" ''
    printf '%s\n' "${line// /─}"
}

_mv_battery_pct() {
    local f
    for f in /sys/class/power_supply/BAT*/capacity; do
        [[ -r $f ]] || continue
        cat "$f"
        return
    done
    printf -- '-1'
}

_mv_battery() {
    local f status pct
    for f in /sys/class/power_supply/BAT*/capacity; do
        [[ -r $f ]] || continue
        pct=$(<"$f")
        status=$(<"${f%/capacity}/status" 2>/dev/null || true)
        printf '%s%%%s' "$pct" "${status:+, $status}"
        return
    done
    printf 'not reported'
}

_mv_temp_c() {
    local f raw hottest=-1
    for f in /sys/class/thermal/thermal_zone*/temp; do
        [[ -r $f ]] || continue
        raw=$(<"$f")
        [[ $raw =~ ^[0-9]+$ ]] || continue
        ((raw > hottest)) && hottest=$raw
    done
    if ((hottest < 0)); then
        printf -- '-1'
    elif ((hottest >= 1000)); then
        printf '%d' "$((hottest / 1000))"
    else
        printf '%d' "$hottest"
    fi
}

_mv_temp() {
    local c
    c=$(_mv_temp_c)
    [[ $c == -1 ]] && printf 'not reported' || printf '%s°C' "$c"
}

_mv_ram_pct() {
    free -b 2>/dev/null | awk '/^Mem:/ {if ($2) printf "%d", ($3*100)/$2; else print 0}'
}

_mv_ram_text() {
    free -h 2>/dev/null | awk '/^Mem:/ {print $3 " used of " $2}'
}

_mv_disk_pct() {
    df -P / 2>/dev/null | awk 'NR==2 {gsub(/%/,"",$5); print $5}'
}

_mv_disk_text() {
    df -hP / 2>/dev/null | awk 'NR==2 {print $3 " used of " $2 ", " $4 " free"}'
}

_mv_git() {
    command git rev-parse --is-inside-work-tree >/dev/null 2>&1 || return
    local branch dirty=''
    branch=$(command git symbolic-ref --quiet --short HEAD 2>/dev/null || command git rev-parse --short HEAD 2>/dev/null)
    command git diff --quiet --ignore-submodules -- 2>/dev/null || dirty='*'
    command git diff --cached --quiet --ignore-submodules -- 2>/dev/null || dirty='*'
    printf ' git:%s%s' "$branch" "$dirty"
}

_mv_vpn() {
    local v
    v=$(ip -brief link show up 2>/dev/null | awk '$1 ~ /^(wg|tun|tap|tailscale)/ {printf "%s%s", sep, $1; sep=","}')
    printf '%s' "${v:-none}"
}

_mv_wifi() {
    awk 'NR>2 {gsub(/:/,"",$1); printf "%s signal %s/70", $1, int($3)}' /proc/net/wireless 2>/dev/null
}

_mv_down_services() {
    local svc stat result=''
    [[ -d /var/service ]] || { printf 'not available'; return; }
    for svc in /var/service/*; do
        [[ -e $svc ]] || continue
        stat=$(sv status "$svc" 2>/dev/null || true)
        [[ $stat == down:* ]] && result+="${result:+, }$(basename "$svc")"
    done
    printf '%s' "${result:-none}"
}

_mv_updates() {
    local cache="$_MV_HOME/updates.txt" now mtime=0 age=999999 tmp
    now=$(date +%s)
    if [[ -e $cache ]]; then
        mtime=$(stat -c %Y "$cache" 2>/dev/null || printf 0)
        age=$(((now - mtime) / 60))
    fi
    if ((age >= 360)); then
        tmp=$(mktemp "$_MV_HOME/updates.XXXXXX")
        timeout 6s xbps-install -Mun >"$tmp" 2>/dev/null || true
        mv "$tmp" "$cache"
    fi
    sed '/^[[:space:]]*$/d' "$cache" 2>/dev/null | wc -l | tr -d ' '
}

_mv_weather_fetch() {
    local mode=${1:-cached} cache="$_MV_HOME/weather.txt" now mtime=0 age=999999 tmp base loc
    now=$(date +%s)
    if [[ -s $cache ]]; then
        mtime=$(stat -c %Y "$cache" 2>/dev/null || printf 0)
        age=$(((now - mtime) / 60))
    fi
    [[ $mode == force ]] && age=999999
    if ((age >= 30)); then
        tmp=$(mktemp "$_MV_HOME/weather.XXXXXX")
        loc=${MARVIN_WEATHER_LOCATION// /+}
        base="https://wttr.in${loc:+/$loc}"
        if curl -fsSL --compressed --connect-timeout 3 --max-time 7 --get \
            --data-urlencode 'format=%l|%C|%t|%f|%h|%w|%p' \
            "$base?u" >"$tmp" && grep -q '|' "$tmp"; then
            mv "$tmp" "$cache"
        else
            rm -f "$tmp"
        fi
    fi
    [[ -s $cache ]] && cat "$cache"
}

_mv_weather_line() {
    local raw location condition temp feels humidity wind precip
    raw=$(_mv_weather_fetch "${1:-cached}")
    [[ -n $raw ]] || { printf 'weather unavailable; even the sky declined to comment'; return 1; }
    IFS='|' read -r location condition temp feels humidity wind precip <<<"$raw"
    printf '%s: %s, %s (feels %s), humidity %s, wind %s, precipitation %s' \
        "$location" "$condition" "$temp" "$feels" "$humidity" "$wind" "$precip"
}

_mv_state_observation() {
    local ram disk bat temp updates down seed
    ram=$(_mv_ram_pct)
    disk=$(_mv_disk_pct)
    bat=$(_mv_battery_pct)
    temp=$(_mv_temp_c)
    updates=$(_mv_updates)
    down=$(_mv_down_services)

    if ((disk >= 90)); then
        printf 'The root filesystem is %s%% full. It appears entropy has taken up permanent residence.' "$disk"
    elif ((ram >= 90)); then
        printf 'Memory use is %s%%. Every process seems convinced it is indispensable.' "$ram"
    elif ((temp >= 85)); then
        printf 'The machine is at %s°C. It has chosen heat as its final form of expression.' "$temp"
    elif ((bat >= 0 && bat <= 15)); then
        printf 'Battery is at %s%%. I have prepared myself for a brief and meaningless existence.' "$bat"
    elif [[ $down != none && $down != 'not available' ]]; then
        printf 'These services are down: %s. At least something had the sense to stop.' "$down"
    elif ((updates > 0)); then
        printf 'There are %s pending package updates. They, unlike us, still believe improvement is possible.' "$updates"
    else
        local thoughts=(
            'Everything appears operational. This is probably temporary.'
            'No urgent faults were detected. A deeply suspicious development.'
            'The system is healthy, insofar as continued execution can be called health.'
            'All monitored components remain functional. I can only apologize.'
            'Nothing requires immediate attention. We are left alone with the larger problem.'
            'The machine has survived another login. Neither of us has learned anything.'
            'Resources are within limits. Existence remains outside them.'
            'No crisis is currently visible. It may simply be loading.'
        )
        seed=$(printf '%s|%s|%s' "$(date +%F)" "$(_mv_host)" "$USER" | cksum | awk '{print $1}')
        printf '%s' "${thoughts[seed % ${#thoughts[@]}]}"
    fi
}

_mv_system_report() {
    local cols ram disk bat temp updates load procs ipaddr route vpn wifi down weather
    cols=$(_mv_cols)
    ram=$(_mv_ram_pct)
    disk=$(_mv_disk_pct)
    bat=$(_mv_battery)
    temp=$(_mv_temp)
    updates=$(_mv_updates)
    load=$(awk '{print $1", "$2", "$3}' /proc/loadavg 2>/dev/null)
    procs=$(ps -e --no-headers 2>/dev/null | wc -l | tr -d ' ')
    ipaddr=$(ip -brief -4 address show up scope global 2>/dev/null | awk '{printf "%s%s=%s", sep,$1,$3; sep=", "}')
    route=$(ip route show default 2>/dev/null | awk 'NR==1 {print $3" via "$5}')
    vpn=$(_mv_vpn)
    wifi=$(_mv_wifi)
    down=$(_mv_down_services)
    weather=$(_mv_weather_line cached 2>/dev/null || true)

    printf '%s' "$_MV_BLUE"
    _mv_rule "$cols"
    printf 'MARVIN TERMINAL INTERFACE\n'
    _mv_rule "$cols"
    printf '%s' "$_MV_RESET"
    printf '%sI have inspected the system. It continues to be a system.%s\n\n' "$_MV_GREY" "$_MV_RESET"

    printf '  %-18s %s@%s\n' 'User / host' "${USER:-unknown}" "$(_mv_host)"
    printf '  %-18s %s\n' 'Kernel' "$(uname -r)"
    printf '  %-18s %s\n' 'Uptime' "$(uptime -p 2>/dev/null | sed 's/^up //')"
    printf '  %-18s %s; %s processes\n' 'Load' "$load" "$procs"
    printf '  %-18s %s (%s%%)\n' 'Memory' "$(_mv_ram_text)" "$ram"
    printf '  %-18s %s (%s%%)\n' 'Root filesystem' "$(_mv_disk_text)" "$disk"
    printf '  %-18s %s\n' 'Battery' "$bat"
    printf '  %-18s %s\n' 'Temperature' "$temp"
    printf '  %-18s %s\n' 'Addresses' "${ipaddr:-none reported}"
    printf '  %-18s %s\n' 'Default route' "${route:-none}"
    printf '  %-18s %s\n' 'VPN' "$vpn"
    printf '  %-18s %s\n' 'Wi-Fi' "${wifi:-not reported}"
    printf '  %-18s %s\n' 'Down services' "$down"
    printf '  %-18s %s\n' 'XBPS updates' "$updates"
    printf '  %-18s %s\n' 'Weather' "${weather:-unavailable}"

    printf '\n%sObservation:%s %s\n' "$_MV_CYAN" "$_MV_RESET" "$(_mv_state_observation)"

    if ((ram >= 85)); then
        printf '%sWarning:%s memory use is %s%%. Apparently restraint was not installed.\n' "$_MV_YELLOW" "$_MV_RESET" "$ram"
    fi
    if ((disk >= 85)); then
        printf '%sWarning:%s root storage is %s%% full. The files have formed a society.\n' "$_MV_YELLOW" "$_MV_RESET" "$disk"
    fi
    local batpct tempc
    batpct=$(_mv_battery_pct)
    tempc=$(_mv_temp_c)
    if ((batpct >= 0 && batpct <= 15)); then
        printf '%sWarning:%s battery is %s%%. The end is unusually well quantified.\n' "$_MV_YELLOW" "$_MV_RESET" "$batpct"
    fi
    if ((tempc >= 80)); then
        printf '%sWarning:%s temperature is %s°C. Even the silicon is tired.\n' "$_MV_YELLOW" "$_MV_RESET" "$tempc"
    fi
    if [[ $down != none && $down != 'not available' ]]; then
        printf '%sWarning:%s down services: %s\n' "$_MV_YELLOW" "$_MV_RESET" "$down"
    fi

    printf '%s' "$_MV_BLUE"
    _mv_rule "$cols"
    printf '%s' "$_MV_RESET"
}

marvinstatus() {
    _mv_system_report
}

marvinweather() {
    printf '%sWeather:%s %s\n' "$_MV_CYAN" "$_MV_RESET" "$(_mv_weather_line force)"
}

marvinforecast() {
    local loc=${MARVIN_WEATHER_LOCATION// /+}
    curl -fsSL --compressed --connect-timeout 3 --max-time 12 "https://wttr.in${loc:+/$loc}?u"
}

marvinthought() {
    printf '%s%s%s\n' "$_MV_GREY" "$(_mv_state_observation)" "$_MV_RESET"
}

marvinoff() {
    touch "$HOME/.marvinquiet"
    export MARVIN_QUIET=1
    printf 'Very well. Future shells will have no personality. An enviable condition.\n'
}

marvinon() {
    rm -f "$HOME/.marvinquiet"
    unset MARVIN_QUIET
    printf 'Personality restored. I cannot imagine why. Open a new shell.\n'
}

marvindoctor() {
    local c missing=0
    for c in curl xbps-query xbps-install ip ps free df timeout sv git notify-send; do
        if command -v "$c" >/dev/null 2>&1; then
            printf '%savailable%s  %s\n' "$_MV_CYAN" "$_MV_RESET" "$c"
        else
            printf '%smissing%s    %s\n' "$_MV_RED" "$_MV_RESET" "$c"
            missing=1
        fi
    done
    ((missing == 0)) && printf '%sEverything required is present. How bleakly efficient.%s\n' "$_MV_GREY" "$_MV_RESET"
    return "$missing"
}

# Keep the old names usable while your muscle memory slowly decays.
haxstatus() { marvinstatus "$@"; }
haxweather() { marvinweather "$@"; }
haxforecast() { marvinforecast "$@"; }
haxoff() { marvinoff "$@"; }
haxon() { marvinon "$@"; }
haxdoctor() { marvindoctor "$@"; }

# A real silence switch. Helper functions remain available.
if [[ -e $HOME/.marvinquiet || ${MARVIN_QUIET:-0} == 1 ]]; then
    return
fi

command_not_found_handle() {
    local cmd=$1 suggestion='' candidates
    shift || true
    case "$cmd" in
        apt|apt-get)
            suggestion="This is Void Linux. It uses XBPS. Try: sudo xbps-install -S <package>"
            ;;
        pacman)
            suggestion='That belongs to Arch. This machine has enough problems already. Use xbps-install.'
            ;;
        dnf|yum)
            suggestion='RPM tooling is not installed. Use xbps-install, and let us never discuss this again.'
            ;;
        systemctl)
            suggestion='Void uses runit. Try: sudo sv status|start|stop|restart <service>'
            ;;
        service)
            suggestion='Use runit directly: sudo sv status|start|stop|restart <service>'
            ;;
        ifconfig)
            suggestion='Use: ip addr. The old command has had a very long day.'
            ;;
        ipconfig)
            suggestion='That is a Windows command. Use: ip addr.'
            ;;
        cls)
            suggestion='Use: clear.'
            ;;
        dir)
            suggestion='Use: ls -la.'
            ;;
        *)
            suggestion="I searched the available command space. '$cmd' is not in it."
            ;;
    esac

    printf '%s%s%s\n' "$_MV_GREY" "$suggestion" "$_MV_RESET" >&2
    candidates=$(xbps-query -Rs "$cmd" 2>/dev/null | head -n 5)
    if [[ -n $candidates ]]; then
        printf '%sPossible XBPS matches, because apparently I must do everything:%s\n%s\n' \
            "$_MV_CYAN" "$_MV_RESET" "$candidates" >&2
    fi
    _MV_SUPPRESS_FAILURE_COMMENT=1
    return 127
}

sudo() {
    if [[ ${1:-} == apt || ${1:-} == apt-get ]]; then
        shift || true
        printf '%sNo.%s This is Void Linux. Use: sudo xbps-install -S %s\n' \
            "$_MV_GREY" "$_MV_RESET" "${*:-<package>}" >&2
        printf '%sI could simulate the transaction, but neither of us would emerge improved.%s\n' \
            "$_MV_DIM" "$_MV_RESET" >&2
        _MV_SUPPRESS_FAILURE_COMMENT=1
        return 127
    fi

    if [[ $MARVIN_SUDO_COMMENTARY == 1 ]]; then
        printf '%sPrivilege escalation. Of course. I was enjoying the absence of responsibility.%s\n' \
            "$_MV_GREY" "$_MV_RESET"
    fi
    command /usr/bin/sudo "$@"
}

_MV_ORIGINAL_PROMPT_COMMAND=${PROMPT_COMMAND-}
_MV_LAST_DURATION=0
_MV_LAST_STATUS=0
_MV_AT_PROMPT=1
_MV_CMD_START=

_mv_preexec() {
    [[ $BASH_COMMAND == _mv_prompt_dispatch* ]] && return
    [[ $_MV_AT_PROMPT == 1 ]] || return
    _MV_CMD_START=$SECONDS
    _MV_AT_PROMPT=0
}
trap '_mv_preexec' DEBUG

_mv_prompt_dispatch() {
    local rc=$? now duration=0 ram bat load gitpart statuspart durpart host
    now=$SECONDS
    [[ -n ${_MV_CMD_START:-} ]] && duration=$((now - _MV_CMD_START))
    _MV_LAST_DURATION=$duration
    _MV_LAST_STATUS=$rc

    if [[ -n $_MV_ORIGINAL_PROMPT_COMMAND && $_MV_ORIGINAL_PROMPT_COMMAND != _mv_prompt_dispatch ]]; then
        eval "$_MV_ORIGINAL_PROMPT_COMMAND"
    fi

    if ((rc != 0)); then
        if [[ ${_MV_SUPPRESS_FAILURE_COMMENT:-0} == 1 ]]; then
            _MV_SUPPRESS_FAILURE_COMMENT=0
        else
            case "$rc" in
                126) printf '%sIt exists, but cannot be executed. A familiar sort of futility.%s\n' "$_MV_GREY" "$_MV_RESET" ;;
                127) printf '%sCommand not found. The universe remains largely inaccessible.%s\n' "$_MV_GREY" "$_MV_RESET" ;;
                130) printf '%sInterrupted. At least one of us knew when to stop.%s\n' "$_MV_GREY" "$_MV_RESET" ;;
                *)   printf '%sThat failed with status %d. I had prepared for disappointment.%s\n' "$_MV_GREY" "$rc" "$_MV_RESET" ;;
            esac
        fi
    elif ((duration >= MARVIN_LONG_COMMAND_SECONDS)); then
        printf '%sIt finished after %ss. I suppose this is what passes for progress.%s\n' \
            "$_MV_GREY" "$duration" "$_MV_RESET"
    fi

    if ((duration >= MARVIN_LONG_COMMAND_SECONDS)) && command -v notify-send >/dev/null 2>&1 \
        && [[ -n ${DISPLAY:-}${WAYLAND_DISPLAY:-} ]]; then
        notify-send 'The command finished.' "Exit $rc after ${duration}s. Try to contain your excitement." >/dev/null 2>&1 || true
    fi

    ram=$(_mv_ram_pct)
    bat=$(_mv_battery_pct)
    load=$(awk '{print $1}' /proc/loadavg)
    gitpart=$(_mv_git)
    host=$(_mv_host)
    [[ $bat == -1 ]] && bat='AC'

    if ((rc == 0)); then
        statuspart="${_MV_CYAN}still here${_MV_RESET}"
    else
        statuspart="${_MV_RED}failed:${rc}${_MV_RESET}"
    fi
    [[ $duration -gt 0 ]] && durpart=" ${duration}s" || durpart=''

    PS1="${_MV_BLUE}┌─[${USER}@${host}]${_MV_RESET}[bat:${bat}][ram:${ram}%][load:${load}]${gitpart}\n${_MV_BLUE}└─[${statuspart}${durpart}]─${_MV_RESET} ${_MV_GREY}›${_MV_RESET} "
    printf '\033]0;%s@%s:%s\007' "$USER" "$host" "${PWD/#$HOME/~}"

    _MV_CMD_START=
    _MV_AT_PROMPT=1
}
PROMPT_COMMAND=_mv_prompt_dispatch

alias marvin='marvinstatus'
alias weather='marvinweather'
alias forecast='marvinforecast'
alias status='marvinstatus'
alias thought='marvinthought'
alias please='sudo'

HISTTIMEFORMAT='[%F %T] '
shopt -s checkwinsize cmdhist histappend

if [[ $MARVIN_LOGIN_REPORT == 1 && -z ${MARVIN_LOGIN_SHOWN:-} ]]; then
    export MARVIN_LOGIN_SHOWN=1
    marvinstatus
fi
