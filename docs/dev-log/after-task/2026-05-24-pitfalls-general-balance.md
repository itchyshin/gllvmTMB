# After Task: Pitfalls Article Balanced Framing

**Branch**: `codex/pitfalls-general-balance-2026-05-24`
**Date**: `2026-05-24`
**Roles (engaged)**: `Ada / Pat / Rose / Grace`

## 1. Goal

Revise the public `pitfalls` article so it teaches general
troubleshooting principles, with the current latent, phylogenetic, and
animal examples serving as examples rather than as the whole point.

## 2. Implemented

- Rewrote the opening to frame the page as seven checks for data
  coding, estimand targets, formula alignment, identifiability,
  grouping columns, and matrix meaning.
- Reworded each heading toward a general diagnostic principle.
- Kept the executable long-format examples, but added language that
  the same checks apply to equivalent wide `traits(...)` calls.
- Replaced `WRONG` / `RIGHT` code comments with `MISMATCHED` /
  `MATCHED`.
- Reframed the phylogenetic section as one identifiability example:
  fully paired, scalar, and three-piece forms now depend on the target
  and design rather than reading as a special-purpose recipe.

## 3. Files Changed

- `vignettes/articles/pitfalls.Rmd`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-05-24-pitfalls-general-balance.md`

No generated Rd, R source, tests, README, NEWS, ROADMAP, or
`_pkgdown.yml` file changed.

## 3a. Decisions and Rejected Alternatives

Decision: keep `pitfalls` as a public troubleshooting article, but make
the examples illustrative rather than model-defining.

Rationale: the article should help applied readers diagnose the class
of mistake before choosing a specific covariance keyword.

Rejected alternative: add new wide-format companion chunks for every
example. That would broaden the slice and duplicate Get Started's
long/wide equivalence role; this follow-up only fixes balance and
framing.

Confidence: high for the prose/framing change.

## 4. Checks Run

- `gh run watch 26359136575 --repo itchyshin/gllvmTMB --interval 15 --exit-status`
  -> post-merge main R-CMD-check for the previous pitfalls PR passed
  on `macos-latest`, `ubuntu-latest`, and `windows-latest`.
- `gh run watch 26359874362 --repo itchyshin/gllvmTMB --interval 15 --exit-status`
  -> post-merge main pkgdown for the previous pitfalls PR passed.
- `gh pr list --repo itchyshin/gllvmTMB --state open --json number,title,headRefName,baseRefName,author,updatedAt,url`
  -> `[]`.
- `git log --all --oneline --since="6 hours ago"`
  -> no competing open lane was detected.
- `git pull --ff-only`
  -> `Already up to date.`
- `git diff --check`
  -> clean.
- `Rscript --vanilla -e 'devtools::install(quick = TRUE, dependencies = FALSE, build_vignettes = FALSE, quiet = TRUE); pkgdown::build_article("articles/pitfalls", quiet = FALSE, new_process = FALSE)'`
  -> completed; `Output created: pkgdown-site/articles/pitfalls.html`.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> `No problems found.`
- `rg -n "general diagnostic|particular example model|not a special rule|fully paired|MISMATCHED|MATCHED|n_species around 100|functional-biogeography|nonsense|WRONG|RIGHT|canonical paired" vignettes/articles/pitfalls.Rmd pkgdown-site/articles/pitfalls.html`
  -> source and rendered HTML contain the intended general-framing
  language; removed over-specific terms had no matches.
- `rg -n "Scope boundary|FG-02|FG-03|FAM-01|EXT-01|EXT-14|EXT-15|LAM-04|PHY-02|PHY-03|PHY-04|PHY-07|ANI-01|ANI-07|ANI-08|MET-01|MET-03" vignettes/articles/pitfalls.Rmd pkgdown-site/articles/pitfalls.html`
  -> source and rendered HTML retain the scope boundary and row IDs.
- `rg -n "Confidence-I|confidence-I|randrop|diag\\(U\\)|U_phy|U_non|\\\\bf S|\\bS_B\\b|\\bS_W\\b|removed in 0\\.2\\.0|profile-likelihood default|meta_known_V as primary|gllvmTMB_wide\\(Y|already removed|primary new-user API|\\bphylo\\(|\\bgr\\(|\\bmeta\\(|phylo_rr\\(|\\bscalar\\(" vignettes/articles/pitfalls.Rmd`
  -> no matches.
- `rg -n "FG-02|FG-03|FG-04|FG-05|FG-06|FAM-01|EXT-01|EXT-14|EXT-15|LAM-04|PHY-02|PHY-03|PHY-04|PHY-07|ANI-01|ANI-07|ANI-08|MET-01|MET-03" docs/design/35-validation-debt-register.md`
  -> all cited row IDs exist with expected covered, partial, or
  blocked statuses.
- `gh issue list --repo itchyshin/gllvmTMB --state open --search "pitfalls OR scope boundary OR article surface reset OR validation-debt" --json number,title,url,labels,updatedAt --limit 20`
  -> found relevant #230; #228 is diagnostics-related and not touched.

## 5. Tests of the Tests

No tests were added or modified. This is an article-only framing
change; the touched article render exercises the existing examples.

## 6. Consistency Audit

- Validation row audit: the scope-boundary row IDs remained present in
  source and rendered HTML.
- Public-prose audit: removed over-specific phrases (`n_species around
  100`, `functional-biogeography`, `nonsense`, `canonical paired`,
  `WRONG`, `RIGHT`) are absent.
- Long/wide discipline: the article still uses long-format examples
  with explicit `trait = "trait"` and points to Get Started for the
  wide `traits(...)` equivalence.
- Stale terminology audit: no matches for obsolete notation,
  deprecated keyword aliases as primary syntax, misspelled `randrop`,
  or unsupported `gllvmTMB_wide()` claims in the touched article.

## 7. Roadmap Tick

N/A. This PR does not change a ROADMAP row or milestone status.

## 7a. GitHub Issue Ledger

- #230, `Article surface reset and user-first tooling gate`, remains
  the relevant tracking issue. This PR advances the balanced article
  framing part of that issue but does not close it.
- #228 was returned by the search but is not relevant; no diagnostic
  prototype API changed.
- No new issue created.

## 8. What Did Not Go Smoothly

The first scope-boundary pass made the article safer but still left
some sections reading as model-specific notes. The follow-up corrected
the article's teaching stance without adding new examples or changing
API claims.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

Ada kept the follow-up narrow and waited for the previous main
R-CMD-check and pkgdown runs to finish before branching.

Pat's reader pass required the article to teach the mistake class
first, then the example model.

Rose checked that the scope-boundary row IDs remained intact and that
removed over-specific wording stayed absent in source and rendered
HTML.

Grace checked the deploy-facing path with a touched-article render and
`pkgdown::check_pkgdown()`.

## 10. Known Limitations And Next Actions

- The article still intentionally uses long-format examples only; Get
  Started remains the long/wide equivalence article.
- The under-audit phylogenetic, animal-model, vocabulary, and
  functional-biogeography pages remain separate restoration work.
- A browser screenshot was not taken; validation used local pkgdown
  render plus source/rendered scans.
