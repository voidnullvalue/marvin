# Marvin Terminal

A Bash terminal personality wrapper inspired by a vastly overqualified,
chronically disappointed machine. It preserves useful shell telemetry while
adding persistent mood, phrase selection, cautious commentary, desktop
notifications, and rare safe refusal of harmless commands.

## Install

```bash
./install.sh
exec bash
```

The installer symlinks `~/.local/lib/marvinrc.sh` to this repository and adds a
single source line to `~/.bashrc`. Running it repeatedly is idempotent.

## Architecture

`marvinrc.sh` is a small interactive-only loader. Behavior lives in `lib/`:

- `core.sh`: configuration, colors, wrapping, sanitization
- `state.sh`: bounded state under `~/.cache/marvin-terminal/`
- `phrases.sh`: 400+ original templates, weighting, cooldowns, anti-repeat
- `mood.sh`: session-stable mood derived from date, host, state, and warnings
- `telemetry.sh`: battery, temperature, RAM, disk, load, VPN, Git, runit, XBPS
- `weather.sh`: cached `wttr.in` weather and forecast helpers
- `notifications.sh`: sanitized desktop notifications with cooldown
- `refusal.sh`: safe allowlisted command refusal wrappers
- `prompt.sh`: DEBUG/PROMPT_COMMAND timing and compact prompt
- `commands.sh`: public commands, sudo/APT interception, command-not-found

Prompt rendering uses cached telemetry and does not make weather/network
requests.

## Commands

```text
marvin status
marvin weather
marvin forecast
marvin thought
marvin sulk
marvin complain
marvin mood
marvin state
marvin history
marvin reset-mood
marvin phrases EVENT
marvin cooperate
marvin please command [args...]
marvin refuse on|off
marvin personality 0|1|2|3
marvin debug on|off
marvin doctor
marvin help
```

Compatibility commands remain: `status`, `weather`, `forecast`, `thought`,
`sulk`, `complain`, `mood`, `marvindoctor`, `marvinoff`, and `marvinon`.

## Mood And State

Mood is normally stable for a shell session. It is derived from the date,
hostname, previous mood, recent failures, repeated commands, long commands,
warnings, uptime, and refusal count. Some host/date combinations produce a
deterministic bad-day modifier.

State is bounded and local:

```text
~/.cache/marvin-terminal/state
~/.cache/marvin-terminal/history
~/.cache/marvin-terminal/phrases
~/.cache/marvin-terminal/weather.txt
~/.cache/marvin-terminal/updates.txt
```

The directory is `0700`; state files are `0600`. Marvin stores sanitized recent
command labels and small counters only. It does not store command output,
environment variables, tokens, or full shell history.

## Refusal Behavior

Refusal is rare, transparent, and restricted to wrapped harmless commands:
`ls`, `date`, `whoami`, `uptime`, `fortune`, `cowsay`, `clear`, and
`fastfetch`.

It never applies in noninteractive shells, scripts, non-TTY stdin/stdout,
`MARVIN_BYPASS=1`, `marvin cooperate`, or protected/recovery commands. Pipelines
and redirections normally remove TTY stdout/stdin, so refusal is skipped. Marvin
does not use `eval` or broad DEBUG-trap command rewriting to refuse commands.

If a command is refused, it is not executed, status `75` is returned, and the
bypass is printed:

```bash
MARVIN_BYPASS=1 ls
marvin please ls -la
marvin cooperate
marvin refuse off
```

Disable permanently by exporting `MARVIN_REFUSAL=0` before sourcing Marvin.

## Configuration

```text
MARVIN_REFUSAL=0|1
MARVIN_REFUSAL_RATE=1
MARVIN_PERSONALITY_LEVEL=0..3
MARVIN_COMMENT_RATE=0..100
MARVIN_MOOD="forced mood"
MARVIN_BYPASS=1
MARVIN_DEBUG=1
MARVIN_WEATHER_LOCATION="City"
MARVIN_LOGIN_REPORT=0|1
MARVIN_LONG_COMMAND_SECONDS=10
MARVIN_NOTIFICATION_COOLDOWN=45
```

Personality levels: `0` is utility-only, `1` restrained, `2` normal, `3`
maximum sulking. To disable every personality feature without uninstalling:

```bash
export MARVIN_PERSONALITY_LEVEL=0
export MARVIN_REFUSAL=0
touch ~/.marvinquiet
exec bash
```

## Testing

```bash
./tests/smoke.sh
make test        # if make is installed
make diff
```

Tests use isolated temporary HOME directories and do not require live network
access.

## Troubleshooting

- `marvin doctor` reports optional helper availability.
- Weather uses a cache and degrades cleanly if `curl` or the network is absent.
- XBPS update checks are cached for six hours.
- If prompt behavior conflicts with an existing complex `PROMPT_COMMAND`, Marvin
  preserves simple function-name hooks and skips complex shell snippets rather
  than evaluating them.

## Adding Phrase Banks

Add templates in `lib/phrases.sh` with:

```bash
_marvin_phrase_add event weight cooldown "Original phrase with {detail}"
```

Then call it with:

```bash
_marvin_say event detail "root filesystem is 91%"
```

Use specific events, safe interpolation keys, and several structurally different
lines. Keep wording dry, restrained, and original.
