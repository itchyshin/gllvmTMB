# `getLV(se = TRUE)` — investigation, design, and verification

Branch: `claude/getlv-score-se-20260725`. Worktree:
`/Users/z3437171/local-scratch/worktrees/gllvmtmb-getlv-se`.

## The need

Ayumi Mizuno's applied 44-indicator analysis (Ayumi-495/urbanisation_map#13)
needs a standard error per unit-level latent score for inverse-variance
weighting in a Stage-2 meta-regression. No competitor package
(`gllvm`, `glmmTMB`) exposes this directly; she extracted it herself from
each package's TMB internals via `sdreport(getJointPrecision = TRUE)`,
locating the relevant random-effect block, inverting the joint precision,
and reading the diagonal. Her explicit warning: wrong block ordering
produces plausible but wrong numbers with no error.

## Block-ordering investigation

### Claim to verify

Ayumi's note: `gllvmTMB`'s block is `"z_B"`, "review-major / LV-interleaved"
(i.e. consecutive parameter-vector entries cycle through the latent axes
for one unit before moving to the next unit).

### Evidence gathered independently (not trusting the note)

1. **TMB template** (`src/gllvmTMB.cpp:496`):
   `PARAMETER_MATRIX(z_B); // d_B x n_sites spherical N(0, I)`.
   TMB flattens a `PARAMETER_MATRIX` column-major, exactly like an R
   matrix. A `(d_B x n_sites)` matrix flattened column-major puts all
   `d_B` axis values for site 1 first, then all `d_B` values for site 2,
   etc. — i.e. **site-major, axes interleaved within each site**. This
   confirms Ayumi's claim directly from the C++ declaration, independent
   of her own extraction code.

2. **`random <- c(random, "z_B")`** (`R/fit-multi.R:4633`, active whenever
   `use_rr_B` is true): confirms `z_B` is genuinely a TMB random effect
   (not a fixed parameter), so its marginal SE is computed by
   `TMB::sdreport()`'s random-effect machinery, not the fixed-effect delta
   method.

3. **Existing R-side reshape convention** (`R/extractors.R:485`, inside
   `extract_ordination()`, already shipping and tested):
   ```r
   z_B <- matrix(par[names(par) == "z_B"], nrow = fit$d_B, ncol = fit$n_sites)
   ...
   innovation <- t(z_B)
   ```
   This is the SAME convention as (1): reshape to `(d_B x n_sites)`
   column-major, then transpose to `(n_sites x d_B)`. `getLV(se = TRUE)`'s
   new helper (`.getLV_se()`, `R/output-methods.R`) reuses this identical
   `matrix(nrow = d, ncol = n)` then `t()` convention for the SE vector, so
   `scores[i, k]` and `se[i, k]` are guaranteed to reference the same
   (unit, axis) cell by construction — not by a second, independently
   re-derived index arithmetic that could disagree with (3).

4. **Within-unit tier**: `z_W` (`level = "unit_obs"`) is declared and
   flattened identically (`R/extractors.R:513-517`), and is random whenever
   `use_rr_W` (`R/fit-multi.R:4637`). The same reshape convention applies;
   `.getLV_se()` handles both tiers with one code path keyed on `level`.

Conclusion: Ayumi's note is correct, and is now independently re-derived
from the C++ template plus the existing (already-tested) R reshape
convention, not merely trusted.

## Design decision: return shape

`getLV(fit, level, rotate, se = FALSE)` — `se` appended as a 4th argument
(default `FALSE`, so existing positional calls `getLV(fit, "unit")` are
unaffected).

- `se = FALSE` (default): unchanged — returns the bare `n x d` matrix, byte
  identical to before this change (verified: `identical(getLV(fit, "unit"),
  getLV(fit, "unit", se = FALSE))` in `test-getlv-se.R`).
- `se = TRUE`: returns `list(scores = <n x d matrix>, se = <n x d matrix>)`,
  with `se` carrying the same `dimnames` as `scores`.

**House-pattern justification.** `getLV()` is a thin wrapper around
`extract_ordination()`, which already returns
`list(scores, loadings, row_id)` (`R/extractors.R:504-508`). Reusing the
`scores` field name and adding a same-shaped `se` field is the smallest
deviation from an established sibling contract in the same file family,
and keeps `se[i, k]` next to `scores[i, k]` positionally rather than
flattening to a long `data.frame`. This was chosen over the alternative
long-format `data.frame(trait/axis/estimate/se/lower/upper/...)` pattern
used by `loading_ci()` and `extract_lv_effects()` (`R/loading-ci.R`,
`R/extractors.R:598+`) because those functions summarise a *small*,
fixed-size structure (T traits x d axes, or predictor x axis), for which a
long table with a `pinned`/`ci_status` column is natural; `getLV()`
summarises potentially hundreds of units, where a wide matrix is the
existing, expected shape and a long table would be a much bigger surface
change for the same information. `bootstrap_Sigma()`
(`R/bootstrap-sigma.R`) was also reviewed; its `point_est`/`ci_lower`/
`ci_upper` named-list pattern is a good precedent for "point + uncertainty
as parallel objects" but its keys are per-quantity strings, not applicable
to a "score matrix + SE matrix" pair.

No `lower`/`upper` fields are added — no Wald bound is claimed here, only
the SE, consistent with "point estimates are the supported claim" language
used elsewhere in this package's uncertainty-bearing extractors when a
route has not been coverage-tested.

## Computation route

`.getLV_se()` (private helper in `R/output-methods.R`, next to `getLV()`):

```r
sd_rep <- fit$sd_report
z_name <- if (level == "B") "z_B" else "z_W"
d <- if (level == "B") fit$d_B else fit$d_W
n <- if (level == "B") fit$n_sites else fit$n_site_species
idx <- which(names(sd_rep$par.random) == z_name)
se_vec <- sqrt(pmax(sd_rep$diag.cov.random[idx], 0))
se_mat <- t(matrix(se_vec, nrow = d, ncol = n))
```

This reuses `fit$sd_report`, which is already computed at fit time
(`R/fit-multi.R:4850-4862`, `TMB::sdreport(obj, par.fixed = opt$par,
getJointPrecision = FALSE)`, on by default via `gllvmTMBcontrol(se =
TRUE)`). Reading TMB's own `sdreport.R` source
(`system.file(package = "TMB")`) confirms `ans$par.random <- par[r]` and
`ans$diag.cov.random <- diag.term1 + diag.term2` are computed **whenever
the model has random effects, independent of `getJointPrecision`** — that
flag only additionally attaches the full `jointPrecision` matrix. So
`se = TRUE` costs **no extra `sdreport()` call**: it reads a quantity TMB
already computed at fit time.

## Independent cross-check (requirement 2)

`diag.cov.random` is computed by TMB via a sparse-Cholesky
Schur-complement shortcut (`solveSubset()` on the random-effect Hessian,
plus a correction term for fixed-parameter uncertainty) — a genuinely
different linear-algebra path from directly inverting the full joint
precision matrix. The Schur-complement identity guarantees these are
mathematically the same quantity; disagreement would indicate the wrong
block was read or reshaped, not a modelling difference.

Cross-check performed (interactively, then encoded as
`test-getlv-se.R`'s `"getLV(se = TRUE) agrees with an independent
joint-precision-inversion route"` test):

```r
sd2 <- TMB::sdreport(fit$tmb_obj, par.fixed = fit$opt$par, getJointPrecision = TRUE)
JP  <- sd2$jointPrecision
idx <- which(rownames(JP) == "z_B")
se_independent <- sqrt(diag(as.matrix(Matrix::solve(JP)))[idx])
```

**Result** (development fit: n_sites = 80, n_species = 12, n_traits = 4,
d_B = 2, ordinary `latent()` with default Psi): `getLV(se = TRUE)$se`
against the independent joint-precision-inversion route —

```
max abs diff: 4.440892e-16   (machine epsilon)
max rel diff: 1.532087e-15
```

**Agreement tolerance used in the shipped test**: `tolerance = 1e-6`
(`testthat::expect_equal(..., tolerance = 1e-6)`), far looser than the
observed ~1e-15 agreement, to be robust to solver/BLAS variation across
machines while still being far tighter than any real ordering error would
produce (a misordered block gives O(1)-scale disagreement, not O(1e-6)).

## Ordering test: how it would fail if the reshape were wrong

`test-getlv-se.R`, `"getLV(se = TRUE) uses the correct (unit-major)
reshape, not a swapped one"`:

- Takes the SAME flat `se_vec <- sqrt(diag.cov.random[idx])` used
  internally.
- Builds the CORRECT reshape: `se_correct <- t(matrix(se_vec, nrow = d,
  ncol = n))` (site-major blocks of `d`, then transpose) — this is what
  `.getLV_se()` does.
- Builds a plausible WRONG reshape: `se_wrong <- matrix(se_vec, nrow = n,
  ncol = d)` (treating the flat vector as if consecutive runs of `n`
  values belonged to one axis) — same `n x d` output shape, so a
  transposed/misordered read like this would NOT be caught by a shape or
  `dim()` assertion alone.
- Asserts `out$se` equals `se_correct` and `max(abs(se_correct -
  se_wrong)) > 1e-3` (i.e. the wrong reshape is demonstrably, numerically
  different — the test would fail to discriminate if `d == n`, so it also
  asserts `d != n` up front).

A second, independent instance of the same guard
(`"getLV(level = 'unit', se = TRUE) on the B+W fit still reads z_B, not
z_W"`) exists because **this exact hazard was hit during development**:
the first implementation passed `.canonical_level_name(level)` (which
converts the internal `"B"`/`"W"` code back to the user-facing
`"unit"`/`"unit_obs"` string) into `.getLV_se()`, whose internal branch
tested `if (level == "B")`. Since `"unit" != "B"`, every call silently
took the `else` (W) branch regardless of the requested `level` — every
test in the suite failed identically (`"Could not locate the z_W
random-effect block"` even when `level = "unit"` was requested) until the
call site was fixed to pass `level` (already `"B"`/`"W"`) directly instead
of re-translating it. This is recorded because it is precisely the class
of silent-misordering bug the task named as the hazard, caught by the
test suite before merge, not left latent.

## `rotate` handling

`rotate != "none"` together with `se = TRUE` raises
`gllvmTMB_getLV_se_rotated_unsupported` rather than silently pairing
rotated scores with un-rotated SEs. Rotating scores
(`rotate_loadings()`) applies an orthogonal (varimax) or oblique (promax)
transform `T`; propagating the SE would require `Var(scores %*% T)`,
i.e. `T` acting on the per-unit score covariance, not just the SE vector
(and for `promax`, `T` is not orthogonal, so even the shape of that
propagation differs). This is not implemented; refusing is the safe
choice given the task's explicit instruction not to return an unrotated
SE beside a rotated score.

## `level` handling

- `level = "unit"` (`z_B`) and `level = "unit_obs"` (`z_W`) are both
  supported through the same `.getLV_se()` code path, keyed by the
  already-normalised internal `level` ("B"/"W").
- Predictor-informed `latent(..., lv = ~ x)` fits (`fit$use$lv_B`) are
  refused (`gllvmTMB_getLV_se_lv_predictor_unsupported`): `getLV()`'s
  `"total"` score component is `innovation (z_B) + mean_scores
  (X_lv_B %*% alpha_lv_B)` when `lv_B` is active
  (`R/extractors.R:496-501`), and the mean term's own uncertainty
  (`alpha_lv_B`'s SE, already partially exposed by
  `extract_lv_effects(type = "axis_effect")`) is not yet propagated into
  the combined score SE. Only `z_B`'s own SE would be a partial, silently
  incomplete answer, so this is refused rather than returned. There is no
  equivalent `lv_W` predictor path, so `level = "unit_obs"` needs no such
  guard.
- Fits with no rr term at the requested level (e.g. `indep(0 + trait |
  site)` only) already return `NULL` from `extract_ordination()`; `getLV()`
  returns `NULL` before `se` is even considered, unchanged from current
  behaviour.
- `engine = "julia"` bridge fits are refused
  (`gllvmTMB_getLV_se_julia_unsupported`): bridge fits carry no native TMB
  `sd_report`.
- A fit with no `sd_report` (`gllvmTMBcontrol(se = FALSE)`, or a failed
  `sdreport()`) is refused (`gllvmTMB_getLV_se_no_sdreport`).
- A non-positive-definite Hessian (`sd_report$pdHess == FALSE`) returns
  `NA` standard errors with a `cli_warn`, matching `loading_ci()`'s
  existing convention for the same situation, rather than erroring.

## NAMESPACE-unchanged confirmation

`getLV` was already an exported name; only its argument list changed
(added `se = FALSE`), which does not touch `NAMESPACE`.

```
$ shasum -a 256 NAMESPACE
c97ae039f1a58346a129e988e127cc8464a401264eb530d6a7da905fd329ff46  NAMESPACE
$ git diff origin/main -- NAMESPACE | wc -l
0
```

Byte-identical to `origin/main`; the signed freeze (SHA-256 `c97ae039...`,
153 exports / 33 S3 methods) holds. `devtools::document()` was run and
only regenerated `man/getLV.Rd`.

## Test counts

`tests/testthat/test-getlv-se.R` (new file): **10 test_that() blocks, all
passing**, ~13s wall time (`testthat::test_file()`), including two ~7s
TMB fits built once at module scope and reused read-only across tests
(not rebuilt per test, to keep the suite fast — the fixture configuration
is the same known-good, positive-definite-Hessian setup already used in
`test-extractors.R`'s first test).

```
getlv-se: ...........................
DONE (no failures)
```

Broader regression sweep, `devtools::test(filter = "getLV|ordination|lv|extract")`
(runs `test-getlv-se.R` alongside every other `extract*`/`*ordination*`/
`*lv*` test file in the package, including comparator, mixed-family,
bootstrap, and heavy-recovery suites):

```
[ FAIL 0 | WARN 2 | SKIP 52 | PASS 1230 ]
```

Zero failures. The 52 skips are heavy recovery/matrix tests that are
opt-in by design (`GLLVMTMB_HEAVY_TESTS=1`), unrelated to this change. The
2 warnings are pre-existing, from `test-comparator-gllvm.R`'s
`gllvm::gllvm()` comparator call ("There are rows full of zeros in y."),
not from any code touched here.

## Warnings verbatim

The only warning newly exercisable by this change, captured verbatim from
a live run (non-positive-definite-Hessian path):

```
Warning message:
Fit's Hessian is not positive-definite at the optimum.
i Returning `NA` standard errors -- Wald inference is unavailable for this fit.
```

The package-load banner (unrelated to this change, present in every
session) is also reproduced verbatim for completeness:

```
gllvmTMB is EXPERIMENTAL (lifecycle: experimental). Use at your own risk:
the package is not complete, is not fully human-verified, and needs
extensive further validation. Point estimates are the supported claim; no
cell's interval coverage is certified, and covariance routes have
focused-test evidence only. See NEWS and the package website for scope.
```

## Files changed

- `R/output-methods.R` — `getLV()` gains `se = FALSE`; new private helper
  `.getLV_se()`.
- `man/getLV.Rd` — regenerated via `devtools::document()`.
- `tests/testthat/test-getlv-se.R` — new file, 9 tests.
- `docs/design/06-extractors-contract.md` — `getLV` coverage-matrix row and
  per-extractor contract section updated.
- `NEWS.md` — new-feature bullet added under the `## New` section.
- `dev/getlv-score-se-RESULTS.md` — this file.
- `NAMESPACE` — unchanged (confirmed above).
