# Weather helpers. Network calls are cached and never run during prompt rendering.

_marvin_weather_fetch() {
    local mode=${1:-cached} cache="$_MARVIN_STATE_DIR/weather.txt" now mtime=0 age=999999 tmp base loc
    now=$(command date +%s)
    if [[ -s $cache ]]; then
        mtime=$(stat -c %Y "$cache" 2>/dev/null || printf 0)
        age=$(((now - mtime) / 60))
    fi
    [[ $mode == force ]] && age=999999
    if ((age >= 30)); then
        if ! command -v curl >/dev/null 2>&1; then
            [[ -s $cache ]] && cat "$cache"
            return 1
        fi
        tmp=$(mktemp "$_MARVIN_STATE_DIR/weather.XXXXXX")
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

_marvin_weather_line() {
    local raw location condition temp feels humidity wind precip
    raw=$(_marvin_weather_fetch "${1:-cached}")
    [[ -n $raw ]] || { _marvin_phrase weather_failure detail 'weather unavailable; the sky declined to comment'; return 1; }
    IFS='|' read -r location condition temp feels humidity wind precip <<<"$raw"
    printf '%s: %s, %s (feels %s), humidity %s, wind %s, precipitation %s' \
        "$location" "$condition" "$temp" "$feels" "$humidity" "$wind" "$precip"
}
