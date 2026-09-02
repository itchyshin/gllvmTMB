# A1-A2 gap-close report — signposting refusals, `unit=` decision 3

Worktree: `/Users/z3437171/local-scratch/lanes/gllvmTMB-gapclose-20260902`
Branch: `claude/gapclose-20260902`. Not committed (per brief).

## Coordinator deviations recorded here

1. **Task (d)**: after A4's pre-run finished, the coordinator asked for the
   `loading_ridge`/`integration = "va"` plain-language bullet text (no
   numbers in the message) instead of a bare name-swap. Applied.
2. **Task (f), Decision 3**: an AST sweep found ~628 `gllvmTMB()`/
   `gllvmTMB::gllvmTMB()` call sites across ~178 test files omitting `unit=`
   and relying on the retired implicit `"site"` default -- far larger than
   the abort-inventory-notes.md table implied (that table only counted
   literal quoted `unit = "site"` text, not omitted-argument call sites).
   Flagged to the coordinator before acting; the coordinator's call was to
   **defer the hard abort to 0.8.0** rather than mechanically rewrite ~628
   test call sites owned by other live lanes (D-88 risk of cross-lane file
   bleed and guaranteed merge conflicts). Implemented as a **staged
   rollout**: `unit = NULL` is the default and required; when omitted and
   `data` has a literal `"site"` column, a one-time deprecation warning
   fires and `unit` resolves to `"site"` (byte-identical behaviour to
   today); when `data` has no `"site"` column, it aborts naming `unit=`.
   This is the ONE user-facing behaviour change this slice intentionally
   ships as "deprecated, not yet removed" rather than "removed", per the
   coordinator's explicit adaptive-deviation instruction, to be flagged to
   Shinichi as a deviation from "NULL with a clear abort" for 0.8.0.

## Per-task detail

### (a) `.assert_no_augmented_lhs` + `phylo_indep`'s own check

- `R/brms-sugar.R`: `.assert_no_augmented_lhs()` (def. ~2382-2444, called
  from the `latent`/`unique`/`indep`/`scalar`/`dep`/`spatial_dep`/
  `spatial_indep`/`spatial_latent`/`spatial_scalar` branches) now inspects
  the RHS of `|`: if it matches the trait column, the `">"` bullet names
  `slope()`/`phylo_slope()`/`animal_slope()` (response-column grammar); for
  any other grouping column it names `phylo_slope(x | <group>, tree = tree)`
  (group-axis grammar) plus `animal_slope()`.
- `phylo_indep`'s own final fallback abort (`R/brms-sugar.R`, the
  `"LHS richer than 0 + trait"` message) gets the identical RHS-conditioned
  treatment, using the already-resolved `species_arg`.
- New helper `.warn_spatial_grouping_token()` (see (c)) added in the same
  region, sharing the file's env-based one-shot tracker.
- Test file: `tests/testthat/test-gapclose-signposting.R` — 4
  `expect_snapshot(error = TRUE)` (both RHS branches x both call sites) +
  2 real fits proving the named route converges
  (`fit$opt$convergence == 0L`), using a 30-site / 4-trait / 6-species
  fixture with `ape::rcoal()` ultrametric trees (one over species, one over
  trait labels).
- **Regression caught and fixed while adding tests**: the first version of
  task (b)'s guard (below) false-positived on `phylo_latent(species, d=1)`
  because `phylo_rr`'s synthetic `$group` is always the literal symbol
  `trait` (a parser artifact from `parse_covstruct_call()`'s bare-species
  special case), not a real user column. `tests/testthat/
  test-augmented-lhs-guard.R` caught it (4 failures) before this report was
  written; fixed by excluding `phylo_rr` from the collision-check kinds.

### (b) #1196 identical grouping/trait-column guard

- `R/gllvmTMB.R` (~1221-1252, right after the unused-optional-slot warning):
  new check over `parsed$covstructs` scoped to kinds `rr`/`diag`/`propto`/
  `equalto` (i.e. `latent`/`indep`/`dep`/`unique`/`scalar` after desugar) —
  `phylo_rr` deliberately excluded (see regression note above); `phylo_slope`
  /`slope`/`kernel_slope`/`spatial_slope` already excluded by not being in
  the kind list. Aborts naming the fixed/random collision and the fix
  (response-column slope grammar or a different grouping column).
- Tests: in `test-gapclose-signposting.R` — 1 `expect_snapshot(error=TRUE)`
  + 1 fit proving a distinct grouping column still converges.

### (c) #1163 spatial grouping-token warning

- `R/brms-sugar.R`: new `.warn_spatial_grouping_token(fn, e)`, called once
  at the top of each of the four base spatial branches (`spatial_scalar`,
  `spatial_latent`, `spatial_indep`, `spatial_dep`). Warns (via the file's
  existing `.gllvmTMB_deprecation_seen` one-shot tracker, respecting
  `getOption("gllvmTMB.quiet_grammar_notes")`) whenever the RHS token isn't
  literally `coords`, explaining the field is always driven by `mesh =`/
  `coords =`.
- Test: `expect_warning()` (with `tests/testthat/setup.R`'s package-wide
  `gllvmTMB.quiet_grammar_notes = TRUE` locally overridden, matching the
  established pattern in `test-unique-family-deprecation.R`) + a logLik
  equality check between `| banana` and `| coords` spellings on a real
  spatial fit (`simulate_site_trait(spatial_range=, sigma2_spa=)` +
  `make_mesh()`).
- Verified inert package-wide: `tests/testthat/setup.R` sets
  `gllvmTMB.quiet_grammar_notes = TRUE` globally, and no existing test both
  overrides that AND uses a spatial keyword with a non-`coords` RHS, so this
  new warning changes no existing test's observable behaviour.

### (d) `loading_ridge` recommendation swap

- `R/diagnose.R` (~739, ~1338, the two `runaway_hit`/`.mn` action strings in
  `.gllvmTMB_check_row()`): now read (per the coordinator's plain-language
  spec, no numbers in the message itself) *"...try
  gllvmTMBcontrol(loading_ridge = tau) with a small tau to shrink runaway
  loadings, or gllvmTMBcontrol(integration = 'va') as a tuning-free
  alternative..."*.
- `R/gllvmTMB.R:~2121` needed no edit — it already recommends
  `loading_ridge` (was cited in the brief as precedent, not a defect).
- Test: extended `tests/testthat/test-no-deprecated-recommendations.R` with
  a new `test_that` scanning R/ string literals for `aghq_ridge\s*=\s*[0-9]`
  (a numeric-ridge recommendation using the old name); deliberately does
  NOT flag `aghq_ridge = "auto"`/`aghq_ridge = Inf` in `R/aghq-report.R`,
  `R/aghq-auto-ridge.R`, `R/gllvmTMB.R`, `R/methods-gllvmTMB.R` — those are
  AGHQ-specific ladder/likelihood-comparison meanings `loading_ridge` does
  not carry, out of this task's scope.
- `[ FAIL 0 | WARN 0 | SKIP 0 | PASS 2 ]`

### (e) Next-step bullets in the named files

Fixed every bare `cli::cli_abort()` call site pointed at by the brief:

- `R/gllvmTMB.R`: all 21 bare rows from the inventory's line list (the
  literal line numbers were stale against this session's edits, so each
  was re-located by grepping the live `cli::cli_abort(` calls and
  classifying by hand): REML/`se` type guards, both `multinomial()`
  single-column-LHS messages, the multinomial baseline/level/category-count
  messages, `start_method` type/value/jitter.sd guards (careful NOT to
  recommend the soft-deprecated `method = "res"` as if it were preferred —
  the `jitter.sd`/`start_method`-must-be-a-list messages name it only as
  "the soft-deprecated residual start").
- `R/parse-multi-formula.R:342` (now ~343): `(1 | group)` non-symbol RHS ->
  names `interaction()`/`paste()`.
- `R/family-cdf-args.R:60,65,71`: `trait_id` range guard now names
  `1..n_traits` (computed from the fit) for all three messages.
- `R/fit-multi.R`: all 7 named "only one X" ceiling-family lines (two at
  the unit-tier ordinary augmented random-regression check, one spatial
  augmented random-regression, one `spatial_latent` random-slope, one
  `phylo_latent` random-slope, two the final `phylo_rr_idx`/
  `phylo_diag_idx` uniqueness checks) now say to combine covariates into
  one term (with a worked example matching each keyword) or fit separate
  models.
- `R/suggest-lambda-constraint.R:191` (now ~194): names `trait = ...`.
- `R/isdm-sources.R`: both remaining bare rows (`family` type guard,
  duplicate source names) fixed with worked examples / a rename
  instruction.
- **"ALL 24 Internal: rows package-wide"**: interpreted as the union the
  original scout's 12-file inventory counted (fit-multi.R 16 + isdm-sources
  7 + methods-gllvmTMB.R 1 = 24). Fixed 22 of these (7 isdm-sources.R + 14
  fit-multi.R [12 single-line via a scripted regex pass + 2 multi-line
  found by hand] + 1 methods-gllvmTMB.R), each now says what to check
  (formula/data/tree-tip-labels/fit provenance, as applicable) and to file
  an issue at the repo's issues page with a reproducible example and
  `sessionInfo()`. NOT touched: 3 `stop()`-based (not `cli_abort()`) internal
  guards in `R/fit-multi.R` (`.augmented_slope_family_allowed`,
  `.spde_latent_slope_design` x2) — a different condition mechanism, outside
  the abort-inventory scout's `cli_abort`-only scan, and genuinely
  unreachable from user input (called only with already-validated internal
  data), so left as-is.
- Test file: `tests/testthat/test-gapclose-next-steps.R` — 6
  `expect_snapshot(error = TRUE)` (REML type, `gllvmTMBcontrol(se=)`,
  `(1 | a+b)`, `isdm_source()` bad family, `isdm_sources()` duplicate names,
  `multinomial()` multi-column response) + 1 ratchet test.
- **Ratchet**: `dev/gapclose/count-bare-aborts.R` re-derives the bare count
  with the stated rule (`cli_abort`/`cli::cli_abort` call whose literal
  message vector carries no `"i"/"x"/"*"/">"`-named element AND no
  `Use |Try |Pass |Set |Choose |Supply |Instead|see \?` match), scanned over
  the WHOLE of `R/` (not the original 12-file inventory scope — the brief
  says "over R/"). **Ratchet number: 658** (hard-coded in
  `test-gapclose-next-steps.R` with the comment "ratchet: may only go
  down"). This is far larger than the original "318 bare" figure because
  that figure was scoped to only the 12 files the abort-inventory scout
  enumerated; this ratchet is package-wide, as instructed.
- `[ FAIL 0 | WARN 0 | SKIP 0 | PASS 7 ]`

### (f) `unit` default — Decision 3, staged (see deviation note above)

- `R/gllvmTMB.R`: signature default `unit = "site"` -> `unit = NULL`
  (line ~625 originally, now ~626 after earlier edits). Roxygen `@param
  unit` rewritten to state it is required, with the one-release deprecated
  fallback and its 0.8.0 removal date. The dual-specification check
  (`site=` alias vs explicit `unit=`) updated from `!identical(unit,
  "site")` to `!is.null(unit)` (correct given the new default).
- New block (~925-945): if `unit` is NULL after alias resolution, and
  `data` has a literal `"site"` column, warn once (package's
  `getOption()`-cached one-shot pattern, matching `.normalise_level()`'s
  established precedent — NOT `cli::cli_warn(.frequency="once")`, whose
  internal throttle is not resettable from tests) and set `unit <-
  "site"`; otherwise abort naming `unit=` (mirrors the `unit_obs`/`cluster`
  NULL-handling wording style from PR #1191).
- `R/ridge-path.R`: default `unit = "site"` -> `unit = NULL` (~133); roxygen
  (~76) already said "no default... matching gllvmTMB()'s own required
  argument" (edited before the coordinator's deviation landed; still
  accurate since gllvmTMB()'s own contract is "required, with a one-release
  deprecated fallback"). Internal `unit = unit` pass-throughs at ~149/~169
  needed no change.
- `R/suggest-lambda-constraint.R`: both `unit = "site"` defaults (~103,
  ~550, for `suggest_lambda_constraint()` and `suggest_lambda_constraints()`)
  -> `unit = NULL`, passed straight through to the internal `gllvmTMB()`
  call, which performs the staged fallback/abort itself.
- **Two real internal package call sites** were found relying on the
  retired implicit default (via an AST sweep of every `gllvmTMB()`/
  `gllvmTMB::gllvmTMB()` call in `R/`, not the whole-package-breaking test
  scan) and fixed to pass `unit = "site"` explicitly, byte-identical
  behaviour: `R/data-mixed-family.R` (`fit_mixed_family_fixture()`,
  `#noRd` test helper) and `R/gllvmTMB-wide.R` (the deprecated
  `gllvmTMB_wide()` legacy wrapper, whose pivoted long data always names
  the column literally `"site"`).
- `devtools::document()` run: `man/gllvmTMB.Rd`, `man/ridge_path.Rd`,
  `man/suggest_lambda_constraint.Rd`, `man/suggest_lambda_constraints.Rd`
  updated. (Unrelated pre-existing roxygen warnings about
  `AIC.gllvmTMB_multi`/`BIC.gllvmTMB_multi`/`anova.gllvmTMB_multi` missing
  `@export`/`@exportS3Method` in `R/aghq-report.R` — a file this slice does
  not touch — were NOT introduced by this session.)
- Tests: covered by (b)'s and (a)'s existing fixtures (all use
  `unit = "site"` explicitly, so exercise the silent/no-warning path), plus
  the manual verification below (not committed as a test file — the
  coordinator's staged-rollout spec asked for 4 behaviours; three are
  cheap enough that a dedicated test file felt like overkill given the
  huge existing `unit = "site"` test surface already covering the "explicit
  silent" case thousands of times over):
  - `withr::local_options(gllvmTMB.warned_unit_implicit_site = NULL)`; fit
    without `unit=` on data with a `site` column -> ONE warning
    (`"Relying on the implicit..."`) + `latent()`'s own psi-default notice;
    second fit in the same session -> no warning; convergence 0 both times.
  - Fit without `unit=` on data with NO `site` column -> aborts
    `"`unit = ...` is required."`.
  - `ridge_path()` default (`NULL`) matches `gllvmTMB()`'s default (`NULL`)
    by inspection of both signatures.

### (g) NEWS

- `NEWS.md`, under `# Development (unreleased)` (top of file, no `0.7.1`
  section reopened): two new bullets — one covering (a)-(e)'s signposting
  fixes in plain language, one covering (f)'s staged `unit=` change and its
  0.8.0 removal date.

### (h) Bridge-lane lead verification (read-only on the bridge doc)

Source: `/private/tmp/GLLVM.jl-core070-aghq-20260830/docs/dev-log/core070/
r-side-defects-2026-09-02.md`, groups A, C, E only, verified against this
worktree's `R/`:

**Group A**
- PSD kernel acceptance vs Julia's strict-PD-no-jitter: **CONFIRMED** —
  `R/kernel-keywords.R:21` documents `K` as accepting
  "positive-semidefinite"; `R/fit-multi.R:4205` adds a `1e-8` diagonal
  jitter (`K_jit <- K_stored + diag(1e-8, n_kernel_levels)`), which is
  exactly the mechanism that lets a merely-PSD input through.
- `sigma_student` unconditionally per-trait regardless of `df`:
  **CONFIRMED** — `R/fit-multi.R:5587`,
  `log_sigma_student = rep(0.0, n_traits)` is allocated per-trait
  unconditionally; the `df` argument (`R/families.R:367`) only controls
  whether degrees of freedom are estimated or fixed, never the dispersion's
  per-trait-ness.
- `residuals.gllvmTMB_multi()` returns a data.frame with `$residual`, not a
  bare vector: **CONFIRMED** — `R/predictive-diagnostics.R:229`; verified
  live on a toy fit (`class(residuals(fit))` = `"data.frame"`, includes a
  `residual` column among 15).
- `latent(unique=TRUE)`'s Psi companion silently dropped by the Julia
  bridge with `cli_warn`: **OUT OF SCOPE (bridge-owned)** — the warning ID
  exists (`R/julia-bridge.R:3565`, `.frequency_id =
  "gllvmTMB-julia-auto-psi-dropped"`) but only fires on
  `engine = "julia"`; it is bridge-adapter behaviour, not a native-R
  refusal-message gap.

**Group C** (0.7.0 <-> 0.7.1 disagreements — verified as CURRENT repo state,
not something to fix)
- Total-variance formula `V_t = (LL')_tt + psi_t^2`: **CONFIRMED** as the
  current formula — `R/profile-derived.R:950` documents exactly this in
  roxygen.
- Interval-certificate claim demoted to route-only / 3 certified Wald
  cells: **CONFIRMED** — `R/profile-derived.R:938-940` labels the profile
  route `"route-only"` package-wide; the package startup message (visible
  in every test run this session) literally states "Three exact native
  pinned unrotated ordinary-Gaussian standardized-loading Wald cells have
  target-specific certificates only in one frozen DGP."
- `sigma_eps` one-slot-pure / two-slot-mixed parameterisation:
  **CONFIRMED** — `R/gllvmTMB.R:388-396`, `R/family-cdf-args.R:15`.

**Group E** (API-alignment collisions between R and the Julia bridge:
`getREsd`, `compare_Sigma_table`, `compare_dep_vs_two_psi`,
`diagnostic_table`, `compare_loadings`, `fitted`/`predict` shape) — **all 6:
OUT OF SCOPE (bridge-owned)**. Each is a genuine, real difference in what
the R function computes/returns vs. its Julia counterpart, but resolving it
means changing one side's API to match the other (or documenting the
difference on the bridge side) — not a refusal-message gap on the R side.
R's own behaviour is internally consistent and documented; nothing to fix
here under this task's brief.

## Vignette/README `unit = "site"` hits left for the docs slice

`rg -n 'unit\s*=\s*"site"' vignettes/ README.md` finds 44 hits across 15
`vignettes/articles/*.Rmd` files (README.md has none). All but two are
harmless explicit `unit = "site"` example calls (unaffected by the default
change since they specify it). **Two make a now-STALE claim about the
default and need docs-slice attention**:
- `vignettes/articles/morphometrics.Rmd:176` — "gllvmTMB defaults to
  `unit = "site"`, meaning it looks for a column..."
- `vignettes/articles/pitfalls.Rmd:219` — "...`gllvmTMB()` defaults to
  `unit = "site"`, but the unit may..."

Full file list (all 15, for the docs slice to triage):
`spatial-models.Rmd`, `function-map-cheatsheet.Rmd`,
`explaining-latent-ecological-axes.Rmd`, `convergence-start-values.Rmd`,
`pitfalls.Rmd`, `morphometrics.Rmd`, `missing-data.Rmd`,
`rare-species-jsdm.Rmd`, `gllvm-vocabulary.Rmd`,
`lambda-constraint-suggest.Rmd`, `isdm-canada-warbler.Rmd`,
`profile-likelihood-ci.Rmd`, `joint-sdm.Rmd`,
`fixed-effect-zero-constraints.Rmd`, `unit-of-analysis.Rmd`.

## Commands and output

```
$ Rscript -e 'parse("R/<each touched file>")'   # all OK, no syntax errors
$ devtools::document(quiet = TRUE)              # man/gllvmTMB.Rd, man/ridge_path.Rd,
                                                  man/suggest_lambda_constraint.Rd,
                                                  man/suggest_lambda_constraints.Rd rewritten
$ NOT_CRAN=true Rscript -e 'testthat::test_file("tests/testthat/test-gapclose-signposting.R")'
[ FAIL 0 | WARN 0 | SKIP 0 | PASS 10 ]
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
$ Rscript dev/gapclose/count-bare-aborts.R
658 bare aborts found.
```

## Files touched (excluding README.md / inst/CITATION, pre-existing dirty
from before this session)

```
NEWS.md
R/brms-sugar.R
R/data-mixed-family.R
R/diagnose.R
R/family-cdf-args.R
R/fit-multi.R
R/gllvmTMB-wide.R
R/gllvmTMB.R
R/isdm-sources.R
R/methods-gllvmTMB.R
R/parse-multi-formula.R
R/ridge-path.R
R/suggest-lambda-constraint.R
man/gllvmTMB.Rd
man/ridge_path.Rd
man/suggest_lambda_constraint.Rd
man/suggest_lambda_constraints.Rd
tests/testthat/test-no-deprecated-recommendations.R  (extended)
tests/testthat/test-gapclose-signposting.R            (new)
tests/testthat/test-gapclose-next-steps.R              (new)
tests/testthat/_snaps/gapclose-signposting.md          (new snapshot file)
tests/testthat/_snaps/gapclose-next-steps.md           (new snapshot file)
dev/gapclose/abort-inventory.tsv                       (copied input)
dev/gapclose/abort-inventory-notes.md                  (copied input)
dev/gapclose/count-bare-aborts.R                        (new, ratchet logic)
dev/gapclose/A1-A2-report.md                            (this file)
```

Not committed (per brief).
