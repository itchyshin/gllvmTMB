# After-task report: runtime ordinary unique diagnostic cleanup

Date: 2026-06-18 21:15 MDT

Branch: `codex/r-bridge-grouped-dispersion`

Guard preserved: `PR green != bridge complete != release ready != scientific coverage passed`.

## Task

Continue the post-coevolution `unique()` deprecation cleanup by removing runtime
diagnostics that still taught ordinary `unique()` as the new spelling.

## Files touched

- `R/brms-sugar.R`
- `R/fit-multi.R`
- `docs/dev-log/check-log.md`
- `docs/dev-log/dashboard/status.json`
- `docs/dev-log/dashboard/sweep.json`

## What changed

- The deprecated `diag()` alias warning now recommends `indep()` for new
  standalone diagonal code and points shared + diagonal-Psi users to ordinary
  `latent(..., d = K)`. It mentions explicit `unique()` only as compatibility.
- Unit-observation augmented-slope diagnostics now recommend
  `latent(1 + x | unit, d = K)` for the default reaction norm and keep
  `unique(1 + x | unit)` as legacy diagonal-only compatibility.
- Cluster2 diagonal-only diagnostics now recommend `indep(0 + trait | cluster2)`.
- The phylogenetic `p_it + q_it` informational message now uses
  `phylo_unique(...) + indep(...)` and describes ordinary `unique()` as
  compatibility syntax.

## Definition-of-done accounting

1. Implementation: local diagnostic cleanup only; not merged to `main`.
2. Simulation recovery: not applicable; no model behavior changed.
3. Documentation: no roxygen behavior changed; runtime warning text is the
   public surface for this slice.
4. Runnable example: not applicable; no examples changed.
5. Check-log: `docs/dev-log/check-log.md` has the 21:15 MDT entry with exact
   commands and outcomes.
6. Review pass: no likelihood or formula-grammar behavior changed; this was a
   lifecycle/diagnostic consistency slice.

## Validation

- `parse("R/brms-sugar.R")` and `parse("R/fit-multi.R")` succeeded.
- Focused `canonical-keywords|unique-family-deprecation|ordinary-latent-random-regression|keyword-grid`
  tests passed with expected INLA skips.
- `pkgdown::check_pkgdown()` reported `No problems found.`
- Focused stale scan found no remaining `diag() -> use unique()` or ordinary
  runtime “Use unique(...)” guidance in the touched files, apart from the
  intentional `phylo_unique(...) + indep(...)` source-specific compatibility
  line.
- Dashboard JSON validation and `git diff --check` passed.

## Still open

- No keyword removal.
- No source-specific/kernel paired-Psi fold.
- No extractor `part = "unique"` rename.
- Broader post-arc `unique()` lifecycle/deprecation cleanup remains ongoing.
