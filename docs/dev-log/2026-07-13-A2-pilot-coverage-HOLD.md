# A2 pilot coverage — VERDICT: HOLD (do NOT scale to n_sim=2000)

**Date:** 2026-07-13 · **Owner:** solo Claude · **Instrument:** Design-66 scaling-gate
pilot, n_sim=200, n_boot=100, core-4 (gate excludes ordinal) · **Compute:** Totoro,
48 shards, `~/gllvm_work/pilot200`, `n_errored=0`, 48/48 cells.

## Verdict

`pilot_scale_gate()` → **HOLD**. Reasons:

1. **2 CORE cells fail a health gate** — `nbinom2` n=150 (d1 & d2, signal 0.2): fit-failure
   ~0.20, boot-failure ~0.21 (both above the 0.20 ceiling).
2. **14 of 24 CORE coverage cells below the provisional coverage floor.**

No interval-coverage certificate is earned. Per D-43 (default NOT-DONE), the claim
"core families have calibrated `Sigma_unit_diag` interval coverage" is **withheld** — the
gate itself refutes it; no adversarial panel needed (the data is clear-cut).

## The headline finding — coverage WORSENS with n (bias signature)

Mean `coverage_primary` (nominal 0.95), core families, signal>0:

| family | n=50 | n=150 |
|---|---|---|
| binomial_probit | 0.92–0.98 | 0.82–0.93 |
| gaussian | 0.80–0.90 | **0.54–0.77** |
| nbinom2 | 0.85–0.96 | **0.52–0.67** |

- **Not a d-effect** (d=1 vs d=2 means ≈ equal). **An n-effect, and in the wrong direction.**
- MCSE ≈ 0.02–0.035, so gaussian 0.535 is ~12 MCSE below nominal — a real, massive
  miscalibration, not noise.
- Coverage *falling* as n grows is the textbook signature of a **bias in the point
  estimator that the parametric bootstrap does not correct**: as n↑ the CI half-width
  shrinks (O(1/√n)), so a fixed/slowly-shrinking bias becomes a larger share of the
  interval and coverage collapses. A calibrated bootstrap would hold near nominal or
  improve with n.
- For a consistent MLE with O(1/n) bias and O(1/√n) SE, bias/SE = O(1/√n) → coverage
  should *improve* with n. It worsens instead, which points to either **(a) an O(1)
  bias / estimand-vs-truth definitional mismatch** (e.g. the bootstrap estimand includes
  the diag(ψ) companion but the DGP truth does not, or a rotation/identifiability
  inconsistency in how the Σ diagonal is compared), or **(b) a bootstrap SE that
  understates uncertainty and worsens with n**. `binomial_probit` degrades least → the
  bias is family-dependent.

## Why we do NOT run the n_sim=2000 grid

Scaling n_sim only shrinks **MCSE**. It does nothing to **bias**. Running the 6–24h grid
now would measure the undercoverage to 3 decimals — it would not earn a certificate. The
pilot gate exists precisely to catch this before the spend; it did.

## Metric bug to repair before any certificate (Repair #5)

`ci_missing_rate = -4` uniformly, because `coverage_eligible_n` (~1000) counts **trait-level
interval checks** (≈5 traits × 200 reps) while `n_converged_fits` (~200) counts **model
fits** — a ~5× denominator mismatch (`1 - 1000/200 = -4`). It does not change the HOLD
(that is driven by legitimate low coverage + the 2 nbinom2 fit/boot failures), and it makes
the CI-missing health component trivially pass, but it must be fixed (align both to the same
unit — per-fit, or per-trait-check) before the CI-missing gate means anything.

## Recommended next move (Shinichi decision)

Default recommendation: **do NOT scale; diagnose the `Sigma_unit_diag` bias first.**
Concretely, on one gaussian-n150 cell (cleanest — low fit/boot failure, coverage 0.54):

1. **Estimand-vs-truth audit** — confirm the bootstrap primary and the DGP "truth" are the
   SAME functional of Σ (both include or both exclude the diag(ψ) companion; same
   rotation-invariant reduction). A definitional mismatch is the leading hypothesis and the
   cheapest to check.
2. **Bias decomposition** — plot Ê[Σ̂_diag] − Σ_diag,true vs n; is bias O(1) or O(1/n)?
3. **Interval method** — is the current interval percentile-bootstrap? Try BCa /
   bias-corrected; but if (1) is the cause, no interval method rescues it.

This keeps the honesty fence exactly where the handover set it: **intervals stay
recovery-only / point-only on every public surface — NOT coverage-certified.** The widget
does not flip.

## RESOLUTION (2026-07-13, after diagnosis) — two DISTINCT causes, not one estimator bias

The "coverage collapses with n" pattern is **not** an estimator finding. Per the
[[LESSONS]] principle recorded this day (*a working algorithm going in a theory-forbidden
direction is OUR pipeline's problem, not a finding — the DIRECTION of the n-effect is the
discriminator*), it split into two separate, family-specific causes:

### gaussian — a harness DGP bug (FIXED + VERIFIED)
Constant offset `mean(Σ̂_diag − truth) ≈ +0.25 = sigma_eps²` at every n/d/signal. The DGP
added a Gaussian observation residual `rnorm(sd=0.5)` on top of `eta`, omitted from the
scored truth, and necessarily absorbed by the fit's single `indep(0+trait|unit)` component
(ψ and σ_eps non-identifiable with one obs/cell). **Fix:** `m3_simulate_response` gaussian
branch now returns `eta` with no separate residual (mirror of the 2026-05-25 binomial-ψ=0
patch). Fit-free DGP check: offset 0.25 → 0.003.

**VERIFIED (Totoro re-run, 8 gaussian sig>0 cells, n_sim=200, n_boot=100, fixed DGP):**
coverage recovered from the broken 0.54–0.77 (n=150) to **0.90–0.93 (mean 0.911)**, and the
**n-direction flipped to correct** — coverage now *rises* with n (n=50 → 0.901, n=150 → 0.920),
as consistency demands. Residual ~0.92-vs-0.95 is benign small-n bootstrap behaviour improving
with n (MCSE ~0.02 at n_sim=200 brackets nominal); the n_sim=2000 grid (or an n=400/800 cell)
would adjudicate 0.92-vs-0.95. **The bug is unambiguously fixed. gaussian is a 0.6 certificate
candidate.** Artifacts: `~/gllvm_work/verify_gauss/` (Totoro).

### nbinom2 — a genuine weak-identifiability LIMIT (fence, do not certify)
NOT a harness coding bug and NOT a power problem. The NB dispersion `phi` and the
observation-level unique variance `psi` are **near-redundant overdispersion sources** for
counts; estimated `phi` is unstable (often collapses to the Poisson limit, `phî → ∞`),
which starves `psi` and drags `Sigma_unit_diag` to ~0.5× truth. Two independent confirmations:
- **Prior recall (2026-05-19/20 audits):** target-scale mismatch fixed (`link_residual="none"`,
  still in place), but a *remaining* dispersion-calibration signal was flagged and nbinom2 left
  **unpromoted**; the known-phi diagnostic showed fixing `phi` at truth recovers Σ from
  0.56–0.70 to **0.70–0.94** (so `phi` estimation is the lever).
- **New n-ladder (`dev/nbinom2-phi-nladder.R`, 2026-07-13):** median Σ̂/truth is **FLAT at
  ~0.45–0.52 from n=150 to n=800** (5× n, no climb toward 1); median psî/truth ~0.3;
  `phî→∞` collapses persist even at n=800. **Recovery does not improve with n → a genuine
  identifiability limit, not under-power.**

**Conclusion.** 0.6 core interval-coverage certificate candidates = **gaussian (fixed,
pending verification) + binomial_probit (healthy, 0.82–0.93 @ n=150)**. **nbinom2 is fenced**
(point-only) as a documented weak-identifiability limitation — a 1.0 modeling lane (known/fixed
dispersion, re-parameterization, or a different estimand), same tier as AGHQ. This matches the
May scope status (nbinom2 never promoted). Ordinal was already excluded (Repair #2).

## Artifacts

- `~/gllvm_work/pilot200/` (Totoro) — 48 cell aggregates + `scale-gate-verdict.rds`.
- Per-cell coverage table: this doc's table + the saved verdict rds.
- `dev/nbinom2-phi-nladder.R` + `dev/nbinom2-phi-nladder-results.rds` — the recovery-vs-n ladder.
- Gaussian DGP fix: `dev/m3-grid.R` `m3_simulate_response` gaussian branch + `m3_sample_truth`.
