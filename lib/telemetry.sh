# System telemetry with lightweight prompt caching.

_MARVIN_TELEMETRY_CACHE_TIME=0
_MARVIN_T_RAM=0
_MARVIN_T_DISK=0
_MARVIN_T_BATTERY_PCT=-1
_MARVIN_T_BATTERY_TEXT="not reported"
_MARVIN_T_BATTERY_STATUS=""
_MARVIN_T_TEMP=-1
_MARVIN_T_LOAD="0.00"
_MARVIN_T_GIT=""
_MARVIN_T_VPN="none"
_MARVIN_T_LAST_PWD=""

_MARVIN_WARNING_CACHE_TIME=0
_MARVIN_WARNING_CACHE_VALUE="none"

_MARVIN_UPDATES_CACHE=-1
_MARVIN_UPDATES_CACHE_TIME=0

_MARVIN_DOWN_SERVICES_CACHE="not available"
_MARVIN_DOWN_SERVICES_CACHE_TIME=0

_marvin_battery_pct() {
    local f
    for f in /sys/class/power_supply/BAT*/capacity; do
        [[ -r $f ]] || continue
        cat "$f"
        return
    done
    printf -- '-1'
}

_marvin_battery_status() {
    local f
    for f in /sys/class/power_supply/BAT*/status; do
        [[ -r $f ]] || continue
        cat "$f"
        return
    done
    printf ''
}

_marvin_battery() {
    local pct status
    pct=$(_marvin_battery_pct)
    status=$(_marvin_battery_status)
    [[ $pct == -1 ]] && printf 'not reported' || printf '%s%%%s' "$pct" "${status:+, $status}"
}

_marvin_temp_c() {
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

_marvin_temp() {
    local c
    c=$(_marvin_temp_c)
    [[ $c == -1 ]] && printf 'not reported' || printf '%sC' "$c"
}

_marvin_ram_pct() {
    local memtotal=0 memavail=0 key value _rest
    while read -r key value _rest; do
        case $key in
            MemTotal:)     memtotal=$value ;;
            MemAvailable:) memavail=$value ;;
        esac
        [[ $memtotal -gt 0 && $memavail -gt 0 ]] && break
    done < /proc/meminfo 2>/dev/null
    (( memtotal > 0 )) && printf '%d' $(( (memtotal - memavail) * 100 / memtotal )) || printf '0'
}

_marvin_ram_text() {
    free -h 2>/dev/null | awk '/^Mem:/ {print $3 " used of " $2}'
}

_marvin_disk_pct() {
    df -P / 2>/dev/null | awk 'NR==2 {gsub(/%/,"",$5); print $5}'
}

_marvin_disk_text() {
    df -hP / 2>/dev/null | awk 'NR==2 {print $3 " used of " $2 ", " $4 " free"}'
}

_marvin_git_state() {
    command git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { printf 'none'; return; }
    local branch dirty='' state symbolic_ref
    symbolic_ref=$(command git symbolic-ref --quiet --short HEAD 2>/dev/null)
    if [[ -n $symbolic_ref ]]; then
        branch=$symbolic_ref
    else
        branch=$(command git rev-parse --short HEAD 2>/dev/null)
    fi
    command git diff --quiet --ignore-submodules -- 2>/dev/null || dirty='dirty'
    command git diff --cached --quiet --ignore-submodules -- 2>/dev/null || dirty='dirty'
    if [[ -z $symbolic_ref ]]; then
        state="detached:$branch"
    elif [[ -n $dirty ]]; then
        state="dirty:$branch"
    else
        state="clean:$branch"
    fi
    printf '%s' "$state"
}

_marvin_git_prompt() {
    local state=${1:-$(_marvin_git_state)} branch
    case "$state" in
        none) return ;;
        dirty:*) branch=${state#dirty:}; printf ' git:%s*' "$branch" ;;
        clean:*) branch=${state#clean:}; printf ' git:%s' "$branch" ;;
        detached:*) branch=${state#detached:}; printf ' git:%s!' "$branch" ;;
    esac
}

_marvin_vpn() {
    local iface result='' state
    for iface in /sys/class/net/*/operstate; do
        [[ -r $iface ]] || continue
        iface=${iface%/operstate}; iface=${iface##*/}
        [[ $iface =~ ^(wg|tun|tap|tailscale) ]] || continue
        read -r state < "/sys/class/net/$iface/operstate" 2>/dev/null || state=unknown
        [[ $state == up || $state == unknown ]] && result+="${result:+,}$iface"
    done
    printf '%s' "${result:-none}"
}

_marvin_wifi() {
    awk 'NR>2 {gsub(/:/,"",$1); printf "%s signal %s/70", $1, int($3)}' /proc/net/wireless 2>/dev/null
}

_marvin_down_services() {
    local now=$(( _MARVIN_SESSION_STARTED_AT + SECONDS ))
    if (( _MARVIN_DOWN_SERVICES_CACHE_TIME > 0 && now - _MARVIN_DOWN_SERVICES_CACHE_TIME < MARVIN_TELEMETRY_TTL )); then
        printf '%s' "$_MARVIN_DOWN_SERVICES_CACHE"
        return
    fi
    _MARVIN_DOWN_SERVICES_CACHE_TIME=$now
    local svc stat result=''
    if [[ ! -d /var/service ]]; then
        _MARVIN_DOWN_SERVICES_CACHE='not available'
        printf 'not available'; return
    fi
    if ! command -v sv >/dev/null 2>&1; then
        _MARVIN_DOWN_SERVICES_CACHE='not available'
        printf 'not available'; return
    fi
    for svc in /var/service/*; do
        [[ -e $svc ]] || continue
        stat=$(sv status "$svc" 2>/dev/null || true)
        [[ $stat == down:* ]] && result+="${result:+, }$(basename "$svc")"
    done
    _MARVIN_DOWN_SERVICES_CACHE="${result:-none}"
    printf '%s' "${result:-none}"
}

_marvin_updates() {
    local now=$(( _MARVIN_SESSION_STARTED_AT + SECONDS ))
    # In-memory cache valid for 1 hour
    if (( _MARVIN_UPDATES_CACHE >= 0 && now - _MARVIN_UPDATES_CACHE_TIME < 3600 )); then
        printf '%d' "$_MARVIN_UPDATES_CACHE"
        return
    fi
    local cache="$_MARVIN_STATE_DIR/updates.txt" mtime=0 file_age_mins=999999
    if [[ -e $cache ]]; then
        mtime=$(stat -c %Y "$cache" 2>/dev/null || printf 0)
        (( mtime > 0 )) && file_age_mins=$(( (now - mtime) / 60 ))
    fi
    if ((file_age_mins >= 360)) && command -v xbps-install >/dev/null 2>&1 && command -v timeout >/dev/null 2>&1; then
        local tmp
        tmp=$(mktemp "$_MARVIN_STATE_DIR/updates.XXXXXX")
        timeout 6s xbps-install -Mun >"$tmp" 2>/dev/null || true
        mv "$tmp" "$cache"
    fi
    local count=0 line
    if [[ -r $cache ]]; then
        while IFS= read -r line || [[ -n $line ]]; do
            [[ -n ${line//[[:space:]]/} ]] && (( count++ ))
        done < "$cache"
    fi
    _MARVIN_UPDATES_CACHE=$count
    _MARVIN_UPDATES_CACHE_TIME=$now
    printf '%d' "$count"
}

_marvin_telemetry_refresh() {
    local now age
    now=$SECONDS
    age=$((now - _MARVIN_TELEMETRY_CACHE_TIME))

    # Invalidate git state when directory changes, even within the TTL window.
    if [[ $_MARVIN_T_LAST_PWD != "$PWD" ]]; then
        _MARVIN_T_LAST_PWD=$PWD
        if (( age < MARVIN_TELEMETRY_TTL && _MARVIN_TELEMETRY_CACHE_TIME > 0 )); then
            _MARVIN_T_GIT=$(_marvin_git_state)
            return 0
        fi
    fi

    ((age < MARVIN_TELEMETRY_TTL && _MARVIN_TELEMETRY_CACHE_TIME > 0)) && return 0
    _MARVIN_TELEMETRY_CACHE_TIME=$now
    _MARVIN_T_RAM=$(_marvin_ram_pct); [[ -n $_MARVIN_T_RAM ]] || _MARVIN_T_RAM=0
    _MARVIN_T_DISK=$(_marvin_disk_pct); [[ -n $_MARVIN_T_DISK ]] || _MARVIN_T_DISK=0
    _MARVIN_T_BATTERY_PCT=$(_marvin_battery_pct)
    _MARVIN_T_BATTERY_STATUS=$(_marvin_battery_status)
    if [[ $_MARVIN_T_BATTERY_PCT == -1 ]]; then
        _MARVIN_T_BATTERY_TEXT="not reported"
    else
        _MARVIN_T_BATTERY_TEXT="${_MARVIN_T_BATTERY_PCT}%${_MARVIN_T_BATTERY_STATUS:+, $_MARVIN_T_BATTERY_STATUS}"
    fi
    _MARVIN_T_TEMP=$(_marvin_temp_c)
    read -r _MARVIN_T_LOAD _ < /proc/loadavg 2>/dev/null || _MARVIN_T_LOAD='0.00'
    _MARVIN_T_GIT=$(_marvin_git_state)
    _MARVIN_T_VPN=$(_marvin_vpn)
}

_marvin_warning_state() {
    local now=$(( _MARVIN_SESSION_STARTED_AT + SECONDS ))
    if (( _MARVIN_WARNING_CACHE_TIME > 0 && now - _MARVIN_WARNING_CACHE_TIME < MARVIN_TELEMETRY_TTL )); then
        printf '%s' "$_MARVIN_WARNING_CACHE_VALUE"
        return
    fi
    _MARVIN_WARNING_CACHE_TIME=$now
    local warnings=() updates down
    _marvin_telemetry_refresh
    updates=$(_marvin_updates)
    down=$(_marvin_down_services)
    ((_MARVIN_T_RAM >= 85)) && warnings+=("high_ram")
    ((_MARVIN_T_DISK >= 85)) && warnings+=("high_disk")
    ((_MARVIN_T_TEMP >= 80)) && warnings+=("high_temperature")
    ((_MARVIN_T_BATTERY_PCT >= 0 && _MARVIN_T_BATTERY_PCT <= 15)) && warnings+=("low_battery")
    [[ $down != none && $down != 'not available' ]] && warnings+=("failed_services")
    ((updates > 0)) && warnings+=("pending_updates")
    local result
    (( ${#warnings[@]} == 0 )) && result='none' || result="${warnings[*]}"
    _MARVIN_WARNING_CACHE_VALUE=$result
    printf '%s' "$result"
}

_marvin_observe_state_changes() {
    local warnings old battery vpn git
    warnings=$(_marvin_warning_state)
    old=${MARVIN_STATE_LAST_WARNINGS:-none}
    if [[ $old != "$warnings" && $old != none && $warnings == none ]]; then
        _MARVIN_RECOVERY_FLAG=1
        _marvin_mood_apply_event warning_recovered
        _marvin_say system_recovery detail "$old"
    elif [[ $warnings != none ]]; then
        _marvin_mood_apply_event warning_seen
    fi
    MARVIN_STATE_LAST_WARNINGS=$warnings

    battery=$_MARVIN_T_BATTERY_STATUS
    if [[ -n $MARVIN_STATE_LAST_BATTERY_STATUS && $battery != "$MARVIN_STATE_LAST_BATTERY_STATUS" && $battery == Charging* ]]; then
        _marvin_say charging_battery detail "$_MARVIN_T_BATTERY_TEXT"
    fi
    MARVIN_STATE_LAST_BATTERY_STATUS=$battery

    vpn=$_MARVIN_T_VPN
    if [[ -n $MARVIN_STATE_LAST_VPN && $vpn != "$MARVIN_STATE_LAST_VPN" ]]; then
        if [[ $vpn == none ]]; then
            _marvin_say vpn_inactive detail "the VPN disappeared"
        else
            _marvin_say vpn_active detail "$vpn"
        fi
    fi
    MARVIN_STATE_LAST_VPN=$vpn

    git=$_MARVIN_T_GIT
    if [[ -n $MARVIN_STATE_LAST_GIT_STATE && $git != "$MARVIN_STATE_LAST_GIT_STATE" ]]; then
        case "$git" in
            clean:*) _marvin_mood_apply_event clean_git; _marvin_say clean_git detail "$git" ;;
            dirty:*) _marvin_mood_apply_event dirty_git; _marvin_say dirty_git detail "$git" ;;
            detached:*) _marvin_say detached_head detail "$git" ;;
        esac
    fi
    MARVIN_STATE_LAST_GIT_STATE=$git
    _marvin_state_mark_dirty
    _marvin_state_flush_if_needed 0
}
