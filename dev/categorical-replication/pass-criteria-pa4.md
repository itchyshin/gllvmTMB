# Pre-registered pass criteria — PA4 combined phylo + non-phylo species replication cells

**STATUS: SIGNED (Shinichi, 2026-08-17, in-session: "sign off - please keep going"). The 20-seed campaigns have NOT
been run and will not run until this file is signed.** Only the D-139 timing
fit and the 2-seed smoke gate run before sign-off (their outputs are recorded
in the Timing appendix below and are not recovery evidence).

This file is committed BEFORE any campaign results exist, restoring the
draft-then-results git provenance that `pass-criteria-s1b.md`'s provenance
note records as missing for the s1b cell.

## What this tests

The paper (Mizuno et al. 2025, eq 38-46) defers the within-species
(non-phylogenetic) variation model for discrete traits to "future
development", naming per-species replication as the practical mechanism.
Design 123's Paper-alignment table carries two "grammatically admitted,
combination UNTESTED" rows for exactly this model — a phylogenetic species
effect a_i (A-structured) AND a non-phylogenetic species effect s_i
(I-structured) in ONE fit — for `ordinal_probit()` (fid 14) and
`multinomial()` (fid 16). PA4 runs the s1b-style replication recovery
campaign for that combined formula.

**Grammatical admission is VERIFIED live** (2026-08-17,
`verify-admission-pa4.R`): all three constructions below fit, converge, and
carry BOTH engine tiers (`use_phylo_rr = 1` AND `use_diag_species = 1`, with
separate `theta_rr_phy` / `theta_diag_species` parameter blocks) on small
probe data. No fence blocks the combination (the multinomial fence's only
whole-fit overrides are the multi-kernel count and the OLRE guard; fid 14
has no fence). This admission check is a precondition, not a recovery
result.

## Cell A — ordinal_probit

- DGP: `dgp_ordinal_replicated()` (this directory) — n_sp = 150 species on
  a coalescent tree, n_rep = 5 replicate observations per species, T = 2
  ordinal traits, K = 4 categories. Liability per trait t, species s:
  `l = b0_t + a_{t,s} + s_{t,s} + e`, with per-trait DIAGONAL phylogenetic
  variance sigma_a^2 = 0.64 (a_t ~ N(0, 0.64 A_corr), independent across
  traits), non-phylogenetic species variance sigma_s^2 = 0.36
  (s_t ~ N(0, 0.36 I)), probit link residual fixed at 1, b0 = (0.9, 0.9),
  true cutpoints tau = (0, 0.9, 1.8) per trait (tau_1 = 0 fixed, Hadfield
  convention).
- Fit (the Design 123 row-522 shape, verified admitted):
  `gllvmTMB(value ~ 0 + trait + phylo_indep(0 + trait | species, tree = tree)
  + indep(0 + trait | species), data, family = ordinal_probit(),
  trait = "trait", unit = "obs", cluster = "species")`.
- 20 seeds: 401-420.
- Extraction: phylo per-trait variances = `diag()` of
  `extract_Sigma(fit, level = "phy", part = "shared", link_residual =
  "none")`; species per-trait variances = `diag()` of
  `extract_Sigma(fit, level = "cluster", link_residual = "none")$Sigma`.
  (Both routes verified live on the probe fit.)

## Cell B — multinomial

- DGP: `dgp_multinomial_replicated_species()` (this directory) — the s1b
  DGP EXTENDED with a non-phylogenetic species effect on the liability:
  n_sp = 300 species, n_rep = 5, K = 3 (2 baseline contrasts);
  `eta_s = b0 + a[, s] + s[, s]` with `vec(a) ~ MVN(0, V (x) A_corr)`,
  V from sd = (0.8, 0.8) and rho = 0.6 (per-contrast phylo variance 0.64),
  and `s[j, s] ~ iid N(0, sigma_s^2)` with sigma_s = 0.6 (variance 0.36);
  b0 = (0.2, -0.3). n_sp/n_rep match the s1b design that PASSED the
  one-tier replication gate.
- Fit (the Design 123 row-521 shape, verified admitted):
  `gllvmTMB(value ~ 0 + trait + phylo_latent(species, d = 2, tree = tree)
  + indep(0 + trait | species), data, family = multinomial(),
  trait = "trait", unit = "obs", cluster = "species")`.
- 20 seeds: 501-520.
- Extraction: phylo V_hat = `extract_Sigma(fit, level = "phy", part =
  "shared", link_residual = "none")` (matrix, or `$Sigma`); rho_hat =
  `V[1,2] / sqrt(V[1,1] V[2,2])`; species per-contrast variances =
  `diag()` of `extract_Sigma(fit, level = "cluster", link_residual =
  "none")$Sigma`.

## Frozen criteria

Aggregate per cell over seeds with `convergence == 0` AND PD Hessian
(non-conv / non-PD counted and reported, excluded from bands). Bands are
frozen as of this commit and will not be widened after seeing results.

1. **Conv+PD accounting (both cells).** Report n_conv_pd / 20. If
   n_conv_pd < 10, the cell is **INCONCLUSIVE** (insufficient fits to
   evaluate the bands), regardless of the surviving seeds' numbers.
2. **Separate variance-component recovery (both cells) — the headline
   gate.** The phylogenetic and non-phylogenetic species components must
   each recover SEPARATELY: for EVERY component below, the median ratio
   est/true over conv+PD seeds must lie in **[0.33, 3.0]**
   (the s2/Arc-1 band). Any component's median outside the band = FAIL
   for the cell.
   - Cell A: 4 components — phylo variance trait 1 and trait 2
     (each /0.64), species variance trait 1 and trait 2 (each /0.36).
   - Cell B: 4 components — phylo per-contrast variances V[1,1], V[2,2]
     (each /0.64), species per-contrast variances (each /0.36).
3. **Rails (Cell B), per the Arc-1/s1b convention.** A seed is railed if
   `|rho_hat| > 0.99`. Rail rate **> 6/20 = FAIL** regardless of the rest.
   Railed seeds are excluded from criterion 4's median but NOT from
   criterion 2's variance medians (rails are a correlation pathology; the
   variance bands must survive them or fail honestly).
4. **rho recovery (Cell B, reported band).** Median rho_hat over
   non-railed conv+PD seeds in **[0.35, 0.75]** (true 0.6), and
   direction-correct rate (rho_hat > 0) >= 16/20 of non-railed seeds —
   the same bands s1b passed WITHOUT the competing s tier; a FAIL here
   with criterion 2 passing is recorded as "the s tier absorbs the phylo
   correlation" rather than a whole-cell FAIL, because rho is not the
   component-separation estimand this cell pre-registers.
5. **Collapse accounting (both cells), issue-#897-aware.** Report, per
   component, the count of conv+PD seeds whose ratio < 1e-3
   (numerical-zero collapse — the silent-degeneracy mode the s2 diagonal
   cell exposed, which NO runtime flag catches for fid 14/16). Reported,
   not gated; a component that passes its median band with >= 5/20
   collapsed seeds must carry the collapse count in any register/prose
   statement.

Interpretation rule: a FAIL on criterion 2 is recorded as "the combined
a_i + s_i decomposition is not separable for this family at this design"
— the Design 123 rows then stay construction-verified-only. No band will
be relaxed post hoc; a re-run at a different design is a NEW pre-registered
cell, not a widening.

## Timing appendix (D-139; filled after the timing fits, before sign-off)

Timing fits (1 seed at full design size per cell) and 2-seed smoke gates
run BEFORE sign-off by design; results recorded here. Projections assume
`CAMPAIGN_CORES = 20` (one seed per core, so wall-clock ~ one fit).

Measured 2026-08-17 on the local Mac (this worktree, `devtools::load_all`),
after the pre-registration commit and before sign-off, as declared above.

- Cell A (ordinal, FULL size n_sp = 150, n_rep = 5, T = 2, K = 4,
  seed 401): elapsed **13.4 s** (conv = 0, pdHess = TRUE). Projected full
  run: 20 fits x 13.4 s ~= **4.5 min serial**, ~0.2 min wall-clock at 20
  cores. (Single-seed point-estimate ratios on this timing fit, NOT
  evidence: phy (0.58, 0.57), sp (1.04, 1.15).)
- Cell B (multinomial, FULL size n_sp = 300, n_rep = 5, K = 3, seed 501):
  elapsed **2.6 s** (conv = 0, pdHess = TRUE). Projected full run: 20 fits
  x 2.6 s ~= **0.9 min serial**. (Single-seed point estimates, NOT
  evidence: rho_hat 0.555, phy ratios (1.05, 0.54), sp ratios
  (1.16, 0.58).)
- Smoke gates (2 seeds, reduced size): Cell A (n_sp = 60, n_rep = 3) 2/2
  fit-and-extract OK, conv 0/0, PD 2/2 — seed 401 shows var_phy2
  collapsed to ~1.6e-10 at this reduced size (the criterion-5 collapse
  mode, expected at small n). Cell B (n_sp = 80, n_rep = 4) 2/2
  fit-and-extract OK, conv 0/0, PD 2/2 — BOTH reduced-size seeds rail
  (rho_hat = 1.0) with one component collapsed each, consistent with the
  known small-N rail behaviour that motivated the s1b full design
  (n_sp = 300); the full-size timing fit above does not rail. The smoke
  gate verifies mechanics (fit + extraction shapes), and these
  reduced-size pathologies are recorded here so they cannot later be
  presented as surprises.

Both cells are far below the D-139 30-minute line (worst case ~4.5 min
serial); the gate on `--mode full` is Shinichi's sign-off of THIS file,
not compute.

## VERDICT (2026-08-17, applied per the frozen gates above; results committed alongside)

- **Cell A (ordinal): PASS.** 20/20 conv+PD; component medians est/true —
  phy1 0.77, phy2 0.82, sp1 1.04, sp2 0.96 — all four in [0.33, 3.0]
  separately. The eq 38-46 combined phylo + species model is EVIDENCED for
  ordinal_probit at n_sp=150 × 5 reps.
- **Cell B (multinomial): FAIL on the rail gate.** 20/20 conv+PD and all
  four component medians in band (phy1 0.97, phy2 0.56, sp1 0.90, sp2
  0.69), but 12/20 seeds railed (threshold >6/20). Interpretation, recorded
  not softened: the variance components separate and recover under the
  combined model, but the among-category correlation — which plain n_rep=5
  replication had rescued (s1b: 4/20 rails) — destabilises again when the
  species tier competes for liability variance at this design. No rho
  recovery claim for the combined multinomial model; components-only.
