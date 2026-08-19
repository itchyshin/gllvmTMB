# Mini plan — rebuilding the two iSDM articles

Status: PLAN. Nothing below is done. Both articles are **already merged** (#1147,
#1156), which is the problem: they shipped before the reviews that found the
defects. Package code is unaffected — this is article quality only.

## Why a rebuild rather than edits

Four independent findings, none of them cosmetic:

| # | finding | source | severity |
|---|---|---|---|
| 1 | The opportunistic arm has **no sampling bias**, so the reason anyone integrates is absent from the design. Pat: she would "wrongly drop her survey arm". | Pat blocking #2 | **fatal to the claim** |
| 2 | Arms weighted 50/50 → the integrated estimate is the **exact midpoint** of the two single-arm means at all four fuzz levels. Mechanical, not a finding. | Pat blocking #3 | **fatal to the claim** |
| 3 | Mesh built on **unprojected lon/lat**. At 54.5 N, 1 deg lat = 111 km but 1 deg lon = 65 km: a **1.72x anisotropy artefact**. `cutoff = 0.8` is 89 km N-S, 52 km E-W. The plot's aspect was corrected; the model's was not. | Shinichi, and Pat blocking #11 independently | high |
| 4 | `offset(log_effort)` is **perfectly confounded** with `isdm_source` (cor = -1): effort is constant within arm, so the source intercept absorbs it. In the article that *teaches* the offset idiom. | measured here | high |

Plus: `spatial_scalar()` does not match the DGP (one shared field with per-species
loadings = `spatial_latent(d = 1)`; measured dLogLik ~ 15 for 1 df), two species
where one is a contrast prop, and `env` `scale()`d separately in training and grid
(Pat #8 — a copy-paste newdata scaling bug, in the article about wrong-scale
covariates).

**1 and 2 together mean the precision article's headline may be an artefact of the
design.** That has to be re-tested honestly, accepting it may not survive.

## The rebuild

**Shared simulation**, used by both articles so they cannot drift apart:

- **20 species** (Shinichi) — makes the joint structure real rather than decorative.
  Measured feasible: 6,000 rows, converges, ~20-25 s.
- **Projected coordinates** via `add_utm_columns()`, domain inside **one UTM zone**
  (the 10-degree span crossed zones and warned).
- **Effort varies within arm** (checklist duration / survey area) so the offset is
  identifiable and the article's own idiom is real.
- **Biased opportunistic arm** — accessibility-driven reporting bias, the thing the
  structured arm exists to correct — with the bias **modelled**
  (`isdm_source:access`), which is what a competent analyst would do.
- **Unequal arm sizes** (large PO, small survey), so integration is the real
  trade-off rather than an average of two equals.
- **`spatial_latent(0 + trait | coords, d = 1)`** to match the DGP.
  `spatial_dep` is also acceptable (Shinichi) and gives a full-rank
  `spde_lv_k` decomposition.

🔴 **Open problem, not yet solved.** With the bias modelled, env-slope recovery is
still poor: `cor(est, true) = 0.67`, `mean|err| = 1.81` against true slopes of SD
0.45. Modelling the bias improved it (4.74 -> 1.81) but did not fix it. **The
rebuild cannot proceed until this is understood** — an article must not
demonstrate a model that does not recover its own truth. Candidate causes, none
confirmed: bias/`env` confounding (both spatial), sparse counts for the
low-intensity species, cloglog near-separation on the detection arm.

## Order of work

1. **Diagnose the recovery failure.** Gate on this. Consider Fable.
2. Rebuild the shared simulation with the six properties above; verify recovery
   before writing any prose.
3. Re-test the precision claim under a **biased** PO arm and unequal arm sizes.
   **Pre-declare** that the claim may not survive, and report it either way.
4. Rewrite both articles against whatever the measurement says.
5. Tufte redraws both figures against the new shape (the map becomes 20 species,
   so small multiples need rethinking — lead with the flagship, or a subset).
6. Florence and Pat re-review **before** merging this time.

## Deferred, filed

- **#1161** — phylogenetic JSDM. `phylo_*(0 + trait | species)` structures the
  species *grouping* (rows); a phylo-JSDM needs the phylogeny on the **trait**
  axis, which is what `gllvm` does across its response columns. Future extension,
  not a blocker.
- Pat's remaining blocking items (4-10) and her ten friction items, to be worked
  through in step 4 rather than piecemeal.
- Florence's figure review — still running at time of writing.
