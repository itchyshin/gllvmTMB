# CRAN 0.7 v2 Totoro pilot: discovery-only HOLD

## Verdict

**HOLD. Do not run v2 production.** The 20-attempt pilot is complete and its
attempt accounting is valid, but it exposed two defects in the frozen v2
adjudicator: detector sensitivity is required separately in cells with no
catastrophic positives, and the implemented production gate omits the frozen
Sigma, Psi, correlation, and sample-size/RMSE criteria. A corrected gate must
use new campaign IDs and new seeds before any production run.

## Exact execution receipt

- Host: Totoro, R 4.5.3, 32 workers, BLAS/OMP pinned to one thread.
- Clean source snapshot SHA-256:
  `585c8329448e0d29acbf36988b940823a43e835846b564d3b3067b46d07fba0a`.
- Run: 2026-08-08 21:03:44--21:04:55 UTC.
- Attempts: 680/680 exact manifest keys across 34 cells; zero missing, extra,
  or duplicated keys.
- Estimands: 20,280/20,280 applicable estimates finite.
- Statuses: 616 usable, 21 boundary, 41 non-positive-Hessian, and 2
  nonstationary; zero unclassified.
- Global detector table: TP = 20, FN = 0, FP = 44, TN = 616; sensitivity =
  1.000 and specificity = 0.9333. All 20 positives came from the held
  `g_latent_psi_large` challenge.
- Raw per-attempt RDS files remain on Totoro under
  `/home/snakagaw/gllvmtmb_cran07_pilot_v2_20260808/pilot/final/` and were not
  committed or uploaded to GitHub.

The first transfer attempt produced a macOS AppleDouble file on Linux and
failed at compilation before a task manifest or fit existed. The clean
snapshot above contains zero `._*` entries. No attempt from that failed
preflight exists in these results.

## Pilot admission outcome

The exact pilot rule admits a cell with at most 3 unusable attempts out of 20,
at most 1 unclassified attempt, and no nonfinite applicable estimand. Thirty of
34 cells provisionally pass:

- ordinary core: 14/18;
- silent-failure grid: 8/8;
- robustness grid: 8/8.

Four ordinary-core cells are held:

| Cell | Unusable | Pilot verdict |
|---|---:|---|
| `nb2_latent_n100` | 4/20 | HOLD |
| `g_latent_rho_boundary98` | 5/20 | HOLD |
| `g_latent_psi_small` | 14/20 | HOLD |
| `g_latent_psi_large` | 20/20 | HOLD |

Exactly 3/20 is a pass under the predeclared `<= 15%` rule; it must not be
rejected because of floating-point representation of 0.15.

## Why v2 production is forbidden

1. Every provisionally admitted cell has a detector-sensitivity denominator
   of zero. The v2 per-cell gate treats this as failure even when the cell is
   entirely healthy, so a 400-attempt healthy cell is structurally unable to
   earn the intended certificate.
2. `cran07_gate_summary()` implements health, detector, catastrophic-false-
   negative, and fixed-effect-bias checks, but not the frozen relative
   Frobenius Sigma bias, Psi bias, correlation bias, or large-versus-small RMSE
   checks.
3. The standalone v2 summarizer does not receive the frozen manifest, making
   its observed `n_expected` tautological. The pilot receipts here were instead
   independently reconciled against the three committed `__FULL.csv`
   manifests.
4. Production is fixed at 400 attempts per admitted cell. The v2 machinery has
   no implemented preregistered rule that permits 200.

## Files retained here

The three exact full manifests, per-cell attempt denominators, detector
metrics, aggregate estimand summaries, and run metadata are committed beside
this note. The v2 `gate-summary.csv` files are deliberately not promoted
because their gate implementation is the defect diagnosed here.

