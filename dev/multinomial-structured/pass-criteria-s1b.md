# Pre-registered pass criteria — s1b replication-rescue cell (SIGNED)

Declared 2026-08-16 BEFORE the campaign ran (Shinichi approved the design in
session: "Yes go ahead"). Tests the documented rescue mechanism for the
failed s1/s2 recovery gates: per-species REPLICATION (Design 84 / FAM-20A:
"V recovers with per-species replication or large N").

## Design

- DGP: `dgp_multinomial_replicated()` — n_sp = 300 species on a coalescent
  tree; ONE species-level liability draw a_s ~ MVN(0, V ⊗ A_corr) with
  V from sd = (0.8, 0.8), rho = 0.6; n_rep = 5 independent categorical
  draws per species from the SAME species liability (eta_s = b0 + a_s).
- Fit: `phylo_latent(species, d = 2, tree = tree)` (the admitted canonical;
  engine-identical to animal/kernel latent and phylo_dep, so the verdict
  transfers to FAM-20C/D by the proven engine identity).
- 20 seeds; extraction `extract_Sigma(level = "phy", part = "shared",
  link_residual = "none")`.

## Frozen criteria

Aggregate over seeds with convergence == 0 AND PD Hessian (non-PD counted
and reported, excluded from bands):
1. Rail rate (any |rho_hat| > 0.99): **> 6/20 = FAIL** regardless of the rest.
2. Median rho_hat ∈ **[0.35, 0.75]** (true 0.6; replication should shrink
   the one-draw attenuation).
3. Median per-contrast SD ratio (est/true) ∈ **[0.5, 2.0]**, both contrasts.
4. Direction-correct rate (rho_hat > 0) ≥ **16/20** of non-railed seeds.

Bands are frozen as of this commit; they will not be widened after seeing
results. A FAIL here is recorded as "replication at this design does not
rescue recovery" — the register then keeps point-estimate-only honesty.

## Provenance note (D-43 completion panel R6, 2026-08-16)

**Stated plainly, not glossed over: this pre-registration is NOT
git-verifiable.** This file, the DGP script
(`dgp-multinomial-replicated.R`), and the campaign's results CSV
(`results/s1b-replication-summary.csv`) all landed in ONE commit
(`438a156f`) — there is no earlier commit showing this criteria file
existing before the results were computed. The claim that the
declaration preceded the campaign rests on Shinichi's in-session
approval ("Yes go ahead") reported at the time, not on git history
independently proving the sequence. This does not retract the PASSED
verdict (the criteria themselves are the same either way, and nothing
about them was tuned post hoc to fit the observed numbers), but the
git-provenance guarantee the other pass-criteria files' separate
draft-then-results commits provide does not apply here, and this file
should not be cited as though it does.
