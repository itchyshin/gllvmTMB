# After-task — A2 coverage diagnosis: gaussian harness bug fixed, nbinom2 confound characterised

**Date:** 2026-07-13 · **Owner:** solo Claude (no Codex) · **Plan:**
`~/.claude/plans/luminous-weaving-nova.md` · **Branch:** `claude/release-0.5.0` (uncommitted) ·
**Predecessor:** `2026-07-13-gap-closure-execution-phase1.md` (the parallel slices A0/A1/B1–B4/C/D/E2/E3).

## Scope

Run the Design-66 coverage pilot to its scaling-gate verdict, and — when it came back HOLD —
diagnose the cause rather than scale past it. The pilot (n_sim=200, n_boot=100, core-4, Totoro,
48/48 cells, `n_errored=0`) returned **HOLD**: `Sigma_unit_diag` bootstrap coverage that
*worsened* with n (gaussian/nbinom2 fell to 0.52–0.77 at n=150).

## Outcome — one symptom, two distinct causes; not an estimator finding

The "coverage collapses with n" pattern is theory-forbidden for a consistent estimator, so per
the discipline it was treated as an OUR-pipeline problem, not a discovery. It split cleanly:

| family | cause | status |
|---|---|---|
| **gaussian** | **harness DGP bug** — `m3_sample_truth`/`m3_simulate_response` added a Gaussian observation residual `rnorm(sd=0.5)` (var 0.25) omitted from the scored truth, absorbed by the fit's single `indep(0+trait\|unit)` component (ψ/σ_eps non-identifiable, 1 obs/cell) → estimator consistent for `truth + 0.25` | **FIXED + VERIFIED** |
| **binomial_probit** | — | healthy (0.82–0.98), one soft cell 0.82 @ d1-n150-sig0.5 |
| **nbinom2** | **known literature confound** — NB dispersion φ vs latent log-scale variance ψ are the same overdispersion mechanism, weakly identified; estimated per-trait φ (5 at T=5) is biased/unstable → ψ and Σ starved to ~0.5× | fenced (1.0 lane) |
| **ordinal** | Bar-3/AGHQ | excluded (Repair #2) |

### gaussian — fixed + verified
- Root cause proven from the pilot's own reps: `mean(Σ̂_diag − truth) ≈ +0.25 = σ_eps²`, constant
  across n/d/signal. Fix: gaussian DGP now returns `eta` with no separate residual (mirror of the
  2026-05-25 binomial-ψ=0 patch). `dev/m3-grid.R`.
- Fit-free DGP check: offset **0.25 → 0.003**.
- **Verification re-run** (Totoro, 8 gaussian sig>0 cells, fixed DGP): coverage recovered
  **0.54–0.77 → 0.90–0.93 (mean 0.911)**, and the **n-direction flipped to correct** (n=50 → 0.901,
  n=150 → 0.920). The bug is unambiguously fixed.

### nbinom2 — characterised, not a today-fix
- **Recall paid off:** the May 2026-05-18 Noether identifiability audit + 2026-05-18 cross-package
  scout + 2026-05-19/20 target/known-phi audits already diagnosed this and proposed the fixes.
- **Mitigation ladder** (`dev/nbinom2-mitigation-ladder.R`): median Σ̂/truth — default 0.45–0.52,
  warm-start **identical** (no help), **known-phi 0.78–0.82 and rising with n**. The whole gap is
  φ estimation; the DGP has one shared φ but the fit estimates 5 per-trait φ (over-parameterised).
- **Literature (NotebookLM, 68 sources, `docs/dev-log/2026-07-13-nbinom2-dispersion-literature.md`):**
  the confound is documented (Lawless 1987; Harrison 2014 *PeerJ*; Bolker GLMM FAQ); small-sample
  NB-dispersion bias is established (Lloyd-Smith 2007; Saha & Paul 2005); bias-corrected estimators
  exist (`brglm2::brnb`) but only for plain NB, **not the joint ridge**. The endorsed remedy is
  **shared/pooled dispersion** (gllvm `disp.formula`, "to avoid volatile estimation") — matching the
  ladder exactly. glmmTMB has no special fix. A ridge-specific bias-corrected/profiled φ is an
  **open methods niche**.

### Core-2 scale gate (gaussian-fixed + binomial; nbinom2 excluded)
`VERDICT: HOLD` but near-passing: **16/16 health gates pass**, mean coverage **0.914**, only 3/16
cells marginally below the provisional floor (2 gaussian n=50; 1 binomial 0.82 @ d1-n150-sig0.5),
all within ~1–2 MCSE of nominal at n_sim=200. This is the legitimate "smoke MCSE can't adjudicate
0.92-vs-0.95" case the **n_sim=2000 grid** exists to resolve — no longer a bug to fix first.

## Durable principle recorded

`~/shinichi-brain/memory/LESSONS.md` + `memory_summary.md`: *a working algorithm going in a
theory-forbidden direction is OUR pipeline's problem, not a finding — the DIRECTION of the n-effect
is the discriminator* (improves with n = information; degrades with n = our DGP/target/truth bug).
Sibling of the 2026-07-06/07 sample-size-first pair. Filed because the prior nbinom2 audit existed
but did not fire — a routing failure.

## Checks
- Pilot 48/48, `n_errored=0`. Gaussian verification 8/8 cells. Mitigation ladder 3 arms × 3 n × 8 seeds.
- **Parallel slices re-verified this session with real fits** (`GLLVMTMB_HEAVY_TESTS=1 NOT_CRAN=true`):
  B4 cluster2-slope 10 ✓ · E2 reml-bridge 14 ✓ · D residuals-family-breadth 23 ✓ · E3 delta
  positive-part 14 ✓ · C1 nbinom1 masked 20 ✓ — **81 pass / 0 fail** (evidence, not assertion).
- Coverage claims scored by `pilot_scale_gate_eval` (health denominators + MCSE); gaussian recovery
  and nbinom2 φ-lever both confirmed by direct measurement, not assertion.
- Metric bug noted (not yet fixed): `ci_missing_rate = -4` (coverage_eligible_n counts trait-checks
  ~5× n_converged_fits) — Repair #5, does not change any verdict.

## Follow-up (needs maintainer steer)
1. **n_sim=2000 core-2 grid** (gaussian+binomial) — now justified (adjudicates the 3 marginal
   cells + the 0.82 binomial cell); 6–24h Totoro, ≤100 cores. Now-vs-overnight = Shinichi's call.
2. **Shared-dispersion (`disp.formula`/`disp_group`)** build — the literature-backed nbinom2 fix,
   ~50 LOC per the May scout; build this cycle vs park as documented 0.6+ lane = Shinichi's call.
3. **Repair #5** — align `coverage_eligible_n` / `n_converged_fits` units before any CI-missing gate.
4. **Doc honesty:** intervals stay point-only/recovery-only on public surfaces until the grid earns
   the certificate; nbinom2 fenced with the cited confound caveat. Widget does NOT flip yet.

## State
gaussian coverage bug fixed + verified; nbinom2 confound fully characterised + literature-grounded;
core-2 near-passing pending the n_sim=2000 adjudication. All work uncommitted on
`claude/release-0.5.0`. No CRAN action. The page-by-page doc-honesty review WITH Shinichi remains
the standing pre-0.6 gate.
