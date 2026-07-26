# Ayumi Mizuno usability fixes (urbanisation_map #13)

Branch: `claude/ayumi-usability-fixes-20260725`
Worktree: `/Users/z3437171/local-scratch/worktrees/gllvmtmb-ayumi-fixes`

Source: three defects reported after running gllvmTMB against `gllvm` and
`glmmTMB` on a 44-indicator applied analysis
(https://github.com/Ayumi-495/urbanisation_map/issues/13; the repo/issue
returned 404 to both `gh api` and `curl` when checked from this session --
likely private -- so this work is grounded in the three item descriptions in
the task brief and in direct experiment, not in the raw issue thread).

`NAMESPACE` is unchanged (verified `shasum -a 256 NAMESPACE` still
`c97ae039f1a58346a129e988e127cc8464a401264eb530d6a7da905fd329ff46`, matching
the frozen hash). No export added or removed. `DESCRIPTION` untouched.

---

## Item 1 -- `?latent`'s `lv` doc said "reserved / not implemented"

**Reproduction.** Fit a small model with `latent(..., lv = ~ x)` on `main`
(pre-existing code, no changes applied yet):

```r
site_x <- setNames(rnorm(length(site_levels)), site_levels)
df$x <- site_x[as.character(df$site)]
fit <- gllvmTMB(
  value ~ 0 + trait + latent(0 + trait | site, d = 2, lv = ~ x),
  data = df, unit = "site"
)
extract_lv_effects(fit)
```

Output (verbatim):

```
  level axis predictor   estimate std.error      lower     upper
1  unit  LV1         x -0.1979296 0.1955384 -0.5811778 0.1853186
2  unit  LV2         x -0.1596030 0.2206680 -0.5921043 0.2728984
                rotation_status             uncertainty_status
1 axis_scale_rotation_dependent wald_sdreport_no_ci_validation
2 axis_scale_rotation_dependent wald_sdreport_no_ci_validation
```

The fit runs and returns coefficients, confirming the user's report. Note:
`lv` predictors must be **constant within `unit`** (a real, separate,
already-typed guard: `` `lv` predictors must be constant within each `unit`.
✖ Nonconstant unit level(s): ...``) -- the first naive attempt (a per-row
random `x`) hit this and had to be corrected to a unit-constant covariate.

**Diagnosis.** `?latent`'s `@param lv` roxygen (`R/brms-sugar.R`, the
`latent()` function) did once say exactly what the user quotes:

```
#' @param lv Reserved one-sided formula for Design 73 predictor-informed latent
#'   score means. Current releases validate the parser surface and then stop
#'   before fitting; no runtime support is implemented yet.
```

`git log -S"reserved / not implemented"` and `git blame` on `man/latent.Rd`
show this was **already corrected in commit `1403c8e3`
("docs: fix 8 honesty ship-blockers on public/shipped doc surfaces (0.5.0)",
2026-07-12)**, well before this branch was created from `main`. The commit
message names this exact defect as ship-blocker #1: *"latent() @param lv:
drop the false 'no runtime support implemented yet'; state the true regime."*
So as literally quoted, the defect **does not reproduce on current `main`**
-- the user's installed version (CRAN, an older tag, or an older checkout)
predates 2026-07-12.

A full sweep for the same convention (`grep` across `R/`, `man/`, `NEWS.md`,
`vignettes/`) found no other surface still carrying the stale "reserved /
not implemented" claim for `lv`. The current roxygen (verified clean, no
change needed):

> "Runtime support is limited to ordinary unit-tier `latent(..., lv = ~ x)`,
> and only Gaussian and pure binomial (logit/probit/cloglog) fits are
> currently admitted (partial coverage, supported for the ordinary-latent
> case). Source-specific `*_latent(..., lv = ~ x)` forms are parsed and then
> fail loud (not yet fittable)."

This is accurate and not overclaiming -- but it is a runtime-coverage
description only. It never told the reader that the *result* is
experimental, that its default output (`extract_lv_effects()`'s
`axis_effect`) is rotation-dependent (item 3), or that its intervals are
uncalibrated Wald approximations -- exactly the three caveats the task asked
the corrected wording to carry. `extract_lv_effects()`'s own roxygen already
states all three caveats in detail, but `?latent` never pointed a reader
there (`@seealso` listed `indep()`, `phylo_latent()`, `diag_re`,
`extract_Sigma()` -- not `extract_lv_effects()`).

**What changed.** `R/brms-sugar.R`, `latent()`'s `@param lv`: appended one
paragraph stating the fit is experimental/exploratory where admitted, that
`extract_lv_effects()` is the way to get the coefficients, that its default
`axis_effect` output is rotation-dependent (an intrinsic latent-axis
indeterminacy, not a defect, with a pointer to the rotation-invariant
`trait_effect` alternative), and that its SEs/intervals are uncalibrated
Wald approximations. Added `extract_lv_effects()` to `@seealso`.
`devtools::document()` regenerated `man/latent.Rd` (only this Rd changed:
+14/-4 lines net, no other content moved).

**What was deliberately NOT changed.** The runtime-coverage sentence itself
(already accurate, already fixed in `1403c8e3`) -- this is a fence/pointer
addition, not a rewrite of already-correct text. No other roxygen block,
vignette, or `NEWS.md` entry needed touching (swept clean, see above). No
new capability was implemented or claimed.

---

## Item 2 -- errors on unused factor levels

**Reproduction attempts that did NOT reproduce a bug** (documented as
negative findings, not silently discarded): a plain ordinary `latent(0 +
trait | site, d = 2)` fit with the `site` grouping factor carrying 20
declared levels but only 15 present in the (filtered) data fit without
error or warning about levels. Same result for an ordinary `(1 | block)`
random intercept with an unused level, and for a fixed-effect factor
covariate (`habitat`) with an unused level. Ordinary glmmTMB-style grouping
factors tolerate unused levels the same way `lme4`/`glmmTMB` do (the
random-effect prior for the unused level just carries no data).

**Reproduction that DID reproduce a real bug**: the phylogenetic path.
`phylo_latent()` / `phylo_scalar()` / `phylo_indep(common = TRUE)` (via the
`propto()` desugar) each build `levs <- levels(data[[species]])` -- the
FULL declared factor level set of the species column, including any level
with zero observations after the caller filtered rows without
`droplevels()` -- and require the supplied `phylo_tree`/`phylo_vcv`/`Ainv`
to cover every one of those declared levels, even the unused ones. A tree
or vcv built to match only the *retained* species (the natural thing to do
after filtering) does not cover the stale unused level, and the fit aborts.

Verbatim reproduction (dense `phylo_vcv` path, `R/fit-multi.R`, before the
fix):

```r
tree <- ape::rcoal(20); tree$tip.label <- paste0("sp", 1:20)
# ... simulate df with species = tree$tip.label ...
df2 <- df[df$species != "sp1", ]        # NOT droplevelled: nlevels stays 20
tree2 <- ape::drop.tip(tree, "sp1")      # tree matches the retained 19 species
Cphy2 <- ape::vcv(tree2, corr = TRUE)
gllvmTMB(value ~ 0 + trait + phylo_latent(species, d = 1),
         data = df2, phylo_vcv = Cphy2)
```

```
Error in `gllvmTMB_multi_fit()` at .../R/gllvmTMB.R:781:3:
! phylo_vcv rownames do not cover all species levels.
```

`df2$species <- droplevels(df2$species)` before fitting resolves it (as
the user reported). Confirmed to reproduce identically across all four
call sites that perform this check: the `phylo_tree` sparse-A^-1 path, the
sparse `phylo_vcv`/`Ainv` path, the legacy dense `phylo_vcv` path (all
three inside `phylo_latent()`/`phylo_slope()`), and the `propto()` path
used by `phylo_scalar()`/`phylo_indep(common = TRUE)`.

**Diagnosis and decision.** Per the task brief's default -- recommend a
typed, actionable error naming `droplevels()` unless dropping levels
internally is *clearly* safe -- I chose the explicit-error route (b), not
silent internal dropping (a). Reasoning: whether dropping the unused level
internally changes the fit depends on subtle phylogenetic marginalization
details (an unused tip left IN a supplied tree/vcv is still validly
marginalized over and is NOT obviously equivalent to a tree that never
had it; see the existing `.resolve_sparse_phylo_precision()` comment on
why "subsetting a precision would condition on the dropped nodes, not
marginalize them"). Given the package's standing "don't do things
silently" arc, an explicit, actionable error is the safer choice; it does
not touch likelihood semantics at all.

The old message ("phylo_vcv rownames do not cover all species levels.")
was also not actionable -- it did not distinguish "the mismatch is just an
unused level; droplevels() fixes it" from "the mismatch is a genuinely
observed species the tree/vcv is missing; droplevels() cannot help."

**What changed.** Added one helper,
`.gllvm_abort_uncovered_species_levels()` (`R/fit-multi.R`, near
`.resolve_sparse_propto_precision()`), that splits the uncovered species
levels into (i) declared-but-unused (zero rows in `data`) -- names
`droplevels()` explicitly as the fix -- and (ii) declared-and-observed
(a genuine tree/vcv coverage gap, NOT fixed by `droplevels()`). Replaced
the four `if (!all(levs %in% <source>)) cli::cli_abort("... do not cover
all species levels.")` call sites (phylo_tree branch, sparse phylo_vcv/Ainv
branch, legacy dense phylo_vcv branch, and the `propto()` phylo_tree/
phylo_vcv branches) with calls to this helper. No likelihood, parameter,
or dimension computation changed -- only the diagnostic message fires
earlier and more specifically; the eventual TMB construction is untouched.

New error message (verbatim, unused-level case):

```
! `phylo_vcv` rownames do not cover all species levels.
i 1 declared level of `species` has no observations in `data` and is not
  covered: sp1.
→ Call `droplevels()` on `species` (or refactor before fitting) so its
  levels match the species actually being fit.
```

New error message (verbatim, genuine-mismatch case, both reasons present
at once):

```
! `phylo_vcv` rownames do not cover all species levels.
i 1 declared level of `species` has no observations in `data` and is not
  covered: sp1.
→ Call `droplevels()` on `species` (or refactor before fitting) so its
  levels match the species actually being fit.
i 1 observed species level of `species` not covered: sp2. This is a
  genuine mismatch and is NOT fixed by droplevels() -- supply a tree/vcv
  that covers these species.
```

**What was deliberately NOT changed.** The two duplicate internal guards
inside `.resolve_sparse_phylo_precision()` and
`.resolve_sparse_propto_precision()` (`R/fit-multi.R` lines ~196, ~240)
keep the old generic message text. They are defensive/unreachable in
normal operation: every caller already runs the new, more specific check
immediately before invoking these helpers, so these are dead-path fallbacks
kept as-is per "surgical changes" (touching them would be speculative
hardening, not part of this fix). Ordinary (non-phylogenetic) grouping
factors are untouched -- they did not reproduce a bug, so nothing to fix
there; documented as a negative finding above rather than silently
dropped.

---

## Item 3 -- `axis_effect` is rotation-dependent

**Investigation.** `extract_lv_effects(fit, type = "axis_effect")` returns
the raw axis-scale coefficient `alpha` from `latent(..., lv = ~ x)`'s score
model `u_s = z_s + X_s alpha`. Rotation-dependence here is intrinsic to
latent-variable/ordination identifiability (the same indeterminacy already
documented for the loadings themselves, `extract_loadings()`/
`getLoadings()`) -- **not a defect**. `docs/design/06-extractors-contract.md`
(dated 2026-07-21, i.e. already existed before this task) and
`extract_lv_effects()`'s own roxygen already documented this thoroughly:
the `rotation_status` column literally reads
`"axis_scale_rotation_dependent"`, and the roxygen already states
`type = "trait_effect"` ($B_\text{lv} = \Lambda\alpha^\top$) is the
rotation-invariant alternative. So most of item 3 was, like item 1,
already substantially addressed -- but neither doc connected the dots for
the user's stated need ("must be manually rotated and aligned before
cross-fit comparison"): no doc said *which* extractor call to prefer for
cross-fit comparison, and none confirmed whether the package's existing
rotation helpers (`rotate_loadings()`, `getLoadings(rotate = ...)`) can be
composed with `axis_effect` at all.

**Verified numerically** (not just derived on paper, given the risk of
publishing a wrong recipe): the mean latent score `X %*% alpha` rotates
exactly as `rotate_loadings()`'s `scores` do. For the `T` returned by
`rotate_loadings(fit, level, method)$T`,

```r
alpha_rot          <- alpha %*% T
mean_rot_via_alpha <- X %*% alpha_rot
mean_rot_direct    <- extract_ordination(fit, component = "mean")$scores %*% T
# max(abs(mean_rot_via_alpha - mean_rot_direct)) == 5.55e-17
```

and `type = "trait_effect"` ($B_\text{lv}$) is confirmed invariant under
the same rotation to the same tolerance.

**What changed.** No code/behaviour change (none needed -- confirmed
intrinsic, not a bug). Documentation only, in two places:
1. `R/extractors.R`, `extract_lv_effects()` roxygen: added an explicit
   paragraph stating the rotation-dependence is intrinsic (not a defect),
   recommending `type = "trait_effect"` for cross-fit comparison, and
   stating the verified `alpha %*% T` composition with `rotate_loadings()`
   for users who specifically need the aligned axis-scale representation
   -- while being explicit that **no separate exported helper performs
   this composition** (per the constraint not to invent one).
2. `docs/design/06-extractors-contract.md`: added the matching paragraph
   under `extract_lv_effects()`, citing the issue.

**What was deliberately NOT changed.** No new exported alignment helper
(would breach the NAMESPACE freeze and was explicitly out of scope). No
change to `rotate_loadings()` itself to auto-rotate `axis_effect` -- that
would be a new capability/behavior change beyond a documentation fix, and
was not requested.

---

## Files touched

- `R/brms-sugar.R` -- `latent()` roxygen (`@param lv`, `@seealso`).
- `R/extractors.R` -- `extract_lv_effects()` roxygen.
- `R/fit-multi.R` -- new `.gllvm_abort_uncovered_species_levels()` helper;
  4 call sites updated to use it.
- `docs/design/06-extractors-contract.md` -- `extract_lv_effects()` section.
- `man/latent.Rd`, `man/extract_lv_effects.Rd` -- regenerated via
  `devtools::document()`.
- `tests/testthat/test-species-unused-levels-guard.R` -- new, 6 tests
  (item 2).
- `tests/testthat/test-lv-effects-rotation.R` -- new, 3 tests (item 3
  regression guard for the verified rotation recipe, plus the item-1
  reproduction that `latent(..., lv = ~x)` fits and returns coefficients).

`NAMESPACE`/`DESCRIPTION`: untouched (verified, see top of this file).

## Test counts

- `devtools::document()`: only `latent.Rd` and `extract_lv_effects.Rd`
  regenerated; `NAMESPACE` byte-identical (SHA-256 confirmed).
- `devtools::test(filter = "latent|lv|extract")`:
  **`FAIL 0 | WARN 2 | SKIP 82 | PASS 1416`**. The 2 warnings are
  pre-existing and unrelated (`test-comparator-gllvm.R`, "There are rows
  full of zeros in y" on an unconstrained binary-ordination cross-package
  comparison). The 82 skips are the standing `GLLVMTMB_HEAVY_TESTS=1`-gated
  recovery/matrix tests, not new.
- `devtools::test(filter = "phylo|animal|kernel|propto|species-unused")`
  (broader regression sweep over every code path touched by the item-2
  fix): **`FAIL 0 | WARN 0 | SKIP 151 | PASS 572`**.
- New test files run individually:
  `test-species-unused-levels-guard.R` -- 6/6 pass.
  `test-lv-effects-rotation.R` -- 3/3 pass.
