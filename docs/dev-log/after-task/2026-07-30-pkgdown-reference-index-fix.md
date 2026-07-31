# After-task — pkgdown docs build unbroken (missing reference-index topic) — 2026-07-30/31

**Platform:** Claude. **Fix:** `84abf689`, merged to `main` via PR #861 (merged by the maintainer, 2026-07-31 00:23:28 UTC). **Status:** FIXED and merged; verified locally before merge, CI-confirmed after. **Scope:** one line of `_pkgdown.yml`. No package code, no API change, no new claim.

## Scope / goal
Maintainer reported the failing `pkgdown` workflow. Goal: root-cause it and unbreak the docs build. Not an arc — a single defect.

## Root cause
`f04c066c` ("feat(profile): export profile_ci_total_variance() behind a per-row fence", merged via PR #832) added `export(profile_ci_total_variance)` to `NAMESPACE` and shipped `man/profile_ci_total_variance.Rd`, but did not add the topic to the `_pkgdown.yml` reference index. pkgdown's `build_reference_index()` aborts on any documented, non-internal topic missing from the index, so the docs build failed on every run from that merge onward.

Timeline (UTC): PR #832 merged **20:55** on 2026-07-30; last good pkgdown run **19:44**; first failure **21:19**; still failing at **00:21** on 07-31. **13 consecutive failures.** Logs were pulled for all 13 — every one carries the identical single cause, so this is one defect, not a streak of unrelated breakage.

The published site was **stale, not broken**: the last good deploy stayed live throughout, and the `deploy` job simply never ran because `build` failed first.

## Correction to the merged commit message
The commit that landed (`84abf689`) states *"8 consecutive runs, 2026-07-30 22:37 onward."* **That is an under-count and the wrong onset.** The correct figures are the ones above: **13 failures**, beginning **21:19 UTC**, triggered by the #832 merge at **20:55 UTC**. I discovered the under-count after opening the PR and pushed a corrected commit message, but the maintainer had already merged the original — so the corrected message never reached `main`. This report is the authoritative record; the commit message is not. The error was in the count and onset only, never in the diagnosis or the fix.

## Fix
Added `profile_ci_total_variance` to the existing **Profile-likelihood confidence intervals** section of `_pkgdown.yml`, beside its sibling route `profile_ci_phylo_signal`.

Indexing was the right call over `@keywords internal`: the function is a deliberate user-facing export ("Profile-likelihood CI for per-trait total variance"), and PR #832's own commit message frames it as an intentional export behind a per-row fence. The chosen section's `desc` already carries the per-target calibration caveat ("inspect each target and do not assume universal calibration"), so the honesty fencing is inherited rather than re-stated — no new reader-facing claim is made about this route's calibration.

## Checks
Ran pkgdown's own code path locally (pkgdown 2.2.0), the same one CI hits:

| check | before | after |
|---|---|---|
| `pkgdown:::data_reference_index()` | reproduced the exact CI error | `PASS: reference index complete` |
| `pkgdown::check_pkgdown()` | — | `✔ No problems found.` |

The clean `check_pkgdown()` is the Rose sweep: it confirms this was the **only** index drift, not one of a set. Re-run afterwards against the merged `main` config (byte-identical `_pkgdown.yml`) to confirm the merged state, not just the pre-merge branch: `✔ No problems found.`, reference index OK.

CI confirmation after the merge:

| run | result |
|---|---|
| R-CMD-check on merge commit `4ee5c81b` | success |
| pkgdown `30594538673` — `build` | **success** (first green build since 19:44 UTC) |
| pkgdown `30594538673` — `deploy` | **success** (site republished) |

That closes the 13-failure streak.

Not run: a full `pkgdown::build_site()` (unnecessary — the failure is in index validation, which the above exercises directly) and `devtools::check()` (`_pkgdown.yml` is not part of the R package build).

## Follow-up (not done here — out of scope)
Reference-index completeness is **invisible to `R CMD check`**, so this class of breakage is structurally undetectable until after merge to `main` — which is why it burned 13 runs before being noticed. `pkgdown::check_pkgdown()` runs in seconds without a site build and would catch it pre-merge. Wiring it into the PR check is a small, separate change, and matches the standing "local checks over CI" rule. Deliberately not bundled here, to keep the fix surgical.

Secondary observations, noted rather than silently fixed:
- Neither `profile_ci_total_variance` nor its sibling `profile_ci_phylo_signal` appears in `NEWS.md`. Since both are absent, this is a pre-existing pattern rather than a regression introduced by #832 — but it is worth a decision before the 0.6 release slice.
- The `pkgdown` workflow carries a Node 20 deprecation annotation for `actions/configure-pages@v5`. Unrelated to this failure.

## Process note
The maintainer merged PR #861 roughly one minute after it opened, while R-CMD-check was still running and before the follow-up commits (corrected message + this report) were pushed. That is why this report lands as a separate PR rather than alongside the fix. No harm resulted — R-CMD-check on the merge commit passed — but it is the reason the two are split.
