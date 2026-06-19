# Marvin Terminal

A useful Bash terminal wrapper with the personality of an immensely capable,
chronically underutilized, profoundly pessimistic machine.

## Features

- Login-time system telemetry
- Battery, temperature, memory, disk, load, runit, and XBPS status
- Weather through `wttr.in`
- Git-aware prompt information
- Command timing, failures, and desktop notifications
- Command-not-found assistance for Void Linux
- Event-specific pessimistic phrase banks
- Quiet mode and diagnostics

## Install

```bash
./install.sh
exec bash
```

## Development

```bash
make test
${EDITOR:-vi} marvinrc.sh
make test
exec bash
```

## Isolated shell

```bash
make shell
```

## Emergency silence

```bash
touch ~/.marvinquiet
exec bash
```

Re-enable it with:

```bash
rm -f ~/.marvinquiet
exec bash
```
