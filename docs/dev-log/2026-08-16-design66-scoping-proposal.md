# Design 66 scoping — the filled-in proposal (one approve/amend decision)

**Status: PROPOSAL for the maintainer.** Every decision box from the
2026-08-16 one-pager now carries a recommended value and the measurement
behind it. Approving this document (or amending boxes inline) closes the
scoping conversation; nothing here authorises the capstone campaign itself,
which stays behind the compute-admission slice (§6) and D-139.

## 1. Claimant dispositions (evidence-settled today)

- **Cox–Reid REML (was claimant 2): RESOLVED — drop from the grid.** K1
  fired on the pre-registered A+B campaign (1,600 fits, `ae17a501`):
  Cox–Reid worsens median |bias| in both families (binomial 7.26 → 10.84 pp;
  ordinal 3.08 → 4.39 pp; paired-median MCSE 22–53× under threshold; more
  degenerates in the Cox–Reid arm). It enters the paper as a pre-registered
  negative result paragraph, not as cells. K2/K4 remain unadjudicated and
  are NOT recommended for the capstone (mechanism-only interest).
  Record: Design 121 §9, `dev/coxreid-ab/RESULTS.md`.
- **VA-vs-Laplace (claimant 1): PROCEEDS as Design 122, repriced.**
  Recommended disposition of the §14 options: see §2 (measured today).
- **Slope evidence cells (claimant 3): admitted to the grid AFTER the
  Design 122 confirmatory tier reports** — Fisher's cancelling-errors
  argument stands; and the A+B campaign's ordinal telemetry (max|Λ|
  distributions at n ∈ {100, 200}) is already in hand to inform the
  PHY-16 ordinal cell's feasibility.

## 2. Design 122 disposition — RECOMMENDED: option (c-modified), now MEASURED

**Cost curve (VGH, p=27, strong truth): 45.0 s at n=100 · 125.7 s at
n=400 · >17.3 min (unfinished) at n=1600.** So: **confirmatory tier at
n ∈ {100, 400}; n = 1600 demoted to a budgeted exploratory probe** —
preserving the realistic-scale question without one corner holding the
grid hostage. No `n_starts` reduction arm in the confirmatory tier (it
changes the estimand, per Design 122 F1's own logic).

**The completed reduced pre-run (120/120 fits, 5.9 min grid wall on 96
workers, stop rule did not fire):**

- **TEST A: 120/120 PASS across all three arms** — after the pre-run
  caught and fixed an instrument bug of exactly the class F1 exists for:
  `aghq_ridge` on the Laplace path is an R-level penalty
  (`R/fit-multi.R:5586-5592`), not part of `tmb_obj$fn()`, so the original
  TEST A scored L2 against the unpenalised objective (18/40 false-alarm
  failures; 40/40 PASS once the penalty entered the evaluated objective,
  `c_hat ∈ [1.0000, 1.0014]`). VGH passes under the pre-registered
  fixed-variational fallback (`TESTA_VGH_partial = TRUE`).
- **Convergence:** L0 40/40, L2 39/40, VGH 40/40 (by its own instrument).
- **Seeds/cell (primary |off|≥0.1 stratum, VGH−L2 contrast):** ~205–306
  at the binomial sentinels; the ordinal sentinel needs only a handful
  (SD(Δ) ≈ 0.03 — the arms barely differ there); the VGH−L0 contrasts are
  degenerate-inflated (up to ~1,700+ raw) and must use the all-arm
  intersection denominators the design already mandates. Working
  recommendation: **~300 seeds/cell confirmatory**, per-cell MCSE check at
  the pilot, exactly as §4's rule prescribes.
- **Flagged, unresolved:** 4/40 optimiser non-determinism flips
  (mirai-parallel vs sequential) at the weakest-signal cell — recorded in
  RESULTS.md for the campaign's determinism note.

Rough confirmatory budget at these measured costs: VGH-dominated,
~2 families × 2 n × 2 p × ~300 seeds × ~45–126 s ≈ tens of CPU-hours —
comfortably a Totoro weekend under D-143, formally derived at the pilot.

## 3. Interval method (Design 66 §3.4) — RECOMMENDED assignment

**Primary: the profile route (P-V), gated on `Sigma_unit_diag` only
(5 estimands). Diagnostic (reported, not gated): bootstrap at
`n_boot ≥ 200`.** Basis: the single cell where both routes have run shows
agreement (bootstrap 0.9418 / profile 0.9491 at B ≥ 200), so there is no
measured case for paying the bootstrap's ~2× cost as primary; the profile
route also carries the package's one documented coverage floor (the 0.94
Gaussian regime), i.e. its failure modes are characterised rather than
unknown. **Condition the pilot must clear before the assignment locks:**
measure `refits_per_profile` empirically (code-derived 14–26 per scalar,
worst case 72 — never measured, and with zero coverage evidence on the
structured-tier RE axis). That one number flips the cost comparison's sign
and decides Totoro-vs-DRAC. Missing-data cells: per the cov119
traits-per-unit mechanism, `se =` interval claims stay out of scope
regardless of method (the deficit is information-limited by p, not fixable
by n). Full evidence trail:
`docs/dev-log/2026-08-16-interval-method-recommendation.md` (8 sources cited).

## 4. Seed budget — one derivation rule, not one number

Recommended rule (MCSE-governed, matching Design 121/122 practice): the
pilot (n_sim ≈ 200) measures each cell's seed-SD; the HPC core's n_sim is
derived per stratum so every gate threshold exceeds 2× its achieved MCSE,
floored at Design 66's locked n_sim = 2000 for coverage cells. Design 122's
confirmatory cells merge into the same budget using the pre-run's derived
seeds/cell (§2). No campaign runs twice over the same cells.

## 5. What was measured today (provenance)

- A+B campaign: `dev/coxreid-ab/` (1,600 fits, canary-gated, Totoro).
- Design 122 pre-run: `dev/va-vs-laplace-prerun/` (stop-rule finding +
  completed reduced-sentinel run).
- Interval-method memo: `docs/dev-log/2026-08-16-interval-method-recommendation.md`.

## 6. The remaining build before ANY capstone fit runs

The Design 66 D-50 supersession's compute-admission slice (checksummed
source/runner, immutable destinations, result schema, smoke ladder) is
still unbuilt. Recommended: build it as its own small lane immediately
after this proposal is approved — the A+B campaign's guarded-launcher +
pinned-lib + canary pattern (`dev/coxreid-ab/launch-ab.sh`) is ~70 % of it
and should be generalised rather than rebuilt.

## Decision boxes (approve as recommended, or amend inline)

- [ ] §1 claimant dispositions as stated
- [ ] §2 Design 122 disposition (c-modified, pending measurements below)
- [ ] §3 interval-method assignment
- [ ] §4 seed-budget rule
- [ ] §6 compute-admission slice authorised as the next lane
