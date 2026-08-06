# VA(GH) H=7 Arc 2 launch and adjudicator

## 1. Goal

Launch the authorised Design-110 campaign through revision-bound smoke gates on
Totoro and DRAC, then make its final 18-cell-by-two-rank verdict machinery
fail closed. This phase does not claim recovery or calibration success while
the broad campaigns remain in progress.

## 2. Implemented

Totoro passed its timed preflight and one-row binomial-logit smoke before the
frozen 5,520-row H-ladder plan launched. Fir passed isolated dependency build,
runtime preparation, timed preflight, and one-row Gaussian exact-VA smoke before
the frozen 36,000-row confirmation plan launched as 36 bounded arrays.

The campaign driver now adjudicates only the exact frozen plan cross-products.
It checksum-verifies result bundles, materialises missing planned tasks, rejects
duplicate task claims, and requires every bundle payload to match its platform's
historical Gate/runtime/preflight/plan checksum chain. It writes 36 cell-by-rank
verdict rows plus an immutable receipt from a clean committed checkout. The
receipt distinguishes data completeness from verdict success, records PASS,
FAIL, INCONCLUSIVE, and INCOMPLETE counts, and checksum-binds the adjudicator
source and complete 41,520-row input-bundle manifest.

## 3a. Decisions and Rejected Alternatives

Known failures take precedence over low eligibility so a demonstrated
degradation cannot be downgraded to INCONCLUSIVE. Infinite estimator ratios are
failures when they cross a finite threshold. Absolute VA recovery caps use all
finite completed VA seeds, while relative ratios retain paired seeds.

Calibration labels remain separate from point-route verdicts exactly as Design
110 predeclared. Family-parameter recovery remains descriptive because no
threshold was predeclared; inventing one after results begin would be post hoc.
Unique-Psi recovery is marked outside scope because this DGP fixes
`unique = FALSE`. `gllvm` remains absent: the primary comparator is the
package's own matched Laplace route.

## 4. Files Touched

- `dev/va-gh-h7-campaign/run-cell.R`: frozen-plan validation, bound bundle
  reading, reliability/recovery/stability/calibration diagnostics, 36-row
  adjudication, and structured receipt.
- `dev/va-gh-h7-campaign/README.md`: live campaign state and final adjudication
  command and scope.
- `tests/testthat/test-va-gh-h7-campaign.R`: healthy, threshold-failure,
  malformed-plan, missing/corrupt-bundle, duplicate-claim, and receipt tests.
- `docs/design/110-va-gh-h7-all-scalar-families.md`: factual Arc-2 launch state;
  no predeclared threshold changed.
- `docs/dev-log/check-log.md`: exact local and remote evidence.
- This after-task report.

No likelihood template, exported API, generated help, package-root README,
vignette, NAMESPACE, or family constructor changed.

## 5. Checks Run

```sh
NOT_CRAN=true Rscript --vanilla -e 'devtools::test(filter="va-gh-h7-campaign", reporter="summary", stop_on_failure=TRUE)'
# DONE; 0 failures.
git diff --check
# PASS.
gh pr list --state open
# No open pull requests.
git log --all --oneline --since='6 hours ago' -- docs/design/110-va-gh-h7-all-scalar-families.md docs/dev-log/check-log.md docs/dev-log/after-task/2026-08-06-va-gh-h7-arc2-scaffold-readiness.md
# Only this VA(GH) lane's commits touched these shared files.
```

Remote gates completed with exit 0: Fir dependency job `53406230`, runtime job
`53406489`, preflight job `53406772`, and smoke job `53407088`. Totoro's timed
preflight completed VA H=7 in 31.769 seconds and matched Laplace in 0.140
seconds. Both smoke bundles passed their checksum/runtime-chain verifiers.

At 2026-08-06T17:22:45Z, Totoro had 4,364/5,520 complete bundles. Fir had
2,559/36,000 complete bundles, with broad array elements running or pending and
no scheduler-failure signal in the live queue view.

## 6. Tests of the Tests

The suite replaces a valid DRAC plan row with a duplicate cross-product key
while preserving its superficial row count and marginal values; validation
rejects it. It reads an empty campaign directory and confirms both planned rows
become scheduler failures, reads a partial directory and retains one missing
row, mutates a published `result.csv` and detects the checksum failure, and
publishes two valid bundles claiming one task ID and rejects the collision.

Synthetic healthy results yield exactly 36 PASS point-route rows. Separate
fixtures exercise a reliability failure, material beta degradation, and
uncalibrated coverage. A one-bundle omission in otherwise healthy results makes
only its family/rank verdict INCOMPLETE. A valid bundle carrying the wrong plan
checksum is rejected through its payload provenance. The structured receipt
test distinguishes COMPLETE data from 36 point-route PASS verdicts and binds
both the input manifest and adjudicator checksum.

## 7a. Issue Ledger

No duplicate issue was opened. Design 110 remains the authoritative campaign
contract. The required live collision check found no open pull request and no
foreign recent edit to the shared design/dev-log files.

## 8. Consistency Audit

The runner, README, and Design 110 agree on 5,520 Totoro rows, 36,000 DRAC rows,
18 family/link cells, ranks q=2 and q=5, H=0 for exact and Laplace rows, H=7 for
DRAC quadrature VA, and the Totoro H ladder 5/7/9/15/61. The adjudicator emits
one row per cell and rank and cannot pool a failing family into a package-wide
average.

The final command requires both platforms' Gate receipt, runtime manifest, and
preflight receipt. Every payload must agree with the resulting expected chain;
the input manifest records every planned task, publication state, bundle name,
and checksum of the bundle's `COMPLETE.dcf` manifest.

Gauss identified failure-precedence, non-finite-ratio, absolute-denominator,
missing-bundle, and cross-product risks. Curie identified cross-product,
bundle-reader, family-parameter, and unique-Psi scope gaps. Each executable gap
was repaired or explicitly marked descriptive/out of scope without changing a
predeclared threshold.

## 9. What Did Not Go Smoothly

The first Fir dependency job (`53406185`) interpolated the intended isolated
library incorrectly and touched the shared library. It was cancelled after 38
seconds. The installed `units` directory and `00LOCK-sf` staging directory were
removed and their absence verified. The corrected job used literal isolated
paths and completed successfully; the shared library was not used as campaign
output.

The campaign exposed real unhealthy fits on Totoro. They remain immutable
evidence by design and are not relabelled as infrastructure failures before
cell-level adjudication. DRAC broad submission began after both platform smoke
gates while the Totoro broad plan was still running; the plans and estimands
remain independent, but their wall-clock execution overlaps.

## 10. Known Residuals

The 5,520-row Totoro and 36,000-row DRAC campaigns are incomplete. Therefore no
family/rank point-recovery, H-stability, VA-Wald calibration, or latent-SD
calibration verdict has yet been earned. The adjudicator must not run as final
evidence until both immutable plans finish or explicit missing tasks are
investigated and retained as INCOMPLETE.

Family-parameter recovery has no predeclared pass threshold. Unique-Psi,
multinomial, and other non-scalar architectures remain outside this campaign.
Cross-OS package CI is not a substitute for this compute evidence and was not
run in this phase.

## 11. Team Learning

Ada kept data completeness distinct from statistical success. Gauss's review
showed why failure precedence and denominator choice are part of the estimator
claim, not presentation details. Curie's review showed that a frozen row count
does not prove a frozen cross-product and that scope exclusions belong in the
machine-readable verdict.

The compute launch also confirmed that an isolated campaign library must be a
literal scheduler input, not a shell value that can silently expand to a shared
location. Immutable bundles made unhealthy statistical outcomes safe to retain
without conflating them with missing scheduler work.

## 12. Cross-Product Coverage

This phase covers launch and adjudication machinery for all 18 scalar
family/link cells, q=2/q=5, Totoro H=5/7/9/15/61 where quadrature applies,
DRAC H=7, matched Laplace H=0, failure retention, beta/Sigma recovery,
fixed-effect VA-Wald coverage, and rotation-aware latent posterior-SD coverage.

It does not yet establish that any Arc-2 cell passes those empirical criteria.
It does not cover unique Psi, structured covariance tiers, random slopes,
multinomial, or other non-scalar likelihoods.
