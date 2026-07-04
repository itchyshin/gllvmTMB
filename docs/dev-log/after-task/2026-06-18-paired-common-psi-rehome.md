# After-task report: paired scalar Psi re-home

Date: 2026-06-18 20:33 MDT

Branch: `codex/r-bridge-grouped-dispersion`

Guard: `PR green != bridge complete != release ready != scientific coverage passed`.

## Task

Finish the narrow ordinary paired scalar-Psi replacement after the standalone
`indep(..., common = TRUE)` slice.

## What changed

- `latent()` now accepts `common = FALSE` and the parser recognizes
  `latent(0 + trait | unit, d = K, common = TRUE)`.
- The new spelling is the ordinary intercept-only replacement for legacy
  `latent(..., residual = FALSE) + unique(..., common = TRUE)`.
- Unsupported combinations fail loudly:
  `latent(..., residual = FALSE, common = TRUE)` and augmented
  `latent(1 + x | unit, d = K, common = TRUE)`.
- `tests/testthat/test-canonical-keywords.R` now checks objective equivalence,
  convergence, `diag_B` dispatch without `indep_B`, one shared fitted SD across
  traits, and both fail-loud guards.
- `NEWS.md`, `R/brms-sugar.R`, `R/unique-keyword.R`,
  `docs/design/01-formula-grammar.md`,
  `docs/design/35-validation-debt-register.md`, generated Rd files, and the
  dashboard JSON source were updated.

## Definition-of-done notes

1. Implementation: local parser/API slice implemented. Not merged to `main`.
2. Simulation / recovery evidence: focused objective-equivalence and parser
   guard tests added in `test-canonical-keywords.R`; no new likelihood or
   estimator was added.
3. Documentation: roxygen source and generated Rd updated with
   `devtools::document(quiet = TRUE)`.
4. Runnable example: keyword documentation now points new ordinary
   intercept-only scalar paired-Psi users to `latent(..., common = TRUE)`.
5. Check-log: see the 2026-06-18 20:33 MDT entry in
   `docs/dev-log/check-log.md`.
6. Review pass: this touched formula grammar only. No TMB likelihood or
   parameterization change was made. Rose boundary: source-specific and
   `kernel_*()` paired-Psi folds remain future work; no keyword removal and no
   Paper 2 multi-kernel explicit-Psi expansion is claimed.

## Checks

- `Rscript --vanilla -e 'parse("R/brms-sugar.R"); invisible(NULL)'`
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`
- `Rscript --vanilla -e 'devtools::test(filter = "canonical-keywords|unique-family-deprecation", reporter = "summary")'`
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
- `python3 -m json.tool docs/dev-log/dashboard/status.json >/dev/null && python3 -m json.tool docs/dev-log/dashboard/sweep.json >/dev/null && git diff --check`
- `rg -n "not yet re-homed|not a paired-Psi|has not yet been re-homed|paired common= was not re-homed|paired-Psi re-home" R docs/design NEWS.md man tests/testthat docs/dev-log/dashboard`
- `curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:8765/`
- `curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1:8770/`

## Explicit non-claims

- No keyword was removed.
- `part = "unique"` was not renamed.
- Source-specific `phylo_*`, `animal_*`, and `spatial_*` paired-Psi folds remain
  future work.
- `kernel_unique()` and other `*_unique()` forms remain compatibility syntax.
- Paper 2 multi-kernel coevolution remains latent-only for this arc.
- This is not bridge completion, release readiness, or scientific coverage
  completion.
