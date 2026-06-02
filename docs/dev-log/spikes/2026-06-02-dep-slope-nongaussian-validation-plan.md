# Plan — non-Gaussian dep-slope validation + guard relaxation (GAP-B1/B2)

**Status:** plan / scope only. Engine + family-guard change = ROADMAP
high-risk → **maintainer-sequenced, not agent fan-out.** Do not merge guard
relaxations without maintainer sign-off and green per-family recovery cells.

**Premise (established):** the identifiability sweep
(`docs/dev-log/spikes/2026-06-01-phylo-dep-slope-identifiability-N-sweep.R`,
after-task `2026-06-02-dep-slope-identifiability-sweep.md`) shows the
non-Gaussian `phylo_dep(1 + x | sp)` full-unstructured covariance is
identifiable at adequate N (finite-sample power, not structural
non-identifiability). The remaining work is *validation cells + staged
guard relaxation*, mirroring how PHY-11..PHY-17 lifted the diagonal and
block-diagonal slope cells. ZERO new C++ — the augmented dep eta is already
accumulated before the family dispatch.

## Sequence (one family per PR, serialize writes to the shared contracts)

Order by the sweep's reliability margin:
**poisson → Gamma → Beta → nbinom2 → ordinal_probit → binomial.**

### Per family, each PR does exactly:

1. **Recovery cell** in `test-matrix-slope-phylo-dep.R` (un-skip the cell
   for that family). It MUST:
   - read `obj$report()$Sigma_b_dep` (the C×C dep covariance), **NOT** the
     2-vector `sd_b` channel (incompatible — the matrix-dep harness's
     existing `sd_b` read is the latent bug to avoid);
   - use n_sp at the sweep-proven level: poisson n_sp≥80;
     Gamma/Beta/nbinom2/ordinal_probit n_sp≥300; binomial multi-trial
     (size≥12) — confirm N from recovery-quality run #3;
   - assert `conv == 0`, `sdreport()$pdHess == TRUE`, and slope-variance +
     cross-(intercept,slope) recovery within the family band inherited from
     the matching `test-matrix-slope-<family>.R` sibling;
   - `skip_if_not_heavy()` + honest-skip on non-convergence, per house style.

2. **Relax the family guard** at `R/fit-multi.R:849`, adding that family's
   runtime `family_id` to the allowlist (currently `c(0L)`), exactly as:
   - `phylo_indep` guard `R/fit-multi.R:826` (`c(0L,1L,2L,4L,5L,7L,14L)`),
   - `phylo_latent` guard `R/fit-multi.R:909` (same allowlist).
   Add the id ONLY after that family's recovery cell is green. Families off
   the allowlist stay reserved fail-loud (keep an allowlist-boundary
   negative test, like `test-matrix-slope-phylo-indep.R`).

3. **Register + docs:** flip the PHY-18 sub-row for that family to
   `covered`, cite the test path, add an after-task report.

### family_id reference (runtime `family_to_id`, R/fit-multi.R:88-97)
gaussian 0 · binomial 1 · poisson 2 · Gamma 4 · nbinom2 5 · Beta 7 ·
ordinal_probit 14.

## spatial_dep (SPA-10, GAP-B2)

Same recipe on the spatial analogue once `phylo_dep` is through:
- confirm transfer with a `use_spde_dep_slope` sweep (extend the harness's
  override to the SPDE-dep path, or add a sibling spike);
- recovery cell in `test-matrix-slope-spatial-dep.R` reading the SPDE-dep
  `Sigma_field` channel;
- relax the `c(0L)` guard for the `use_spde_dep_slope` path in
  `R/fit-multi.R` (the gaussian-only abort split off the base/dep guard).

## Guardrails

- **Do not** repoint the matrix-dep harness's `sd_b` read globally without
  checking every reader; add the `Sigma_b_dep` read in the new cells.
- **Do not** relax a guard ahead of its green recovery cell (the #388
  discipline: a family joins the allowlist only after its cell passes).
- **Do not** parallelize across families in the `.cpp`/TMB map — the
  dep/indep/latent paths share `b_phy_*` / `theta_dep_chol` and the eta
  loop; serialize.
- Multi-start may help the harder small-N cells (the sweep used a single
  start); consider `gllvmTMBcontrol()` restarts in the recovery cells.
</content>
