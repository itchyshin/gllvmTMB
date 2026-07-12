# Lesson: the public pkgdown site deploys ONLY from `main`

**Date:** 2026-07-12
**Recorded by:** Claude (release-0.5.0 review session)
**Trigger:** Maintainer saw the fixed-top navbar clipping page headings on
`itchyshin.github.io/gllvmTMB/` and asked why a fix "we discussed a lot and
fixed" was still not implemented.

## Symptom

Reader-facing pkgdown fixes (the fixed-top navbar spacing that stops the page
header / logo / right-hand TOC being clipped under the navbar; grid/table
fixes; landing-page rework) are repeatedly made — but the **public** GitHub
Pages site never shows them.

## Root cause — a deploy gap, not a code gap

The navbar fix is real and correct: `pkgdown/extra.css` lines ~157-199
("Fixed-top navbar spacing (site-wide)", `scroll-padding-top` + `margin-top`
at the 992-1280px range + navbar collapse below 1280px), added in commits
`e9dbe709` and `4a983599` ("correct fixed-top navbar spacing to match
drmTMB"). It lives on `claude/release-0.5.0`.

It is invisible to the public site because of **two locks, both pointing at
`main`:**

1. **Workflow trigger.** `.github/workflows/pkgdown.yaml` deploys on
   `workflow_run` of R-CMD-check completing on `branches: [main, master]`
   (plus manual `workflow_dispatch`). Feature-branch pushes never
   auto-deploy.
2. **Environment protection rule.** The `github-pages` environment has a
   deployment-branch policy that allows **only `main`**. A
   `workflow_dispatch` from a feature branch fails in ~1-4s with:
   *"Branch 'claude/release-0.5.0' is not allowed to deploy to github-pages
   due to environment protection rules."*

`git merge-base --is-ancestor <fixcommit> main` = **NO** — the fix has never
reached `main`, and `main` is the only thing Pages builds. So every session
re-fixes it on a branch, the branch never merges, and the public site keeps
serving `main`'s old `extra.css`.

## The general trap

**Work that only ever lives on feature branches is structurally invisible to
a site that deploys from `main`.** A local pkgdown render (or a branch commit)
is NOT evidence the public site changed. This is the "local vs live"
distinction: local render = this checkout only; public site = whatever last
reached `main`.

## Standing rule

- Pkgdown / reader-facing site fixes only go live when they **reach `main`**
  (normally via the release merge).
- To deploy a branch ad hoc (e.g. to preview before release), you must
  **temporarily add the branch to the `github-pages` environment
  deployment-branch policy**, `workflow_dispatch` the pkgdown workflow on that
  branch, then restore the policy. Triggering the workflow alone is not
  enough — the environment gate rejects non-`main` branches.
- Never report a pkgdown fix as "done/implemented" on the strength of a local
  render or a branch commit. "Done" for a reader-facing fix means **merged to
  `main` and the pkgdown deploy succeeded**.

## Current status of the navbar fix

Present and correct on `claude/release-0.5.0` (`pkgdown/extra.css`). It lands
publicly when the release branch merges to `main`, or via an authorised
temporary environment-policy override + branch dispatch.
