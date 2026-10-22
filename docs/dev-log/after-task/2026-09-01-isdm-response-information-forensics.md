# After Task: iJSDM response-information forensic audit

**Date:** 2026-09-01
**Branch:** `codex/isdm-response-information-forensics-20260902`
**Roles engaged:** Ada, Curie, Fisher, Rose, Grace

## 1. Goal

Explain the two `rep3` fit-health misses in the completed iJSDM
response-information campaign without changing the retained denominator,
classification, or public scope, then decide whether a successor campaign is
justified.

## 2. Mathematical contract

No public R API, likelihood, formula grammar, family, NAMESPACE, generated Rd,
vignette, or pkgdown navigation changed. The frozen health predicate remains
convergence code zero, positive-definite Hessian, finite objective/estimates,
and maximum gradient at most 0.01. This audit only reads and compares existing
records.

## 3. Findings and files

The retained 800-file Tamia archive was copied read-only to a temporary local
directory and independently scored. Focal tasks 624 and 632 match the committed
SHA-256 manifest. Their gradients are 0.01036609 and 0.01108690, ranks 49/50
and 50/50 among cell-7 `rep3` records. Their paired baselines are healthy; the
cell's largest baseline gradient is 0.00999407. Surface/covariance scores,
runtime, and memory do not give a shared recovery-failure signature.

Created:

- `dev/isdm-requalification/response-information-forensics/{PLAN.md,forensics.R,analyse.R,verify-forensics.R,RESULTS.md}`.
- `dev/isdm-requalification/response-information-forensics/evidence/` compact
  800-fit, 400-pair, focal, and decision receipts.
- `tests/testthat/test-isdm-response-information-forensics.R`.
- `.unlazy/ijsdm-response-information-forensics/GATES.md`.

Updated:

- `docs/design/35-validation-debt-register.md`.
- `docs/dev-log/check-log.md`.
- This report.

No public-facing source, help, vignette, README, NEWS, ROADMAP, or package
engine file changed.

## 4. Checks run

- Read-only Tamia archive count: 800 records; focal SHA-256 values matched the
  committed predecessor manifest.
- `Rscript --vanilla .../analyse.R`: regenerated all diagnostic tables from
  800 local read-only copies.
- `Rscript --vanilla .../verify-forensics.R integrity|table|boundary|receipt`:
  G0--G3 all passed.
- `testthat::test_file("tests/testthat/test-isdm-response-information-forensics.R")`:
  five focused expectations passed.
- Unlazy ledger: G0--G3 all met.

## 5. Tests of the tests

The initial rank oracle wrongly demanded that both focal records tie for the
single largest gradient. It failed against the actual data, which show the
expected rank-49/rank-50 pair. The corrected test requires those two ordered
upper-tail ranks, so it would reject a lone maximum or two arbitrary high
records. The health-boundary test pins 0.01000000 as eligible and 0.01000001 as
ineligible.

## 6. Consistency and documentation audit

`rg -n -i 'response-information|rep3|EVIDENCE_INCOMPLETE|NO_FRESH_CAMPAIGN_YET' README.md NEWS.md ROADMAP.md _pkgdown.yml vignettes R man`
returned no public capability claim. Internal PLAN, RESULTS, ledger, register,
check log, and this report agree: `EVIDENCE_INCOMPLETE` is unchanged and no
fresh campaign is presently justified.

## 7. Design and pkgdown

The validation register now distinguishes the supported narrow gradient-tail
observation from an unsupported component-level cause. No pkgdown or generated
help update applies.

**Roadmap tick:** N/A. This internal audit changes no public roadmap row.

## 8. GitHub issue ledger

Inspected [#943](https://github.com/itchyshin/gllvmTMB/issues/943). It is the
broader integrated-GLLVM misspecification campaign and is neither closed nor
advanced by this numerical forensic audit. No issue comment or new issue was
created.

## 9. What did not go smoothly

The first forensic verifier treated two top-ranked records as if both must tie
at rank 50. The real table exposed the error immediately; the repaired oracle
requires ranks 49 and 50. The Unlazy ledger initially ran from its own
subdirectory, so its commands could not find the repository scripts. Explicit
repository-root `CWD: ../..` repaired the ledger; no scientific calculation or
receipt changed.

## 10. Team learning

**Ada:** use a post-campaign audit to decide whether a new denominator is
warranted; do not spend new fits to conceal a missing diagnostic.

**Curie:** an exact frozen eligibility rule must stay exact even for small
gradient overruns; evidence tables must keep every returned record visible.

**Fisher:** high gradient rank alone supports a tail observation, not a causal
optimizer diagnosis or recovery claim.

**Grace:** raw evidence can remain durable on `/project` while compact,
recomputable diagnostic summaries enter Git.

**Rose:** the failed rank check and wrong Unlazy working directory both show why
independent executable gates must be allowed to fail before closeout.

## 11. Limitations and next action

The record schema does not contain component-labelled gradients or an optimizer
trace, so the cause remains unresolved. Do not launch a successor scientific
campaign yet. The next permitted work is a separately planned, non-retained
engineering qualification of the exact cell-7 fixture with component-level
gradients and termination metadata; it must show that any convergence-control
change preserves the estimand before a new campaign is proposed.
