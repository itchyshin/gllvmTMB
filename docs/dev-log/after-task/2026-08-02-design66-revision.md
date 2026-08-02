# After Task: Design 66 revision — integrate six-finding staleness audit patches

**Branch**: `claude/capstone-scope-20260802`
**Date**: `2026-08-02`
**Roles (engaged)**: `Emmy (integrator)`

## 1. Goal

Integrate three independently-drafted patch sets against
`docs/design/66-capstone-power-study.md`, produced in response to
`docs/dev-log/audits/2026-08-02-design66-staleness-audit.md` (a six-finding
staleness audit, S-1 through S-6): S-2 (CRAN reframing + kernel-engine
correction), S-4 (interval-method reopening, section-8 re-pricing, H4
boundary-null caveat, section-12 dated addenda), and S-3 (a new inserted
section on validation oracles, numbered 6A). Then cascade the change per
AGENTS.md rule 10: update the two GitHub issues that assert a now-retired
CRAN gate, log the work, and write this report. No compute, no register-row
promotion, no capability advertisement, and no resolution of any open
decision were in scope.

## 2. Implemented

- `docs/design/66-capstone-power-study.md` carries all 17 patch sites (7
  from S-2, 10 from S-4) plus one new section 6A (from S-3), applied by
  verbatim old-text match. Section 0 and section 2 now frame the capstone as
  the paper's evidence chapter, not a CRAN release gate. Section 3 gains a
  full accounting of the two distinct profile routes (P-psi, demoted; P-V,
  certified-but-scope-limited) and reopens the primary-interval-method
  choice as an explicit maintainer decision (new §3.4) rather than assuming
  bootstrap-primary. Section 6's interval-methods bullet states both routes
  at equal weight. Section 8's cost table is re-priced at the `n_boot >=
  200` floor (the former `n_boot = 50` "halve the bill" lever is deleted as
  arithmetically unsafe — it could not have cleared the study's own 0.94
  gate), and gains a profile-arm cost term with an explicit note that
  `refits_per_profile` is unmeasured. Section 10's Definition of Done gains
  a numbered prerequisite: the compute-admission design doc does not exist
  (verified by `grep -rl 'compute-admission' docs/ dev/`, 7 hits, none a
  design doc), and gains the 2026-08-02 CRAN-descoped reframing. Section 12
  (LOCKED) keeps every one of its L-rows' original text verbatim and adds
  dated addenda below the preamble, L-a, L-c, and L-e — no L-row is
  reversed. New section 6A documents that all four Tier-0 core RE
  structures lack an MLE-quality external oracle, with three distinct
  epistemic gradations (untested-plausible / admitted-scouting-gap /
  checked-absence) rather than one flat "none exists" claim.
- GitHub issues #345 and #349 each got a dated `## 2026-08-02 update — CRAN
  descoped` section appended to their existing bodies (bodies otherwise
  unchanged, not rewritten, not closed).
- `docs/dev-log/check-log.md` got a dated entry recording the exact commands
  run and what was deliberately not done.

## 3. Files Changed

- `docs/design/66-capstone-power-study.md` — the integration (17 patch
  sites + 1 new section 6A).
- `docs/dev-log/check-log.md` — dated entry appended.
- `docs/dev-log/after-task/2026-08-02-design66-revision.md` — this report
  (new file).
- GitHub issue #345 body — dated update section appended via `gh issue edit
  --body-file`.
- GitHub issue #349 body — dated update section appended via `gh issue edit
  --body-file`.

**Explicitly not touched**: `docs/dev-log/audits/2026-08-02-design66-staleness-audit.md`
(pre-existing modified-but-uncommitted state at session start, per the
orchestrator's instruction to leave it exactly as found — this session made
no edits to it); `docs/design/35-validation-debt-register.md`; R/, src/,
tests/, NAMESPACE, DESCRIPTION.

## 3a. Decisions and Rejected Alternatives

- **Decision: apply s2's section-10 site before s4's section-10 site.**
  Rationale: the two patches' OLD blocks in section 10 share verbatim text
  (the original items 4 and 5 — register-rows update and paper-ready-report
  — appear at the tail of s4's OLD block and the head of s2's OLD block).
  Applying s4 first would renumber those items before s2's OLD block could
  match, breaking s2's verbatim-match precondition. Applying s2 first
  leaves items 1–5 intact for s4's OLD block to match, then s4's renumbering
  (inserting a new item 1) happens without disturbing s2's already-applied
  text. Rejected alternative: apply strictly patch-by-patch (all of s4 then
  all of s2, or vice versa) without checking per-site ordering — rejected
  because it would have caused a hard failure on this one site rather than
  a silent corruption, but the task explicitly asked for an overlap check
  first, and doing that check surfaced the ordering requirement.
  Confidence: high (verified by successful application in this order, and
  by rereading the integrated section 10 for coherence).
- **Left an unrepaired cross-reference for the maintainer to see, not to
  fix.** s2's section-10 NEW text says "This changes how item 2 above is
  read" (referring to the H1–H4 adjudication item). After s4's insertion of
  a new prerequisite item 1, that line becomes item 3, not item 2 — a
  numbering drift that is a mechanical consequence of combining two
  patches whose authors could not see each other's work. I did not
  silently renumber s2's cross-reference, because the task instructed
  verbatim OLD/NEW application and explicitly said not to improvise fixes;
  I flag it here and in the PR body instead. Rejected alternative: quietly
  change "item 2" to "item 3" — rejected as an unauthorized edit to
  reviewed patch text.

## 4. Checks Run

- `git status` / `git diff --stat` before and after each edit block, to
  confirm scope stayed to `docs/design/66-capstone-power-study.md` plus the
  three cascade files.
- `grep -n '^## ' docs/design/66-capstone-power-study.md` — confirmed
  sections 0 through 12 in original order, with 6A inserted between 6 and
  7, and no other section renumbered.
- `grep -c '```' docs/design/66-capstone-power-study.md` — returned 0
  before and after; the document uses no triple-backtick fences anywhere,
  so there was nothing to orphan.
- Visual read of section 12 in full (`Read` offset 1078) to confirm the
  preamble, L-a, L-c, and L-e each retain their original locked text
  verbatim above a `**2026-08-02 addendum --**` block.
- Visual read of the section 3/4 boundary and section 7/8 boundary to
  confirm no duplicated paragraphs or dangling context at patch-adjacent
  seams.
- `gh issue view 345/349 --json body -q .body` to fetch current bodies
  before editing; `gh issue edit --body-file` to apply; both returned issue
  URLs with no error.
- No `devtools::test()`, no `R CMD check`, no `devtools::document()`: this
  is a docs-only change touching no R/, src/, tests/, NAMESPACE, or
  DESCRIPTION file.

## 5. Tests of the Tests

N/A — no test code changed. The sanity checks above (structural grep,
visual review of every seam) function as the equivalent verification for a
markdown integration.

## 6. Consistency Audit

- `grep -n '^## ' docs/design/66-capstone-power-study.md` — one-line
  verdict: sections 0–12 present, in order, 6A correctly slotted between 6
  and 7, no gaps or duplicates.
- `grep -c '```'` — one-line verdict: 0 fences before and after; no orphan
  risk in this file.
- Manual scan for the phrase "CRAN" across the diffed regions — one-line
  verdict: every remaining CRAN reference in the touched sites is either
  historical framing (e.g. "the run that gated on CRAN + paper" in the
  now-superseded quoted text) or the new 2026-08-02 descoping language; no
  site reintroduces CRAN as a live gate.

## 7. Roadmap Tick

N/A — this is a design-doc correction, not a roadmap-tracked capability
change. No ROADMAP.md row applies.

## 7a. GitHub Issue Ledger

- **#349** ("[roadmap] Power-simulation capstone") — appended a dated
  `## 2026-08-02 update — CRAN descoped` section via `gh issue edit --body-file`.
  Original body preserved verbatim above it. Not closed.
- **#345** (CRAN release umbrella) — appended the same dated update section.
  Original body preserved verbatim above it. Not closed.
- No new issue created. No other issue inspected or commented.

## 8. What Did Not Go Smoothly

The task's own overlap-disclaimer ("The two patches ... do NOT overlap")
was accurate for section 3 (the specific case it named) but not exhaustive:
s2 and s4 share verbatim text in section 10 (original items 4–5). This
required determining and respecting an application order rather than
applying strictly patch-by-patch; documented above (§3a) and in the PR
body. No other friction — the remaining 15 of 17 sites and the section 6A
insertion applied cleanly on the first attempt with no retries.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

**Integrator (Emmy):** verbatim-match patch integration is only as safe as
its overlap analysis. A task brief's overlap claim should be treated as a
hypothesis to verify against the actual patch text, not a fact to trust —
in this case the claim was correct about the one case it named (section 3)
and silent about a second real case (section 10) that a mechanical
substring check would have caught immediately. Worth doing that check
explicitly and early on any future multi-patch integration, rather than
relying on the brief's own disjointness claim.

## 10. Known Limitations And Next Actions

- **Compute:** none run. The `n_sim = 200` pilot re-measurement, the
  `n_sim = 2000` HPC core, and the `refits_per_profile` empirical
  measurement (newly required before any compute-saving number from
  section 8 can be trusted) are all still open and unscheduled.
- **Register:** CI-08 and CI-10 remain `partial`. No register row was
  touched or promoted by this revision.
- **Open decisions, still unresolved by this revision** (this revision
  documents them; it does not decide them):
  1. Section 3.4 — primary interval method: profile (P-V) primary,
     bootstrap primary, or both reported.
  2. Section 12 L-e — whether the coevolution/Gamma Tier-3 extension
     should be reconsidered now that `kernel_*()` is built, exported, and
     tested (deferred to Shinichi; the audit's finding S-4).
  3. Section 6A.5 — whether a hand-written fixed-parameter Stan check for
     `phylo_latent` (the one core cell with a checked-absent third-party
     oracle) is in scope for this capstone or a separate slice.
  4. Whether the off-diagonal correlation estimand is gated alongside
     `Sigma_unit_diag` (changes `n_estimands` from 5 to 15 in the section-8
     cost model, flipping the sign of the profile-vs-bootstrap cost
     comparison).
  5. Whether extending the P-V certified route to the structured RE tiers
     (phylo/spatial/animal) is in-scope work for this capstone.
  6. Whether the compute-admission design document (section 10 item 1)
     gets built at all, and on what timeline — it is verified NOT to exist
     yet and gates all execution regardless of how the other decisions
     resolve.
  7. The numbering cross-reference drift noted in §3a (s2's "item 2"
     reference, now pointing at the wrong item after s4's renumbering) —
     left unedited pending maintainer sign-off on the integration as a
     whole.
- **Next action:** maintainer review of the three judgment calls flagged in
  the PR body, then a decision on whether/how to schedule the
  `refits_per_profile` measurement and the compute-admission design slice.

---

## 11. Addendum — two commits landed AFTER this report was written

This report was written by the integration slice and then overtaken by two
further commits in the same arc. Recorded here rather than by rewriting the
sections above, so the original record stands.

### 11.1 `6286be09` — the audit's compute claim was withdrawn

Section 3's "explicitly not touched" line says
`docs/dev-log/audits/2026-08-02-design66-staleness-audit.md` was left
untouched. **That is no longer true.** The orchestrator subsequently edited and
committed it, for a reason that belongs in the permanent record:

The audit's S-2 finding argued the certified profile route was better on two
axes — evidence quality *and* compute cost. The compute half was wrong. It
claimed "roughly an order of magnitude" cheaper. Two adversarial reviews took
it apart and the second **flipped its sign**:

1. Bootstrap **amortises** (one refit set yields every requested summary from
   the same draws, `R/bootstrap-sigma.R:346-375`); a profile does not — it is a
   per-scalar `uniroot` bisection (`R/profile-derived.R:866-897`).
2. The scalar count was undercounted. The off-diagonal target runs over
   `utils::combn(n_traits, 2L)` — **ten pairs at T=5**
   (`dev/m3-grid.R:1666-1681`) — so the capstone needs **5 or 15** univariate
   profiles per replicate, not the "~6" the first correction assumed.

Measured: diagonals-only = 1.5x-2.8x cheaper; diagonals plus pairs =
1.05x-1.95x **more expensive**. The claim was withdrawn *in place*, with the
superseded text quoted verbatim inside a correction box, and **no compute-saving
figure is committed anywhere** pending an empirical `refits_per_profile`
measurement. The evidence-quality half of S-2 is unaffected and stands.

Same commit also fixed a cross-reference this integration broke: section 10's
reframing paragraph pointed at "item 2", but the compute-admission prerequisite
was inserted as item 1, so the H1 adjudication it refers to is item 3.

### 11.2 `fa6cb152` — two CRAN residuals the fencing missed

Section 4 records the structural verification as passing. It did, but a
follow-up sweep found two surviving pieces of stale CRAN framing **outside the
three sites the drafting agent was fenced to**:

- section 4.1 — "a core confirmatory grid that *must* pass to support the
  paper/CRAN claims"
- section 7.2 — "these inform register promotions, not the headline CRAN gate"

Neither asserted outright that the capstone gates CRAN, which is why the
structural check passed them. Both are fixed. Five CRAN mentions remain in the
file, all of them statements that submission is not planned, plus the retained
superseded quote in section 10.

### 11.3 Revised file list for this arc

```
docs/design/66-capstone-power-study.md                        (17 sites + section 6A + 3 later fixes)
docs/dev-log/audits/2026-08-02-design66-staleness-audit.md    (new, then corrected in place)
docs/dev-log/check-log.md                                     (dated entry)
docs/dev-log/after-task/2026-08-02-design66-revision.md       (this report + this addendum)
docs/dev-log/plan-actual/2026-08-02-design66-revision.md      (reconciliation)
GitHub issues #345, #349                                      (dated update appended; NEITHER closed)
```

Still untouched, as fenced: `docs/design/35-validation-debt-register.md`, `R/`,
`src/`, `tests/`, `NAMESPACE`, `DESCRIPTION`.

### 11.4 The process lesson

**Fencing prevents collisions only where a fence was drawn.** Section 3 was
fenced after a plan reviewer predicted an S2/S4 collision there, and section 3
came through clean. Section 10 was *not* fenced, both patches touched it, and
the result was a broken cross-reference. Sections 4.1 and 7.2 were outside every
fence and kept their stale text. The fence is a whitelist, and anything outside
it is unowned — so a fenced multi-agent edit needs a whole-file sweep for the
*concept* afterwards, not only a check of the fenced sites.
