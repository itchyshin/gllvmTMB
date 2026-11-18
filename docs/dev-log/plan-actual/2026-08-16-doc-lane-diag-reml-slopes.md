# Plan-vs-Actual — doc lane: diagnostics / REML / slopes (2026-08-16)

Plan: `/Users/z3437171/.claude/plans/glowing-soaring-pike.md` (slice table S0-S7,
fan-out budget 6 children/1 Opus). Reconciled by Melissa (Sonnet, low effort),
receipt-based, material deviations only.

## Planned vs Actual

| Axis | Planned | Actual | Match? |
|---|---|---|---|
| Scope | 3 doc slices (S1 diagnostics article, S2 REML/Cox-Reid proposal, S3 slope staging checklist), zero engine code, zero campaigns | Same 3 deliverables produced; S2's roxygen sub-item deferred (not dropped); S3 recovered 1 article (matches slice-table text, not GOAL-block headline) | Mostly — 1 scope-adjacent wording gap (GOAL block) |
| Evidence/verification | S4 mechanical: `pkgdown::build_article("fit-diagnostics")` + `devtools::document()`/`check_man()`; S5 judgment: Opus claims-vs-register review; PR CI green; after-task passes `check-after-task.R` "if available" | S4 used `rmarkdown::render` fallback against the INSTALLED package, not `pkgdown::build_article` against source (6/6 PASS, clean after fixes); `document()`/`check_man()` correctly skipped as moot (no roxygen touched); S5 Opus ran as planned, 18 findings, all disposed; `check-after-task.R` availability never checked | Partial — verification method substituted; conditional check not evaluated |
| Model routing | S0 Haiku (reused S4), S1-S3 Sonnet parallel, S5 Opus, S6 Fable(parent); repair loops "return to producers" | All model tiers matched exactly; BUT S5's 18 fixes were applied by the parent (Fable) directly, not routed back to the S1-S3 Sonnet producers, because session resume dropped the named agents | Model tiers: yes. Repair-loop routing: no |
| Safety gates | No new exports/engine edits, compute <30 min, 0.6.0 pinned, slope articles stay hidden, separation-screen framed qualitative only, design-doc number 121 claimed by commit | All held — no exports, no engine edits, recovered article parked under `dev/held-articles/`, not unhidden; no compute >30 min reported | Full match |
| Public claims | Register-bounded claims (RQR exactness, no DHARMa-equivalence, ordinal degeneracy not-detectable); GOAL block describes deliverable (3) as "the two held random-slope articles" | Delivered checklist covers ONE recovered article (slice-table S3 always said singular); GOAL-block headline text (plan line 9) still reads "two held random-slope articles" — never corrected | Deliverable matches slice table; plan's own headline is stale |
| Handoff/closure | S6: commit, rebase, PR, after-task report, check-log, AGENT_LOG + vault commit; S7 Melissa reconcile | Commit `0b899413` rebased to `0fd56e79` (one append-only conflict, keep-both), PR #1050 opened, after-task report + check-log + brain log written; `check-after-task.R` not run (availability unchecked) | Mostly — one unverified conditional check |

## Deviations

1. **S1 target: `fit-diagnostics.Rmd` extension, not new `model-checking.Rmd`.**
   Not a true plan-vs-actual deviation — the slice table already specifies
   extending `fit-diagnostics.Rmd` as a pre-approval fix from Rose's plan
   review. Actual conforms to the approved plan exactly.
   **Tag: adaptive** (justified, recorded pre-approval). Owner: n/a (closed
   before execution).

2. **S2 REML roxygen note deferred to Design 121 §7.**
   The plan itself flagged the conditional ("check lane heat first"); the
   condition fired (the file measured hot) and the anticipated branch was
   taken. Minor note: plan text names `R/fit-multi.R`, actual measured heat
   on `R/gllvmTMB.R` — a filename slip in the plan/actual record, not a
   scope change (no roxygen edit landed either way).
   **Tag: adaptive** (justified, recorded, plan-anticipated). Owner: Ada
   (scope/routing) — confirm which file the deferred edit actually targets
   before Design 121 §7 is picked up.

3. **S4 verification method: `rmarkdown::render` + installed package, not
   `pkgdown::build_article` + source package.**
   The plan's verification section names `pkgdown::build_article` against the
   fresh worktree specifically to catch pkgdown-machinery issues (index
   entries, cross-refs) that a bare `rmarkdown::render` cannot. No
   justification for the substitution is recorded in the actuals. It is
   partly mitigated here because no `R/` source changed in this lane (S2's
   roxygen edit was deferred), so installed-vs-source could not diverge in
   this instance — but the method substitution itself was not authorized and
   would not be safe practice for a lane that did touch `R/`.
   **Tag: drift** (unjustified departure from the plan's named verification
   command). Owner: domain reviewer (r-package-engineer) — confirm a real
   `pkgdown::build_article` pass before this article ships in a lane that
   also touches package code.

4. **S5 fixes applied by the parent (Fable), not routed back to producer
   agents.**
   The plan's fan-out budget states "repair loops return to producers."
   Instead the parent applied all 18 Opus findings directly. A reason is
   recorded (session resume dropped the named S1-S3 agents) and the outcome
   was tracked (after-task §9; all 18 findings applied or dispositioned,
   including a check-log flag and an excluded html artifact).
   **Tag: adaptive** (justified by a session-continuity failure outside the
   plan's control, recorded) — with a residual concern flagged, not tagged as
   drift: parent-applied fixes forgo the independent second pass a producer
   handoff would have given noisier findings. Owner: Ada (scope/routing) —
   worth a standing note that repair-loop routing needs a session-survival
   fallback in future plans, not a retroactive fix here.

5. **GOAL-block "two held random-slope articles" left uncorrected.**
   The plan's own headline (line 9) still says "the two held random-slope
   articles" for deliverable (3), even though Rose's plan-review already
   established at approval time that only one article exists in the deleted
   git history (`random-slopes-nongaussian.Rmd` at `eacbd0f6`) and the slice
   table (S3) was corrected to singular before execution. The actual
   deliverable (one recovered article + one checklist) matches the corrected
   slice table, not the uncorrected headline — so the delivered work is
   right, but the approved plan document itself carries a public-claims
   inconsistency that was never swept.
   **Tag: drift** (unjustified — the correction was made in one place in the
   approved plan and not propagated to the summary line, an easy miss to
   catch at approval time). Owner: Rose (closeout/claims) — scrub the
   after-task report and any chat surfacing of this lane to make sure "two
   articles" doesn't propagate from the stale plan text into a public claim.

6. **`tools/check-after-task.R` not run; availability never checked.**
   The plan's verification item 4 is conditional: "passes
   `tools/check-after-task.R` if available locally." A conditional check
   still requires evaluating the condition — the actuals record that
   availability was never checked, so the lane cannot claim compliance with
   even the conditional form of this verification step.
   **Tag: drift** (unjustified — checking availability costs one `ls`/`find`
   and was skipped, not deferred for a stated reason). Owner: Rose
   (closeout/claims) — run the check (or confirm its absence) before this
   after-task report is treated as final.

## Verdict

SHIP-WITH-FOLLOWUPS. Scope, safety gates, and model-tier routing held exactly;
the three drifts are all closeout/verification-rigor gaps (unverified render
method, a stale "two articles" line in the approved plan's own headline, and
an unchecked after-task-linter conditional) — none touch the fences (#897,
Design 51, 0.6.0 pin, hidden slope articles) or invent an unearned claim, but
Rose should scrub the "two articles" wording before it surfaces publicly and
confirm `check-after-task.R` before this closes for good.
