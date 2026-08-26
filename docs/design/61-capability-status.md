# 61 -- Capability Status and Dependency-Ordered Work-List

**Status date:** 2026-07-20 (covariance-grid correction; row-level register remains authoritative)
**Scope:** status synthesis only. The validation-debt register
(`docs/design/35-validation-debt-register.md`) remains the row-level source
of truth; this document is the readable planning layer.

## 2026-07-12 update — covariance-mode taxonomy + tested tier

**Canonical taxonomy: [Design 79](79-covariance-mode-taxonomy.md).** The
covariance grid is now specified on two orthogonal axes — mode (scalar/indep/
dep/latent, cross-trait) × correlation coupling (`|` correlated / `||`
uncorrelated, intercept–slope). Design 79 supersedes Design 55 §5 ("scalar NOT
APPLICABLE to slopes" — now applicable, as a shared-across-traits G-matrix).

**Landed Design 79/80 contract (corrected 2026-07-20).** Intercept-only cells
retain their existing meanings. For one random slope, `*_indep(1+x | g)` now
uses an interleaved `2T` covariance with `T` independent 2 by 2 trait blocks:
cross-trait blocks are zero and each within-trait intercept-slope correlation
is free (`3T` covariance parameters). `*_indep(1+x || g)` additionally fixes
those within-trait correlations to zero (`2T` variances). `*_dep(1+x | g)` is
full unstructured `2T` by `2T`; `*_dep(1+x || g)` retains separate full
intercept and slope covariance blocks while fixing every intercept-slope
covariance to zero. Source-tier `*_latent(... || ...)` routes to the existing
uncorrelated separate-loading form. Ordinary no-prefix latent `||` remains a
separate deferred cell.

**Landed (non-breaking):** `scalar()` no-prefix intercept-only keyword
(byte-identical to `indep(common = TRUE)`), tested; the capability widget gains a
**tested** tier and phylo/animal/spatial + `kernel_latent` flip amber→tested
(recovery tests already existed — the label was stale, not the code).

The old shared-2x2 channels remain only for the distinct `*_unique(1+x)`
compatibility/canonical paths where still wired; they must not be used to
describe current `*_indep(1+x)`. Remaining deferred cells include ordinary
no-prefix latent `||` and any family/mode combination lacking its own evidence.

## 2026-06-28 Truth Sync

The register currently contains 221 identifier rows. This document does not
maintain a single-status tally: several rows deliberately contain mixed
covered/partial/blocked sub-scopes, so a hand total would be misleading. Public
prose must cite the exact covered regime instead of generalising a row label.

Two near-term status surfaces need to stay separate:

- PR #538 (`docs: clarify JSDM screening scope`) merged on 2026-06-23
  at `475cd7a`, so `origin/main` now includes the JSDM screening scope
  polish and fixed-effect-zero article boundary updates.
- The mission-control widget and issue #340 are operating surfaces. They
  must be refreshed from this register before they are treated as current
  evidence.

`Xcoef_fixed` is now implemented within the `MIS-34` covered scope:
zero fixed-effect constraints in native ML fits and admitted Julia
fixed-effect-X rows. `REML = TRUE`, non-zero fixed values, Julia
per-trait intercept pinning, mixed-family-X, masks+X, NB1-X,
ordinal-X, and unsupported Julia fixed-effect-X families remain gated.

The current power pilot remains diagnostic only. Do not promote `CI-08`
or `CI-10` until the pilot reports target-explicit coverage, MCSE, and
fit-health denominators for the corrected estimands.

Design 73 adds a new predictor-informed latent-score lane:
`latent(..., lv = ~ x)`. This is now a C1 **partial** capability for
ordinary unit-tier `latent()` fits. Gaussian fits have parser/API
preflight, TMB score-mean plumbing, `B_lv_unit = Lambda alpha^T`, and
point-estimate extractors. Pure binomial logit/probit/cloglog fits are
now admitted through the same score-mean path with multi-trial and
single-trial trait-scale `B_lv` recovery/algebra and separation
diagnostics. Ordinary Gaussian factor-valued `lv` predictors now have
runtime/recovery evidence for the trait-by-level `B_lv` target, rare
nonempty factor levels, and empty-level rejection. The validation
register records `FG-18`, `RE-13`, `EXT-31`, `LV-01`, `LV-03`,
`LV-04`, and `LV-05` as partial rows; `LV-02` as covered for native
Gaussian recovery/interval evidence; and `LV-06` and `LV-07` as
blocked. Focused native TMB Gaussian recovery now exists for
rotation-stable `B_lv` and `Sigma` targets, and the local r500
Gaussian Wald grid records one seed per replicate, MCSE, failed-fit
denominators, and paired normal-critical / unit-df t-critical
comparator rows for four ordinary Gaussian `B_lv` cells. The local
2026-06-30 binomial r500 grid now adds interval evidence for the three
rank-1 multi-trial standard-link cells: logit, probit, and cloglog. All
1,500 binomial fits converged with positive-definite Hessians and usable
`sdreport()` output, and all 18 target/method rows passed the 0.92--0.98
coverage band. A third, deliberately loadings-only tier now covers the frozen
19-cell mixed/sentinel native ML allow-list at rank one with complete
responses: all 3,800 r200 attempts are retained, all optimizers converged, 11
strict point exclusions remain visible as gradient failures, and every named
cell passed the pre-frozen `B_lv`, shared `Lambda Lambda^T`, intercept, and
score-identity gates. That campaign used `se = FALSE`; it is point-recovery
evidence with no interval conclusion. The separate pure r200 retained all
3,800 attempts and passed 17 of 19 pure cells; pure Beta is held for its 0.91
convergence rate and pure ordinal-probit is held for shared-Sigma bias. The
eight-archetype mixed r500 retained all 4,000 attempts and 3,999 eligible
intervals; all eight named Gaussian-anchor cells passed target-wise `B_lv`
Wald coverage (0.920--0.966). This does not establish simultaneous all-target
coverage or arbitrary-mixture calibration. Missing `lv`
predictors, non-Gaussian response masks, fixed-effect `X + X_lv`, nonstandard
binomial links, arbitrary family mixtures, ranks above one for the programme
cells, default `+ Psi` programme cells, tier-expanded / structured-source
support, Julia mixed-family rows and bridge intervals, and broad Julia bridge
parity remain gated until their own evidence lands.

Guard note: current Design 73 C1 parser tests reject any ordinary
fixed-effect RHS covariate beside `latent(..., lv = ~ x)`, including exact
overlap and non-overlap formulas. This is fail-loud evidence only; it does
not admit combined `X + X_lv` fits.

## Bottom Line

The random-slope engine grid exists, but scientific admission is family- and
covariance-mode-specific:

- **IN:** one random slope (`s = 1`) has admitted cells across the structured
  phylogenetic and spatial grid, with row-level evidence in PHY-11..PHY-18,
  SPA-08..SPA-10, and ANI-11..ANI-12. This is not a uniform grid-wide claim:
  PHY-11 binomial is structural-health only and PHY-16 ordinal has no recovery
  promotion.
- **PARTIAL C1:** lognormal and Student-t are intentionally permitted by the
  six family-agnostic augmented-slope guards after one adequate-N
  `phylo_indep()` seed per family. That evidence checks convergence and pooled
  slope-SD plausibility only; direct mode-specific recovery, Hessian/gradient,
  replicated-seed, and calibration evidence remain open.
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
  `latent(1 + x | unit, d = K)` / long-form augmented decomposition now fits
  the default `Lambda_aug Lambda_aug^T + Psi_B,aug` covariance and extracts the
  shared, unique, and total pieces under RE-12. The behavioural reaction-norm
  article is buildable but internal while its plain-language reader path is
  under review; explicit augmented `unique()` remains Gaussian-only
  compatibility syntax, and non-Gaussian augmented `unique()` remains guarded.

The practical consequence is simple: the public article lane stays narrow.
Ordinary Gaussian individual-level reaction norms, structured random slopes for
`s = 1`, Gaussian structured `s = 2`, and non-Gaussian structured `s >= 2` stay
internal until their reader paths are ready.

## Random-Slope Capability Table

Legend: **covered** = recovery / route evidence exists for the named
family-by-mode cells in the validation register, not for every
runtime-permitted family; **partial** = a useful path exists but not at full
advertised depth; **blocked** = needs a mathematical derivation or different
scope.

| Surface | Status | Evidence rows | Public wording |
|---|---|---|---|
| `phylo_slope(x | species)` | covered / legacy | PHY-06, RE-02 | Single shared phylogenetic slope variance; retained for compatibility, not used in new public articles. |
| `animal_slope(x | id)` | covered / legacy | ANI-06 | Pedigree-facing alias for the same legacy slope machinery; not the public ordinary reaction-norm target. |
| `phylo_latent(1 + x | species, unique = TRUE)` / `animal_latent(1 + x | id, unique = TRUE)` | covered for cited route-specific core cells; partial for lognormal/Student-t | ANI-11, PHY-17, RE-14 | Folded taught spelling: reduced-rank slope (PHY-17) plus the correlated intercept+slope Psi companion (ANI-11; the deprecated standalone `*_unique` spelling is the validated companion). IDs 3 and 9 are runtime-permitted but lack direct folded-latent recovery. Read out via `extract_Sigma(level = "phy")`. |
| `phylo_indep(1 + x | species)` | partial | PHY-11..PHY-16; RE-14 | Family-specific Design 79/80 `2T` block-diagonal `Sigma_b`: cross-trait blocks are fixed at zero, while each `|` trait block retains a free intercept-slope correlation. Binomial has structural-health evidence only, ordinal lacks recovery, and lognormal/Student-t have only one-seed C1-partial evidence; do not describe all permitted families as scientifically admitted. |
| `phylo_latent(1 + x | species, d = 1)` | covered for registered core cells; partial for lognormal/Student-t | PHY-17; RE-14 | Block-diagonal reduced-rank random slope; no intercept-slope correlation. Lognormal/Student-t are mechanically permitted from the family-agnostic engine but lack direct route-specific recovery. |
| `phylo_dep(1 + x | species)` | covered for registered core cells; partial for lognormal/Student-t | PHY-18; RE-14 | Full unstructured 2T x 2T intercept+slope covariance across traits. Lognormal/Student-t are mechanically permitted but lack direct dep recovery. |
| `phylo_dep(1 + x1 + x2 | species)` under Gaussian | covered | RE-03 | Gaussian full-unstructured multi-slope path; `s = 2` validated. |
| `phylo_dep(..., s >= 2)` under non-Gaussian families | partial | RE-03 | Runtime guard remains; feasibility sweeps continue but this is not admitted. |
| `latent(1 + x \| unit, d = K)` ordinary unit-tier Gaussian reaction norm | partial | RE-12 | Gaussian default `latent()` decomposition implemented with `extract_Sigma(level = "unit_slope", part = "shared" / "unique" / "total")`, deterministic recovery evidence, and a buildable internal behavioural-syndrome draft; explicit `+ unique(1 + x \| unit)` remains Gaussian-only compatibility syntax, and non-Gaussian augmented `unique()` remains guarded. |
| `spatial_unique(1 + x | coords)` | covered for registered core cells; partial for lognormal/Student-t | SPA-08; RE-14 | Shared 2 by 2 intercept-slope SPDE field covariance; this is the base `spde_base_slope` channel, not current `spatial_indep`. |
| `spatial_indep(1 + x | coords)` | covered for registered core cells; partial for lognormal/Student-t | SPA-08; RE-14 | Current Design 79/80 interleaved `2T` block-diagonal field covariance with one free 2 by 2 block per trait (`spde_indep_slope`). |
| `spatial_latent(1 + x | coords, d = 1)` | covered for registered core cells; partial for lognormal/Student-t | SPA-09; RE-14 | Block-diagonal reduced-rank spatial slope. Lognormal/Student-t lack direct route-specific recovery. |
| `spatial_dep(1 + x | coords)` | covered for registered core cells; partial for lognormal/Student-t | SPA-10; RE-14 | Full unstructured 2T x 2T SPDE field covariance; hard cells require large validation fixtures. Lognormal/Student-t lack direct dep recovery. |
| delta / hurdle / two-stage zero-inflated families | blocked | FAM-17, MIX-10 | Do not advertise random-slope covariance or latent-scale correlation for these families. |

## Latent-Rank `d` Status

`d` is the public argument name. The live guard is `d <= n_traits`; `d ==
n_traits` is valid and tested, while `d > n_traits` aborts.

| Surface | `d` status | Practical next work |
|---|---|---|
| Gaussian latent / structured latent fits | `d = 1` and `d = 2` are the ordinary user-facing ranks; `d = 3` has additional boundary evidence. | Keep examples at `d = 1` or `d = 2` unless the article is explicitly about rank depth. |
| Non-Gaussian latent / structured latent fits | `d = 1` is the strongest structured random-slope evidence; `d = 2` exists in several binary / Poisson latent fixtures but is not yet a broad article claim. | Build a separate rank-depth grid before advertising `d = 3`, `d = 4`, or `d = 6` outside Gaussian examples. |
| `spatial_latent(1 + x | coords, d = 1)` and `phylo_latent(1 + x | species, d = 1)` | Engine and recovery evidence exists at rank one. | Do not convert the engine matrix into a broad worked-article claim. A future applied guide must distinguish the block-diagonal latent estimand from `indep` and full `dep`. |

## Article Restoration Queue

| Article | Status after this sync | Return / keep-public condition |
|---|---|---|
| `random-regression-reaction-norms` | public Gaussian behavioural reaction-norm guide; maintainer visual approval pending | Uses a corrected within-individual context design, long/wide fits, public extractors, complete diagnostics, block-specific recovery, and pointwise repeatability over common support. |
| `random-slopes-nongaussian` | live in `_pkgdown.yml` nav (unhidden 2026-08-16, commit `60318d48`); tier 3 / under-audit developer note, not yet a full public claim | Promote out of tier 3 once it has one applied phylogenetic or spatial question with a fixed population slope, aligned DGP and covariance mode, adequate within-unit context coverage, runnable public-API code, and a scientific figure. Keep engine matrices and recovery tolerances in developer evidence. |
| Future fixed cross-lineage covariance guide | deferred; the coevolution-labelled pkgdown draft was retired | Use association-conditioned language, the live latent-only multi-kernel model, actual fitted output, public diagnostics, explicit `Gamma_shape` / fixed-rho effect / pair-specific covariance scales, and no causal or novelty claim. Keep Paper-2 hypotheses, fixture thresholds, and open inferential gates in design records. |
| `phylogenetic-gllvm` | public Gaussian covariance guide; maintainer visual approval pending | Keep reaction norms and behavioural tiers out of this focused full-phylogenetic-covariance workflow. |
| Future quantitative-genetics guide | deferred; the flawed animal-model article was retired | Requires an informative pedigree, repeated records, explicit environmental components, stable public heritability/genetic-covariance extractors, and replicated recovery evidence. |
| Future applied mixed-response guide | deferred | The former extractor catalogue was retired. A future guide needs a likelihood-aligned applied fixture, explicit family/link scales, complete diagnostics, and point-estimate-only interpretation until interval calibration is established. |
| Future applied ordinal guide | deferred | The former threshold-family reference was retired after its one-observation-per-cell fixture collapsed the planted variance despite passing numerical diagnostics. A future guide needs replicated or structured data, non-boundary recovery, category-probability interpretation, and a reconciled `link_residual` liability-scale contract. |
| Future psychometrics / IRT guide | deferred; the mixed-response draft was retired | Start from a validated item-response fixture with correct item coding, lower-triangular anchors that preserve every factor, public loading and score extractors, item difficulty/discrimination interpretation, an external comparator, complete diagnostics, and calibrated uncertainty. Do not advertise psychometrics as a package domain until that reader path exists. |
| Future cross-package agreement guide | deferred; the comparator article was retired | Use versioned, estimand-aligned fixtures with healthy fits in every engine, predeclared tolerances, truth recovery, rank/subspace and covariance checks, and durable outputs. Separate shared-engine port regression from independent implementation agreement, and keep interval calibration separate from point-estimate parity. |
| Future interval-validation evidence guide | deferred; the profile-Psi smoke article was retired | Use current-version, target-explicit production artifacts for total covariance and reader-interpreted derived quantities. Report attempted fits, fit-health and interval failures, unconditional denominators, Monte Carlo intervals, bias/RMSE, and calibrated acceptance rules. The historical smoke and failed production evidence remains in design and audit records. |
| Future simulation-verification guide | deferred; the misaligned workflow article was retired | Require an exactly aligned DGP, evaluated end-to-end checks, repeated predeclared datasets, bias/RMSE and Monte Carlo uncertainty, and an explicit distinction among known-DGP recovery, fitted-model self-consistency, predictive checking, and scientific validity. |
| Public roadmap wrapper | retired; `ROADMAP.md` remains contributor-only | Reader-facing support is defined by the current article navigation and per-page boundaries. Internal agent coordination, validation IDs, restoration gates, and planned work are not rendered as package documentation. |
| Future functional-biogeography capstone | deferred; the unhealthy composite article was retired | Use a biologically named fixture or real dataset, stagewise component-aligned fits with a hard diagnostic stop, long/wide equivalence, truth comparison at every tier, evidence-based design guidance, uncertainty for the named regime, and associational sensitivity language. Do not reuse the failed composite fit or its unsupported universal sample thresholds. |

## Remaining Work

| Lane | Why it remains | Next bounded action |
|---|---|---|
| Simulation-validation helper correctness | `check_identifiability()` currently treats a near-zero mean absolute Procrustes residual as factor collapse even though that is close recovery, accepts optimiser convergence or a positive-definite Hessian rather than requiring a healthy conjunction, and leaves its documented coverage column uncomputed. `coverage_study()` excludes failed refits and unusable bounds from the coverage denominator while applying an uncalibrated 94% binary flag at small replicate counts. | Repair the estimands, health gates, failure denominators, Monte Carlo decision rule, reference help, and operating-characteristic tests before these helpers are taught as validation tools. |
| RE-03 non-Gaussian `s >= 2` | Current evidence is diagnostic, not admission-grade; weak-family sweeps are still in progress. | Continue targeted `s = 2` sweeps for weak families after the positive-definite fixture repair. |
| Rank-depth validation (`d = 3`, `d = 4`, `d = 6`) | Public examples mostly live at `d = 1/2`; high-rank non-Gaussian structured claims need their own grid. | Design a separate rank-depth recovery table, not bundled with random-slope article restoration. |
| Interval coverage | CI-08 / CI-10 remain separate from point recovery and must not be implied by slope examples. | Keep slope articles point-estimate/recovery framed until coverage gates pass. |
| Delta / hurdle covariance | Two response scales make a single latent residual or slope covariance undefined. | Derivation first; no article or runtime admission in this slice. |
| Ordinary behavioural random regression | The Gaussian Appendix-B-style target is now public as the individual-level article; broader non-Gaussian augmented `unique()` support remains guarded. | Decide whether non-Gaussian augmented `unique()` should stay guarded or get a separate admission grid. |
| Predictor-informed latent scores (`latent(..., lv = ~ x)`) | **Bounded C1 closure complete; overall Design 73 remains partial.** Native ordinary Gaussian rank-1/rank-2 cells have rotation-invariant `B_lv`, total `Sigma = Lambda Lambda^T + Psi`, recovery, and conditional-on-eligible r500 Wald evidence with attempted, eligible, non-PD, and MCSE accounting. Native rank-1 multi-trial binomial logit/probit/cloglog cells have `B_lv` recovery and r500 Wald evidence with all 1,500 attempts eligible. The frozen native family-wide extension has retained point-recovery evidence for all 19 named mixed/sentinel ML, rank-1, `unique = FALSE`, complete-response cells: all 3,800 attempts remain in the ledger, all optimizers converged, 11 gradient exclusions remain explicit, and every cell passed the pre-frozen `B_lv`, shared `Lambda Lambda^T`, intercept, and score-identity gates. The pure r200 retained all 3,800 attempts and passed 17/19 cells; pure Beta and pure ordinal-probit retain cell-specific HOLD verdicts. The eight-archetype mixed r500 retained 4,000/4,000 attempts and 3,999 eligible intervals; every named Gaussian-anchor cell passed target-wise `B_lv` Wald coverage at 0.920--0.966. This is not simultaneous all-target coverage and does not admit arbitrary mixtures. `extract_lv_effects(type = "trait_effect")` is the cross-fit route; raw axis `alpha` and `Lambda` are not cross-fit targets. Factor-valued predictors remain point/recovery-supported without interval calibration, and the named Gaussian response-mask cell remains compatibility evidence rather than a broad mask claim. The Julia bridge is a separate complete-response, loadings-only (`unique = FALSE`) point route for Gaussian, Poisson, NB2, Gamma, Beta, and binomial standard links, with optional uncalibrated Wald plumbing and no profile/bootstrap or calibrated bridge-interval claim. Current guards reject `REML = TRUE`, fixed `X + X_lv`, unlisted family/link combinations, richer `lv` formulas, programme ranks above one, default `+ Psi`, masks, and source/tier expansion; fail-loud guards are not capability evidence. Source-pinned family-wide evidence is in `docs/dev-log/artifacts/methods-superarc/lv-mixed-family-all-native-source-contract.md`. | Investigate the two pure HOLD cells without weakening their frozen gates. Bridge calibration, structured sources, extra tiers, broader ranks/masks, factor intervals, missing LV predictors, arbitrary mixtures, and REML remain mathematically distinct future programmes. |

## Status-Scan Handles

Use these exact handles when auditing future drift:

```sh
rg -n "RE-03|s >= 2|s ≥ 2|two or more random slopes|non-Gaussian s" \
  README.md ROADMAP.md NEWS.md docs vignettes R tests/testthat
rg -n "random-regression-reaction-norms|random-slopes-nongaussian|under audit|forthcoming|engine in progress" \
  README.md ROADMAP.md _pkgdown.yml vignettes/articles docs/dev-log/audits
rg -n "d == n_traits|d = n_traits|d <= n_traits|d = K|d = q|d = 6" \
  docs R tests/testthat vignettes
rg -n "lv =|predictor-informed|latent-score mean|B_lv|LV-0[1-7]|FG-18|RE-13|EXT-31" \
  docs R tests/testthat vignettes README.md NEWS.md
```
