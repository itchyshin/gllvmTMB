# Phase-0 capability audit — consolidated gap map

**Date:** 2026-07-12. Four read-only audits (slope/tier, missing-data,
diagnostics/intervals, structured-admission), code-verified. In-scope:
{gaussian, poisson, nbinom1, nbinom2, binomial} × {ordinary, phylogenetic,
spatial}. Full reports: `scratchpad/audit-*.md`.

## Meta-finding (the good news)

**The engine machinery is largely family-agnostic and already admits the
in-scope families.** The base structured grid (`phylo_*`/`spatial_*`
scalar/indep/dep/latent) has *no family guard at all*; missing-response and
`mi()` gates don't depend on response family; the augmented single-slope grid
allowlists all five scoped families. So the campaign is **smaller than the
widget implied** — the real work is (a) TEST/RECOVERY coverage for
non-Gaussian, (b) a handful of genuine bugs, (c) a few structural holes, and
(d) finishing nbinom1 (the consistently-thinnest family). It is **not** a
build-from-scratch per family.

## Tier 1 — genuine bugs / correctness (do regardless of scope)

| # | Item | Evidence |
|---|---|---|
| T1.1 | **binomial `cbind(succ, fail)` + `miss_control(response="include")` crashes** — `n_trials <- succ+fail` runs before the NA-sentinel fill | `R/fit-multi.R:1902-1910` vs `1939-1952` |
| T1.2 | **non-Gaussian unit-tier `latent(1+x\|unit)` slope silently drops the diagonal-Ψ companion** (loadings-only, no warning) | slope audit §4 |
| T1.3 | **`extract_phylo_signal` / `extract_repeatability` silently substitute interval methods** instead of aborting — same nominal request behaves differently across entry points | diag/interval audit §3 |
| T1.4 | **NB1 rootogram silently excluded** though exact-residual diagnostics do cover NB1 | diag/interval audit §1 |

## Tier 2 — structural holes (real engine work; scope decision needed)

| # | Item | Evidence |
|---|---|---|
| T2.1 | **`unit_obs` and `cluster2` tiers carry zero random-slope support** — any structure/family. The "each tier takes ≥1 slope" gap. | slope audit §1 |
| T2.2 | **Ordinary `indep()`/`dep()` never admit a slope** — only `latent()` does (unit-tier only) | slope audit §4 |
| T2.3 | **binomial has no exact-residual/rootogram diagnostic route** — only the untested simulation-rank fallback | diag/interval audit §2 |
| T2.4 | **`scalar()` (no-prefix) + `kernel_scalar()`** — approved grammar, not yet built | (task #7) |

## Tier 3 — coverage / recovery evidence (Phase-2 compute; mostly mechanical)

Machinery works but is Gaussian-only-tested. Needs recovery tests vs truth:
- Non-Gaussian **missing-response** (poisson/nbinom1/nbinom2/binomial) — engine confirmed to fit; no tests.
- Non-Gaussian **slope** recovery across structures.
- Non-Gaussian **structured base grid** — gaussian/binomial/poisson/nbinom2 already tested all 4 modes phylo+spatial; **nbinom1 only `indep`**.
- Non-Gaussian **interval routes** (Sigma/corr/communality/repeatability/phylo_signal/bootstrap) — nbinom1 has none.
- **`Sigma_cluster`/`cluster2`, `rho:cluster/cluster2`**: no bootstrap route, point-only off-diagonals.

**nbinom1 is the single thinnest family** across every dimension — a focused
"finish nbinom1" thread closes many cells at once.

## Tier 4 — honesty / docs
- `README.md:181` overclaims response-mask support with no family qualifier.
- Refresh `docs/design/61-capability-status.md` (stale 2026-06-28) + the capability widget from this verified state (the "grammar-guess" cells are now known).

## Scope decisions the audit forces

1. **Slope scope (the big fork).** Two levels:
   - *Minimum:* finish + test what already exists (`latent()` unit-tier +
     structured s=1) — smaller.
   - *Full:* also build the missing structural pieces — **`unit_obs`/`cluster2`
     slope support (T2.1)** and **ordinary `indep`/`dep` slopes (T2.2)**. This
     is the largest single build item; matches "each cluster tier ≥1 slope."
2. **Ordinary `indep`/`dep` slopes** — in or out?
3. Confirm **`unit_obs`/`cluster2` slope** is in (it's substantial engine work).

Tier 1 is unconditional. Tier 3 is the compute campaign. Tier 2 is where the
scope call lands.
