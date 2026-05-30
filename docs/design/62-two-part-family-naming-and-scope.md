# 62 — Two-part (delta / hurdle) families: naming and scope decision

**Status date:** 2026-05-30
**Decision owner:** maintainer (S. Nakagawa); recorded by capability-completion lane.

## Context

The package ships two two-part response families — `delta_gamma()` and
`delta_lognormal()` (each with `type = "standard"` and Thorson-2018
`"poisson-link"`) — plus `truncated_poisson()` (the zero-truncated count
that is the positive part of a count hurdle). There is **no
zero-inflation machinery** in the package (no `ziformula`, no
`zi_poisson` / `zinb`).

## Decision 1 — Naming

Keep the **`delta_*`** prefix. Describe these in prose as **"two-part
(hurdle / delta) models, conditional on presence."** Do **not** call them
"zero-inflated."

Rationale:
- **Audience.** `delta_gamma` / `delta_lognormal` is the established
  term in the SDM / fisheries audience (Pennington 1983; Thorson 2018,
  "Three problems with the conventional delta-model"). 
- **API parity with sdmTMB.** sdmTMB uses the same family names and the
  same `type = "poisson-link"` switch; matching it lets users move
  between packages without relearning.
- **It is already documented this way** (roxygen: "Delta/hurdle model
  families", `link1`/`link2`, `type`).

The three concepts are distinct and must not be conflated:

| Model | Sources of zeros | Second part | In package |
|---|---|---|---|
| Hurdle / delta (conditional) | one (binary presence) | strictly-positive, or zero-truncated count | yes |
| Zero-inflated | two (structural + the count's own sampling zeros) | untruncated count that can emit 0 | no |

Calling a delta family "zero-inflated" is a category error — there is no
second zero source. Reserve "zero-inflated" (`zi_*`) strictly for a
future true-ZI count family if one is ever added.

## Decision 2 — Scope: no latent / random structure on two-part families

Two-part families are offered as **fixed-effect response distributions
only.** They do **not** carry latent variables or random effects (no
`latent()`, `unique()`, `phylo_*`, `spatial_*`, slope, or tier terms).

Rationale (this is the genuinely-blocked piece, ref Design 61 §B11):
- A two-part family has two linear predictors on two non-comparable
  scales: `link1` (logit, presence) and `link2` (log, positive amount).
- The GLLVM latent structure exists to induce **one** interpretable
  residual covariance Σ among species, from which correlations / co-occurrence
  are read.
- Latent structure on a two-part family lives on two scales at once — a
  presence-correlation and an abundance-correlation — with no single
  latent-residual scale on which a species×species correlation is
  defined. The combined correlation is mathematically undefined, not
  merely hard to compute.
- Therefore the JSDM correlation machinery is kept defined **only** on
  single-scale families. Two-part families validate for **fixed-effect
  recovery** (both linear predictors, both links, both `type`s) and are
  excluded from the random-slope / cluster / latent capability matrix by
  design — not by omission.

## Implication for the validation matrix

- `delta_gamma`, `delta_lognormal`: validate fixed-effect parameter
  recovery (link1 + link2, standard + poisson-link). Mark the
  latent/slope/tier cells **N/A by design** (cite this note), not
  "blocked" or "partial."
- This is a permanent scope boundary, reversible only by first solving
  the two-scale latent-residual definition (open research, not a
  validation task).
