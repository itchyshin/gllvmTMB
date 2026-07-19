# CI-11 cross-family interval coverage — the MEASURED certificate (2026-07-19)

**Banner:** MEASURED, NOT certified — awaiting D-43 panel + Ayumi clean real-data pass. Results LOCAL (D-50).

## Provenance
DRAC super-sim, fir job `49532634`, `--grid=certified --n-sim=13000 --n-boot=499`, **6389 shards** aggregated
(of 6500; 128 stragglers pending, ≈2% — immaterial). ~76,666 converged reps per multiple_r cell-group,
~153,332 per contrast_r cell-group → **2·MCSE ≈ 0.0016** (coverage resolved to ±0.002). conv_rate 1.00,
ci_failed_rate 0 everywhere. Estimand truth `Σ_total_true = ΛΛᵀ + diag(ψ) + R_link`; the AUTO-scale R_link
that wald/bootstrap target was **verified byte-identical** to the truth's analytic R_link (0.0000).

## Coverage (target 0.95), pooled over partner {gaussian, binomial} × target-r {0.2,0.5,0.8} [× contrast]

### multiple_r
| method | N=50 | N=150 | N=500 |
|---|---|---|---|
| bootstrap | 0.933 | 0.898 | **0.791** |
| wald | 0.971 | 0.965 | 0.937 |

### contrast_r
| method | N=50 | N=150 | N=500 |
|---|---|---|---|
| bootstrap | 0.930 | 0.923 | 0.883 |
| profile | 0.942 | 0.943 | 0.935 |
| wald | 0.960 | 0.958 | 0.950 |

## ⚠️ CORRECTION — the pooled table above OVER-STATES coverage (D-43 panel caught this)
The pooled-over-r numbers **mask a boundary catastrophe**. The per-cell (partner × target-r × N) decomposition
(from the local `AGGREGATED-49532634.rds`) shows coverage degrades sharply at **r=0.8**, hidden by averaging
against the over-covering r=0.2 cells. **The r=0.8 / N=500 corner:**

| estimand | route | gaussian | binomial |
|---|---|---|---|
| multiple_r | bootstrap | 0.943 | **0.303** |
| multiple_r | wald | 0.938 | **0.726** |
| contrast_r | bootstrap | — | min **0.640** |
| contrast_r | profile | — | min **0.885** |
| contrast_r | wald | — | min **0.806** |

(multiple_r wald by r: r=0.2 → 0.99–1.00, r=0.5 → 0.98, **r=0.8 → 0.73–0.94** — the pooled 0.95 averages
over-coverage at low r against under-coverage at high r.)

## Findings (CORRECTED, per-cell)
1. **No route is validated at the r=0.8 boundary.** All degrade there, worsening with N. Pooling over r hid it.
2. **Wald is r-DEPENDENT, not uniformly safe.** Over-covers at r=0.2 (0.99–1.00), under-covers at r=0.8
   (0.73 mr / 0.81 cr at N=500). The "pooled ~0.95" was an artifact of averaging opposite errors — do NOT
   present wald as near-nominal.
3. **Profile is the MOST ROBUST route** — most stable across r (0.885–0.946), degrades least at the boundary
   (worst 0.885 at r=0.8/N=500). Best-behaved, but still mildly under-covers at the corner. (contrast_r only.)
4. **Bootstrap's collapse is partner × r × N specific.** Catastrophic on **binomial × r=0.8 × N=500 = 0.303**;
   but **gaussian** bootstrap is actually stable (~0.94 across N). So "worsens with N" is driven by the
   binomial high-r cells — a real, severe, and family-specific defect.
5. Direction: the boundary failures are **anti-conservative UNDER-coverage** (the safety-relevant direction),
   not conservatism. (My first draft mislabeled profile's ~0.935 as "conservatism" — it is under-coverage.)

## D-43 PANEL VERDICT — WITHHELD (3/3 NOT_DONE)
Three fresh independent reviewers, all NOT_DONE. Consensus per-route: **wald = partial · profile = partial ·
bootstrap = not_covered.** The panel rejected the first-draft "wald covered / profile conservative" language
(both fail the project's own `lower_2mcse ≥ 0.94` gate at N=500; profile is under-covering not conservative)
and required the per-cell r-decomposition above. "All routes validated" is **WITHHELD**.

## Honest disposition (route-specific; DO NOT flip the register yet)
- **profile → partial** — best route; in-regime (r≤0.5) near-nominal; r=0.8 corner mild under-coverage; contrast_r only.
- **wald → partial (heuristic, r-dependent)** — near/over-nominal for r≤0.5, under-covers at r=0.8; keep the
  `heuristic_unvalidated` flag; do not advertise as validated.
- **bootstrap → NOT covered — fenced / do-not-advertise** — severe binomial×high-r×large-N under-coverage (0.30).
- **Disclosure limits:** single loading-ray, gaussian/binomial + K=3 only, r∈{0.2,0.5,0.8} (r=0.8 fails),
  balanced/complete-case, correct-d, conditional-on-convergence (moot; conv 1.00).

## Must happen before ANY register flip (D-43)
1. **Per-cell minimum** (not pooled) is the certificate — done here; the r=0.8 corner governs.
2. Fix or formally fence the boundary; re-run bootstrap with larger B to confirm the defect isn't a B artifact
   (keep fenced regardless). Investigate the binomial-specific bootstrap collapse + the wald r-dependence.
3. **Ayumi's external real-data pass + maintainer sign-off** — no register/NEWS/roxygen flip without both.
