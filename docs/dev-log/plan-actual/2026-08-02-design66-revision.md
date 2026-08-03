# Plan vs Actual: Design 66 capstone revision (2026-08-02)

**Plan:** `/Users/z3437171/.claude/plans/merry-marinating-lake.md` ("merry-marinating-lake")
**Branch:** `claude/capstone-scope-20260802` · **PR:** #914
**Reconciler:** Melissa (Phase 4.5, light receipt-based reconciliation)
**Commits in range** (`git log origin/main..HEAD`): `9663cebf` (audit) → `d9331174`
(integration) → `6286be09` (audit correction + §10 xref fix) → `fa6cb152` (CRAN residual
sweep). `git diff --stat origin/main...HEAD`: 4 files, 1152 insertions(+), 51 deletions(-),
all under `docs/`.

This is a receipt check against the plan's own contract (slice table, FAN-OUT BUDGET,
VERIFY, "Explicitly NOT in this arc") — not a re-review of the method content, which the
domain reviewers (Rose, Fisher) already covered inline in the plan and which Melissa does
not re-litigate here.

---

## 1. Planned vs actual

| Axis | Planned | Actual | Match? |
|---|---|---|---|
| **Scope** | One docs-only PR: revised Design 66 + audit + cascade (issue #349 body, check-log, after-task report). | 4 commits, `docs/` only (confirmed: `git diff --stat -- R/ src/ tests/ NAMESPACE DESCRIPTION` empty). Cascade delivered: #349 **and** #345 (plan explicitly added #345 as a Rose finding), check-log entry, after-task report, **plus** a fourth artifact the plan named but did not itemise as a deliverable — this reconciliation doc. | Match, plus the two extra same-day correction commits (adaptive, see §2). |
| **Six findings applied** | S-1 (n_boot ceiling), S-2 (interval-arm reopen), S-3 (CRAN reframe), S-4 (kernel-engine correction), S-5 (oracle section), S-6 (compute-admission gap). | All six landed in `docs/design/66-capstone-power-study.md`: §8 n_boot floor table, new §3.4 open decision, §0/§2/§10 CRAN reframe (plus two residuals swept in `fa6cb152`), §3/§4.1/§4.5/L-e kernel correction, new §6A oracle section, §10 DoD item 1 (compute-admission). | Match. |
| **§3 fencing (S1 line-range assignment)** | S1 assigns disjoint line ranges within §3 to S2 vs S4 so the two drafts never collide there. | Held. §3's Gamma/coevolution bullet (S2) and estimand/CI paragraph (S4) never overlapped; confirmed at integration time and re-confirmed here by rereading the integrated §3. | Match. |
| **§10 fencing** | Not planned. §10 is assigned to **both** S2 ("§0/§2/§10 framing") and S4 ("§10 DoD") in the slice table, with no line-range fence the way §3 got one. | Collision occurred: both S2's and S4's OLD blocks contained the original items 4–5 verbatim. Caught during integration (Emmy's own overlap check, not an S1 fence), resolved by sequencing (S2's site applied before S4's), but left a broken cross-reference ("item 2" → should be "item 3") that shipped in `d9331174` and was fixed same-day in `6286be09`. | **Drift** — see §2, item D1. |
| **Model routing** | S1=haiku/low, S2=sonnet/medium, S3=sonnet/high, S4=fable/high (ceiling), S5=sonnet/medium, S6=haiku/low. | Cannot be independently confirmed from git. Commits `9663cebf`, `6286be09`, `fa6cb152` (audit + both post-hoc corrections) carry `Co-Authored-By: Claude Fable 5` — consistent with orchestrator-authored work (plan header: "session model is Fable 5"). `d9331174` (the S5 integration commit) carries `Co-Authored-By: Claude Opus 5`, which does not match the plan's `sonnet, medium` assignment for S5 — **but** this trailer is drawn from the Bash tool's own boilerplate commit template and is not reliable evidence of the model that actually ran the slice. | **Unclear** — see §2, item U1. |
| **S1 recon accuracy** | S1 (haiku) inventories every "profile" mention for S2/S4 to draft against. | S1 reported 3 mentions; actual count was 5 (missed L101, L207). Caught by the orchestrator before drafting finished; the two missed lines were handed to S4 explicitly. No site was lost in the final document. | **Drift, caught** — see §2, item D2. |
| **S5 integration diff-check** | "Diff-checks S2/S4 for §3 hunk overlap before applying" (Rose finding ②). | Performed, and — because the check as executed was not scoped only to §3 — it also caught the unplanned §10 overlap (D1). The plan's own verification language named only §3; the broader check is why D1 was caught at all rather than shipping silently. | Adaptive (the check was written more broadly than the plan's own wording, and that saved the arc). |
| **S6 verification** | Re-run the audit's ledger greps; assert "no CRAN-gate language" among other checks, ALL PASS gates the merge. | S6 returned ALL PASS on 6 checks. Its own CHECK 1c surfaced a residual ("paper/CRAN claims", §4.1) but scored it a pass anyway. A second residual (§7.2, "the headline CRAN gate") was not found by S6 at all — an orchestrator sweep found it. Both fixed in `fa6cb152`, after the PASS verdict had already been returned. | **Drift** — see §2, item D3. |
| **Safety gates — LOCKED §12** | §12 addenda append dated corrections; superseded text retained verbatim, no L-row reversed. | Confirmed: preamble, L-a, L-c, L-e each retain their pre-2026-08-02 text verbatim above a `**2026-08-02 addendum --**` block (reconfirmed by rereading §12 in the final doc). No L-row content altered. | Match. |
| **Public claims — audit's own compute-saving figure** | Plan already carried one correction (Fisher, in-plan review: audit's "order of magnitude" → "~1.1×–3.3×"). Not flagged as needing a *second* correction. | S4, drafting against the actual code, found even the plan's own corrected figure wrong: the off-diagonal target runs over `combn(5,2)=10` pairs, so it's 5 or 15 scalars per replicate, not ~6, and the profile arm can be **1.05×–1.95× more expensive**, not uniformly cheaper. Withdrawn in place in `6286be09`, superseded text quoted verbatim rather than deleted, matching the file's own locking convention. | Adaptive — the arc's own verification loop caught its own planning-stage error before it reached the merged doc; see §2, item A1. |
| **Handoff state** | S5 opens the PR; Melissa reconciles via `SendMessage` reuse of S5 (no new agent). | PR #914 open, all cascade items present. This reconciliation is written directly rather than via reused S5 context (Melissa here is a role reassignment mid-session on the same worktree, not a fresh `SendMessage` to a persisted S5 agent) — functionally equivalent outcome, immaterial to the deliverable. | Match (cosmetic difference only). |
| **Fan-out budget** | `checkpoint=design66-revision`, `new children = 6/6`: scout=2 (S1,S6), build=3 (S2,S3,S5), ceiling=1 (S4). All six slices (S1–S6) accounted under one checkpoint. | The `design66-revision` checkpoint's 6 slots were actually consumed by S1, S2, S3, S4 **plus the two plan-review agents Rose and Fisher** — not by S5 and S6 as the FAN-OUT BUDGET line's own arithmetic implies. This left S5 and S6 unbudgeted under `design66-revision`; the user issued a new checkpoint ("the rest!"), under which S5 and S6 ran as `design66-integration`. | **Drift in the plan's own accounting, handled adaptively at runtime** — see §2, item D4. |
| **"Explicitly NOT in this arc"** | No compute; no decisions resolved; `stash@{0}` untouched; #911 untouched; Dropbox checkout untouched. | All four held — verified against git, not assumed. See §3. | Match. |

---

## 2. Tagged deviations

### Drift

**D1 — §10 was never fenced, and the collision it caused shipped a broken cross-reference.**
The plan fenced §3 explicitly (S1 assigns disjoint ranges; Rose's review finding ② calls
this out by name) because S2 and S4 were both known to touch it. It did not extend the same
treatment to §10, despite assigning **both** S2 ("§10 framing") and S4 ("§10 DoD") to edit
it in the same slice-table row. The collision was real: both patches' OLD blocks contained
the original Definition-of-Done items 4–5 verbatim. It was caught and sequenced correctly
during integration (apply S2's site first, since S4's item-renumbering would otherwise
invalidate S2's verbatim match) — but the sequencing didn't repair a **content** consequence:
S2's added paragraph says "This changes how item 2 above is read," and S4's renumbering
(inserting a new item 1) silently shifts that reference to item 3. This defect shipped in
`d9331174` and reached the PR before being caught and fixed in `6286be09`. Net effect: no
information was lost and the fix landed same-day, pre-merge — but it is still a defect that
should not have needed a second commit to catch.
**Owner: Ada** (scope/routing — the slice table assigned overlapping scope without a fence;
this is a planning-step gap, not an execution error).

**D2 — S1's recon undercounted "profile" mentions (3 reported vs 5 actual).**
S1 (haiku, low effort) is the fence-setter: its inventory is what S2 and S4 draft against,
and Rose's review explicitly relies on "S1 now assigns disjoint ranges" as the collision
prevention mechanism for §3. An inventory miss at this stage is a miss in the safety
mechanism itself, not a downstream typo. It was caught by the orchestrator before drafting
completed and the two missed lines (L101, L207) were handed to S4 explicitly, so no site was
actually lost — but the near-miss is on the same axis as D1: a low-effort scout was trusted
as the sole fencing mechanism for a LOCKED, single-file, multi-writer edit.
**Owner: Ada** (model routing — whether haiku/low is the right tier for a recon step whose
output is later relied on as a collision-prevention fence, versus a step whose output is
merely informational).

**D3 — S6's verification returned ALL PASS while its own evidence said otherwise, and missed
a second residual outright.**
S6 (haiku, low effort) was tasked with re-running the audit's ledger greps and specifically
checking "no CRAN-gate language" (plan's Verification section, first bullet). Its own CHECK
1c surfaced a residual — "paper/CRAN claims" in §4.1 — and scored the check a PASS anyway.
A second residual (§7.2, "the headline CRAN gate") was not surfaced by S6 at all; an
orchestrator sweep after the ALL-PASS verdict found it. Both were fixed in `fa6cb152`, after
verification had already certified the document clean. This is a gate that did not gate:
the explicit purpose of S6 in the plan is to be the thing that blocks a stale-language merge,
and it did not block on language it had itself found.
**Owner: Rose** (closeout/claims — the defect is exactly the kind of "did the claim outrun
the evidence" question Rose's scope check exists to catch, and it reached the point of a
PASS verdict before a human/orchestrator caught it) with a routing note to **Ada** (was
haiku/low sufficient effort for a verification task that turned out to require judgment
about whether found text constitutes a violation, not just pattern matching).

**D4 — The plan's FAN-OUT BUDGET line double-counted against a 6-slot checkpoint.**
The plan's own FAN-OUT BUDGET arithmetic (`scout=2 (S1,S6) · build=3 (S2,S3,S5) ·
ceiling=1 (S4)`) sums to 6 and names S1 through S6 — implying all six slices share one
checkpoint budget. In practice the `design66-revision` checkpoint's 6 slots were consumed by
S1–S4 plus the two **plan-review** agents (Rose, Fisher), which the FAN-OUT BUDGET line does
not mention at all. This left S5 and S6 — half the slice table, including the integrator and
the verifier — unbudgeted under the checkpoint the plan named for them. Execution recovered
cleanly: the user issued an explicit new checkpoint ("the rest!") and S5/S6 ran under
`design66-integration` instead. Nothing was silently dropped and the user's explicit
authorization is exactly the kind of recorded, justified escalation the adaptive/drift line
is meant to separate — but the plan's own budget line was wrong on its face the moment
Rose and Fisher's review consumed slots the arithmetic had allocated to S5/S6.
**Owner: Ada** (scope/routing — checkpoint budgeting is a routing artifact, and plan-review
agents versus execution-slice agents need to be counted consistently in a fan-out budget
line, not silently drawn from the same pool).

### Adaptive

**A1 — The audit's own compute-saving figure was corrected a second time, in place, by the
arc's own process.** The plan already recorded one Fisher correction (order-of-magnitude →
~1.1×–3.3×) before execution began. S4, drafting against the actual code rather than the
plan's prose, found the corrected figure was *itself* still wrong (the off-diagonal target
is `combn(5,2)=10` pairs, not ~1, so `n_estimands` is 5 or 15, not ~6, and the profile arm
can be up to 1.95× *more* expensive, not always cheaper). This was withdrawn in place in
`6286be09`, with the superseded text quoted verbatim inside a correction box rather than
silently deleted — the same locking convention the document already uses for §12. This is
exactly what the audit process is supposed to do (catch its own unverified quantitative
claims before they reach a paper-cited spec) and it did so twice in the same arc. No owner
action needed; recorded as a positive instance of the review loop working, not a defect.

**A2 — S5's overlap check was broader than the plan's stated scope, and that is what caught
D1.** The plan's verification language names §3 specifically ("diff-checks S2/S4 for §3
hunk overlap"). The check as actually run was not restricted to §3, and it is the reason the
§10 collision (D1) was caught during integration rather than shipping silently. Recorded as
adaptive because widening a stated check beyond its literal scope, when the wider check
costs little and catches a real gap, is the right call — but it is also the reason D1 is
"drift, caught" rather than "drift, shipped."

**A3 — Two same-day follow-up commits (`6286be09`, `fa6cb152`) after the integration commit,
not in the original slice table.** Neither is a new slice; both are corrections to what S4/S6
respectively surfaced (A1, D3) landing as their own commits rather than being folded back
into `d9331174` or left for a later session. Given the PR was not yet merged, this is
ordinary same-arc iteration, not scope creep — recorded here only because it is a literal
difference between the plan's "S5 commits + opens PR" (implying one integration commit) and
the actual four-commit shape.

### Unclear

**U1 — Model routing for S5 (the integrator) cannot be confirmed from git.** The plan assigns
S5 `sonnet, medium`. The integration commit `d9331174` carries `Co-Authored-By: Claude Opus
5`, which if taken literally would mean the ceiling-adjacent integration step ran on a higher
tier than planned (over-routing, not under-routing — the safer direction of error, but still
a deviation). However, this trailer text is the Bash tool's own example boilerplate for git
commit messages, copied verbatim unless a session substitutes its actual model identity, so
it is not reliable evidence either way. There is no independent signal in the repository to
resolve this. **No owner action recommended beyond the process-fix note in §4** — the
reconciliation process itself needs a trustworthy model-identity signal before this axis can
be checked from git alone.

---

## 3. "Explicitly NOT in this arc" — fence check (verified against git, not assumed)

| Fence | Verified how | Result |
|---|---|---|
| No compute of any kind | `git diff --stat origin/main...HEAD -- R/ src/ tests/ NAMESPACE DESCRIPTION` → empty | **Held.** |
| No register row moved (CI-08/CI-10 stay `partial`) | `git diff origin/main...HEAD -- docs/design/35-validation-debt-register.md` → empty (file not in the 4-file diff) | **Held.** |
| No open decision resolved | `docs/design/66-capstone-power-study.md` §3.4 header reads "OPEN DECISION -- primary interval method (NOT resolved here)"; §6A.5 reads "is not resolved here — it is the maintainer's call"; §12 L-e addendum explicitly declines to re-decide ("This is not a re-decision by this patch") | **Held**, and stated in the document's own text, not merely absent. |
| `stash@{0}` untouched | `git stash list` → `stash@{0}: On claude/profile-coverage-remeasure-20260718: profile-route in-flight (PRIOR session...)` — present, message unchanged from the plan's own quote of it | **Held.** |
| `#911` untouched by this lane | `gh issue view 911` → merged, but no commit in `git log origin/main..HEAD` for this branch references VA/#911/phylogenetic-KL work; the merge is a different lane entirely, unrelated in time and content to this arc's four commits | **Held** — this lane made no interaction with #911. |
| Dropbox checkout untouched | `git -C "/Users/z3437171/Dropbox/Github Local/gllvmTMB" status -sb` → identical modified/untracked file set to the session's starting `gitStatus` snapshot (capability-surface.html, the 2026-07-18 handover doc modified; `.claude/`, `.uinit/`, the 2026-07-17 handover doc untracked) | **Held** — no drift in that checkout across the session. |

All five fences held.

---

## 4. Recurring drift classes worth a process fix

1. **"Fencing prevents collisions only where a fence was drawn."** This arc's one real defect
   (D1) did not come from a broken fence — it came from a section the plan assigned to two
   writers and never fenced at all, because the plan's own attention (and Rose's review) was
   on §3, the section everyone remembered was contested. §10 was contested too (S2 "framing",
   S4 "DoD") and nobody's checklist said so. **This generalizes past this one document**: any
   slice table that assigns two drafting agents to edit the same single file needs an explicit
   full-file overlap fence (or a scoped overlap check that is *not* pre-restricted to the one
   section the plan-writer happened to notice), not a fence scoped to the section that felt
   risky at planning time. Worth a guard: for any multi-writer single-file integration, the
   overlap check's scope should default to *the whole file*, and narrowing it to "just §3"
   (or any subset) should be a deliberate, stated decision, not the default plan-writer
   attention pattern. This session's own overlap check (A2) already did the right thing by
   accident of being written broader than instructed; the guard would make that the rule
   rather than a lucky implementation choice.
2. **A low-effort scout's output being trusted as a safety mechanism (D2), and a low-effort
   verifier's PASS being trusted as a gate (D3), are the same failure pattern twice in one
   arc.** Both were caught — once by the orchestrator mid-arc, once by a follow-up sweep after
   the PASS verdict — so the arc's overall self-correction loop worked. But "worked, with a
   human/orchestrator catching it after the fact" is a weaker property than "the gate itself
   caught it." Worth considering, for any LOCKED-file or public-claim-bearing verification
   step: either raise the effort tier for the *judgment* parts of a check (distinguishing "text
   matches this pattern" from "does this text violate the checked property"), or require a
   second, independent pass before a PASS verdict is treated as load-bearing for merge — which
   is close to what already happened here informally (the orchestrator sweep), and could be
   made a named step instead of an ad hoc catch.
3. **Fan-out budget arithmetic that names all six slices but the checkpoint that actually gets
   consumed also includes plan-review agents never mentioned in the budget line (D4).** If
   plan-review agents (Rose, Fisher) draw from the same checkpoint pool as execution slices,
   the FAN-OUT BUDGET line should say so and count them; if they draw from a separate pool,
   the checkpoint accounting should make that explicit rather than have it discovered when the
   pool runs out mid-arc. Either is fine; the silent version is the process gap.
