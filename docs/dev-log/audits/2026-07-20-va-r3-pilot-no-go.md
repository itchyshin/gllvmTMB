# Design 85 R3 pilot audit — NO-GO

**Date:** 2026-07-20  
**Branch:** `codex/va-r3-prototype-20260720`  
**Decision:** **NO-GO; retain Laplace**

## Claim boundary

This audit decides whether the internal Gaussian-VA experiment may advance
from q=1/q=2 references to q=4/q=6 stress. It does not validate a VA estimator,
an AGHQ fitting method, non-Gaussian REML, rank selection, intervals, coverage,
or a public API.

## Evidence provenance

- Platform: Totoro, Linux, R 4.5.3; ten single-threaded workers.
- Exact pilot source commit: `0e9b3b563edb5a2a61dc9d3fe7d072a7340196a7`.
- Prototype C++ MD5: `4d5817ebf6a21e4c9a27aadf39097755`.
- Seed manifest: q1 seeds 1--25 and q2 seeds 1--25; 50/50 RDS receipts.
- Local-only evidence directory: `/private/tmp/va-r3-pilot-0e9b3b56/pilot`.
- SHA-256 of the 50-file checksum manifest:
  `6125ec3d96808bedade49f7b33f6a29bad789b0ce4688a02e9e65fc9888b1cc3`.
- SHA-256 of `pilot-summary.csv`:
  `9f632b1b616fe4a5f3b82bb97c6e68e6b639348eb915122c0399f07abfde2c55`.

The receipts remain local under the project's D-50 compute policy. No
simulation output was uploaded to GitHub Actions or committed to the package.

## Corrected classification

The original post-pilot classifier compared the range of all healthy starts.
The frozen contract requires agreement of any three of four starts. The final
helper and test correct that mismatch. q1 seed 8 is therefore healthy: its best
three objectives span `3.50e-7`, below the `1e-6` threshold. Because its old
receipt classified the fit as failed, it stores no recovery summary and cannot
be retroactively used as positive recovery evidence.

| Planted cell | Attempted | Applicable | Optimiser healthy under final contract | Rank-zero stop |
|---|---:|---:|---:|---:|
| q1 | 25 | 24 | 22 (91.7%) | 1 |
| q2 | 25 | 25 | 19 (76.0%) | 0 |

Eight applicable fits fail the predeclared optimiser gate. The stored healthy
receipts have VA elapsed-time p50/p95 of 1.421/22.602 seconds at q1 and
1.804/22.886 seconds at q2; these are descriptive, not an admitted speed claim.

## Gate-3 versus Gate-4 defect

The runner selected rank by ML before fitting VA. Selection frequencies were:

- planted q1: selected q0/q1/q2 = 1/20/4;
- planted q2: selected q1/q2/q3 = 4/20/1.

That is the Gate-4 hand-off design, not the required fixed-rank Gate-3 known-DGP
comparison. Among stored healthy same-rank rows, there were 18 q1 and 15 q2
recovery summaries and no axis collapses. Mean VA-minus-ML relative-Sigma error
was `+0.00276` at q1 and approximately `-0.00003` at q2. These conditional
descriptives do not replace the missing all-attempt fixed-rank denominator.

The previously reported q2 collapse occurred at seed 14, where ML selected q3
against planted q2. Final code records `rank_matches_truth` and reports collapse
as `NA` for rank-mismatched fits.

## Independent lenses

**Fisher/Curie:** the pilot cannot be promoted because the sequential recovery
gate was not run as declared and failed fits must remain in the denominator.

**Grace:** the receipts are admissible for negative falsification and preserve
source/platform/failure provenance, but not for a positive recovery or timing
claim because fixed-rank and selected-rank experiments were conflated.

**Noether:** the ELBO, coordinate map, Gaussian anchor, O3 comparisons, and
quadrature checks are coherent. The classifier and rank-mismatch defects were
real implementation/reporting defects; correcting them does not supply the
missing experiment.

**Rose:** the only supportable public statement is no statement: the work is
research-only, stopped before q4/q6, and must not change README, NEWS, roxygen,
the validation register, pkgdown, or release claims.

## Admission decision

**NO-GO.** Gate 3 was not established, so Gate 5 is closed. Do not run q4/q6,
100, or 500 replicates; do not tune the frozen gates after observing this
pilot. Retain Laplace-only ordinary non-Gaussian inference. Reconsider an
engine arc only if a genuinely new evidence source identifies a tractable
alternative and the maintainer approves a new formal contract.
