# After-task: Lift `tools/codex-checkpoint.R` from drmTMB -- 2026-05-15

**Tag**: `tooling` (new R script + new dev-log subdirectory; no R/
source change, no test, no NAMESPACE change).

**PR / branch**: this PR / `agent/lift-codex-checkpoint-from-drmtmb`.

**Lane**: Claude (Codex absent).

**Dispatched by**: maintainer 2026-05-15 ("you can do B and then A")
after the Jason persona drmTMB cross-team scout (same morning) named
the codex-checkpoint script as the top concrete action item for the
gllvmTMB team this week.

## Files (5)

- **`tools/codex-checkpoint.R`** (NEW, 305 lines). Lifted verbatim from
  drmTMB's `tools/codex-checkpoint.R` (file dated 2026-05-12, 284
  lines pre-comment). Added a 21-line provenance header comment at
  the top explaining the source + the date + the usage pattern.
- **`docs/dev-log/recovery-checkpoints/`** (NEW directory).
- **`docs/dev-log/recovery-checkpoints/.gitkeep`** (NEW, empty).
  Keeps the directory tracked even when empty.
- **`docs/dev-log/recovery-checkpoints/README.md`** (NEW). Brief
  explainer of what the directory is for, when to create a
  checkpoint, what flags the script accepts.
- **`docs/dev-log/recovery-checkpoints/2026-05-15-054356-codex-checkpoint.md`**
  (NEW). First real checkpoint, generated during the lift by running
  the script once with `--goal "Adopt drmTMB's codex-checkpoint.R
  tool"` and `--next "Open PR for the lift; then proceed to Phase 1b
  item 3"`. Demonstrates the script works on the gllvmTMB tree
  without modification.

## Math contract

N/A. No public R API, likelihood, formula grammar, family,
NAMESPACE, generated Rd, vignette, or pkgdown navigation change.

## Why the direct lift works

The drmTMB script's structure is package-agnostic. It reads:

- `docs/dev-log/check-log.md` -- newest N sections (default 3).
- `docs/dev-log/after-task/` -- newest 8 reports by mtime.
- Git state via `git status --short --branch`, `git diff
  --name-status`, `git ls-files --others --exclude-standard`,
  `git diff --stat`, `git log -1 --oneline`.

It then writes a timestamped Markdown checkpoint to
`docs/dev-log/recovery-checkpoints/`. gllvmTMB has the same dir
layout drmTMB uses (`docs/dev-log/check-log.md`,
`docs/dev-log/after-task/`), so no path adaptation is needed. The
sample checkpoint generated during this PR confirms it works out of
the box.

## Checks run

- Smoke test: `Rscript tools/codex-checkpoint.R --goal ... --next
  ... --stdout` → renders cleanly to stdout, includes git state +
  newest check-log sections + newest after-task reports.
- File-write test: `Rscript tools/codex-checkpoint.R --goal ...` →
  writes `docs/dev-log/recovery-checkpoints/<timestamp>-codex-checkpoint.md`.
  Verified the file exists and is well-formed (6113 bytes).
- `pkgdown::check_pkgdown()`: not run; no package-rendered file touched.

## Consistency audit

```
# Provenance traceability
rg -n 'drmTMB/tools/codex-checkpoint.R' tools/ docs/dev-log/
  -> 2 hits: the provenance comment + this after-task report.

# Directory created and gitkeep present
ls docs/dev-log/recovery-checkpoints/
  -> .gitkeep, README.md, 2026-05-15-054356-codex-checkpoint.md.

# Script is executable as Rscript
file tools/codex-checkpoint.R
  -> Rscript with #!/usr/bin/env Rscript shebang.
```

## Tests of the tests

No package tests added. The script is exercised once during this PR
(producing the sample checkpoint). A future Phase 1c-slope PR (the
multi-PR engine work) will be a natural moment to use it for real.

## Why now (per Jason cross-team scout)

The drmTMB team has used `tools/codex-checkpoint.R` since 2026-05-12
and accumulated ~10 checkpoints in the first three days. Their
multi-day Codex slice work (Slice 47 design-gate → Slices 48-50
implementation) benefits from durable handoffs every time a stream
fails or a session pauses.

gllvmTMB's upcoming Phase 1c-slope (random slopes pre-CRAN, 6 PRs
of engine + extractor + recovery-test + plots + article work) is
exactly the long-scope context where checkpoints prevent leaked
context across agent sessions. Better to have the tooling in place
before the work starts than after the first stalled session.

The Phase 1b items 3-6 + validation milestone (the next ~5-6 PRs)
will also use it where useful.

## Roadmap tick

> **Roadmap tick**: N/A. Tooling addition; no `ROADMAP.md` phase
> row's status chip or progress bar changes in this PR.

(Future amendment: when Phase 1c-slope dispatches, mention this
script in the Phase 1c-slope section as part of the engine-PR
discipline.)

## What went well

- Direct verbatim lift; no adaptation required. The drmTMB script's
  directory assumptions match gllvmTMB exactly.
- Sample checkpoint generated during the lift demonstrates it works
  out of the box.
- The Jason scout's specific action item ("lift
  `tools/codex-checkpoint.R` from drmTMB") was executable as
  described; no surprises.

## What did not go smoothly

- Nothing flagged. Smallest possible scope for a tooling addition.

## Team learning, per AGENTS.md "Standing Review Roles"

- **Jason (literature / scout)**: the periodic cross-team scout
  pattern (dispatched 2026-05-15 morning) surfaced this concrete
  action item alongside 4 other "learn from drmTMB" items and 5
  "teach drmTMB" items. The cadence works -- one scout per
  phase-boundary is the right frequency for cross-team learning
  without ritualising the process.
- **Shannon (cross-team)**: the lift propagates a drmTMB working
  pattern into gllvmTMB. Cross-team coordination is fundamentally
  about sharing what works; this is a clean instance.
- **Ada (maintainer)**: confirmed B before A ordering ("you can do
  B and then A"). The small-side-quest-before-substantive-engine-work
  ordering is the right call when the side-quest unlocks better
  process for the substantive work.
- **Boole / Gauss / Noether / Darwin / Fisher / Curie / Pat / Rose /
  Emmy / Grace**: standing brief. No engine, math, biology, test,
  user-experience, audit, architecture, or CI change.

## Design-doc updates

- None for this PR. A short cross-reference from
  `docs/design/10-after-task-protocol.md` to the new
  `recovery-checkpoints/` directory could be added later; for now
  the directory's README is the entry point.

## pkgdown / documentation updates

- None. `tools/` is not in pkgdown's render path.

## Known limitations and next actions

**Known limitations**: the script's output filename includes
"codex-" as a prefix (`<timestamp>-codex-checkpoint.md`) because
that matches the drmTMB convention. gllvmTMB has both Codex and
Claude Code agents; either can use the script. If the prefix
becomes confusing, a future PR can switch to `<timestamp>-recovery-checkpoint.md`.
Not changing it now to preserve the direct-lift provenance.

**Next actions**:

1. After this PR merges: continue with the maintainer's "B then A"
   plan -- open Phase 1b item 3 (`check_auto_residual()` safeguard)
   on a new branch.
2. The first time a Phase 1c-slope PR sequence starts, generate a
   checkpoint to mark the multi-PR session entry point.
