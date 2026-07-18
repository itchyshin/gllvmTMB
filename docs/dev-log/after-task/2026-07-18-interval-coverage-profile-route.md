# After-task — Interval-coverage profile-route: wire + re-measure (Phase A) — 2026-07-18

**Platform:** Claude (user-driven). **Branch:** `claude/profile-coverage-remeasure-20260718` (off
`claude/release-0.5.0`). **Arc:** "certify the whole interval-coverage story" — Phase A (measure the profile
route). **Status:** measurement COMPLETE; **nothing certified, nothing committed, nothing promoted.**

## Scope / goal
Move gllvmTMB interval-coverage measurement OFF the closed parametric-bootstrap route ONTO the profile route,
for `Sigma_unit_diag = diag(ΛΛ'+Ψ)` (certificate candidate) and `rho:unit` on `Sigma_total` (diagnostic), and
RE-MEASURE gaussian + binomial. Deliverable = measured coverage reported to the maintainer BEFORE any D-43
panel / register flip.

## What shipped (code — dev/ harness only; no package `R/` or `src/` change)
- **A1a/A1b/A1c wire** (`dev/m3-grid.R`, `dev/m3-pilot-report.R`, `dev/m3-pilot-launch.R`): route the profile
  number through the harness's EXISTING `coverage_certificate` column (never overwriting `coverage_primary`);
  new `Sigma_unit_corr` (rho) target with truth built on the `Sigma_total` scale so truth==target; PF-3
  endpoint-sanity guard (`m3_profile_ci_sane()`); shared `m3_placeholder_ci_method()` honesty helper; the scale
  gate now reads `coverage_certificate`; `pilot_rbind_cell` dedup key gains `trait_j`; nbinom2 fenced at the
  selector; additive `coverage_certificate` mirror into the live-index/status surfaces.
- **`dev/profile-pilot-run.R`** (NEW): focused profile-route pilot runner (core cells × estimands,
  `(cell, rep-chunk)` sharding, stale-package PREFLIGHT + installed-first/load_all-fallback loader,
  `--families/--ns/--signals/--targets/--n-boot/--extra-methods` scope flags).
- **Tests:** `dev/test-profile-coverage-remeasure.R` (NEW, 56 checks incl. estimand identity, PF-3 injection,
  single-target, label helper); `dev/test-pilot-scale-gate.R` extended (gate reads `coverage_certificate`).

## What was measured (results LOCAL: `results/profile-pilot-{A2,A3,pf5}/`; MEASURED, NOT certified)
- **Gaussian `Sigma_unit_diag` (A3 confirm, n_sim=4000, rep-clustered MCSE ~0.0017):** n≥150 = **borderline
  nominal ~0.945–0.949** (3/4 cells' 95% CI covers 0.95; d2-n150-sig0.2=0.9452 marginally misses); **n=50
  sub-nominal ~0.940–0.943** (coverage ≈1pp below 0.95; separately, point bias ~2%, est/truth ~0.98). The
  χ²₁ profile carries a **mild residual small-sample under-coverage even at n=150**. (Bootstrap route gave ~0.91 — the profile is a real improvement, just not a
  clean 0.95.)
- **Binomial (PF-5 discriminator — 3 constructions on identical fits, signal0.5):** bootstrap / profile / wald
  disagree by up to **23pp on the SAME fits** (e.g. d1-n50: 0.907 / 0.679 / 0.783); point est/truth **wildly
  UPWARD (9.6–122×)**, psi→0 boundary collapse in 68–98% of fits. → binomial under-coverage is an **interval-
  CONSTRUCTION + boundary-collapse problem, NOT the two-lever ML-Laplace estimator floor**; no construction
  cleanly covers.
- **psi=0 boundary cells:** binomial signal=0 two-sided coverage ~0.00 is a **log(V)-profiling scoring
  artifact** (one-sided-upper coverage = 1.000 exactly), NOT real 0%.

## Key corrections during the arc (honesty trail — two over-claims retracted)
1. **"Gaussian nominal across all 12 cells incl. n=50 / earned"** → FALSE. Earned only ≈ n≥150 (borderline);
   n=50 sub-nominal. I had quoted a too-loose MCSE (0.017) that hid the shortfall; honest rep-clustered MCSE is
   ~0.0017–0.0075.
2. **"Binomial under-covers = two-lever floor, fixed by Phase-B REML/AGHQ"** (which the maintainer also
   provisionally agreed to) → DISPROVEN by our PF-5 data (construction + boundary, not estimator; point upward
   not downward). Re-labelled "mechanism = construction/boundary; Phase-B route unconfirmed."
Both were caught by adversarial verification (W2 diff-review; W5 conclusion panel; PF-5 discriminator) BEFORE
the report — the reason the arc ran those checks.

## Decisions
- Profile → `coverage_certificate`, `coverage_primary` untouched (Rose). nbinom2 fenced at selector. Binomial
  rho truth built on `Sigma_total` (maintainer ruling b). No D-43 panel / register flip this arc (deferred).
- Recommended next arc (NOT this one): (1) **Bartlett-correct the gaussian profile** (`b` ESTIMATED on our
  fits) → candidate path toward a clean n≥150 certificate (to be RE-SCORED, not assumed) — construction-level,
  no engine change; (2) **Gaussian REML for n=50**
  (available `reml_bridge`); (3) **binomial boundary-collapse DIAGNOSTIC** (identifiability of ΛΛ' vs
  link-residual vs Ψ) BEFORE any Phase-B engine build. Do NOT jump to multi-dim AGHQ/Cox-Reid on an unconfirmed
  diagnosis.

## Checks / evidence
- 56/56 + 19/19 local tests; W2 diff-verify PASS (post-repair); A2 n_sim=200 (24 cells), A3 n_sim=4000
  (8 gaussian cells), PF-5 (4 binomial cells × 3 constructions) on Totoro (built from source, preflight
  `.profile_ci_total_variance`=TRUE). Compute Totoro ≤100 cores, results LOCAL (D-50).

## Follow-ups / next arc
Bartlett-`b` estimation + gaussian re-score; Gaussian REML n=50; binomial boundary-collapse diagnostic;
one-sided psi=0 scoring folded into the report; register CI-08/CI-10/CI-07 note (staged, NOT promoted); commit
the wire (maintainer's act). See handover `docs/dev-log/handover/2026-07-18-claude-handover-profile-route.md`.

## Landing state
Wire is UNCOMMITTED on `claude/profile-coverage-remeasure-20260718` (dev/ + tests). NOT committed (maintainer's
call). Never-commit: Lane-C drafts, `.claude/`, `docs/dev-log/check-log.md`. Results LOCAL only.
