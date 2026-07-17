# Handover — Claude → Claude: Sigma_unit coverage certificate SHIPPED (arc CLOSED)

**Date:** 2026-07-17 · **Branch:** `claude/release-0.5.0` (pushed, in sync with origin) · **From:** Claude (Fable 5)

## 🎯 One-command resume
```
claude "Rehydrate from docs/dev-log/handover/2026-07-17-claude-handover-coverage-shipped.md. The
Sigma_unit-diagonal coverage certificate arc is DONE and pushed (dd80244a). Pick the next arc from the
'Remaining arcs' map below (or ask Shinichi). Do NOT touch Lane C (multinomial) files."
```

## What SHIPPED this session (the coverage arc is CLOSED)

The gaussian n≥150 **`Sigma_unit`-diagonal coverage certificate** — WITHHELD at the start of the
session — is now **earned, wired, and public**, merged as **`dd80244a`** (pushed to
`origin/claude/release-0.5.0`).

- **Evidence:** the Shinichi-approved fresh-seed lift finished on Totoro (`profile_rescore_freshseed_A`,
  10k fresh disjoint-seed reps, n_boot=100). Pooled with the original 5k → **N≈15,000**. Under the
  **committed rep-level MCSE** = √(p(1−p)/N): d1-n150 = 0.9477 (2·MCSE band 0.9440), d2-n150 = 0.9461
  (band 0.9424). Batches homogeneous (p=0.85/0.65); cross-hardware consistent (rorqual 0.9462).
- **Gate:** an independent **D-43 panel** (3 adversarial lenses + synthesis, 2 recomputing on Totoro)
  certified **both cells 3-0**. Audit: `docs/dev-log/2026-07-17-sigma-coverage-d43-panel.md`.
- **Decision:** Shinichi chose **flip both**. Memo:
  `docs/dev-log/2026-07-17-sigma-coverage-earn-vs-defer-memo.md`.
- **Implementation (`dd80244a`):** wired `.profile_ci_total_variance` into `confint(parm="Sigma_unit",
  method="profile")` — diagonal now profiles, off-diagonal + non-converged diagonal stay bootstrap
  (non-regressive). Public wording flipped on 3 surfaces (confint roxygen, NEWS, capability-surface)
  with the panel's mandatory framing: **clears the 0.94 gate** (NOT nominal 0.95), **for converged
  fits** (rate ~2.9% d1 / ~0.7% d2 disclosed), scoped to **d≤2**, number **0.946–0.948**, "validated"
  not "certificate." Fences intact: binomial/nbinom2/ordinal/off-diagonal/n<150 uncertified.
- **Verification:** `test-profile-ci.R` 113/113 (incl. the rewritten wiring guard); independent
  reviewer cleared wiring + all 6 wording constraints. Known unrelated: 3 pre-existing
  `test-confint-derived.R` failures on the withdrawn `communality` route (NOT touched here).
  After-task: `docs/dev-log/after-task/2026-07-17-sigma-coverage-freshseed-pooled-audit.md`.

## Coordination state
- The earlier concurrent coverage lane CLOSED and handed this off; `c0754666` (its correlation
  recovery-restore) rode along in the push (Shinichi-approved). No live competing writer.
- Left untouched (not mine): `docs/dev-log/check-log.md` (unstaged, other lane's), `.claude/`, and the
  Tier-2 phylo-multinomial lane docs (Lane C — off-limits).

## Remaining arcs (map — 2026-07-17 grounded survey: ROADMAP + issues + designs + backlog)

**Headline:** the engine surface is largely built and shipped (grammar, families, missing-data engine,
kernel quartet, augmented latent/unique fold, base multinomial, and now the gaussian Sigma_unit-diagonal
coverage certificate). What remains = interval-coverage certification, the gated coverage/power capstone,
non-Gaussian random-slope completion, and the paper. **0.6 = focused honesty/coverage/article push to
first CRAN; 1.0 = full validation + paper + Julia parity.**

### Toward 0.6 (first CRAN release)
- **CI/engineering health** (S, in-flight) — fix the red `test-spde-slope-base-engine.R:145` tolerance + test hygiene (#343).
- **Article Wave 1** (L, in-flight) — promote the 6 ready articles one-by-one after the register/figure/prose audit (#347).
- **multinomial() concept article** (S, in-flight) — PR #751, awaiting maintainer voice pass. **[Lane C]**
- **Unconditional RE redraw — spatial tiers** (M, in-flight) — phylo_diag landed (`be40d8ae`); extend to spatial so `bootstrap_Sigma()` is valid for structured Σ (#750).
- **BCa / studentized bootstrap** (M, planned) — for quantities without a tractable profile (communality, phylo-signal, repeatability, ICC); lands after the redraw.
- **REML profile for small-n gaussian** (M, planned) — certify the n=50 Sigma_unit-diagonal cell (0.939); reuses `.total_variance_spec`/`.profile_ci_total_variance`.
- **Restore correlation profile on Sigma_total** (M, open-decision 0.6-vs-1.0) — unify all four CI methods on one estimand.

### Toward 1.0 (capability maturity)
- **Capstone power/coverage campaign** (XL, in-flight) — Design 66 / #346+#349; blocked by the metric-repair gate (CI-08/CI-10, binary-harness mislabelling, ordinal-probit rows). **Gates CRAN + paper.**
- **CRAN readiness + methods paper** (L, planned) — #345; gated on the capstone.
- **Random-slope completion (non-Gaussian)** (L, in-flight) — Poisson/NB/binomial/beta/gamma/ordinal structured slopes + a random-slope article; `||` axis + Gaussian core shipped.
- **Correlated Tier-3 slope** (M), **cluster2 4th tier** (L, #342), **family-validation completion** (L, #348).
- **AGHQ integration** (L, planned) — replace Laplace for binomial/ordinal coverage (binomial profile stuck ~0.89–0.916).
- **nbinom2 phi-bias correction** (L), **Sigma_unit off-diagonal coverage** (L), **broaden the validated diagonal grid** (L, toward nominal 0.95 / d>2 / smaller n).
- **REML beyond Gaussian pilot** (L), **missing-response nbinom1/mi() coverage** (M), **fitted diagnostics >3 families** (M), **Design 70 missing-data ADEMP** (L), **meta_V() article** (S).

### Parked / open maintainer decisions
- **Phylo multinomial GLLVM (Design 84 / Tier-2a)** — Discussion-Checkpoint; needs sign-off. **[Lane C]**
- **3 held sign-offs:** disp_group (DEFERRED — fails recovery gate), family-breadth advertising (merge-now vs Phase-F), tweedie stale-rationale refresh.
- **Design 72 VA engine** (open-decision), **Design 76 structured X_lv** (parked — high-risk likelihood change), **delta/hurdle latent-correlation convention** (open-decision), **z→t Wald advisory** (#565), **bridge-gate drift audit** (#488), **matrix-free REML** (#705, parked), **kernel coevolution capstone** (#361, post-1.0), **phylo mi() flagship** (#338, post-1.0).

### Recommended next (by leverage)
1. **Spatial RE redraw (#750)** — small, proven pattern, unblocks valid structured-Σ bootstrap + the BCa work.
2. **Capstone metric-repair (CI-08/CI-10)** — the single gate holding the whole coverage/power campaign, which gates CRAN + paper.
3. **Article Wave 1 (#347)** — parallel, low-risk, most-visible 0.6 reader path.
4. **BCa/studentized bootstrap** — the interval-honesty win for 0.6 (after redraw).
5. **Restore correlation profile on Sigma_total** — reuses just-landed infra; decide 0.6-vs-1.0 up front.

## Fences (standing)
No public flip without Shinichi. Lane B (X_lv) / Lane C (multinomial) files off-limits. Compute on
Totoro/DRAC, results LOCAL, never GitHub artifacts (D-50). Certificate work defaults NOT-DONE (D-43).
