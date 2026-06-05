# After Task: SPA-09 spatial_latent non-Gaussian slope gap closed

**Branch**: `claude/random-slopes-dependence-status-bHMFb`
**Date**: `2026-06-05`
**PR**: #453 (merged) — squash `3490564`
**Roles (engaged)**: Claude (evidence + CI gate), Rose (no-fake-pass / overpromise prevention)

## 1. Scope

Close one of the three remaining random-slope/dependence gaps identified in
the 2026-06-04 capability review: **SPA-09**, the
`spatial_latent(1 + x | site, d = 1)` augmented block-diagonal reduced-rank
slope, which was `covered` for four families but `partial` for three
(binomial-logit, ordinal_probit, nbinom2) that honest-skipped at the default
heavy fixture.

## 2. Outcome — CLOSED (covered, all seven families)

The three borderline families were a finite-sample **power** artifact, not
non-identifiability — they were already on the `R/fit-multi.R`
`use_spde_latent_slope` allowlist; Design 35 SPA-09 already recorded they are
PD at `n_sites = 150`. The fix threaded `n_sites`/`seed` through the cell
driver and ran those three at `n_sites = 150L` (the four already-PD families
keep `n_sites = 100L`, no regression). **No engine / `src` code changed.**

## 3. Checks run (CI-gated; no R/TMB in the web container)

New gate `spatial-latent-slope-nongaussian-recovery.yaml` (mirrors the
`spatial_indep` / `spatial_dep` recovery gates), heavy
(`GLLVMTMB_HEAVY_TESTS=1`) on the code commit:

```
spatial_latent non-Gaussian suite: 0 failed, 0 errored, 0 skipped across 7 tests
No skipped cells -- all seven families non-skipped (SPA-09 candidate covered).
```

R-CMD-check (ubuntu-latest, release): green. Register SPA-09 flipped to
`covered` (all seven) and a `NEWS.md` entry added only AFTER the gate was
green (no-fake-pass).

With this, the **spatial random-slope grid is complete** (scalar / indep /
latent / dep × all families) alongside the phylo side.

## 4. Follow-up / HANDOFF to Codex + maintainer

The other two gaps and VA are NOT quick wins; they are the deliberately-hard
remainder and fit the "Claude gathers evidence → maintainer decides → Codex
implements bounded code" rhythm. None is verifiable in the web container (no
R/TMB) — all must be CI-gated.

- **RE-03 — non-Gaussian `s ≥ 2` (two+ random slopes).** Gaussian
  `phylo_dep(1 + x1 + x2 | sp)` is already `covered` (the C++ dep likelihood
  is dimension-general in `C = n_lhs_cols`). Non-Gaussian `s ≥ 2` is
  reserved. **This needs NEW work, not a dispatch:** the existing
  `dep-slope-identifiability-sweep.yaml` has **no `s` parameter** (it sweeps
  s=1 only). Codex step 1 = add an s=2 sweep harness (full
  `(1+s)T × (1+s)T` `Sigma_b`) and run it to establish whether non-Gaussian
  s=2 is identifiable at feasible n; step 2 (maintainer-gated, high-risk) =
  relax the dep-slope family guard for the s=2 case ONLY after a recovery
  cell passes non-skipped, mirroring PHY-18 / SPA-10.
- **FG-07/08/09 — known-V non-Gaussian.** Bare `dep`/`indep`/`scalar`
  `(0 + trait | unit)` with `propto()`/`equalto()` known V, under
  non-Gaussian families. The register calls this "the genuinely-hard
  identifiability item"; lowest odds of closing. Feasibility sweep first.
- **VA (variational approximation).** Already audited — Design 72 +
  `2026-06-03-va-feasibility-audit.md` on `claude/va-feasibility-audit`.
  Recommendation is a **conditional GO on Phase 1 only**: a falsifiable
  VA-vs-Laplace-vs-truth proof-of-mechanism benchmark on existing fixtures,
  NOT full implementation. Biggest named risk: structured-covariance KL
  scalability (keeping the variational covariance sparse/Kronecker against
  the exact phylo `A⁻¹` / SPDE `Q` / meta `V` priors for non-Gaussian
  families). ELBO ≠ marginal likelihood, so AIC/LRT stop being cross-method
  comparable; VA's downward variance bias means a "converged" VA fit can be
  worse than an honest LA skip.

## 5. Session-state note

SPA-09 is the only one of the four that was a genuine quick win, and it is
landed + CI-verified + merged. The remaining three are research/engine-scale
and are handed off above rather than rushed.
