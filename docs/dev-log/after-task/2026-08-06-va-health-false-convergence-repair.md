# VA multi-start false-convergence repair

## 1. Goal

Repair the production VA multi-start health gate after Arc 2 exposed stationary
`nlminb` code-1 starts that were being rejected solely by their termination
label. Keep the VA objective, likelihoods, H=7 default, Arc-2 thresholds, and
immutable campaign results unchanged.

## 2. Implemented

The engine now distinguishes optimizer termination from numerical eligibility.
A start is agreement-eligible only when its objective and full parameter vector
are finite, its analytic maximum absolute gradient is below the existing
`5e-3` health bar, and its `nlminb` code is 0 or 1. Admission still needs three
agreeing starts and now also needs a code-zero anchor in the three-lowest-start
consensus. Diagnostic output retains each raw code/message and reports strict
code-zero and eligible code-one counts separately.

The old helper selected the tightest window of any three starts. That could
admit objectives `0, 10, 10, 10` even though the best solution was outside the
agreeing cluster. The repair compares the three lowest eligible objectives. If
a code-zero solution is objective-equivalent to the best consensus member, the
code-zero solution is selected.

## 3a. Decisions and Rejected Alternatives

Blindly increasing optimizer budgets was rejected. The engine already performs
two deterministic `nlminb` polish attempts and an L-BFGS-B fallback. On the
campaign truncated-NB2 q=2 seed-12 reproduction, additional high-budget
`nlminb` and L-BFGS-B calls lowered neither code-one objective materially
(`<= 6.20e-8`, below the frozen `1e-6` agreement scale).

Code 1 was not treated as automatic success. It contributes only under the
same finite-parameter and gradient gates as code 0, cannot admit an all-code-one
consensus, and codes outside 0/1 remain ineligible. Existing Arc-2 bundles are
not relabelled; the repair is prospective and supplementary.

## 4. Files Touched

- `R/va-r3-proto.R`: start eligibility and consensus adjudication.
- `tests/testthat/test-va-r3-prototype.R`: pure-logic adversarial cases and the
  exact campaign truncated-NB2 q=2 seed-12 DGP regression.
- `docs/design/85-highdim-nongaussian-va-formal-contract.md`: current H=7/H=61
  roles and health rule.
- `docs/design/va-intervals-status.md`: health-gate wording.
- `docs/design/35-validation-debt-register.md`: VA-04 evidence and boundary.
- `docs/dev-log/check-log.md`: exact checks and outcomes.
- This after-task report.

No TMB likelihood template, family parameterisation, exported function,
roxygen block, generated Rd file, formula grammar, vignette, README, NAMESPACE,
or campaign bundle changed.

## 5. Checks Run

```sh
Rscript --vanilla -e 'devtools::test(filter="va-r3-prototype")'
# PASS: 645; FAIL/WARN/SKIP: 0/0/0.

Rscript --vanilla -e 'devtools::test(filter="(va-all-family-light-fits|va-intervals|va-routing-oracle)")'
# PASS: 320; FAIL/WARN/SKIP: 0/0/0. All 18 light cells healthy.

Rscript --vanilla -e 'devtools::test(filter="integration-fence")'
# PASS: 57; FAIL/WARN/SKIP: 0/0/0.

Rscript --vanilla /private/tmp/va-health-regression-current.R
# PASS: truncated-NB2 q=2 seed 12 admitted; 4 eligible starts, 2 code-zero,
# 2 code-one; objective range 3.393982e-7; projected variance 0.4268445.

git diff --check
# PASS.
```

The required pre-edit check found no open pull request. Recent shared-file
history contained only this VA(GH) lane's Arc 1/Arc 2 commits.

## 6. Tests of the Tests

Pure-logic tests reject a code-one start at or above the gradient threshold,
non-finite objectives/parameters, codes outside 0/1, three starts disagreeing
above `1e-6`, an all-code-one consensus, and the adversarial `0,10,10,10`
inferior cluster. The positive synthetic case uses the unrounded objectives
from the original campaign failure shape and verifies code-zero preference.

The end-to-end regression regenerates the frozen campaign DGP rather than
hand-building a fit result. It is platform-tolerant about whether `nlminb`
returns code 0 or 1, but requires all four starts to satisfy the numerical gate,
at least one strict code-zero anchor, and three-lowest objective agreement.

## 7a. Issue Ledger

No new issue was opened. This is a production repair found while completing the
authorised Design-110 Arc 2 campaign. It is not a new likelihood or estimator.

## 8. Consistency Audit

Code, tests, formal contract, interval-health wording, and validation row VA-04
now agree on the same rule: finite codes 0/1 may be numerically eligible;
three-lowest agreement and a code-zero anchor are mandatory. Existing fields
`healthy`, `healthy_starts`, and `all_starts_healthy` continue to describe gate
eligibility, while new fields expose strict/code-one counts and consensus IDs.

Gauss identified both defects: conflating a platform-sensitive code-one label
with non-stationarity and selecting the tightest arbitrary three-start cluster.
Curie specified the discriminating high-budget probe and adversarial tests.
Rose's campaign-seam review remains valid because no plan, bundle, threshold,
or adjudicator changed. Their bounded final reviews all returned PASS with no
P0/P1 finding.

## 9. What Did Not Go Smoothly

The first pure-logic numeric assertion used a rounded expected objective range;
it failed despite the correct decision. The assertion now uses the unrounded
campaign values and an explicit absolute-difference bound. This did not expose
an implementation failure.

A generic DRAC status helper initially reported an unrelated historical
campaign. The Fir campaign was then checked directly through its existing
ControlMaster socket and immutable `COMPLETE.dcf` receipts.

## 10. Known Residuals

The frozen Arc-2 DRAC campaign still runs the pre-repair revision. Its results
must be adjudicated under the predeclared rules and must not be reclassified
post hoc. A repaired-engine confirmation campaign may later measure the
prospective yield change, but it is not required to preserve the original
Arc-2 verdict.

This repair does not calibrate VA-Wald or latent posterior-SD intervals, does
not add unique Psi, and does not open multinomial or any non-scalar family.

## 11. Team Learning

Optimizer return codes are diagnostics, not estimands. A safe health gate needs
independent numerical evidence: finite parameters, a calibrated gradient bar,
cross-start objective agreement, and an anchor from a normally terminated
start. Agreement must also be tied to the best objective, otherwise a stable
inferior basin can counterfeit convergence.

## 12. Cross-Product Coverage

The pure-logic kernel covers codes 0, 1, 2, and missing codes; finite and
non-finite values; below/at-threshold gradients; agreement/disagreement;
code-zero anchoring; and inferior-cluster rejection. End-to-end gates cover the
campaign truncated-NB2 q=2 seed-12 fixture, all 18 public scalar family/link
light fits, public routing, intervals, and integration fences.

This is numerical-health evidence. It does NOT cover family-wise recovery,
H-stability, coverage calibration, unique Psi, multinomial/non-scalar families,
structured covariance providers, or replacement of the still-running Arc-2
campaign.
