# COE-04 high-overlap Gamma extraction guard

Date: 2026-06-18 12:09 MDT

Branch: `codex/r-bridge-grouped-dispersion`

Guard: `PR green != bridge complete != release ready != scientific coverage passed`.

## Scope

This slice closes the silent extraction-side warning gap for fixed named
multi-kernel coevolution fits. Earlier slices warned during fitting when two
fixed kernel tiers had high overlap; this slice repeats the warning when a
user calls `extract_Gamma(level = ...)` for a component that participates in a
high-overlap pair.

The point `Gamma_shape` block is still returned for inspection. The warning
only changes claim discipline: high-overlap component-specific blocks are
descriptive unless lower-overlap kernels, null/sensitivity checks, or a
collapsed-tier model support a separation claim.

This is not high-overlap recovery/failure calibration.

## Files changed

- `R/extract-sigma.R`
- `man/extract_Gamma.Rd`
- `tests/testthat/test-coevolution-two-kernel.R`
- `NEWS.md`
- `docs/design/35-validation-debt-register.md`
- `docs/design/65-cross-lineage-coevolution-kernel.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/dashboard/status.json`
- `docs/dev-log/dashboard/sweep.json`

## Commands run

- `/opt/homebrew/bin/gh pr list --state open`
  -> only draft PR #489 open.
- `git log --all --oneline --since="6 hours ago"`
  -> recent commits were current mission-control/article/kernel commits.
- `git diff --check`
  -> clean before edits.
- `/usr/local/bin/Rscript --vanilla -e 'devtools::test(filter = "coevolution-two-kernel")'`
  -> `FAIL 0 | WARN 0 | SKIP 5 | PASS 47`.
- `/usr/local/bin/Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`
  -> wrote `extract_Gamma.Rd`.
- `GLLVMTMB_HEAVY_TESTS=1 /usr/local/bin/Rscript --vanilla -e 'devtools::test(filter = "coevolution-two-kernel")'`
  -> `FAIL 0 | WARN 0 | SKIP 0 | PASS 99`.
- `/usr/local/bin/Rscript --vanilla -e 'devtools::test(filter = "kernel|coevolution")'`
  -> `FAIL 0 | WARN 0 | SKIP 8 | PASS 133`.
- `GLLVMTMB_HEAVY_TESTS=1 /usr/local/bin/Rscript --vanilla -e 'devtools::test(filter = "kernel|coevolution")'`
  -> `FAIL 0 | WARN 0 | SKIP 0 | PASS 208`.

## Review perspectives

Boole: no formula grammar change was made. The warning uses the existing
`fit$kernel_diagnostics` table and the existing `level` argument.

Emmy: extractor behavior stays backward-compatible: the matrix is still
returned, and the new warning is tied to stored fit metadata rather than a new
object shape.

Gauss / Noether: no TMB likelihood or parameterisation change was made.

Fisher / Curie: high-overlap claim discipline improved, but the row remains
partial because no recovery/failure calibration grid was added.

Rose: NEWS, validation register, Design 65, dashboard, and check-log all keep
`COE-04` partial and preserve the claim guard.

## Still open

- Broader moderate-overlap calibration.
- High-overlap recovery/failure calibration beyond fit/extraction warning
  language.
- Calibrated block-null thresholds across seeds/effect sizes.
- `rho` profiling or estimation.
- Interval coverage.
- Mixed/non-Gaussian coevolution gates.
- Explicit Psi grammar redesign and `*_unique()` lifecycle/deprecation arc.
- Bridge completion, release readiness, and scientific coverage completion.
