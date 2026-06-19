# Marvin Terminal

Marvin Terminal is an interactive Bash personality layer for Void Linux systems:
a compact telemetry prompt plus a persistent, context-aware, miserable machine
that comments on shell activity with more intelligence than the work deserves.

It is not a greenfield shell. Normal commands still run normally. Prompt
rendering does not fetch weather or make network requests.

## Example Transcript

```text
┌─[void@host][bat:38][ram:80%][load:1.89] git:feature/stateful-marvin-personality*
└─[still here] › false
That failed with status 1. I had made room for disappointment.

┌─[void@host][bat:38][ram:80%][load:1.89] git:feature/stateful-marvin-personality*
└─[failed:1] › definitely-not-real
'definitely-not-real' is not available. I searched the obvious places; they were mercifully empty.

┌─[void@host][bat:38][ram:80%][load:1.89] git:feature/stateful-marvin-personality*
└─[failed:127] › marvin mood --verbose
mood=quietly resentful
intensity=42
reason=combined pressure moderate; bad_day=0
```

## Install And Uninstall

```bash
./install.sh
exec bash
```

The installer creates `~/.local/lib/marvinrc.sh` as a symlink to this checkout
and appends one marked source block to `~/.bashrc`. Re-running it is idempotent.

```bash
./uninstall.sh
```

The uninstaller removes only Marvin's managed source block and symlink. It leaves
unrelated `.bashrc` content alone.

## Architecture

- `marvinrc.sh`: interactive-only loader.
- `lib/core.sh`: config, colors, sanitization, small helpers.
- `lib/state.sh`: bounded state, history, dirty tracking, atomic flush.
- `lib/mood.sh`: slow mood state machine and verbose factor reporting.
- `lib/phrases.sh`: phrase IDs, weights, cooldowns, anti-repeat, stats.
- `lib/telemetry.sh`: RAM, disk, battery, temperature, load, Git, VPN, runit, XBPS.
- `lib/weather.sh`: explicit cached weather/forecast commands.
- `lib/notifications.sh`: sanitized long-command desktop notifications.
- `lib/refusal.sh`: rare allowlisted theatrical refusal wrappers.
- `lib/prompt.sh`: command timing, prompt rendering, benchmark.
- `lib/commands.sh`: public command interface and shell hooks.
- `compatibility/legacy-hax.sh`: optional old `hax*` aliases, not loaded by default.

## Public Commands

```text
marvin
marvin status
marvin weather
marvin forecast
marvin thought
marvin sulk
marvin complain
marvin mood
marvin mood --verbose
marvin state
marvin history
marvin reset-mood
marvin phrases EVENT
marvin phrase-stats
marvin cooperate
marvin please COMMAND [ARGS...]
marvin refuse on|off
marvin refusal-status
marvin personality 0|1|2|3
marvin debug on|off
marvin benchmark
marvin doctor
marvin help
```

Short aliases kept for usability: `status`, `weather`, `forecast`, `thought`,
`sulk`, `complain`, and `mood`.

## Configuration

```text
MARVIN_PERSONALITY_LEVEL=0..3
MARVIN_COMMENT_RATE=0..100
MARVIN_REFUSAL=0|1
MARVIN_REFUSAL_RATE=1
MARVIN_REFUSAL_COOLDOWN_COMMANDS=20
MARVIN_REFUSAL_COOLDOWN_SECONDS=1200
MARVIN_REFUSAL_SESSION_MAX=2
MARVIN_BYPASS=1
MARVIN_DEBUG=1
MARVIN_WEATHER_LOCATION="City"
MARVIN_LOGIN_REPORT=0|1
MARVIN_LONG_COMMAND_SECONDS=10
MARVIN_NOTIFICATION_COOLDOWN=45
MARVIN_STATE_FLUSH_INTERVAL=12
```

Personality level `0` leaves telemetry/prompt behavior and disables commentary
and refusal. Level `1` is restrained, `2` is normal, and `3` increases frequency
and variety without printing paragraphs after every command.

## Mood Model

Mood is not selected from a fresh weighted list on every prompt. Marvin keeps a
daily baseline, persisted previous mood, session factors, and event-driven
pressure:

```text
daily baseline
+ previous mood
+ irritation, fatigue, despair, cooperation, wounded pride, operator trust
+ failures, repeated commands, warnings, battery/system pressure, uptime
+ sulking episode and cooldown state
= mood and intensity
```

Supported public moods include `resigned`, `morose`, `irritable`, `wounded`,
`catatonic`, `bitterly efficient`, `theatrically doomed`, `quietly resentful`,
`unusually cooperative`, `existential`, `sulking`, and `exhausted`.

Use `marvin mood --verbose` to see sanitized factors. It does not reveal full
command arguments.

## Phrase Engine

`marvin phrase-stats` reports the validated phrase/event counts. `marvin phrases
EVENT` prints phrase ID, event, mood constraints, weight, cooldown, and text.

Selection supports event-specific banks, weights, mood constraints, cooldowns,
session and persistent anti-repeat, safe placeholder interpolation, phrase IDs,
and `MARVIN_PHRASE_DEBUG=1` diagnostics. Recent phrase IDs are persisted so the
same line is not repeated among the last 25 selections.

## Refusal Guarantees

Refusal is rare, explicit, and restricted to allowlisted harmless commands such
as `ls`, `date`, `whoami`, `uptime`, `fortune`, `cowsay`, `clear`, and
`fastfetch`.

It never applies in noninteractive shells, scripts, non-TTY sessions,
`MARVIN_BYPASS=1`, `marvin cooperate`, protected commands, package management,
Git state-changing operations, SSH/SCP/rsync, mount/service/network/reboot
operations, or unclassified commands. It does not use `eval`, does not partially
execute, returns status `75`, and prints an exact bypass.

```bash
MARVIN_BYPASS=1 ls -la
marvin please ls -la
marvin cooperate
marvin refuse off
marvin refusal-status
```

## State, Cache, And Performance

State lives under `${XDG_CACHE_HOME:-$HOME/.cache}/marvin-terminal/` with `0700`
directory permissions and `0600` files:

```text
state       bounded counters and mood factors
history     sanitized recent events
phrases     recent phrase IDs
weather.txt explicit weather cache
updates.txt cached XBPS update count
```

Normal prompt rendering uses in-memory telemetry caches and dirty-state flushes.
XBPS, runit, weather, and network-heavy checks are cached or explicit commands.
`marvin benchmark` estimates cached prompt overhead.

## Testing

```bash
./tests/run.sh
./tests/smoke.sh
make test
make diff
```

Tests use isolated HOME/XDG directories and do not require live Internet access.
ShellCheck is useful when available but is not a runtime dependency.

## Adding A Phrase Event

Add templates with `_marvin_phrase_add event weight cooldown "text"` in
`lib/phrases.sh`, emit through `_marvin_say event key value`, then run
`./tests/test-phrases.sh`. Lines must be original, event-specific, technically
aware, dry, and concise.

## Migration From The Old Haxx0r Version

The default shell no longer loads `haxstatus`, `haxweather`, `haxforecast`,
`haxoff`, `haxon`, or `haxdoctor`. Source `compatibility/legacy-hax.sh` manually
after Marvin only if local shell snippets still depend on those names.
