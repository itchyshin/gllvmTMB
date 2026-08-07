# After Task: VA(GH) H = 7 Arc 1 public and light closeout

**Branch**: `codex/va-gh-all-families`  
**Date**: 2026-08-06  
**Roles (engaged)**: Ada, Gauss, Curie, Rose, Grace

## 1. Goal

Promote the independently passed Design-110 Gate-E result to the public scalar
variational route: make H = 7 and Gauss-Hermite evaluation the defaults, admit
each of the 18 scalar family/link cells individually, retain explicit JJ and
non-scalar/multinomial fences, synchronise inference wording and validation
status, and close Arc 1 with local package gates.

## 2. Implemented

`gllvmTMBcontrol(integration = "va")` now defaults to `va_H = 7L`, and public
`va_eval_method = "auto"` resolves to `"gh"` for every admitted scalar cell.
Explicit `"jj"` remains available only for pure binomial-logit comparisons.
The admission fence enumerates exactly 18 `(family, link)` pairs rather than
inferring admission from a family name. Multinomial family ID 16 and every
other non-scalar/coupled response architecture fail before VA construction.

Fixed-effect `vcov()` and `confint()` are documented as uncalibrated VA-Wald
inference from profiled Schur information. `getLV(se = TRUE)` is documented as
a variational posterior SD for VA fits, not a frequentist random-effect
standard error. NEWS, the validation article, generated help, the validation
debt register, and historical design notes now state the same boundary.

### Mathematical contract

This slice does not change a likelihood or parameter transform. For
`q(u_i) = N(m_i, S_i)`, the scalar likelihood contribution remains
`E_q[log p(y_ij | eta_ij)]`, evaluated exactly for the registered analytic
cells, by the existing hybrid path for the two delta cells, and otherwise by
the existing one-dimensional Gauss-Hermite rule, now with default order
`H = 7`. The fixed-effect covariance remains
`(H_bb - H_bv H_vv^{-1} H_vb)^{-1}` and is labelled
`calibrated = FALSE`; the latent uncertainty remains `sqrt(diag(S_i))` and is
a posterior SD under the fitted variational distribution. This is not a
marginal likelihood, loading/covariance interval, nominal coverage result, or
multinomial approximation.

## 3a. Decisions and Rejected Alternatives

> **Decision:** Admit an exact 18-row family/link table.  
> **Rationale:** Binomial has three admitted links, so a one-link-per-family map
> would silently erase or over-admit cells.  
> **Rejected alternative:** Admit every family name and validate links later.  
> **Confidence:** high; exact-set and per-cell tests pass.

> **Decision:** Make public `auto` uniformly GH while retaining explicit JJ.  
> **Rationale:** Design 110's H-ladder found GH convergence while the JJ loading
> scale plateaued; Gate E then passed all 18 H7 cells independently.  
> **Rejected alternative:** Preserve the historical pure-logit JJ default.  
> **Confidence:** high for routing and light health; recovery/coverage remains
> Arc 2.

> **Decision:** Stop at Arc 1 after local closeout.  
> **Rationale:** Curie's Arc-2 audit found receipt, CLI, array-size, comparator,
> denominator, and latent-alignment defects in the campaign scaffold.  
> **Rejected alternative:** Submit the current 5,520-task plan and repair after
> launch.  
> **Confidence:** high.

## 4. Files Touched

Public routing and defaults: `R/approximation-engine.R`, `R/fit-multi.R`,
`R/gllvmTMB.R`, `R/integration-fence.R`, `R/va-r3-proto.R`, and
`R/va-routing.R`.

Uncertainty wording: `R/output-methods.R`, `man/getLV.Rd`,
`man/gllvmTMB_va-methods.Rd`, and `man/gllvmTMBcontrol.Rd`.

Tests: `tests/testthat/test-integration-fence.R`,
`tests/testthat/test-va-ac2-expectation.R`,
`tests/testthat/test-va-control-exposure.R`,
`tests/testthat/test-va-probit-adsafety.R`,
`tests/testthat/test-va-r3-prototype.R`, and
`tests/testthat/test-va-routing-oracle.R`.

Status and reader surfaces: `NEWS.md`, `_pkgdown.yml`,
`vignettes/articles/validation-oracles.Rmd`,
`docs/design/35-validation-debt-register.md`,
`docs/design/108-va-parity-programme.md`, and
`docs/design/honest-variance-component-ses.md`.

Process records: `docs/dev-log/check-log.md` and this report. The only example
source changed is the pure-R `gllvmTMBcontrol()` example in `R/gllvmTMB.R`;
all configured articles were rendered successfully. No README, ROADMAP,
formula grammar, likelihood template, NAMESPACE, or package-family constructor
changed in this slice.

## 5. Checks Run

```sh
Rscript --vanilla -e 'files <- c("R/approximation-engine.R","R/fit-multi.R","R/gllvmTMB.R","R/integration-fence.R","R/output-methods.R","R/va-methods.R","R/va-r3-proto.R","R/va-routing.R","tests/testthat/test-integration-fence.R","tests/testthat/test-va-control-exposure.R","tests/testthat/test-va-probit-adsafety.R","tests/testthat/test-va-r3-prototype.R","tests/testthat/test-va-routing-oracle.R"); for (f in files) parse(f)'
# PASS
NOT_CRAN=true Rscript --vanilla -e 'devtools::test(filter = "(integration-fence|va-control-exposure|va-routing-oracle|va-probit-adsafety)", reporter = "summary")'
# DONE; 0 failures
NOT_CRAN=true Rscript --vanilla -e 'devtools::test(filter = "va-(all-family-(oracles|compiled|light-fits)|intervals|ordination|mixed-family|missing-response|r3-prototype)", reporter = "summary")'
# DONE; 0 failures; all 18 light cells healthy
NOT_CRAN=true Rscript --vanilla -e 'devtools::test(reporter = "summary")'
# One stale AC2 test used obsolete family code 4 for binomial-probit; all other tests completed.
NOT_CRAN=true Rscript --vanilla -e 'devtools::test(filter = "va-ac2-expectation", reporter = "summary")'
# DONE after correcting the test to family ID 1 + link ID 1
Rscript --vanilla -e 'devtools::document(quiet = TRUE)'
# Completed; pre-existing unresolved internal CV-link warnings only
NOT_CRAN=true Rscript --vanilla -e 'devtools::test(filter = "va-control-exposure|integration-fence", reporter = "summary")'
# DONE after the final help-text correction; 0 failures
Rscript --vanilla -e 'pkgdown::check_pkgdown()'
# PASS after registering two previously missing exported topics
Rscript --vanilla -e 'pkgdown::build_articles(lazy = FALSE)'
# All configured articles rendered; final sandbox cache-write warning only
Rscript --vanilla -e 'devtools::check(args = "--no-manual", quiet = TRUE, error_on = "never")'
# 0 errors, 0 warnings, 2 environmental notes: remote clock verification and xcrun_db temp detritus
git diff --check
# PASS
```

Rendered-Rd spot checks found one intended `\\keyword{internal}` in
`man/getLV.Rd` and zero keyword tags in the other two regenerated topics.

## 6. Tests of the Tests

The 18-row exact-set test is a boundary test: it fails on a missing, duplicate,
or newly over-admitted cell. It pairs all 18 acceptance cases with invalid-link,
multinomial, rank, response-count, sample-size, Psi, and Julia-engine refusals.
The public probit test combines a newly admitted link with the full
`gllvmTMB()` route and asserts class, health, GH, and H = 7. The routing oracle
compares the public and direct engines under the same estimator. The AC2 repair
is failure-before-fix: code 4 now correctly selects Gamma and can no longer
masquerade as binomial-probit; the test supplies both family and link IDs.

## 7a. Issue Ledger

No relevant open issue could be verified and no new issue was created. The
required `gh pr list --state open` refresh failed because `api.github.com` was
unreachable. Local `git log --all --oneline --since="6 hours ago"` showed no
foreign lane touching this subject. Arc 2 is already represented by Design 110
and its campaign scaffold, so this closeout did not create a duplicate tracker.
Shannon's end-of-session coordination verdict is therefore **WARN** rather than
PASS solely because live PR/CI state could not be refreshed; local branch,
ownership, after-task coverage, and durable message-bus checks are consistent.

## 8. Consistency Audit

```sh
rg -n "va_H = 61L|default.*JJ|JJ.*default|auto.*sends.*jj|confint\\(\\).*still refuse|vcov\\(\\).*still refuse|no standard errors, no confidence intervals|binomial-logit, Poisson-log or|NOT USER-REACHABLE|not user-selectable" R/gllvmTMB.R R/va-routing.R R/output-methods.R man/gllvmTMBcontrol.Rd man/gllvmTMB_va-methods.Rd man/getLV.Rd NEWS.md vignettes/articles/validation-oracles.Rmd docs/design/35-validation-debt-register.md docs/design/108-va-parity-programme.md docs/design/honest-variance-component-ses.md
```

Verdict: remaining JJ-default hits are explicitly labelled historical in Design
108, the validation register, or the router's superseded Gate-3 rationale; no
current public surface retains the old default or blanket uncertainty refusal.

```sh
rg -n "multinomial|non-scalar|family_id.?16|family code 4|family_code = 4L" R/integration-fence.R R/va-routing.R tests/testthat/test-integration-fence.R tests/testthat/test-va-ac2-expectation.R docs/design/35-validation-debt-register.md NEWS.md
```

Verdict: source, tests, NEWS, and the register consistently keep multinomial as
a separate coupled architecture; the stale AC2 family-code claim is gone.

```sh
rg -n "VA-|variational|integration = \\"va\\"|va_H|Gauss-Hermite|H = 7|H=7" README.md ROADMAP.md NEWS.md docs/dev-log/known-limitations.md docs/design/35-validation-debt-register.md _pkgdown.yml
```

Verdict: the active public claim is concentrated in NEWS and validation rows
VA-02/04/06/09/11/12/13; README and ROADMAP make no conflicting detailed claim.
`_pkgdown.yml` now indexes every exported topic.

Rose's final read-only audit returned **PASS** after the invalid-H hint was
corrected to call H = 61 a high-order diagnostic, `va_eval_method = "auto"`
was documented explicitly as GH for all admitted cells, generated Rd was
refreshed, and neighbouring historical-routing prose was reconciled. No public
surface blocker remains.

## 9. What Did Not Go Smoothly

Applying `air format` to the touched R files rewrote thousands of unrelated
lines because the repository is not air-formatted. The worktree had been clean
at rehydration, so only those formatter rewrites were restored and the small
substantive patch was reapplied. This should be recorded as a tool/repository
style incompatibility, not committed as noise.

The full test suite exposed a stale AC2 registry test that called family code 4
without a link ID; the live registry correctly interpreted it as Gamma. The
test was corrected to the actual `(family = 1, link = 1)` cell and passed.
`pkgdown::check_pkgdown()` also exposed two unrelated exported topics missing
from the reference index; both were added before the gate was rerun.

## 10. Known Residuals

Arc 1 establishes public reachability, independent expectation arithmetic,
compiled derivatives, and light-fit health. It does not establish multi-seed
point recovery, nominal fixed-effect coverage, latent-posterior-SD calibration,
or family equivalence with gllvm/Laplace. The public fence still requires
`unique = FALSE`, `q <= 2`, `p <= 80`, `n >= 100`, one ordinary unit-tier
latent block, and the native TMB engine. Multinomial, structured tiers, random
slopes, additional tiers, missing predictors, and calibrated loading/covariance
intervals remain outside this claim.

The next action is a fresh Arc-2 task that first repairs and tests the campaign
scaffold, then performs one-row Totoro and DRAC smokes before broad submission.
Family verdicts must remain independent, failures must remain in denominators,
Tweedie power and Student df must match the Laplace comparator, and latent-score
assessment must be rotation-aware.

## 11. Team Learning

**Ada** kept Gate E, public promotion, and the remote campaign as separate
irreversibility boundaries. The full local gate was allowed to finish before
Arc 2 work began, which prevented a campaign launch from hiding a packaging
regression.

**Gauss** independently verified that H, evaluator, exact/hybrid routes,
fixed-effect Schur covariance, and latent-posterior-SD labels agree with the
runtime. The key remaining numerical risk is calibration, not a silent model
substitution in Arc 1.

**Curie** confirmed all 18 arithmetic/compiled/light cells and identified the
Arc-2 scaffold defects that make immediate submission unsafe. Future campaign
reviews should dry-run the documented command, not merely parse the scripts.

**Rose** caught stale generated help and uncertainty wording before promotion.
The later full-package run caught the neighbouring stale AC2 family-code test,
illustrating the Rose principle: registry changes require searching every
consumer of both family and link IDs.

**Grace** supplied the package envelope: generated documentation, reference
index, full article rendering, and `R CMD check`. The two check notes are local
environment notes, not package errors or warnings.

## 12. Cross-Product Coverage

This Arc covers public scalar VA dispatch across the 18 registered family/link
cells, H = 7, automatic GH evaluation, explicit JJ comparison, fixed-effect
VA-Wald availability, latent posterior-SD labelling, dense response masks, and
thin mixed-family plumbing under the existing ordinary unit-tier fence. It
does NOT cover multinomial or other coupled likelihoods, `unique = TRUE`,
structured covariance providers, multiple tiers, random slopes, `mi()`
predictors, `q >= 3`, small samples, recovery/coverage campaigns, cross-OS CI,
or remote-compute execution.
