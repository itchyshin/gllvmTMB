# After Task: M3.3a nbinom2 Target-Construction Audit

**Branch**: `codex/m3-3a-nbinom2-target-audit-2026-05-19`
**Date**: `2026-05-19`
**Roles (engaged)**: `Ada / Curie / Fisher / Grace / Rose`

## 1. Goal

Inspect the `nbinom2` `Sigma_unit_diag` target path after the r10
stress pilot showed mostly successful fits and bootstrap refits but
zero coverage in the low-dispersion 120-unit scenario.

## 2. Implemented

The source audit found a scale mismatch. M3 truth used
`truth$diag_Sigma = diag(Lambda Lambda^T + Psi)`, but the runner and
bootstrap extractor used the default `link_residual = "auto"` scale,
which adds the family/link residual variance to non-Gaussian trait
diagonals.

This lane:

- added `link_residual = c("auto", "none")` to `bootstrap_Sigma()`;
- appended the new argument after `keep_draws` so old positional calls
  that pass `seed` as argument six still work;
- forwarded `link_residual` through `bootstrap_Sigma()` point
  estimates and bootstrap refit summaries;
- forwarded the same convention from
  `extract_correlations(method = "bootstrap")` and
  `extract_communality(method = "bootstrap")`;
- changed `dev/m3-grid.R` so the M3 `Sigma_unit_diag` target uses
  `link_residual = "none"`;
- recorded the corrected convention in NEWS, Rd, and design docs;
- created the audit note
  `docs/dev-log/audits/2026-05-19-m3-3a-nbinom2-target-construction-audit.md`.

## 3. Files Changed

- `R/bootstrap-sigma.R`
- `R/extract-correlations.R`
- `R/extractors.R`
- `dev/m3-grid.R`
- `tests/testthat/test-bootstrap-Sigma.R`
- `tests/testthat/test-m1-8-bootstrap-mixed-family.R`
- `NEWS.md`
- `man/bootstrap_Sigma.Rd`
- `docs/design/06-extractors-contract.md`
- `docs/design/44-m3-3-inference-replacement.md`
- `docs/dev-log/audits/2026-05-19-m3-3a-nbinom2-target-construction-audit.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-05-19-m3-3a-nbinom2-target-audit.md`

No examples or vignettes were touched. `_pkgdown.yml` was checked and
already contains `bootstrap_Sigma`; no reference-index change was
needed.

## 3a. Mathematical Contract

The M3 `Sigma_unit_diag` target is:

```text
truth:    diag(Lambda Lambda^T + Psi)
estimate: diag(extract_Sigma(fit, level = "unit",
                             link_residual = "none")$Sigma)
CI:       diag(bootstrap_Sigma(fit, level = "unit",
                               what = "Sigma",
                               link_residual = "none") interval)
```

`link_residual = "auto"` remains the default public extraction
convention for marginal latent response variance. It is not the right
scale for the DGP target above.

## 3b. Decisions and Rejected Alternatives

The new argument was added to `bootstrap_Sigma()` rather than hard
coding the M3 runner because the same scale convention already exists
on `extract_Sigma()`, `extract_correlations()`, `extract_ICC_site()`,
and `extract_communality()`. Bootstrap summaries should be able to
match those extractor conventions.

I rejected inserting `link_residual` before `seed` in the formal list.
That would have broken existing positional calls such as
`bootstrap_Sigma(fit, 3, "unit", "Sigma", 0.95, 123)`.

## 4. Checks Run

- `gh pr list --state open --limit 20`
  -> no open PRs at branch start.
- `git log --all --oneline --since="6 hours ago"`
  -> recent main/PR activity reviewed before editing shared docs.
- `air format R/bootstrap-sigma.R R/extractors.R dev/m3-grid.R tests/testthat/test-bootstrap-Sigma.R tests/testthat/test-m1-8-bootstrap-mixed-family.R`
  -> formatting completed.
- `air format R/extract-correlations.R`
  -> formatting completed.
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`
  -> regenerated `man/bootstrap_Sigma.Rd`.
- `tail -5 man/bootstrap_Sigma.Rd && grep -c '^\\keyword' man/bootstrap_Sigma.Rd`
  -> tail displayed the example close; grep count was `0` as expected
  for this non-internal Rd topic.
- `Rscript --vanilla -e 'devtools::test(filter = "bootstrap-Sigma")'`
  -> `[ FAIL 0 | WARN 0 | SKIP 0 | PASS 39 ]`.
- `Rscript --vanilla -e 'devtools::test(filter = "m1-8-bootstrap-mixed-family")'`
  -> `[ FAIL 0 | WARN 0 | SKIP 0 | PASS 31 ]`.
- `Rscript --vanilla -e 'devtools::test(filter = "m1-4-extract-correlations-mixed-family|m1-5-extract-communality-mixed-family")'`
  -> `[ FAIL 0 | WARN 2 | SKIP 0 | PASS 57 ]`. The two warnings are
  pre-existing legacy `B` alias warnings inside the profile-path test,
  not the new bootstrap forwarding path.
- M3 direct smoke using `devtools::load_all(".")`, `source("dev/m3-grid.R")`,
  `m3_run_cell(family = "nbinom2", d = 1, n_reps = 1, n_boot = 3,
  targets = "Sigma_unit_diag")`
  -> finite estimates and CIs for all five traits, `n_boot_failed = 0`,
  and `m3 bootstrap target smoke ok`.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> `No problems found`.
- `Rscript --vanilla -e 'devtools::check(args = "--no-manual", quiet = TRUE)'`
  -> 0 errors, 1 warning, 4 notes. The warning is the local Apple
  clang/R header warning
  `R_ext/Boolean.h: unknown warning group '-Wfixed-enum-extension'`.
  Notes were existing top-level `air.toml` / ignored `Rplots.pdf`,
  NEWS headings, unused `nlme` import, and base-function namespace
  notes for `setNames` / `modifyList`.
- `git diff --check`
  -> clean.

## 5. Tests of the Tests

The new positional-compatibility test is a regression guard: it would
fail if `link_residual` were inserted before `seed`.

The mixed-family `link_residual` bootstrap test is a feature-combination
test: mixed-family fit plus bootstrap refit plus link-residual scale
choice. It compares `bootstrap_Sigma()` point estimates directly to
`extract_Sigma(..., link_residual = "auto")` and
`extract_Sigma(..., link_residual = "none")`, and checks that at least
one non-Gaussian diagonal is larger under `"auto"`.

The M3 smoke is an integration test of the corrected runner path. It
does not validate coverage; it only confirms that the corrected target
path returns finite estimates and bootstrap intervals.

## 6. Consistency Audit

Exact scans run:

- `rg -n 'link_residual|Sigma_unit_diag|truth\\$diag_Sigma|Lambda\\\\Lambda|CI-08|CI-10|EXT-13|MIX-08|MIX-09' NEWS.md R/bootstrap-sigma.R R/extractors.R R/extract-correlations.R dev/m3-grid.R docs/design/06-extractors-contract.md docs/design/44-m3-3-inference-replacement.md man/bootstrap_Sigma.Rd tests/testthat/test-bootstrap-Sigma.R tests/testthat/test-m1-8-bootstrap-mixed-family.R`
  -> touched files consistently name `link_residual`, the corrected
  `Sigma_unit_diag` convention, and the scope rows.
- `rg -n 'bootstrap_Sigma' _pkgdown.yml R/bootstrap-sigma.R man/bootstrap_Sigma.Rd NEWS.md docs/design/06-extractors-contract.md docs/design/44-m3-3-inference-replacement.md`
  -> `_pkgdown.yml` already lists `bootstrap_Sigma`; no export
  navigation gap.
- `rg -n 'method *=|default|fisher-z|profile|wald|bootstrap|n_boot|nsim' R NEWS.md man docs/design/06-extractors-contract.md docs/design/44-m3-3-inference-replacement.md`
  -> found two stale design-doc snippets, both corrected:
  `nsim = B` became `n_boot = B`, and the extractor table signature
  was updated.
- `rg -n 'unit_obs|unit =|trait =|cluster =|level =' NEWS.md R/bootstrap-sigma.R man/bootstrap_Sigma.Rd docs/design/06-extractors-contract.md docs/design/44-m3-3-inference-replacement.md docs/dev-log/audits/2026-05-19-m3-3a-nbinom2-target-construction-audit.md`
  -> level naming is consistent with canonical `unit` / `unit_obs`;
  examples still pass explicit `trait =`.
- `rg '\\bS_B\\b|\\bS_W\\b|\\\\bf S' NEWS.md R/bootstrap-sigma.R man/bootstrap_Sigma.Rd docs/design/06-extractors-contract.md docs/design/44-m3-3-inference-replacement.md docs/dev-log/audits/2026-05-19-m3-3a-nbinom2-target-construction-audit.md`
  -> no stale S notation in touched public prose.
- `rg -n 'EXT-13|CI-08|CI-10|MIX-08|MIX-09|covered|partial' docs/design/35-validation-debt-register.md NEWS.md docs/dev-log/audits/2026-05-19-m3-3a-nbinom2-target-construction-audit.md`
  -> NEWS and audit map claims to MIX-08/MIX-09 covered and
  EXT-13/CI-08/CI-10 partial.

Rose verdict: PASS for the pre-publish surface. The only local check
warning is compiler-environment noise, not a public-prose or R API
inconsistency.

## 7. Roadmap Tick

No validation-debt row was promoted. EXT-13 remains
`covered (Gaussian) / partial (non-Gaussian)`, and CI-08 / CI-10 stay
partial until the corrected M3.3a target is rerun at stress-grid
scale.

## 8. What Did Not Go Smoothly

The first direct M3 smoke accidentally used the installed namespace,
so the new `bootstrap_Sigma(link_residual = ...)` argument was not
available and the runner swallowed the bootstrap error into missing CI
columns. I reran the smoke with `devtools::load_all(".")`, which is the
correct local-development path.

`air format` also reformatted surrounding code in touched files, so
the raw diff stat is larger than the semantic change. The meaningful
change is the new scale argument, forwarding path, M3 target selection,
and tests/docs around those.

## 9. Team Learning

Ada kept the lane bounded to target construction instead of launching
another larger simulation. Curie focused the tests on the failure mode
that would have caught the argument-order mistake. Fisher treated the
0.58 residual-scale coverage as remaining calibration evidence, not as
a solved problem. Grace ran pkgdown and package-check gates. Rose
checked the public-surface claims against the register and corrected
stale design-doc signatures.

## 10. Known Limitations And Next Actions

`nbinom2` bootstrap coverage is not validated yet. The next autonomous
slice should rerun the two-scenario stress grid with the corrected
target path, at roughly `n_reps = 20` and `n_boot = 20`, and record
fitted `phi`, link residual, latent + unique covariance ratios, and
bootstrap failure rates before considering the full 15-cell grid.

The local `R CMD check` warning should be interpreted alongside CI:
if GitHub's three-OS check passes, the Apple clang warning is a local
environment issue.
