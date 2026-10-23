# AA-03 Gaussian latent admission contract

**Status:** Completed single-cell production evidence; conditional claim review
pending. This is not a release, API, or broad capability promotion.

## Purpose

This contract tests whether one exact ordinary-Laplace regime can support a
conditional point-estimation statement without altering the status of any
other `CRAN07-AA-03` cell. It is not a broad Gaussian-latent, dependable-core,
diagnostic, interval, release, or API admission.

## Frozen target

The only candidate is the `g_latent_n240` core-registry row:

| Field | Frozen value |
| --- | --- |
| Family / link | Gaussian / identity |
| Formula mode | ordinary `latent(unique = TRUE)` |
| Covariance target | `Sigma = Lambda Lambda^T + Psi`, rank 1, diagonal `Psi` |
| Units / traits | 240 / 3 |
| DGP profile | `base_latent` |
| Estimands | fixed effects, `Sigma_shared`, diagonal `Psi`, and `Sigma_total` |
| Excluded estimands | raw loading signs, orientation, intervals, diagnostic sensitivity |
| Base source | `origin/main` commit `cb312689` |
| Existing frozen evidence | v4 source archive `ca6c3feb474d9cbfb44cec3c08e380e8d5810bef8e226cb5b426a6ade9b5f630` |

The existing v4 family-pair verdict remains `HOLD` /
`characterization_only`. It is historical evidence, not an authority to pool
new attempts with the old pair.

## Retained negative space

These rows remain outside this campaign and retain their existing status:

- `g_latent_n60` remains held and characterization-only;
- `g_latent_rho0`, `g_latent_rho_pos08`, and `g_latent_rho_neg08` remain
  production failures;
- `g_latent_rho_boundary98`, `g_latent_psi_small`, and `g_latent_psi_large`
  remain predeclared held challenges.

No result for `g_latent_n240` can erase, pool with, or generalise across those
rows.

## Evidence protocol

The frozen v4 runner rejects caller-selected cells, so this programme will use
a new AA-03-specific, fail-closed runner rather than modifying v4. Before any
production batch it must:

1. create a source archive and immutable manifest for the fresh AA-03 source;
2. run one `g_latent_n240` smoke attempt from the archive-installed package;
3. retain its seed, fit health, estimands, output hashes, elapsed time, and
   environment receipt; and
4. report the measured estimate for a full all-attempt batch to Shinichi.

The production batch required separate approval. The approved batch used the
predeclared seed schedule and counted every attempt; its retained receipt is
`docs/dev-log/simulation-artifacts/2026-08-12-aa03-production/`. Its evidence
packet includes the matched
`glmmTMB::rr() + diag()` comparator at the same rank, diagonal-Psi residual
model, trait order, fixed effects, objective, and covariance extractor.

## Conditional claim and decision gates

The strongest possible post-review wording is:

> For the exact ordinary native-Laplace, three-trait complete-data Gaussian
> rank-1 `latent(unique = TRUE)` design at 240 units, retained production
> evidence supports point estimation of fixed effects and rotation-invariant
> shared and total covariance, including diagonal Psi targets.

This sentence is permitted only if all retained production attempts and the
matched comparator meet the frozen gates, and Curie/Fisher, Gauss/Noether, and
Rose each sign the resulting evidence and wording review. Otherwise the
existing `partial` / characterization-only boundary remains unchanged.

Any source or installed-package byte change receives a new source identity and
requires its own normal-vignette artifact and applicable platform ladder before
any release decision. This programme grants neither.
