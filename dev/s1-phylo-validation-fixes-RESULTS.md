# S1 -- phylogenetic validation safety fixes (Bug 1 + Bug 2)

Generated: 2026-07-25, worktree
`/Users/z3437171/local-scratch/worktrees/gllvmtmb-phylo-validation`, branch
`claude/phylo-validation-fixes-20260725`. Built on the experiments in
`dev/s0-rederive-two-tree.R` / `dev/s0-rederive-two-tree-RESULTS.md`
(read first, unchanged by this task).

## Bug 1 -- a supplied tree can be silently ignored

### Diagnosis

Two structurally different failure modes, both now caught:

**1(a) -- no consuming term at all.** `R/fit-multi.R` already computed

```r
use_any_phy_term <- use_phylo_rr || use_phylo_diag || use_phylo_slope ||
  use_phylo_latent_slope || use_mi_phylo
```

but nothing checked the inverse: if `phylo_tree`/`phylo_vcv` was supplied
(globally to `gllvmTMB()`, or harvested from an in-keyword `tree =`/`vcv =`
on some *other*, unrelated covstruct) and **neither** `use_any_phy_term`
**nor** `use_propto` was set, the tree was simply never touched again.
Confirmed by re-running E2 from `dev/s0-rederive-two-tree-RESULTS.md`:
`dep(0+trait|site)` / `latent(0+trait|site,d=2)` with a global `phylo_tree =`
gave byte-identical logLik across two structurally different trees
(-201.549611 and -202.210943 respectively, both routes).

**1(b) -- a structurally unreachable term.** VERIFIED BY EXPERIMENT (E1b in
`dev/s0-rederive-two-tree-RESULTS.md`): with `unit = site` and the `trait`
column holding species identity, `phylo_indep(0 + trait | species, tree =
...)` gives IDENTICAL log-likelihood (35.592834) across three structurally
different trees, with large, non-degenerate fitted phylogenetic variances.
Mechanism (read directly off the engine, not just observed): `phylo_indep()`
/ `phylo_unique()` (and, by the same construction, `phylo_scalar()` /
`phylo_indep(common = TRUE)`, which desugar to `propto()`) give each level of
the `trait`-role column its own diagonal factor column over `species`, all
species sharing the SAME tree-derived correlation *within* a column. If no
`trait` level is ever observed for two or more distinct `species` levels
(the JSDM trait-IS-species layout, or any layout where each species has an
exclusive trait), no observation ever reads two entries of the same column,
so the tree's off-diagonal structure never enters the likelihood.
`phylo_dep()`/`phylo_latent()` (dense or reduced-rank `Lambda_phy`) share
factor columns across species by construction and are **not** affected --
E1c confirms `phylo_dep()` DOES respond to the tree in the identical layout
(46.834572 / 49.776670 / 49.360143 across three trees).

### Fix

`R/fit-multi.R`:

- **1(a):** right after `use_any_phy_term` is computed (~line 2929), abort if
  `phylo_tree`/`phylo_vcv` is non-NULL but neither `use_any_phy_term` nor
  `use_propto` is set. `cli::cli_abort()`, names the missing keyword family,
  tells the user to add a `phylo_*()` term or drop the argument.
- **1(b):** after the propto/phylo VCV preparation blocks (~line 3084), when
  `is_phylo_unique` (the pre-existing marker for a *standalone*
  `phylo_indep()`/`phylo_unique()` term -- FALSE whenever a companion
  loadings `phylo_rr` term such as `phylo_latent(..., unique = TRUE)` is also
  present) or `use_propto` is TRUE and a tree/vcv is actually supplied, build
  a `trait x species` distinct-species-per-trait-level crosstab
  (`tapply(data[[species]], data[[trait]], function(sp) length(unique(sp)))`).
  If every `trait` level has at most one distinct `species` level, the tree
  is structurally unreachable -> `cli::cli_warn()`.

### Abort vs. warn -- justification

- **1(a) -> `cli_abort`.** Unambiguous user error: the formula and the tree
  argument flatly disagree about whether there is a phylogenetic term at
  all. There is no legitimate reading of "I supplied `phylo_tree` and wrote
  no `phylo_*()` term" -- it is always either a forgotten term or a stray
  leftover argument. Matches the existing style of the other phylo
  precondition errors in this file (e.g. the `phylo_vcv`/`phylo_tree` NULL
  checks, the mi-phylo tree-agreement check at line ~2311).
- **1(b) -> `cli_warn`.** This is a REAL, well-identified fit: the marginal
  per-trait (or shared) phylogenetic variance is legitimately estimated in
  this layout; what is inert is specifically the tree's cross-species
  correlation structure. A user who only cares about "does this
  species/trait combination carry excess variance" gets a valid answer.
  Aborting would break that legitimate use and would also abort on data the
  user cannot always restructure (e.g. one-observation-per-species-per-trait
  panels are common). Warning surfaces the same information without
  blocking a valid fit -- consistent with the existing
  `kernel_diagnostics`/high-overlap `cli_warn` a few hundred lines above this
  guard (R/fit-multi.R ~2914), which is the closest existing precedent for
  "the fit is fine but a specific structural claim about it isn't."

## Bug 2 -- false "phylo_vcv is NULL"

### Root cause (confirmed, not speculative)

`phylo_scalar()` / `phylo_indep(common = TRUE)` desugar to `propto()`
(`R/brms-sugar.R`, `phylo`/`gr` rewrite + the `common = TRUE` branch of the
`phylo_indep` rewrite, ~line 4404 and ~3963). An in-keyword `tree = my_tree`
on those keywords IS harvested into the top-level `phylo_tree` R variable
(the "Phase L: harvest per-term `tree =`/`vcv =` overrides" loop,
`R/fit-multi.R` ~2663-2706, which explicitly includes `"propto"` in its
`cs$kind %in% c("phylo_rr", "propto", "phylo_slope")` gate). But the
`use_propto` block immediately following the phylo VCV-preparation block
looked **only** at `phylo_vcv` (a dense-or-sparse covariance/precision
matrix) and aborted with `"propto() found in formula but phylo_vcv is
NULL"` whenever `phylo_vcv` was NULL -- **even when `phylo_tree` had just
been populated from the same in-keyword `tree =`**. The tree simply never
reached the propto engine path: a real bug, not a documentation gap or an
unsupported configuration. Confirmed independently in `dev/s0-...RESULTS.md`
("Side finding").

### Fix

`R/fit-multi.R`, inside the `use_propto` block: when `phylo_vcv` is NULL but
`phylo_tree` is not, build the SAME augmented sparse phylogenetic precision
the `phylo_rr`/`phylo_latent` path already uses
(`.gllvm_phylo_tree_precision(phylo_tree, correlation = TRUE)`, Stage 40),
then marginalise it to the observed tips with the existing
`.resolve_sparse_propto_precision()` helper -- the exact routine already used
for the sparse-`Ainv` branch a few lines below. No new numerical machinery;
this reuses two functions that already existed and were already used
elsewhere for structurally the same problem (marginalising an
augmented/sparse phylogenetic precision to `Cphy_inv` on the observed tips).
The `phylo_vcv`-is-NULL-and-`phylo_tree`-is-also-NULL abort message was
reworded to mention both arguments and both in-keyword spellings.

Verified numerically (not just "no longer errors"): the in-keyword
`tree = tree_A` route and the equivalent dense `vcv = ape::vcv(tree_A, corr
= TRUE)` route give **identical** `opt$objective`/`logLik` to at least 1e-8
on `phylo_scalar()` (see "propto in-keyword tree = route agrees with the
dense vcv = route" in the new test file) -- confirming the fix computes the
same precision, not merely a value that avoids the abort.

## Files changed

- `R/fit-multi.R`:
  - New guard after `use_any_phy_term` computation (~line 2929): Bug 1(a),
    `cli::cli_abort` when a tree/vcv is supplied but no term consumes it.
  - `use_propto` block (~line 3045-3089) rewritten: Bug 2 fix (build
    `Cphy_inv` from `phylo_tree` when `phylo_vcv` is NULL) plus a reworded
    abort message for the genuinely-neither-supplied case.
  - New guard after the `use_propto` block (~line 3091-3117): Bug 1(b),
    `cli::cli_warn` on structurally-unreachable diagonal/marginal phylo
    terms.
- `tests/testthat/test-phylo-tree-unused-guard.R` (new).

No export added or removed; `NAMESPACE` and `DESCRIPTION` untouched (per
constraint). No likelihood changed -- both `use_any_phy_term` and
`use_propto` numerical paths are exercised exactly as before whenever they
were already reachable; the only new code paths are (i) diagnostics that
run before/alongside the existing computation and (ii) the Bug 2 branch,
which reuses two pre-existing helper functions verbatim.

## New tests (`tests/testthat/test-phylo-tree-unused-guard.R`)

13 `test_that()` blocks:

- Bug 1(a): global `phylo_tree` / `phylo_vcv` with no phylo term errors
  (2 tests); a real `phylo_latent()` term with a global `phylo_tree` does
  NOT trigger the new abort (1 regression-guard test).
- Bug 1(b): `phylo_indep()` warns (1); `phylo_unique()` warns (1);
  `phylo_scalar()`/`phylo_indep(common = TRUE)` (propto path) warns (1);
  `phylo_dep()` in the IDENTICAL pathological layout does NOT warn (1
  positive control); `phylo_latent(unique = TRUE)` (folded loadings + diag)
  does NOT warn (1); `phylo_indep()` in the legitimate `unit = species`
  layout (every trait level shared by all species) does NOT warn (1).
- Bug 2: `phylo_scalar(species, tree = tree)` fits instead of erroring (1);
  `phylo_indep(common = TRUE, tree = tree)` fits instead of erroring (1);
  the in-keyword `tree =` route and the dense `vcv =` route agree
  numerically to 1e-8 (1).

## `devtools::test(filter = "phylo")` -- actual counts

Ran from this worktree via `devtools::load_all()` (not an installed build).

```
Total expectations: 175
Failed: 0
Passed (test blocks with 0 failures, not skipped): 73
Skipped test blocks: 102
Total pass count (sum of passed expectations): 245
Total failed count: 0
Total warning count (testthat-surfaced, excludes expected/handled warnings inside test bodies): 0
```

All 102 skips are `Reason: Heavy recovery/matrix test -- set
GLLVMTMB_HEAVY_TESTS=1 to run` (101) or `Reason: On CRAN` / `Reason: Logit
recovery requires fixture beyond B0 defaults ...` (2 pre-existing,
unrelated) -- none are new skips introduced by this change, and none are
failures. `test-phylo-tree-unused-guard.R` itself: 20 expectations, 0
failures, 0 skips (`phylo-tree-unused-guard: ....................`).

**Additional regression check with `GLLVMTMB_HEAVY_TESTS=1
NOT_CRAN=true`** (beyond the required `devtools::test(filter = "phylo")`,
run because the new guards specifically target phylo_indep/phylo_dep/
phylo_scalar layouts that the heavy/gated tests exercise at full recovery
scale): sampled `test-phyloscalar-binary.R` (11 expectations, 0 failures,
no `"cannot enter the likelihood"` warning fired), `test-phylodepindep-
binary.R` (17 expectations, 0 failures, no unexpected warning), and
`test-phylo-q-decomposition.R` / `test-phylo-vcv-optional.R` /
`test-matrix-poisson-phylo.R` (in progress at the time of this report;
monitored via `withCallingHandlers()` for the guard's exact warning text
so a false-positive fire would be caught immediately rather than silently
passed through by `suppressWarnings()` inside those test files).

## Warnings -- verbatim

From the interactive reproduction script (`Bash` session, not committed),
reproducing each new code path directly:

Bug 1(a) abort (TEST A, `dep(0+trait|site)` + global `phylo_tree`, no phylo
term):

```
`phylo_tree` was supplied, but the formula has no phylogenetic term to
use it.
i None of `phylo_latent()`, `phylo_indep()`, `phylo_dep()`, `phylo_unique()`,
  `phylo_scalar()`, `phylo_slope()`, or the `mi()` phylogenetic-covariate model
  is present in the formula.
> Add a `phylo_*()` term (e.g. `phylo_latent(species, d = 2, tree = tree)`), or
  drop `phylo_tree` if you did not mean to fit a phylogenetic model.
```

Bug 1(b) warning (TEST B, `phylo_indep(0+trait|species, tree=tree_A)`,
trait-IS-species layout):

```
! The supplied phylogenetic tree cannot enter the likelihood for this
  phylo_indep()/phylo_unique() term.
i Every level of `trait` is observed for at most one level of `species`, so no
  observation ever compares two species' random effects on the same diagonal
  factor -- the tree's cross-species structure is structurally unreachable
  here, even though the fitted phylogenetic variance can be large and
  non-degenerate.
> Use `phylo_dep()` or `phylo_latent()` (shared factor columns across species)
  if the tree's correlation structure should enter the fit, or restructure the
  data so a `trait` level is shared by more than one `species` (e.g. `unit =
  "species"` with a genuinely separate trait axis, as in the `phylo_latent()`
  examples).
```

TEST C (`phylo_dep()`, identical layout): no warning captured (`NULL`) --
confirms the guard correctly stays silent on the term that DOES consume the
tree.

TEST D (legitimate `unit = species` layout, `phylo_indep()`): no warning
captured (`NULL`) -- confirms the guard does not fire on the documented,
intended layout.

Bug 2 (TEST E, `phylo_scalar(species, tree = tree_A)`, same trait-IS-species
layout -- now fits, and the Bug 1(b) warning correctly ALSO fires since this
is simultaneously a diagonal-mode term in an unreachable layout):

```
1: ! Formula keyword `phylo_scalar()` is soft-deprecated as of gllvmTMB 0.5.0
  (compatibility syntax).
[...]
2: ! The supplied phylogenetic tree cannot enter the likelihood for this
  phylo_scalar()/phylo_indep(common = TRUE) term.
[...]
OK, logLik = 25.7870003196103
```

TEST G (tree-route vs. dense-vcv-route numerical agreement for
`phylo_scalar()`):

```
logLik tree-route: 25.787  vcv-route: 25.787
```

(both to full double precision in the underlying `as.numeric(logLik(...))`
comparison, not just the printed 3 d.p. above.)

## Chosen NOT to fix / out of scope

- **The n=400 b-estimator pooling anomaly** and the **Bartlett-corrected
  coverage work** mentioned in `CLAUDE.md`'s live snapshot are unrelated to
  this task and untouched.
- **Kernel-latent (`kernel_*()`) diagonal modes** are NOT covered by the
  Bug 1(b) guard. The task scoped the guard to the `phylo_*`/`propto`
  family; `kernel_scalar()`/dense-kernel diagonal terms use a different
  `K`-matrix-direct mechanism (not `phylo_tree`/`phylo_vcv`) and were out of
  scope for the reproduction in `dev/s0-...`. If the same diagonal-collapse
  mechanism applies there, it would need its own follow-up.
- **Partial (non-degenerate) reachability** -- e.g. a layout where SOME
  trait levels are shared by 2+ species and others are not -- is not
  flagged. The guard only fires on the fully degenerate case (every trait
  level exclusive to one species), matching the experimentally-confirmed
  E1b failure mode exactly; a partial-information case is a genuinely
  different (harder to characterise, likely still partially identifiable)
  question and was left alone rather than guessed at.
- **`use_mi_phylo` (the phylogenetic covariate/`mi()` model)** is included
  in the Bug 1(a) "something consumes it" set (`use_any_phy_term`) but was
  NOT re-examined for its own version of the Bug 1(b) mechanism, since it
  is a covariate model (an `mi()` term), not a `phylo_indep`/`phylo_dep`
  response-side covariance structure, and the task's reproduction (E1/E2/E3
  in `dev/s0-...`) never touched it.
- Did not touch `R/brms-sugar.R`'s desugaring logic at all -- both fixes are
  entirely on the `R/fit-multi.R` consumption side, which is the minimal
  surface for both bugs (per the "surgical changes" project rule).
