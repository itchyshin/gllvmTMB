# Random-effects surface arc — start (pkgdown + Strand 0 + A0/A1) — 2026-07-12

**Author:** Claude (opus-4.8) · **Branch:** `claude/release-0.5.0`
**Plan:** `~/.claude/plans/ok-are-you-bubbly-anchor.md` (approved ultra-plan:
pkgdown cleanup + complete the random-effects surface, Tier 2, single lane).

## Scope this session

Kicked off the approved arc. Landed the pkgdown release-track pass, the kernel
silent-mis-parse safety fix (Strand 0), and the **first functional `||` cell**
(A0 parser + A1 engine, `indep||` for phylo/animal, Gaussian, recovery-verified).

## Landed + verified (all committed + pushed)

| Commit | What | Verify |
|---|---|---|
| `640b895a` | rootogram stale-assertion fix (release gate) | test-predictive-diagnostics 19/0 |
| `4f151c8e` | **pkgdown banner → sticky navbar** (P2) — fixes Firefox/all-width content clipping; the fixed-top navbar wrapped labels ("Get started") unpredictably so no `padding-top` cleared it | CSS cascade reasoned (sandbox can't serve localhost); needs visual check on redeploy |
| `9ba03d79` | **kernel slope fail-loud** (Strand 0) — `kernel_*(1+x\|g)` mis-parsed silently; now errors | test-kernel-slope-guard 5/0 |
| `7d8ca4fe` | **`indep\|\|`** (A0+A1) phylo/animal | recovery fit: `\|\|`=2T free, off-diag cor=0; `\|`=3T, rho~0.6; 11/0 |
| `bf541444` | **`latent\|\|`** (A3) source-tier phylo/animal/spatial — `\|\|` spelling routed to the already-uncorrelated latent engine | desugar + logLik identity to `\|`; 15/0 |

**Pkgdown P1 (pull under-audited articles): already done** by the prior estate-
renewal commits `eacbd0f6`/`3b6f4225` — the six named articles (animal-model,
cross-lineage-coevolution, random-slopes-nongaussian, simulation-recovery-
validated, lambda-constraint-suggest, roadmap) are gone; estate = 19, no dangling
links. (Shinichi's memory of "not taken out" predated that cleanup.)

## Key verified recipes (for the remaining slices)

- **`||` interception (A0)** lives at the top of `rewrite()` in `R/brms-sugar.R`
  (~line 2427): detect a `||`-headed `e[[2L]]`, flip to `|`, recurse, append
  `.uncorrelated = TRUE` to the resulting `phylo_slope` call. Currently scoped to
  `phylo_indep`/`animal_indep`; **every other wrapper fails loud under `||`** (no
  silent-correlated fit). To extend a mode, add it to the allowlist + teach its
  engine to read `.uncorrelated`.
- **`indep||` engine (A1)**: `R/fit-multi.R:~1406` sets
  `use_phylo_indep_uncorrelated`; `~3969` passes `block_size = 1L` to
  `dep_chol_crossblock_pins()` (vs `1L + n_phy_slope` for `|`) → fully diagonal.
- **Family generality (C1) is R-only, ZERO C++** (tmb-engineer verdict): the
  `eta`-accumulation engine `src/gllvmTMB.cpp:1798-1938` is family-agnostic;
  lognormal(3)/tweedie(6)/betabinomial(8)/student-t(9) only need the 6 allowlist
  sites relaxed (`R/fit-multi.R:850,857,910,1435,1469,1543`) + a recovery cell
  each (the `#388` discipline; small-cluster + ML-vs-REML-gap acceptance).

## Remaining (Tier 2), in the plan's value order

1. **B2 spatial `indep(1+x)` migration** — re-flip the parser TODO
   (`R/brms-sugar.R:~3980`, `.spatial_unique_augmented`→per-trait block-diagonal
   like phylo), migrate `test-spatial-indep-slope-{gaussian,nongaussian}.R`,
   verify with **fmesher (not INLA)**. Spatial `||` then follows (spde block_size=1
   pin, `R/fit-multi.R:~3982`).
2. **B1 kernel slope engine** — route `kernel_indep/dep(1+x|g)` → the same
   `phylo_slope` augmented call (mirror `animal_indep`, carry `kernel_meta`/vcv=K),
   `kernel_latent` → `use_phylo_latent_slope`; **build kernel-slope extraction**
   (`.kernel_level_alias` has no slope branch). Replaces the Strand 0 fail-loud.
   Then kernel `||` follows (already wired via A1 once the engine routes).
3. **A2 `dep||`** = Σ_int⊕Σ_slope — the SUBTLE one (mixed-models lens): interleaved
   stacking means pin ONLY the cross-block int↔slope entries, leave cross-trait
   int↔int & slope↔slope FREE. **Write the index algebra + a hand-built
   target-matrix unit test BEFORE coding** (else it silently collapses to
   indep-diag). Needs a new modulo/strided pin in `R/lambda-constraint.R`.
4. **A3 ordinary `latent||`** — DONE for source-tier (phylo/animal/spatial,
   `bf541444`). The no-prefix ordinary `latent||` still needs a block-diagonal Λ
   constraint (ordinary `latent(1+x|g)` fits the CORRELATED joint-Λ form, so it
   is the one latent cell where `|`≠`||`).
5. **C1 family generality** — relax the 6 allowlist sites + recovery cell per
   family (lognormal/tweedie/betabinomial/student-t). Zero C++ (verified).
6. **V close-out** — singular/boundary-fit diagnostic for new `||` cells; teach
   `R/extract-sigma.R` + `R/profile-route-matrix.R` the new cells (`dep||` changes
   Σ_b *semantics* without changing *shape* → they'd misreport "full
   unstructured"); `||` cells get their OWN family allowlist; full
   `devtools::test()` **summing `error` too**; `--as-cran`; docs (Design 79/61/80,
   widget `|`/`||` axis, article §8, NEWS); drmTMB `|`/`||` coordination issue.

## Durable rules (to persist to memory/DECISIONS.md)

- **No parallel platform lanes** (Claude ∥ Codex on one repo) — one lane all the
  way, then hand off complete. In-lane sub-agent fan-out is fine.
- The RE arc needs **zero new C++** — Claude runs it end-to-end; Codex only for an
  optional gated multi-seed recovery campaign (not required to ship).

## 0.5.0 release track

`--as-cran` passes after `640b895a` (0E/0W/1N benign "New submission"). Remaining:
the one-by-one doc honesty review (with Shinichi) + merge/tag/submit (his acts).
