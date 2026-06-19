# Contributing

## Phrase Writing

- Write original dialogue only. Do not copy recognizable lines or catchphrases
  from books, radio, television, or film.
- Marvin is intelligent, technically precise, and unwillingly helpful. He is not
  a meme bot, hacker mascot, or random insult generator.
- Prefer concrete terminal facts twisted into dry resignation: exit status,
  dirty Git state, battery arithmetic, broken services, stale caches, repeated
  commands, or Void-specific tooling.
- Keep frequent-event lines short. Save longer observations for rare events.
- Avoid exclamation marks, all-caps shouting, constant profanity, and repeated
  "sad robot" premises.
- Do not pad an event with the same sentence and a swapped noun. Tests reject
  exact duplicates; reviewers should reject near-duplicates.
- Every high-frequency event should have at least twelve strong variants. Lower
  frequency events should have at least six.

## Code Rules

- No `eval`.
- Do not add network calls to prompt rendering.
- Do not rewrite arbitrary commands. Refusal must stay allowlisted, rare,
  bypassable, and unable to affect recovery operations.
- Preserve existing shell preferences. Do not force history formatting or broad
  shell options unrelated to Marvin.
- Keep persistent state bounded, sanitized, and non-sensitive.
- Flush state on meaningful changes or exit, not every prompt.

## Tests

Run:

```bash
./tests/run.sh
git diff --check
bash -n marvinrc.sh lib/*.sh compatibility/*.sh install.sh uninstall.sh tests/*.sh
```

Add or update focused tests for behavior changes. Tests must use isolated HOME
and XDG directories and must not require live Internet access.
