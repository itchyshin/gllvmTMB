# After-task: joint-SDM binary scope rewrite

**Date:** 2026-05-25
**Branch:** `codex/joint-sdm-scope-rewrite-2026-05-25`
**Spawned subagents:** none. Ada coordinated using standing review
perspectives.

## Task Goal

Make the hidden `joint-sdm` article more scope-honest before any
public restoration: soften unsupported binary `unique()`, `dep()`,
and `indep()` claims; add a narrow bridge to loading constraints; and
remove stale design wording that still described binary
`lambda_constraint` support as reserved.

## Mathematical Contract

No public R API, likelihood, formula grammar, family, NAMESPACE,
generated Rd, or pkgdown navigation change.

The article now keeps three targets separate:

- single-trial binary JSDM default:
  `latent(0 + trait | site, d = K)`;
- paired `latent + unique` for binary: diagnostic / development path,
  not public default, because RE-09 remains `partial`;
- confirmatory loading constraints:
  `lambda_constraint = list(B = M)`, where `NA` means free and numeric
  entries are pinned.

## Files Changed

- `vignettes/articles/joint-sdm.Rmd`
  - Rewrote the binary `unique()` subsection to cite RE-09 `partial`
    and remove hard claims based on boundary behaviour.
  - Rewrote the binary `dep()` / `indep()` subsection to cite FG-07 /
    FG-08 `partial` rather than treating a local comparison table as
    validation proof.
  - Added a short "Where loading constraints fit" subsection that
    points to LAM-03 / LAM-04 without making constraints the default
    species-distribution workflow.
- `docs/design/04-random-effects.md`
  - Updated stale status wording: Gaussian and binary IRT
    `lambda_constraint` / `suggest_lambda_constraint()` paths are now
    `covered` via LAM-01..LAM-04.
- `tests/testthat/test-joint-sdm-binary-long-wide.R`
  - Added a complete binary site x species fixture that avoids sparse
    absence-fill ambiguity and checks long-vs-wide likelihood equality.
- `docs/dev-log/audits/2026-05-25-joint-sdm-rendered-figure-qa.md`
  - Recorded rendered HTML and Florence-style figure blockers for
    `joint-sdm`.
- `docs/dev-log/audits/2026-05-25-r200-readiness-review.md`
  - Recorded the r200 scope recommendation and timeout/sharding blocker.
- `docs/dev-log/audits/2026-05-25-hidden-article-validation-map.md`
  - Mapped the hidden-article restoration queue to validation rows,
    evidence paths, missing fixtures, and next task types.

## Checks Run

- `git status --short --branch` -> clean `main` before branching.
- `git diff --stat` -> no local diff before branching.
- `gh pr list --repo itchyshin/gllvmTMB --state open --json number,title,headRefName,baseRefName,isDraft,updatedAt,url`
  -> open PRs #261, #265, #267.
- `git log --all --oneline --decorate --since='6 hours ago'`
  -> recent #261 / #265 / #267 stack plus main #266.
- `gh pr view 261 --repo itchyshin/gllvmTMB --json files,headRefName,title,url`
  -> #261 owns `ROADMAP.md`, `docs/dev-log/check-log.md`, and public
  diagnostic-teaching docs; no `joint-sdm.Rmd` / Design 04 overlap.
- `gh pr view 265 --repo itchyshin/gllvmTMB --json files,headRefName,title,url`
  -> #265 owns diagnostic-table helper plus `ROADMAP.md`,
  `docs/dev-log/check-log.md`, Design 35 / 51; no `joint-sdm.Rmd` /
  Design 04 overlap.
- `gh pr view 267 --repo itchyshin/gllvmTMB --json files,headRefName,title,url`
  -> #267 owns the Set C gate matrix, r200 plan, Design 54, and
  coordination board; no touched-file overlap with this slice.
- `rg -n 'reserved for binary|catastrophic|broken|wasted effort|Skip dep|skip dep|skip indep|✅|❌|🔴' vignettes/articles/joint-sdm.Rmd docs/design/04-random-effects.md`
  -> no output.
- `rg -n 'RE-09|FG-07|FG-08|LAM-03|LAM-04|unique\(\)|dep\(\)|indep\(\)|lambda_constraint' vignettes/articles/joint-sdm.Rmd docs/design/04-random-effects.md`
  -> intentional row-ID and keyword hits only.
- `git diff --check` -> clean.
- `Rscript --vanilla -e 'rmarkdown::render("vignettes/articles/joint-sdm.Rmd", output_file="/tmp/gllvmTMB-joint-sdm.html", quiet=TRUE)'`
  -> rendered successfully to `/tmp/gllvmTMB-joint-sdm.html`.
- `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test-joint-sdm-binary-long-wide.R")'`
  -> `FAIL 0 | WARN 0 | SKIP 0 | PASS 11`.
- `Rscript --vanilla -e 'rmarkdown::render("vignettes/articles/joint-sdm.Rmd", output_file="/tmp/gllvmTMB-joint-sdm-after-delegation.html", quiet=TRUE)'`
  -> rendered successfully to `/tmp/gllvmTMB-joint-sdm-after-delegation.html`.
- `air format tests/testthat/test-joint-sdm-binary-long-wide.R`
  -> completed with no output.
- `perl -ne 'print "$ARGV:$.: trailing whitespace\n" if /[ \t]$/; print "$ARGV:$.: tab character\n" if /\t/;' docs/dev-log/after-task/2026-05-25-joint-sdm-binary-scope-rewrite.md docs/dev-log/audits/2026-05-25-hidden-article-validation-map.md docs/dev-log/audits/2026-05-25-joint-sdm-rendered-figure-qa.md docs/dev-log/audits/2026-05-25-r200-readiness-review.md tests/testthat/test-joint-sdm-binary-long-wide.R`
  -> no output.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> `No problems found.`
- `Rscript --vanilla -e 'testthat::test_file("tests/testthat/test-joint-sdm-binary-long-wide.R")'`
  -> after formatting, `FAIL 0 | WARN 0 | SKIP 0 | PASS 11`.
- `gh issue list --repo itchyshin/gllvmTMB --state open --search 'joint-sdm OR "joint SDM" OR species distribution OR lambda_constraint OR "lambda constraint"' --json number,title,url,labels,updatedAt --limit 20`
  -> #230 is the relevant article-surface issue.
- `gh issue list --repo itchyshin/gllvmTMB --state open --search 'Set C OR article restoration OR hidden article' --json number,title,url,labels,updatedAt --limit 20`
  -> #230 again.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> `No problems found.`
- `rg -n 'gllvmTMB\(' vignettes/articles/joint-sdm.Rmd docs/design/04-random-effects.md`
  -> article long call retains `trait = "trait"`; wide `traits(...)`
  call correctly has no `trait`; Design 04 examples are existing
  design examples, not changed call sites.
- `rg -n '\bS_B\b|\bS_W\b|\\bf S|diag\(U\)|U_phy|U_non|meta_known_V|gllvmTMB_wide\(Y|already removed|primary new-user API' vignettes/articles/joint-sdm.Rmd docs/design/04-random-effects.md`
  -> one intentional Design 04 compatibility mention of
  `meta_known_V()` as deprecated alias.
- `rg -n '\bphylo\(|\bgr\(|\bmeta\(|block_V\(|phylo_rr\(' vignettes/articles/joint-sdm.Rmd docs/design/04-random-effects.md`
  -> one existing Design 04 `block_V()` cross-reference; not touched by
  this slice.

## Consistency Audit

The article now matches the Set C gate matrix from PR #267:
pure-binary JSDM remains restorable in principle, the wide chunk stays
deferred, RE-09 and FG-07 / FG-08 are not over-advertised, and loading
constraints are introduced as optional confirmatory follow-up.

The design doc now matches the validation-debt register status for
LAM-03 and LAM-04.

## Tests of the Tests

The new `test-joint-sdm-binary-long-wide.R` test satisfies the
feature-combination rule: it combines the wide `traits(...)` API,
long-format `trait = "trait"` API, binomial family dispatch, a fixed
environmental slope term, and a reduced-rank `latent()` term. The
fixture uses a complete site x species grid, so equality is not
confounded with sparse absence-fill semantics.

The article render remains the execution smoke test for prose chunks:
all article chunks still run with `eval = TRUE` except the
already-deferred wide JSDM chunk.

## What Did Not Go Smoothly

The first ad hoc `rg` stale-wording command included unescaped
backticks in a shell string and zsh tried to execute `dep` / `indep`.
The command was rerun safely with single-quoted patterns.

I did not append `docs/dev-log/check-log.md` because #261 and #265
both currently modify that append-only file. Shannon marked the state
as WARN: this branch can safely touch `joint-sdm.Rmd` and Design 04,
but a third check-log append should wait until the open Codex stack is
settled.

## Team Learning

**Ada:** Kept the slice to non-overlapping files and stopped short of
pkgdown navigation or public restoration.

**Shannon:** Open PR state is WARN, not FAIL. #261 and #265 own the
shared check-log / roadmap lane; this branch avoids those files.

**Pat:** The article now keeps the reader's ecology path first:
co-occurrence, `Sigma`, correlations, and ordination before
confirmatory constraints.

**Darwin:** The loading-constraint bridge is framed as a biological
hypothesis question, not an IRT takeover of the species-distribution
page.

**Boole:** The keyword guidance now distinguishes `latent()`,
`unique()`, `dep()`, and `indep()` by validated public role.

**Noether:** Binary `psi` is no longer described as an estimable
observation-level variance for single-trial Bernoulli responses.

**Fisher:** Partial validation rows are named where the prose relies
on partial evidence; the article no longer turns local comparison
numbers into inferential proof.

**Rose:** Stale Design 04 wording was removed; hard unsupported
language such as "catastrophic" / "broken" was deleted.

**Grace:** `pkgdown::check_pkgdown()` remains clean and the article
renders to a temporary HTML file. The r200 readiness review also
surfaced a concrete timeout/sharding blocker before any expensive
workflow dispatch.

**Curie:** The binary long-vs-wide validation now has a focused test
fixture that can graduate the article's dormant wide call once the
article prose is ready.

**Florence:** Rendered figure QA failed the current article for public
Tier-1 use because the fitted Sigma scale is extreme and the biplot is
hand-built without attached rotation/alt-text metadata.

## Design, pkgdown, and Roadmap

Design 04 changed. `_pkgdown.yml`, `ROADMAP.md`, `NEWS.md`, README,
and generated Rd files did not change.

**Roadmap tick:** N/A. No roadmap row changed in this slice because
the article remains hidden and restoration is not complete.

## GitHub Issue Ledger

- Inspected #230, "Article surface reset and user-first tooling
  gate." This slice advances that issue's joint-SDM scope-honesty
  prerequisite but does not close it.
- No issue was commented on or closed. A PR, if opened, should mention
  #230 and the deferred check-log append.

## Known Limitations and Next Actions

- `joint-sdm` remains in the internal pkgdown tier.
- The binary long/wide absence-fill fixture is now represented by a
  focused complete-grid parity test, but the article's wide chunk
  still remains `eval = FALSE` until the prose/figure restoration PR
  chooses how to present that fixture.
- No `docs/dev-log/check-log.md` append yet, by design, until #261 /
  #265 merge order clears.
- The rendered figure QA says `joint-sdm` is not public Tier-1 ready:
  replace the hand-built biplot with the package ordination helper,
  use a correlation-first matrix display, and add captions / alt text
  before moving the article out of `internal`.
- r200 should not be dispatched until the maintainer approves scope
  and the workflow timeout risk is fixed by sharding or an explicit
  timeout change.
- Next safe slice after the open stack settles: append check-log,
  re-run Rose pre-publish audit, and either open a focused test/audit
  PR or split visual restoration into a second branch.
