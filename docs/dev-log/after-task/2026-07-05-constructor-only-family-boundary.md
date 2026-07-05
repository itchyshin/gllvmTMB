# After Task: Constructor-Only Family Boundary

**Branch**: `codex/r-bridge-grouped-dispersion`
**Date**: `2026-07-05`
**Roles (engaged)**: `Ada / Boole / Fisher / Curie / Grace / Rose`

## 1. Goal

Make the non-Gaussian family surface honest before further v1 completion work.
Several constructors are exported, but the current multivariate engine does not
admit them. The goal was to turn that into explicit docs and tests, not to add
new likelihood support.

## 2. Implemented

- Clarified that the family registry lists exported constructors, not automatic
  fit admission.
- Marked `gamma_mix()`, `lognormal_mix()`, `nbinom2_mix()`, `gengamma()`,
  `truncated_nbinom1()`, and `censored_poisson()` as blocked
  constructor-only surface.
- Split admitted truncated-count support into `truncated_poisson()` and
  `truncated_nbinom2()` only.
- Added roxygen/Rd wording that constructor-only families fail loudly as
  unsupported until likelihood wiring and recovery tests land.
- Added a focused test asserting the constructor-only families fail with
  `Unsupported family` before runtime admission.

## 3. Files Changed

- `R/families.R`
- `man/families.Rd`
- `tests/testthat/test-enum-runtime-ids.R`
- `docs/design/02-family-registry.md`
- `docs/design/35-validation-debt-register.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-07-05-constructor-only-family-boundary.md`

## 3a. Decisions and Rejected Alternatives

Decision: keep constructors exported but make engine admission fail-loud and
documented.

Rationale: removing constructors would be an API change. Admitting the families
would require likelihood wiring and simulation recovery. The current v1-safe
move is to stop overclaiming and guard the fail-loud behavior.

Rejected alternative: implement mixture/gengamma/truncated NB1/censored Poisson
likelihoods in this slice. That would violate the one-surface-per-PR discipline
and AGENTS.md family-addition rule without simulation recovery.

Confidence: high for the truth boundary; no new family capability was claimed.

## 4. Checks Run

```sh
Rscript --vanilla -e 'invisible(parse("R/families.R")); invisible(parse("tests/testthat/test-enum-runtime-ids.R")); cat("parse-ok\n")'
Rscript --vanilla -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-enum-runtime-ids.R")'
Rscript --vanilla -e 'devtools::document(quiet = TRUE)'
rg -n "Lognormal mixture|Gamma mixture|Generalised Gamma|Negative binomial 2 mixture|Truncated nbinom1|Censored Poisson|gamma_mix|lognormal_mix|nbinom2_mix|gengamma|censored_poisson|truncated_nbinom1" docs/design/02-family-registry.md docs/design/35-validation-debt-register.md R/families.R man/families.Rd tests/testthat/test-enum-runtime-ids.R
rg -n "mixture.*claimed|gengamma.*claimed|truncated_nbinom1.*claimed|censored_poisson.*claimed|claimed.*mixture|claimed.*gengamma|claimed.*truncated_nbinom1|claimed.*censored" docs/design R man tests/testthat
Rscript --vanilla -e 'tools::checkRd("man/families.Rd")'
Rscript --vanilla -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-enum-runtime-ids.R")'
GLLVMTMB_HEAVY_TESTS=1 NOT_CRAN=true Rscript --vanilla -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-truncated-recovery.R")'
GLLVMTMB_HEAVY_TESTS=1 NOT_CRAN=true Rscript --vanilla -e 'pkgload::load_all(".", quiet = TRUE); testthat::test_file("tests/testthat/test-matrix-truncated.R")'
python3 -m json.tool docs/dev-log/dashboard/status.json >/dev/null
python3 -m json.tool docs/dev-log/dashboard/sweep.json >/dev/null
sh tools/start-mission-control.sh --background
curl -s http://127.0.0.1:8770/status.json | python3 -m json.tool >/dev/null
curl -s http://127.0.0.1:8770/sweep.json | python3 -m json.tool >/dev/null
git diff --check
```

Results:

- Parse check: `parse-ok`.
- `test-enum-runtime-ids.R`: 9 pass before and after documentation generation.
- `devtools::document(quiet = TRUE)`: wrote `families.Rd`.
- Stale-claim audit found only intended blocked constructor-only wording.
- `tools::checkRd("man/families.Rd")` returned existing non-ASCII citation
  warnings from reference page ranges.
- Heavy `test-truncated-recovery.R`: 15 pass, 0 fail, 0 warn, 0 skip.
- Heavy `test-matrix-truncated.R`: 30 pass, 0 fail, 0 warn, 0 skip.
- Dashboard JSON and served JSON validated. The in-app browser preview at
  `http://127.0.0.1:8770/` showed the refreshed active-work row with
  `6bf0d79e`, constructor-only boundary text, and no active compute.
- `git diff --check`: clean.

## 5. Tests of the Tests

The new test would fail if any constructor-only family were silently assigned a
runtime id or accepted by `gllvmTMB()` before the validation rows are updated.
It does not test the future likelihoods, because no likelihood admission was
implemented.

## 6. Consistency Audit

Patterns:

```sh
rg -n "mixture.*claimed|gengamma.*claimed|truncated_nbinom1.*claimed|censored_poisson.*claimed|claimed.*mixture|claimed.*gengamma|claimed.*truncated_nbinom1|claimed.*censored" docs/design R man tests/testthat
```

Verdict: no stale constructor-only family claim remains in the audited files.

## 7. Roadmap Tick

Validation-debt rows `FAM-15` and `FAM-16` were updated. `FAM-18` and `FAM-19`
remain blocked.

## 7a. GitHub Issue Ledger

No GitHub issue was changed. This was found from the local validation register
and family registry.

## 8. What Did Not Go Smoothly

`tools::checkRd()` reports existing non-ASCII citation page-range warnings in
`families.Rd`. They predate this slice and were not fixed here.

## 9. Team Learning

Ada: the v1 arc needs claim-boundary fixes as much as new models.

Boole: exported constructor syntax and runtime family admission must be kept
separate in docs and tests.

Fisher: no inference claim follows from a constructor existing.

Curie: unsupported-family fail-loud behavior is now tested in the enum/runtime
guard file.

Grace: roxygen and generated Rd were synchronized.

Rose: the stale `claimed` wording is gone for blocked constructor-only
families.

## 10. Known Limitations And Next Actions

- `gamma_mix()`, `lognormal_mix()`, `nbinom2_mix()`, `gengamma()`,
  `truncated_nbinom1()`, and `censored_poisson()` are still not admitted.
- Future admission requires likelihood wiring, simulation recovery, extractor
  and prediction semantics, and validation-debt row promotion in the same slice.
- No Totoro or DRAC run is needed until a future family-admission design is
  frozen.
