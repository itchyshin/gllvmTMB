# Codex Handover — Response-column coefficient foundation and next arc

Meta: 2026-08-26 · AUTHOR = Codex · TARGET = Codex · repository `itchyshin/gllvmTMB`

You are Codex, picking up the response-column coefficient programme in a fresh
session. This repository has many simultaneous lanes. Read `AGENTS.md`, the
active-lane split, and this document before editing. Classify every item as
`DONE`, `OWED`, `RETRACTED`, or `PROTECTED`, then execute only `OWED` work.

## Mission Control

| Repo | Branch / main | CI · what shipped | Plan by leverage |
| --- | --- | --- | --- |
| `itchyshin/gllvmTMB` | feature `codex/response-column-coef-arc1`; `origin/main` was `1bacee9a808b4106ce681502463baa317dcb9d9b` at final fetch | Arc 1 local parser/data tests and pkgdown metadata check green; no three-OS PR result yet. Released `*_slope()` programme and corrected article are already on main. | 1. monitor Arc 1 PR; 2. human merge only after green; 3. fresh Ultra Plan for IID `column_coef()` engine; 4. phylogenetic rho mixture; 5. remaining sources; 6. migration/deprecation arc and articles. |

## Critical Context

Arc 1 is deliberately a **fail-closed foundation**, not a fitted model family.
It adds exact keyed `column_data`, an internal top-level `shared()` marker, and
inert parsers for `column_coef()`, `phylo_coef()`, `animal_coef()`,
`kernel_coef()`, and `spatial_coef()`. Every valid coefficient marker stops at
`gllvmTMB_column_coef_engine_not_admitted` before TMB construction. No helper is
exported and no existing fit is rerouted.

The user has now clarified the intended migration direction: the released
`*_slope()` series may be soft-deprecated eventually, but it is **not deprecated
now**. Do not add lifecycle warnings until replacement engines exist and exact
fit-equivalence gates pass. Required migration identities are expected to be:

```r
slope(x | trait)                         -> column_coef(0 + x | trait)
phylo_slope(x | trait, ...)              -> phylo_coef(0 + x | trait, rho = 1, ...)
animal_slope(x | trait, ...)             -> animal_coef(0 + x | trait, rho = 1, ...)
kernel_slope(x | trait, ...)             -> kernel_coef(0 + x | trait, rho = 1, ...)
spatial_slope(x | trait, ...)            -> spatial_coef(0 + x | trait, rho = 1, ...)
```

These are **proposed equivalence targets**, not yet proved public claims. The
future deprecation arc must demonstrate fitted-object and numerical equivalence,
preserve existing fits throughout the lifecycle period, and provide migration
messages before changing article teaching syntax.

## Goals and Plan

The durable goal is a coherent response-column random-coefficient family in
which coefficient bases may contain intercepts and/or slopes, while source
structure is explicit and fixed effects remain available through ordinary
formula interactions and keyed column metadata.

The leverage-ordered programme is:

1. land Arc 1 unchanged except for attributable CI fixes;
2. implement the IID `column_coef()` engine as the reference coefficient block;
3. add `phylo_coef()` with fixed/estimated rho under Design 131;
4. extend the proven engine to animal, kernel, then spatial sources;
5. add public long/wide teaching, extractor and interval gates at their earned
   scope; and
6. only then run the `*_slope()` soft-deprecation/migration arc.

Do not implement all five engines in one PR. Do not let article repair absorb
likelihood work, or let coefficient work absorb the independent random-slope,
MSPL, interval, iSDM, release, or dirty article lanes.

## What Was Accomplished

- Design 131 froze coefficient ordering, the raw-scale-preserving rho mixture,
  metadata alignment, shared fixed effects, overlap rules, and explicit
  deferrals.
- `column_data` was added as the last `gllvmTMB()` formal to preserve positional
  calls. Long input keys on the resolved trait column; wide `traits(...)` input
  keys on literal `trait` and rejects a custom `trait =` value.
- Metadata are fixed-effect-only and cannot overwrite `.y_wide_`,
  `.offset_wide_`, `.multinom_group_`, or `.multinom_L_`.
- Internal `shared()` and every `*_coef()` marker must be top-level additive
  terms; user-defined functions named `shared` retain their ordinary meaning.
- The parser records explicit bases `1`, `0 + x`, and `1 + x`; distinguishes
  `|` from `||`; validates helper/source identity, source count, rho intent, and
  rank overlap; then stops before engine construction.
- Independent review found and closed carrier overwrite, metadata covariance,
  nested marker, formula-environment rho, custom wide-key, and user-defined
  `shared()` defects.
- The after-task report, canonical grammar, validation row FG-20, exact check
  log, and Arc 2 handover are committed.

## Current Working State

- **Working:** clean feature branch with four reviewed implementation/test/docs
  commits plus this handover commit; focused foundation, `traits()`, and released
  slope regressions pass.
- **In progress:** PR publication and terminal three-OS CI. The human, not Codex,
  decides merge.
- **Not working / blocked:** `pkgdown::build_articles(lazy = FALSE)` reaches the
  unchanged `where-does-the-tree-go.Rmd` and fails because
  `extract_Sigma(..., level = "column_slope")` is not supported. Source was
  byte-identical to Arc 1 baseline. Treat this as an independent article repair
  lane unless current main or CI proves otherwise.
- **No compute:** no simulation or recovery campaign was appropriate because no
  coefficient likelihood exists. Heavy campaign approval was neither requested
  nor implied.

## Key Decisions and Rationale

1. **Coefficient design is not a rename of slope design.** Future
   `phylo_coef()` needs a coefficient block and rho mixture; released
   `phylo_slope()` uses the supplied structure directly and is slope-only.
2. **IID first.** `column_coef()` is the smallest engine and becomes the oracle
   for ordering, extractors, recovery, and fixed/random overlap before adding a
   structured source.
3. **No premature deprecation.** A warning without a working replacement breaks
   users and violates the preserve-existing-fits contract.
4. **Articles follow earned capability.** Repair the currently invalid article
   call separately. Teach `*_coef()` only after engine, recovery, help, and CI
   gates pass. The 5 x 3 article must present coefficients as a separate family,
   not a fourth covariance mode.
5. **Multi-lane pointer remains canonical.** `AGENTS.md` continues to point to
   the active-lane split; this handover is one additional lane, not the whole
   project.

## Landing State

| Artifact / branch | Committed | Pushed | PR | State |
| --- | --- | --- | --- | --- |
| `codex/response-column-coef-arc1`; reviewed implementation/closure anchor `60ba61dc` plus the commit containing this handover | yes | yes | open; resolve the exact remote tip and PR with `gh pr view codex/response-column-coef-arc1 --repo itchyshin/gllvmTMB --json number,url,state,headRefOid` | CARRIED-OVER pending human merge |
| dirty checkout `/Users/z3437171/.codex/worktrees/0733/gllvmTMB` on `codex/column-slope-family` | foreign/pre-existing changes | remote branch gone | none | PROTECTED; do not stage, reset, or absorb |
| all rows in `docs/dev-log/handover/2026-07-25-active-lane-split.md` | mixed | mixed | mixed | PROTECTED unless explicitly assigned |

**CARRIED-OVER reason:** Arc 1 requires terminal PR CI and human merge. Resume
from the pushed branch using the one-command recipe below.

**FINDINGS-OF-RECORD: none.** The coefficient contract is implementation/design
state recorded in repository Design 131 and the after-task report, not a new
external scientific finding held only on an unmerged branch.

## Files Created / Modified

Relative to `origin/main` at `1bacee9a808b4106ce681502463baa317dcb9d9b`:

- `AGENTS.md`
- `R/column-coef-foundation.R`
- `R/gllvmTMB.R`
- `R/traits-keyword.R`
- `man/gllvmTMB.Rd`
- `tests/testthat/test-column-coef-foundation.R`
- `docs/design/01-formula-grammar.md`
- `docs/design/131-response-column-coefficient-foundation.md`
- `docs/design/35-validation-debt-register.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-08-26-response-column-coefficient-foundation.md`
- `docs/dev-log/handover/2026-07-25-active-lane-split.md`
- `docs/dev-log/handover/2026-08-26-response-column-coefficient-arc2.md`
- `docs/dev-log/handover/2026-08-26-codex-handover.md`

Never stage the seven pre-existing modified/untracked files in the protected
`0733` checkout. No `src/`, `NAMESPACE`, `_pkgdown.yml`, README, NEWS, public
article, or coefficient-helper reference topic belongs to Arc 1.

## Verification Evidence

Fresh post-commit/local evidence before this handover:

```sh
Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); testthat::test_dir("tests/testthat", filter = "^(column-coef-foundation|traits-keyword|fixed-column-slope-family)$", reporter = "summary", stop_on_failure = TRUE)'
# PASS; two pre-existing CRAN skips.

Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); testthat::test_dir("tests/testthat", filter = "^(phylo-slope-rhs-routing|ordinary-column-slope-phylo-coexistence|spatial-column-slope|animal-slope-recovery|phylo-column-slope-indep)$", reporter = "summary", stop_on_failure = TRUE)'
# PASS; six existing heavy-test skips and existing unused-cluster warnings.

Rscript --vanilla -e 'devtools::document(quiet = TRUE)'
# PASS; regenerated man/gllvmTMB.Rd; three pre-existing S3 export reminders.

Rscript --vanilla -e 'pkgdown::check_pkgdown()'
# PASS: No problems found.

Rscript --vanilla '/Users/z3437171/Dropbox/Github Local/Shinichi/tools/check-after-task.R' docs/dev-log/after-task/2026-08-26-response-column-coefficient-foundation.md
# PASS.

git diff --check
# PASS.
```

The full test suite and `R CMD check` are not claimed. A full `devtools::test()`
was stopped after review found boundary defects; repaired focused suites were
then rerun. The full article build has the baseline failure described above.

## Next Immediate Steps

1. Run lane preflight and reconcile this dated handover with live Git/PR state.
2. Classify the Arc 1 PR and checks as `DONE` or `OWED`. If CI is active, wait.
   If it fails, diagnose systematically and change only failures attributable
   to Arc 1; do not use CI as a reason to absorb the article or another lane.
3. Ask Rose to inspect final PR head, closure prose, branch cleanliness, and
   cross-file consistency. Verify macOS, Ubuntu, and Windows terminal green.
4. Leave the PR unmerged. Report the URL and exact terminal state to Shinichi;
   he merges.
5. After merge, start a **fresh Ultra Plan**, not implementation by inference,
   for the IID `column_coef()` engine. Use symbolic alignment and TDD; estimate
   any simulation before running it.
6. Keep the article repair separate. Once `column_coef()` is truly fitted and
   recovered, plan the reader update: corrected phylogeny article, 5 x 3
   boundary note, dedicated coefficient article with long/wide data visuals,
   roxygen/Rd, NEWS, and pkgdown navigation.

## Blockers / Open Questions

- PR number and terminal CI are resolved live after publication; do not infer
  them from this dated file.
- Decide in the next Ultra Plan whether Arc 2 ships only IID `column_coef()` or
  a stacked follow-up PR for `phylo_coef()`. Recommendation: IID only first.
- `screen_gllvmTMB()` does not yet propagate `column_data`; Arc 2 must decide
  explicitly whether parity is required before public export.
- Malformed tree, pedigree, kernel, and mesh objects are not Arc 1 evidence.
- The proposed slope-to-coef migration identities require exact tests before
  being documented as replacements.

## Gotchas and Failed Approaches

- The active `0733` checkout contains seven pre-existing article/bridge files.
  Never use broad staging or destructive cleanup there.
- GitHub API calls failed in the sandbox and succeeded only with normal network
  escalation. Do not restart authentication or run `gh auth login`.
- The local unlazy Node checker was unavailable; the acceptance ledger was
  manually verified with exact commands and recorded in the after-task report.
- A generic `shared()` rewrite captured user functions until the formula
  environment guard was added.
- Metadata initially could overwrite internal wide carriers and enter
  covariance terms; both are now classed failures with tests.
- Do not claim malformed source-object validation merely because helper/source
  identity and source-count parsing pass.
- Pushing repeated fixups while CI runs creates cancellation cascades. Batch a
  complete attributable fix, wait for active CI, then push once.

## Codex Live-Toolchain Rehydration

This Mac currently resolves:

```sh
export PATH="/opt/local/bin:/opt/local/sbin:/opt/homebrew/bin:/opt/homebrew/sbin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export R_LIBS_USER="/Users/z3437171/Library/R/arm64/4.6/library"
export NOT_CRAN=true
unset GLLVMTMB_HEAVY_TESTS

command -v R Rscript
R RHOME
R CMD config CC       # clang -arch arm64
R CMD config CXX17    # clang++ -arch arm64
```

Codex owns live R/TMB compilation, focused fits, `R CMD check`, and article
rendering. Simulation/recovery campaigns use Totoro or DRAC, never GitHub
Actions, and require a stated estimate; campaigns over 30 minutes require a
pre-run test and approval.

Before a public-doc or exported-API push, run the project-required checks:

```sh
Rscript --vanilla -e 'devtools::document(quiet = TRUE)'
Rscript --vanilla -e 'pkgdown::check_pkgdown()'
Rscript --vanilla -e 'devtools::check(args = "--no-manual", quiet = TRUE)'
```

Do not rerun a broad local campaign merely to repeat Arc 1 evidence. Use a
targeted check after a rebase conflict or attributable CI failure.

## How to Resume

One command from Shinichi's authenticated terminal creates a clean clone of
the pushed lane and starts a fresh Codex session:

```sh
next=$(mktemp -d /private/tmp/gllvmTMB-coef-next.XXXXXX) && git clone --branch codex/response-column-coef-arc1 --single-branch git@github.com:itchyshin/gllvmTMB.git "$next" && codex -C "$next" "Rehydrate from docs/dev-log/handover/2026-08-26-codex-handover.md + the AGENTS.md snapshot, classify all items as OWED/DONE/RETRACTED/PROTECTED, then continue only the OWED Next Immediate Steps."
```

If Codex CLI is not on `PATH`, launch Codex normally in the cloned directory
and paste:

> Rehydrate from `docs/dev-log/handover/2026-08-26-codex-handover.md` + the
> `AGENTS.md` snapshot, classify all items as OWED/DONE/RETRACTED/PROTECTED,
> then continue only the OWED Next Immediate Steps.
