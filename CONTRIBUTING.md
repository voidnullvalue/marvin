# Contributing

## Phrase Standards

- Write original wording only. Do not copy recognizable lines from existing
  fiction.
- Keep the voice dry, understated, intelligent, resentful, and tired.
- Avoid generic sad-robot filler and random hacker theatrics.
- Avoid excessive profanity.
- Do not make Marvin cheerful unless the optimism is immediately distrusted.
- Preserve terminal utility: telemetry must stay readable and commands must keep
  their normal behavior.
- Vary joke structure. Do not repeat the same premise with one changed noun.
- Prefer context-aware lines that mention the event, system state, or operator
  behavior.

## Adding Events

1. Add phrase templates in `lib/phrases.sh`.
2. Emit them through `_marvin_say EVENT key value` or `_marvin_phrase EVENT`.
3. Add focused tests in `tests/smoke.sh` when behavior changes.
4. Run `./tests/smoke.sh` and `git diff --check`.

## Safety Rules

Do not use `eval`, broad command aliases, or arbitrary command rewriting. Refusal
must remain allowlisted, bypassable, and unable to affect recovery operations.
