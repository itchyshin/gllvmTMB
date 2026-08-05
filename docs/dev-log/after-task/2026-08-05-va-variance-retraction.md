# After Task: VA lane — variance finding retracted, large-N gllvm result not established (closure)

**Date:** 2026-08-05 · **Agent:** Claude Code, Rose role (closer) · **Branch:** `claude/va-lane2`
**Worktree:** `/private/tmp/gllvmtmb-va-lane2` @ `728f4aa8` · **Compute:** Totoro + local Mac (D-50:
results LOCAL, nothing on GitHub Actions)

## 1. Goal

Close out a same-session, multi-agent measurement arc that re-examined two live claims in the VA
lane: (1) the 2026-08-04 handover's "the gllvm gap is VARIANCE, not a constant factor" finding
(8-seed N=120 cell, one seed 35× its own median); and (2) a 72-cell, 24-seed model-matched ladder
that appeared to show our VA engine beating gllvm's VA at N ≥ 1000. Both were adversarially
re-measured this session (`dev/va-speed/73` through `77`, consolidated in `78`). This task's job was
**closure only**: write the four durable artifacts (claims-ledger update, check-log entry,
after-task report, handover) that carry the findings forward without softening or strengthening
either conclusion, and without touching any reader-facing surface.

**Mathematical contract:** No public R API, likelihood, formula grammar, family, NAMESPACE,
generated Rd, vignette, or pkgdown navigation change. No file under `R/`, `src/`, or `tests/` was
read for editing purposes in this task, let alone modified.

## 2. Implemented

This is a documentation-only closure. What is now true that was not true before:

- The claims ledger (`dev/va-speed/20-CLAIMS-LEDGER.md`) has a durable, numbered record of the
  variance-finding retraction (new row 47) and the shared SE-matching measurement hazard (new row
  48), and claim 30's row now carries a third, dated adjudication appended in the file's own
  `→ THE ARC WAS RUN` style rather than overwriting the existing two.
- `docs/dev-log/check-log.md` has a dated entry naming the exact scripts run, what was measured,
  what was verified whole-grid (not spot-checked), and what was deliberately not run.
- This after-task report and a fresh handover (`docs/dev-log/handover/2026-08-05-claude-handover-variance-retracted.md`)
  exist so a session with no inherited chat can resume without loss.

**The outcome being closed out is two negative results and no promotion.** Nothing was shipped,
fixed, or improved: the "1-in-8 catastrophic seed" finding is retracted (it was a TMB recompile
inside a timed block, not ill-conditioning), and the "we beat gllvm at large N" finding is
downgraded to NOT ESTABLISHED (gllvm was timed computing standard errors our arm never computes,
plus a start-count mismatch against our own shipped default). No NEWS entry, pkgdown page, roxygen
block, README line, export, or validation-debt-register row was touched by this task or by the arc
it closes. The engine code under `R/` was not modified at all — this arc measured the existing
engine, it did not change it.

## 3. Files Changed

| file | change |
|---|---|
| `dev/va-speed/20-CLAIMS-LEDGER.md` | Amended claim 30's row (appended, not rewritten) with the 2026-08-05 third-attempt adjudication; added new rows 47 (variance-finding retraction) and 48 (SE-matching hazard shared by `57`/`29`/`75`) |
| `docs/dev-log/check-log.md` | Appended a dated entry: scripts run, what was measured, what was verified, what was deliberately not run |
| `docs/dev-log/after-task/2026-08-05-va-variance-retraction.md` | New — this report |
| `docs/dev-log/handover/2026-08-05-claude-handover-variance-retracted.md` | New — handover for the next session |

**Not written by this task, pre-existing and read as evidence only** (all untracked, produced by
other agents in this session before the closure task began): `dev/va-speed/73-SPLIT-RESULT.md`,
`73-split-instrumented.R`, `73-split-instrumented.rds`, `73-run.log`, `74-spec-discriminator.R`,
`74-spec-discriminator.rds`, `74-run.log`, `75-CLEAN-LADDER-RESULT.md`, `75-ladder-results.rds`,
`76-gllvm-eval-counts.md`, `77-ADVERSARIAL-REVIEW.md`, `78-VARIANCE-RETRACTION-AND-LARGE-N.md`,
`trace-gllvm-va.R`, `inventory-analysis.txt`, and `docs/dev-log/plan-actual/2026-08-05-va-variance.md`.
This task did not create, edit, or move any of them; they are listed in the handover's landing
state for the next session's benefit.

No status-inventory file (`README.md`, `NEWS.md`, `ROADMAP.md`, `docs/dev-log/known-limitations.md`,
`docs/design/01-formula-grammar.md`, `_pkgdown.yml`, any `man/*.Rd`) was touched — verified in §6.

## 3a. Decisions and Rejected Alternatives

- **Decision:** Append to claim 30's row rather than add a fourth standalone claim number for the
  third adjudication. **Rationale:** claim 30 is already the ledger's single point of reference for
  "do we have a better VA than gllvm", and the file's own convention (`→ THE ARC WAS RUN, 2026-08-04`)
  is to accumulate dated attempts inside one row so a reader following claim 30 does not have to
  cross-reference a second row for the same question. **Rejected alternative:** a new claim 49
  cross-referencing 30 — rejected because it would split one question across two rows for no
  reader benefit. **Confidence:** high.
- **Decision:** Give the SE-matching hazard its own ledger row (48) rather than folding it into
  claim 30's append. **Rationale:** the hazard is not specific to claim 30 — it also taints `57`
  and `29`, which are cited elsewhere in the ledger and in prior handovers independently of claim
  30. A reader who finds `57` or `29` cited on its own (not via claim 30) needs a way to discover
  the defect. **Rejected alternative:** a footnote inside claim 30 only — rejected because `57` and
  `29` predate claim 30's row and are referenced independently in the 2026-08-04 handover's "Next
  Immediate Steps". **Confidence:** high.
- **Decision:** Number the two new rows 47 and 48, appended after the existing last row (46) rather
  than inserted near claim 30 topically. **Rationale:** the file's row order is already not strictly
  numeric (rows 23/24/28/33–36 sit after 29/30/18 in file order), so there is no ordering convention
  to preserve beyond monotonic claim numbers; appending at the physical end keeps the diff minimal
  and matches "delta, not summary" — nothing existing was reordered. **Rejected alternative:**
  reordering the table by claim number — rejected as unnecessary churn on a file with no stated
  ordering rule. **Confidence:** medium (a future editor could reasonably prefer numeric order; not
  attempted here because it was out of this task's scope).
- **Decision:** Do not open or comment on GitHub issue #934 (the closest related open issue —
  sandwich route + speed backlog). **Rationale:** #934's ask is Arc B (sandwich scoring) and the
  speed-lever backlog, neither of which this arc touched; commenting would misattribute this arc's
  findings to an issue they don't inform. **Rejected alternative:** commenting anyway "for
  visibility" — rejected because it would be noise against #934's actual ask. **Confidence:** high.
- **Decision:** Do not soften "NOT ESTABLISHED" to any weaker qualifier, and do not describe the
  harness defects as "fixed" anywhere in the four files. **Rationale:** explicit task constraint,
  and consistent with the source documents' own verdicts (`77`, `78`). **Confidence:** high.

## 4. Checks Run

This task is documentation-only; no `devtools::test()`, `devtools::check()`, or `R CMD check` was
run or was appropriate, since no `R/`, `src/`, or `tests/` file was touched (confirmed in §6). The
checks performed were evidentiary and bibliographic, not computational:

- `git status --porcelain=v1` and `git diff --stat`, before and after editing, to confirm the only
  tracked-file modification made by this task is `dev/va-speed/20-CLAIMS-LEDGER.md`, and that no
  reader-facing path (`NEWS|README|vignettes/|man/|_pkgdown|R/|src/|tests/`) appears in the status
  output. Result: confirmed — only `dev/va-speed/` and `docs/dev-log/` paths changed.
- `grep -oE '^\| [0-9]+ \|' dev/va-speed/20-CLAIMS-LEDGER.md | grep -oE '[0-9]+' | sort -n | uniq -c`
  before editing, to confirm claims 1–46 each appear exactly once and that 47/48 were unused.
  Result: confirmed, no collision.
- `grep -c "One cell, q=1, one family. |"` and a search for the claim-46 row's closing sentence,
  to confirm both `Edit` anchor strings were unique in the file before applying them. Result: both
  unique (count 1).
- Spot-verified two source citations against `R/va-r3-proto.R` directly rather than trusting the
  producer documents: `build_dir <- file.path(tempdir(), ...)` is at line 909, and `n_starts = 4L`
  is the documented default in `.va_r3_fit()`'s signature. Result: both confirmed in source.
- `gh issue list --search "..." --state all` and `gh issue view 934`, to check for an open issue
  this arc's findings should update. Result: no dedicated issue exists for the VA-vs-gllvm
  speed/conditioning question; #934 covers an adjacent, untouched ask (see §7a).
- `grep -n -i "variational|va-speed|va-lane" ROADMAP.md` to check for a roadmap row this task might
  need to tick. Result: no matches — confirms the Roadmap Tick in §7.

## 5. Tests of the Tests

Not applicable — no test file was added or modified. This task's verification is documentary
(§4, §6), not a test suite; there is no code path for a failure-before-fix, boundary, or
feature-combination test to attach to.

## 6. Consistency Audit

Ran a narrowed subset of the standard consistency-audit patterns, scoped to confirm this
documentation-only task did not leak into reader-facing or code surfaces:

```sh
git status --porcelain=v1 | grep -E "NEWS|README|vignettes/|man/|_pkgdown|R/|src/|tests/"
# → no output (confirmed NONE touched; only dev/va-speed/ and docs/dev-log/ paths in git status)

rg "in prep|in preparation" dev/va-speed/20-CLAIMS-LEDGER.md docs/dev-log/check-log.md \
   docs/dev-log/after-task/2026-08-05-va-variance-retraction.md \
   docs/dev-log/handover/2026-08-05-claude-handover-variance-retracted.md
# → no output (no foundational in-prep citation introduced)
```

The full `AGENTS.md`/`10-after-task-protocol.md` stale-wording sweep (`Sigma_B|Sigma_W`,
`gllvmTMB\(` call-site enumeration, `meta_known_V`, `gllvmTMB_wide`, etc.) was **not** re-run in
full — it targets user-facing prose, articles, and roxygen, none of which this task touched, and
the git-status check above already confirms those trees are untouched. Running the full sweep
against files it cannot have affected would not add evidence.

**Verdict:** confirmed — this closure task touched only `dev/va-speed/20-CLAIMS-LEDGER.md` (one
tracked-file edit) plus three new `docs/dev-log/` files; no reader-facing, package-code, or test
surface was touched, and no new in-prep citation was introduced.

## 7. Roadmap Tick

**N/A.** `rg -i "variational|va-speed|va-lane" ROADMAP.md` returns no matches — this lane has no
`ROADMAP.md` row (consistent with the standing note that it is not one of the six 0.7 capability
tracks; D-113 names missing-data #332 as the primary post-0.6 slice). No row's status chip or
progress bar changed.

## 7a. GitHub Issue Ledger

- **Inspected:** issue #934 ("VA intervals: score the SANDWICH route ... + speed backlog"), the
  only open issue in this lane. Its ask is Arc B (sandwich-route scoring) and the speed-lever
  backlog. This closure task's arc did not touch either — Arc B remains untouched and deferred
  (carried forward in the handover) — so #934 was **not commented on**: a comment citing findings
  that don't inform its ask would be noise, not signal, for whoever picks it up next.
  `gh issue list --search "gllvm speed OR AC tier OR albert chib OR loadings diagonal OR
  conditioning" --state all` and a search on "VA speed"/"variational speed" found no other open or
  closed issue tracking the AC-vs-gllvm speed/conditioning question this arc measured — that
  question has lived entirely in `dev/va-speed/*.md` and the claims ledger, not the tracker, since
  it began.
- **Commented:** none.
- **Closed:** none.
- **Created:** none. This task's brief scoped exactly four files; opening a tracker issue for a
  negative result that is already fully captured in the ledger and handover was judged unnecessary
  process overhead, and is flagged as a maintainer option in §10 rather than done unilaterally.
- **Judged not relevant:** all other open issues returned by the searches above (#931, #565, #347,
  #855, #349, #340, #348, #488, #230) — none concerns VA speed, the AC tier, or the gllvm
  comparison; they surfaced only as search noise from shared keywords.

## 8. What Did Not Go Smoothly

Nothing procedurally went wrong in the closure task itself. Two things are worth recording about
the arc being closed, both already flagged by the producer documents and repeated here because a
closer's job is to make sure they survive into the durable record rather than staying in chat:

- **The claims ledger had no row at all for the variance finding before this task.** The
  2026-08-04 handover stated the "gap is VARIANCE" finding as fact, and it propagated into that
  handover's "Next Immediate Steps", but it was never entered into `20-CLAIMS-LEDGER.md` as a
  numbered claim — so the ledger, which this lane treats as the source of truth for "what still
  stands", was silently out of date with the handover for a full day. New row 47 both introduces
  and retracts it in the same edit; there was no earlier "STANDS" state to supersede.
  **Recommend the standing habit: a finding that changes a handover's "Next Steps" gets a ledger
  row in the same session it is made**, not deferred to whenever someone next measures it, so the
  ledger cannot drift behind the handover it is supposed to anchor.
- **The same harness defect (Defect A / unmatched `sd.errors`) taints three separate scripts
  (`57`, `29`, `75`) written at different times by different sessions.** `75` inherited its arms
  verbatim from `57` without re-examining the default arguments; `29` scored the same estimand the
  same way independently. This is the ledger's own "process lesson 3" (`43-va-vs-la-ladder.R`'s
  unpassed-default defect, 2026-08-03) recurring in a different pair of arguments one arc later —
  recorded as claim 48 rather than treated as three independent findings that happen to agree.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

- **Rose.** The ledger drift above (a finding live in a handover but absent from the ledger for a
  day) is exactly the kind of discrepancy this role exists to catch. It did not cause any harm here
  — the retraction landed before anyone cited the ungated claim publicly — but it is a repeatable
  gap: a handover's "what we found" section and the ledger's "what stands" table are two documents
  with no enforced sync point between them.
- **Fisher.** `75-clean-ladder.R`'s comparator harness reused `57`'s arm definitions without
  re-auditing their default arguments against what each engine actually computes — the question
  "what work does each arm do that the other does not?" (named explicitly in the session's own
  plan-actual reconciliation as the cheap countermeasure) was not asked before the campaign ran,
  only after, by a separate adversarial pass. The harness's statistics (guards, rotation, paired
  Wilcoxon) were otherwise sound; the defect was in what was being compared, not how.
- **Curie.** The 8-seed reproduction (`73`/`74`) is a clean example of the role's job done well:
  same DGP verified line-for-line against the original script, an untimed warm-up added
  specifically because the original lacked one, and run order randomised and reported rather than
  assumed neutral. It is the reason Finding 1 could be retracted with a mechanism and a number
  (24.77 s) rather than only a failure to reproduce.

## 10. Known Limitations and Next Actions

- **N=2500 SE-matched is unmeasured.** The Defect-A correction (SE-matched ratio 1.08×/0.98×) was
  only measured at N=1000, 2 seeds. Whether gllvm's heavier N=2500 tail is optimisation or the SE
  pass is open. See the handover's OWED list.
- **The `tempdir()`-scoped DLL cache (`R/va-r3-proto.R:909`) remains a live hazard for every future
  timing script in this lane**, not just the one that produced the retracted finding. It was
  diagnosed, not fixed, in this arc.
- **Arc B (sandwich-scoring timed pilot) is untouched**, and issue #934 is the tracker record for
  it — this closure did not advance or comment on it (§7a).
- **Whether this lane continues at all is a maintainer decision**, carried forward from the prior
  handover and restated in the new one: D-112/D-113 mean this lane is not one of the six 0.7
  capability tracks, and missing-data #332 remains the named primary post-0.6 slice.
- **The claims ledger's row-ordering is not numeric** (noted in §3a as a rejected alternative); a
  future pass could renumber for readability, but that was out of scope here and touches many
  existing rows for a purely cosmetic gain.
