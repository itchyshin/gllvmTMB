# Pre-registered criteria — diagonal-V replication rescue (closes FAM-20D's caveat)

**STATUS: SIGNED** — Shinichi's standing sign-off for this arc's campaigns
(2026-08-17, "sign off - please keep going!"). Committed BEFORE any fit of
this cell ran; results land in a separate later commit.

## What this closes

FAM-20D records: *"The replication rescue is UNTESTED for the diagonal-V mode
— s1b fit only the full-rank parameterisation; do not extrapolate."*
Unreplicated `phylo_indep` on diagonal truth FAILED its Arc-1 gate: the
smaller contrast variance collapsed (median ratio 0.24, 9/20 in band) and
**7/20 seeds collapsed to numerical zero (<= 1e-9) with convergence = 0 AND a
PD Hessian**. s1b then showed that per-species replication (n_rep = 5)
rescues the FULL-RANK cell. This cell asks the same question of the DIAGONAL
mode, which s1b did not touch.

## Design

- DGP: `dgp_multinomial_replicated()` with **diagonal truth** —
  `rho_true = 0`, `sd_true = c(0.8, 0.5)` (matching the corrected Arc-1
  diagonal cell so the comparison is like-for-like), `n_sp = 300`,
  `n_rep = 5`, K = 3, seeds 601:620 (20 seeds).
- Fit: `phylo_indep(0 + trait | species, tree = tree)`, `unit = "obs"`.
- Extraction: `extract_Sigma(level = "phy", part = "shared",
  link_residual = "none")`; per-contrast variance ratios vs truth
  (0.64 and 0.25).

## Frozen gates (not to be widened after results)

Aggregate over seeds with `convergence == 0` AND PD Hessian; non-PD counted
and reported, excluded from bands.

1. **Collapse rate** — seeds with any per-contrast variance <= 1e-9 must be
   **<= 2/20** (unreplicated baseline: 7/20). More than 2 = FAIL regardless
   of the rest.
2. **Median per-contrast variance ratio (est/true) in [0.33, 3.0] for BOTH
   contrasts** — the sd = 0.5 contrast is the one that failed unreplicated
   (0.24).
3. **Per-seed in-band** — >= 14/20 conv+PD seeds inside [0.33, 3.0] on each
   contrast.

Power note (stated up front): with a true collapse rate of 0.35 (the
unreplicated 7/20), P(<= 2/20) = 1.21%, so a pass is strong evidence of a
real change. The band does NOT strongly separate "rescued to ~0" from
"reduced to ~15-20%" (P(<= 2/20 | p = 0.20) = 20.6%), so a pass is worded as
*"collapse rate consistent with substantial rescue"*, never *"eliminated"*.

## Planted-zero sub-cell

`sd_true = c(0.8, 0)` (one contrast genuinely null), 10 seeds (621:630),
same replicated design, fit with the FULL-V `phylo_latent(d = 2)`:
median ratio of the null contrast's variance to the non-null contrast's
**< 0.35** (the model must not invent variance where there is none), and
rails (|rho| > 0.99) **<= 3/10**.

## Detector cross-check (free out-of-sample validation)

`.gllvmTMB_multinomial_degeneracy_row()` is evaluated on every fit of both
sub-cells and its verdict recorded per seed. Expectation stated in advance:
it fires on every collapse seed and on no in-band healthy seed. **A miss or
a spurious firing here is a calibration finding to be reported, not
suppressed** — this cell's fits were not part of the detector's calibration
set, so this is genuine out-of-sample evidence.

## Reporting

FAIL is recorded as *"replication does not rescue the diagonal-V mode at
this design"* and FAM-20D keeps its point-estimate-only honesty. Bands are
frozen as of this commit.
