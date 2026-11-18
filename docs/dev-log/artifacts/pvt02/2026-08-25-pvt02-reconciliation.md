# PVT-02 reconciliation — route label versus calibrated cells

## Finding

The current `profile_ci_total_variance()` status predicate is intentionally
machine-readable but empirically over-broad. Its code accepts an unpenalised,
ordinary Gaussian unit-tier latent fit with `d in {1, 2}`, `n_units >= 150`,
two-sided level 0.95, and convergence. Its focused export test explicitly
marks a stub at `n_sites = 4000` as `"certified-0.94"`.

The retained CI-08 evidence is narrower: exactly Gaussian `d = 1`, `n = 150`
and Gaussian `d = 2`, `n = 150`, each with 20,000 attempts. PVT-02's Gaussian
`d = 2`, `n = 400` cell is unmeasured before this packet and must therefore
remain a **candidate calibration cell**, even if the current public predicate
would label a real fit as inside its broad regime.

## Evidence

| Surface | Evidence | Interpretation |
| --- | --- | --- |
| Predicate | `R/profile-derived.R:940-975` | labels all `n_sites >= 150` fits satisfying the other route conditions |
| Existing test | `tests/testthat/test-profile-ci-total-variance-export.R:36-42` | includes the incorrect extrapolation check at `n_sites = 4000` |
| Certificate | `docs/dev-log/2026-07-29-certificate-disposition.md:9-20` | reports only `d1-n150` and `d2-n150` results |
| Target ledger | `docs/dev-log/artifacts/methods-superarc/interval-target-ledger.md` | calls those two fenced cells the calibrated scope and PVT-02 a new-regime packet |
| Truth matrix | `docs/design/75-inference-route-truth-matrix.md` | contains stale blanket prose that no cell is empirically coverage-calibrated |

The two inconsistencies are different. The predicate and its test overstate the
*range* of the evidence; the truth matrix understates the existence of the two
retained `n = 150` results. Neither is repaired in this lane because either
change would be a shared public-claim decision outside the PVT-02 lease.

## PVT-02 handling

PVT-02 records the discrepancy, leaves public code and status untouched, and
uses its own fail-closed predicate. The candidate can only pass that predicate
with the exact `n = 400`, `d = 2`, `latent(..., unique = TRUE)` cell, 5,000
retained attempts, a disjoint seed window, coverage at least 0.94, and
coverage minus two replicate-clustered MCSE at least 0.94. A successful smoke
is not evidence of coverage and cannot trigger a promotion.

## Required follow-up after an approved campaign

If and only if the frozen campaign earns the exact PVT-02 evidence, a separate
maintainer-owned claim-reconciliation task must decide whether to narrow the
public predicate to enumerated cells, update its test, and replace the truth
matrix's blanket wording with a target-specific statement. That follow-up must
not infer a wider family, rank, tier, or sample-size status.
