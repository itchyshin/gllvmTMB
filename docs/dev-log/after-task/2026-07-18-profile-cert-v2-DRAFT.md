# After-task — Profile-route interval-coverage CERTIFICATION arc (v2) — 2026-07-18 [DRAFT — pending B3 + D-43 panel]

**Platform:** Claude (user-driven, ultracode). **Branch:** `claude/profile-coverage-remeasure-20260718` (off `claude/release-0.5.0`). **Status:** MEASURED + diagnosed; certificate verdict PENDING the D-43 panel (default NOT-DONE). Nothing promoted.

## Scope / goal
Deferred arc (A4/A6 + binomial diagnostic + data-integrity) after the prior session's "MEASURED, not certified" stop. Maintainer chose (options 2+3): (2) TRY to EARN the gaussian n≥150 certificate via a Bartlett-corrected χ²₁ profile + REML n=50 test; (3) deep-diagnose the binomial + reconcile the truth_psi flag. Then D-43 panel → truthful register update.

## Settled findings (FINAL — evidence in scratchpad + results/profile-pilot-*)
1. **Gaussian n≥150 baseline (uncorrected χ²₁):** pooled fresh-seed ~10k reps → **d1 0.9474, d2 0.9455, rep-clustered MCSE 0.0011.** Clears the 0.94 IUT bar (lower bands 0.9453/0.9433) but ~0.3–0.5pp short of a clean 0.95. Confirms borderline at 3× A3 precision.
2. **REML n=50 (B2, `reml_bridge()` Gaussian):** ML 0.9437 (est/truth 0.985) → **REML 0.9488 (est/truth 1.005).** REML closes ~half the n=50 shortfall AND removes the finite-cluster point bias → confirms the ML-variance-bias hypothesis as the n=50 lever.
3. **Binomial (C1, Fisher+Gelman, adversarially corroborated): FENCE for 0.6 (recovery-only).** Named mechanism = a weakly-identified ΛΛ'-vs-total-variance **identifiability ridge** (single-trial Bernoulli can't separate per-trait Ψ from the fixed probit residual r=1; V_t scale pinned only by r=1) → bimodal, upward-mislocated point estimates (interior est/truth 50–600×). Coverage worsens as signal grows (ridge fingerprint) — **NOT the two-lever floor** (disproven, PF-5). No interval construction closes it; Bartlett powerless (can't re-center a mislocated point). Fix = estimation-side (pin Ψ=0 for single-trial binomial) = a **1.0 Discussion-Checkpoint spec change**.
4. **truth_psi (C2): a harness record-keeping BUG,** logs the raw pre-zeroing Gamma(2,2) draw not `psi_effective` (enforced 0 for binomial, `dev/m3-grid.R` L490–494). `est_psi≈0` is CORRECT; "psi→0 collapse" was compared against the wrong reference. **Certificate target `truth_diag_sigma` unaffected.** (Follow-up: rewire the truth_psi emission column; secondary defect in the non-primary "psi" target scoring.)
5. **Sigma_unit_corr (S4): DIAGNOSTIC only** — gaussian corr under-covers 5–15 MCSE below 0.95 even where gaussian diag certifies (a family-independent correlation-estimand shortfall); binomial corr under-covers in lockstep with diag (shared ridge). Moves no register row; the certificate is DIAG-only.

## The Bartlett lever (B1, verified) — the certificate hinges on B3
- **Opt-in `crit·(1+b/n)`** in `.qchisq_threshold` (`R/profile-ci.R`), `b̂ = n·(W_mean−1)`, W=2ΔL under the fitted null, pooled per design on an INDEPENDENT seed stream, boundary-collapsed refits excluded. Default `confint(method="profile")` **byte-identical** (opt-in only). `n = fit$n_sites` (estimation-n = application-n → factor = W_mean).
- **Verified:** B1v adversarial panel SOUND on all 3 lenses (Fisher/Efron/statistical-reviewer, 0 blockers); heavy tests pass (#12 byte-identical path, #13 widening-brackets, #14 estimand identity).
- **[PENDING B3]** re-score gaussian n≥150 with the Bartlett crit (well-powered pooled b̂) + PF-2 n=400 asymptote anchor → **does it reach ≥0.95?**  ➜ _fill: per-cell corrected coverage, MCSE, b̂, boundary_hit_fraction, earn verdict._

## [PENDING] D-43 panel (P) — the gating authority
4 lenses (Rose/Fisher/Efron/Gelman), RAW tables only, default NOT-DONE, IUT, ≥2 NOT-DONE ⇒ WITHHELD. ➜ _fill: per-cell EARNED/WITHHELD._

## [PENDING] Register update (R) — promote ONLY panel-earned cells
- CI-08 / CI-10 (`partial`): disambiguate the OLD 2026-05-19 M3.3 profile-psi bootstrap-era numbers from the Design-73 `profile_total` route; update per the panel; NO promotion without a pass.
- CI-11 (`covered` route-ledger only): unchanged.
- Binomial → fenced (C1 mechanism); corr → diagnostic (moves no row). nbinom2 stays fenced.

## Checks / evidence
- B1: B1v SOUND + heavy tests pass (worktree). B2/A/B3: Totoro, ≤100 cores, results LOCAL (D-50). Binomial/truth_psi: analysis of existing pf5/A2/A3 rds. Compute NOT on GitHub.

## Follow-ups / next
- [pending] Bartlett verdict + panel + register + widget + CLAUDE.md pointer + handover + Melissa reconcile.
- truth_psi emission-column rewire (harness hygiene). Correlation-estimand shortfall (own arc). Phase B (pin-Ψ=0 binomial; AGHQ+Cox–Reid) = 1.0 + sign-off.
