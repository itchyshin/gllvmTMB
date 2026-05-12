# After-Task: NEWS.md CRAN-reviewer rewrite (Phase 5 prep)

## Goal

Rewrite the top section of `NEWS.md` for the CRAN-reviewer
audience, per the `2026-05-12-phase5-cran-readiness-pre-audit.md`
recommendation:

> First CRAN release needs a properly framed `# gllvmTMB 0.2.0
> (first CRAN release)` section that summarises the package for
> reviewers, not the rebuild story. Action at Phase 5 time:
> rewrite the top section to be CRAN-reviewer-facing rather than
> dev-log-facing.

The pre-rewrite file opened with internal jargon ("rebuilds
gllvmTMB from a clean repository, modelled on the drmTMB sister
package's regimented team and tooling") and led with the
NAMESPACE-trim diff against the legacy 0.1.x line. A CRAN
reviewer reading the file wants the package summary first, the
user-facing API second, the inherited-code attribution third,
and the bookkeeping last.

After-task report at branch start per `CONTRIBUTING.md`.

## Implemented

- **`NEWS.md`** (M, full rewrite of the `# gllvmTMB 0.2.0`
  section):
  - Version header gains the explicit `(first CRAN release)`
    tag per the audit's recommendation.
  - New one-paragraph opening summarising what `gllvmTMB` is
    (TMB engine for stacked-trait GLLVMs) and the scientific
    questions it addresses (shared latent covariance,
    ordination, communality, phylogenetic signal, spatial
    structure).
  - **User-facing API** section: two entry points (`gllvmTMB()`
    + `gllvmTMB_wide()`), 3 x 5 keyword grid table,
    `Sigma = Lambda Lambda^T + diag(s)` decomposition,
    per-trait family list, the no-covstruct error.
  - **Inference** section: ML / REML via Laplace,
    profile-likelihood / Fisher-z / Wald / bootstrap intervals.
  - **Phylogenetic and spatial paths** section: sparse `A^-1`
    representation, SPDE / GMRF mesh, attribution to `sdmTMB`
    helpers.
  - **Inherited code and citation** section: Authors@R
    rationale, `inst/COPYRIGHTS`, `inst/CITATION`, the CRAN
    "Writing R Extensions" §1.1.1 pattern reference.
  - **Source-tree notes** section: TMB engine compilation,
    DLL registration, `gllvmTMBcontrol()` independence.
  - **Relationship to the legacy 0.1.x line** section at the
    bottom: brief reframing of the rebuild story as a
    user-actionable note rather than a dev-log entry.
  - The long enumerated list of removed `sdmTMB` re-exports
    (`sdmTMB_cv()`, `dharma_residuals()`, `cv_to_waywiser()`,
    etc.) is dropped from CRAN-NEWS framing -- reviewers do
    not need each name; the principle ("does not re-export
    single-response sdmTMB paths") is captured by the legacy
    section.
  - The pkgdown article-tier discussion is dropped; pkgdown
    infrastructure is not CRAN-relevant.
  - The standalone "Bug fixes" subsection is folded into the
    flow because this is the first CRAN release and there is
    no prior CRAN version to bug-fix against.
- **`docs/dev-log/after-task/2026-05-12-news-cran-rewrite.md`**
  (NEW, this file).

## Mathematical Contract

No public R API, likelihood, formula grammar, family, NAMESPACE,
generated Rd, vignette, or pkgdown navigation change. `NEWS.md`
rewritten in place; the substantive technical claims
(`Sigma = Lambda Lambda^T + diag(s)`, 3 x 5 grid, family list)
are preserved verbatim.

## Files Changed

- `NEWS.md` (M)
- `docs/dev-log/after-task/2026-05-12-news-cran-rewrite.md`
  (new, this file)

## Checks Run

- Pre-edit lane check: 3 open Claude PRs (#47 skills refresh,
  #48 docs wording bundle, #49 methods-paper outline) + 1 Codex
  PR (#46 Tier-2 articles). None touch `NEWS.md`. Safe.
- Audit cross-reference: the rewrite follows the exact
  recommendation in
  `docs/dev-log/shannon-audits/2026-05-12-phase5-cran-readiness-pre-audit.md`
  lines 143-151.
- Notation spot-check: every math expression uses `s` / `S`,
  not `u` / `U`. `Sigma = Lambda Lambda^T + diag(s)` matches
  the README's canonical form (per the spot-check verdict on
  PR #46).
- API claims spot-check:
  - 3 x 5 grid table matches the README and
    `docs/design/02-data-shape-and-weights.md`.
  - Per-trait family list matches `family_to_id()` in
    `R/fit-multi.R`.
  - `extract_correlations(method = ...)` Fisher-z default is
    correct per the PR #39 revert.

## Tests Of The Tests

This is a documentation rewrite of a single file. The "test" is
whether a CRAN reviewer reading the file in isolation can:

1. Understand what the package does (one paragraph).
2. Find the main user-facing entry points (one section).
3. Find the inherited-code attribution and `inst/COPYRIGHTS`
   pointer (one section).
4. Find the relationship to the legacy line if they search for
   it (one section at the bottom).

If a reviewer cannot answer "what does `gllvmTMB` do?" from the
first paragraph, the rewrite did not succeed and needs another
pass.

If future API additions (random slopes, ZINB, barrier mesh,
two-U single-call) land before the CRAN submission window, the
"User-facing API" / "Inference" sections need a small update;
the structural shape of the rewritten file accommodates this
without further restructuring.

## Consistency Audit

```sh
rg -n "regimented|rebuild|legacy 133-export" NEWS.md
```

verdict: zero hits. The previous dev-log-facing wording is gone.

```sh
rg -n "Sigma = Lambda Lambda\\^T" NEWS.md
```

verdict: one hit, `Sigma = Lambda Lambda^T + diag(s)`. Matches
README.md canonical form.

```sh
rg -n "first CRAN release|inst/CITATION|inst/COPYRIGHTS" NEWS.md
```

verdict: each appears in the appropriate section -- the version
header carries the "(first CRAN release)" tag; `inst/CITATION`
and `inst/COPYRIGHTS` are named in the "Inherited code and
citation" section.

## What Did Not Go Smoothly

Nothing. The rewrite is a controlled prose refactor of a single
file; the substantive technical claims were preserved verbatim
while the framing was changed.

The hardest decision was where to file the "removed sdmTMB
re-exports" enumeration. A CRAN reviewer reading
`citation("gllvmTMB")` or `library(gllvmTMB)` would not see a
problem from the missing names; they would only notice if they
specifically tried to load the package and call (say)
`sdmTMB_simulate()` from a `library(gllvmTMB)` session. The
enumerated list is preserved in
`docs/dev-log/after-task/<earlier rebuild PR>.md` for archival
purposes; the user-facing principle ("install `sdmTMB` directly
for single-response work") is in the "Relationship to the
legacy 0.1.x line" section.

## Team Learning

By standing-review role per `AGENTS.md`:

- **Pat (applied user / CRAN reviewer)** -- the rewrite is for
  Pat's CRAN-reviewer role. A new reader should be able to
  answer "what does this package do" from the first paragraph
  and "should I install it" from the user-facing API section.
- **Rose (cross-file consistency)** -- the rewrite preserves
  exactly the technical claims that appear in README.md,
  `docs/design/02-data-shape-and-weights.md`, and
  `family_to_id()`. No new claim introduced.
- **Ada (orchestrator)** -- the rewrite executes the explicit
  Phase 5 pre-audit recommendation (audit lines 143-151).
- **Noether (math consistency)** -- the math notation matches
  README's canonical `diag(s)` form, not the alternative
  `+ S` form that drifted into `api-keyword-grid.Rmd:56` (PR
  #46 spot-check).

## Known Limitations

- This rewrite assumes the CRAN submission target version
  remains 0.2.0. If the team decides to do additional pre-CRAN
  point releases (0.2.1, 0.3.0) before the first CRAN
  submission, the "(first CRAN release)" tag should move to
  the version that actually ships.
- The "Inference" section names `profile_ci_*()`,
  `extract_correlations()`, and the four interval methods. If
  the Phase 5 `@examples` round demotes some `profile_ci_*()`
  helpers to `@keywords internal` (per the Shannon Phase 5
  pre-audit), this section may need a touch-up.
- The "Phylogenetic and spatial paths" section assumes the
  SPDE barrier path remains unimplemented at the CRAN
  submission window. If the barrier path lands first, this
  section needs to mention it.

## Next Actions

1. Maintainer reviews / merges. Self-merge eligible: documentation
   rewrite of a single dev-log file, no source / API / NAMESPACE
   change.
2. Future Phase 5 PRs (the `@examples` round, the
   `RUN_SLOW_TESTS` gating) do not touch `NEWS.md`; they should
   each add a single bullet to this file as they land.
3. At CRAN submission time, the final review pass should
   spot-check that:
   - The first paragraph still summarises the package correctly.
   - No claim in `NEWS.md` has been falsified by a subsequent
     code change.
   - The `inst/CITATION` / `inst/COPYRIGHTS` references still
     match the actual file contents.
