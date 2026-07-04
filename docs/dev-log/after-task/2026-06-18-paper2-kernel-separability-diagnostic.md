# Paper 2 kernel separability diagnostic after-task report

Date: 2026-06-18 18:03 MDT

Guard: `PR green != bridge complete != release ready != scientific coverage passed`.

## 1. Goal

Add the next narrow coevolution gate after the Paper 2 estimand audit: a
pre-fit diagnostic that screens candidate fixed kernels before fitting a
two-kernel coevolution model.

## 2. Implemented

Implemented `diagnose_kernel_separability()` as an exported helper in
`R/kernel-helpers.R`. The helper compares two or more fixed dense kernels by
off-diagonal Frobenius-style similarity, classifies each pair as
`near_orthogonal`, `moderate`, or `high`, and returns a conservative
recommendation. The key Paper 2 claim boundary is explicit: a raw/aliased
`K_tip` candidate is flagged as `collapse_or_single_covariance`, while a
residualized/opposed candidate can be a `separable_candidate`.

Mathematical contract:

```text
similarity(K_1, K_2) =
  <offdiag(K_1), offdiag(K_2)> /
  (||offdiag(K_1)|| ||offdiag(K_2)||)
```

This does not change the likelihood, TMB parameterisation, formula grammar,
family code, or fitted model. It is a diagnostic for fixed kernels, not a
formal identifiability proof, `rho` estimator, interval method, or scientific
coverage claim.

## 3. Files Changed

- `R/kernel-helpers.R`: added `diagnose_kernel_separability()` and small
  helper functions.
- `tests/testthat/test-coevolution-two-kernel.R`: added the raw/aliased versus
  residualized/opposed separability test and failure-path checks.
- `NAMESPACE`: exported `diagnose_kernel_separability`.
- `man/diagnose_kernel_separability.Rd`: generated help topic.
- `_pkgdown.yml`: registered the new reference topic.
- `NEWS.md`: added a bounded development-note entry under the fixed
  multi-kernel section.
- `docs/design/65-cross-lineage-coevolution-kernel.md`: recorded the pre-fit
  separability gate while keeping COE-04 partial.
- `docs/design/35-validation-debt-register.md`: updated COE-04 evidence and
  open gates.
- `docs/dev-log/audits/2026-06-18-paper2-coevolution-estimand-gate.md`: created
  the preceding estimand audit.
- `docs/dev-log/check-log.md`, `docs/dev-log/dashboard/status.json`, and
  `docs/dev-log/dashboard/sweep.json`: recorded the slice and live status.

No example cascade was required for an argument rename or syntax default
change. The new helper has its own roxygen example and pkgdown reference entry.

## 3a. Decisions and Rejected Alternatives

I did not implement residualization of `W` itself. The Paper 2 note leaves the
definition of `W_hat_phy` as a theoretical choice, so this slice only compares
candidate kernels after they have been built. That keeps the diagnostic useful
without prematurely choosing the empirical residualization rule.

I did not expand `kernel_unique()` or `*_unique()` for Paper 2. Those remain
compatibility syntax only.

## 4. Checks Run

- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`
  -> regenerated `NAMESPACE` and `man/diagnose_kernel_separability.Rd`.
- `Rscript --vanilla -e 'devtools::test(filter = "coevolution-two-kernel|coevolution-recovery", reporter = "summary")'`
  -> first run failed because a validation `lapply()` stripped kernel names
  before the pair table was built.
- Fixed the helper with `stats::setNames()`.
- `Rscript --vanilla -e 'devtools::test(filter = "coevolution-two-kernel|coevolution-recovery", reporter = "summary")'`
  -> passed with 13 expected heavy skips.
- `Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); A <- diag(2); rownames(A) <- colnames(A) <- c("H1", "H2"); B <- diag(2); rownames(B) <- colnames(B) <- c("P1", "P2"); W <- matrix(c(1, .2, .2, 1), 2, 2, dimnames = list(rownames(A), rownames(B))); K <- make_cross_kernel(A, B, W, rho = .5); dx <- diagnose_kernel_separability(phy = K, tip = K); print(dx$pairs)'`
  -> returned high overlap with `collapse_or_single_covariance`.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> first run failed because the new topic was missing from `_pkgdown.yml`;
  after adding it, rerun returned `No problems found.`
- `python3 -m json.tool docs/dev-log/dashboard/status.json >/dev/null && python3 -m json.tool docs/dev-log/dashboard/sweep.json >/dev/null && git diff --check`
  -> passed.
- `tail -5 man/diagnose_kernel_separability.Rd && grep -c '^\\keyword' man/diagnose_kernel_separability.Rd`
  -> showed the example footer and `0` keyword lines.
- `rsync -a docs/dev-log/dashboard/ /tmp/gllvm-dashboard/`
  plus `curl` checks against `http://127.0.0.1:8770/status.json` and
  `sweep.json`
  -> live dashboard contains the pre-fit separability status.

## 5. Tests of the Tests

The new test is a boundary test. It intentionally compares a raw/aliased
`K_tip` candidate against `K_phy` and expects the high-overlap recommendation
`collapse_or_single_covariance`. It also checks an opposed/residualized
candidate that remains `near_orthogonal`, plus failure paths for too few
kernels and duplicate names.

The first failing test run caught a real bug: kernel names were lost during
validation. The passing rerun confirms the pair table now preserves user-facing
kernel names.

## 6. Consistency Audit

Exact scans:

- `rg -n "diagnose_kernel_separability|export\\(diagnose_kernel_separability\\)|kernel separability|one network-conditioned covariance" NAMESPACE man/diagnose_kernel_separability.Rd R/kernel-helpers.R tests/testthat/test-coevolution-two-kernel.R`
  -> confirmed export, Rd, helper, and tests.
- `rg -n "diagnose_kernel_separability|collapse_or_single_covariance|separable_candidate|kernel-collinearity|formal identifiability|scientific coverage" README.md NEWS.md R tests/testthat man docs/design docs/dev-log/dashboard _pkgdown.yml`
  -> confirmed the new helper and bounded claims in active source/docs; hits
  for scientific coverage are guard text and open-gate wording.
- `rg -n "\\bS_B\\b|\\bS_W\\b|\\\\bf S" R/kernel-helpers.R NEWS.md docs/design/65-cross-lineage-coevolution-kernel.md docs/design/35-validation-debt-register.md docs/dev-log/check-log.md man/diagnose_kernel_separability.Rd tests/testthat/test-coevolution-two-kernel.R`
  -> no new touched-surface notation drift; historical check-log hits are old
  command records.
- `rg -n "kernel_unique\\(\\).*Paper 2|Paper 2.*kernel_unique\\(\\).*support|scientific coverage passed|release ready" NEWS.md docs/design/65-cross-lineage-coevolution-kernel.md docs/design/35-validation-debt-register.md docs/dev-log/dashboard/status.json docs/dev-log/dashboard/sweep.json R/kernel-helpers.R man/diagnose_kernel_separability.Rd`
  -> confirmed the active wording keeps `kernel_unique()` compatibility-only
  and preserves the guard.

## 7. Roadmap Tick

No `ROADMAP.md` row was changed. The validation-debt row changed instead:
`COE-04` remains `partial` and now names the pre-fit separability diagnostic.

## 8. What Did Not Go Smoothly

The first focused test run failed because the helper stripped names from the
validated kernel list. `pkgdown::check_pkgdown()` also failed once because the
new exported topic was missing from `_pkgdown.yml`. Both failures were local
and fixed before closeout.

## 9. Team Learning

Ada: kept the slice narrow after the larger Paper 2 note. The useful move was
not another recovery grid, but a diagnostic that prevents overclaiming the
`Gamma_phy` / `Gamma_tip` split.

Boole: the helper API takes named kernels directly, so users can reuse the
same objects they intend to pass to `kernel_latent(..., K = ..., name = ...)`.

Curie and Fisher: the test is a boundary gate, not calibration. Formal
kernel-collinearity simulations are still required before scientific
promotion.

Grace: `pkgdown::check_pkgdown()` caught the missing reference-index entry
locally. That failure was exactly the right kind of cheap friction.

Rose: the design, NEWS, validation-debt row, check-log, and dashboard all say
the same thing: diagnostic added, COE-04 still partial.

## 10. Known Limitations and Next Actions

- Formal kernel-collinearity simulations beyond this pre-fit diagnostic remain
  open.
- No in-engine `rho` estimation or `rho` profile intervals were added.
- No `Gamma` interval calibration was added.
- No standardized `R_l` plus SVD module extractor was added.
- No `kernel_unique()` / `*_unique()` expansion for Paper 2 multi-kernel
  coevolution was added.
- Next coevolution step, if continuing this lane, is a formal
  raw-`W` versus residualized-`W_tip` simulation design and threshold rule.
