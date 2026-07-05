# After Task: Derived Phylogenetic CI Audit

**Branch**: `codex/r-bridge-grouped-dispersion`
**Date**: `2026-07-04`
**Roles (engaged)**: `Ada / Fisher / Noether / Curie / Grace / Rose / Shannon`

## 1. Goal

Use Ayumi-495/avian_trait_scales#14 as the first real-world route audit for the
derived-profile surface. The practical target was to stop three-tier
phylogenetic fits from returning no interval for key derived quantities when an
admitted fallback or tier route exists.

## 2. Implemented

- `profile_ci_phylo_signal()` still profiles the simple two-component ratio,
  but richer 3+ component fits now return numerical delta-method Wald bounds
  via `.phylo_signal_wald_ci()` and label them `wald(numeric)`.
- `extract_communality()`, `profile_ci_communality()`, the scalar Wald and
  bootstrap helpers, and the `confint(..., parm = "communality:phy:<trait>")`
  token path now admit phylogenetic-tier communality.
- `bootstrap_Sigma()` summary collection now records `communality_phy` when
  requested.
- The Ultra-Plan now includes a derived-CI route matrix gate so future audits
  test `profile_ci_*()`, extractor `ci = TRUE`, `confint(parm = ...)`, and
  bootstrap collectors together.
- Validation-debt rows now avoid overclaiming: true 3+ component
  phylogenetic-signal profile-LR remains planned, not covered.

## 3. Files Changed

R code:

- `R/profile-derived.R`
- `R/extractors.R`
- `R/communality-ci.R`
- `R/bootstrap-sigma.R`
- `R/z-confint-gllvmTMB.R`
- `R/extract-omega.R`

Tests:

- `tests/testthat/test-derived-phylo-ci-audit.R`

Docs and evidence:

- `man/confint.gllvmTMB_multi.Rd`
- `man/extract_communality.Rd`
- `man/extract_phylo_signal.Rd`
- `man/profile_ci_communality.Rd`
- `man/profile_ci_phylo_signal.Rd`
- `docs/design/06-extractors-contract.md`
- `docs/design/35-validation-debt-register.md`
- `docs/dev-log/while-away/2026-07-04-gllvmtmb-completion-ultra-plan.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-07-04-derived-phylo-ci-audit.md`

## 3a. Decisions and Rejected Alternatives

Decision: do not claim true multi-component profile-LR for phylogenetic signal.

Rationale: the fix-and-refit target is a real future method slice. The existing
numeric-Wald helper is already tested and gives useful bounds now.

Rejected alternative: leave `profile_ci_phylo_signal()` as point-only on 3+
component fits.

Reason rejected: the package already had a better fallback, and the old
message said `wald(approx)` while returning `NA` bounds.

Confidence: high for route consistency; moderate for interval quality because
calibration remains a separate CI-08 / CI-10 question.

## 4. Checks Run

```sh
Rscript --vanilla -e 'invisible(parse("R/profile-derived.R")); invisible(parse("R/extractors.R")); invisible(parse("R/communality-ci.R")); invisible(parse("R/bootstrap-sigma.R")); invisible(parse("R/z-confint-gllvmTMB.R")); invisible(parse("R/extract-omega.R")); invisible(parse("tests/testthat/test-derived-phylo-ci-audit.R")); cat("parse-ok\n")'
```

Outcome: passed.

```sh
Rscript --vanilla -e 'devtools::document(quiet = TRUE)'
```

Outcome: passed; regenerated the expected Rd files, with existing unrelated
unresolved-link warnings.

```sh
GLLVMTMB_HEAVY_TESTS=1 NOT_CRAN=true Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-derived-phylo-ci-audit.R", reporter = "summary")'
```

Outcome: passed.

```sh
GLLVMTMB_HEAVY_TESTS=1 NOT_CRAN=true Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-phylo-signal-ci.R", reporter = "summary")'
```

Outcome: passed with the known conditional-simulation warning.

```sh
GLLVMTMB_HEAVY_TESTS=1 NOT_CRAN=true Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-bootstrap-Sigma.R", reporter = "summary")'
```

Outcome: passed with the expected `{future}` skip.

```sh
GLLVMTMB_HEAVY_TESTS=1 NOT_CRAN=true Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); testthat::test_file("tests/testthat/test-communality-ci.R", reporter = "summary")'
```

Outcome: passed.

```sh
git diff --check
```

Outcome: passed.

## 5. Tests of the Tests

`test-derived-phylo-ci-audit.R` builds a three-tier Gaussian fit with a
phylogenetic latent+unique tier, a non-phylogenetic species latent+unique tier,
and a within-observation latent+unique tier. It checks the exact failure shape
from Ayumi #14: multi-component phylogenetic signal returns finite fallback
bounds, `communality:phy` routes through extractor/profile/confint, and the
bootstrap summary collector stores `communality_phy`.

## 6. Consistency Audit

```sh
rg -n "wald\\(approx\\)|point estimates with method|profile-only;|Profile-only|communality.*unit_obs.*B.*W|Communality tiers:.*unit.*unit_obs" R man docs/design tests/testthat -S
```

Verdict: no stale phylogenetic-signal empty-fallback wording remains. Remaining
profile-only hits are expected `proportion` wording.

## 7. Roadmap Tick

Phase 1 inference-safety now includes a derived-CI route matrix gate. CI-05 was
narrowed from blanket covered to partial for true 3+ profile-LR.

## 7a. GitHub Issue Ledger

- External issue used as the audit trigger:
  <https://github.com/Ayumi-495/avian_trait_scales/issues/14>
- No GitHub issue was closed from this local slice.

## 8. What Did Not Go Smoothly

The heavy `test-confint-derived.R` file is too slow for inner-loop work because
it walks existing profile branches. It was interrupted after several minutes
with no observed failure. The new route-specific file is the faster guard.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

Ada kept the repair tied to the reported user pain rather than expanding into a
full profile-method rewrite.

Fisher separated useful fallback uncertainty from calibrated profile-LR claims.

Noether clarified that `communality:phy` is a phylogenetic-tier shared fraction,
not whole-model phylogenetic signal.

Curie added a small three-tier regression fixture rather than relying on a
large applied model.

Grace regenerated Rd files and kept remote compute idle.

Rose narrowed the validation-debt claim for CI-05.

Shannon kept this as a local repair and did not close external issue state.

## 10. Known Limitations And Next Actions

- True 3+ component phylogenetic-signal profile-LR remains planned.
- Derived-CI matrix audit should continue across `icc`, `rho`, `proportion`,
  spatial, mixed-family, and non-Gaussian rows.
- CI-08 / CI-10 calibration rows remain separate and unchanged.
- No Totoro or DRAC compute was launched.
