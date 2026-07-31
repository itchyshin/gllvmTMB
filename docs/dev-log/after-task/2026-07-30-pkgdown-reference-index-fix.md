# After-task — pkgdown docs build unbroken (missing reference-index topic) — 2026-07-30/31

**Platform:** Claude. **Branch:** `claude/pkgdown-index-total-variance-20260730` (off `origin/main`). **PR:** #861. **Status:** FIXED, verified locally; CI confirmation follows the merge. **Scope:** one line of `_pkgdown.yml`. No package code, no API, no claim.

## Scope / goal
Maintainer reported the failing `pkgdown` workflow. Goal: find the root cause and unbreak the docs build. Not an arc — a single defect.

## Root cause
`f04c066c` ("feat(profile): export profile_ci_total_variance() behind a per-row fence", merged via PR #832) added `export(profile_ci_total_variance)` to `NAMESPACE` and shipped `man/profile_ci_total_variance.Rd`, but did not add the topic to the `_pkgdown.yml` reference index. pkgdown's `build_reference_index()` aborts on any documented, non-internal topic missing from the index, so the docs build failed on every run from that merge onward.

Timeline (UTC): PR #832 merged **20:55** on 2026-07-30; last good pkgdown run **19:44**; first failure **21:19**; still failing at **00:21** on 07-31. **13 consecutive failures.** Logs pulled for all 13 — every one carries the identical single cause, so this is one defect, not a streak of unrelated breakage.

The published site is **stale, not broken**: the last good deploy is still live, and nothing has deployed since 19:44 UTC. The `deploy` job never ran because `build` failed first.

## Fix
Added `profile_ci_total_variance` to the existing **Profile-likelihood confidence intervals** section of `_pkgdown.yml`, beside its sibling route `profile_ci_phylo_signal`.

Indexing was the right call over `@keywords internal`: the function is a deliberate user-facing export ("Profile-likelihood CI for per-trait total variance"), and PR #832's own commit message frames it as an intentional export behind a per-row fence. The chosen section's `desc` already carries the per-target calibration caveat ("inspect each target and do not assume universal calibration"), so the honesty fencing is inherited rather than re-stated — no new reader-facing claim is made about this route's calibration.

## Checks
Ran pkgdown's own code path locally (pkgdown 2.2.0), the same one CI hits:

| check | before | after |
|---|---|---|
| `pkgdown:::data_reference_index()` | reproduced the exact CI error | `PASS: reference index complete` |
| `pkgdown::check_pkgdown()` | — | `✔ No problems found.` |

The clean `check_pkgdown()` is the Rose sweep: it confirms this was the **only** index drift, not one of a set.

Not run: a full `pkgdown::build_site()` (unnecessary — the failure is in index validation, which the above exercises directly) and `devtools::check()` (`_pkgdown.yml` is not part of the R package build).

## Honest limits
`pkgdown` runs `on: workflow_run` after **R-CMD-check on `main`**, so the PR itself cannot produce a green pkgdown run. The local `check_pkgdown()` result is the real evidence at merge time; the CI-green confirmation is only observable after the merge lands.

## Follow-up (not done here — out of scope)
Reference-index completeness is **invisible to `R CMD check`**, so this class of breakage is structurally undetectable until after merge to `main` — which is why it burned 13 runs before being noticed. `pkgdown::check_pkgdown()` runs in seconds without a site build and would catch it pre-merge. Wiring it into the PR check is a small, separate change, and matches the standing "local checks over CI" rule. Not bundled here to keep this fix surgical.

Secondary observation, not acted on: the `pkgdown` workflow carries a Node 20 deprecation annotation for `actions/configure-pages@v5`. Unrelated to this failure; noted, not fixed.
