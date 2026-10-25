# After Task: README optimizer-selection examples

**Branch**: codex/optimizer-docs-20261019
**Date**: 2026-10-19
**Roles (engaged)**: Ada and Rose (cross-package integration and pre-publish review)

## 1. Goal

Make the VA optimizer controls easier to discover for readers arriving through the README, while keeping the example scoped to the documented experimental VA route.

## 2. Implemented

Added a row in the README’s scientific-question table linking to a short comparison section. The section shows gllvmTMBcontrol() settings for nlminb and optim with BFGS, sets va_polish = FALSE, explains resetting the seed before fitting the same model, and says the native iteration limits do not represent equal computational effort. It labels VA experimental and makes no convergence or accuracy claim. The full runnable comparison and start-level diagnostics remain in gllvmTMBcontrol() help.

## 4. Files Touched

- README.md
- docs/dev-log/check-log.md
- docs/dev-log/after-task/2026-10-19-optimizer-selection-examples.md

No model examples were added to roxygen or vignettes; the README section contains control-object examples and points to the existing full fit example.

## 3a. Decisions and Rejected Alternatives

Kept the README snippet to control objects so it remains short and can be applied to the reader’s existing model call. A second copy of the full synthetic VA fit would duplicate the reference example. The native limits are shown as examples, not as matched budgets or recommendations about optimizer performance.

## 5. Checks Run

- python3 /Users/z3437171/shinichi-brain/tools/route.py gllvmTMB: loaded the gllvmTMB LOAD-FIRST manifest.
- bash /Users/z3437171/shinichi-brain/tools/lane_preflight.sh /Users/z3437171/Dropbox/Github Local/gllvmTMB: reported no recent active local branches; the PR line was “none (or gh not authenticated)” and therefore did not confirm the open-PR inventory; origin/main had one recent commit at that time.
- Lease readback: the live lease covered README.md, docs/dev-log/check-log.md, and this report path before editing.
- GitHub refresh in the isolated clone: fetched live origin/main at a674f29fb4f87f9e12558c372ca2417015025b34; replayed the README draft and confirmed a clean base before edits.
- Extracted the README R block and ran it after devtools::load_all() from the current source: both control objects passed assertions for optimizer, optArgs, eval.max, method, and va_polish fields; no fit was run.
- pkgdown::check_pkgdown(): “No problems found”; emitted existing Pandoc --mathml deprecation notices.
- source("/Users/z3437171/shinichi-brain/tools/check-after-task.R"); check_after_task(report): structure check passed, including required headings and section 12 negative-space marker.
- No model fits or package tests were run; this is a README-only user-facing change.

An initial check against the installed package was discarded as evidence because that installation predates these controls and warned that the arguments were ignored. The source-level check above supersedes it.

## 6. Tests of the Tests

No tests were added or changed. Constructor checks confirmed the displayed controls are accepted by the current source. No fit behavior, convergence, or optimizer-performance claim was tested.

## 8. Consistency Audit

- rg "\bS_B\b|\bS_W\b|\\bf S" .: existing matches are outside the edited README; no hit in the new section.
- rg -n "gllvmTMB\(" R vignettes README.md NEWS.md docs/design: existing README wide and long calls remain; the long-format call includes trait = "trait". The new section has no model call.
- rg "in prep|in preparation" docs vignettes: matches are outside README; no new literature claim was added.
- rg "\bphylo\(|\bgr\(|\bmeta\(|block_V\(|phylo_rr\(" vignettes: existing vignette matches; no README hit.
- rg "meta_known_V" README.md NEWS.md docs vignettes: existing matches outside README; no README hit.
- rg "gllvmTMB_wide" README.md NEWS.md docs vignettes: existing matches outside README; no README hit.
- Register boundary: the prose presents optimizer controls on the experimental VA route, with the route admission and boundary traceable internally to VA-01 and VA-02. It does not generalize optimizer performance or VA recovery.

## 7. Roadmap Tick

N/A; no roadmap status or progress changed.

## 7a. Issue Ledger

The targeted gh issue list --state open --search 'VA optimizer' --limit 20 request could not reach api.github.com, so current open issues could not be verified. The task adds discoverability for an existing API and creates no new issue or issue-state claim.

## 9. What Did Not Go Smoothly

The first local clone inherited a stale local main reference. It was refreshed from GitHub in the isolated clone and rebased to current main before the final checks. The installed R package was also stale; its constructor result was discarded and replaced by a source-level check. Relative paths made the prose checker resolve against the brain repository, so it was rerun with absolute paths to this checkout.

## 11. Team Learning

The root integrator will perform the cross-package final review. Rose pre-publish review found the selector API, scope, link, and discovery-table placement correct after the README block gained its library() line. Ada and Rose independently reviewed the README addition. Rose found the selector API, scope, link, and discovery-table placement correct after the README block gained its library() line.

## 10. Known Residuals

This verifies control construction and pkgdown consistency only. It does not compare optimizer convergence, runtime, or fitted objectives. Existing VA experimental boundaries remain unchanged. A current GitHub issue inventory remains unverified because the CLI could not connect.


## 12. Cross-Product Coverage

The README example does NOT cover fitted objectives, runtime, optimizer convergence, parameter recovery, interval coverage, or cross-platform behavior. It does not change or broaden the experimental VA admission boundary.
