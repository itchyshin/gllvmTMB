# After-task: README Tiny example wide-form + drop gllvmTMB_wide mention -- 2026-05-13

**PR / branch**: #80 / `agent/readme-tiny-example-wide-form`

**Lane**: Claude (rule-file-adjacent docs; landing-page wording).

**Dispatched by**: maintainer (2026-05-13 mid-afternoon MT):
*"Tiny example -- don't we need to have wide format syntax too??"*
and *"do not need to mention `gllvmTMB_wide` here??"*

**Files touched**: `README.md` only (no source, no rules, no API).

## Math contract

No change. The Tiny example is unchanged in math (still
`\Sigma = \Lambda \Lambda^\top + \text{diag}(s)` with one
shared latent axis + per-trait unique variance); only the
formula-API surface is widened from long-only to both shapes,
matching what the "Data shapes" section above already shows.

## What changed

1. **Tiny example -- added wide-form companion call.** After the
   long-form `fit <- gllvmTMB(value ~ 0 + trait + ..., data =
   sim$data, ...)`, a wide-form `fit_wide <-
   gllvmTMB(traits(t1, t2, t3) ~ 1 + latent(1 | site, d = 1) +
   unique(1 | site), data = df_wide, ...)` block follows, with
   a one-line note that both reach the same long-format engine
   and produce byte-identical fits. Points to the Get Started
   vignette for the runnable long-to-wide pivot.

2. **Current boundaries -- dropped the `gllvmTMB_wide(Y, ...)`
   soft-deprecation paragraph.** The landing page should
   advertise the canonical API (`traits(...)` LHS), not the
   deprecated one. Users hitting `gllvmTMB_wide()` still get
   the `lifecycle::deprecate_soft()` message at runtime, and the
   function's roxygen still describes the migration. The
   landing page is where new users decide whether to invest in
   the package; the deprecated wrapper is noise there.

## Why this matters

The first screenshot the maintainer shared (index.html /
README's Tiny example) showed long-form only, even though the
"Data shapes" section right above it tells the reader both
shapes are first-class. New users reading the Tiny example as
"this is what gllvmTMB looks like" would walk away thinking
only the long shape is canonical -- which then makes
`gllvmTMB_wide()`'s deprecation paragraph in "Current
boundaries" feel like a contradiction rather than a clean
migration story.

After this PR: Tiny example shows the canonical wide form too,
and the "Current boundaries" paragraph doesn't have to
disambiguate which wide entry point is canonical because only
one form is advertised.

## Risk

Low. Landing-page wording only; no executable chunks added
(the wide-form block uses a placeholder `df_wide` data frame
since `simulate_site_trait()` returns long-only -- the
runnable pivot lives in the Get Started vignette per the note).

## What this does NOT do

- Does not touch `extract_correlations(fit, tier = "unit")`
  at line 127. That call is correct for the current API
  (`extract_correlations()` actually uses `tier = `). The
  `tier=` vs `level=` API inconsistency across extractors is
  item #10 in `audits/2026-05-13-post-overnight-drift-scan.md`
  and is parked for maintainer judgment.
- Does not touch `gllvmTMB_wide()`'s roxygen, soft-deprecation
  message, or reference-index entry. The function still exists
  and the deprecation pathway is unchanged.

## Tests of the tests

No tests added (docs-only). Local check: `Rscript -e
'rmarkdown::render(\"README.md\", quiet = TRUE)'` -- ensures
the README still parses. CI runs `R CMD check` which builds
`man/gllvmTMB-package.Rd` from `DESCRIPTION` (unchanged), so
no further test coverage is required.

## Self-merge eligibility

Landing-page wording, no source, no rules, no API. Maintainer
explicitly dispatched both edits this turn. Self-merge once
CI is green.
