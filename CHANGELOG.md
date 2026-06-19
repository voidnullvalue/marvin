# Changelog

## Unreleased

- Removed forced `HISTTIMEFORMAT`, `cmdhist`, and `histappend` mutations.
- Added `uninstall.sh` for safe removal of Marvin's managed `.bashrc` source
  block and symlink.
- Reworked mood into a bounded state machine with daily baseline, persisted
  previous mood, intensity, irritation, fatigue, despair, cooperation, wounded
  pride, operator trust, sulking episodes, and verbose factor reporting.
- Added phrase IDs, mood constraints, cooldown-aware selection, persistent
  recent-ID history, `marvin phrase-stats`, and diagnostic phrase listing.
- Expanded phrase coverage to more than 600 original templates across more than
  50 events.
- Added refusal cooldowns, per-session refusal maximums, `marvin
  refusal-status`, and deterministic forced-refusal test support.
- Made `sudo` wrapping resolve the real command portably instead of hardcoding
  `/usr/bin/sudo`.
- Added dirty-state tracking and periodic state flush to avoid routine state-file
  rewrites after ordinary prompts.
- Added `marvin benchmark`.
- Split tests into focused scripts with isolated HOME/XDG state and no live
  Internet requirement.
