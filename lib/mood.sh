# Slowly changing mood state.

_MARVIN_MOOD=resigned
_MARVIN_BAD_DAY=0
_MARVIN_RECOVERY_FLAG=0

_marvin_daily_mood_seed() {
    _marvin_hash "$(command date +%F)|$(_marvin_host)|${USER:-unknown}"
}

_marvin_mood_compute() {
    if [[ -n ${MARVIN_MOOD:-} ]]; then
        printf '%s' "$MARVIN_MOOD"
        return
    fi

    local seed score idx moods warnings
    seed=$(_marvin_daily_mood_seed)
    _MARVIN_BAD_DAY=$((seed % 17 == 0 ? 1 : 0))
    score=$((seed % 100))
    warnings=${MARVIN_STATE_LAST_WARNINGS:-}

    ((MARVIN_STATE_CONSECUTIVE_FAILURES >= 2)) && score=$((score + 22))
    ((MARVIN_STATE_REPEATED_COMMANDS >= 2)) && score=$((score + 16))
    ((MARVIN_STATE_RECENT_LONG_COMMANDS >= 3)) && score=$((score + 10))
    ((MARVIN_STATE_REFUSAL_COUNT >= 2)) && score=$((score + 14))
    [[ -n $warnings && $warnings != none ]] && score=$((score + 12))
    ((_MARVIN_BAD_DAY == 1)) && score=$((score + 18))

    moods=(resigned morose irritable wounded catatonic "bitterly efficient" "theatrically doomed" "quietly resentful" "unusually cooperative" existential sulking exhausted)
    idx=$(((score / 11) % ${#moods[@]}))
    printf '%s' "${moods[$idx]}"
}

_marvin_mood_refresh() {
    local old=${_MARVIN_MOOD:-}
    _MARVIN_MOOD=$(_marvin_mood_compute)
    if [[ -n $old && $old != "$_MARVIN_MOOD" ]]; then
        _marvin_debug "mood changed: $old -> $_MARVIN_MOOD"
    fi
    MARVIN_STATE_LAST_MOOD=$_MARVIN_MOOD
    _marvin_state_save
}

_marvin_mood() {
    printf '%s\n' "${_MARVIN_MOOD:-$(_marvin_mood_compute)}"
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
    MARVIN_STATE_LAST_MOOD=""
    _marvin_mood_refresh
}
