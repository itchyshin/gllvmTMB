# After Task: JSDM Screening Scope Polish

**Branch**: `codex/jsdm-screen-polish-20260623`
**Date**: `2026-06-23`
**Roles (engaged)**: `Ada / Curie / Jason / Pat / Rose / Shannon / Boole / Grace`

## 1. Goal

Clarify the public response-screening story after PR #537: `screen_gllvmTMB()`
should help users inspect binary/binomial candidate responses before fitting a
stacked-trait GLLVM, especially in JSDM-like presence-absence settings, without
turning rare species into automatic deletion targets. The companion goal was to
add explicit `MIS-34` scope wording to the fixed-effect zero-constraint article
now that #537 has merged.

## 2. Implemented

- Added `DIA-14` scope wording to the pre-fit response-screening article:
  binary/binomial screening is implemented; non-binary modules, optional
  `detectseparation` / `mirt` comparators, and high-dimensional benchmarks
  remain planned.
- Added binary JSDM framing: the systematic-map `review` unit can be read as a
  site, plot, survey, or other sampling unit, and each indicator can be read as
  a species presence-absence response.
- Rewrote the `FAIL` guidance so exact duplicate/complement responses lead to
  coding, taxonomy, sampling-design, and scientific-role checks plus possible
  sensitivity fits, not automatic species removal.
- Added literature-backed rare-species wording: sparse species are sometimes
  filtered in applied JSDM/HMSC analyses, but those thresholds are documented
  analysis choices; rare species can also be a reason to use a joint model.
- Kept `suppressWarnings()` in the article/example because the current wide
  call emits the ordinary one-shot `latent()` Psi-default warning; the prose now
  explains the wrapper is only for article readability.
- Mirrored the advisory-only scope in `R/screen-gllvmTMB.R` roxygen and
  regenerated `man/screen_gllvmTMB.Rd`.
- Added `MIS-34` IN / gated wording to
  `vignettes/articles/fixed-effect-zero-constraints.Rmd`, keeping it framed as
  trait-specific mean-structure control rather than screening, response
  deletion, variable selection, loading constraints, or rank selection.
- Prepared, but did not post, a draft response for `@Ayumi-495`.

## 3. Files Changed

Documentation and articles:

- `vignettes/articles/pre-fit-response-screening.Rmd`
- `vignettes/articles/fixed-effect-zero-constraints.Rmd`

Roxygen and generated help:

- `R/screen-gllvmTMB.R`
- `man/screen_gllvmTMB.Rd`

Developer records:

- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-23-jsdm-screening-scope-polish.md`
- `docs/dev-log/spikes/2026-06-23-ayumi-jsdm-screening-draft.md`

## 3a. Decisions and Rejected Alternatives

Decision: keep `suppressWarnings()` in the rendered examples.
Rationale: the wide article call emits the current ordinary-`latent()` Psi
warning; hiding it in the article keeps the output readable, while the prose
now tells interactive users to read warnings and inspect recommendations.
Rejected alternative: remove the wrapper and let the article show the warning.
Confidence: high for this docs-only slice.

Decision: describe rare species as inspection and sensitivity-analysis cases.
Rationale: JSDM literature includes documented prevalence filtering, but rare
species are also a motivation for joint modelling and information sharing.
Rejected alternative: recommend automatic removal below a fixed prevalence
threshold. Confidence: high.

Decision: do not add `quiet = TRUE/FALSE` or change the screen API.
Rationale: the plan explicitly scoped this as prose and documentation polish,
with no behavior/API change. Confidence: high.

## 4. Checks Run

- `gh pr view 537 --repo itchyshin/gllvmTMB --json number,state,mergeCommit,url,title`
  -> PASS; #537 is merged at `e2b94409dca50a268aab582bffa9f350178aadc9`.
- `git worktree add -b codex/jsdm-screen-polish-20260623 /private/tmp/gllvmtmb-jsdm-screen-polish-20260623 origin/main`
  -> PASS; fresh worktree created from updated `origin/main`.
- `git status --short --branch`
  -> PASS before edits; clean branch.
- `gh pr list --repo itchyshin/gllvmTMB --state open --json number,title,headRefName,isDraft,author,updatedAt`
  -> PASS; no open gllvmTMB PRs after #537 merge.
- `git log --all --oneline --since="6 hours ago"`
  -> PASS; no same-file collision detected.
- `gh issue list --repo Ayumi-495/urbanisation_map --state open --limit 20 --json number,title,url,updatedAt`
  -> PASS; inspected issues #3 and #1 for the draft note.
- `Rscript --vanilla -e 'devtools::document(quiet = TRUE)'`
  -> PASS; regenerated `man/screen_gllvmTMB.Rd`; unrelated Rd churn was excluded.
- `tail -5 man/screen_gllvmTMB.Rd`
  -> PASS; generated help ends in the expected references block.
- `grep -c '^\\keyword' man/screen_gllvmTMB.Rd`
  -> PASS; returned `0`, so no misplaced roxygen keyword spillover.
- `LC_ALL=C rg -n "[^\x00-\x7F]" R/screen-gllvmTMB.R man/screen_gllvmTMB.Rd vignettes/articles/pre-fit-response-screening.Rmd vignettes/articles/fixed-effect-zero-constraints.Rmd docs/dev-log/spikes/2026-06-23-ayumi-jsdm-screening-draft.md`
  -> PASS; no non-ASCII hits.
- `Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); pkgdown::build_article("articles/pre-fit-response-screening", lazy = FALSE, new_process = FALSE)'`
  -> PASS.
- `Rscript --vanilla -e 'pkgdown::clean_site(force = TRUE); devtools::load_all(quiet = TRUE); pkgdown::build_article("articles/pre-fit-response-screening", lazy = FALSE, new_process = FALSE); pkgdown::build_article("articles/fixed-effect-zero-constraints", lazy = FALSE, new_process = FALSE)'`
  -> PASS; both touched articles rendered sequentially.
- `Rscript --vanilla -e 'devtools::test(filter = "screen-gllvmTMB|xcoef-fixed|julia-bridge")'`
  -> PASS with existing warning: `FAIL 0 | WARN 1 | SKIP 16 | PASS 454`.
- `git diff --check`
  -> PASS.
- `rg -n "DIA-14|MIS-34" NEWS.md vignettes/articles/pre-fit-response-screening.Rmd vignettes/articles/fixed-effect-zero-constraints.Rmd docs/design/35-validation-debt-register.md`
  -> PASS; intended row references found.
- `rg -n "automatic deletion|remove species|guarantees convergence|proves identifiability|selects variables|gllvmTMB_wide|meta_known_V|trio|diag\\(U\\)|\\\\bf S|S_B|S_W" vignettes/articles/pre-fit-response-screening.Rmd vignettes/articles/fixed-effect-zero-constraints.Rmd R/screen-gllvmTMB.R man/screen_gllvmTMB.Rd docs/dev-log/spikes/2026-06-23-ayumi-jsdm-screening-draft.md _pkgdown.yml`
  -> PASS; no stale-overclaim hits.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> PASS: `No problems found.`
- Rose pre-publish audit commands:
  - `rg -n "Scope boundary|DIA-14|MIS-34|IN|PARTIAL|PLANNED|gated" vignettes/articles/pre-fit-response-screening.Rmd vignettes/articles/fixed-effect-zero-constraints.Rmd R/screen-gllvmTMB.R man/screen_gllvmTMB.Rd`
    -> PASS.
  - `rg -n "gllvmTMB\\(|screen_gllvmTMB\\(" vignettes/articles/pre-fit-response-screening.Rmd vignettes/articles/fixed-effect-zero-constraints.Rmd R/screen-gllvmTMB.R man/screen_gllvmTMB.Rd`
    -> PASS; wide/long example forms are consistent.
  - `rg -n "trio|phylo\\(|gr\\(|meta\\(|block_V\\(|phylo_rr\\(|profile-likelihood default|diag\\(U\\)|U_phy|U_non|\\\\bf S|S_B|S_W|gllvmTMB_wide|meta_known_V|automatic deletion|response deletion|selects variables|guarantees convergence|proves identifiability" vignettes/articles/pre-fit-response-screening.Rmd vignettes/articles/fixed-effect-zero-constraints.Rmd R/screen-gllvmTMB.R man/screen_gllvmTMB.Rd`
    -> PASS with one intended negative-scope hit: the fixed-effect article says
    the feature is "not ... response deletion".
  - `Rscript --vanilla -e 'print(names(formals(gllvmTMB::screen_gllvmTMB))); print("Xcoef_fixed" %in% names(formals(gllvmTMB::gllvmTMB)))'`
    -> PASS.
- `Rscript --vanilla -e 'pkgdown::build_articles(lazy = FALSE)'`
  -> first run failed because an older installed `gllvmTMB` lacked
  `Xcoef_fixed`; after `devtools::install(quick = TRUE, upgrade = "never",
  quiet = TRUE)`, the rerun progressed past the touched fixed-effect article
  but was manually interrupted after a long unrelated `lambda-constraint.Rmd`
  render. Targeted article renders are the claimed render evidence.

## 5. Tests of the Tests

No new tests were added because this was a docs/prose-only slice with no
behavior or API change. The focused regression command included the existing
screening tests plus the fixed-zero and Julia-bridge tests touched by the newly
merged base, and the stale scans targeted the specific overclaim risks named in
the council plan.

## 6. Consistency Audit

- `DIA-14|MIS-34` scan: PASS; touched public prose references the relevant
  validation rows.
- Stale-overclaim scan: PASS; no hits for automatic deletion, remove-species
  wording, convergence/identifiability guarantees, variable selection,
  `gllvmTMB_wide`, `meta_known_V`, or stale `U/S` notation.
- ASCII scan: PASS; all touched files are ASCII.

## 7. Roadmap Tick

N/A. This slice did not change roadmap status; it clarified already registered
rows `DIA-14` and `MIS-34`.

## 7a. GitHub Issue Ledger

Inspected Ayumi issue context:

- https://github.com/Ayumi-495/urbanisation_map/issues/3
- https://github.com/Ayumi-495/urbanisation_map/issues/1

No GitHub comment was posted. The draft is in
`docs/dev-log/spikes/2026-06-23-ayumi-jsdm-screening-draft.md` for Shinichi
review.

## 8. What Did Not Go Smoothly

Two pkgdown wrinkles showed up. First, parallel article renders collided in the
ignored `pkgdown-site/` output folder, so the touched articles were rerun
sequentially. Second, the broad `pkgdown::build_articles(lazy = FALSE)` command
initially used an older installed `gllvmTMB` without `Xcoef_fixed`; installing
the current source fixed that, but the broad rerun then spent a long time in an
unrelated `lambda-constraint.Rmd` render and was manually interrupted. The
touched articles themselves rendered cleanly.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

Curie and Jason agreed that rare-species filtering exists in JSDM/HMSC practice
but is a documented modelling or computational choice, not a default package
rule. They also emphasised that rare species can motivate joint modelling
because shared structure can borrow strength.

Pat wanted the article to translate systematic-map language into JSDM language.
That became the explicit mapping from `review` to site/plot/survey/unit and
from indicator column to species presence-absence response.

Rose and Shannon kept the process boundary tight: merge #537 first, work in a
fresh `/private/tmp` worktree, cite `DIA-14`, and avoid editing the old #537
branch or Dropbox mission-control checkout.

Boole and Grace kept the polish scoped: no function API changes, no `quiet`
argument, no new pkgdown nav restructuring, and no unsupported claims about
non-binary screening or Julia screening parity.

## 10. Known Limitations And Next Actions

`screen_gllvmTMB()` remains binary/binomial-only pre-fit screening under
`DIA-14`. Non-binary modules, optional `detectseparation` / `mirt` comparators,
high-dimensional systematic-map benchmarks, and Julia parity remain planned
separate slices. The Ayumi draft should be reviewed by Shinichi before posting.
