# After-task report: current design-doc ordinary unique cleanup

Date: 2026-06-18 20:56 MDT

Branch: `codex/r-bridge-grouped-dispersion`

Guard preserved: `PR green != bridge complete != release ready != scientific coverage passed`.

## Task

Continue the post-coevolution `unique()` deprecation cleanup by removing current
design-doc examples that still taught explicit ordinary `unique()` as the
default companion to ordinary `latent()`.

## Files touched

- `docs/design/02-data-shape-and-weights.md`
- `docs/design/05-testing-strategy.md`
- `docs/design/06-extractors-contract.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/dashboard/status.json`
- `docs/dev-log/dashboard/sweep.json`

## What changed

- Long and wide data-shape examples now teach default `latent()`.
- RE-12 testing-strategy wording now says default `latent()` carries the
  Gaussian random-regression diagonal Psi companion.
- The testing pseudocode now fits `latent(0 + trait | site, d = 2)` without an
  explicit ordinary `unique()` term.
- Extractor-contract prose now names explicit `latent + unique` as
  compatibility syntax for the ordinary unit-tier side.

## Definition-of-done accounting

1. Implementation: documentation-only cleanup on the local branch; not merged
   to `main`.
2. Simulation recovery: not applicable; no model behavior changed.
3. Documentation: current design docs updated.
4. Runnable example: design-doc pseudocode and examples now use the current
   default spelling.
5. Check-log: `docs/dev-log/check-log.md` has the 20:56 MDT entry with exact
   commands and outcomes.
6. Review pass: no likelihood, parser, or exported API change. This was a
   lifecycle/documentation consistency slice.

## Validation

- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'` reported `No problems found.`
- Stale-syntax scan over the active design-doc surface found no active ordinary
  default `latent() + unique()` teaching; the remaining hits were the new
  default `latent()` pseudocode line and a historical FAM-07 ledger paragraph.

## Still open

- No keyword removal.
- No source-specific or kernel paired-Psi fold.
- No `part = "unique"` rename.
- Broader post-arc `unique()` lifecycle/deprecation cleanup remains ongoing.
