# Plan-vs-actual reconciliation — categorical follow-ups (#1098 · #1097 · #1099)

**Reconciler:** Melissa. **Plan:** `~/.claude/plans/read-agents-md-and-docs-dev-log-handover-warm-biscuit.md`.
**Actual:** three worktrees / PRs as given in the task brief. All commands below were run directly
against the three worktrees and `gh` against `itchyshin/gllvmTMB`; nothing here is taken on the
plan document's word.

## Summary

The programme executed close to plan. All three lanes landed as open PRs with after-task reports,
check-log entries, and register rows; the DEFER fence held completely (verified by diff-grep across
all three lanes' file lists — zero touches to `R/mspl*`, isdm paths, Design 84, Design 66, VA-vs-Laplace,
CRAN-shaped work, or the five previously-eliminated ordinal candidates); the B4 D-139 gate correctly did
not fire (measured pilot came in under 30 min, exactly as the plan's own row anticipated); B2's Opus-only
adversarial review did its job and forced a real B1 revision; A0/C0 were added exactly as the plan's
Rose-review record says. One clear, material drift: the plan's own D-43 panel trigger ("a shipped
threshold in A3") was not honored for lane A's `loading_absolute_thresh` 6→8 change, and — unlike lane
B, which explicitly surfaced the D-43 question to the maintainer even though its own trigger condition
did not fire — lane A's PR and after-task never raise it. Everything else classified below is adaptive
(recorded, reasoned) or a handoff-state note, not drift.

**Counts:** 1 drift · 8 adaptive · 2 unclear.

## 1. Scope

**Adaptive.** A0 (`a0-pool-scout`) and C0 (`c0-data-scout`) were added exactly as the plan's Phase-2
review record states, and both did real work: A0 recovered a pool the plan's own BLOCKING finding said
might be unrecoverable (`totoro:~/gllvm_work/results/design108-stage8-grid.csv`, confirmed retrieved
per the after-task and PR #1110 body, kept off-repo), and C0 corrected a scout report before it shipped
(verified the four archive URLs itself: `accipitridae_sampled.csv`/`.nex`, `turdidae.csv`/`trees.nex`,
all HTTP 200, CC BY 4.0).

**Adaptive.** B2 returned BLOCK, forcing a B1 revision — confirmed in the EXECUTION LOG and independently
visible in `dev/ordinal-degeneracy/pass-criteria-curvature.md`'s own "Review history"/"Pushback" sections
(git-diffed, present in the landed commit `1bee9bf0`). The FP-scoring denominator was narrowed
(`scale_boundary` stratum moved to reported-only), the primary Arm C statistic changed from a naive
conditional block to the Schur complement of `cov.fixed`, and Arm D was honestly restated as
single-statistic rather than a claimed ratio/absolute pair — all three changes are visible in the frozen
document and cross-checked against the after-task's "Decisions and Rejected Alternatives" section.

**Adaptive.** B6 (fresh-scorer) and B7/B8 executed. Confirmed: `dev/ordinal-degeneracy/results/scoring-verdict.md`
exists and states it was produced by an agent "with no design-discussion context"; B7 landed as commit
`1bee9bf0` (PR #1115) recording the ship-disarmed verdict.

**Unclear (minor).** B8 ("MECHANICAL-VERIFY … after B7 touches `R/diagnose.R`") has no evidence of having
run at all — `git show --stat 1bee9bf0` shows zero `R/`, `src/`, or `tests/` files touched, and neither
the after-task report nor the check-log entry for lane B mentions running `devtools::test()` or
`R CMD check` (grepped both files for `devtools::test|devtools::check|R CMD check|rcmdcheck`: zero hits
inside lane B's own entries). The underlying justification is sound — B7's actual outcome was
ship-disarmed, so `R/diagnose.R` was never touched and there is nothing to mechanically verify — but
lane A's after-task explicitly itemizes what it deliberately did *not* run and why ("Deliberately NOT
run: full `devtools::check()` …"), while lane B's simply omits the row without saying so. Not a
correctness risk (verified independently: no R/ file changed), but a documentation-discipline gap
relative to lane A's own standard. Route: **Rose** (closeout/claims consistency).

**Adaptive.** Model routing held: `a0-pool-scout`, `a1-attribution`, `b1-prereg`, `b2-adversarial`,
`b6-fresh-scorer`, `c0-data-scout`, `c1-vignette-data` match the plan's per-row agent list; B2 is
confirmed as the one Opus child ("The Opus adversarial review rejected the pre-registration with four
blocking findings" — EXECUTION LOG, corroborated by the pushback sections in the frozen document
itself). No second Opus child found anywhere in either lane's artifacts.

## 2. Evidence / verification

**Adaptive.** Lane A's headline number was independently reproduced by command, not merely asserted:
`OPENBLAS_NUM_THREADS=1 Rscript --vanilla dev/heywood/fp-attribution.R` is recorded as reproducing
`n=928, WARN=232, FPR=0.2500` exactly, and `devtools::test(filter="runaway|diagnose|sanity")` is recorded
as run **twice** by the builder and once more independently by the coordinator, all three runs agreeing
at `0 failures / 174 passing`.

**Adaptive.** Lane B's campaign was pre-registered before scoring (frozen `pass-criteria-curvature.md`
mtime `18:07:31`, scored run starting `18:19`, both timestamps stated as filesystem-verifiable in the
after-task) and scored by an agent walled off from the design discussion — the two guards the brain's
binding note on this exact failure mode calls for. Independence precondition (statistic vs. the
already-eliminated `max_loading_unit`) was checked and passed (`r = 0.538`, `r = -0.452` against a `0.8`
refusal bar) before the null was accepted as informative rather than a disguised repeat.

**Adaptive.** Lane C's no-network smoke is not just claimed — the PR body states it "caught a real bug"
(an unguarded `ggplot()` chunk), and the after-task separately states the fix was re-verified by
text-extracting the rendered HTML. This is falsifiable evidence of the C3 no-network smoke actually
running, not a restated intention.

**Unclear.** Lane B's PR #1115 shows **zero triggered CI check-runs** as of this reconciliation
(`gh api repos/itchyshin/gllvmTMB/commits/1bee9bf0.../check-runs` → `"total_count":0`), even though
`R-CMD-check.yaml` triggers on any `pull_request` targeting `main` with no path filter. The PR was
created only ~4 minutes before this check, and the Actions queue is visibly saturated (several other
lanes' runs `in_progress` concurrently in this 28-lane-active repo), so this reads as a queue delay
rather than a confirmed gap — but it is not yet resolved as of this report and should be rechecked.
Given B7 touched no `R/`/`src/`/`tests/` file, a green or absent CI run does not change the substance
of the landed claim either way.

## 3. Model routing

**Adaptive** — covered under Scope above (Haiku scouts for A0/C0, Sonnet-high builders for A1/B1/B7/C2,
the single Opus child at B2, Sonnet-medium for B3/C1, fresh-context Sonnet-high scorer at B6). No
deviation found.

## 4. Safety gates

**Adaptive.** D-50 (campaign results off-repo) was honored correctly and unevenly-but-appropriately
across lanes: Lane A's pool-2 CSV (3,600 fits, Totoro-scale) was confirmed **not** committed — verified
by `git show --stat` on both lane-A commits (no CSV in the file list) and the after-task's own statement
("Pool 2's 3,600-fit CSV was generated on Totoro and deliberately never committed to this repo (D-50)").
Lane C committed **zero** data files (`git show --stat` on both lane-C commits: only `.Rmd`, one `.R`
fetch script, `_pkgdown.yml`, and dev-log docs). Lane B **did** commit its 450-fit campaign CSV
(`dev/ordinal-degeneracy/results/campaign-curvature-scored.csv`, 96 KB) plus several smaller pilot/smoke
CSVs — checked against repo convention rather than assumed to be a violation: `git log --all
--diff-filter=A --name-only -- 'dev/**/*.csv'` returns **1,609** historically-committed dev CSVs
(e.g. the entire `dev/aghq-evidence/` corpus), and `.gitignore` explicitly excludes only large,
Totoro/DRAC-scale runtime directories by name (`dev/m3-pilot-results/`, `dev/va-gate3/results/cells/`,
`dev/isdm-package-recovery/results/`) — nothing matching `dev/ordinal-degeneracy/results/`. D-50's
"off-repo" rule reads, by established local convention, as binding on GB/Totoro-scale campaign output,
not on a 96 KB / 450-row local evidence CSV of the kind this repo routinely commits. **Not drift.**

**Adaptive.** Pre-registration freeze is provable, not merely asserted, for lane B: the after-task cites
a filesystem mtime (`18:07:31`) preceding the scored run's start (`18:19`), and the frozen "Scoring rule"
text in `pass-criteria-curvature.md` is stated to be unedited, with the scorer's three found ambiguities
recorded as a clearly-separated post-hoc amendment rather than silently folded into the frozen text —
checked directly in the file, not taken on the after-task's word.

**Drift.** The plan's own D-43 checkpoint (`## Checkpoints where I stop for Shinichi`, item 3: "Any
milestone claim → D-43 panel (2 Sonnet + 1 Opus, fresh contexts) before the claim ships") and the
`D-43 PANEL` line under `ESTIMATE`/`VERIFY` explicitly names two trigger conditions: *"a re-armed screen
in B6, or a shipped threshold in A3."* Lane A **did** ship a threshold change (`loading_absolute_thresh`
6 → 8, a stated "BEHAVIOUR CHANGE" in both `NEWS.md` and the PR body). No D-43 panel evidence exists
anywhere in lane A's artifacts — grepped `docs/dev-log/after-task/2026-08-17-binomial-screen-fp-attribution.md`,
`dev/heywood/fp-attribution-findings.md`, and lane A's check-log entry for `D-43|D43|panel`: zero hits.
Contrast with lane B, whose verdict did **not** meet either trigger condition (ship-disarmed, nothing
re-armed) but which still surfaced the D-43 question explicitly to the maintainer in its PR body ("🔴
Needs you: Whether to fire a D-43 completion panel … Your call"). Lane A does the opposite: it ships the
one change the plan itself named as a D-43 trigger, and neither runs the panel nor asks the maintainer
whether to. This is not a correctness problem — A3's evidence chain is independently strong (exact
reproduction, failure-before-fix test, maintainer sign-off at A2 on the fix shape) — but it is an
unrecorded, undisclosed skip of a checkpoint the plan itself declared binding. **Route: Ada** (the
checkpoint's own owner per the plan's `Checkpoints` section) for a call on whether to run D-43 now,
retroactively, or explicitly waive it in the closing record; secondarily **Rose**, since the gap should
have been visible to a closeout QA pass and wasn't flagged in lane A's own after-task the way lane B
flagged its own (non-triggered) case.

## 5. Public claims

**Adaptive — verified, not just read.** Lane A's "100% of FPs from one arm" claim: checked against
`dev/heywood/fp-attribution-findings.md` and the after-task's Checks-Run section, which states the
attribution script reproduces `n=928, WARN=232, FPR=0.2500` exactly and that `runaway_loading` fires 0
times / `extreme_magnitude` fires 232/232 — matches the PR body's table exactly.

**Adaptive — verified.** Lane B's null verdict: PR body states Arm C sensitivity "1.1–5.3%", Arm D
"7.3%", combined "7.3%" against a ≥90% target — matches `scoring-verdict.md` and the after-task's §4
Checks Run section word-for-word on the key numbers; independence precondition values (`r = 0.538`,
`-0.452`) also match across all three documents (PR body, after-task, register row).

**Adaptive — verified.** Lane C's fit results and withheld correlation: read directly in the rendered
`vignettes/articles/phylogenetic-categorical-pglmm.Rmd`. The Example-2 among-category correlation is
genuinely not computed/shown for that example (only `extract_phylo_signal()`'s per-contrast H² is
called; `extract_correlations()` is not invoked for Example 2 in the article), with an explicit callout
box stating why. H² numbers in the PR body (migration ≈0.41–0.45, habitat density ≈0.87; per-contrast
0.70/0.74) match the after-task report and the Rmd's own code path.

## 6. Handoff state

**Handoff note (not drift).** All three PRs (`#1110`, `#1115`, `#1112`) are `state: OPEN`,
`mergedAt: null`, and — as of this check — `mergeable: CONFLICTING` against current `main`
(`origin/main` @ `2b321296`, which has advanced by several merges from each lane's branch point at
`40a41e32` — other foreign lanes, per the plan's own PREFLIGHT warning of "28 lanes live"). This is the
expected shape of three parallel long-lived branches in a 28-lane-active repo, not a content collision
between the three plan lanes themselves: lane A and lane B both touch `docs/design/35-validation-debt-register.md`
but on different rows (DIA-08 vs. FAM-14 — diffed directly, no overlapping lines), and all three touch
`docs/dev-log/check-log.md` only by append. None of the three PRs is merged; merge order and conflict
resolution are still open work for the maintainer or a future session.

**Handoff note.** Working trees are clean in all three worktrees (`git status -sb`: no uncommitted
changes anywhere) and all three branches are pushed to `origin` (confirmed by `git ls-remote` for lane B,
whose local branch lacked an upstream-tracking pointer — cosmetic only, the SHA matches the PR's
`headRefOid` exactly).

**Handoff note.** The plan document's own `EXECUTION LOG` is stale relative to landed state: it stops at
"C2 — in flight," but both lane B (through B7) and lane C (through C3, including a green CI run) are
fully landed as open PRs. This reconciliation reconstructed B7/B8/C3 status from the repo directly
rather than from the plan document, per the task brief's own instruction. Worth a follow-up append to
the plan document's log before it is treated as the closing record, independent of this report.

## Recurring drift classes

None rise to a pattern across all three lanes — the one confirmed drift (D-43 skip) is lane-A-specific
and the one documentation-discipline gap (B8) is lane-B-specific. The one soft pattern worth naming:
**self-disclosure of process shortcuts is uneven across lanes.** Lane A's after-task explicitly names a
role-compression shortcut it took (Fisher self-applying Rose's cross-file consistency role rather than
spinning up a distinct reviewer identity, flagged in its own §8) and explicitly itemizes what it
deliberately did not run and why. Lane B goes further and proactively raises an out-of-scope-trigger
question (D-43) that didn't even need asking. Lane A, by contrast, does not raise the D-43 question its
own shipped change actually triggers. If this program continues, the fix is procedural, not technical:
every lane's after-task should carry an explicit "checkpoints checked against the plan" line, the way
lane B's "Needs you" section models, rather than leaving a reconciler to notice the asymmetry after the
fact.
