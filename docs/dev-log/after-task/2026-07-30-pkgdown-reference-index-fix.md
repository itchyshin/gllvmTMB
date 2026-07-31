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

## THE RECURRENCE — this is the fourth time, and the guard has never been built
Found while filing this report, and it is the most important thing here. **This is not a one-off.** The same defect class — a documented export missing from the `_pkgdown.yml` reference index, breaking the docs build on `main` — has now happened at least four times:

| date | report | what was missing |
|---|---|---|
| 2026-05-31 | `2026-05-31-pkgdown-phylo-signal-mi-hotfix.md` | `check_pkgdown()` failing on `main` |
| 2026-06-17 | `2026-06-17-pkgdown-julia-index-main-repair.md` | `gllvm_julia_fit`, `gllvm_julia_setup` |
| 2026-06-21 | `2026-06-21-pkgdown-reference-index-fix.md` | **3 topics** missing from index |
| 2026-07-30 | this report | `profile_ci_total_variance` |

Worse: **three of those reports already name `pkgdown::check_pkgdown()` as the right reproducer** — 2026-05-31 calls it "the right local reproducer," 2026-06-17 records it as the verification command — and `grep -rn "check_pkgdown" .github/workflows/` returns **nothing**. The guard has been identified repeatedly and built zero times. Each session diagnosed correctly, fixed the instance, recommended the guard, and moved on; the next session then paid the same cost.

That reframes the follow-up below. It is not a nice-to-have — it is the actual fix for the recurring problem, and writing "worth considering" a fourth time would just continue the pattern.

## Follow-up (not done here — deliberately deferred, with a reason)
Reference-index completeness is **invisible to `R CMD check`**, so this class of breakage is structurally undetectable until after merge to `main` — which is why it burned 13 runs before being noticed. `pkgdown::check_pkgdown()` runs in seconds without a site build and would catch it pre-merge, matching the standing "local checks over CI" rule.

It is deferred rather than bundled because wiring it in correctly is a real design task, not a one-liner, and getting it wrong gates every PR in a repo mid-release-prep. What the next session needs to decide, with the groundwork already done:

- **Insertion point:** `.github/workflows/R-CMD-check.yaml`, after the `setup-r-dependencies` step (currently line ~201, `extra-packages: any::rcmdcheck` → add `any::pkgdown`), before `check-r-package`.
- **The scoping wrinkle:** that workflow gates its heavy steps on `steps.scope.outputs.full_required == 'true'`, with a "Fast pass" branch for ignored-source/process changes. A PR that edits **only** `_pkgdown.yml` may take the fast path — so a guard gated on `full_required` would miss exactly the config-only PRs most likely to break the index. The check should run on both branches, which means R must be available in the light path too (`light_r_required`).
- **Open question to resolve first:** whether `pkgdown::as_pkgdown(".")` works without the package installed. It reads DESCRIPTION and `man/*.Rd` from source, which suggests yes, but this was only verified locally where gllvmTMB *was* installed. If it needs the installed package, the step must run after the build rather than before — which changes both cost and placement. The cheapest way to settle it is to let the guard's own PR run be the test.

Secondary observations, noted rather than silently fixed:
- Neither `profile_ci_total_variance` nor its sibling `profile_ci_phylo_signal` appears in `NEWS.md`. Since both are absent, this is a pre-existing pattern rather than a regression introduced by #832 — but it is worth a decision before the 0.6 release slice.
- The `pkgdown` workflow carries a Node 20 deprecation annotation for `actions/configure-pages@v5`. Unrelated to this failure.

## Process note
The maintainer merged PR #861 roughly one minute after it opened, while R-CMD-check was still running and before the follow-up commits (corrected message + this report) were pushed. That is why this report lands as a separate PR rather than alongside the fix. No harm resulted — R-CMD-check on the merge commit passed — but it is the reason the two are split.
