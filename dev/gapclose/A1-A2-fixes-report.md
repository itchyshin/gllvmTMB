# A1-A2 corrections — adversarial review response (2026-09-02)

Worktree: `/Users/z3437171/local-scratch/lanes/gllvmTMB-gapclose-20260902`
Branch: `claude/gapclose-20260902`. Not committed (per brief).

Source review: `.../scratchpad/verify-opus.md`, probes `.../scratchpad/vv/p1.R..p8.R`.
Scope here is exactly the eight items the coordinator assigned: **B2
(BLOCKING), R2, R3, R4, R7, R8, S1, R1**. B1, R5, R6, S2, S3, S4 belong to
other lanes and are untouched. `README.md`, `NEWS.md`, `DESCRIPTION`,
`R/zzz.R`, `vignettes/` untouched per instruction.

## B2 (BLOCKING) — group-axis redirect named a route that refuses

**Root cause**: the redirect logic only conditioned on the RHS of `|`
(trait vs. not), never on whether a relatedness axis (`tree=`/`A=`) was
actually available. For an ordinary column like `site`, or the spatial
placeholder `coords`, `phylo_slope(x | site, tree = tree)` /
`animal_slope()` are meaningless — no tree covers `site`'s levels, and a
pedigree over coordinates makes no sense.

**Fix**: `.assert_no_augmented_lhs()` (`R/brms-sugar.R`, def. ~2382,
non-trait branch ~2438) now branches three ways:
1. RHS = trait -> unchanged (response-column slope grammar: `slope()`/
   `phylo_slope()`/`animal_slope()`).
2. `fn` is a `spatial_*` keyword -> **no phylo/animal name at all**; says
   plainly there is no supported multi-covariate route, fit separate
   models.
3. Otherwise (bare `latent`/`unique`/`indep`/`dep`/`scalar`) -> checks the
   LHS shape via the existing `.gllvmTMB_lhs_form()`: a **single** slope
   covariate names `latent(1 + x | group, d = K)` / `unique(1 + x |
   group)` (verified fitting, `conv = 0`, for both); **more than one**
   slope covariate has no supported single-term route at all (`indep`/
   `dep`/`scalar` never had an augmented engine; `latent`/`unique`'s own
   augmented engine only reaches this fallback for shapes it does NOT
   support), so the message says so plainly.

Verified against every probe in the review:
- `indep(1 + x | site)` -> names `latent(1 + x | site, d = K)` /
  `unique(1 + x | site)`; both **fit**, `conv = 0`.
- `dep(1 + x | site)` -> same redirect (verified message text).
- `spatial_dep(1 + x1 + x2 | coords)` -> "no supported route for more
  than one slope covariate ... fit separate models, one covariate per
  `spatial_dep()` term" — no `phylo_slope`/`animal_slope` mentioned
  (`expect_false(grepl("phylo_slope|animal_slope", msg))`).
- `phylo_slope(x | species, tree = tree)` remains verified fitting on its
  own genuine merits (unchanged; still correctly the response-column /
  group-axis route when the grouping IS phylogenetic).

Tests: `tests/testthat/test-gapclose-signposting.R`, new/rewritten blocks
covering all four cases above (snapshot + fit or plain-refusal assertion
per case).

## R2 — "combine the covariates" bullets named formulas the parser refuses

`p4.R` confirmed only `phylo_latent(1 + x1 + x2 | species, d = K, tree =
tree)` (`R/fit-multi.R:2117`, untouched) parses; the other four
(`R/fit-multi.R:1619` `latent`, `:1626` `unique`, `:1766` `spatial_indep`,
`:1850` `spatial_latent`) do not. Each of those four now reads *"There is
no supported multi-covariate route here (only a single slope covariate is
supported); fit separate models."* — no longer names a formula.
`phylo_latent(1 + x1 + x2 | species, d = 1, tree = tree)` independently
verified to both parse AND **fit** (`conv = 0`), so its bullet stays as-is.

Tests: two new blocks in `test-gapclose-signposting.R` — the ordinary-latent
"only one X at unit tier" guard fires and says "no supported multi-covariate
route", not "combine the covariates"; `phylo_latent(1+x1+x2|species,...)`
fits.

## R3 — literal unbound `tau`

`R/diagnose.R:739,1338`: `gllvmTMBcontrol(loading_ridge = tau)` ->
`object 'tau' not found` when copy-pasted. Now reads `gllvmTMBcontrol(
loading_ridge = 0.25) (0.25 to 0.5; larger tau shrinks less)` — the
pre-run's own measured arm (`ridge_tau0.25`: converged, max_loading 1.128
down from ~10.9 unpenalised; the arm that cleared
`binomial_prevalence_loading`). `gllvmTMBcontrol(loading_ridge = 0.25)`
verified to run without error and return `$loading_ridge == 0.25`.

## R4 — VA offered with no stated precondition

Same two strings: `integration = "va"` is now qualified in one clause —
*"for latent(..., unique = FALSE) fits with at least 100 units and d <=
2"* — matching the VA fence's actual gates
(`R/integration-fence.R:96-99,128-140`, confirmed by `p6.R`: default
`latent()` refuses, `n = 40` refuses, `d = 3` refuses).

**Final sentence** (both `R/diagnose.R:739` and `:1338`, action text after
"...which lowering the rank does not resolve;"):

> try gllvmTMBcontrol(loading_ridge = 0.25) (0.25 to 0.5; larger tau
> shrinks less) to shrink runaway loadings, or gllvmTMBcontrol(integration
> = 'va') for latent(..., unique = FALSE) fits with at least 100 units and
> d <= 2 -- either makes the result a penalised (MAP) or variational
> estimate, so logLik(), AIC() and BIC() no longer apply to it

Tests: two new blocks in `test-gapclose-signposting.R` scanning
`R/diagnose.R`'s source text for the runnable literal and the VA clause,
plus a direct `gllvmTMBcontrol(loading_ridge = 0.25)` no-error check.

## R7 — five `animal_*` roxygen examples abort under the staged `unit` default

Source: `R/animal-keyword.R` (not `R/brms-sugar.R` as the review's grep
context implied — the animal keyword family lives in its own file).
`animal_scalar()`, `animal_unique()`, `animal_indep()`, `animal_latent()`,
`animal_dep()` each build a `df` with a `species`/`trait`/`value` long
format and NO `site` column; their `\dontrun{}` example called `gllvmTMB()`
with neither `unit=` nor a `site` column, so it now aborts (hidden from
`R CMD check` by `\dontrun{}`). Added `unit = "species"` (the actual
sampling-unit column in each example's `df`) to all five. Verified each
example, run verbatim, now **fits** (`conv = 0`).

**Regression found and fixed while verifying R7**: `animal_scalar()`'s own
example initially still refused — under the #1196 B2/task(b) collision
guard, `animal_scalar(species, pedigree = ped)` desugars to
`propto(0 + species | trait, Ainv)`, a covstruct whose `$group` is a
SYNTHETIC literal `trait` symbol (an engine marker from the `common =
TRUE` scalar-collapse rewrite), not a user-chosen column — the same defect
class as the earlier `phylo_rr` false positive this slice already fixed,
but reachable through `propto` too. Fixed by excluding any covstruct whose
group symbol is literally named `trait`/the trait column, by name, in
addition to the existing kind restriction (`R/gllvmTMB.R`, the #1196
collision-guard block). All five animal_* examples now fit, `conv = 0`
across the board; new regression test added.

Scanned all `man/*.Rd` examples for a fit call with neither `unit=` nor a
`site` column: 8 hits total, matching the review's count. The other 3
(`confirmatory_lambda.Rd`, `impute_model.Rd`, `miss_control.Rd`) are FALSE
POSITIVES on inspection — they contain no actual `gllvmTMB(...)` example
call, only `\code{gllvmTMB()}` prose cross-references outside
`\examples{}` (my grep's `.*` incidentally spans past the `\examples{}`
block without a DOTALL-safe anchor on the closing brace). None fits a
model, so none needed fixing, per the brief ("fix the ones that fit a
model").

`devtools::document()` run ONCE at the end of this pass (after all edits,
including R8): rewrote `man/animal_scalar.Rd`, `man/animal_unique.Rd`,
`man/animal_indep.Rd`, `man/animal_latent.Rd`, `man/animal_dep.Rd`,
`man/profile_ci_total_variance.Rd`. No `NAMESPACE` change. Pre-existing,
unrelated roxygen warnings (`AIC.gllvmTMB_multi`/`BIC.../anova...` in
`R/aghq-report.R`, a file this slice never touches) were not introduced by
this session.

## R8 — register code on a reader-facing surface

`R/profile-derived.R:957`: `2026-08-25 PVT-02 `n_units = 400`, `d = 2`
campaign...` -> `2026-08-25 `n_units = 400`, `d = 2` campaign...` (register
code removed, date + campaign description kept). Reaches
`man/profile_ci_total_variance.Rd` via the `devtools::document()` run
above; confirmed clean (`grep -n PVT-02` -> no hits).

## S1 — ratchet's bareness rule counted "i"-only as fixed

`dev/gapclose/count-bare-aborts.R`: `bullet_names` narrowed from
`c("i","x","*",">")` to `c("*",">")` — an information-only ("i") or
what-went-wrong-only ("x") bullet no longer counts as "has a next step".
This is strictly stricter, so the honest count went **UP**, not down:
**658 -> 1004** (re-scanning `R/` under the corrected rule, before any new
fixes in this pass). R1's five targeted fixes below then brought it from
1004 to **999**. The slice's own `unit = ...` abort
(`R/gllvmTMB.R:947-950`, the exact instance the review named) had its
`"i"` bullet retagged `">"` — it is now genuinely actionable, not merely
recounted differently.

`tests/testthat/test-gapclose-next-steps.R`'s ratchet updated to
`expect_lte(length(hits), 999L)`, comment states the honest trajectory
(658 undercounted by rule -> 1004 honest -> 999 after R1's fixes) rather
than hiding it.

## R1 — remaining bare aborts in the seven named files, honestly counted

Did **not** attempt to fix all remaining bare aborts (184 under the
corrected S1 rule, not 98 — the review's 98 used the pre-S1, looser rule).
Fixed exactly the three plainly user-reachable messages the reviewer
listed by exact text, all in `R/fit-multi.R` (5 call sites total, since
"Sparse `phylo_vcv`/`Ainv` must have rownames..." appears three times):
- `"Mixed-family {.arg family} list names must be unique."` (:218) ->
  names the fix (rename the duplicate `family = list(...)` entries).
- `"Sparse {.arg phylo_vcv}/{.arg Ainv} must have rownames matching levels
  of {.var species}."` (:604, :649, and the `{.var {species}}` dynamic
  variant at :4384) -> names the fix (`rownames(Ainv) <- levels(...)`).
- `"The {.arg tree} supplied to {.fn phylo_slope} must be an {.cls
  ape::phylo} tree."` (:693) -> names how to build one
  (`ape::read.tree`/`ape::read.nexus`) plus a worked call.

**Remaining bare-abort count per file, under the corrected (S1) rule, after
these fixes** (re-derived with `count_bare_aborts()` scoped to just the
seven named files):

| File | Remaining bare |
|---|---|
| `R/fit-multi.R` | 125 |
| `R/methods-gllvmTMB.R` | 22 |
| `R/gllvmTMB.R` | 18 |
| `R/suggest-lambda-constraint.R` | 12 |
| `R/isdm-sources.R` | 4 |
| `R/parse-multi-formula.R` | 3 |
| **Total (7 named files)** | **184** |

This is the honest number for restating gate G-A2: the slice's original
"every abort in the inventory carries a next-step bullet" claim does not
hold, and does not hold for the 7 named files specifically either — 184
remain, not 0, and not 98 (the pre-correction count). `fit-multi.R` alone
carries 125 of the 184; that file was never fully swept, only the ~19
call sites explicitly named across tasks (e), R1, and R2's corrections.

## Commands and output

```
$ Rscript -e 'parse("R/brms-sugar.R")' # and every other touched R/ file
OK (all)
$ NOT_CRAN=true Rscript -e 'testthat::test_file("tests/testthat/test-gapclose-signposting.R")'
[ FAIL 0 | WARN 0 | SKIP 0 | PASS 22 ]
$ NOT_CRAN=true Rscript -e 'testthat::test_file("tests/testthat/test-gapclose-next-steps.R")'
[ FAIL 0 | WARN 0 | SKIP 0 | PASS 7 ]
$ NOT_CRAN=true Rscript -e 'testthat::test_file("tests/testthat/test-no-deprecated-recommendations.R")'
[ FAIL 0 | WARN 0 | SKIP 0 | PASS 2 ]
$ NOT_CRAN=true Rscript -e 'testthat::test_file("tests/testthat/test-augmented-lhs-guard.R")'
[ FAIL 0 | WARN 0 | SKIP 0 | PASS 33 ]
$ NOT_CRAN=true Rscript -e 'testthat::test_file("tests/testthat/test-1188-trait-col-augmented-lhs-guard.R")'
[ FAIL 0 | WARN 0 | SKIP 0 | PASS 8 ]
$ NOT_CRAN=true Rscript -e 'testthat::test_file("tests/testthat/test-isdm-source-formula.R")'
[ FAIL 0 | WARN 0 | SKIP 0 | PASS 27 ]
$ NOT_CRAN=true Rscript -e 'testthat::test_file("tests/testthat/test-gllvmTMBcontrol.R")'
[ FAIL 0 | WARN 0 | SKIP 0 | PASS 36 ]
$ NOT_CRAN=true Rscript -e 'testthat::test_file("tests/testthat/test-family-cdf-args-1080.R")'
[ FAIL 0 | WARN 0 | SKIP 0 | PASS 40 ]
$ NOT_CRAN=true Rscript -e 'testthat::test_file("tests/testthat/test-animal-keyword.R")'
[ FAIL 0 | WARN 0 | SKIP 2 | PASS 21 ]   # 2 pre-existing, unrelated skips
$ Rscript dev/gapclose/count-bare-aborts.R
999 bare aborts found.
$ devtools::document(quiet = TRUE)
Writing 'animal_scalar.Rd', 'animal_unique.Rd', 'animal_indep.Rd',
        'animal_latent.Rd', 'animal_dep.Rd', 'profile_ci_total_variance.Rd'
```

## Files touched this pass

```
R/animal-keyword.R                            (R7: unit = "species" x5)
R/brms-sugar.R                                (B2: redirect rewrite)
R/diagnose.R                                  (R3/R4: runnable literal + VA clause)
R/fit-multi.R                                 (R2: 4 bullets; R1: 5 call sites)
R/gllvmTMB.R                                  (S1: "i"->">" ; R7 regression: propto/trait-literal group exclusion)
R/profile-derived.R                           (R8: PVT-02 removed)
dev/gapclose/count-bare-aborts.R              (S1: stricter bullet rule)
man/animal_dep.Rd, animal_indep.Rd,
    animal_latent.Rd, animal_scalar.Rd,
    animal_unique.Rd                          (R7: devtools::document())
man/profile_ci_total_variance.Rd              (R8: devtools::document())
tests/testthat/_snaps/gapclose-signposting.md (regenerated)
tests/testthat/test-gapclose-next-steps.R     (S1: ratchet number + comment)
tests/testthat/test-gapclose-signposting.R    (B2/R2/R3/R4/R7 regression: new/rewritten tests)
```

Not touched (per instruction): `README.md`, `NEWS.md`, `DESCRIPTION`,
`R/zzz.R`, `vignettes/`.

Not committed (per brief).

---

# Full-suite follow-up (aa704f8ed: FAIL 9 / PASS 26898, 2 attributed here)

## Fix 1 — `test-gllvmTMB-args.R:24`: data.frame check ran after the `unit` requirement

`expect_error(gllvmTMB(value ~ 0 + trait, data = 1:10), <data.frame message>)`
was instead getting `"unit = ...` is required."`. Root cause: the #1196
`unit`-required block (`R/gllvmTMB.R`, ~line 908) tests `"site" %in%
names(data)`, which on a non-data-frame `data` (e.g. `1:10`) silently
evaluates `FALSE` rather than erroring — so the unrelated "unit is
required" abort fired first, masking the real "not a data.frame"
complaint, because `assertthat::assert_that(is.data.frame(data))` ran much
later, inside the "Validate input" section.

**Fix**: moved `assertthat::assert_that(is.data.frame(data))` to run
immediately before the `site =`/`unit =` alias-handling block (i.e.
before ANY code inspects `data` via `names(data)`), and removed it from
its later position in "Validate input" (no duplicate check; message text
unchanged — assertthat's own default `"data is not a data frame"`).
Nothing else in the function's ordering changed: the trait-column check
and the explicit-`unit=`-column-not-found check both stay exactly where
they were.

## Fix 2 — `test-null-tier-defaults.R:137`: stale #1191-era message expectation

`"a missing `unit` column aborts naming the `unit` argument"` renames the
`site` column to `loc` and calls `gllvmTMB(value ~ 0 + trait, data = dat)`
with no `unit=`. Under the OLD default (`unit = "site"`), that produced
the #1191 message `` `unit = "site"` is not a column in `data` ``. Under
this slice's staged rollout, `unit` defaults to `NULL`, and `dat` has no
`"site"` column to fall back to, so the CORRECT and INTENDED behaviour is
the new `` `unit = ...` is required. `` abort (`R/gllvmTMB.R`) — this is
exactly the design decided in task (f): omitting `unit` with no `site`
column present should abort naming the argument, not silently guess.

**Fix**: updated the test's `regexp` from
`"unit.*=.*\"site\".*is not a column"` to match the new message
(`` "unit = \.\.\.`? is required" ``, accounting for cli's backtick
around the code span). The test's structure, fixture, and all other
assertions in the file are unchanged — this is a pure expectation update
reflecting the intended new behaviour, not a behaviour change.

## Commands and output

```
$ NOT_CRAN=true Rscript -e 'testthat::test_file("tests/testthat/test-gllvmTMB-args.R")'
[ FAIL 0 | WARN 1 | SKIP 4 | PASS 28 ]
$ NOT_CRAN=true Rscript -e 'testthat::test_file("tests/testthat/test-null-tier-defaults.R")'
[ FAIL 0 | WARN 0 | SKIP 0 | PASS 17 ]
$ NOT_CRAN=true Rscript -e 'testthat::test_file("tests/testthat/test-gapclose-next-steps.R")'
[ FAIL 0 | WARN 0 | SKIP 0 | PASS 7 ]
$ NOT_CRAN=true Rscript -e 'testthat::test_file("tests/testthat/test-gapclose-signposting.R")'
[ FAIL 0 | WARN 0 | SKIP 0 | PASS 22 ]
```

The 1 WARN in `test-gllvmTMB-args.R` is the staged-unit deprecation
notice firing as an incidental side effect of an unrelated pre-existing
test (`data` has a `site` column, no `unit=` given) — not a failure; the
test's own `expect_error(regexp = "trait")` still passes.

## Files touched this pass

```
R/gllvmTMB.R                             (Fix 1: is.data.frame() reordered earlier)
tests/testthat/test-null-tier-defaults.R (Fix 2: regexp updated to the new message)
```

Not committed (per brief).

---

# R CMD check follow-up (tarball run, NOT_CRAN unset, tree as of ~09:47)

## Fix 1 (REGRESSION) — `suggest_lambda_constraint()`/`suggest_lambda_constraints()`/`ridge_path()` lost their grouping under `unit = NULL`

**Root cause**: `suggest_lambda_constraint()`'s formula branch computed
`target_group <- if (level == "B") unit else "site_species"` and matched
covstructs against it; with the new `unit = NULL` default and no
resolution step, `target_group` was `NULL`, so `groups == target_group`
never matched and every call aborted "Formula has no `latent(... | ,
...)` term". `ridge_path()` had the SAME underlying defect one level
removed: it passes `unit` straight through to its own per-grid-point
`gllvmTMB()` calls, which each hit the `unit`-required abort and had it
silently swallowed by `ridge_path()`'s own `tryCatch`, returning an
all-`NA` table with the real cause buried in an unread `$fit_error`
column (confirmed empirically before the fix: `ridge_path()` on data
whose sampling-unit column is not literally `"site"` returned six `NA`
rows with `fit_error = "unit = ... is required."` on every one, no
visible error at all).

**Fix**: refactored `gllvmTMB()`'s inline staged-rollout block into a
shared, exported-nowhere internal helper,
`.gllvmTMB_resolve_unit_staged(unit, data)` (`R/gllvmTMB.R`) — same
one-time deprecation warning (one shared `getOption()` key across all
call sites), same "unit is required" abort when no `site` column exists.
`gllvmTMB()` itself now calls it (behavior-preserving refactor, re-verified
against `test-gllvmTMB-args.R`/`test-null-tier-defaults.R`). Applied it in
two more places:
- `suggest_lambda_constraint()`'s formula branch (`R/suggest-lambda-constraint.R`):
  resolves `unit` via the helper ONLY when `level == "B"` (the only case
  that uses `unit` as `target_group`; `level == "unit_obs"`/`"W"` always
  targets the fixed `"site_species"` group and never touches `unit`, so
  it must not be forced to resolve/abort needlessly). `suggest_lambda_constraints()`
  (plural) delegates to the singular function per method and needed no
  separate fix.
- `ridge_path()` (`R/ridge-path.R`): resolves `unit` immediately after tau
  validation, before `.screen_prepare_formula_data()` and before any grid
  point is fit — turns N silently-identical buried `fit_error` rows into
  one clear, immediate abort (or, when `data` has a `site` column, silent
  correct resolution exactly as `gllvmTMB()` itself now does).

**Placement bug found and fixed while doing this**: my first attempt
inserted `.gllvmTMB_resolve_unit_staged()`'s definition in the middle of
`gllvmTMB()`'s own `@examples` `\dontrun{}` block (a bad string-match
target), which silently mis-attached that roxygen block's `@export` tag
to the new internal helper and produced a mismatched-brace `\dontrun{}` —
`devtools::document()` wrote `NAMESPACE` with a stray
`export(.gllvmTMB_resolve_unit_staged)` and a new
`man/dot-gllvmTMB_resolve_unit_staged.Rd`. Caught immediately by running
`devtools::document()` and reading its output rather than assuming
success; relocated the helper to a verified-safe non-roxygen-adjacent
spot (between `gllvmTMBcontrol()`'s closing brace and the existing
`.gllvmTMB_normalize_aghq()` internal helper, mirroring that file's own
established pattern for internal helpers). Re-ran `devtools::document()`
twice to confirm: `NAMESPACE` and `man/gllvmTMB.Rd` now show **zero diff**
against their pre-session state (`git status --porcelain` clean on both),
and the stray `.Rd` page is gone.

Verified via `tests/testthat/test-suggest-lambda-constraint.R` (all 7
originally-failing tests, plus the other 33 in that file) and manual
checks of the `ridge_path()` silent-failure case (now a clear immediate
abort) and the working case (a `site` column resolves silently, `fit_error`
all `NA`).

## Fix 2 — `test-runaway-warning.R:58` expected `"aghq_ridge"`, message now says `loading_ridge` by design

One-line expectation update: `expect_match(w, "aghq_ridge")` ->
`expect_match(w, "loading_ridge")`. This is the R3 message change from
the earlier adversarial-review pass, working as intended; nothing else in
that test changed.

## Fix 3 — `deviance.gllvmTMB_multi`: no visible global function definition for `'logLik'`

`R/methods-gllvmTMB.R`: `-2 * as.numeric(logLik(object, ...))` ->
`-2 * as.numeric(stats::logLik(object, ...))`. One-token fix; confirmed
no other bare (non-`stats::`) `logLik(` call sits inside that method, and
`devtools::document()` reports no new roxygen/NAMESPACE issue from this
change (no `@importFrom` needed since the call is now fully qualified).

## Fix 4 — new gapclose tests read repo files by relative path, erroring under `R CMD check`'s installed-tarball execution

Added `tests/testthat/helper-gapclose-repo-root.R` (auto-sourced by
testthat, shared by every `test-gapclose-*.R` file): `.gapclose_repo_root()`
walks up from `testthat::test_path()` looking for a directory that has
BOTH `DESCRIPTION` and `dev/gapclose/`, returning `NULL` (never erroring)
when neither is found (i.e. running from an installed copy, where
`dev/gapclose/` and the raw `.R` sources are not shipped).

- `test-gapclose-next-steps.R:8`: the top-level `source(testthat::test_path(
  "..", "..", "dev", "gapclose", "count-bare-aborts.R"))` (which ran at
  file-parse time, before any `test_that()`, so it could not be wrapped in
  `skip()`) moved INSIDE the one `test_that()` block that uses it; that
  block now resolves the repo root first, `testthat::skip_if(is.null(root),
  ...)`, and only then `source()`s the file (`local = TRUE`, so
  `count_bare_aborts()` is available for the very next line) and reads
  `file.path(root, "R")`. Assertions unchanged.
- `test-gapclose-signposting.R:259,270` (the two `readLines(testthat::
  test_path("..", "..", "R", "diagnose.R"))` calls, inside two
  `test_that()` blocks already): each now resolves the repo root first and
  skips if not found, then reads `file.path(root, "R", "diagnose.R")`.
  Assertions unchanged.

## Commands and output

```
$ NOT_CRAN=true Rscript -e 'testthat::test_file("tests/testthat/test-suggest-lambda-constraint.R")'
[ FAIL 0 | WARN 1 | SKIP 0 | PASS 40 ]
$ NOT_CRAN=true Rscript -e 'testthat::test_file("tests/testthat/test-runaway-warning.R")'
[ FAIL 0 | WARN 0 | SKIP 0 | PASS 17 ]
$ NOT_CRAN=true Rscript -e 'testthat::test_file("tests/testthat/test-gapclose-next-steps.R")'
[ FAIL 0 | WARN 0 | SKIP 0 | PASS 7 ]
$ NOT_CRAN=true Rscript -e 'testthat::test_file("tests/testthat/test-gapclose-signposting.R")'
[ FAIL 0 | WARN 0 | SKIP 0 | PASS 22 ]
$ NOT_CRAN=true Rscript -e 'testthat::test_file("tests/testthat/test-gllvmTMB-args.R")'
[ FAIL 0 | WARN 0 | SKIP 4 | PASS 28 ]
$ NOT_CRAN=true Rscript -e 'testthat::test_file("tests/testthat/test-null-tier-defaults.R")'
[ FAIL 0 | WARN 0 | SKIP 0 | PASS 17 ]
$ Rscript -e 'devtools::document(quiet = TRUE)'
Writing 'gllvmTMB.Rd'   # content unchanged vs pre-session (git diff empty)
(3 pre-existing, unrelated aghq-report.R @exportS3Method warnings only)
$ git status --porcelain NAMESPACE man/gllvmTMB.Rd
(clean -- no output)
```

The 1 WARN in `test-suggest-lambda-constraint.R` is the shared staged-unit
deprecation notice firing once (that test's fixtures have a `site` column
and omit `unit=`), consistent with the earlier `test-gllvmTMB-args.R`
run's WARN 1 for the same reason. It fired only once across this whole
run's process (once-per-session), which is why `test-gllvmTMB-args.R`
shows `WARN 0` here despite showing `WARN 1` in the previous, separate
round — the option was already set by an earlier file in this same
process, not a regression.

## Files touched this pass

```
R/gllvmTMB.R                               (Fix 1: .gllvmTMB_resolve_unit_staged() extracted + relocated)
R/methods-gllvmTMB.R                       (Fix 3: stats::logLik())
R/ridge-path.R                             (Fix 1: resolve unit before the grid loop)
R/suggest-lambda-constraint.R              (Fix 1: resolve unit when level == "B")
tests/testthat/helper-gapclose-repo-root.R (Fix 4: new shared helper)
tests/testthat/test-gapclose-next-steps.R  (Fix 4: source() moved inside test_that + skip)
tests/testthat/test-gapclose-signposting.R (Fix 4: readLines() calls skip when repo files absent)
tests/testthat/test-runaway-warning.R      (Fix 2: aghq_ridge -> loading_ridge)
```

Not committed (per brief).
