# After-task: Phase 1a Batch D -- 2026-05-14

**Tag**: `docs` (article cleanup; no R/, src/, or NAMESPACE
change).

**PR / branch**: this PR / `agent/phase1a-batch-d`.

**Lane**: Claude (Codex absent).

**Dispatched by**: maintainer 2026-05-14 22:50 UTC ("so the
road map is done let's get to work!!" + "get your team to
work - Ada I want to see who is working and what they are
thinking"). Batch D is one of the four drift-cleanup batches
in the
[2026-05-13 post-overnight drift-scan audit](https://github.com/itchyshin/gllvmTMB/blob/main/docs/dev-log/audits/2026-05-13-post-overnight-drift-scan.md).

## Files touched

- `vignettes/articles/morphometrics.Rmd` -- removed the
  `fit_wide_matrix <- gllvmTMB_wide(Y, d = 2, family =
  gaussian())` chunk (line 137 in the pre-edit file) and the
  matrix-wide vs long-wide `cat()` comparison that referenced
  it (lines 147-150). Also dropped the prose sentence
  "`gllvmTMB_wide(Y, ...)` is the matrix-in entry point for
  the same model when the response already lives in a numeric
  matrix" (formerly lines 163-165). The article retains both
  the long-format `fit_long` and the wide-formula
  `fit_wide_formula` (using `traits(...)`); the
  long/formula-wide `logLik` comparison stays as the canonical
  byte-identical-fit demonstration.
- `vignettes/articles/response-families.Rmd` -- removed the
  "For matrix-first workflows, `gllvmTMB_wide()` is the
  shortest route" paragraph and its code chunk (formerly
  lines 91-95). The wide-formula path via `traits(...)` shown
  just above (formerly lines 79-89) remains as the canonical
  wide entry point.

Net diff: **1 insertion, 16 deletions across 2 files**.

## Math contract

No public R API, likelihood, formula grammar, family,
NAMESPACE, generated Rd, or pkgdown navigation change.

## Why

`gllvmTMB_wide(Y, ...)` is the legacy matrix-in entry point
to the package, soft-deprecated in 0.2.0
([PR #65 deprecation](https://github.com/itchyshin/gllvmTMB/pull/65),
documented at
[`docs/dev-log/decisions.md` 2026-05-11 user-facing examples pair long + wide](https://github.com/itchyshin/gllvmTMB/blob/main/docs/dev-log/decisions.md)).
The two articles touched here still showed `gllvmTMB_wide()`
as a demonstration alongside the new
`gllvmTMB(traits(...) ~ ..., data = df_wide)` formula path,
which contradicts the soft-deprecation: a reader landing on
the article today sees three side-by-side fits with no signal
that `gllvmTMB_wide()` is on the way out.

Removing the matrix-in demonstrations from these two articles
leaves the formula-API examples (`fit_long`,
`fit_wide_formula`) as the user-facing canon. The legacy
`gllvmTMB_wide()` function still exists in the package
NAMESPACE for backward compatibility; users who need it can
find it in the reference index.

## Checks run

- `pkgdown::check_pkgdown()`: **"No problems found."** ✓
- `rg -n 'gllvmTMB_wide' vignettes/articles/morphometrics.Rmd
  vignettes/articles/response-families.Rmd`: **0 hits**, as
  intended.
- `git diff --stat`: 2 files changed, 1 insertion(+), 16
  deletions(-).

## Consistency audit

```
[target files: morphometrics.Rmd + response-families.Rmd]
  rg 'gllvmTMB_wide' -> 0 hits
  rg 'fit_wide_matrix' -> 0 hits
  rg 'matrix-first|matrix-in' -> 0 hits in the target files (still
    present in non-target articles like response-families.Rmd
    has not been edited beyond the targeted paragraph; rest of
    the article unchanged)
```

`gllvmTMB_wide` may still appear in non-target locations
(`R/gllvmTMB-wide.R` source, `man/gllvmTMB_wide.Rd`,
`_pkgdown.yml` deprecated-aliases group, NAMESPACE export);
those are intentional retentions per the soft-deprecation.

## Tests of the tests

No tests added. The chunks removed had `eval = TRUE` so they
ran on every pkgdown render; their removal slightly reduces
article render time. No fit-output dependence elsewhere in
either article on `fit_wide_matrix` or `fit_matrix`
(verified by inspecting downstream chunks).

## Roadmap tick

> **Roadmap tick**: Phase 1a → progress `████░░░░` 4/5 (was
> 3/5 after Batch B); status stays 🟢 In progress. Batches:
> A ✅ · B 🟢 (PR #94 in CI) · C ✅ · D 🟢 (this PR) ·
> E ⚪ (next).

Will update the rendered roadmap row in `ROADMAP.md`'s "Phases
at a glance" table on `main` after this PR + PR #94 merge.
The roadmap-tick discipline (codified in `docs/design/10-after-task-protocol.md`
this morning) is now in routine use.

## What went well

- The Phase 1b persona consult ran in parallel with Batch D
  execution (Gauss / Fisher / Emmy returned substantive
  briefs while the mechanical edits happened). Two work
  threads in one turn is exactly the parallelism the
  maintainer asked for ("get your team to work").
- The articles still demonstrate long-format and wide-format
  fits side-by-side -- the long/formula-wide byte-identical
  check (`logLik(fit_long)` vs `logLik(fit_wide_formula)`)
  is the user-facing canonical proof and stays intact.
- Tiny diff: 1 insertion, 16 deletions. Low review burden.

## What did not go smoothly

- Nothing flagged. Batch D was the smallest of the four
  Phase 1a drift-cleanup batches (4 audit-doc hits) and went
  to plan.

## Team learning, per AGENTS.md "Standing Review Roles"

For this small docs PR the standing brief applies for most
roles -- text-only article edits with no engine, API,
formula-grammar, family, or NAMESPACE change. The notable
engagement was the **parallel Phase 1b consult**:

- **Gauss**: surfaced the mu_t saturation footgun in
  `R/extract-sigma.R:195, 210` (Beta + betabinomial trigamma
  blow-up when `mu_t → 0` or `1`). **Pulled into Phase 1b
  scope from Phase 5 polish**: the `mu_t <- pmin(pmax(mu_t,
  1e-6), 1 - 1e-6)` clamp is correctness-critical when
  shipping the `link_residual = "auto"` default. Also flagged
  that `sigma_eps` is Gaussian-scalar; using it for Gamma
  `nu_hat` in mixed-family fits is a real (separate-PR) bug.
- **Fisher**: locked the `check_identifiability(fit,
  sim_reps = 100, alpha = 0.05, parallel = FALSE, seed =
  NULL, tier = c("B","W","phy"), verbose = TRUE)` signature
  and the 4-component return shape
  (`$recovery` / `$loadings` / `$hessian` / `$flags`).
  Identified "spurious extra factor masquerading as
  identified" as the canonical case `check_identifiability`
  catches that no other diagnostic currently does. Costed
  100 refits at 5-15 min serial on a Tier-1 fixture --
  `skip_on_cran() + skip_on_ci()` mandatory.
- **Emmy**: confirmed `check_*()` standalone verb naming
  (not folded into `gllvmTMB_diagnose()`); placed
  `check_auto_residual` + `check_identifiability` in
  Diagnostics group of `_pkgdown.yml`. Flagged that
  `extract_correlations(link_residual = "auto")` default
  change IS a breaking change for non-Gaussian callers --
  needs `lifecycle::deprecate_soft("0.3.0", ...)`. Listed
  test fixtures that need explicit
  `link_residual = "none"` to lock current semantics.
  Surfaced the **`n_boot` / `nsim` / `sim_reps` naming
  inconsistency** across `bootstrap_Sigma`,
  `extract_correlations`, and the new
  `check_identifiability` -- pick one name (Emmy
  recommended `n_sim`) before CRAN.
- **Pat / Darwin / Boole / Noether / Rose / Grace /
  Curie / Jason / Shannon**: standing brief.

## Design-doc updates

None for this PR. The Phase 1b persona findings will land in
the Phase 1b implementation PRs alongside the corresponding
code.

## pkgdown / documentation updates

None directly. The two affected vignettes will re-render on
the next pkgdown deploy after `R-CMD-check` passes on `main`.

## Known limitations and next actions

**Known limitations**: none for Batch D itself. The
soft-deprecated `gllvmTMB_wide()` function remains in the
0.2.0 NAMESPACE for backward compatibility; Phase 2's export
audit will decide whether to escalate the deprecation
(`lifecycle::deprecate_warn()` for 0.3.0) or keep as-is.

**Next actions**:

1. PR #94 (Batch B) is in CI; await maintainer approval to
   merge once green.
2. After Batch D merges: open **Phase 1a Batch E** --
   `\mathbf{U}` → `\boldsymbol{\Psi}` in
   `vignettes/articles/behavioural-syndromes.Rmd` math +
   roxygen-only sweep of `R/extract-two-U-via-PIC.R`
   returned-list docs (function names stay per the PR #40
   task-label retention rule).
3. After Batch E merges: Phase 1a closes; open **Phase 1b**.
   First Phase 1b PR carries the **`mu_t` Beta/betabinom
   clamp** (Gauss's pulled-forward polish) + the
   `extract_correlations(link_residual = "auto")` default
   change with `lifecycle::deprecate_soft("0.3.0", ...)` per
   Emmy's recommendation. The
   `n_sim` argument-naming convention should be set in this
   first Phase 1b PR so subsequent ones (`check_identifiability`,
   `bootstrap_Sigma`) inherit a consistent name.
