# Overnight Report: 2026-05-11 → Tuesday 5 a.m.

For the maintainer's morning read. Single file, single read-path —
no need to walk 18 after-task reports to catch up.

Window covered: 22:20 UTC 2026-05-11 (PR #23 approval) → Tuesday
morning.

## Headline

Five PRs merged today/overnight: four Claude doc PRs + one Codex
morphometrics article rewrite. Main is at `60eeba4` (post-PR-#27).
Public site rebuilt twice overnight. No CI red lights left standing
on main. Phase 3 implementation is now unblocked for Codex; Phase
1a row 1 (morphometrics) is **done**.

## Merged on main (today + overnight)

| Merge commit | PR | Title | Time (UTC) |
|---|---|---|---|
| `b425462` | #23 | Phase 3 design doc: data-shape and weights contract | 22:22:37 |
| `2fd4896` | #24 | Enrich after-task protocol with drmTMB-style patterns | 22:55:33 |
| `50d5382` | #25 | Record PR #22 post-merge CI evidence in check-log | ~23:?? |
| `d7d72e1` | #26 | Citation policy cleanup (Path A) | 23:48:38 |
| `60eeba4` | #27 | Rewrite morphometrics Tier-1 article (Codex) | 23:52:48 |

Claude #23-#26 are documentation-only (no source / NAMESPACE / Rd
/ vignette / pkgdown navigation change). PR #27 (Codex) touches
the vignette + the extractor R/ files + the corresponding Rd
files + one test file (adds back-compat tests for the new
canonical level names). Each PR shipped with its after-task
report in the same commit per the new `CONTRIBUTING.md` rule.

Main CI on `50d5382` (post-#25): 3-OS R-CMD-check success;
workflow_run pkgdown deploy success.
Main CI on `60eeba4` (post-#27): was running at report writing
time; the R-CMD-check on the post-#26 `d7d72e1` was cancelled by
concurrency when #27 merged, which is the expected
`cancel-in-progress` behaviour. pkgdown deploy follows on success.

## Open PRs

**None awaiting your review.** PR #27 merged at 23:52:48 UTC
(merge commit `60eeba4`) while the overnight loop was running. My
Claude review checklist + recommendation are preserved as a PR
comment on #27 for the record:
<https://github.com/itchyshin/gllvmTMB/pull/27#issuecomment-4426088412>

### What PR #27 landed

| Item | Status |
|---|---|
| Long + wide pairing in three fit blocks (main, recovery loop, `dep`/`indep`/`latent(d=T)` comparison) | ✅ |
| Formula RHS byte-identical across long/wide; inline `logLik` equivalence checks | ✅ |
| `unit = "individual"` consistent | ✅ |
| `getLoadings()` replaced with `extract_ordination($loadings)` + `rotate_loadings()` | ✅ |
| `ordiplot()` replaced with `extract_ordination()` + `plot(fit, type = "ordination")` | ✅ |
| Equations + structure preserved (equations moved to "What model did we fit?" *after* the fit -- reader-path improvement) | ✅ |
| After-task report at branch start | ✅ |
| 3-OS R-CMD-check green | ✅ |

**One content change that landed**: the rendered article dropped
the `extract_communality(..., ci = TRUE, method = "wald")` call,
keeping only point estimates. Codex's rationale:
"Bootstrap is a slower, deliberate option for a separate cached
check, not part of this rendered article." A Tier-1 reader no
longer sees communality CIs in the rendered article. **Worth a
glance**: if you want CIs restored in the Tier-1 article, that's
a small follow-up PR Codex can pick up. Otherwise no action.

**Scope creep that landed (defensible)**: PR #27 also touched the
extractors (`R/extractors.R`, `R/output-methods.R`,
`R/plot-gllvmTMB.R`, `R/rotate-loadings.R`) and added an internal
`.canonical_level_name()` helper. Legacy `"B"`/`"W"` levels now
emit a deprecation warning and translate to `"unit"`/`"unit_obs"`
canonical names. No existing user code breaks. The article uses
the canonical names; the tests verify both the deprecation
warning path and the no-warning canonical path.

## Codex handoff

Posted as a PR comment on the (now-merged) PR #23
(<https://github.com/itchyshin/gllvmTMB/pull/23#issuecomment-4425658870>):
Phase 3 implementation is now unblocked. Codex's next bounded task
is `R/weights-shape.R` + the entry-point refactor + paired tests,
following `docs/design/02-data-shape-and-weights.md` "Implementation
Notes For Codex" and the Option C decision recorded in
`decisions.md`.

## Process state (snapshot for your sanity check)

- **WIP**: 0 open PRs at report time. (PR #28, this overnight
  report, may still be open when you read this; it'll self-merge
  on CI green.) Back to WIP=0/1 discipline; healthy.
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
  the merge-authority rule, that nudged toward the API-change
  side. Left for you with a Claude review comment. PR #27 was
  subsequently merged at 23:52:48 (most likely by you in a brief
  awake window, or by Codex's own self-merge judgement) -- either
  way it's on main now.
- **Did not start any new substantive Claude-lane PR after the
  citations cleanup.** WIP discipline; the open queue cleared,
  the overnight stream became "watch and report" rather than
  "open more work."
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

1. **Dispatch Codex to the next bounded task.** Two natural
   options:
   - Phase 1a row 2: `covariance-correlation.Rmd` rewrite, same
     pattern as PR #27.
   - Phase 3 implementation: `R/weights-shape.R` + entry-point
     refactor + paired tests, per the PR #23 handoff comment
     and `docs/design/02-data-shape-and-weights.md`.
   Either is well-scoped; running both in parallel is fine
   because the file scopes do not overlap.
2. **Optional content question on PR #27**: do you want the
   communality CI restored to the rendered morphometrics article?
   Small follow-up if yes.
3. **Optional housekeeping**: tiny PR moving `tidyselect` out of
   `Suggests:` (it's in both `Imports` and `Suggests` and shows
   up as a NOTE on every R CMD check). I can pick this up if you
   ack.
4. **Optional review**: PR #24's protocol enrichment is now in
   force; you may want to glance at how it landed.

I'll keep the loop ticking overnight in case Codex pushes a
follow-up or main CI surfaces anything unexpected, but no further
action is expected from me without your dispatch.

## Files added by this report

- `docs/dev-log/while-away/2026-05-11-overnight.md` (this file)
- No other change.
