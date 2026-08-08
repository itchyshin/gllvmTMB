# `link_residual` NA-propagation fix — notes (isdm lane, 2026-08-08)

## The defect

`link_residual_per_trait()` (`R/extract-sigma.R`) sets a trait's entry to
`NA_real_` and warns when that trait's rows span more than one
family/link ("no single link-residual variance is defined"). The
consumer in `extract_Sigma()`'s `"total"` branch gated the addition with:

```r
if (any(link_resid_per_trait != 0, na.rm = TRUE)) {
  diag(Sigma) <- diag(Sigma) + link_resid_per_trait
}
```

`na.rm = TRUE` discards the `NA` from the `any()` check. When a trait's
residual is `NA` and no OTHER trait has a nonzero residual, the whole
block is skipped and the returned `Sigma` is `identical()` to
`link_residual = "none"` — the function warns the quantity is undefined,
then returns a number computed as though it were zero.

The same discard pattern also gated the informational `note` describing
what was added (`nonzero <- link_resid_per_trait != 0; if (any(nonzero,
na.rm = TRUE))`), so in the all-NA-no-other-nonzero case no note was
attached either.

## Blast-radius: every internal caller of `extract_Sigma()` / consumer of
## `link_residual`

`link_residual` is `c("auto", "none")` via `match.arg()` in
`extract_Sigma()` itself, so **`"auto"` is the default** whenever a
caller does not pass the argument explicitly.

| Caller (file:line) | Passes | Notes |
|---|---|---|
| `extract_Sigma_B()` (R/extractors.R:26-32) | `"none"` explicit | SAFE |
| `extract_Sigma_W()` (R/extractors.R:51-57) | `"none"` explicit | SAFE |
| `extract_ICC_site()` B tier (R/extractors.R:94-99) | `"none"` explicit | SAFE |
| `extract_ICC_site()` W tier (R/extractors.R:100-105) | `link_residual` param, **default `"auto"`** | **INHERITS AUTO** |
| `extract_communality()` shared (R/extractors.R:237-245) | `"none"` explicit, `.skip_warn=TRUE` | SAFE |
| `extract_communality()` total (R/extractors.R:246-252) | `link_residual` param, **default `"auto"`** | **INHERITS AUTO** |
| `extract_proportions()`-style helper (R/extractors.R:204,238-301) | mixes explicit `"none"` and pass-through `link_residual` (default `"auto"`) | pass-through default |
| **`summary.gllvmTMB()`** (R/methods-gllvmTMB.R:601-605) | `extract_Sigma_B(object)`, `extract_Sigma_W(object)` — safe; `extract_ICC_site(object)` and `extract_communality(object, "unit"/"unit_obs")` — **called with NO override, so both inherit the `"auto"` default** | **CORE PRINT/SUMMARY PATH INHERITS AUTO** — see below |
| `print.gllvmTMB_multi()` internals (R/methods-gllvmTMB.R:947,956) | `extract_Sigma_B(x)$Sigma_B`, `extract_Sigma_W(x)$Sigma_W` | both `"none"` internally → SAFE |
| `extract_Omega()` per-tier sum (R/extract-omega.R:225-231) | `"none"` explicit | SAFE (per-tier) |
| `extract_Omega()` own diag-add (R/extract-omega.R:270-271) | `link_residual == "auto"` gated by `any(link_resid_per_trait != 0, na.rm = TRUE)` | **IDENTICAL DEFECT PATTERN, DIFFERENT FILE** — not fixed here (out of this lane's scope: only `R/extract-sigma.R` was assigned) |
| `extract_phylo_signal()` / omega tiers (R/extract-omega.R:445-706) | `"none"` explicit at the extract_Sigma() call sites; own `link_residual` param default `"auto"` gates the omega-level add (same pattern as above) | not fixed here |
| `extract_two_psi_cross_check` internals (R/extract-two-psi-cross-check.R) | `"none"` explicit throughout | SAFE |
| `extract_correlations()` (R/extract-correlations.R:124,142-146) | own default is directly `"auto"` (not wrapped in `c()`), passes through to `extract_Sigma()` | user-facing extractor; **inherits auto by design** (already documented/tested, e.g. `test-mixed-family-extractor.R`) |
| `extract_cross_correlations()` (R/extract-correlations.R:401,869) | default `c("auto","none")`, pass-through | user-facing; inherits auto by design |
| `communality-ci.R` (`extract_communality_ci`-style wrapper) | default `c("auto","none")` | user-facing CI wrapper; inherits auto by design |
| `bootstrap_Sigma()` and friends (R/bootstrap-sigma.R) | multiple `link_residual = c("auto","none")` defaults, pass-through to `extract_Sigma()`/`extract_ICC_site()` | user-facing, opt-in; inherits auto by design |
| `extract_Sigma_table()` / plot table builders (R/extract-sigma-table.R, R/plot-covariance-tables.R x4) | default `c("auto","none")`, pass-through | user-facing plot/table helpers; inherit auto by design |
| `rotate_loadings()`-adjacent helper (R/rotate-loadings.R:379-383) | **hard-coded `link_residual = "auto"`** (not a parameter) | internal helper invoked explicitly by the user's rotation workflow, not by `summary()`/`print()`/`fit()` |
| `profile_derived*`, `z-confint-gllvmTMB.R`, `extractors.R` (extract_proportions shared piece) | `"none"` explicit | SAFE |
| `julia-bridge.R` `link_residual` handling | independent mechanism reading the GLLVM.jl retained payload; does **not** call `link_residual_per_trait()` | unaffected by this fix |
| `check-auto-residual.R` | guidance/guard messaging about `link_residual = "auto"` for ordinal-probit double-counting; does not call `extract_Sigma()`/`link_residual_per_trait()` directly | unaffected |

### The one finding that matters

**`summary.gllvmTMB()` calls `extract_ICC_site(object)` and
`extract_communality(object, "unit")` / `extract_communality(object,
"unit_obs")` with no `link_residual` override, so both inherit the
`"auto"` default and therefore call into the exact `extract_Sigma()`
consumer this fix changes.** Before the fix, a trait spanning multiple
families would silently make `summary()`'s ICC and communality entries
for that trait numerically wrong (computed as if the residual were 0).
After the fix, those same console entries become `NA` for that trait —
visibly undefined, which is the same "visibly undefined rather than
silently zero" contract requested for `extract_Sigma()` itself, now
propagated one level further to the two `summary()` fields that reuse
its `"auto"` default.

## Contract chosen

**Full NA propagation inside `R/extract-sigma.R`, without patching
`extract_ICC_site()` / `extract_communality()` / `summary.gllvmTMB()` to
force `link_residual = "none"`.**

Rationale:

1. The task's own contract for `extract_Sigma()` is "visibly undefined
   rather than silently zero." `extract_ICC_site()`'s W-tier value and
   `extract_communality()`'s total value are *both derived directly from*
   `extract_Sigma(..., link_residual = "auto")` — they are not a separate
   quantity with a separate defect. Making `extract_Sigma()` correct and
   then deliberately overriding the two console-facing callers back to
   `"none"` would reintroduce exactly the "quantity is undefined but the
   printed number pretends otherwise" failure mode for two more surfaces,
   just one call deeper.
2. The boundary test (single-family-per-trait fits: logit, probit,
   cloglog, Poisson-log) proves the ordinary/common case is completely
   unaffected — `NA` only appears when a trait genuinely spans multiple
   families, which is already a pre-existing edge case that
   `link_residual_per_trait()` warns about on its own. No existing
   passing test in the repository exercises a trait spanning multiple
   families through `summary()` (grep for "multiple families" found no
   test references before this lane), so this is not a documented/relied-
   upon behaviour being broken — it is the same undocumented silent-zero
   bug now visible one layer further out.
3. This is a **file-scoped lane** (`R/extract-sigma.R` only, per the
   task's working-directory rule); editing `R/extractors.R` or
   `R/methods-gllvmTMB.R` to force `"none"` would be scope creep beyond
   what was assigned, and per the task's own instruction "do not silently
   pick a weaker fix to avoid touching a caller" — the alternative of
   quietly forcing `"none"` in those callers would be exactly that: it
   would hide the newly-correct `NA` instead of fixing the caller's
   documentation/behaviour deliberately.

**Recommendation for a follow-up, out of this lane's scope:** if the
maintainer wants `summary()`/`print()` to stay numeric even for a
multi-family trait (e.g. because they should never show `NA` in routine
console output), the correct fix is in `R/extractors.R`:
`extract_ICC_site()`'s W-tier call and `extract_communality()`'s `total`
call would need to pass `link_residual = "none"` explicitly (mirroring
what `extract_Sigma_B()` / `extract_Sigma_W()` already do), OR
`summary.gllvmTMB()` could special-case a friendlier per-field message.
Either is a caller-side decision belonging to whoever owns
`R/extractors.R` / `R/methods-gllvmTMB.R`, not to this fix.

`R/extract-omega.R`'s `extract_Omega()` carries the **identical**
`na.rm = TRUE` discard bug at its own diagonal-add step
(`R/extract-omega.R:270-271`, `if (any(link_resid_per_trait != 0, na.rm =
TRUE))`). It was **not** touched — it's a different file, out of this
lane's assigned scope — but it is the same defect and should get the
same fix in a follow-up.

## The fix (R/extract-sigma.R)

1. `link_residual_per_trait()`'s multi-family warning text now also says
   what the return value means and what to do about it: the trait's
   residual is `NA_real_`, it propagates into `diag(Sigma)` (and, via
   `.safe_cov2cor()`, into that trait's row/column of `R`) as `NA` rather
   than `0`, and `link_residual = "none"` is offered as the deliberate
   ecological-linear-predictor-only alternative.
2. The `"total"`-branch consumer's guard changed from
   `any(link_resid_per_trait != 0, na.rm = TRUE)` to
   `any(is.na(link_resid_per_trait) | link_resid_per_trait != 0)`, so an
   `NA` entry is no longer dropped by `na.rm`. `diag(Sigma) <-
   diag(Sigma) + link_resid_per_trait` then naturally propagates `NA`
   into exactly the affected trait's diagonal entry (`0 + x = x`, `NA + x
   = NA`), leaving every other trait's diagonal untouched.
3. The note-building gate got the same `anyNA()` fix so the descriptive
   note (which already labels a mixed-family trait as `"mixed:fam1/fam2"`
   via the existing `fam_lookup()` machinery) is still attached even when
   every affected trait's residual happens to be `NA` with no other
   nonzero entries.
4. `R` (the correlation matrix) needed **no separate code change**:
   `.safe_cov2cor()` already gates on `is.finite(D) & D > 0` where `D <-
   sqrt(diag(Sigma))`, so once `diag(Sigma)` carries an `NA` at the
   affected trait, that trait's entire row/column of `R` is already
   correctly `NA_real_` (its pre-existing initialization value) with no
   further edit needed.

## Before-fix failure (verbatim)

Reproduced by `git stash push --keep-index -m ... -- R/extract-sigma.R`
(reverting only that file to its pre-fix state while the new tests stayed
in place), then running
`tests/testthat/test-extract-sigma.R` with `devtools::load_all()`:

```
extract-sigma: ..................................W.1234................

══ Warnings ════════════════════════════════════════════════════════════
1. extract_Sigma(link_residual = 'auto') propagates NA for a trait spanning
   multiple families ('test-extract-sigma.R:269:3') - Link-scale residual
   variance is unavailable for trait(s): trait_2. Returning NA rather than
   substituting a finite value.

══ Failed ════════════════════════════════════════════════════════════════
── 1. Failure ('test-extract-sigma.R:281:3'): extract_Sigma(link_residual = 'aut
Expected `isTRUE(all.equal(out_auto$Sigma, out_none$Sigma))` to be FALSE.
Differences:
`actual`:   TRUE
`expected`: FALSE

── 2. Failure ('test-extract-sigma.R:284:3'): extract_Sigma(link_residual = 'aut
Expected `is.na(out_auto$Sigma[mixed_idx, mixed_idx])` to be TRUE.
Differences:
`actual`:   FALSE
`expected`: TRUE

── 3. Failure ('test-extract-sigma.R:285:3'): extract_Sigma(link_residual = 'aut
Expected `all(is.na(out_auto$R[mixed_idx, ]))` to be TRUE.
Differences:
`actual`:   FALSE
`expected`: TRUE

── 4. Failure ('test-extract-sigma.R:286:3'): extract_Sigma(link_residual = 'aut
Expected `all(is.na(out_auto$R[, mixed_idx]))` to be TRUE.
Differences:
`actual`:   FALSE
`expected`: TRUE
```

This is the proof that, pre-fix, `extract_Sigma(fit, link_residual =
"auto")` on a trait spanning multiple families returned a `Sigma`
`all.equal()`-identical to `link_residual = "none"` — the exact defect
described in the task — while a *different*, pre-existing catch-all
warning inside `link_residual_per_trait()` (`if (anyNA(out)) warning(...)`,
`R/extract-sigma.R:379-387`, present before this lane touched the file)
already fires whenever any per-trait residual is `NA`, regardless of
cause. That catch-all warning is **not** part of this fix; it pre-dates
this lane and was not modified. The lane's own inline warning (added at
the "multiple families" detection site) is consumed by `expect_warning()`
in the test; the pre-existing catch-all warning is the one that surfaces
as an uncaught `Warning` in the report above (harmless — it does not fail
the test, and existed before this fix).

## After-fix test results

`tests/testthat/test-extract-sigma.R` (`devtools::load_all()`,
`NOT_CRAN=true`):

```
extract-sigma: ..................................W.....................
passed: 55  failed: 0  warning: 1  skipped: 0
```

The single remaining `Warning` is the same pre-existing catch-all
(`R/extract-sigma.R:379-387`), not a failure.

Broader run — every file under `tests/testthat/` that references
`extract_Sigma`, `link_residual`, or `Sigma_B` (`grep -rln
"extract_Sigma\|link_residual\|Sigma_B" tests/testthat/*.R`), prioritised
to the files that exercise `link_residual` / mixed-family / the extractor
surface most directly:

(results filled in below once the batch run completes — see the
"Verification" section of the final chat reply for the authoritative
counts and any failures, with each one marked pre-existing vs
caused-by-this-change.)
