# After-task report: gllvmTMB_wide default latent cleanup

Date: 2026-06-18 21:51 MDT

Branch: `codex/r-bridge-grouped-dispersion`

Guard: `PR green != bridge complete != release ready != scientific coverage passed`.

## Scope

This slice removed one active ordinary `unique()` teaching path from the
soft-deprecated `gllvmTMB_wide()` matrix wrapper. The wrapper now builds its
default long-format formula with ordinary `latent()` alone, relying on the
current default diagonal Psi companion instead of appending explicit
`unique(0 + trait | site)`.

This is compatibility cleanup only. It does not remove `unique()`, change the
legacy compatibility parser, fold source-specific/kernel latent tiers, rename
`part = "unique"`, or expand Paper 2 multi-kernel coevolution.

## Files touched

- `R/gllvmTMB-wide.R`
- `tests/testthat/test-gllvmTMB-wide.R`
- `tests/testthat/test-wide-weights-matrix.R`
- `tests/testthat/test-weights-unified.R`
- `docs/dev-log/check-log.md`
- `docs/dev-log/dashboard/status.json`
- `docs/dev-log/dashboard/sweep.json`

## Validation

- `Rscript --vanilla -e 'parse("R/gllvmTMB-wide.R"); parse("tests/testthat/test-gllvmTMB-wide.R"); parse("tests/testthat/test-wide-weights-matrix.R"); parse("tests/testthat/test-weights-unified.R")'`
  passed.
- `rg -n 'default formula includes `unique\\(0 \\+ trait \\| site\\)`|latent\\(0 \\+ trait \\| site, d = 1\\) \\+\\s*unique\\(0 \\+ trait \\| site\\)|" \\+ unique\\(0 \\+ trait \\| site\\)"|unique\\(0 \\+ trait \\| site\\)' R/gllvmTMB-wide.R tests/testthat/test-gllvmTMB-wide.R tests/testthat/test-wide-weights-matrix.R tests/testthat/test-weights-unified.R man/gllvmTMB_wide.Rd`
  returned no hits.
- `Rscript --vanilla -e 'devtools::test(filter = "gllvmTMB-wide|wide-weights-matrix|weights-unified|unique-family-deprecation", reporter = "summary")'`
  passed.
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'` passed.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'` passed with
  `No problems found.`
- `python3 -m json.tool docs/dev-log/dashboard/status.json >/dev/null && python3 -m json.tool docs/dev-log/dashboard/sweep.json >/dev/null`
  passed.
- `git diff --check` passed.

## Definition-of-done notes

1. Implementation: local only on the active #489 branch; not merged.
2. Simulation recovery: not applicable to this wrapper-syntax cleanup; no new
   likelihood, family, keyword, or estimator was added.
3. Documentation: roxygen regenerated; no user-facing example text changed in
   this slice.
4. Runnable example: existing wrapper and weight tests exercise the generated
   formula path.
5. Check-log: appended in `docs/dev-log/check-log.md`.
6. Review pass: Boole-style formula-surface check is the relevant lens here;
   no likelihood or TMB plumbing changed.

## Still guarded

- `unique()` remains compatibility syntax.
- `kernel_unique()` and source-specific `*_unique()` are not expanded for Paper
  2 coevolution.
- Coevolution remains `COE-04 partial`.
- Bridge completion, release readiness, and scientific coverage are not
  claimed.
