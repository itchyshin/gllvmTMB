# After Task: Public-route iJSDM point-prediction repair

**Branch**: `codex/isdm-evidence-map-closure`
**Date**: `2026-08-29`
**Roles (engaged)**: Ada, Boole, Emmy, Curie, Fisher, Pat, Rose, Grace

## 1. Goal

Repair the public `gllvmTMB(..., family = isdm_sources(...))` prediction path
that failed the frozen training-row identity oracle, harden the retained
requalification harness, and reconcile the capability record before freezing a
claim-bearing source. This phase creates no pre-run or production attempt.

## 2. Implemented

- Integrated-source fits retain the exact source-observation model-matrix
  basis: terms, factor levels, contrasts, complete columns, and fitted columns.
- `predict()` rebuilds each source block on that frozen basis, keeps absent
  sources neutral, checks unseen values only on rows where the source is active,
  and requires a known source label for every `isdm_sources()` new-data row.
- Training identity, per-row inverse-link dispatch, response-free prediction,
  changed global contrasts, serialized fits, aliased columns, separator-bearing
  source labels, two/three sources, and all-missing source-by-trait refusal have
  dedicated public-route tests.
- Harness availability gates are target- and overlap-specific. Spatial
  deterministic oracles use every eligible fit. Uncertainty timing either
  exercises the registered 1,000-draw marginal route or retains a typed
  unavailable record.
- NEWS, Designs 120/126/127, the validation register, the developer README,
  stale test commentary, and the Warbler article now agree on the narrow point
  capability and the still-owed held-out and interval evidence.

No likelihood, family, formula keyword, TMB parameterization, exported helper,
or map-interval API changed.

## 3. Mathematical Contract

For source `s` and row `i`, prediction reconstructs the fitted observation
design `Z_s(x_i)` on the training terms/levels/contrasts basis and adds
`I(source_i = s) Z_s(x_i) gamma_s` to the ecological linear predictor. An
inactive source block is exactly zero. The row's registered source law supplies
the inverse link. This repair changes reconstruction and validation only; the
fitted likelihood, ecological DGP, covariance packing, and score identity are
unchanged.

## 4. Files Touched

Implementation:

- `R/fit-multi.R`
- `R/isdm-sources.R`
- `R/methods-gllvmTMB.R`

Harness and receipt:

- `dev/isdm-requalification/README.md`
- `dev/isdm-requalification/campaign.R`
- `dev/isdm-requalification/summarise.R`
- `dev/isdm-requalification/2026-08-29-training-identity-repair-receipt.md`

Tests:

- `tests/testthat/test-isdm-predict.R`
- `tests/testthat/test-isdm-requalification-campaign.R`
- `tests/testthat/test-isdm-requalification-prediction.R`
- `tests/testthat/test-isdm-requalification-summary.R`

Truth and reader surfaces:

- `NEWS.md`
- `docs/design/120-multi-source-isdm-contract.md`
- `docs/design/126-isdm-prediction-api.md`
- `docs/design/127-isdm-prediction-map-implementation.md`
- `docs/design/35-validation-debt-register.md`
- `vignettes/articles/isdm-canada-warbler.Rmd`
- `docs/dev-log/check-log.md`
- this after-task report

## 3a. Decisions and Rejected Alternatives

**Decision:** store the training source-observation basis on the fit.
**Rationale:** rebuilding under current global contrast options changes the
meaning and columns of a fitted model.
**Rejected:** infer the basis only from coefficient names; that cannot reproduce
all factor and transformed-term semantics.
**Confidence:** high, with contrast-change and serialization regressions.

**Decision:** permit an unseen source-specific factor value on rows belonging to
another source, while refusing it on the active source's rows.
**Rationale:** the inactive block is structurally zero.
**Rejected:** global factor restoration before source masking; it rejects valid
neutral rows.
**Confidence:** high.

**Decision:** split point pre-runs from uncertainty pre-runs in execution order.
The 14 point tasks belong before the point campaign; the 24 uncertainty tasks
belong only after a marginal-interval implementation lands and is requalified.
**Rejected:** time point predictions and label them uncertainty fits.
**Confidence:** high.

## 5. Checks Run

```sh
Rscript --vanilla -e 'devtools::test(filter = "isdm", stop_on_failure = TRUE)'
# PASS: 565 assertions; one deliberate heavy skip; zero failures/warnings.

Rscript --vanilla -e 'devtools::test(stop_on_failure = TRUE)'
# PASS: 18,652 assertions; 52 expected warnings; 879 skips; 0 failures.
# Duration 2,332.3 s (38m52s), an honestly retained overrun of the 30-minute estimate.

R_USER_CACHE_DIR=/private/tmp/gllvmtmb-r-cache Rscript --vanilla -e 'pkgdown::build_article("articles/isdm-canada-warbler", lazy = FALSE)'
# PASS: article rendered and HTML written.

Rscript --vanilla -e 'pkgdown::check_pkgdown()'
# PASS: no problems.

Rscript --vanilla -e 'devtools::document(quiet = TRUE)'
# PASS: three pre-existing AIC/BIC/anova S3 notices; no generated diff.

Rscript --vanilla -e 'devtools::check(args = "--no-manual", error_on = "warning", quiet = TRUE)'
# PASS in 19m52s: 0 errors, 0 warnings, 3 unrelated notes.

git diff --check
# PASS.
```

Focused counts: prediction 86, campaign 73, summary 44. The final
implementation-identical candidate package check passed in 19m52s with 0
errors, 0 warnings, and 3 unrelated notes. Rose's three subsequent prose-only
clarifications were rechecked with `document()`, `check_pkgdown()`, the Warbler
article render, and `git diff --check`; exact-final-source package coverage is
the replacement three-OS CI gate.
Manual run `33255953258` passed all three OSes at pre-repair head `7b1a281c4`;
it is retained as stale evidence and is not the final-source CI receipt.

## 6. Tests of the Tests

The training-identity regression failed before the repair with maximum error
`1.10123482841` and passes after repair with error `0`. Each adversarial finding
was reproduced before its fix: off-source unseen factor refusal, missing source
on bare laws, contrast drift, serialization drift, overlap-pooled availability,
available-only spatial oracles, and point-only uncertainty timing. Boundary
tests retain typed errors for active-source unseen levels, missing/unknown
sources, absent covariates, all-missing source-by-trait arms, and unavailable
interval routing.

## 8. Consistency Audit

Exact searches run:

```sh
rg -n 'more than two|any number of sources|not implemented|dummy response|all-NA|all-missing|held-out|0\.23|0\.82|22,200|SPDE slope|response-free' NEWS.md dev/isdm-requalification/README.md docs/design/120-multi-source-isdm-contract.md docs/design/126-isdm-prediction-api.md docs/design/127-isdm-prediction-map-implementation.md docs/design/35-validation-debt-register.md tests/testthat/test-isdm-predict.R vignettes/articles/isdm-canada-warbler.Rmd
rg -n 're_int|fixed-only|interval = "marginal"|newdata.*response' NEWS.md dev/isdm-requalification/README.md docs/design/120-multi-source-isdm-contract.md docs/design/126-isdm-prediction-api.md docs/design/127-isdm-prediction-map-implementation.md docs/design/35-validation-debt-register.md tests/testthat/test-isdm-predict.R vignettes/articles/isdm-canada-warbler.Rmd
```

Verdict: no current surface says more than two sources are unavailable, requires
a dummy response, treats fixed-only map SE as calibrated, promotes held-out
accuracy, or promotes SPDE map intervals. The `re_int` matches are unrelated
multinomial history in NEWS/register, not iJSDM wording.

## 7. Roadmap Tick

N/A. The umbrella iJSDM rows remain partial; this phase repairs and documents a
narrow existing route without broadening the roadmap claim.

## 7a. Issue Ledger

- #1132 is closed and remains the provenance issue for the point-map defect.
- #1133 remains open for map API and uncertainty.
- #1138 remains open for omitted random-effect tiers.
- #941 remains open for the broader multisource integrated-model programme.

No issue is closed by this repair because held-out recovery and uncertainty are
still owed.

## 9. What Did Not Go Smoothly

The first spatial feasibility probe exposed a real public prediction defect after fitting.
The first independent review then found six additional P1 gaps. A first article
render used the wrong pkgdown article name and an unwritable default cache; the
correct `articles/isdm-canada-warbler` route with a `/private/tmp` cache passed.
The full suite passed but took 38m52s, overrunning its 30-minute estimate. One
stale-wording shell search mistakenly used shell-active backticks; it produced
only a command-not-found message and was rerun safely with quoted patterns.

## 11. Team Learning

**Ada:** kept production denominators at zero and folded truth sync into the
repair candidate so qualification will not be invalidated immediately by a
follow-up documentation commit.

**Boole and Emmy:** required the fitted design basis—not only coefficient
names—to survive prediction, changed contrast options, and serialization.

**Curie and Fisher:** separated availability by target and overlap, required
deterministic map oracles on all eligible fits, and refused point-only timing as
uncertainty evidence.

**Pat:** retained response-free `newdata`, source/link-specific interpretation,
and plain-language limitations in the Warbler path.

**Rose:** found and reconciled stale all-missing, source-count, held-out, and
fixed-only interval statements across the capability surfaces.

**Grace:** confirmed no dependency or compiled-code change; final exact-head
and exact-main three-OS matrices remain mandatory because the prior green run is
stale.

Terminal API/method, reproducibility, and Rose pre-publish reviews returned
PASS with no unresolved P0--P2 finding. Shannon confirmed the exact-path lease
and CI pacing are sound; its merge verdict remains pending until the consolidated
candidate is pushed and replacement exact-head CI passes.

## 10. Known Residuals

This phase proves deterministic reconstruction, not point recovery. It creates
no pre-run/production denominator and no interval API. Before any campaign:

1. obtain terminal API/reproducibility and Rose/Shannon review on the final diff;
2. pass replacement exact-head three-OS CI, merge, and pass exact-main CI;
3. install and qualify that exact main source with package/DLL hashes;
4. run the 14 retained point pre-runs and make the Totoro/DRAC decision;
5. run and adjudicate the 1,800 nonspatial and 800 spatial attempts without
   replacement;
6. implement and pre-run marginal uncertainty only if the spatial point gate
   passes.

## 12. Cross-Product Coverage

This phase covers the public TMB integrated-source route on local macOS and the
stale candidate on the prior Ubuntu/macOS/Windows matrix. It does not cover the
final changed head on three OSes, Julia, structured-source latent tiers, SPDE
slopes, out-of-hull intervals, profile/bootstrap intervals, or any production
recovery/coverage denominator. The developer harness is intentionally absent
from built tarballs and must be exercised directly from the exact qualified
source on Totoro or DRAC.

## 13. Next Actions

Finish terminal reviews, commit and push one CI-paced repair, require replacement
exact-head three-OS success, merge, require exact-main success, then qualify the
installed package and DLL before starting the 14 retained point pre-runs.
