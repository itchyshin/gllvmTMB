# #872 two-tier flatness admission — no remedy admitted

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
