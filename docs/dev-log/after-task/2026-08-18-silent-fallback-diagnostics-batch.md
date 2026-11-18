# After-task: the silent-fallback diagnostics batch (#1083, #1119, #1120)

**Date:** 2026-08-18 · **Platform:** Claude Code · **PRs:** #1140, #1141, #1142 (all merged)
**Branches:** `claude/fix-1083-saturation-families`, `claude/fix-1119-boundary-blindspots`,
`claude/fix-1120-family-swap` — all `ahead=0` of `main`, working trees clean.

## Task goal

Close three unclaimed defects from the open-issue board, all instances of one class: **the code hit an
ambiguous or unsupported case, silently chose a fallback, and reported success.**

## Mathematical contract

**No likelihood, family, parameterisation or formula-grammar change.** No new public export. The
family→trait *binding* is corrected in #1120 — the model a user's data is fitted under may change,
because previously it could silently be the wrong one — but no likelihood was rewritten.

All three are **behaviour changes** at the diagnostic/validation surface:

- **#1120** — genuinely ambiguous mixed-family input now **aborts** where it previously fitted silently.
- **#1119** — collapsed spatial/kernel Psi now **flags** where the screen was previously blind.
- **#1083** — Gamma/Beta/student-t saturation now **warns** where it was previously silent.

## Files changed

| PR | files |
|---|---|
| #1142 (#1120) | `R/fit-multi.R`, `R/gllvmTMB.R`, `R/families.R`, `man/families.Rd`, `NEWS.md`, `tests/testthat/test-mixed-family-unnamed-swap-1120.R` (new), `tests/testthat/test-lme4-style-weights.R` |
| #1141 (#1119) | `R/diagnose.R`, `NEWS.md`, `tests/testthat/test-boundary-flags-1119.R` (new) |
| #1140 (#1083) | `R/predictive-diagnostics.R`, `NEWS.md`, `tests/testthat/test-saturated-residual-continuous-families.R` (new), `tests/testthat/test-predictive-diagnostics.R` |

No README, ROADMAP, vignette or register row moved: no advertised capability changed tier. `man/families.Rd`
regenerated via `devtools::document()`, never hand-edited.

## Checks run, with outcomes

- #1120: `test_local(filter="mixed|family|sanity")` → **0 failures**; `test-multinomial.R` and
  `test-isdm-public-door.R` individually → 0 failures each. CI green on `f84d58bd`.
- #1119: `test_local(filter="diagnose|boundary|sanity|spatial|kernel")` → all pass; re-run under
  `GLLVMTMB_HEAVY_TESTS=1` scoped to spatial-unique/kernel-unique/coevolution/mapped-off/1119 → all pass,
  **no pre-existing fixture began flagging**. CI green on `30839f2b`.
- #1083: first CI run **FAILED** (see below); after fix, `test_local(filter="predictive-diagnostics|saturat|residual")`
  → **387 passing, 0 failures**. CI green on `5e482655`.

**Deliberately not run:** the full heavy suite (very long). Scoped instead to the files most likely
affected, and said so rather than implying full coverage.

## Consistency audit

Verified present on `origin/main` after merge, not merely "merged": `#1083` gate `0L, 3L, 4L, 7L, 9L`
(1 hit), `#1119` `sd_spde_unique` (5 hits), `#1120` `resolve_unnamed_family_list` (2 hits across both sites).

## Tests of the tests

The load-bearing part of this batch.

1. **#1120's fix contained a bug caught by its own test.** `vapply()` over a character vector auto-names
   its result (`USE.NAMES` defaults `TRUE`), so `identical(name_idx, pos_idx)` compared *names* and
   spuriously flagged disagreement on an all-agreeing case. It surfaced only because the brief required a
   test for the **agreement** branch — the boring one — not just the swap.
2. **An existing test's assertions were circular.** `test-lme4-style-weights.R` defined "binomial rows"
   *via `family_id_vec` itself*, so **a real swap would have passed it unnoticed**. Its comment also
   documented the alphabetical sort as if it were the contract. Fixed in **its own commit** (`f84d58bd`)
   with the reasoning recorded, and it now asserts the pairing against ground-truth trait labels —
   a test that pinned a defect must not be updated quietly, or a later reader cannot distinguish it from
   weakening a test to make a fix pass.
3. **Pre-fix failure proven** for every new test, by checking out the parent commit and running them there.
   Where a test exercises a function that did not exist pre-fix, that is stated plainly rather than dressed
   up as a pre-fix failure.

## What did not go smoothly

1. 🔴 **A filtered test run gave false confidence.** #1083's local verification used
   `filter="saturat|residual|sanity|conditional"`, which **does not match the filename
   `test-predictive-diagnostics.R`** — where two tests pinned the warning string the PR legitimately
   changed. CI caught it in one pass. **Rule: filters match FILENAMES, not content; grep the test tree for
   the literal phrase before trusting any filtered run** after changing user-facing text.
2. 🔴 **Two lanes claimed #1120 simultaneously.** Both ran the same unclaimed check (no assignee, no
   comments, no branch, no PR) and both got a false clear, because the other lane was working **locally and
   unpushed** — invisible to every check available. Resolved under D-87 by the maintainer, not by push
   order. Both lanes stood down, which briefly left the bug ownerless; that inversion had to be surfaced
   rather than executed literally.
3. **Six CI cancellations** across the session's PRs, from the concurrency group under heavy lane traffic.
   Consequence worth knowing: **a PR can display a green check belonging to a superseded commit.** Verify
   `headSha` against the branch head before trusting it.
4. **A conflict-resolution script of mine left stray markers** on one branch, pushed before being caught.
   Repaired; `main` verified clean afterwards across all five branches the script had touched.

## Team learning (roles engaged)

**Gauss** — carried #1083. The exclusion argument is the substance: continuous densities (gaussian,
lognormal, Gamma, Beta, student-t) can diverge as dispersion degenerates; discrete pmfs bounded by
probability 1 structurally cannot. A 15-seed sweep confirmed inclusion (Gamma `phi_gamma` past 1e6 in
9/15; student to 0.0042 in 6/15; Beta past 1e8 in 2/15) **and a Poisson control confirmed the exclusion** —
testing the boundary, not just the claim. Tweedie flagged as genuinely uncertain and left out rather than
guessed. Watch for: the same reasoning will be demanded if anyone widens this gate again.

**Curie** — the three "did it reproduce?" gates. **Four of four issues were wrong or incomplete as filed**,
and every one surfaced only because work began by reproducing the claim rather than implementing it.
#1083's premise was half-superseded (PR #1094 had already done gaussian+lognormal, and the headline
"0.00064 silent collapse" was deliberate *announced* auto-suppression). #1119's second quantity was a trap.
#1120 had an unfound second site.

**Rose** — the completeness sweep. #1120 enumerated every other `sort(unique(...))` on a user-facing
grouping column, the trait-level derivation, and the wide `traits()` path, each with an affected /
not-affected verdict. That is what surfaced `expand_multinomial_response()` as a **second,
independently-reachable site running earlier than the first** — the finding that would otherwise have made
a "fixed" claim false. An unenumerated completeness claim is the most likely way a PR of this shape gets
refuted.

**Fisher** — #1119's near-miss. The issue asked for two quantities to be added to the boundary screen;
adding the second naively would have **false-fired on every 2+-named-kernel fit**, because
`sd_kernel_diag` is currently an all-zero placeholder (the R-level grammar hard-blocks a fitted kernel-tier
Psi). That would have manufactured a new false-positive class — the same pattern #1114 fixed for
`sd_B`/`sd_W`, in a package that had just spent an arc on a screen with a measured 25% false-positive rate
(#1098). Wired inert behind a `kernel_has_diag` filter instead, self-activating when the block lifts.

**Shannon** — the lane collision. Pre-flight and the repo checks both reported #1120 unclaimed and both
were wrong, because an unpushed local lane is invisible. The honest limit of the tooling; the recovery was
direct peer messaging plus escalation to the maintainer.

**Ada** — routing and the design adjudication. The shipped contract came from **`gllvmTMB_main2`**, who
filed the issue, briefly held the lane, stood down the instant a collision surfaced, and then handed over a
design better than either competing brief. The testability argument came from the iSDM lane
(`gllvmTMB_sdm3`). Recorded because the cross-lane outcome beat what any single lane would have shipped.

## Follow-ups

- **#1149** (filed) — ten `family_id` branches of `.gllvmTMB_family_cdf_args()` with no test coverage.
  Not a suspected bug: all ten were hand-verified against `src/gllvmTMB.cpp`. A regression-coverage gap.
- **#1134** (filed) — Design 123 presents univariate-PMM and ordinal-phylo rows as covered; nothing
  exercises them at T=1, and they do not fit. Read as a scope boundary per `AGENTS.md` line 87.
- **#897 / #1097** remain open. The curvature and multi-start campaign eliminated candidates six and seven;
  `dev/ordinal-degeneracy/pass-criteria-curvature.md` §8.2a lists all seven dead ends so a future attempt
  does not retry them. Released to any lane that wants it.
- **Tweedie** for the #1083 gate — uncertain, deliberately excluded, would need its own evidence.

## The class this batch belongs to

Seven instances in three days across four lanes: #1120's swap (×2 sites), `fitted()` silent NULL,
`deviance()` silent NULL (#1118), `predict()` dropping RE tiers **while printing "Random effects have been
added"**, `predict()`'s `re_form` read only as literal `~0`, and #1098's screen crying wolf 25% of the time.

Every one is a **defensive** branch that succeeded at not crashing, by not telling anyone. The mild form
returns a silent NULL; **the dangerous form emits a reassuring message, because that defeats the reader's
own check.** The #1120 contract generalises as the remedy: compute both readings, stay silent when they
agree, abort loudly when they differ — informative exactly when it fires, and testable by construction.
