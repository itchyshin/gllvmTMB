# After Task: Pitfalls Article Scope Boundary

**Branch**: `codex/pitfalls-boundary-2026-05-24`
**Date**: `2026-05-24`
**Roles (engaged)**: `Ada / Pat / Rose / Grace`

## 1. Goal

Tighten the public `pitfalls` article so each advertised capability is
bounded by validation-debt row IDs, and remove one unanchored numerical
recovery claim from the public troubleshooting path.

## 2. Implemented

- Added a scope-boundary block to `vignettes/articles/pitfalls.Rmd`.
  It marks the covered long/wide syntax, Gaussian covariance examples,
  extractor, loading, phylogenetic, and animal-relatedness paths as IN.
- Marked `phylo_scalar()` and exact single-V `meta_V(V = V)` as PARTIAL
  caveats rather than full workflow recommendations.
- Marked proportional known-V mode as PLANNED/BLOCKED via `MET-03`.
- Reworded the long/wide framing sentence and removed the public
  `~10%` phylogenetic recovery claim, replacing it with the narrower
  `PHY-03` validation boundary.

## 3. Files Changed

- `vignettes/articles/pitfalls.Rmd`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-05-24-pitfalls-boundary.md`

No generated Rd, R source, tests, README, NEWS, ROADMAP, or
`_pkgdown.yml` file changed.

## 3a. Decisions and Rejected Alternatives

Decision: treat `pitfalls` as a visible troubleshooting reference, not
as a new capability surface.

Rationale: the article already sits in the public Methods section and
is useful for applied users, but it needs the same validation-boundary
discipline as the other visible articles.

Rejected alternative: restore a larger phylogenetic worked example in
this PR. That would touch under-audit article scope and require a
separate rendered-reader review.

Confidence: high for the narrow prose/status change.

## 4. Checks Run

- `gh pr list --repo itchyshin/gllvmTMB --state open --json number,title,headRefName,baseRefName,mergeStateStatus,updatedAt,url`
  -> `[]`.
- `git log --all --oneline --since="6 hours ago"`
  -> recent commits were the merged keyword-grid PR #244,
  response-families PR #243, covariance article PR #242, Get Started
  PR #241, and their source-branch commits; no competing open lane was
  detected.
- `gh run list --repo itchyshin/gllvmTMB --limit 8 --json databaseId,displayTitle,workflowName,status,conclusion,headBranch,headSha,url,event`
  -> latest `R-CMD-check` and `pkgdown` runs on main commit `4908fc3`
  were completed successfully.
- `Rscript --vanilla -e 'devtools::install(quick = TRUE, dependencies = FALSE, build_vignettes = FALSE, quiet = TRUE); pkgdown::build_article("articles/pitfalls", quiet = FALSE, new_process = FALSE)'`
  -> completed; `Output created: pkgdown-site/articles/pitfalls.html`.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> `No problems found.`
- `rg -n "Scope boundary|FG-02|FG-03|FAM-01|EXT-01|EXT-14|EXT-15|LAM-04|PHY-02|PHY-03|PHY-04|PHY-07|ANI-01|ANI-07|ANI-08|MET-01|MET-03|proportional known-V|current workflow|functional-biogeography" vignettes/articles/pitfalls.Rmd pkgdown-site/articles/pitfalls.html`
  -> source and rendered HTML contain the scope boundary and row IDs.
- `rg -n "bar-style|sigma\\^2_Q|\\\\sim\\$10|~10|recovers within|functional-biogeography capstone will walk through" vignettes/articles/pitfalls.Rmd pkgdown-site/articles/pitfalls.html`
  -> no matches.
- `rg -n "gllvmTMB\\(|traits\\(|trait =" vignettes/articles/pitfalls.Rmd pkgdown-site/articles/pitfalls.html`
  -> long-format examples pass `trait =`; the article references the
  wide `traits(...)` path but does not add a wide example.
- `rg -n "Confidence-I|confidence-I|randrop|diag\\(U\\)|U_phy|U_non|\\\\bf S|\\bS_B\\b|\\bS_W\\b|removed in 0\\.2\\.0|profile-likelihood default|meta_known_V as primary|gllvmTMB_wide\\(Y|already removed|primary new-user API|\\bphylo\\(|\\bgr\\(|\\bmeta\\(|phylo_rr\\(|\\bscalar\\(" vignettes/articles/pitfalls.Rmd`
  -> no matches.
- `rg -n "FG-02|FG-03|FG-04|FG-05|FG-06|FAM-01|EXT-01|EXT-14|EXT-15|LAM-04|PHY-02|PHY-03|PHY-04|PHY-07|ANI-01|ANI-07|ANI-08|MET-01|MET-03" docs/design/35-validation-debt-register.md`
  -> all cited row IDs exist with expected covered, partial, or
  blocked statuses.
- `gh issue list --repo itchyshin/gllvmTMB --state open --search "pitfalls OR scope boundary OR article surface reset OR validation-debt" --json number,title,url,labels,updatedAt --limit 20`
  -> found relevant #230; #228 is diagnostics-related and not touched
  by this PR.
- `git diff --check`
  -> clean.

## 5. Tests of the Tests

No tests were added or modified. This is an article-only
scope-boundary/prose change; the touched article render exercises the
existing examples.

## 6. Consistency Audit

- Validation row audit: all row IDs added to the public article were
  present in `docs/design/35-validation-debt-register.md`.
- Long-format syntax audit: every executable long-format
  `gllvmTMB()` example in the touched article passes `trait =`.
- Stale public-prose audit: no matches for obsolete notation,
  deprecated keyword aliases as primary syntax, misspelled
  `randrop`, or unsupported `gllvmTMB_wide()` claims in the touched
  article.
- Removed-claim audit: the old `bar-style` typo and the unanchored
  `~10%` phylogenetic recovery claim are absent from source and
  rendered HTML.

## 7. Roadmap Tick

N/A. This PR does not change a ROADMAP row or milestone status.

## 7a. GitHub Issue Ledger

- Inspected #230, `Article surface reset and user-first tooling gate`.
  This PR advances the visible-page validation-boundary part of that
  issue but does not close it.
- Inspected #228 from the same search results and judged it not
  relevant; this PR does not touch diagnostic prototype APIs.
- No new issue created.

## 8. What Did Not Go Smoothly

The article had one public numerical recovery sentence whose evidence
lived in internal testing/audit context rather than in the article
itself. The fix was to replace the number with a row-ID boundary
instead of trying to turn a troubleshooting page into a phylogenetic
simulation report.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

Ada kept the lane narrow: one visible article plus the required
ledger files, with no code, grammar, Rd, or navigation changes.

Pat's reader pass kept the article public because it answers concrete
"what went wrong?" questions, but required the top boundary so users
know which examples are recommendations and which are caveats.

Rose enforced the scope-boundary rule: covered, partial, and blocked
claims are traceable to validation-debt rows before PR closeout.

Grace checked the deploy-facing path by rendering the touched article
and running `pkgdown::check_pkgdown()` locally.

## 10. Known Limitations And Next Actions

- `pitfalls` still intentionally uses long-format examples only; it
  points readers to Get Started for long/wide equivalence.
- The under-audit phylogenetic, animal-model, vocabulary, and
  functional-biogeography pages remain separate restoration work.
- The next public-docs lane should continue from issue #230, preferably
  with rendered-browser review if browser tooling is available.
