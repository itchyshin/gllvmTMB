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
| `a51e9704` | **C1 family generality (partial)** — lognormal(3) + student(9) random slopes admitted (6 gate sites) | recovery fit converges + plausible variance recovery; 10/0 |
| `bcd96888` | **`dep\|\|`** (A2) = Σ_int⊕Σ_slope via Cholesky **parity pin** (`dep_chol_parity_pins`) — the subtle cell | target-matrix test: T(T+1) free, int-slope cov=0, cross-trait cov=0.34 recovered; 7/0 |

| `7d8dc6d4` | **B1 kernel random slopes** — kernel_indep/dep(1+x\|g) route to phylo_slope w/ vcv=K; `\|\|` free | logLik == phylo_*(vcv=A) to 1e-6, all 4 cells; 16/0 |
| `e902f8bd` | **B2a spatial migration** — spatial_indep(1+x) → per-trait block-diagonal | gaussian 9/0 (byte-identity + recovery); non-gaussian structural 9/0; fmesher |
| `93123ea0` | **B2b spatial `\|\|`** — spatial indep\|\|(2T diag) / dep\|\|(T(T+1) parity) | 6/0; indep\|\| converges; parser regression 38/0 |

**B2 spatial COMPLETE.** The `||` coupling axis + per-trait migration now span
phylo / animal / kernel / spatial (indep/dep) + source-tier latent.

**The `||` coupling axis is COMPLETE** for indep/dep/latent (phylo/animal/**kernel** +
source-tier latent). That was the heart of the arc (the maintainer's original `||`
instinct). Kernel random slopes (indep/dep) also landed (B1).

**Pkgdown P1 (pull under-audited articles): already done** by the prior estate-
renewal commits `eacbd0f6`/`3b6f4225` — the six named articles (animal-model,
cross-lineage-coevolution, random-slopes-nongaussian, simulation-recovery-
validated, lambda-constraint-suggest, roadmap) are gone; estate = 19, no dangling
links. (Shinichi's memory of "not taken out" predated that cleanup.)

## Closure check

Full non-heavy `devtools::test()` after all feature commits (incl. B2 spatial):
**4532 pass / 0 fail / 0 error / 958 skip** (heavy), summing the `error` column.
Heavy `||`/kernel/family/spatial recovery cells pass under `GLLVMTMB_HEAVY_TESTS=1`.

**`R CMD check --as-cran` on the final tree: 0 ERRORS / 0 WARNINGS / 1 NOTE**
(the benign "New submission"). The package is CRAN-clean with the full `||`
coupling axis, kernel slopes, spatial migration, and lognormal/student families
integrated.

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

## Remaining (Tier 2) — after the coupling axis

**Done since first draft:** A2 `dep||` (`bcd96888`), A3 `latent||` (`bf541444`),
C1-partial lognormal+student (`a51e9704`). **`||` coupling axis complete.**

Still to do (all locally verifiable — **`fmesher` IS installed**, so spatial needs no INLA):
- **B2 spatial** — TWO parts: (a) migrate `spatial_indep(1+x|coords)` off the old
  shared-field path (`R/brms-sugar.R:4053-4074`, `.spatial_unique_augmented`) to the
  per-trait block-diagonal `use_spde_indep_blockdiag` path (mirrors phylo) — a
  *behavior change*, and `test-spatial-indep-slope-{gaussian,nongaussian}.R` assert the
  OLD contract and must migrate; (b) spatial `||`: extend A0 to route
  spatial_indep/spatial_dep under `||` and append `.uncorrelated` to the **spde**
  covstruct (A0 currently only tags `phylo_slope` calls), then apply block_size=1
  (indep||) / parity (dep||) pins to `theta_spde_dep_chol` (`R/fit-multi.R:4017-4033`,
  flags `use_spde_dep_slope`/`use_spde_indep_blockdiag` at :789/:792 — direct mirror of
  the phylo `use_phylo_dep_uncorrelated` + `dep_chol_parity_pins` I just landed).
- **C1 rest** — tweedie(6) + betabinomial(8). **Finding (this session):** tweedie
  is structurally slope-ready but its random-slope recovery is **empirically
  ridge-biased** — a bare gate-removal fit converges but over-estimates the slope
  SDs by ~44% (the sigma_u^2 <-> p <-> phi ridge flagged by Design 80 + the
  mixed-models lens). So tweedie is NOT a clean gate-removal like lognormal/student;
  it needs a ridge-aware recovery study (fix p or phi, or the ML-vs-REML-gap
  diagnostic) before admission. betabinomial needs a trials/size DGP. Both stay
  gated (the two gate-rejection tests using tweedie remain valid). This is a proper
  follow-up recovery campaign, not a quick win.
- **Kernel `||`** — once B1 wires kernel slopes, kernel `indep||`/`dep||` come for
  free via the existing A1/A2 markers (add kernel_indep/dep to the A0 allowlist).
- **V: `extract_Sigma` for augmented slope fits** — PRE-EXISTING gap (errors on
  BOTH `|` and `||` slope fits identically, so no `||` regression). When built, add
  the `dep||`/`indep||` labels so `dep||` reports Σ_int⊕Σ_slope, not "full
  unstructured" (mixed-models lens). Also `R/profile-route-matrix.R`.
- Plus the original remaining below (B1 kernel engine, B2 spatial, V close-out
  diagnostics/docs/gate/drmTMB issue).

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
