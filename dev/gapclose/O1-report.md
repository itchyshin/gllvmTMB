# O1 report — user-reachable bare-abort next steps (issue #1247)

Branch: `claude/overnight-aborts-1` (worktree `~/local-scratch/lanes/gllvmTMB-aborts-1`,
based on `origin/main` @ `5855e2ad9`).

## Starting / ending count

- Starting count: **999** (confirmed: `Rscript dev/gapclose/count-bare-aborts.R` → `999 bare aborts found.`)
- Ending count: **828**
- Total fixed: **171**
- Ratchet in `tests/testthat/test-gapclose-next-steps.R` lowered `999L -> 828L`, comment updated
  with the 2026-09-03 O1 note.

## Per-file counts: fixed / skipped

| File | Bare aborts (start) | Fixed | Skipped | Skip reason |
|---|---|---|---|---|
| `R/crs.R` | 6 | 6 | 0 | — |
| `R/parse-multi-formula.R` | 3 | 3 | 0 | — |
| `R/families.R` | 10 | 10 | 0 | — |
| `R/mesh.R` | 27 | 27 | 0 | — |
| `R/gllvmTMB.R` | 18 | 18 | 0 | — |
| `R/brms-sugar.R` | 5 | 5 | 0 | — |
| `R/fit-multi.R` | 125 | 102 | 23 | see below |
| **Total** | **194** | **171** | **23** | |

### `R/fit-multi.R` skip breakdown (23 unfixed)

**Truly internal plumbing, not user-triggerable (8 — left as-is, no message change):**
- 7 messages prefixed `"Internal error: ..."` — `.arg lv` unit-level design missing levels,
  the binary/ordered/unordered `mi()` predictor data-column checks (x3), `is_y_observed` length
  mismatch, the `mi` predictor fixed-effect column check, and the `phylo` covariate
  species→node map. Each guards an invariant the package itself is responsible for
  maintaining after its own parsing/expansion steps; none names a formula shape or argument a
  user could have written differently. The counter's own convention (and the existing ratchet
  test's docstring) treats these as out of scope.
- 1 message `"The internal iSDM marker has an invalid observation contract. The developer
  marker admit..."` — guards a package-internal token (`gllvmTMB_internal_isdm`) set only by
  the package's own iSDM constructors, never by user-supplied arguments.

**User-reachable but left unfixed this slice, for scope/budget or accuracy reasons (15):**
- 7 × `{.arg K}`/`{.arg d}` checks inside the `kernel_latent()` multi-tier block (square/finite/
  symmetric/PD/row-names/positive-semidefinite/positive-integer-d). Genuinely reachable via
  `kernel_latent(name=, d=, K=)`, structurally identical to the `kernel_slope()` checks already
  fixed in this slice — deferred only because the fix count target (~150) was already exceeded
  before reaching this block; a natural next slice.
- 7 × the `n_init` restart / `start=` coefficient-start block (`"All {control$n_init} restarts
  failed."`, `control$aghq_start_par` mismatch, "No successful restart has a finite objective",
  and four `Physical coefficient starts...`/`Coefficient covariance starts...` checks under a
  structured `start = list(...)` argument). Reachable via `gllvmTMBcontrol(n_init=, start=)`, but
  writing a *true* next-step bullet needs a clear read of the optimizer-restart contract and the
  structured-start Cholesky-parameterisation this package uses; misnaming that route would
  violate the "must be true" rule, so left for a slice with time to verify by fitting.
- 1 × `"This structured {.arg rho} configuration does not resolve to one trait-intercept
  covariance block."` — fires from a large disjunction of six structured-rho competing-feature
  flags (`use_phylo_rr`, `use_phylo_slope`, `use_rr_B_slope`, `use_diag_B_slope`, `use_mi_phylo`,
  `use_kernel_multi`, `use_propto`). No single accurate one-line fix exists across all of those
  combinations without checking each in turn; left rather than risk naming a route that itself
  refuses for some triggering combination.

## The ten routes proven by fitting or calling (not just reading code)

1. **`slope(x | trait)`** — `gllvmTMB(value ~ 0 + trait + slope(x | trait), data = d, family =
   gaussian(), unit = "site")` returned class `gllvmTMB_multi` (verified after switching family
   from `poisson()`, which the route explicitly does not support, to `gaussian()`).
2. **`latent(1 + x | site, d = K)`** — `gllvmTMB(value ~ 0 + trait + latent(1 + x | site, d = 2),
   data = d, family = poisson(), unit = "site")` returned class `gllvmTMB_multi` (with the
   expected `unique = FALSE` loadings-only warning for a non-Gaussian family).
3. **`delta_gamma(link1 = "logit", link2 = "log", type = "poisson-link")`** — constructor call
   returned class `family`.
4. **`delta_lognormal(link1 = "logit", link2 = "log", type = "poisson-link")`** — constructor
   call returned class `family`.
5. **`poisson(link = "log")`** — a full `gllvmTMB()` fit with this family/link (2 traits x 20
   sites) returned class `gllvmTMB_multi`; the same data with `poisson(link = "identity")`
   reproduced the abort this arc's bullet now names.
6. **`column_coef(0 + x | trait)`** — ran the function's own roxygen `@examples` fit verbatim;
   returned class `gllvmTMB_multi`.
7. **`gllvmTMBcontrol(aghq = 9)`** — accepted without error (normalises to integer `9L`),
   confirming the named alternative to a bad `aghq` value is real, working syntax.
8. **`betabinomial(link = "cloglog")`** — constructor call returned class `family`.
9. **`ordinal_probit()`** (default `link = "probit"`) — constructor call returned class
   `ordinal_probit`/`family`.
10. **`.gllvm_normalize_mesh()` / `make_mesh()` reachability** — grep-confirmed
    `.gllvm_normalize_mesh()` (which the mesh-validation bullets point back to) is called from
    `R/fit-multi.R:4775` and `:4780`, i.e. genuinely reached from `gllvmTMB(mesh = ...)`; and
    `make_mesh()` itself carries a working roxygen `@examples` block
    (`make_mesh(df, c("X","Y"), cutoff = 0.1)`), the exact syntax the new mesh-validation
    bullets recommend.

Two additional branching-logic routes were verified with three live calls each (not just one
value), because the fix itself required deriving which of three different answers is correct
per case (mirroring the pre-existing #1196 fix for a sibling error site):
- `parse_re_int_call()`'s new three-way bullet (`slope()`/`phylo_slope()`/`animal_slope()` when
  grouped by `trait`; `latent(1 + x | group, d = K)`/`unique(1 + x | group)` when grouped by an
  ordinary column with a single intercept+slope LHS; "no supported route" for a bare slope-only
  term) — verified all three branches fire the right message AND that the `trait`-branch
  (`slope(x | trait)`, item 1 above) and the ordinary-column branch (`latent(1 + x | site, d =
  2)`, item 2 above) both fit successfully.

## Test files whose snapshots were touched / updated

- **New**: `tests/testthat/test-gapclose-next-steps-batch1.R` — 16 `expect_snapshot(error =
  TRUE)` tests spanning all seven touched files (2 crs.R, 2 parse-multi-formula.R, 2 families.R,
  2 mesh.R, 3 gllvmTMB.R, 1 brms-sugar.R, 4 fit-multi.R).
- **New**: `tests/testthat/_snaps/gapclose-next-steps-batch1.md` — auto-generated snapshot file
  for the above (no prior snapshot existed; `testthat::snapshot_accept()` confirmed nothing
  further to accept once generated).
- **Updated**: `tests/testthat/test-gapclose-next-steps.R` — ratchet `999L -> 828L`, comment
  extended with the O1 note.
- **No other snapshot files needed updating.** Systematic `grep -rl` sweeps of
  `tests/testthat/_snaps/*.md` and `tests/testthat/` for distinctive substrings from every
  rewritten message (primary text and any converted `"i"`-bullet text) found zero hits outside
  the two `gapclose-next-steps*.md` files above. Three unrelated test files reference message
  *substrings* I did not change (`test-matrix-nbinom1.R`, `test-spatial-latent-slope-gaussian.R`
  via `expect_error(regexp = ...)`, and `test-multi-trial-binomial.R`/`test-isdm-public-door.R`/
  `test-julia-bridge.R` in comments only) — none use `expect_snapshot()` on the primary message
  line, and none of my edits changed that primary line, only added or converted bullets after
  it, so these are unaffected (re-ran `test-matrix-nbinom1.R` to confirm: 0 fail).

## Commands run, with exact output

```
$ git -C "/Users/z3437171/Dropbox/Github Local/gllvmTMB" worktree add -b claude/overnight-aborts-1 ~/local-scratch/lanes/gllvmTMB-aborts-1 origin/main
...
HEAD is now at 5855e2ad9 Merge PR #1240: zero-inflated families zi_poisson(), zi_nbinom2(), zi_binomial() (ARC D1; maintainer-approved D-207)

$ Rscript -e 'pkgbuild::compile_dll(quiet = TRUE)'
(no output; compiled clean)

$ Rscript dev/gapclose/count-bare-aborts.R    # BEFORE any edits
999 bare aborts found.
[... 999 file:message lines ...]

$ Rscript dev/gapclose/count-bare-aborts.R    # AFTER crs.R
993 bare aborts found.

$ Rscript dev/gapclose/count-bare-aborts.R    # AFTER parse-multi-formula.R
990 bare aborts found.

$ Rscript dev/gapclose/count-bare-aborts.R    # AFTER families.R
980 bare aborts found.

$ Rscript dev/gapclose/count-bare-aborts.R    # AFTER mesh.R
953 bare aborts found.

$ Rscript dev/gapclose/count-bare-aborts.R    # AFTER gllvmTMB.R
935 bare aborts found.

$ Rscript dev/gapclose/count-bare-aborts.R    # AFTER brms-sugar.R
930 bare aborts found.

$ Rscript dev/gapclose/count-bare-aborts.R    # AFTER fit-multi.R batch 1 (family/link + phylo-precision)
894 bare aborts found.

$ Rscript dev/gapclose/count-bare-aborts.R    # AFTER fit-multi.R batch 2 (column-coef/kernel-slope)
885 bare aborts found.

$ Rscript dev/gapclose/count-bare-aborts.R    # AFTER fit-multi.R batch 3 (rank/covstruct/grouping)
872 bare aborts found.

$ Rscript dev/gapclose/count-bare-aborts.R    # AFTER fit-multi.R batch 4 (response/weights/REML)
860 bare aborts found.

$ Rscript dev/gapclose/count-bare-aborts.R    # AFTER fit-multi.R batch 5 (family row-range + ordinal_probit)
850 bare aborts found.

$ Rscript dev/gapclose/count-bare-aborts.R    # AFTER fit-multi.R batch 6 (spatial/mesh)
843 bare aborts found.

$ Rscript dev/gapclose/count-bare-aborts.R    # AFTER fit-multi.R batch 7 (equalto/references-column/student)
835 bare aborts found.

$ Rscript dev/gapclose/count-bare-aborts.R    # AFTER fit-multi.R batch 8 (phylo-source/mixed-family-length) -- FINAL
828 bare aborts found.

$ Rscript -e 'tryCatch({parse("R/fit-multi.R"); cat("OK\n")}, error=function(e) cat("ERR:", conditionMessage(e), "\n"))'
OK    # ran after every fit-multi.R batch; always OK

$ Rscript -e 'devtools::test(filter = "gapclose")'    # after adding the new snapshots, first run
... 16 "Adding new snapshot" WARNINGs (expected: no prior snapshot for the new file) ...
[ FAIL 0 | WARN 16 | SKIP 0 | PASS 77 ]

$ Rscript -e 'devtools::test(filter = "gapclose")'    # second run, after snapshots written
[ FAIL 0 | WARN 0 | SKIP 0 | PASS 77 ]

$ Rscript -e 'devtools::test(filter = "matrix-nbinom1")'
[ FAIL 0 | WARN 0 | SKIP 3 | PASS 0 ]   # 3 heavy tests skipped by design (GLLVMTMB_HEAVY_TESTS), 0 fail

$ Rscript dev/gapclose/count-bare-aborts.R | head -1    # FINAL confirmation
828 bare aborts found.
```

## Live-fit / call verification transcript (the ten proven routes + branching logic)

```r
# 1-2: slope() and latent() random-slope routes
gllvmTMB(value ~ 0 + trait + slope(x | trait), data = d, family = gaussian(), unit = "site")
#> class: gllvmTMB_multi
gllvmTMB(value ~ 0 + trait + latent(1 + x | site, d = 2), data = d, family = poisson(), unit = "site")
#> class: gllvmTMB_multi (with expected non-Gaussian loadings-only warning)

# 3-4: delta_gamma / delta_lognormal poisson-link constructors
delta_gamma(link1 = "logit", link2 = "log", type = "poisson-link")       #> class: family
delta_lognormal(link1 = "logit", link2 = "log", type = "poisson-link")   #> class: family

# 5: poisson(link = "log") vs poisson(link = "identity")
gllvmTMB(value ~ 0 + trait, data = d, family = poisson(link = "identity"), unit = "site")
#> Error: poisson: only the log link is currently supported.
#>        > Use `poisson(link = "log")` (the default).
gllvmTMB(value ~ 0 + trait, data = d, family = poisson(link = "log"), unit = "site")
#> class: gllvmTMB_multi

# 6: column_coef() roxygen example, run verbatim
gllvmTMB(value ~ 1 + column_coef(0 + x | trait), data = dat, trait = "trait", unit = "unit",
         family = gaussian(), control = gllvmTMBcontrol(se = FALSE), silent = TRUE)
#> class: gllvmTMB_multi

# 7: gllvmTMBcontrol(aghq = 9) accepted
gllvmTMBcontrol(aghq = 9)   #> no error

# 8-9: betabinomial(cloglog) / ordinal_probit() default
betabinomial(link = "cloglog")   #> class: family
ordinal_probit()                 #> class: ordinal_probit / family

# 10: .gllvm_normalize_mesh() reachability
grep -n "\.gllvm_normalize_mesh" R/fit-multi.R
#> R/fit-multi.R:4775:    mesh <- .gllvm_normalize_mesh(mesh)
#> R/fit-multi.R:4780:    mesh <- .gllvm_normalize_mesh(mesh)

# Branching-logic verification for parse_re_int_call()'s new three-way bullet
parse_re_int_call(quote(x | trait))     #> "...slope(), phylo_slope(), animal_slope()..."
parse_re_int_call(quote(1 + x | site))  #> "...latent(1 + x | site, d = K) or unique(1 + x | site)..."
parse_re_int_call(quote(0 + x | site))  #> "...no supported route for a bare slope-only term..."
```

## Follow-up (out of this slice's scope)

- `R/fit-multi.R`'s `kernel_latent()` 7-item tier-validation block (square/finite/symmetric/PD/
  row-names/positive-semidefinite/positive-integer-d) is structurally identical to the
  `kernel_slope()` block fixed here; a natural next O-slice.
- The `n_init`/`start=` restart-failure block (7 items) needs the structured-start
  Cholesky-parameterisation read before any bullet can be trusted.
- The single `"structured {.arg rho} configuration does not resolve..."` message needs
  per-branch bullets, not one line, given its six-flag disjunction.
