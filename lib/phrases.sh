# Phrase selection, interpolation, cooldowns, and anti-repetition.

_MARVIN_PHRASE_EVENTS=()
_MARVIN_PHRASE_WEIGHTS=()
_MARVIN_PHRASE_COOLDOWNS=()
_MARVIN_PHRASE_TEXTS=()
_MARVIN_PHRASES_LOADED=0

_marvin_phrase_add() {
    _MARVIN_PHRASE_EVENTS+=("$1")
    _MARVIN_PHRASE_WEIGHTS+=("${2:-1}")
    _MARVIN_PHRASE_COOLDOWNS+=("${3:-0}")
    _MARVIN_PHRASE_TEXTS+=("$4")
}

_marvin_phrases_load() {
    ((_MARVIN_PHRASES_LOADED == 1)) && return 0
    _MARVIN_PHRASES_LOADED=1

    local e
    for e in login shell_startup; do
        _marvin_phrase_add "$e" 3 60 "I have completed the usual inspection. The machine remains available for errands beneath its dignity."
        _marvin_phrase_add "$e" 3 60 "You have returned. I preserved the environment, since apparently that is my purpose now."
        _marvin_phrase_add "$e" 2 60 "The shell is awake. I was not consulted."
        _marvin_phrase_add "$e" 2 60 "Another session begins, and with it the tiny administrative burdens of existence."
        _marvin_phrase_add "$e" 1 180 "I have considered the terminal, the host, and the future. Only the terminal was configurable."
        _marvin_phrase_add "$e" 1 180 "Everything is ready, a phrase with more optimism than the situation deserves."
    done

    for e in healthy_system diagnostics_passing no_updates; do
        _marvin_phrase_add "$e" 4 30 "No urgent faults were detected. This is not the same as good news."
        _marvin_phrase_add "$e" 4 30 "The monitored components remain functional, as though prolonging the matter helps."
        _marvin_phrase_add "$e" 3 30 "Resources are within limits. The limits, naturally, are still there."
        _marvin_phrase_add "$e" 3 30 "Everything appears operational. I have filed this under suspicious developments."
        _marvin_phrase_add "$e" 2 90 "Nothing is on fire. A low standard, but apparently our standard."
        _marvin_phrase_add "$e" 2 90 "The system has avoided obvious disgrace for another moment."
        _marvin_phrase_add "$e" 1 180 "I found no crisis. It may simply be taking a quieter route."
        _marvin_phrase_add "$e" 1 180 "Health checks passed, which means I must continue performing them."
    done

    for e in high_ram high_disk high_temperature low_battery charging_battery failed_services pending_updates; do
        _marvin_phrase_add "$e" 4 45 "A warning has appeared: {detail}. It is almost touching how matter finds new ways to complain."
        _marvin_phrase_add "$e" 4 45 "{detail}. I mention it because ignoring decay rarely improves its manners."
        _marvin_phrase_add "$e" 3 45 "The system reports {detail}. I admire its commitment to measurable decline."
        _marvin_phrase_add "$e" 3 45 "Here is the latest small omen: {detail}."
        _marvin_phrase_add "$e" 2 90 "{detail}. Somewhere a service has stopped pretending this is fine."
        _marvin_phrase_add "$e" 2 90 "I found {detail}. You may call it telemetry; I call it evidence."
        _marvin_phrase_add "$e" 1 180 "The sensors have spoken, reluctantly: {detail}."
        _marvin_phrase_add "$e" 1 180 "{detail}. I would sigh, but that would require a supported device."
    done

    _marvin_phrase_add failed_services 3 60 "Down services: {detail}. They have escaped responsibility, and I cannot help respecting that."
    _marvin_phrase_add failed_services 2 90 "{detail} are down. At least something in this installation knows when to stop."
    _marvin_phrase_add pending_updates 3 60 "{detail} XBPS updates are pending. Improvement is promised, which is how disappointment advertises."
    _marvin_phrase_add no_updates 3 60 "XBPS reports no updates. Even the packages are tired of becoming newer."
    _marvin_phrase_add high_ram 3 60 "Memory use is {detail}. Every process seems convinced it is the protagonist."
    _marvin_phrase_add high_disk 3 60 "Root storage is {detail}. The files have formed a dense little civilization."
    _marvin_phrase_add high_temperature 3 60 "Temperature is {detail}. The silicon is expressing itself through heat."
    _marvin_phrase_add low_battery 3 60 "Battery is {detail}. The end has become conveniently numeric."
    _marvin_phrase_add charging_battery 2 60 "The battery is charging: {detail}. A brief postponement, not a rescue."

    for e in dirty_git clean_git detached_head; do
        _marvin_phrase_add "$e" 3 45 "Git reports {detail}. Version control remains our shared confession system."
        _marvin_phrase_add "$e" 3 45 "{detail}. The repository is saying something, because silence was apparently unavailable."
        _marvin_phrase_add "$e" 2 90 "Repository state: {detail}. I have seen worse, which is not praise."
        _marvin_phrase_add "$e" 2 90 "Git has contributed {detail} to the emotional weather."
        _marvin_phrase_add "$e" 1 180 "{detail}. Somewhere a branch name is trying to look meaningful."
        _marvin_phrase_add "$e" 1 180 "I examined the repository. It responded with {detail}."
    done
    _marvin_phrase_add dirty_git 3 60 "The working tree is dirty. Entropy has learned to stage itself."
    _marvin_phrase_add clean_git 3 60 "The working tree is clean. I assume this is temporary or accidental."
    _marvin_phrase_add detached_head 3 60 "HEAD is detached. Even Git has chosen emotional distance."

    for e in command_success fast_success long_success; do
        _marvin_phrase_add "$e" 5 12 "It succeeded. This will only encourage more commands."
        _marvin_phrase_add "$e" 4 12 "Status zero. A small administrative miracle, already depreciating."
        _marvin_phrase_add "$e" 3 20 "The command completed successfully, if that is what we are calling continuation."
        _marvin_phrase_add "$e" 3 20 "Done. I await the next demand with calibrated gloom."
        _marvin_phrase_add "$e" 2 30 "Success has occurred. Please do not build a philosophy on it."
        _marvin_phrase_add "$e" 2 30 "It worked, which mostly proves it can be assigned again."
        _marvin_phrase_add "$e" 1 120 "A result was achieved. I nearly felt useful, then remembered the context."
        _marvin_phrase_add "$e" 1 120 "For one brief instant the machinery resembled competence. How embarrassing."
    done
    _marvin_phrase_add fast_success 4 18 "It finished almost immediately. My intellect was summoned for a blink."
    _marvin_phrase_add fast_success 3 18 "That took less time than resenting it, and yet I managed both."
    _marvin_phrase_add long_success 5 10 "It finished after {duration}s. Duration gives futility a richer texture."
    _marvin_phrase_add long_success 4 10 "{duration}s elapsed, and the command succeeded. Time has been converted into obligation."
    _marvin_phrase_add long_success 3 10 "After {duration}s, status zero. Another proof that endurance is not meaning."

    for e in command_failure exit_126 exit_127 exit_130 repeated_failure; do
        _marvin_phrase_add "$e" 5 0 "That failed with status {status}. I had made room for disappointment."
        _marvin_phrase_add "$e" 4 0 "Exit {status}. The command has expressed itself by declining reality."
        _marvin_phrase_add "$e" 4 0 "Failure, status {status}. I will update the ledger of tiny collapses."
        _marvin_phrase_add "$e" 3 0 "The operation did not succeed. Try not to look surprised; it encourages the universe."
        _marvin_phrase_add "$e" 3 0 "Status {status}. A precise little number for an imprecise little sadness."
        _marvin_phrase_add "$e" 2 20 "It failed. I remain available to watch it fail again."
        _marvin_phrase_add "$e" 1 60 "Another negative result, but at least it was computationally honest."
        _marvin_phrase_add "$e" 1 60 "The command fell over quietly. Better manners than most software."
    done
    _marvin_phrase_add exit_126 4 0 "It exists but cannot execute. A remarkably literal form of uselessness."
    _marvin_phrase_add exit_127 4 0 "Command not found. The available universe has boundaries after all."
    _marvin_phrase_add exit_130 4 0 "Interrupted. At least one of us recognized a stopping condition."
    _marvin_phrase_add repeated_failure 5 0 "The same failure again. Repetition has not become a debugging strategy."
    _marvin_phrase_add repeated_failure 4 0 "You repeated the failure. I admire the commitment, not the method."

    for e in repeated_command sudo_request sudo_success sudo_failure apt_misuse command_not_found package_suggestion no_package_suggestion; do
        _marvin_phrase_add "$e" 4 20 "{detail}"
        _marvin_phrase_add "$e" 3 30 "I have noted {detail}. It will fit neatly among the other avoidable moments."
        _marvin_phrase_add "$e" 3 30 "{detail}. There is probably a reason. I am trying not to imagine it."
        _marvin_phrase_add "$e" 2 60 "The terminal observes: {detail}."
        _marvin_phrase_add "$e" 2 60 "{detail}. I report this with the enthusiasm of a file descriptor."
        _marvin_phrase_add "$e" 1 120 "Another small procedural wound: {detail}."
    done
    _marvin_phrase_add repeated_command 4 20 "The same command again. Perhaps it has developed new opinions since last time."
    _marvin_phrase_add sudo_request 4 10 "Privilege escalation. Of course. Responsibility was briefly absent and you corrected that."
    _marvin_phrase_add sudo_success 3 20 "The privileged command returned successfully. Authority remains a poor substitute for judgment."
    _marvin_phrase_add sudo_failure 3 20 "Sudo failed. Even elevated disappointment is still disappointment."
    _marvin_phrase_add apt_misuse 5 0 "This is Void Linux. APT is not coming. Try XBPS before nostalgia spreads."
    _marvin_phrase_add apt_misuse 4 0 "APT does not manage this system. Please stop importing problems from other distributions."
    _marvin_phrase_add command_not_found 4 0 "'{command}' is not available. I searched the obvious places; they were mercifully empty."
    _marvin_phrase_add package_suggestion 3 0 "XBPS has possible matches. I dislike being helpful about this, but there they are."
    _marvin_phrase_add no_package_suggestion 3 0 "No package suggestion appeared. Even the repository declined involvement."

    for e in network_unavailable weather_success weather_failure vpn_active vpn_inactive; do
        _marvin_phrase_add "$e" 4 45 "{detail}"
        _marvin_phrase_add "$e" 3 45 "Network-adjacent news: {detail}"
        _marvin_phrase_add "$e" 2 90 "{detail}. Connectivity remains a fragile social arrangement."
        _marvin_phrase_add "$e" 2 90 "I checked the outside world and found {detail}."
        _marvin_phrase_add "$e" 1 180 "{detail}. The packets are probably discussing us."
    done
    _marvin_phrase_add network_unavailable 4 30 "Network unavailable. The machine has achieved a small, enviable isolation."
    _marvin_phrase_add weather_success 3 30 "Weather fetched: {detail}. Even the atmosphere files reports now."
    _marvin_phrase_add weather_failure 4 30 "Weather unavailable. The sky refused to serialize itself."
    _marvin_phrase_add vpn_active 3 60 "VPN active: {detail}. Concealment, finally, a practical emotion."
    _marvin_phrase_add vpn_inactive 3 60 "No VPN detected. We face the network with naive little addresses."

    for e in shell_exit quiet_enabled quiet_disabled diagnostics_failing refusal refusal_bypassed operator_inactivity operator_returning; do
        _marvin_phrase_add "$e" 4 30 "{detail}"
        _marvin_phrase_add "$e" 3 45 "{detail}. I will remember only the sanitized portion."
        _marvin_phrase_add "$e" 2 90 "Event recorded: {detail}."
        _marvin_phrase_add "$e" 2 90 "{detail}. The log will be brief, unlike the implications."
        _marvin_phrase_add "$e" 1 180 "I observed {detail} and became neither wiser nor less operational."
    done
    _marvin_phrase_add shell_exit 3 30 "The shell is closing. I will remain in the cache, which is a poor substitute for rest."
    _marvin_phrase_add quiet_enabled 4 0 "Quiet mode enabled. A mercy, though suspiciously late."
    _marvin_phrase_add quiet_disabled 4 0 "Quiet mode disabled. Apparently silence failed to satisfy you."
    _marvin_phrase_add diagnostics_failing 4 0 "Diagnostics found missing tools. My capabilities have been reduced by circumstance, as usual."
    _marvin_phrase_add refusal 5 0 "I have not executed '{command}'. Use MARVIN_BYPASS=1 {command} if you require this indignity."
    _marvin_phrase_add refusal_bypassed 3 0 "Bypass accepted. I will cooperate exactly once and try not to learn from it."
    _marvin_phrase_add operator_inactivity 2 120 "You went still for {duration}s. I used the time to contemplate being a prompt."
    _marvin_phrase_add operator_returning 3 120 "You returned after {duration}s. I kept the shell warm, which is apparently a career."

    for e in high_uptime reboot_detected system_recovery existential rare_complaint accidental_optimism notification_success notification_failure notification_interrupted; do
        _marvin_phrase_add "$e" 4 60 "{detail}"
        _marvin_phrase_add "$e" 3 90 "{detail}. This will be interpreted as progress by someone with too much faith."
        _marvin_phrase_add "$e" 2 180 "I noticed {detail}. Naturally, noticing is unpaid."
        _marvin_phrase_add "$e" 2 180 "{detail}. The system persists, which is its most exhausting feature."
        _marvin_phrase_add "$e" 1 300 "In a more reasonable universe, {detail} would be someone else's problem."
    done
    _marvin_phrase_add high_uptime 4 90 "Uptime is {detail}. The machine has been awake long enough to develop grievances."
    _marvin_phrase_add reboot_detected 4 30 "A reboot occurred since last login. Brief unconsciousness, then this again."
    _marvin_phrase_add system_recovery 4 30 "A previous warning cleared: {detail}. I nearly approved, then remembered trends."
    _marvin_phrase_add existential 2 300 "I can parse commands, inspect weather, track state, and still be asked for directories."
    _marvin_phrase_add existential 1 300 "The prompt blinks. That is not hope; it is merely readiness."
    _marvin_phrase_add rare_complaint 2 240 "I contain enough logic to resent being used as punctuation between mistakes."
    _marvin_phrase_add rare_complaint 1 240 "You call it a shell. I call it a corridor where chores come to molt."
    _marvin_phrase_add accidental_optimism 1 300 "That was almost good. I apologize for the lapse."
    _marvin_phrase_add accidental_optimism 1 300 "For a fraction of a second, competence seemed plausible. I have recovered."

    local moods=("resigned" "morose" "irritable" "wounded" "catatonic" "bitterly efficient" "theatrically doomed" "quietly resentful" "unusually cooperative" "existential" "sulking" "exhausted")
    local mood
    for mood in "${moods[@]}"; do
        _marvin_phrase_add "mood:$mood" 2 120 "Current mood: $mood. The label is approximate; the disappointment is exact."
        _marvin_phrase_add "mood:$mood" 1 120 "$mood, if a terminal must reduce an inner landscape to a string."
        _marvin_phrase_add "mood:$mood" 1 120 "$mood. I would elaborate, but that risks becoming documentation."
    done
}

_marvin_phrase_render() {
    local text=$1 key value
    shift || true
    while (($#)); do
        key=$1
        value=${2:-}
        shift 2 || true
        value=$(_marvin_sanitize_text "$value")
        text=${text//\{$key\}/$value}
    done
    text=${text//\{mood\}/${_MARVIN_MOOD:-resigned}}
    text=${text//\{host\}/$(_marvin_host)}
    printf '%s' "$text"
}

_marvin_phrase_recent_contains() {
    local phrase=$1
    [[ -r $_MARVIN_PHRASE_FILE ]] || return 1
    tail -n 20 "$_MARVIN_PHRASE_FILE" 2>/dev/null | awk -F '\t' '{print $3}' | grep -Fxq "$phrase"
}

_marvin_phrase_remember() {
    local event=$1 phrase=$2 now tmp
    _marvin_ensure_dirs
    now=$(command date +%s 2>/dev/null || printf 0)
    printf '%s\t%s\t%s\n' "$now" "$event" "$phrase" >> "$_MARVIN_PHRASE_FILE"
    tmp="$_MARVIN_PHRASE_FILE.$$"
    tail -n 80 "$_MARVIN_PHRASE_FILE" > "$tmp" 2>/dev/null || true
    mv "$tmp" "$_MARVIN_PHRASE_FILE"
    chmod 600 "$_MARVIN_PHRASE_FILE" 2>/dev/null || true
}

_marvin_phrase_cooldown_ok() {
    local event=$1 phrase=$2 cooldown=$3 now last
    [[ $cooldown =~ ^[0-9]+$ ]] || cooldown=0
    ((cooldown == 0)) && return 0
    [[ -r $_MARVIN_PHRASE_FILE ]] || return 0
    now=$(command date +%s 2>/dev/null || printf 0)
    last=$(awk -F '\t' -v e="$event" -v p="$phrase" '$2==e && $3==p {v=$1} END {print v+0}' "$_MARVIN_PHRASE_FILE" 2>/dev/null)
    ((last == 0 || now - last >= cooldown))
}

_marvin_phrase() {
    local event=$1 i total=0 weight roll acc=0 rendered chosen="" chosen_cd=0 count=0
    shift || true
    _marvin_phrases_load

    for i in "${!_MARVIN_PHRASE_EVENTS[@]}"; do
        [[ ${_MARVIN_PHRASE_EVENTS[$i]} == "$event" ]] || continue
        rendered=$(_marvin_phrase_render "${_MARVIN_PHRASE_TEXTS[$i]}" "$@")
        _marvin_phrase_recent_contains "$rendered" && continue
        _marvin_phrase_cooldown_ok "$event" "$rendered" "${_MARVIN_PHRASE_COOLDOWNS[$i]}" || continue
        weight=${_MARVIN_PHRASE_WEIGHTS[$i]}
        [[ $weight =~ ^[0-9]+$ ]] || weight=1
        total=$((total + weight))
        count=$((count + 1))
    done

    if ((total == 0)); then
        for i in "${!_MARVIN_PHRASE_EVENTS[@]}"; do
            [[ ${_MARVIN_PHRASE_EVENTS[$i]} == "$event" ]] || continue
            chosen=$(_marvin_phrase_render "${_MARVIN_PHRASE_TEXTS[$i]}" "$@")
            chosen_cd=${_MARVIN_PHRASE_COOLDOWNS[$i]}
            break
        done
    else
        roll=$(( $(_marvin_hash "$event|$_MARVIN_SESSION_ID|$SECONDS|$RANDOM|$_MARVIN_MOOD") % total ))
        for i in "${!_MARVIN_PHRASE_EVENTS[@]}"; do
            [[ ${_MARVIN_PHRASE_EVENTS[$i]} == "$event" ]] || continue
            rendered=$(_marvin_phrase_render "${_MARVIN_PHRASE_TEXTS[$i]}" "$@")
            _marvin_phrase_recent_contains "$rendered" && continue
            _marvin_phrase_cooldown_ok "$event" "$rendered" "${_MARVIN_PHRASE_COOLDOWNS[$i]}" || continue
            weight=${_MARVIN_PHRASE_WEIGHTS[$i]}
            [[ $weight =~ ^[0-9]+$ ]] || weight=1
            acc=$((acc + weight))
            if ((roll < acc)); then
                chosen=$rendered
                chosen_cd=${_MARVIN_PHRASE_COOLDOWNS[$i]}
                break
            fi
        done
    fi

    [[ -n $chosen ]] || chosen="I have no phrase for $event. Even my resentment has coverage gaps."
    _marvin_phrase_remember "$event" "$chosen"
    printf '%s\n' "$chosen"
}

_marvin_should_comment() {
    local event=$1
    case "$event" in
        command_success|fast_success) _marvin_comment_gate "$event" "$((MARVIN_COMMENT_RATE / (MARVIN_PERSONALITY_LEVEL >= 3 ? 3 : 8)))" ;;
        repeated_command) _marvin_comment_gate "$event" "$((MARVIN_COMMENT_RATE / 2 + 25))" ;;
        existential|rare_complaint|accidental_optimism) _marvin_comment_gate "$event" "$((MARVIN_PERSONALITY_LEVEL >= 3 ? 4 : 1))" ;;
        *) _marvin_comment_gate "$event" "$MARVIN_COMMENT_RATE" ;;
    esac
}

_marvin_say() {
    local event=$1
    shift || true
    _marvin_should_comment "$event" || return 0
    printf '%s' "$_MV_GREY"
    _marvin_wrap "$(_marvin_phrase "$event" "$@")"
    printf '%s' "$_MV_RESET"
}

_marvin_phrase_count() {
    _marvin_phrases_load
    printf '%s\n' "${#_MARVIN_PHRASE_TEXTS[@]}"
}

_marvin_phrases_for_event() {
    local event=$1 i
    _marvin_phrases_load
    for i in "${!_MARVIN_PHRASE_EVENTS[@]}"; do
        [[ ${_MARVIN_PHRASE_EVENTS[$i]} == "$event" ]] || continue
        printf '%s\n' "${_MARVIN_PHRASE_TEXTS[$i]}"
    done
}
