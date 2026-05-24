# After Task: Autonomous Surface Wave 1

**Branch:** `codex/autonomous-surface-wave1-2026-05-24`
**Date:** 2026-05-24
**Roles engaged:** Ada, Shannon, Rose, Grace, Pat, Florence, Fisher, Boole, Emmy

## 1. Goal

Start the maintainer-requested autonomous 30-slice sequence with the lowest-risk public-surface reconciliation work: make the roadmap and article gate ledger agree with the helper surface that has already landed, then render-review the visible pkgdown pages after the logo/site polish.

## 1a. Mathematical Contract

No likelihood, formula grammar, covariance parameterisation, family, extractor implementation, or TMB code is intended to change in this wave.

## 2. Implemented

- Reconciled `ROADMAP.md` with the already-merged report-ready extractor and
  plotting helper surface.
- Marked reset slices 9-12 as done and slice 13 as partial, with explicit
  evidence boundaries.
- Updated the public-surface table so visible pages are no longer described as
  generically "under HTML review"; they now distinguish launch-level review
  from final figure/prose audits.
- Updated the article gate matrix so morphometrics, covariance/correlation,
  convergence/start-values, and pitfalls list the helper rows they now rely on.
- Added `docs/dev-log/audits/2026-05-24-public-surface-wave1-render-review.md`
  with rendered-page evidence and the mobile screenshot caveat.
- Added homepage-only narrow-screen CSS so summary tables stack and long code
  terms wrap on phones.

## 3. Files Changed

- `ROADMAP.md`
- `docs/dev-log/audits/2026-05-20-article-gate-matrix.md`
- `docs/dev-log/audits/2026-05-24-public-surface-wave1-render-review.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-05-24-autonomous-surface-wave1.md`
- `docs/dev-log/recovery-checkpoints/2026-05-24-111418-ada-checkpoint.md`
- `pkgdown/extra.css`

## 4. Checks Run

Pre-edit coordination checks:

- `gh pr list --repo itchyshin/gllvmTMB --state open --json number,title,headRefName,baseRefName,isDraft,mergeStateStatus,url,statusCheckRollup`
  - Result: `[]`.
- `git log --all --oneline --since="6 hours ago" --decorate`
  - Result: recent merged docs/site commits only; no open competing PR.
- `gh run list --repo itchyshin/gllvmTMB --limit 12 --json databaseId,displayTitle,workflowName,status,conclusion,headBranch,headSha,url,createdAt`
  - Result: all recent `main` R-CMD-check and pkgdown runs completed successfully; no active run.

- `Rscript --vanilla -e 'pkgdown::build_site(new_process = FALSE, install = FALSE)'`
  - Result: completed; sitrep reported URLs, favicons, Open Graph metadata,
    article metadata, and reference metadata ok.
- `Rscript --vanilla -e 'pkgdown::check_pkgdown()'`
  - Result: `No problems found.`
- `cmp -s pkgdown/extra.css pkgdown-site/extra.css; printf 'css cmp=%s\n' $?`
  - Result: `css cmp=0`.
- `rg -n "first tidy table helper still pending|Visible, under HTML review|Visible, wording review|visible, under HTML review|under wording review|functional but still basic" ROADMAP.md docs/dev-log/audits/2026-05-20-article-gate-matrix.md`
  - Result: no matches.
- `rg -n "extract_Sigma_table\\(\\)|EXT-18|EXT-30|plot_correlations\\(\\)|compare_Sigma_table\\(\\)|plot_Sigma_comparison\\(\\)|rotated-loading|M3\\.3b" ROADMAP.md pkgdown-site/articles/roadmap.html docs/dev-log/audits/2026-05-20-article-gate-matrix.md`
  - Result: source and rendered roadmap contain the updated helper evidence.
- `python3 -m http.server 8767 --bind 127.0.0.1 --directory pkgdown-site`
  - Result: local server used for rendered screenshots.
- Headless Chrome screenshots:
  - `/tmp/gllvmTMB-wave1-home.png`
  - `/tmp/gllvmTMB-wave1-roadmap.png`
  - `/tmp/gllvmTMB-wave1-morphometrics.png`
  - `/tmp/gllvmTMB-wave1-covariance.png`
  - `/tmp/gllvmTMB-wave1-pitfalls.png`
  - `/tmp/gllvmTMB-wave1-home-stacked.png`
  - `/tmp/gllvmTMB-wave1-mobile-home-widthfix.png`
- `find vignettes -maxdepth 1 -type f \( -name '*.png' -o -name '*.jpg' -o -name '*.jpeg' \) -print`
  - Result: generated scratch files were removed after the site builds.

## 5. Tests Of The Tests

This wave does not add package tests. The regression checks are structural:
the stale roadmap phrases must be absent, the roadmap HTML must contain the
updated helper evidence, `pkgdown::check_pkgdown()` must pass, and source CSS
must byte-match generated `pkgdown-site/extra.css`.

## 6. Consistency Audit

- The roadmap now agrees with validation-debt rows EXT-18 through EXT-30.
- The article gate matrix distinguishes launch-level public visibility from
  final article-quality approval.
- The roadmap still keeps diagnostic tables and final Florence article review
  as pending work; this avoids converting helper infrastructure into a
  publication-grade figure claim.
- No user-facing syntax convention changed, so no convention-change cascade was
  required.

## 7. Roadmap Tick

Slices 9-12 moved from stale "done when" wording to explicit done evidence.
Slice 13 moved to partial, because the helper and snapshot surface exists but
full rendered article-figure review remains open.

## 7a. GitHub Issue Ledger

Issue #230 remains open and continues to own the public-surface reset ledger.
This wave advances #230 but does not close it because the final visible-article
figure/prose passes and the diagnostic/API follow-up waves are still pending.

## 8. What Did Not Go Smoothly

The command-line Chrome mobile screenshot behaved like a cropped narrow desktop
viewport rather than a reliable mobile-device emulation. I kept the CSS fix
because it improves narrow homepage tables, but I recorded that the exact mobile
visual should be rechecked with a proper browser/Playwright viewport in the
next visual QA wave.

## 9. Team Learning

Ada: the first autonomous slice should reconcile the ledger before adding new
API or article content.

Grace: full `pkgdown::build_site()` is slower than targeted rendering, but it
is useful for public-surface reconciliation because it catches hidden article
metadata and generated-site parity.

Pat: launch-level visible does not mean final reader-ready. The roadmap should
say which review remains so users do not read "visible" as "finished".

Florence: helper metadata and snapshots are useful, but rendered article
figures still need a separate visual gate.

Rose: stale "pending" roadmap lines are overpromise risks in reverse: they hide
implemented helper evidence and can send the team back over old ground.

No spawned subagents were running.

## 10. Known Limitations And Next Actions

- Wave 2 should close visible article review gaps: morphometrics,
  covariance/correlation, pitfalls, response-families, api-keyword-grid, and
  convergence/start-values.
- The mobile homepage screenshot should be rechecked with a true mobile
  browser viewport rather than command-line Chrome's cropped narrow-window
  behavior.
- No public diagnostic API work was done here; #248 and #228 remain later
  autonomous waves.
