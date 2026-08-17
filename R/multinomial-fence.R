## Multinomial structured-term admission fence (Slice 0 + Slice 1 + Slice 2,
## Design 108/123).
##
## `multinomial()` (family_id 16) is fixed-effects-plus-two-tiers only in this
## release: ordinary shared `latent()` at the unit tier (cross-family
## correlations, with its default auto-Psi companion mapped off for the
## categorical contrast diagonal) and intercept-only `phylo_latent()` (the
## among-category phylogenetic surface, default `unique = FALSE` -- it emits
## NO Psi companion at all; `unique = TRUE` is NOT admitted, since a free
## phylogenetic Psi is deliberately unsupported for multinomial, see
## R/extract-sigma.R). Every other structured / random-effect keyword is
## deferred and must fail loud rather than silently fit an unvalidated
## categorical path.
##
## Slice 1 (2026-08-16): the among-category phylogenetic surface is extended
## from `phylo_latent()` alone to also admit loadings-only (`unique = FALSE`)
## `animal_latent()` (pedigree/known-relatedness `A`) and SINGLE-NAME
## loadings-only `kernel_latent()` (a dense supplied `K`). Both are PURE
## ENGINE SUGAR: they desugar (R/brms-sugar.R) into the identical `phylo_rr`
## covstruct `phylo_latent()` itself produces, so no engine/C++ code changes
## for this slice -- only the classifier below and the evidence in
## `tests/testthat/test-matrix-multinomial-phylo.R`. `unique = TRUE` on
## either keyword, their augmented-slope forms, every other animal_*/kernel_*
## mode (`*_indep`/`*_dep`/`*_scalar`/`kernel_unique`), and more than one
## `kernel_latent()` name in the same fit (multi-kernel) remain BLOCKED --
## see the admission table and `.mn_classify_covstruct()` below.
##
## Slice 2 (2026-08-16): the PHYLO MODE AXIS and its animal/kernel twins join
## the admitted set -- `phylo_dep()`/`animal_dep()`/`kernel_dep()` (the
## intercept-only full-`V` route) and `phylo_indep()`/`animal_indep()`/
## `kernel_indep()` plus their soft-deprecated standalone `*_unique()`
## aliases (the diagonal-`V` route). All six/eight resolve to the SAME
## `phylo_rr`/`theta_rr_phy` engine slot as `phylo_latent()` -- `*_dep()`
## with a full free packed-triangular Lambda (IDENTICAL parameterisation to
## `phylo_latent(d = n_traits)`, not merely V-equivalent: both go through
## `gll_unpack_rr_loadings()` with an unconstrained diagonal; the genuinely
## exp()-positive Cholesky diagonal belongs to the AUGMENTED `*_dep(1 + x |
## ...)` slope engine, `theta_dep_chol`, a different covstruct kind that
## stays blocked), `*_indep()`/`*_unique()` with the strict lower triangle
## pinned to 0 via a TMB map (D independent per-contrast variances, no
## among-category correlation). `*_scalar()` (`phylo_scalar()`,
## `animal_scalar()`, `kernel_scalar()`) STAYS REFUSED -- the first two route
## through the unrelated `propto` engine (blocked by the late `use_propto`
## re-scan, unchanged since Slice 0); `kernel_scalar()` shares the SAME
## `.phylo_unique`/`.indep` markers as the now-admitted `kernel_indep()` and
## is distinguished only by `.kernel_mode == "scalar"`, so this file's
## classifier carries an explicit carve-out for it. See
## `dev/multinomial-structured/probe-scalar-null.R` for the null-DGP evidence
## behind the scalar refusal. Augmented (intercept + slope) `*_dep`/`*_indep`
## forms, `*_latent(unique = TRUE)`, and every other cell remain BLOCKED.
##
## Historically the ONLY gate was a late allow-list re-scan of `use_*` engine
## flags in R/fit-multi.R (the "FAIL-CLOSED allow-list", Rose review
## 2026-07-18). That scan is necessary but not sufficient: several keywords
## desugar (R/brms-sugar.R) onto the SAME engine flag as an admitted keyword,
## so the flag-level scan cannot tell them apart and lets them through:
##   * `dep(0 + trait | unit)`            -> same `use_rr_B` flag as `latent()`
##   * `phylo_dep()` / `phylo_indep()` /
##     `phylo_unique()` (standalone)      -> same `use_phylo_rr` flag as
##                                            `phylo_latent()` (phylo_indep and
##                                            phylo_unique are REROUTED onto the
##                                            phylo_rr slot; see fit-multi.R's
##                                            `is_phylo_unique` rerouting block)
##   * single-name `kernel_*()`           -> also `use_phylo_rr` (Design 65 C1
##                                            reuses the phylo_rr engine path)
##   * `animal_latent()`                  -> also `use_phylo_rr`: `animal_*` is
##                                            PURE SUGAR for `phylo_*` (no
##                                            distinguishing marker survives
##                                            the desugar for any OTHER
##                                            `animal_*` keyword either, but
##                                            every other one lands on an
##                                            already-blocked cell; only
##                                            `animal_latent` collides with the
##                                            one ADMITTED cell -- see the
##                                            `.animal_source` marker this file
##                                            adds in R/brms-sugar.R)
##   * `phylo_scalar()` / `animal_scalar()` -> `use_propto`, which was
##                                              EXEMPTED from the scan entirely
##                                              (a non-tier keyword-mapping
##                                              flag alongside `use_equalto`)
##
## This file adds an EARLY covstruct-keyed classifier that reads the raw
## parser markers (`cs$kind`, `cs$extra$.dep`, `$.phylo_unique`,
## `$.kernel_name`, `$.animal_source`, `$.auto_unique`, and the grouping
## column) DIRECTLY off `parsed$covstructs`, before any of that flag-level
## folding happens, so keywords that fold onto the same engine flag are still
## told apart. It is deliberately a fail-closed ALLOW-list: only the current
## admitted set matches; every other covstruct classification aborts.
##
## The late `use_*` re-scan in R/fit-multi.R stays as belt-and-braces (moved
## after every `use_*` flag is defined, including the `use_mi_*` mi()
## predictor flags -- see the call site) and the `use_propto` exemption is
## removed there for family_id 16 fits. Both passes share the classed
## condition "gllvmTMB_multinomial_structured_not_admitted".
##
## Slice-0 repair (adversarial Opus review, 2026-08-16): the FIRST pass of
## this fence, above, had three more holes of the same shape --
## classification gaps that made pass 1 non-load-bearing (a coincidental
## OTHER gate, or the untyped pass-2 scan, happened to catch them instead):
##   * augmented (intercept + slope) ordinary `latent(1 + x | unit)` stays
##     `kind == "rr"` at the unit tier with no `.dep` marker, so the plain
##     unit-tier check admitted it; only untyped pass-2 (`use_rr_B_slope`)
##     caught it.
##   * augmented `phylo_latent(1 + x | species)` stays `kind == "phylo_rr"`
##     with none of the other markers set, so the plain-latent fall-through
##     admitted it; NEITHER pass caught it -- an unrelated per-family
##     augmented-slope-support gate happened to abort first.
##   * `phylo_latent(unique = TRUE)`'s auto-emitted Psi companion
##     (`.phylo_unique` + `.auto_unique`) was classified ADMITTED, directly
##     contradicting R/extract-sigma.R's documented policy that a free
##     phylogenetic Psi is not admitted for multinomial (pass 2 already
##     caught it via `use_phylo_diag`, so this was a documentation/pass-1
##     contradiction, not a live leak).
## Also closed: `equalto()` / `meta_V()` (known-sampling-covariance) was
## blanket-exempted in both passes; it is now fail-closed for fid 16 (no
## established route on a categorical-contrast pseudo-trait).
##
## Slice 4 (Design 123, 2026-08-16): ordinary GROUP random intercepts join
## the admitted set -- a generic `(1 | g)` random intercept (engine kind
## `re_int`, src/gllvmTMB.cpp's `re_int` block) and the non-phylogenetic
## `cluster`/`cluster2` diagonal tier (`indep(0 + trait | g)` via the
## `cluster =`/`cluster2 =` arguments, the `use_diag_species`/
## `use_diag_cluster2` engine slots). Both routes are pre-existing,
## family-agnostic engine code; nothing in src/gllvmTMB.cpp changes for this
## slice -- only the classifier below, a new whole-fit OLRE guard, and their
## test/doc coverage.
##   * `(1 | g)`: `src/gllvmTMB.cpp`'s `re_int` block adds ONE draw per group
##     level to EVERY row of `eta` that shares that group (`re_int_group_id`
##     is read off the group column of the AFTER-expansion pseudo-trait data,
##     R/fit-multi.R, so all K-1 baseline-contrast rows of one multinomial
##     observation carry the SAME group id and so get the SAME draw added).
##     Verified: this shared additive shift does NOT cancel in the softmax
##     between the baseline and any non-baseline category (it moves
##     baseline-vs-rest probability, i.e. P(y = baseline) vs
##     P(y != baseline)); the *ratio* between any TWO non-baseline
##     categories, WITHIN one fit, IS invariant to it (it cancels there).
##     So the semantics are a baseline-vs-rest group effect, and
##     `sigma_re`'s substantive interpretation is
##     REFERENCE-CATEGORY-SPECIFIC. CORRECTION (this task, caught by a test
##     failure -- see the after-task report): re-anchoring the baseline is
##     NOT a reparameterisation of the same model here, so it is not just
##     `sigma_re` that changes -- the fitted response-scale probabilities
##     change too. Under `baseline = 1`, `eta = (0, b0_2 + u_g, b0_3 +
##     u_g)` constrains the log-odds BETWEEN categories 2 and 3 to be
##     constant across groups (`eta_3 - eta_2 = b0_3 - b0_2`, no `u_g`
##     term); under `baseline = 3`, the SAME engine instead shares a (new)
##     `u_g` between categories 1 and 2, constraining THEIR log-odds to be
##     constant instead. These are two different parametric restrictions on
##     the model space, not one distribution under two labels -- unlike the
##     fixed-effects-only case, where relabelling genuinely is a
##     reparameterisation (`test-multinomial.R`'s existing baseline-
##     invariance tests). See `multinomial()`'s roxygen (R/families.R),
##     `test-matrix-multinomial-unit.R`'s Cell (c) (the corrected,
##     within-fit claim), and the informational note `fit-multi.R` emits
##     once per session (`gllvmTMB-multinomial-reint-baseline-inform`).
##   * cluster/cluster2 `indep(0 + trait | g)`: `use_diag_species` /
##     `use_diag_cluster2` are the IDENTICAL engine route (same per-trait
##     independent-normal math, `eta(o) += q_sp(t, species_id(o))` /
##     `eta(o) += r_c2(t, cluster2_id(o))`, src/gllvmTMB.cpp) on two
##     different grouping columns -- so both are admitted together, giving
##     D independent per-CONTRAST (pseudo-trait) variances at that grouping,
##     the per-category random intercept users usually want. The
##     soft-deprecated standalone `unique()` alias is the SAME engine path
##     as `indep()` at this tier too (only the printed label differs, exactly
##     as at the unit tier) and is admitted alongside it.
##     `common = TRUE` (the `scalar()` modifier) STAYS BLOCKED at this tier:
##     the generic engine has no `common`-pooling map for `use_diag_species`/
##     `use_diag_cluster2` (unlike the unit/unit_obs `diag_B_common`/
##     `diag_W_common` map tricks), so a `common = TRUE` request would
##     otherwise be silently admitted and silently ignored rather than
##     actually pooling to one shared level -- refused explicitly instead.
##   * `unit_obs` (`site_species`) grouping stays BLOCKED (no change this
##     slice); augmented slopes and `latent()`/`dep()` at the cluster/
##     cluster2 tiers stay BLOCKED (no engine slot); the spatial mode axis
##     (Slice 3, not this slice) stays BLOCKED.
##   * OLRE guard: for a fid-16 fit, if EVERY level of an admitted `(1 | g)`
##     or cluster/cluster2 `indep()` grouping factor covers exactly one
##     multinomial observation (`.multinom_group_`), the term is an
##     observation-level random effect (OLRE) in disguise -- the softmax
##     latent scale is fixed (no free residual-dispersion parameter, unlike
##     a Gaussian/count response), so a per-observation intercept shared
##     across its own K-1 contrast rows is not identifiable from the fixed
##     effects. `.multinomial_reint_group_olre_guard()` below aborts this
##     case typed, separately from (after) the admission classification --
##     the term IS admitted per-covstruct, exactly like the multi-kernel
##     override is a separate whole-fit check layered on top of an
##     individually-admitted classification.

## The current admitted set. Kept as an explicit constant so the CURRENT
## ADMITTED SET is legible in one place and the cli_abort message below can
## quote it without hand-duplicating prose. `since` records the design/PR
## that admitted the cell; it is documentation only.
## Each row is deliberately ONE classifiable cell with ONE representative
## covstruct shape, so a table-consistency test can iterate every row,
## construct that row's representative covstruct, and assert
## `.mn_classify_covstruct()`'s verdict matches `status` -- catching exactly
## the kind of table/code drift that let row 4 (below) go stale.
.mn_admission_table <- data.frame(
  source = c(
    "none", "none", "phylo", "phylo", "none", "phylo", "none",
    "animal", "kernel", "animal", "kernel",
    ## Slice 2 (Design 123, 2026-08-16): the phylo mode axis and its
    ## animal/kernel twins.
    "phylo", "phylo", "phylo",
    "animal", "animal", "animal",
    "kernel", "kernel", "kernel", "kernel",
    ## Slice 4 (Design 123, 2026-08-16): generic group random intercepts and
    ## the non-phylogenetic cluster/cluster2 diagonal tier.
    "none", "none", "none", "none", "none", "none", "none",
    ## Slice 3 (Design 123, 2026-08-16): the spatial (SPDE) mode axis.
    "spatial", "spatial", "spatial", "spatial", "spatial", "spatial", "spatial",
    ## Slice 5 repair (D-43 completion panel R1/R2, 2026-08-16): explicit
    ## unit-tier dep()/indep()/unique() (previously blocked only via
    ## classifier fallthrough, no table row) and the unit_obs-tier re_int
    ## exclusion (previously mis-admitted, see the re_int branch's comment).
    "none", "none", "none", "none"
  ),
  mode   = c(
    "latent", "latent", "latent", "latent", "latent_slope", "latent_slope",
    "equalto", "latent", "latent", "latent", "latent",
    "dep", "indep", "unique",
    "dep", "indep", "unique",
    "dep", "indep", "unique", "indep (scalar)",
    "re_int", "indep", "unique", "indep", "unique", "indep (scalar)", "indep (scalar)",
    "latent", "indep", "dep", "latent (unique=TRUE)", "scalar", "unique", "latent_slope",
    "dep", "indep", "unique", "re_int"
  ),
  tier   = c(
    "unit", "unit (auto-Psi)", "among-category",
    "among-category (auto-Psi)", "unit", "among-category", "-",
    "among-category", "among-category (single name)",
    "among-category (auto-Psi)",
    "among-category (auto-Psi, single name)",
    "among-category (full V)", "among-category (diagonal V)",
    "among-category (diagonal V, deprecated alias)",
    "among-category (full V)", "among-category (diagonal V)",
    "among-category (diagonal V, deprecated alias)",
    "among-category (full V, single name)",
    "among-category (diagonal V, single name)",
    "among-category (diagonal V, deprecated alias, single name)",
    "among-category (single shared level, single name)",
    "any group (generic, except unit_obs)", "cluster", "cluster", "cluster2", "cluster2",
    "cluster", "cluster2",
    "spatial (shared field, loadings-only)", "spatial (per-contrast independent fields)",
    "spatial (full field covariance, === latent(d=T))",
    "spatial (paired Psi_spde companion)", "spatial (single shared level)",
    "spatial (standalone / deprecated bare alias)",
    "spatial (augmented intercept + slope, any mode)",
    "unit", "unit", "unit", "unit_obs"
  ),
  status = c(
    "admitted", "admitted", "admitted", "blocked", "blocked", "blocked",
    "blocked", "admitted", "admitted", "blocked", "blocked",
    "admitted", "admitted", "admitted",
    "admitted", "admitted", "admitted",
    "admitted", "admitted", "admitted", "blocked",
    "admitted", "admitted", "admitted", "admitted", "admitted",
    "blocked", "blocked",
    "admitted", "admitted", "admitted", "blocked", "blocked", "blocked", "blocked",
    "blocked", "blocked", "blocked", "blocked"
  ),
  since  = c(
    "Tier-2b item 2a-ii (0.6.0)",
    "0.2.0 (latent() default Psi)",
    "Design 84 Tier-2a (0.6.0)",
    "BLOCKED -- Slice 0 repair (2026-08-16): was wrongly admitted, contradicting R/extract-sigma.R's documented policy that a free phylogenetic Psi ('unique = TRUE') is not admitted for multinomial. phylo_latent() with the default unique = FALSE emits no Psi companion at all; an explicit unique = TRUE request is blocked.",
    "BLOCKED -- Slice 0 repair (2026-08-16): pass 1 fell through to ADMITTED for augmented latent(1 + x | unit) / latent(0 + trait + (0 + trait):x | unit); only the untyped pass-2 use_rr_B_slope scan caught it.",
    "BLOCKED -- Slice 0 repair (2026-08-16): pass 1 fell through to ADMITTED for augmented phylo_latent(1 + x | species); NEITHER pass caught it (an unrelated family-augmented-slope gate happened to abort first).",
    "BLOCKED -- Slice 0 repair (2026-08-16): meta_V()/equalto() (known-sampling-covariance) has no admitted route on a categorical-contrast pseudo-trait; fail-closed default rather than the prior blanket pass-1/pass-2 exemption.",
    "ADMITTED -- Design 123 Slice 1 (2026-08-16): loadings-only (unique = FALSE) animal_latent() is pure sugar over phylo_rr, engine-identical to phylo_latent() -- equivalence verified in test-matrix-multinomial-phylo.R.",
    "ADMITTED -- Design 123 Slice 1 (2026-08-16): loadings-only (unique = FALSE) single-name kernel_latent() routes through the SAME phylo_rr engine (Design 65 C1 phylo-equivalence) -- equivalence verified in test-matrix-multinomial-phylo.R. Multiple kernel_latent() terms in one fit (multi-kernel) stay BLOCKED; that check is whole-fit, not per-covstruct, so it has no row of its own here -- see .multinomial_structured_admission()'s kernel-name count and test-multinomial-fence.R's 'multi-kernel is not admitted'.",
    "BLOCKED -- Design 123 Slice 1 (2026-08-16): animal_latent(unique = TRUE)'s auto-emitted Psi companion is a free phylogenetic Psi, not admitted for multinomial for the same reason as row 4 (phylo_latent(unique = TRUE)).",
    "BLOCKED -- Design 123 Slice 1 (2026-08-16): kernel_latent(unique = TRUE)'s auto-emitted Psi companion is a free phylogenetic Psi, not admitted for multinomial for the same reason as row 4 (phylo_latent(unique = TRUE)).",
    "ADMITTED -- Design 123 Slice 2 (2026-08-16): intercept-only phylo_dep(0 + trait | species) resolves d = n_traits and populates the SAME phylo_rr/theta_rr_phy slot as phylo_latent(species, d = n_traits) -- the IDENTICAL unconstrained packed-triangular parameterisation (gll_unpack_rr_loadings, src/gllvmTMB.cpp), not merely V-equivalent. Do not confuse with the augmented *_dep(1 + x | species) slope engine (theta_dep_chol), which DOES exp()-transform its Cholesky diagonal and stays BLOCKED (row 5/6). Equivalence to phylo_latent(d = n_traits) verified in test-matrix-multinomial-phylo.R.",
    "ADMITTED -- Design 123 Slice 2 (2026-08-16): phylo_indep(0 + trait | species) reroutes to the phylo_rr diagonal slot (.phylo_unique + .indep markers) -- a diagonal Lambda_phy (strict lower triangle pinned to 0 via a TMB map), giving D independent per-contrast phylogenetic variances with no among-category correlation.",
    "ADMITTED -- Design 123 Slice 2 (2026-08-16): standalone phylo_unique(species) is the soft-deprecated alias of phylo_indep() -- same phylo_rr diagonal slot, same engine, differing only in the printed label (R/brms-sugar.R issues a one-time deprecation warning).",
    "ADMITTED -- Design 123 Slice 2 (2026-08-16): animal_dep() twin of phylo_dep(), pure sugar over the same phylo_rr/theta_rr_phy route with the pedigree/A matrix supplied via vcv.",
    "ADMITTED -- Design 123 Slice 2 (2026-08-16): animal_indep() twin of phylo_indep(), same diagonal phylo_rr route.",
    "ADMITTED -- Design 123 Slice 2 (2026-08-16): animal_unique() twin of standalone phylo_unique() (soft-deprecated alias of animal_indep()).",
    "ADMITTED -- Design 123 Slice 2 (2026-08-16): kernel_dep() twin of phylo_dep(), single named dense K matrix, same phylo_rr/theta_rr_phy route (Design 65 C1 phylo-equivalence).",
    "ADMITTED -- Design 123 Slice 2 (2026-08-16): kernel_indep() twin of phylo_indep(), same diagonal phylo_rr route.",
    "ADMITTED -- Design 123 Slice 2 (2026-08-16): kernel_unique() twin of standalone phylo_unique() (soft-deprecated alias of kernel_indep()).",
    "BLOCKED -- Design 123 Slice 2 (2026-08-16): kernel_scalar() (and kernel_indep(..., common = TRUE)) carry the SAME .phylo_unique + .indep markers as kernel_indep() and are distinguished ONLY by .kernel_mode == \"scalar\"; it ties the per-trait diagonal phylogenetic variances to ONE shared level. STAYS REFUSED like phylo_scalar()/animal_scalar() -- see dev/multinomial-structured/probe-scalar-null.R for the null-DGP evidence motivating the refusal.",
    "ADMITTED -- Design 123 Slice 4 (2026-08-16): a generic (1 | g) random intercept adds one draw per group level to EVERY pseudo-trait row of a multinomial observation (src/gllvmTMB.cpp re_int block, group id read off the AFTER-expansion data). Semantics: a baseline-vs-rest group effect (the shared shift does not cancel in the softmax); sigma_re is REFERENCE-CATEGORY-SPECIFIC. Subject to the whole-fit OLRE guard (.multinomial_reint_group_olre_guard()) below. EXCLUDES the unit_obs tier (Slice 5 repair, D-43 R1, 2026-08-16 -- see the last table row and the re_int classifier branch's comment; this row's 'admitted' verdict is only reached for a grouping OTHER than the unit_obs column).",
    "ADMITTED -- Design 123 Slice 4 (2026-08-16): indep(0 + trait | <cluster_col>) via the cluster = argument routes through use_diag_species (per-trait/per-contrast independent normal variances, family-agnostic, pre-existing engine code). Subject to the OLRE guard.",
    "ADMITTED -- Design 123 Slice 4 (2026-08-16): standalone unique(0 + trait | <cluster_col>) is the SAME use_diag_species engine path as indep() at this tier (the .indep marker only changes the printed label, as at the unit tier) -- admitted alongside it.",
    "ADMITTED -- Design 123 Slice 4 (2026-08-16): indep(0 + trait | <cluster2_col>) via the cluster2 = argument routes through use_diag_cluster2 -- verified LITERALLY IDENTICAL engine math to use_diag_species (same per-trait independent-normal density, different DATA/PARAMETER slot; src/gllvmTMB.cpp), so admitted together with cluster.",
    "ADMITTED -- Design 123 Slice 4 (2026-08-16): standalone unique(0 + trait | <cluster2_col>) is the SAME use_diag_cluster2 engine path as indep() at this tier -- admitted alongside it.",
    "BLOCKED -- Design 123 Slice 4 (2026-08-16): indep(0 + trait | <cluster_col>, common = TRUE) (the scalar() modifier). The generic engine has no common-pooling map for use_diag_species (unlike the unit/unit_obs diag_B_common/diag_W_common map tricks); admitting it would silently ADMIT the term while silently IGNORING the common = TRUE request rather than actually pooling to one shared level, so it is refused explicitly instead, matching phylo_scalar()/animal_scalar()/kernel_scalar().",
    "BLOCKED -- Design 123 Slice 4 (2026-08-16): indep(0 + trait | <cluster2_col>, common = TRUE), same reasoning as the cluster-tier scalar refusal above (no common-pooling map for use_diag_cluster2 either).",
    "ADMITTED -- Design 123 Slice 3 (2026-08-16): intercept-only spatial_latent(0 + trait | coords, d = k) (loadings-only, default unique = FALSE) -- the shared-field cross-contrast SPDE ordination; A_proj row alignment verified (dev/multinomial-structured/gate-check-a-proj.R): the SPDE eta contribution is applied per EXPANDED row, and a mesh built on the post-expansion coordinate frame carries each site's projector row correctly repeated across its K-1 contrast rows.",
    "ADMITTED -- Design 123 Slice 3 (2026-08-16): spatial_indep(0 + trait | coords) (`.spatial_indep = TRUE`) -- per-contrast independent SPDE fields, no cross-contrast field correlation.",
    "ADMITTED -- Design 123 Slice 3 (2026-08-16): spatial_dep(0 + trait | coords) -- VERIFIED (R/brms-sugar.R desugar) to literally set `.spatial_latent = TRUE, d = n_traits, .dep = TRUE`, i.e. it IS spatial_latent(d = n_traits) under a documentary keyword (the package's own roxygen already states this identity); same `use_spde` engine slot, not a separate one.",
    "BLOCKED -- Design 123 Slice 3 (2026-08-16): spatial_latent(unique = TRUE)'s paired diagonal Psi_spde companion (`.spatial_unique_diag = TRUE`, a SINGLE marker on the SAME covstruct, architecturally different from phylo/animal/kernel's separate-companion-covstruct pattern) is a free spatial Psi, not admitted for multinomial for the same reason as row 4 (phylo_latent(unique = TRUE)).",
    "BLOCKED -- Design 123 Slice 3 (2026-08-16): spatial_scalar() (`.spatial_scalar = TRUE`, incl. spatial_indep(..., common = TRUE)) ties the per-contrast spatial-field variances to ONE shared level -- the (I+J) carve-out, refused for the same reason as phylo_scalar()/animal_scalar()/kernel_scalar().",
    "BLOCKED -- Design 123 Slice 3 (2026-08-16): standalone spatial_unique()/deprecated bare spatial() (no markers at all) is the PAIRED-COMPANION alias mechanism (meant to pair with spatial_latent(), Design 60), not an independent diagonal term the way phylo_unique()/phylo_indep() are -- unlike Slice 2's phylo mode axis, this cell is NOT admitted as a deprecated alias of spatial_indep(); use spatial_indep() directly for a standalone diagonal spatial fit.",
    "BLOCKED -- Design 123 Slice 3 (2026-08-16): every augmented (intercept + slope) spatial_*(1 + x | coords) term (`.spatial_unique_augmented` / `.spatial_dep_augmented` / `.spatial_latent_augmented`) stays blocked, mirroring rows 5/6's augmented phylo/ordinary-latent refusal.",
    "BLOCKED -- Slice 5 repair (D-43 completion panel finding R2, 2026-08-16): dep(0 + trait | unit) at the unit tier was already blocked by the classifier's rr-kind fallthrough (row above the auto-Psi row) and by fit-level tests, but had no explicit table row of its own -- the table is documented as the single source of truth, so it must be literally exhaustive. Same engine/reasoning as row 1's admitted latent(); this is the DIFFERENT, unadmitted dep() covstruct at the same tier.",
    "BLOCKED -- Slice 5 repair (D-43 completion panel finding R2, 2026-08-16): explicit indep(0 + trait | unit) at the unit tier -- classifier's diag-kind fallthrough, previously untabled. Only the default latent()-carried auto-Psi (row 2) is admitted at this tier; an EXPLICIT indep()/unique() diagonal term here is not.",
    "BLOCKED -- Slice 5 repair (D-43 completion panel finding R2, 2026-08-16): explicit standalone unique(0 + trait | unit) at the unit tier -- same fallthrough/reasoning as the indep() row immediately above, differing only in the .indep marker (printed label only).",
    "BLOCKED -- Slice 5 repair (D-43 completion panel finding R1, 2026-08-16): (1 | <unit_obs column>) at the unit_obs tier. The re_int classifier branch previously admitted ANY grouping unconditionally, discarding the tier computed above it -- a unit_obs-tier (1 | g) term classified ADMITTED and was only stopped by the coincidental OLRE guard on fixtures where every unit_obs level happened to be a categorical singleton. Fixed: re_int now consults tier directly and blocks unit_obs, matching design-123 Section 1/6's documented unit_obs-out-of-scope statement. See test-multinomial-fence.R's typed regression test for a fit where unit_obs levels are NOT singletons (so the OLRE guard would not have caught it either)."
  ),
  stringsAsFactors = FALSE
)

## Determine which grouping TIER (unit / unit_obs / cluster / cluster2 /
## other) a covstruct's grouping factor maps to. Extracted so both
## `.mn_classify_covstruct()` and `.multinomial_reint_group_olre_guard()`
## (the whole-fit OLRE check, Slice 4) agree on the SAME tier logic rather
## than risking two copies drifting apart.
.mn_covstruct_tier <- function(cs, site, ss_name, species, cluster2_col) {
  grp <- tryCatch(deparse(cs$group), error = function(e) NA_character_)
  if (identical(grp, site)) {
    "unit"
  } else if (identical(grp, ss_name)) {
    "unit_obs"
  } else if (identical(grp, species)) {
    "cluster"
  } else if (!is.null(cluster2_col) && identical(grp, cluster2_col)) {
    "cluster2"
  } else {
    "other"
  }
}

## Classify ONE covstruct into (source, mode, admitted). Reads only the raw
## fields the parser preserves on `cs` -- never a derived `use_*` flag -- so
## keywords that later fold onto the same engine flag are still distinguished
## here. Returns a one-row list; never errors (the caller aborts).
.mn_classify_covstruct <- function(cs, site, ss_name, species, cluster2_col) {
  kind  <- cs$kind
  extra <- cs$extra %||% list()
  tier  <- .mn_covstruct_tier(cs, site = site, ss_name = ss_name,
                               species = species, cluster2_col = cluster2_col)

  ## propto is handled entirely by the late use_* re-scan (the use_propto
  ## exemption is removed there for fid 16) -- not this classifier's job.
  if (identical(kind, "propto")) {
    return(list(source = NA_character_, mode = NA_character_,
                admitted = TRUE, label = NA_character_))
  }
  ## equalto (meta_V()) is a known-sampling-covariance term. It has no
  ## established route for a categorical-contrast pseudo-trait -- fail
  ## closed here rather than carry the old blanket propto/equalto
  ## exemption forward. (Both passes previously exempted it identically;
  ## pass 2's use_equalto exemption is now vestigial for fid 16 but is left
  ## in place as it is shared with every other family.)
  if (identical(kind, "equalto")) {
    return(list(source = "none", mode = "equalto", admitted = FALSE,
                label = "meta_V() / equalto()"))
  }

  if (identical(kind, "re_int")) {
    ## Slice 4 (Design 123, 2026-08-16): admitted for any grouping EXCEPT
    ## the unit_obs tier, which is out of scope for this arc (design-123
    ## Section 1/6). Design 123 Slice 5 repair (D-43 completion panel
    ## finding R1, 2026-08-16): this branch used to ignore `tier` entirely
    ## and admit re_int for ANY grouping, so a `(1 | <unit_obs-like
    ## column>)` term classified ADMITTED here and was only stopped by the
    ## coincidental OLRE guard on fixtures where every unit_obs level
    ## happened to be a categorical singleton -- not a real admission
    ## decision, and silently wrong on any fixture where a unit_obs level
    ## covered more than one categorical observation. `src/gllvmTMB.cpp`'s
    ## `re_int` block adds one draw per group level to EVERY row of `eta`
    ## sharing that group id -- for multinomial's expanded K-1 pseudo-trait
    ## rows, that is a baseline-vs-rest group effect (see the header comment
    ## above). Whether a PARTICULAR admitted grouping is degenerate (an OLRE
    ## in disguise, one categorical observation per level) remains a
    ## SEPARATE whole-fit check against `data`, not classifiable from this
    ## covstruct alone -- see `.multinomial_reint_group_olre_guard()` below,
    ## mirroring how the multi-kernel override works on top of an
    ## individually-admitted classification.
    if (identical(tier, "unit_obs")) {
      return(list(source = "none", mode = "re_int", admitted = FALSE,
                  label = "a (1 | group) random intercept at the unit_obs tier"))
    }
    return(list(source = "none", mode = "re_int", admitted = TRUE,
                label = "a generic (1 | group) random intercept"))
  }

  if (identical(kind, "rr")) {
    ## Augmented (intercept + slope) ordinary latent(): latent(1 + x | unit)
    ## / latent(0 + trait + (0 + trait):x | unit, d = K) carry
    ## `.latent_augmented` and stay `kind == "rr"` at the unit tier, so the
    ## plain unit-tier check below would otherwise admit them.
    if (isTRUE(extra$.latent_augmented)) {
      return(list(source = "none", mode = "latent_slope", admitted = FALSE,
                  label = "an augmented (intercept + slope) latent() random-regression term"))
    }
    if (identical(tier, "unit") && !isTRUE(extra$.dep)) {
      return(list(source = "none", mode = "latent", admitted = TRUE,
                  label = "latent() at the unit tier"))
    }
    mode <- if (isTRUE(extra$.dep)) "dep" else "latent"
    return(list(source = "none", mode = mode, admitted = FALSE,
                label = sprintf("%s() at the %s tier", mode, tier)))
  }

  if (identical(kind, "diag")) {
    if (identical(tier, "unit") && isTRUE(extra$.auto_unique)) {
      return(list(source = "none", mode = "latent", admitted = TRUE,
                  label = "the default auto-Psi companion of latent()"))
    }
    mode <- if (isTRUE(extra$.indep)) "indep" else "unique"
    ## Slice 4 (Design 123, 2026-08-16): admit the cluster/cluster2
    ## diagonal tier -- indep(0 + trait | g) / the soft-deprecated
    ## standalone unique(0 + trait | g) alias via `cluster =`/`cluster2 =`,
    ## the SAME use_diag_species/use_diag_cluster2 engine route for both
    ## aliases (only the printed label differs, exactly as at the unit
    ## tier). `common = TRUE` (the scalar() modifier) stays BLOCKED at this
    ## tier: the generic engine has no common-pooling map for
    ## use_diag_species/use_diag_cluster2, so admitting it would silently
    ## ignore the request instead of actually pooling -- refused explicitly.
    if (tier %in% c("cluster", "cluster2")) {
      if (isTRUE(extra$common)) {
        return(list(
          source = "none", mode = "indep (scalar)", admitted = FALSE,
          label = sprintf(
            "%s(..., common = TRUE) (a single shared level across contrasts) at the %s tier",
            mode, tier
          )
        ))
      }
      return(list(source = "none", mode = mode, admitted = TRUE,
                  label = sprintf("%s() at the %s tier", mode, tier)))
    }
    return(list(source = "none", mode = mode, admitted = FALSE,
                label = sprintf("an explicit %s() term at the %s tier",
                                 mode, tier)))
  }

  if (identical(kind, "phylo_rr")) {
    ## Slice 1 (Design 123, 2026-08-16): determine the SOURCE label first
    ## (kernel / animal / phylo), then apply the mode checks (.latent_slope /
    ## .dep / .phylo_unique) UNIFORMLY across sources, mirroring the plain
    ## phylo_* logic below instead of short-circuiting animal_*/kernel_* to
    ## "blocked" before those checks run (Slice 0's behaviour). This is what
    ## lets the plain loadings-only cell (no slope/dep/unique marker) reach
    ## the fall-through at the bottom and be admitted for animal_latent() and
    ## single-name kernel_latent() -- pure sugar / a Design 65 C1
    ## phylo-equivalent path over the ALREADY-admitted phylo_latent() engine;
    ## equivalence to phylo_latent() is verified in
    ## test-matrix-multinomial-phylo.R. Every other animal_*/kernel_* mode
    ## (unique = TRUE, augmented slopes, *_indep/*_dep/*_scalar) still carries
    ## one of those markers and is still blocked, unchanged from Slice 0.
    ## Multiple kernel_latent() terms in one fit (multi-kernel) are NOT
    ## classifiable from a single covstruct in isolation -- that whole-fit
    ## check lives in .multinomial_structured_admission(), below, which
    ## overrides an individually-admitted kernel cell back to blocked when
    ## more than one distinct kernel name is present.
    kernel_name <- if (!is.null(extra$.kernel_name)) {
      as.character(extra$.kernel_name)
    } else {
      NA_character_
    }
    kernel_mode <- if (!is.null(extra$.kernel_mode)) {
      as.character(extra$.kernel_mode)
    } else {
      NA_character_
    }
    source_label <- if (!is.na(kernel_name)) {
      "kernel"
    } else if (isTRUE(extra$.animal_source)) {
      "animal"
    } else {
      "phylo"
    }
    kw <- source_label # "kernel" / "animal" / "phylo" is also the keyword prefix

    ## Augmented (intercept + slope) *_latent(1 + x | species): carries
    ## `.latent_slope` and stays `kind == "phylo_rr"` with no other marker, so
    ## the plain-latent fall-through below would otherwise admit it. (Neither
    ## this early classifier nor the late use_* re-scan caught the
    ## phylo_latent() case pre-Slice-0 -- an unrelated per-family
    ## augmented-slope gate happened to abort first for every family
    ## currently reachable via multinomial(), which is NOT the same as this
    ## fence being load-bearing here.) kernel_latent() itself has no wired
    ## augmented-bar form at all (it fails loud in the parser, for every
    ## family, before reaching this classifier), so this branch is reached by
    ## phylo_latent() and animal_latent() only.
    if (isTRUE(extra$.latent_slope)) {
      return(list(source = source_label, mode = "latent_slope", admitted = FALSE,
                  label = sprintf("an augmented (intercept + slope) %s_latent() random-regression term", kw),
                  kernel_name = kernel_name))
    }
    if (isTRUE(extra$.dep)) {
      ## Slice 2 (Design 123, 2026-08-16): admit the intercept-only *_dep()
      ## cell for all three sources. `phylo_dep(0 + trait | species)` /
      ## `animal_dep(0 + trait | id)` / `kernel_dep(unit, K = K)` all resolve
      ## `d = n_traits` and populate the SAME `phylo_rr_idx` / `theta_rr_phy`
      ## slot as `phylo_latent(species, d = n_traits)` (R/fit-multi.R) --
      ## unpacked by the SAME `gll_unpack_rr_loadings()` (src/gllvmTMB.cpp),
      ## whose diagonal is UNCONSTRAINED for every caller of that function.
      ## This is the intercept-only route; it must not be confused with the
      ## AUGMENTED (intercept + slope) `*_dep(1 + x | ...)` engine
      ## (`use_phylo_dep_slope`, `theta_dep_chol`), which genuinely DOES
      ## exp()-transform its Cholesky diagonal for positivity -- that path is
      ## a different covstruct kind (`phylo_slope`, handled above) and stays
      ## BLOCKED (augmented slopes are not admitted for multinomial). So the
      ## intercept-only cell admitted here is not merely V-equivalent to
      ## `phylo_latent(d = n_traits)`, it is the IDENTICAL parameterisation
      ## (full-rank packed lower-triangular Lambda, no positivity
      ## constraint) under a different parse-time label -- see
      ## test-matrix-multinomial-phylo.R's equivalence tests.
      label <- sprintf("%s_dep()", kw)
      return(list(source = source_label, mode = "dep", admitted = TRUE,
                  label = label, kernel_name = kernel_name))
    }
    if (isTRUE(extra$.phylo_unique)) {
      if (isTRUE(extra$.auto_unique)) {
        ## The auto-emitted companion of *_latent(unique = TRUE), any source.
        ## A free phylogenetic Psi is deliberately NOT admitted for
        ## multinomial (see the has_multinomial branch of extract_Sigma()'s
        ## "phylogenetic tier is currently latent-only" note,
        ## R/extract-sigma.R) -- so this is blocked, not admitted. Plain
        ## *_latent() (the default unique = FALSE) never emits this covstruct
        ## at all.
        return(list(
          source = source_label, mode = "latent", admitted = FALSE,
          label = sprintf(
            "%s_latent(unique = TRUE) (a free phylogenetic Psi is not admitted for multinomial)",
            kw
          ),
          kernel_name = kernel_name
        ))
      }
      mode <- if (isTRUE(extra$.indep)) "indep" else "unique"
      ## kernel_scalar()/kernel_indep(..., common = TRUE) carry the SAME
      ## `.phylo_unique = TRUE, .indep = TRUE` markers as kernel_indep() and
      ## are distinguished ONLY by `.kernel_mode == "scalar"` (set at parse
      ## time, R/brms-sugar.R). phylo_scalar()/animal_scalar() take a
      ## DIFFERENT covstruct kind entirely (`propto`, handled at the top of
      ## this function) so they never reach this branch -- only kernel_scalar
      ## needs an explicit carve-out here to stay BLOCKED while its
      ## kernel_indep()/kernel_dep() siblings are admitted (Slice 2).
      is_kernel_scalar <- identical(source_label, "kernel") &&
        identical(kernel_mode, "scalar")
      ## Slice 2 (Design 123, 2026-08-16): admit the diagonal-V cell
      ## (*_indep() and the deprecated standalone *_unique() alias) for all
      ## three sources -- same `phylo_rr`/`theta_rr_phy` route as *_dep(),
      ## with the strict lower triangle pinned to 0 via a TMB map
      ## (R/fit-multi.R's `is_phylo_unique` diagonal-`lambda_constraint`
      ## block), giving D independent per-contrast phylogenetic variances
      ## with NO among-category correlation. `*_scalar()` (source = kernel
      ## only, reached via this branch) ties those independent variances to
      ## ONE shared level and stays BLOCKED (the null-DGP probe,
      ## dev/multinomial-structured/probe-scalar-null.R, evidences why a
      ## scalar summary is not interpretable on the (I+J) contrast
      ## geometry).
      admitted <- !is_kernel_scalar
      label <- if (identical(source_label, "kernel")) {
        ## kernel_indep()/kernel_scalar() both carry `.indep = TRUE` and are
        ## distinguished only by `.kernel_mode` ("indep" vs "scalar");
        ## kernel_unique() carries neither `.indep` nor `.kernel_mode` !=
        ## "unique". Prefer the more specific kernel_mode label when present.
        sprintf("kernel_%s()", if (!is.na(kernel_mode)) kernel_mode else mode)
      } else {
        sprintf("%s_%s()", kw, mode)
      }
      return(list(source = source_label, mode = mode, admitted = admitted,
                  label = label, kernel_name = kernel_name))
    }
    ## Plain loadings-only cell (no slope/dep/unique marker): admitted for
    ## ALL THREE sources as of Slice 1 -- phylo_latent() (Design 84,
    ## pre-existing), animal_latent() and single-name kernel_latent()
    ## (Design 123 Slice 1, 2026-08-16). Multi-kernel is blocked separately,
    ## at the whole-fit level, by the caller.
    label <- switch(source_label,
      kernel = "kernel_latent()",
      animal = "animal_latent()",
      "phylo_latent()"
    )
    return(list(source = source_label, mode = "latent", admitted = TRUE,
                label = label, kernel_name = kernel_name))
  }

  if (identical(kind, "phylo_slope")) {
    return(list(source = "phylo", mode = "slope", admitted = FALSE,
                label = "an augmented (intercept + slope) phylogenetic term"))
  }

  if (identical(kind, "spde")) {
    ## Slice 3 (Design 123, 2026-08-16): admit intercept-only spatial_latent()
    ## (shared fields, loadings-only), spatial_indep() (per-contrast
    ## independent fields, `.spatial_indep = TRUE`), and spatial_dep() (full
    ## unstructured cross-contrast field covariance). VERIFIED at the parser
    ## level (R/brms-sugar.R, `fn == "spatial_dep"` intercept-only branch):
    ## spatial_dep(0 + trait | coords) desugars to
    ## `spde(form, .spatial_latent = TRUE, d = n_traits, .dep = TRUE)` -- it
    ## literally SETS the SAME `.spatial_latent` marker spatial_latent()
    ## itself uses (plus a `.dep` label-only marker), i.e. it reuses the
    ## IDENTICAL `use_spde` engine slot at full rank d = n_traits. This is
    ## the identity the task brief asked to verify; it holds exactly as
    ## hypothesised (spatial_dep === spatial_latent(d = T), even more
    ## directly than phylo_dep's shared-slot-but-separate-marker relationship
    ## to phylo_latent).
    ##
    ## Stays BLOCKED: spatial_scalar() (`.spatial_scalar`, one shared level
    ## across contrasts -- the (I+J) carve-out, mirroring phylo_scalar()/
    ## animal_scalar()/kernel_scalar()); spatial_latent(unique = TRUE) (the
    ## PAIRED diagonal Psi_spde companion -- unlike phylo/animal/kernel,
    ## this is a SINGLE marker `.spatial_unique_diag = TRUE` on the SAME
    ## covstruct rather than a second covstruct, so it needs an explicit
    ## carve-out here); standalone `spatial_unique()`/deprecated bare
    ## `spatial()` (desugars with NO markers at all -- it is the PAIRED-
    ## COMPANION alias mechanism, not an independent diagonal term the way
    ## phylo_unique()/phylo_indep() are, so it stays on the DEFAULT "unique"
    ## fallthrough below, blocked); and every AUGMENTED (intercept + slope)
    ## spatial term (`.spatial_unique_augmented` / `.spatial_dep_augmented` /
    ## `.spatial_latent_augmented`, covering spatial_unique(1+x|.)/
    ## spatial_dep(1+x|.)/spatial_indep(1+x|.) [reuses .spatial_dep_augmented]/
    ## spatial_latent(1+x|.)).
    is_spatial_augmented <- isTRUE(extra$.spatial_unique_augmented) ||
      isTRUE(extra$.spatial_dep_augmented) ||
      isTRUE(extra$.spatial_latent_augmented)
    mode <- if (isTRUE(extra$.dep)) {
      "dep"
    } else if (isTRUE(extra$.spatial_latent)) {
      "latent"
    } else if (isTRUE(extra$.spatial_scalar)) {
      "scalar"
    } else if (isTRUE(extra$.spatial_indep)) {
      "indep"
    } else {
      "unique"
    }
    has_unique_diag <- isTRUE(extra$.spatial_unique_diag)
    admitted <- !is_spatial_augmented && !has_unique_diag &&
      mode %in% c("dep", "latent", "indep")
    label <- if (is_spatial_augmented) {
      sprintf("an augmented (intercept + slope) spatial_%s() random-regression term", mode)
    } else if (has_unique_diag) {
      "spatial_latent(unique = TRUE) (a free spatial Psi companion is not admitted for multinomial)"
    } else {
      sprintf("spatial_%s()", mode)
    }
    return(list(source = "spatial", mode = mode, admitted = admitted,
                label = label))
  }

  ## Defensive default-deny: any covstruct kind this classifier does not
  ## recognise is blocked rather than silently admitted.
  list(source = "unknown", mode = kind %||% "unknown", admitted = FALSE,
       label = sprintf("a %s covstruct", kind %||% "unknown"))
}

#' Early covstruct-keyed admission fence for multinomial() structured terms
#'
#' Classifies every covstruct in `parsed$covstructs` and aborts if any is
#' outside the current admitted set for a fit that includes a multinomial
#' (family_id 16) trait. See R/multinomial-fence.R for the full leak this
#' closes; kept as a separate early pass from the late `use_*` re-scan in
#' `gllvmTMB_multi_fit()` because several keywords desugar onto the same
#' engine flag as an admitted keyword and are only distinguishable here, from
#' the raw parser markers.
#'
#' Multiple `kernel_latent()` terms in one fit (multi-kernel) are NOT
#' classifiable from a single covstruct in isolation -- each individual term
#' would otherwise be an admitted plain loadings-only kernel cell on its own
#' (Slice 1). This function does that whole-fit check itself, after
#' classifying every covstruct individually: if more than one distinct
#' `kernel_latent` name is present, every kernel-sourced classification is
#' overridden back to blocked.
#'
#' @param covstructs `parsed$covstructs`, a list of covstruct specs.
#' @param family_id_vec Integer family-id vector (one per row of `data`).
#' @param site,ss_name,species,cluster2_col Grouping-tier column names, as
#'   used elsewhere in `gllvmTMB_multi_fit()` (unit / unit_obs / cluster /
#'   cluster2).
#' @return `invisible(NULL)`; called for its `cli_abort()` side effect.
#' @noRd
.multinomial_structured_admission <- function(covstructs, family_id_vec,
                                               site, ss_name, species,
                                               cluster2_col = NULL) {
  if (!any(family_id_vec == 16L)) {
    return(invisible(NULL))
  }
  cls_list <- lapply(covstructs, function(cs) {
    .mn_classify_covstruct(cs, site = site, ss_name = ss_name,
                            species = species, cluster2_col = cluster2_col)
  })
  ## Multi-kernel override (see roxygen above): count DISTINCT kernel names
  ## across all covstructs, admitted or not (two covstructs from the SAME
  ## kernel_latent(unique = TRUE) call share one name and must not count as
  ## "multi").
  kernel_names <- vapply(cls_list, function(cl) {
    if (identical(cl$source, "kernel")) cl$kernel_name %||% NA_character_ else NA_character_
  }, character(1L))
  if (length(unique(stats::na.omit(kernel_names))) > 1L) {
    cls_list <- lapply(cls_list, function(cl) {
      if (identical(cl$source, "kernel")) {
        cl$admitted <- FALSE
        cl$label <- "multiple kernel_*() terms in one fit (multi-kernel)"
      }
      cl
    })
  }
  labels <- character(0L)
  for (cls in cls_list) {
    if (!isTRUE(cls$admitted)) {
      labels <- c(labels, cls$label)
    }
  }
  if (length(labels) == 0L) {
    return(invisible(NULL))
  }
  cli::cli_abort(c(
    "{.fn multinomial} supports fixed effects, a shared {.fn latent} ordination, the phylogenetic/relatedness mode axis ({.fn phylo_latent}/{.fn animal_latent}/{.fn kernel_latent} and their {.fn phylo_dep}/{.fn phylo_indep}/{.fn animal_dep}/{.fn animal_indep}/{.fn kernel_dep}/{.fn kernel_indep} twins), the spatial (SPDE) mode axis ({.fn spatial_latent}/{.fn spatial_indep}/{.fn spatial_dep}), a generic {.code (1 | group)} random intercept, and the non-phylogenetic {.code cluster}/{.code cluster2} diagonal tier in this release.",
    "x" = "Not admitted: {.val {unique(labels)}}.",
    "i" = "Admitted set: {.code latent(0 + trait | unit, d = k)} (the default {.code unique = TRUE} works; the categorical contrast Psi is mapped off); {.code (1 | group)} (a baseline-vs-rest group effect -- {.code sigma_re} is reference-category-specific; subject to an OLRE guard, see below); {.code indep(0 + trait | <cluster_col>)}/{.code indep(0 + trait | <cluster2_col>)} via the {.arg cluster}/{.arg cluster2} arguments (per-contrast independent variances; the standalone {.code unique()} alias is admitted alongside {.code indep()} at this tier too; {.code common = TRUE} is NOT admitted; also subject to the OLRE guard); for the among-category phylogenetic/relatedness surface, intercept-only {.code phylo_latent(species, d = K)}/{.code animal_latent(species, A = A, d = K)}/single-named {.code kernel_latent(species, K = K, d = K, name = nm)} (loadings-only ordination), {.code phylo_dep(0 + trait | species)}/{.code animal_dep(0 + trait | id)}/{.code kernel_dep(unit, K = K, name = nm)} (the full unstructured (K-1)x(K-1) V), and {.code phylo_indep(0 + trait | species)}/{.code animal_indep(0 + trait | id)}/{.code kernel_indep(unit, K = K, name = nm)} (diagonal V, no among-category correlation; standalone {.code phylo_unique()}/{.code animal_unique()}/{.code kernel_unique()} are soft-deprecated aliases of the {.code indep} cell) -- {.code unique = TRUE} on {.fn phylo_latent}/{.fn animal_latent}/{.fn kernel_latent} is NOT admitted (a free phylogenetic Psi is deliberately unsupported for multinomial), {.fn phylo_scalar}/{.fn animal_scalar}/{.fn kernel_scalar} (a single shared level across contrasts) are NOT admitted, and more than one {.fn kernel_latent}/{.fn kernel_dep}/{.fn kernel_indep} name in the same fit (multi-kernel) is NOT admitted; and, for the spatial surface, intercept-only {.code spatial_latent(0 + trait | coords, d = k)} (shared fields), {.code spatial_indep(0 + trait | coords)} (per-contrast independent fields), or {.code spatial_dep(0 + trait | coords)} (full field covariance -- VERIFIED identical to {.code spatial_latent(d = n_traits)}) -- {.fn spatial_scalar} (a single shared level), {.code spatial_latent(unique = TRUE)}'s paired Psi_spde companion, and standalone {.fn spatial_unique}/deprecated bare {.fn spatial} (the paired-companion alias, not an independent diagonal cell) are NOT admitted.",
    "i" = "This fence is per-fit, not per-trait: a blocked term targeting only a non-multinomial trait in a mixed-family fit still aborts the whole fit.",
    ">" = "Other latent-scale structures on categorical responses -- including dep()/indep()/unique() at the unit tier, {.code latent()}/{.code dep()} at the cluster/cluster2 tiers, the {.code unit_obs} tier, phylo_scalar()/animal_scalar()/kernel_scalar(), multi-kernel, augmented (intercept + slope) forms of every keyword above (phylo/animal/kernel/spatial), *_latent(unique = TRUE), and meta_V()/equalto() -- are deferred."
  ), class = "gllvmTMB_multinomial_structured_not_admitted")
}

#' OLRE guard for `(1 | group)` / cluster / cluster2 group intercepts on a
#' multinomial trait
#'
#' A generic `(1 | g)` random intercept and the `cluster`/`cluster2`
#' `indep()`/`unique()` diagonal tier are admitted (Slice 4, Design 123) as a
#' family-agnostic, per-covstruct classification -- see
#' `.mn_classify_covstruct()` above. But when EVERY level of the grouping
#' factor covers exactly one multinomial observation (one row of the
#' `.multinom_group_` carrier `expand_multinomial_response()` writes), the
#' term is an observation-level random effect (OLRE) in disguise: the
#' softmax latent scale is fixed (no free residual-dispersion parameter,
#' unlike a Gaussian/count response), so a per-observation intercept shared
#' across that observation's own K-1 contrast rows is not identifiable from
#' the fixed effects alone. This is a WHOLE-FIT check against `data` (it
#' needs the observation-to-group mapping, not just the covstruct shape), so
#' it runs as a separate pass after `.multinomial_structured_admission()`,
#' mirroring how the multi-kernel override sits on top of an individually-
#' admitted classification.
#'
#' @param covstructs `parsed$covstructs`.
#' @param data The (already multinomial-expanded) model data frame; must
#'   carry `.multinom_group_` when any fid-16 row is present (always true
#'   once `expand_multinomial_response()` has run).
#' @param family_id_vec Integer family-id vector, one per row of `data`.
#' @param site,ss_name,species,cluster2_col Grouping-tier column names, as in
#'   `.multinomial_structured_admission()`.
#' @return `invisible(NULL)`; called for its `cli_abort()` side effect.
#' @noRd
.multinomial_reint_group_olre_guard <- function(covstructs, data, family_id_vec,
                                                  site, ss_name, species,
                                                  cluster2_col = NULL) {
  if (!any(family_id_vec == 16L) || !(".multinom_group_" %in% names(data))) {
    return(invisible(NULL))
  }
  mn_rows <- family_id_vec == 16L
  if (!any(mn_rows)) {
    return(invisible(NULL))
  }
  mgrp_all <- data[[".multinom_group_"]]
  for (cs in covstructs) {
    kind <- cs$kind
    tier <- .mn_covstruct_tier(cs, site = site, ss_name = ss_name,
                                species = species, cluster2_col = cluster2_col)
    is_group_term <- identical(kind, "re_int") ||
      (identical(kind, "diag") && tier %in% c("cluster", "cluster2"))
    if (!is_group_term) {
      next
    }
    gname <- tryCatch(as.character(cs$group), error = function(e) NA_character_)
    if (is.na(gname) || !(gname %in% names(data))) {
      next # a bad/missing column is reported by the caller's own checks
    }
    grp_vals  <- data[[gname]][mn_rows]
    mgrp_vals <- mgrp_all[mn_rows]
    if (length(grp_vals) == 0L) {
      next
    }
    grp_f <- droplevels(factor(grp_vals))
    n_obs_per_level <- tapply(mgrp_vals, grp_f, function(x) length(unique(x)))
    if (length(n_obs_per_level) > 0L && all(n_obs_per_level == 1L)) {
      term_label <- if (identical(kind, "re_int")) {
        sprintf("(1 | %s)", gname)
      } else {
        sprintf("indep(0 + trait | %s)", gname)
      }
      cli::cli_abort(c(
        "{.code {term_label}} is an observation-level random effect (OLRE) in disguise for {.fn multinomial}.",
        "x" = "Every level of {.var {gname}} covers exactly one categorical observation (one multinomial draw): {length(n_obs_per_level)} levels, {length(n_obs_per_level)} observations.",
        "i" = "The {.fn multinomial} softmax latent scale is fixed (unlike a Gaussian/count residual variance), so a per-observation intercept shared across its own K-1 baseline-contrast rows is not identifiable from the fixed effects.",
        ">" = "Use a coarser grouping factor with multiple categorical observations per level, or drop the term."
      ), class = "gllvmTMB_multinomial_olre_not_admitted")
    }
  }
  invisible(NULL)
}
