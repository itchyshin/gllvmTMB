# After Task: Visible Article Closeout Wave 2

**Branch**: `codex/visible-article-closeout-wave2-2026-05-24`
**Date**: `2026-05-24`
**Roles (engaged)**: `Ada / Florence / Pat / Darwin / Fisher / Grace / Rose / Shannon`
**Spawned subagents**: none

## 1. Goal

Close the next visible-article review gap from the public-surface reset,
starting with the rendered morphometrics ordination figure defect found after
Wave 1.

## 2. Implemented

- Fixed the rendered Morphometrics ordination biplot by replacing the
  long built-in caption with a shorter, rotation-honest article caption.
- Increased the ordination chunk height from 5.0 to 5.6 inches.
- Added
  `docs/dev-log/audits/2026-05-24-morphometrics-final-figure-prose-review.md`.
- Updated `ROADMAP.md` and the article gate matrix to mark only
  Morphometrics as final rendered figure/prose audit passed.

## 3. Files Changed

- `vignettes/articles/morphometrics.Rmd`
- `ROADMAP.md`
- `docs/dev-log/audits/2026-05-20-article-gate-matrix.md`
- `docs/dev-log/audits/2026-05-24-morphometrics-final-figure-prose-review.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/recovery-checkpoints/2026-05-24-132734-ada-checkpoint.md`
- `docs/dev-log/after-task/2026-05-24-visible-article-closeout-wave2.md`

No R source, likelihood, formula grammar, family, roxygen, generated
Rd, NAMESPACE, NEWS, `_pkgdown.yml`, or validation-debt status changed.

## 3a. Decisions and Rejected Alternatives

Decision: close only the Morphometrics final rendered article gate.

Rationale: Wave 1 read-only QA found a concrete rendered defect in the
Morphometrics ordination figure. After the fix, the rendered HTML
references four current figures and all four were reviewed.

Rejected alternative: mark the whole six-page public surface as final.
That would overclaim; the other visible pages still need their own
rendered closeout passes.

Rejected alternative: change the built-in `plot(type = "ordination")`
caption globally. This was not necessary for the current defect; the
article-level caption is narrower and avoids changing the public plot
helper API or snapshots.

## 4. Checks Run

- `gh run view 26369528814 --repo itchyshin/gllvmTMB --json status,conclusion,jobs`
  -> Wave 1 post-merge main R-CMD-check passed on macOS, Ubuntu, and
  Windows.
- `gh run view 26370333206 --repo itchyshin/gllvmTMB --json status,conclusion,jobs`
  -> downstream `pkgdown` workflow passed.
- `gh pr list --repo itchyshin/gllvmTMB --state open --json number,title,headRefName,baseRefName,author,updatedAt,url`
  -> `[]`.
- `git log --all --oneline --since="6 hours ago" --decorate`
  -> no competing open PR.
- `Rscript --vanilla -e 'devtools::install(quick = TRUE, dependencies = FALSE, build_vignettes = FALSE, quiet = TRUE); pkgdown::build_article("articles/morphometrics", quiet = FALSE, new_process = FALSE)'`
  -> completed.
- `view_image("pkgdown-site/articles/morphometrics_files/figure-html/ordi-1.png")`
  -> rendered caption no longer clips.
- `Rscript --vanilla -e 'pkgdown::build_article("articles/roadmap", quiet = FALSE, new_process = FALSE)'`
  -> completed.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  -> `No problems found.`
- Rendered figure reference scan showed only four active Morphometrics
  figures in the HTML.
- Status/rendered wording and stale terminology scans are recorded in
  `docs/dev-log/check-log.md`.
- `gh issue list --repo itchyshin/gllvmTMB --state open --search "morphometrics OR article surface reset OR figure prose closeout OR Article surface reset" --json number,title,url,labels,updatedAt --limit 20`
  -> found #230.
- `git diff --check`
  -> clean.

## 5. Tests of the Tests

No tests were added or modified. This is an article render and status
slice. The executable guard is the targeted Morphometrics render, which
would fail if the example code, fitted object, or plot call were broken.

## 6. Consistency Audit

Rose verdict: PASS for the touched public article and status ledger.

- Morphometrics now has one audit path in the roadmap and gate matrix:
  `docs/dev-log/audits/2026-05-24-morphometrics-final-figure-prose-review.md`.
- The audit keeps the cached bootstrap fixture bounded as visual QA, not
  calibration evidence.
- The other visible pages remain pending where their final rendered
  reviews are not done.
- No convention change occurred, so no roxygen/Rd/vignette cascade was
  required.

## 7. Roadmap Tick

`ROADMAP.md` Slice 6 and the current public surface row now mark
Morphometrics as final rendered figure/prose audit passed. No other
article status was promoted.

## 7a. GitHub Issue Ledger

#230 remains open. This wave advances the Morphometrics final rendered
article gate but does not close the broader article-surface reset.

## 8. What Did Not Go Smoothly

The rendered ordination biplot exposed a practical figure-gate issue:
the plot helper caption was mathematically careful but too long for the
article figure size. The fix was to keep the rotation warning in the
article but make it short enough to render cleanly.

## 9. Team Learning

Ada kept the lane to one article after Wave 1's full merge/deploy gate
passed.

Florence treated clipped caption text as a figure failure, not a minor
cosmetic nuisance.

Pat/Darwin kept the article focused on the applied morphometrics
question and the under-audit complexity ladder.

Fisher kept the cached bootstrap fixture framed as visual uncertainty
plumbing, not calibration evidence.

Grace verified the deploy-facing path with targeted article renders and
`pkgdown::check_pkgdown()`.

Rose checked that status promotion is limited to Morphometrics and that
stale/unsupported wording did not creep in.

Shannon's coordination view: no open PRs were present before the branch;
Wave 1 main R-CMD-check and pkgdown deploy were green before Wave 2
edits began.

## 10. Known Limitations And Next Actions

- The other visible articles still need their own final rendered
  closeout passes.
- This wave does not add new figure snapshots or change plot helper
  defaults.
- Next safest slice: close the covariance/correlation article's final
  rendered figure/prose gate, especially the matrix display boundary and
  any remaining figure readability issues.
