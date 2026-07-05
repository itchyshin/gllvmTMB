# Slice 2b — unify ordinary `latent()` `residual =` -> `unique =`

Date: 2026-07-05
Branch: `codex/r-bridge-grouped-dispersion`
Commit before task: `aec8df92` (Slice 2a)
Agent: Claude (implementation authorized by Shinichi; multi-agent cascade)

## Goal

Decision 1 of the `unique`-fold arc (Shinichi 2026-07-05): rename the ordinary
intercept-only `latent()` argument `residual =` to `unique =` (same meaning,
same default `TRUE`), unifying the name with the source latents
(`spatial_latent(..., unique = )`, `phylo_latent`) and the augmented
random-regression form (Slice 2a). `residual =` becomes a soft-deprecated alias.
Maintainer instruction: "make sure all documents and webpages are rewritten;
use multiple Haiku scouts to check."

## What changed (code)

- `R/brms-sugar.R`: generalised the Slice-2a resolver to
  `.gllvmTMB_resolve_latent_unique()` (shared by the ordinary and augmented
  branches); the ordinary `latent` desugar branch now reads `unique =`
  (default `TRUE`) with `residual =` as a `lifecycle::deprecate_warn` alias
  (id `gllvmTMB-latent-residual`), drops both keywords before covstruct
  assembly, and keeps the `common`/`.latent_psi` logic. Constructor signature is
  now `latent(formula, d = 1, unique = TRUE, common = FALSE, residual =
  lifecycle::deprecated())`. Roxygen `@param unique` + deprecated `@param
  residual`, `@details` prose, regenerated `man/latent.Rd`.
- Semantics unchanged: `unique = TRUE` == the old `residual = TRUE`. No default,
  likelihood, or covariance behaviour change (verified: default ->
  `rr + diag[psi]`; `unique = FALSE` -> `rr`; `residual = FALSE` -> `rr` +
  deprecation warning).

## Cascade (documents + webpages)

Delegated by non-overlapping area to model-tiered subagents, then verified by
three Haiku scouts (all reported "cascade complete, no stale argument
references"):

- Sonnet V: 7 article webpages (`vignettes/articles/*.Rmd`) -- 12 code
  substitutions + 5 prose/label/comment spots (fixed by orchestrator).
- Sonnet D: `README.md`, `AGENTS.md`, `CLAUDE.md`, `docs/design/01-formula-grammar.md`,
  `docs/design/04-random-effects.md`, `docs/design/35-validation-debt-register.md`
  -- 15 substitutions.
- Sonnet R: R roxygen/cli references in `extract-sigma.R`, `extractors.R`,
  `unique-keyword.R`, `profile-derived-curves.R`, `extract-omega.R` -- 10
  substitutions (kept the deprecation-helper hint + `link_residual` intact).
- `NEWS.md`: 2b entry with scope-boundary statement.
- Haiku scouts 1/2/3 verified vignettes+README, design+AGENTS+CLAUDE, and
  R-roxygen+Rd respectively.

## Tests migrated

12 test files migrated `residual =` -> `unique =` (63 sites), plus the saved
example fixture. Two classes of subtlety fixed:

- **sed over-reach (found + fixed):** `test-mixed-family-extractor.R` has a
  local helper `make_mixed_family_fit(unique = TRUE)`; the blunt sed renamed its
  signature default and call-sites but left the body reference `isTRUE(residual)`
  -> "object 'residual' not found" (4 errors). Fixed the body reference to
  `isTRUE(unique)` and the stale test name. A repo-wide scan confirmed this was
  the only orphaned-`residual` case.
- **deprecation-warning throttle:** `lifecycle::deprecate_warn(id = ...)` warns
  once per session and is NOT overridden by `lifecycle_verbosity`/`rlib_warning_verbosity`.
  So the residual= deprecation warning is asserted in exactly one place
  (`test-ordinary-latent-random-regression.R`, the shared resolver); the
  ordinary alias test in `test-unique-family-deprecation.R` is a behaviour-only
  check (warning silenced) to stay order-independent.
- **saved fixture:** `inst/extdata/examples/covariance-edge-cases-example.rds`
  stored formulas with `residual = FALSE` (1 deprecation warning at parse). The
  fixture holds formulas + data, no fitted models, so the formulas were
  surgically rewritten to `unique = FALSE` (semantically identical, no refit),
  and `data-raw/examples/make-covariance-edge-cases-example.R` updated to match.

## Checks run

```sh
Rscript -e 'devtools::document(quiet=TRUE)'   # clean, no "documented arg not in usage"
# behaviour: default -> rr+diag[psi]; unique=FALSE -> rr; residual=FALSE -> rr + lifecycle_warning_deprecated
# focused: test-mixed-family-extractor 17/0/0; test-example-covariance-edge-cases 31/0/0/0;
#          test-canonical-keywords 96/0; test-extract-sigma 31/0
# full suite (authoritative): PASS=3960 FAIL=0 WARN=0 SKIP=747 -- ALL GREEN
```

Not run (deliberate): `devtools::check()` and `pkgdown::build_articles()` — the
pre-commit gate; the rename is name-only with the alias intact, and the full
`devtools::test()` is the authoritative gate. pkgdown render-check of the
changed articles is a follow-up before any public deploy.

## Guards honored

No push/PR/merge. `residual =` keeps working (soft-deprecated alias), so no
user code breaks. Name-only change: no default / likelihood / covariance
behaviour change. Source-tier default flip (Slice 2c) is separate and NOT in
this slice.

## Known limitations / follow-ups

- Slice 2c (source-tier `phylo_latent`/`spatial_latent` default
  `unique = FALSE -> TRUE`, breaking) is next.
- `pkgdown::build_articles(lazy = FALSE)` render-check of the 7 changed articles
  before any public site deploy.
- GitHub issue closure (if any references the rename) waits for push authority.
