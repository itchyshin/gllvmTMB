# Recovery checkpoints

Durable handoff files for long or interrupted agent (Codex or Claude
Code) sessions. Each checkpoint is a compact Markdown snapshot of the
working tree state, the newest `docs/dev-log/check-log.md` sections,
the newest after-task reports, and recovery commands the next agent
should run before assuming the checkpoint is current.

## Why

Long sessions leak context. When a Codex stream fails partway through
a multi-file change, or a Claude Code session is paused for hours and
resumed cold, the next agent needs a self-contained brief to pick up
without re-discovering the whole state from scratch. A checkpoint is
that brief.

The pattern was adopted from the drmTMB sister package on 2026-05-15
(Jason persona cross-team scout). drmTMB has used this discipline
since 2026-05-12 and accumulated ~10 checkpoints in the first three
days alone.

## How to create one

```sh
Rscript tools/codex-checkpoint.R \
  --goal "what you were trying to accomplish in this session" \
  --next "what the next agent should do first when resuming"
```

Optional flags:

- `--sections N` — number of newest `check-log.md` sections to
  include (default 3).
- `--output PATH` — write to a specific path instead of the
  auto-named `docs/dev-log/recovery-checkpoints/<timestamp>-codex-checkpoint.md`.
- `--stdout` — print the checkpoint to stdout instead of writing a
  file (useful for pasting into chat).
- `--help` — show the full help.

## When to create one

- Before a long-running test suite that may stall the session.
- Before a known-risky multi-PR sequence (e.g., the upcoming Phase
  1c-slope engine work — 6 PRs touching `R/fit-multi.R`,
  `src/gllvmTMB.cpp`, and extractors).
- After landing a substantive PR, so the next agent picks up from a
  clean known-good state.
- When a session is about to be paused for hours or days.

## What lives here

Filenames are auto-stamped `YYYY-MM-DD-HHMMSS-codex-checkpoint.md`.
The directory is tracked in git (via `.gitkeep` and this README) so
the checkpoint history is durable across agents and machines.

Old checkpoints can be deleted when they're no longer useful; there
is no retention policy enforced. The most recent few are usually
enough.
