#!/usr/bin/env bash

set -euo pipefail

repo="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
marvin="$repo/marvinrc.sh"
tmp_root="$(mktemp -d /tmp/marvin-test.XXXXXX)"
trap 'rm -rf "$tmp_root"' EXIT

fail() {
    printf 'FAIL: %s\n' "$*" >&2
    exit 1
}

run_i() {
    local home="$tmp_root/home"
    mkdir -p "$home"
    env -i \
        HOME="$home" \
        XDG_CACHE_HOME="$home/.cache" \
        USER="${USER:-void}" \
        LOGNAME="${LOGNAME:-${USER:-void}}" \
        PATH="$PATH" \
        TERM="${TERM:-xterm-256color}" \
        SHELL=/bin/bash \
        MARVIN_LOGIN_REPORT=0 \
        bash --noprofile --norc -ic "$1" _ "$marvin"
}

printf 'Checking Bash syntax...\n'
while IFS= read -r file; do
    bash -n "$file" || exit 1
done < <(find "$repo" -maxdepth 2 -type f \( -name '*.sh' -o -name 'marvinrc.sh' \) | sort)

printf 'Checking unsafe eval absence...\n'
if grep -Rnw --include='*.sh' --include='marvinrc.sh' 'eval[[:space:]]' "$repo/marvinrc.sh" "$repo/lib" "$repo/tests"; then
    fail 'unsafe eval text found'
fi

printf 'Checking interactive loading and public API...\n'
run_i '
    source "$1"
    required=(
        marvin marvinstatus marvinweather marvinforecast marvinthought
        marvindoctor marvinoff marvinon status weather forecast thought
        sulk complain mood marvindoctor
    )
    for name in "${required[@]}"; do
        type "$name" >/dev/null 2>&1 || { printf "missing %s\n" "$name" >&2; exit 1; }
    done
    marvin help >/dev/null
    marvin mood >/dev/null
    marvin state >/dev/null
    marvin history >/dev/null
    phrases=$(marvin phrases command_failure)
    [[ -n $phrases ]]
'

printf 'Checking quiet mode and personality level zero...\n'
run_i '
    touch "$HOME/.marvinquiet"
    source "$1"
    marvin thought >/dev/null
    [[ ${MARVIN_QUIET:-0} != 1 ]]
'
run_i '
    export MARVIN_PERSONALITY_LEVEL=0
    source "$1"
    [[ ${MARVIN_QUIET:-0} == 1 ]]
'

printf 'Checking phrase selection and anti-repetition...\n'
run_i '
    source "$1"
    a=$(_marvin_phrase command_failure status 2)
    b=$(_marvin_phrase command_failure status 2)
    [[ -n $a && -n $b && $a != "$b" ]]
    (($( _marvin_phrase_count ) >= 400))
'

printf 'Checking mood persistence and deterministic mood input...\n'
run_i '
    source "$1"
    first=$(marvin mood)
    [[ -n $first ]]
    [[ -s "$XDG_CACHE_HOME/marvin-terminal/state" ]]
    grep -q "^MARVIN_STATE_LAST_MOOD=" "$XDG_CACHE_HOME/marvin-terminal/state"
    _marvin_daily_mood_seed >/dev/null
'

printf 'Checking state permissions and bounded files...\n'
run_i '
    source "$1"
    state_dir="$XDG_CACHE_HOME/marvin-terminal"
    [[ $(stat -c %a "$state_dir") == 700 ]]
    [[ $(stat -c %a "$state_dir/state") == 600 ]]
    for i in {1..120}; do _marvin_history_add test "entry-$i"; done
    [[ $(wc -l < "$state_dir/history") -le 80 ]]
'

printf 'Checking refusal safety...\n'
env -i HOME="$tmp_root/noninteractive" XDG_CACHE_HOME="$tmp_root/noninteractive/.cache" USER=test PATH="$PATH" TERM=xterm \
    bash -c 'source "$1"; ! type _marvin_should_refuse >/dev/null 2>&1; ! type marvin >/dev/null 2>&1' _ "$marvin"

run_i '
    source "$1"
    export MARVIN_REFUSAL_RATE=100 MARVIN_MOOD=sulking
    _marvin_mood_refresh
    _marvin_should_refuse ls; [[ $? -ne 0 ]]
'

run_i '
    source "$1"
    export MARVIN_BYPASS=1 MARVIN_REFUSAL_RATE=100 MARVIN_MOOD=sulking
    _marvin_mood_refresh
    _marvin_should_refuse ls; [[ $? -ne 0 ]]
'

run_i '
    source "$1"
    export MARVIN_REFUSAL_RATE=100 MARVIN_MOOD=sulking
    _marvin_mood_refresh
    set +e
    for protected in cd pwd exit logout jobs fg bg kill disown ssh git sudo doas mount umount reboot shutdown; do
        _marvin_should_refuse "$protected"
        [[ $? -ne 0 ]] || exit 1
    done
    set -e
'

run_i '
    source "$1"
    export MARVIN_REFUSAL_RATE=100 MARVIN_MOOD=sulking
    _marvin_mood_refresh
    set +e
    ls >/tmp/marvin-refusal.out 2>/tmp/marvin-refusal.err
    rc=$?
    set -e
    [[ $rc -eq 0 || $rc -eq 75 ]]
    if [[ $rc -eq 75 ]]; then grep -q "Command was not executed" /tmp/marvin-refusal.err; fi
'

run_i '
    source "$1"
    mkdir -p "$HOME/bin"
    cat > "$HOME/bin/argvdump" <<'"'"'EOF'"'"'
#!/usr/bin/env bash
printf "<%s>\n" "$@"
EOF
    chmod +x "$HOME/bin/argvdump"
    PATH="$HOME/bin:$PATH"
    out=$(marvin please argvdump "two words" "semi;colon" '"'"'quote"mark'"'"')
    grep -q "<two words>" <<<"$out"
    grep -q "<semi;colon>" <<<"$out"
    grep -q "<quote\"mark>" <<<"$out"
'

printf 'Checking command status preservation and Ctrl-C mapping...\n'
run_i '
    source "$1"
    set +e
    false
    rc=$?
    set -e
    [[ $rc -eq 1 ]]
    _marvin_comment_after_command 130 0 "sleep"
'

printf 'Checking command-not-found and weather degradation...\n'
run_i '
    source "$1"
    xbps-query() { return 1; }
    curl() { return 7; }
    set +e
    command_not_found_handle definitely_not_a_real_command >/tmp/cnf.out 2>/tmp/cnf.err
    rc=$?
    set -e
    [[ $rc -eq 127 ]]
    [[ -s /tmp/cnf.err ]]
    set +e
    marvin weather >/tmp/weather.out 2>/tmp/weather.err
    wrc=$?
    set -e
    [[ $wrc -ne 0 ]]
'

printf 'Checking prompt generation without network and notification sanitization...\n'
run_i '
    source "$1"
    _marvin_prompt_dispatch >/tmp/prompt.out
    [[ -n ${PS1:-} ]]
    body=$(_marvin_command_label "deploy --token secretvalue")
    [[ $body != *secretvalue* ]]
'

printf 'Checking installer idempotence in isolated HOME...\n'
home="$tmp_root/install-home"
mkdir -p "$home"
HOME="$home" bash "$repo/install.sh" >/tmp/install1.out
HOME="$home" bash "$repo/install.sh" >/tmp/install2.out
[[ $(grep -c "marvinrc.sh" "$home/.bashrc") -eq 1 ]] || fail 'installer duplicated bashrc entry'

printf 'Marvin remains functional. He has decided not to interpret this as encouragement.\n'
