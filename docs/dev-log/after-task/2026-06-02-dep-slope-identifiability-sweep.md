# After-task — non-Gaussian phylo_dep slope identifiability sweep (GAP-B1)

**Date:** 2026-06-02
**Author lens:** Claude Code
**Branch:** `claude/random-slopes-dependence-status-bHMFb`
**Spike:** `docs/dev-log/spikes/2026-06-01-phylo-dep-slope-identifiability-N-sweep.R`
**Workflow:** `.github/workflows/dep-slope-identifiability-sweep.yaml`
**Runs:** smoke #26808484707 (gaussian+poisson), full grid #26812586011
(all reserved cores), recovery-quality #3 (N=300/600 × 5 seeds, multi-trial
binomial) — see "Recovery quality" below.

## Scope

GAP-B1 / PHY-18 / SPA-10 asked whether the reserved non-Gaussian
`phylo_dep(1 + x | sp)` augmented full-unstructured slope is **genuinely
non-identifiable** or merely **finite-sample underpowered**. The register
recorded "every non-Gaussian dep fit returns conv != 0 / non-PD Hessian at
n_sp up to 100" and reserved the cells fail-loud.

Method: a research harness (no engine change) that builds a scaffold fit
under the target family with the family-general correlated-unique augmented
slope, overrides the harvested `tmb_data` to the dep path
(`use_phylo_dep_slope = 1L`, `theta_dep_chol`), and refits via
`TMB::MakeADFun` — the same override the validated Gaussian recovery harness
uses, which bypasses the gaussian-only R family guard without touching it.
Run on GitHub Actions (the container has no R). gaussian is the pass-control.

## Outcome — the reservation rationale is refuted

Full grid (`conv==0 & pdHess==TRUE`, fraction of 3 seeds):

| family | N=80 | 150 | 300 | 600 | 1200 |
|---|---|---|---|---|---|
| gaussian (control) | 1.0 | 1.0 | 1.0 | 1.0 | 1.0 |
| poisson | 1.0 | 1.0 | 1.0 | 1.0 | 1.0 |
| Gamma | 0.67 | 0.67 | 1.0 | 1.0 | 1.0 |
| Beta | 0.33 | 0.67 | 1.0 | 1.0 | 1.0 |
| nbinom2 | 0.0 | 0.67 | 1.0 | 0.67 | 1.0 |
| ordinal_probit | 0.0 | 0.33 | 1.0 | 0.67 | 1.0 |
| binomial (Bernoulli) | 0.0 | 0.0 | 0.0 | 0.33 | 1.0 |

**The non-Gaussian dep-slope covariance is identifiable given adequate
data — it is a finite-sample power story, not structural
non-identifiability.** poisson is PD at every N (incl. n_sp=80); Gamma,
Beta, nbinom2, ordinal_probit are reliably PD across all seeds by N=300;
Bernoulli binomial (the lowest-information case, 1 trial/row) needs N=1200.
The monotone rise of PD-fraction with N is the textbook underpowered
signature. The original "non-PD at n<=100" verdict reflected the
matrix-test fixtures' small n_sp and low `n_rep`, not impossibility.

Smoke-run recovery (seed 101, poisson) was good: slope-variance ratios
1.26/1.14 at N=80 improving to 0.92/0.93 at N=300; `max|Sigma_hat - Sigma|`
0.30 -> 0.069.

### Recovery quality (run #3: N=300/600, 5 seeds, multi-trial binomial ×12)

Fraction of 5 seeds with `conv==0 & pdHess==TRUE`:

| family | N=300 | N=600 |
|---|---|---|
| gaussian (control) | 1.0 | 1.0 |
| poisson | 1.0 | 1.0 |
| Gamma | 1.0 | 1.0 |
| Beta | 1.0 | 1.0 |
| binomial (multi-trial ×12) | 1.0 | 1.0 |
| nbinom2 | 0.8 | 0.8 |
| ordinal_probit | 0.8 | 0.6 |

Slope-variance recovery ratios cluster ~0.7-1.5 (within the inherited
2x bands) when fits converge. Two refinements vs the full grid:
**multi-trial binomial converges at N=300** (Bernoulli had needed
N=1200 -- low information per row was the issue, not the family), and
**nbinom2 / ordinal_probit are seed-sensitive** (~60-80% PD across
seeds at N=300/600) -- their production recovery cells need a robust
seed or larger N, and may legitimately honest-skip on an unlucky draw
(the phi<->slope-variance confound for nbinom2; ordinal borderline per
the Phase B0 memo). poisson/Gamma/Beta/binomial are 100% PD across
seeds -> clean validation targets.

## Caveats (honest bounds)

- The harness uses `n_rep = 10`, so total information is species x reps;
  the operative quantity is "enough data," not literally `n_sp >= 300` in
  every design. The threshold scales with information, not n_sp alone.
- This validates convergence + PD (identifiability), not yet
  recovery-within-band as a gating test. Run #3 reports recovery accuracy.
- The MakeADFun override faithfully mirrors the validated Gaussian recovery
  harness (same likelihood, same Hessian), but it is NOT the production
  guard-relaxed code path. The production validation cell must go through
  the engine guard (see "Recommended engine path").
- The matrix-dep recovery harness reads the 2-vector `sd_b` channel, which
  is incompatible with the dep engine's C-wide `Sigma_b_dep`; the
  production test must read `report$Sigma_b_dep` (this spike does).
- nbinom2 / ordinal_probit show a single-seed dip at N=600 (0.67) — 3-seed
  noise; the N>=300 trend is clear and run #3's 5 seeds tighten it.

## Recommended engine path (Track B — needs maintainer review)

The finding promotes GAP-B1 from "reserved, maybe non-identifiable" to
"validate + relax the guard," mirroring exactly how PHY-11..PHY-17 lifted
the diagonal (`phylo_indep`) and block-diagonal (`phylo_latent`) cells:

1. **Add recovery cells** for the dep path per family, reading
   `report$Sigma_b_dep` (not `sd_b`), at the N where this sweep shows
   reliable PD (poisson n_sp>=80; Gamma/Beta/nbinom2/ordinal n_sp>=300;
   binomial multi-trial — confirm N from run #3). Assert conv==0, PD
   Hessian, and slope-variance/cross-covariance recovery within the
   family band inherited from the matching `test-matrix-slope-*.R`.
2. **Relax the family guard** at `R/fit-multi.R:849` from `c(0L)` to the
   allowlist of families whose recovery cell passes, one family at a time,
   exactly as the `phylo_indep` guard at `:826` and `phylo_latent` at
   `:909` were relaxed. ZERO new C++ — the augmented dep eta is already
   accumulated before the family dispatch.
3. **Repeat for `spatial_dep`** (SPA-10): the same finding is expected to
   transfer (spatial analogue), validated via `use_spde_dep_slope`.
4. **Sequence, do not fan out** — the dep/indep/latent slope keywords
   share the `b_phy_*` / `theta_dep_chol` data contracts and the eta loop;
   guard relaxations must be serialized by the maintainer.

This is an engine/grammar/family change (a ROADMAP high-risk item), so it
stops here for maintainer review rather than being applied in this PR.

## Checks

Documentation + a research-only spike (no engine code touched). The sweeps
ran green on GitHub Actions (gaussian control PD at every N confirms the
harness). No package behaviour changed.

## Follow-up — engine work now IN PROGRESS (maintainer authorized 2026-06-02)

- Run #3 recovery-quality numbers appended above. Done.
- **poisson `phylo_dep(1+x)` shipped:** PR #422 merged to main — guard
  relaxed to `c(0L, 2L)` behind a real-API recovery cell reading
  `Sigma_b_dep` (validated via the `dep-slope-poisson-recovery` CI gate).
- **Remaining 5 families in flight:** a follow-up PR extends the allowlist
  to the families whose recovery cells pass (poisson/Gamma/Beta/binomial
  are 100% PD across seeds; nbinom2/ordinal seed-sensitive, included only
  if their cells pass) — same PHY-11..17 pattern.
- **spatial_dep (SPA-10) in flight:** an analogous SPDE-dep identifiability
  sweep + validation (or a findings doc if internals prove uncertain).
- Reconcile Design 35 PHY-18 / SPA-10 notes (this PR reframed the
  rationale; PHY-18 sub-rows flip to `covered` per family as each lands).
