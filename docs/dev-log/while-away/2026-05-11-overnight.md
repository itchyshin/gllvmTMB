# Overnight Report: 2026-05-11 → Tuesday 5 a.m.

For the maintainer's morning read. Single file, single read-path —
no need to walk 18 after-task reports to catch up.

Window covered: 22:20 UTC 2026-05-11 (PR #23 approval) → Tuesday
morning.

## Headline

Four Claude PRs merged + one Codex PR awaits your review.
Main is at `d7d72e1` (post-PR-#26). Public site rebuilt twice
overnight (post-#22 and post-#25 cycles). No CI red lights left
standing on main. Phase 3 implementation is now unblocked for
Codex; Phase 1a (morphometrics) is one merge away from done.

## Merged on main (today + overnight)

| Merge commit | PR | Title | Time (UTC) |
|---|---|---|---|
| `b425462` | #23 | Phase 3 design doc: data-shape and weights contract | 22:22:37 |
| `2fd4896` | #24 | Enrich after-task protocol with drmTMB-style patterns | 22:55:33 |
| `50d5382` | #25 | Record PR #22 post-merge CI evidence in check-log | ~23:??:?? |
| `d7d72e1` | #26 | Citation policy cleanup (Path A) | 23:48:38 |

All four are documentation-only (no source / NAMESPACE / Rd /
vignette / pkgdown navigation change). Each shipped with its
after-task report in the same commit per the new
`CONTRIBUTING.md` rule.

Main CI on `50d5382` (post-#25): 3-OS R-CMD-check success;
workflow_run pkgdown deploy success. Main CI on `d7d72e1`
(post-#26) was running at report writing time; expected to pass
since #26 itself passed CI before merge and main only differs by
the merge commit.

## Awaiting your review (the only open PR)

### PR #27 -- Rewrite morphometrics Tier-1 article (Codex)

URL: <https://github.com/itchyshin/gllvmTMB/pull/27>

- 591 additions / 140 deletions across 19 files.
- 3-OS R-CMD-check: **all green**.
- After-task report at branch start: ✅.

**Scope**: article rewrite per the PR #14 canonical snippet, plus
defensive support for canonical `level = "unit"` / `"unit_obs"`
names in the extractors (with `"B"`/`"W"` kept as legacy aliases
that emit a deprecation warning, so no existing user code breaks).

**My checklist** (full version posted as a PR comment, abridged
here):

| # | Item | Status |
|---|---|---|
| 1 | Long + wide pairing on the main fit | ✅ |
| 2 | Formula RHS byte-identical across long/wide | ✅ (3 fit pairs in the article) |
| 3 | `unit = "individual"` consistent | ✅ |
| 4 | `getLoadings()` replaced with `extract_ordination($loadings)` + `rotate_loadings()` | ✅ |
| 5 | `ordiplot()` replaced with `extract_ordination()` + `plot(fit, type = "ordination")` | ✅ |
| 6 | Equations + structure preserved | ✅ (equations moved to "What model did we fit?" *after* the fit -- reader-path improvement) |
| 7 | After-task report at branch start | ✅ |
| 8 | Rose gate / pkgdown article render | ✅ (CI green) |

**One content change to confirm**: the rendered article dropped
the `extract_communality(fit, level = "unit", ci = TRUE,
method = "wald")` call, keeping only point estimates. Codex's
rationale: "Bootstrap is a slower, deliberate option for a
separate cached check, not part of this rendered article." This
keeps the rendered article fast but means a Tier-1 reader does
not see CIs.

**My recommendation**: approve. The API addition (canonical level
names + back-compat aliases) is necessary scope for the article
to use the canonical naming; the deprecation path means no
existing user code breaks. The communality CI removal is a small
content change worth ratifying.

**To clear in 5 minutes**: merge PR #27 if you accept the
communality CI removal; or comment "please restore the CI" if you
want it back, and Codex iterates.

## Codex handoff

Posted as a PR comment on the (now-merged) PR #23
(<https://github.com/itchyshin/gllvmTMB/pull/23#issuecomment-4425658870>):
Phase 3 implementation is now unblocked. Codex's next bounded task
is `R/weights-shape.R` + the entry-point refactor + paired tests,
following `docs/design/02-data-shape-and-weights.md` "Implementation
Notes For Codex" and the Option C decision recorded in
`decisions.md`.

## Process state (snapshot for your sanity check)

- **WIP**: 1 open PR (#27, Codex). Back to WIP=1 discipline after
  the day's doc-sprint cleared. Healthy.
- **Pre-edit lane check**: held throughout the day. The expected
  decisions.md and check-log.md conflicts on parallel PRs were
  resolved chronologically (append-only convention). One
  worked-example noted in the PR #26 after-task.
- **drmTMB-style after-task protocol** (PR #24) is in force going
  forward. The PR #26 (citations) after-task and this overnight
  report both follow the new patterns (Mathematical Contract
  section, classified Consistency Audit, Team Learning by role).
- **Codex morphometrics review checklist** in
  `~/.claude/plans/please-have-a-robust-elephant.md` matched the
  PR #27 work item-by-item. Worth keeping for the remaining seven
  article rewrites.

## What I did NOT do (and why)

- **Did not self-merge PR #27.** Touches `R/` + tests + Rd; per
  the merge-authority rule, that nudges toward the API-change
  side. Left for you, with a Claude review comment surfacing the
  checklist + the content question.
- **Did not start any new Claude-lane PR after the citations
  cleanup.** WIP=1 discipline; the open queue cleared, the
  overnight stream became "watch and report" rather than "open
  more work."
- **Did not respond on Codex's behalf to any Phase 3 questions.**
  The handoff comment on PR #23 has the spec; Codex picks up at
  their own pace.

## Pre-existing items worth a note (not new from overnight)

- `DESCRIPTION` has `tidyselect` in both `Imports` and `Suggests`.
  Surfaced as a NOTE on the PR #26 CI run (the kind that R CMD
  check tolerates but flags). Pre-existing on main since before
  today; not caused by any of today's PRs. Worth a future tiny
  cleanup PR -- move `tidyselect` to `Imports` only (since `R/`
  uses it).

## Dispatch options when you're back

In rough priority order:

1. **Review + merge PR #27** -- one decision, one click. Codex
   can then start a second article rewrite (PR #14 row 2:
   `covariance-correlation.Rmd`).
2. **Dispatch Codex to start Phase 3 implementation** if you want
   to parallelise -- the `R/weights-shape.R` helper + refactor
   are on the queue per the PR #23 handoff comment.
3. **Optional housekeeping**: tiny PR moving `tidyselect` out of
   `Suggests:`. I can pick this up if you ack.
4. **Optional review**: PR #24's protocol enrichment is now in
   force; you may want to glance at how it landed.

I'll keep the loop ticking overnight in case Codex pushes a
follow-up or main CI surfaces anything unexpected, but no further
action is expected from me without your dispatch.

## Files added by this report

- `docs/dev-log/while-away/2026-05-11-overnight.md` (this file)
- No other change.
