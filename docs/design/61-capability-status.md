# 61 -- Capability Status and Dependency-Ordered Work-List

**Status date:** 2026-06-08
**Scope:** status synthesis only. The validation-debt register
(`docs/design/35-validation-debt-register.md`) remains the row-level source
of truth; this document is the readable planning layer.

## Bottom Line

The random-slope surface has moved from "engine in progress" to a bounded
covered capability:

- **IN:** one random slope (`s = 1`) is covered across the structured
  phylogenetic and spatial grid for the core supported families, with
  row-level evidence in PHY-11..PHY-18, SPA-08..SPA-10, and ANI-11..ANI-12.
- **IN:** Gaussian `phylo_dep(1 + x1 + x2 | species)` is covered for
  two random slopes (`s = 2`) under RE-03.
- **PARTIAL:** non-Gaussian `phylo_dep(..., s >= 2)` remains fail-loud
  guarded. The RE-03 diagnostic sweeps show useful feasibility evidence, but
  the admission gate has not cleared.
- **OUT:** zero-inflated, hurdle, and two-stage delta families remain outside
  this random-slope restoration slice. Their latent-scale covariance has two
  response scales and is blocked by FAM-17 / MIX-10.
- **CAUTION:** interval calibration is still separate from point-estimate
  recovery. CI-08 and CI-10 remain open/failing coverage gates.
- **GAUSSIAN ORDINARY REACTION NORMS:** the ordinary unit-tier
  `latent(1 + x | unit, d = K) + unique(1 + x | unit)` / long-form augmented
  decomposition now fits and extracts `Lambda_aug Lambda_aug^T`,
  `Psi_B,aug`, and their total covariance under RE-12. The behavioural
  reaction-norm article is buildable but internal while its plain-language
  reader path is under review; non-Gaussian augmented `unique()` remains
  guarded.

The practical consequence is simple: the public article lane stays narrow.
Ordinary Gaussian individual-level reaction norms, structured random slopes for
`s = 1`, Gaussian structured `s = 2`, and non-Gaussian structured `s >= 2` stay
internal until their reader paths are ready.

## Random-Slope Capability Table

Legend: **covered** = recovery / route evidence exists in the validation
register; **partial** = a useful path exists but not at full advertised
depth; **blocked** = needs a mathematical derivation or different scope.

| Surface | Status | Evidence rows | Public wording |
|---|---|---|---|
| `phylo_slope(x | species)` | covered / legacy | PHY-06, RE-02 | Single shared phylogenetic slope variance; retained for compatibility, not used in new public articles. |
| `animal_slope(x | id)` | covered / legacy | ANI-06 | Pedigree-facing alias for the same legacy slope machinery; not the public ordinary reaction-norm target. |
| `phylo_unique(1 + x | species)` / `animal_unique(1 + x | id)` | covered | ANI-11 | Correlated 2 x 2 intercept+slope block with `extract_Sigma(level = "phy")` read-out. |
| `phylo_indep(1 + x | species)` | covered | PHY-11..PHY-16 | Diagonal intercept+slope block; correlation pinned to zero; core families admitted. |
| `phylo_latent(1 + x | species, d = 1)` | covered | PHY-17 | Block-diagonal reduced-rank random slope; no intercept-slope correlation. |
| `phylo_dep(1 + x | species)` | covered | PHY-18 | Full unstructured 2T x 2T intercept+slope covariance across traits. |
| `phylo_dep(1 + x1 + x2 | species)` under Gaussian | covered | RE-03 | Gaussian full-unstructured multi-slope path; `s = 2` validated. |
| `phylo_dep(..., s >= 2)` under non-Gaussian families | partial | RE-03 | Runtime guard remains; feasibility sweeps continue but this is not admitted. |
| `latent(1 + x | unit, d = K) + unique(1 + x | unit)` ordinary unit-tier Gaussian reaction norm | partial | RE-12 | Gaussian `latent + unique` decomposition implemented with `extract_Sigma(level = "unit_slope", part = "shared" / "unique" / "total")`, deterministic recovery evidence, and a buildable internal behavioural-syndrome draft; non-Gaussian augmented `unique()` remains guarded. |
| `spatial_unique(1 + x | coords)` / `spatial_indep(1 + x | coords)` | covered | SPA-08 | Two-field spatial intercept+slope path; `indep` pins cross-field correlation to zero. |
| `spatial_latent(1 + x | coords, d = 1)` | covered | SPA-09 | Block-diagonal reduced-rank spatial slope across the core families. |
| `spatial_dep(1 + x | coords)` | covered | SPA-10 | Full unstructured 2T x 2T SPDE field covariance; hard cells require large validation fixtures. |
| delta / hurdle / two-stage zero-inflated families | blocked | FAM-17, MIX-10 | Do not advertise random-slope covariance or latent-scale correlation for these families. |

## Latent-Rank `d` Status

`d` is the public argument name. The live guard is `d <= n_traits`; `d ==
n_traits` is valid and tested, while `d > n_traits` aborts.

| Surface | `d` status | Practical next work |
|---|---|---|
| Gaussian latent / structured latent fits | `d = 1` and `d = 2` are the ordinary user-facing ranks; `d = 3` has additional boundary evidence. | Keep examples at `d = 1` or `d = 2` unless the article is explicitly about rank depth. |
| Non-Gaussian latent / structured latent fits | `d = 1` is the strongest structured random-slope evidence; `d = 2` exists in several binary / Poisson latent fixtures but is not yet a broad article claim. | Build a separate rank-depth grid before advertising `d = 3`, `d = 4`, or `d = 6` outside Gaussian examples. |
| `spatial_latent(1 + x | coords, d = 1)` and `phylo_latent(1 + x | species, d = 1)` | covered for the random-slope article lane. | Keep the restored article at `d = 1`; do not make high-rank structured-slope claims in this slice. |

## Article Restoration Queue

| Article | Status after this sync | Return / keep-public condition |
|---|---|---|
| `random-regression-reaction-norms` | internal Gaussian behavioural reaction-norm draft | Uses `unit = "individual"` and `unit_obs = "session_id"` with a shipped long/wide example object, diagnostics, augmented covariance recovery, and repeatability curves. Return after the opening prose, model-choice framing, and uncertainty caveats pass a plain-language Pat/Rose/Fisher review. |
| `random-slopes-nongaussian` | internal structured-grid continuation | Return after the phylogenetic GLLVM and structured-dependence reader path is public. Must cite PHY-11..PHY-18, SPA-08..SPA-10, ANI-11..ANI-12, RE-03, FAM-17, and MIX-10; heavy cells may stay `eval = FALSE`. Keep it separate from the ordinary individual reaction-norm article. |
| `cross-lineage-coevolution` | internal Design 65 C2 workflow | Return after `phylogenetic-gllvm` is public and the article can read as a biological worked example rather than the first explanation of dense kernels, `Gamma`, and supplied `rho`. |
| `phylogenetic-gllvm` | still internal | Can later link to the random-regression article after its own phylo/non-phylo split and helper example pass. |
| `animal-model` | still internal | Needs the larger pedigree fixture and A/Ainv truth recovery before public restoration. |
| `mixed-family-extractors` | still internal | Must keep delta/hurdle blocked cases explicit and avoid CI calibration overclaims. |

## Remaining Work

| Lane | Why it remains | Next bounded action |
|---|---|---|
| RE-03 non-Gaussian `s >= 2` | Current evidence is diagnostic, not admission-grade; weak-family sweeps are still in progress. | Continue targeted `s = 2` sweeps for weak families after the positive-definite fixture repair. |
| Rank-depth validation (`d = 3`, `d = 4`, `d = 6`) | Public examples mostly live at `d = 1/2`; high-rank non-Gaussian structured claims need their own grid. | Design a separate rank-depth recovery table, not bundled with random-slope article restoration. |
| Interval coverage | CI-08 / CI-10 remain separate from point recovery and must not be implied by slope examples. | Keep slope articles point-estimate/recovery framed until coverage gates pass. |
| Delta / hurdle covariance | Two response scales make a single latent residual or slope covariance undefined. | Derivation first; no article or runtime admission in this slice. |
| Ordinary behavioural random regression | The Gaussian Appendix-B-style target is now public as the individual-level article; broader non-Gaussian augmented `unique()` support remains guarded. | Decide whether non-Gaussian augmented `unique()` should stay guarded or get a separate admission grid. |

## Status-Scan Handles

Use these exact handles when auditing future drift:

```sh
rg -n "RE-03|s >= 2|s ≥ 2|two or more random slopes|non-Gaussian s" \
  README.md ROADMAP.md NEWS.md docs vignettes R tests/testthat
rg -n "random-regression-reaction-norms|random-slopes-nongaussian|under audit|forthcoming|engine in progress" \
  README.md ROADMAP.md _pkgdown.yml vignettes/articles docs/dev-log/audits
rg -n "d == n_traits|d = n_traits|d <= n_traits|d = K|d = q|d = 6" \
  docs R tests/testthat vignettes
```
