# #872 two-tier flatness admission — no remedy admitted

## 1. Goal

Decide whether #872 supports a bounded release remedy or a durable fence.

## 2. Implemented

Added a private mapped-point admission harness, a capped Totoro campaign runner,
and immutable local/remote receipts. No package behavior changed.

## 3a. Decisions and Rejected Alternatives

Rejected a convergence warning, criterion, optimizer-control change, and public
claim: this grid did not validate a diagnostic threshold or remedy.

## 4. Files Touched

`dev/872-two-tier-flatness-admission.R`,
`dev/872-two-tier-flatness-campaign.R`, and the retained smoke/campaign
artifacts plus this report and plan-actual reconciliation.

## 5. Checks Run

Mapped value/gradient identities, local smoke, Totoro one-cell smoke, 120-cell
campaign, Gauss mapping review, Rose boundary review, and `git diff --check`.

## 6. Tests of the Tests

The harness initially exposed unnamed TMB gradients; assigning the authoritative
outer names made the nonstationary chain-rule probe pass. This specifically
tested the mapping check rather than weakening its threshold.

## 7a. Issue Ledger

#872 remains open and `park/research`; #851 remains separate and untouched.

## 8. Consistency Audit

Rose required—and this report now states—that the grid did not measure
multi-seed mapped objective gaps or parameter distances.

## 9. What Did Not Go Smoothly

Three high-scale small-n cells errored; all remain retained. NotebookLM imported
sources but did not return a citable answer, so it was quarantined.

## 10. Known Residuals

The one-fixture mapped gap remains open research; no multi-seed mapped-point
study, recovery study, or diagnostic threshold exists.

## 11. Team Learning

Objective equality needs named-block gradient pullbacks and a nonstationary
probe; an `OK` campaign row is not automatically a healthy fit.

## 12. Cross-Product Coverage

Covered Gaussian native Laplace only: single/nested structure × n 150/400 ×
k 1/100/5000 × ten seeds. All other families and tiers remain fenced.

## Decision

Retain #872 as **park/research**.  This arc does not admit a package warning,
new convergence criterion, optimizer-control change, or release claim.

## Exact scope and reproducibility

The campaign used commit `cd527af1`, ordinary Gaussian ML with native Laplace,
rank-1 `latent(0 + trait | site, d = 1)`, and (for the target arm) diagonal
`unique(0 + trait | site_species)`.  It varied structure (single/nested),
`n_sites` (150/400), response scale (1/100/5000), and seeds (1--10): 120
attempts in total, all retained in
`docs/dev-log/simulation-artifacts/2026-08-13-872-totoro-campaign-cells.csv`.

The mapped-point smoke independently passed the native Laplace value and
gradient identities at the fitted and non-stationary probe points; its retained
receipt is under `2026-08-13-872-smoke/`.

## Results

Totoro used 12 single-threaded workers (below the 150-core ceiling) and
returned 117/120 executable, retained `OK` cells (not all health diagnostics
were necessarily green).  All three errors occurred at `n=150, k=5000`:
one single-tier and two nested-tier cells.  Therefore failure is not confined
to the #872 nested target.

Among retained nested paired `k=1`/`k=5000` cells, B-tier covariance-norm
scale-law relative error was median 0.0066 (max 0.0102, n=8) at `n=150` and
median 0.0062 (max 0.0119, n=10) at `n=400`; W-tier errors were smaller.
These descriptive results neither establish parameter recovery nor validate a
diagnostic threshold. The grid did not test or establish a multi-seed
parameter-distance or mapped-objective-gap claim; among successfully paired
cells, covariance-norm scale-law error was small, which is insufficient to
justify a remedy.

## Boundary and next action

The earlier one-fixture 0.01-nll mapped-point gap remains a valid observation,
not a general convergence claim.  It is distinct from #851, does not cover
AGHQ, non-Gaussian, structured, source-specific, or two-latent-tier models,
and does not support issue closure.  Proposed issue action: retain #872 open
with this campaign receipt linked; no NEWS, validation-register, API, or
default change.

## Checks and deliberately not run

- Passed: local mapped-point smoke, remote one-cell smoke, 120-cell Totoro
  campaign with retained failures, independent Gauss/Rose boundary reviews.
- Not run: package checks, CI, public documentation render, or a remedy test;
  no package code changed and the evidence does not admit those steps.
