# Rare theatrical refusal. This intentionally wraps only known harmless commands.

_MARVIN_COOPERATE=0

_marvin_refusal_enabled() {
    _marvin_is_interactive_tty || return 1
    [[ ${MARVIN_REFUSAL:-1} != 0 ]] || return 1
    [[ ${MARVIN_BYPASS:-0} != 1 ]] || return 1
    ((_MARVIN_COOPERATE == 0)) || return 1
    _marvin_personality_enabled || return 1
}

_marvin_refusal_eligible() {
    local cmd=$1
    case "$cmd" in
        ls|date|whoami|uptime|fortune|cowsay|clear|fastfetch) return 0 ;;
        *) return 1 ;;
    esac
}

_marvin_should_refuse() {
    local cmd=$1 seed rate mood_bonus abuse_bonus roll
    _marvin_refusal_enabled || return 1
    _marvin_refusal_eligible "$cmd" || return 1
    case " ${_MARVIN_MOOD:-resigned} " in
        *" irritable "*|*" wounded "*|*" catatonic "*|*" sulking "*) mood_bonus=1 ;;
        *) mood_bonus=0 ;;
    esac
    abuse_bonus=0
    ((MARVIN_STATE_CONSECUTIVE_FAILURES >= 3)) && abuse_bonus=$((abuse_bonus + 1))
    ((MARVIN_STATE_REPEATED_COMMANDS >= 3)) && abuse_bonus=$((abuse_bonus + 1))
    rate=${MARVIN_REFUSAL_RATE:-1}
    [[ $rate =~ ^[0-9]+$ ]] || rate=1
    rate=$((rate + mood_bonus + abuse_bonus))
    ((rate > 8)) && rate=8
    ((rate <= 0)) && return 1
    seed=$(_marvin_hash "refuse|$cmd|$SECONDS|$RANDOM|$_MARVIN_SESSION_ID|$_MARVIN_MOOD")
    roll=$((seed % 100))
    ((roll < rate))
}

_marvin_refuse_command() {
    local cmd=$1 printable
    shift || true
    printable=$(_marvin_sanitize_text "$cmd${*:+ $*}")
    MARVIN_STATE_REFUSAL_COUNT=$((MARVIN_STATE_REFUSAL_COUNT + 1))
    _marvin_state_save
    _marvin_history_add refusal "$printable"
    printf '%s' "$_MV_GREY" >&2
    _marvin_wrap "$(_marvin_phrase refusal command "$printable")" >&2
    printf 'Command was not executed. Bypass exactly once with: MARVIN_BYPASS=1 %s\n' "$printable" >&2
    printf 'Other bypasses: marvin please %s | marvin cooperate | marvin refuse off\n' "$printable" >&2
    printf '%s' "$_MV_RESET" >&2
    return "$MARVIN_REFUSAL_STATUS"
}

_marvin_wrap_harmless() {
    local cmd=$1
    shift || true
    if _marvin_should_refuse "$cmd"; then
        _marvin_refuse_command "$cmd" "$@"
        return "$?"
    fi
    MARVIN_BYPASS=1 command "$cmd" "$@"
}

ls() { _marvin_wrap_harmless ls "$@"; }
date() { _marvin_wrap_harmless date "$@"; }
whoami() { _marvin_wrap_harmless whoami "$@"; }
uptime() { _marvin_wrap_harmless uptime "$@"; }
fortune() { _marvin_wrap_harmless fortune "$@"; }
cowsay() { _marvin_wrap_harmless cowsay "$@"; }
clear() { _marvin_wrap_harmless clear "$@"; }
fastfetch() { _marvin_wrap_harmless fastfetch "$@"; }

