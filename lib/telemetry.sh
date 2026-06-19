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
    free -b 2>/dev/null | awk '/^Mem:/ {if ($2) printf "%d", ($3*100)/$2; else print 0}'
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
    local branch dirty='' state
    branch=$(command git symbolic-ref --quiet --short HEAD 2>/dev/null || command git rev-parse --short HEAD 2>/dev/null)
    command git diff --quiet --ignore-submodules -- 2>/dev/null || dirty='dirty'
    command git diff --cached --quiet --ignore-submodules -- 2>/dev/null || dirty='dirty'
    if ! command git symbolic-ref --quiet HEAD >/dev/null 2>&1; then
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
    local v
    v=$(ip -brief link show up 2>/dev/null | awk '$1 ~ /^(wg|tun|tap|tailscale)/ {printf "%s%s", sep, $1; sep=","}')
    printf '%s' "${v:-none}"
}

_marvin_wifi() {
    awk 'NR>2 {gsub(/:/,"",$1); printf "%s signal %s/70", $1, int($3)}' /proc/net/wireless 2>/dev/null
}

_marvin_down_services() {
    local svc stat result=''
    [[ -d /var/service ]] || { printf 'not available'; return; }
    command -v sv >/dev/null 2>&1 || { printf 'not available'; return; }
    for svc in /var/service/*; do
        [[ -e $svc ]] || continue
        stat=$(sv status "$svc" 2>/dev/null || true)
        [[ $stat == down:* ]] && result+="${result:+, }$(basename "$svc")"
    done
    printf '%s' "${result:-none}"
}

_marvin_updates() {
    local cache="$_MARVIN_STATE_DIR/updates.txt" now mtime=0 age=999999 tmp
    now=$(command date +%s)
    if [[ -e $cache ]]; then
        mtime=$(stat -c %Y "$cache" 2>/dev/null || printf 0)
        age=$(((now - mtime) / 60))
    fi
    if ((age >= 360)) && command -v xbps-install >/dev/null 2>&1 && command -v timeout >/dev/null 2>&1; then
        tmp=$(mktemp "$_MARVIN_STATE_DIR/updates.XXXXXX")
        timeout 6s xbps-install -Mun >"$tmp" 2>/dev/null || true
        mv "$tmp" "$cache"
    fi
    sed '/^[[:space:]]*$/d' "$cache" 2>/dev/null | wc -l | tr -d ' '
}

_marvin_telemetry_refresh() {
    local now age
    now=$SECONDS
    age=$((now - _MARVIN_TELEMETRY_CACHE_TIME))
    ((age < MARVIN_TELEMETRY_TTL && _MARVIN_TELEMETRY_CACHE_TIME > 0)) && return 0
    _MARVIN_TELEMETRY_CACHE_TIME=$now
    _MARVIN_T_RAM=$(_marvin_ram_pct); [[ -n $_MARVIN_T_RAM ]] || _MARVIN_T_RAM=0
    _MARVIN_T_DISK=$(_marvin_disk_pct); [[ -n $_MARVIN_T_DISK ]] || _MARVIN_T_DISK=0
    _MARVIN_T_BATTERY_PCT=$(_marvin_battery_pct)
    _MARVIN_T_BATTERY_STATUS=$(_marvin_battery_status)
    _MARVIN_T_BATTERY_TEXT=$(_marvin_battery)
    _MARVIN_T_TEMP=$(_marvin_temp_c)
    _MARVIN_T_LOAD=$(awk '{print $1}' /proc/loadavg 2>/dev/null || printf '0.00')
    _MARVIN_T_GIT=$(_marvin_git_state)
    _MARVIN_T_VPN=$(_marvin_vpn)
}

_marvin_warning_state() {
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
    ((${#warnings[@]} == 0)) && printf 'none' || printf '%s' "${warnings[*]}"
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
