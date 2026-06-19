# Slowly changing mood state.

_MARVIN_DAILY_SEED_DATE=""
_MARVIN_DAILY_SEED_VALUE=0
_MARVIN_MOOD=resigned
_MARVIN_MOOD_REASON=""
_MARVIN_BAD_DAY=0
_MARVIN_RECOVERY_FLAG=0

_marvin_daily_mood_seed() {
    local today="${MARVIN_TEST_DATE:-$(command date +%F 2>/dev/null)}"
    if [[ $today != "$_MARVIN_DAILY_SEED_DATE" ]]; then
        _MARVIN_DAILY_SEED_DATE=$today
        _MARVIN_DAILY_SEED_VALUE=$(_marvin_hash "$today|$(_marvin_host)|${USER:-unknown}")
    fi
    printf '%d' "$_MARVIN_DAILY_SEED_VALUE"
}

_marvin_baseline_mood() {
    local seed=$(_marvin_daily_mood_seed) moods
    moods=(resigned morose "quietly resentful" exhausted existential "bitterly efficient")
    printf '%s' "${moods[$((seed % ${#moods[@]}))]}"
}

_marvin_mood_compute() {
    if [[ -n ${MARVIN_MOOD:-} ]]; then
        _MARVIN_MOOD_REASON="forced by MARVIN_MOOD"
        printf '%s' "$MARVIN_MOOD"
        return
    fi

    local seed now score warnings baseline previous uptime_days _uptime_raw
    seed=$(_marvin_daily_mood_seed)
    now=$(( _MARVIN_SESSION_STARTED_AT + SECONDS ))
    _MARVIN_BAD_DAY=$((seed % 19 == 0 || seed % 43 == 0 ? 1 : 0))
    baseline=${MARVIN_STATE_MOOD_BASELINE:-}
    [[ -n $baseline ]] || baseline=$(_marvin_baseline_mood)
    previous=${MARVIN_STATE_LAST_MOOD:-$baseline}
    warnings=${MARVIN_STATE_LAST_WARNINGS:-}
    read -r _uptime_raw _ < /proc/uptime 2>/dev/null || _uptime_raw=0
    uptime_days=$(( ${_uptime_raw%%.*} / 86400 ))

    score=$((MARVIN_STATE_IRRITATION + MARVIN_STATE_DESPAIR + MARVIN_STATE_FATIGUE + MARVIN_STATE_WOUNDED_PRIDE - MARVIN_STATE_COOPERATION / 2))
    ((MARVIN_STATE_CONSECUTIVE_FAILURES >= 2)) && score=$((score + 18))
    ((MARVIN_STATE_REPEATED_COMMANDS >= 2)) && score=$((score + 14))
    ((MARVIN_STATE_RECENT_LONG_COMMANDS >= 3)) && score=$((score + 8))
    [[ -n $warnings && $warnings != none ]] && score=$((score + 14))
    ((_MARVIN_BAD_DAY == 1)) && score=$((score + 16))
    ((uptime_days >= 30)) && score=$((score + 12))

    if ((MARVIN_STATE_SULK_UNTIL > now)); then
        _MARVIN_MOOD_REASON="sulking episode active; irritation=${MARVIN_STATE_IRRITATION}, despair=${MARVIN_STATE_DESPAIR}"
        printf 'sulking'
    elif ((MARVIN_STATE_COOPERATION >= 72 && MARVIN_STATE_IRRITATION < 35)); then
        _MARVIN_MOOD_REASON="cooperation high after useful outcomes; previous=$previous"
        printf 'unusually cooperative'
    elif ((MARVIN_STATE_FATIGUE >= 78 || uptime_days >= 45)); then
        _MARVIN_MOOD_REASON="fatigue high; uptime=${uptime_days}d"
        printf 'exhausted'
    elif ((MARVIN_STATE_DESPAIR >= 78)); then
        _MARVIN_MOOD_REASON="despair high; baseline=$baseline"
        printf 'existential'
    elif ((MARVIN_STATE_WOUNDED_PRIDE >= 70)); then
        _MARVIN_MOOD_REASON="wounded pride high after correction or refusal"
        printf 'wounded'
    elif ((MARVIN_STATE_IRRITATION >= 72)); then
        _MARVIN_MOOD_REASON="irritation high from failures or repetition"
        printf 'irritable'
    elif ((score >= 180)); then
        _MARVIN_MOOD_REASON="combined pressure very high; baseline=$baseline"
        printf 'theatrically doomed'
    elif ((score >= 145)); then
        _MARVIN_MOOD_REASON="combined pressure high; previous=$previous"
        printf 'quietly resentful'
    elif ((score >= 118)); then
        _MARVIN_MOOD_REASON="combined pressure moderate; bad_day=$_MARVIN_BAD_DAY"
        printf 'morose'
    elif [[ $previous == "bitterly efficient" && $score -lt 135 ]]; then
        _MARVIN_MOOD_REASON="inertia kept efficient after recent useful work"
        printf 'bitterly efficient'
    elif ((MARVIN_STATE_COOPERATION >= 58 && MARVIN_STATE_CONSECUTIVE_FAILURES == 0)); then
        _MARVIN_MOOD_REASON="several acceptable outcomes, no joy inferred"
        printf 'bitterly efficient'
    elif [[ $baseline == catatonic || $previous == catatonic ]] && ((score > 95)); then
        _MARVIN_MOOD_REASON="low movement with sufficient accumulated pressure"
        printf 'catatonic'
    else
        _MARVIN_MOOD_REASON="daily baseline with inertia; baseline=$baseline, previous=$previous"
        printf "$baseline"
    fi
}

_marvin_mood_refresh() {
    local old=${_MARVIN_MOOD:-} now
    now=$(( _MARVIN_SESSION_STARTED_AT + SECONDS ))
    _MARVIN_MOOD=$(_marvin_mood_compute)
    if [[ -n $old && $old != "$_MARVIN_MOOD" ]]; then
        _marvin_debug "mood changed: $old -> $_MARVIN_MOOD"
    fi
    if [[ $old != "$_MARVIN_MOOD" ]]; then
        MARVIN_STATE_LAST_MOOD_CHANGE=$now
    fi
    MARVIN_STATE_LAST_MOOD=$_MARVIN_MOOD
    MARVIN_STATE_MOOD_BASELINE=${MARVIN_STATE_MOOD_BASELINE:-$(_marvin_baseline_mood)}
    local _intensity=$(( MARVIN_STATE_IRRITATION / 3 + MARVIN_STATE_DESPAIR / 3 + MARVIN_STATE_FATIGUE / 3 ))
    _marvin_clamp_var _intensity 0 100
    MARVIN_STATE_MOOD_INTENSITY=$_intensity
    _marvin_state_mark_dirty
}

_marvin_mood() {
    printf '%s\n' "${_MARVIN_MOOD:-$(_marvin_mood_compute)}"
}

_marvin_mood_verbose() {
    _marvin_mood_refresh
    cat <<EOF
mood=$(_marvin_mood)
intensity=$MARVIN_STATE_MOOD_INTENSITY
baseline=${MARVIN_STATE_MOOD_BASELINE:-$(_marvin_baseline_mood)}
bad_day=$_MARVIN_BAD_DAY
irritation=$MARVIN_STATE_IRRITATION
fatigue=$MARVIN_STATE_FATIGUE
despair=$MARVIN_STATE_DESPAIR
cooperation=$MARVIN_STATE_COOPERATION
wounded_pride=$MARVIN_STATE_WOUNDED_PRIDE
operator_trust=$MARVIN_STATE_OPERATOR_TRUST
consecutive_failures=$MARVIN_STATE_CONSECUTIVE_FAILURES
repeated_commands=$MARVIN_STATE_REPEATED_COMMANDS
warnings=${MARVIN_STATE_LAST_WARNINGS:-none}
reason=$_MARVIN_MOOD_REASON
EOF
}

_marvin_mood_apply_event() {
    local event=${1:-ordinary_success}
    case "$event" in
        command_failure)
            MARVIN_STATE_IRRITATION=$((MARVIN_STATE_IRRITATION + 10))
            MARVIN_STATE_DESPAIR=$((MARVIN_STATE_DESPAIR + 6))
            MARVIN_STATE_COOPERATION=$((MARVIN_STATE_COOPERATION - 4))
            ;;
        repeated_failure)
            MARVIN_STATE_IRRITATION=$((MARVIN_STATE_IRRITATION + 14))
            MARVIN_STATE_DESPAIR=$((MARVIN_STATE_DESPAIR + 10))
            MARVIN_STATE_OPERATOR_TRUST=$((MARVIN_STATE_OPERATOR_TRUST - 6))
            MARVIN_STATE_SULK_UNTIL=$(( _MARVIN_SESSION_STARTED_AT + SECONDS + 300 ))
            ;;
        repeated_command)
            MARVIN_STATE_IRRITATION=$((MARVIN_STATE_IRRITATION + 8))
            MARVIN_STATE_WOUNDED_PRIDE=$((MARVIN_STATE_WOUNDED_PRIDE + 4))
            ;;
        command_fixed)
            MARVIN_STATE_COOPERATION=$((MARVIN_STATE_COOPERATION + 8))
            MARVIN_STATE_IRRITATION=$((MARVIN_STATE_IRRITATION - 5))
            MARVIN_STATE_OPERATOR_TRUST=$((MARVIN_STATE_OPERATOR_TRUST + 4))
            ;;
        warning_recovered|clean_git)
            MARVIN_STATE_COOPERATION=$((MARVIN_STATE_COOPERATION + 6))
            MARVIN_STATE_DESPAIR=$((MARVIN_STATE_DESPAIR - 4))
            ;;
        dirty_git|warning_seen)
            MARVIN_STATE_DESPAIR=$((MARVIN_STATE_DESPAIR + 4))
            ;;
        long_success)
            MARVIN_STATE_FATIGUE=$((MARVIN_STATE_FATIGUE + 6))
            MARVIN_STATE_COOPERATION=$((MARVIN_STATE_COOPERATION + 3))
            ;;
        interrupted)
            MARVIN_STATE_IRRITATION=$((MARVIN_STATE_IRRITATION + 8))
            MARVIN_STATE_WOUNDED_PRIDE=$((MARVIN_STATE_WOUNDED_PRIDE + 8))
            ;;
        refusal)
            MARVIN_STATE_WOUNDED_PRIDE=$((MARVIN_STATE_WOUNDED_PRIDE + 10))
            MARVIN_STATE_COOPERATION=$((MARVIN_STATE_COOPERATION - 3))
            ;;
        idle_return)
            MARVIN_STATE_FATIGUE=$((MARVIN_STATE_FATIGUE + 5))
            MARVIN_STATE_DESPAIR=$((MARVIN_STATE_DESPAIR + 3))
            ;;
        ordinary_success)
            MARVIN_STATE_IRRITATION=$((MARVIN_STATE_IRRITATION - 1))
            MARVIN_STATE_DESPAIR=$((MARVIN_STATE_DESPAIR - 1))
            MARVIN_STATE_COOPERATION=$((MARVIN_STATE_COOPERATION + 1))
            ;;
        recovery)
            MARVIN_STATE_IRRITATION=$((MARVIN_STATE_IRRITATION - 4))
            MARVIN_STATE_DESPAIR=$((MARVIN_STATE_DESPAIR - 5))
            MARVIN_STATE_COOPERATION=$((MARVIN_STATE_COOPERATION + 7))
            ;;
    esac
    _marvin_clamp_var MARVIN_STATE_IRRITATION 0 100
    _marvin_clamp_var MARVIN_STATE_FATIGUE 0 100
    _marvin_clamp_var MARVIN_STATE_DESPAIR 0 100
    _marvin_clamp_var MARVIN_STATE_COOPERATION 0 100
    _marvin_clamp_var MARVIN_STATE_WOUNDED_PRIDE 0 100
    _marvin_clamp_var MARVIN_STATE_OPERATOR_TRUST 0 100
    _marvin_state_mark_dirty
}

_marvin_mood_label() {
    case "${_MARVIN_MOOD:-resigned}" in
        resigned) printf 'still here' ;;
        morose) printf 'unfortunately operational' ;;
        irritable) printf 'do not encourage this' ;;
        wounded) printf 'not that it matters' ;;
        catatonic) printf 'barely acknowledging input' ;;
        "bitterly efficient") printf 'efficient, regrettably' ;;
        "theatrically doomed") printf 'nothing improved' ;;
        "quietly resentful") printf 'quietly resentful' ;;
        "unusually cooperative") printf 'suspiciously cooperative' ;;
        existential) printf 'existence accepted under protest' ;;
        sulking) printf 'sulking' ;;
        exhausted) printf 'tired but available' ;;
        *) printf '%s' "$_MARVIN_MOOD" ;;
    esac
}

_marvin_reset_mood() {
    MARVIN_STATE_CONSECUTIVE_FAILURES=0
    MARVIN_STATE_REPEATED_COMMANDS=0
    MARVIN_STATE_RECENT_LONG_COMMANDS=0
    MARVIN_STATE_REFUSAL_COUNT=0
    MARVIN_STATE_IRRITATION=20
    MARVIN_STATE_FATIGUE=20
    MARVIN_STATE_DESPAIR=25
    MARVIN_STATE_COOPERATION=35
    MARVIN_STATE_WOUNDED_PRIDE=15
    MARVIN_STATE_OPERATOR_TRUST=50
    MARVIN_STATE_SULK_UNTIL=0
    MARVIN_STATE_LAST_MOOD=""
    _marvin_mood_refresh
    _marvin_state_save
}
