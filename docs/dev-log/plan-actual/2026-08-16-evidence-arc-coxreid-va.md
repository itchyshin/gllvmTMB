# Plan-vs-Actual Reconciliation — Cox–Reid A+B campaign + VA-vs-Laplace study design (Design 122)

Reconciler: Melissa (Sonnet, low effort). Plan:
`/Users/z3437171/.claude/plans/glowing-soaring-pike.md`. Scope: slices
C0–C2 (A+B campaign), D0–D2 (Design 122 authoring + pre-run), E0–E1
(consolidation + reconcile).

## Planned vs Actual (six axes)

| Axis | Planned | Actual | Verdict |
|---|---|---|---|
| **Scope** | 8 slices, 6 new children (C0, C2, D0, D1-Opus, D2, E1), C1/E0 held by parent; C-track and D-track run in parallel; no `R/`/`src/` edits; `dev/` + `docs/design/` + dev-log only | 6/6 children dispatched as tabled, budget held, no `R/`/`src/` edits reported; C-track (harness→deploy→adjudicate) and D-track (design→review→pre-run) both completed; Design 122 §14 appended by the **parent at E0**, not by D2 as the slice table's natural owner | **Adaptive**, with one **unclear** item (design-doc append ownership — see Deviations) |
| **Evidence-verification** | Canary chunk inspected before full launch (Verification #1); C2 adjudicates K1–K4 against Design 121 §3, thresholds compared to achieved MCSE (#2); D1 Opus SHIP gate before D2 runs (#3); D2 runs Fisher's F1-bound TEST A optimum certification on the real sentinel grid | Canary caught two real harness defects (mirai worker-env serialization → 0 rows; env-name mismatch) — verification worked as designed, twice in effect. C2 delivered K1-fires with **both** the literal-spec MCSE (fails governance) and the paired-bootstrap MCSE (clears) reported rather than the convenient one alone. D1 Opus SHIP-WITH-FIXES ran before D2. D2's own smoke rule fired (one VGH fit at n=1600 exceeded 17.3 min) and it STOPPED — 0/120 sentinel fits run, TEST A validated only on toys (VGH partial), SD(Δ)/seeds-per-cell not measured | **Adaptive** on the stop decision itself (matches the plan's own pre-registered D-139 contingency verbatim); **unclear** on whether F1's BINDING certification requirement is discharged by a toys-only TEST A, and on K2–K4 left explicitly unadjudicated |
| **Model routing** | Slice table: C0 Sonnet/medium, C2 Sonnet/high, D0 Sonnet/high, D1 Opus/high (ceiling=1), D2 Sonnet/medium, E1 Sonnet/low; C1/E0 = parent | Matched exactly — 6 children, 1 Opus (D1), Sonnet elsewhere, ceiling honored | **Adaptive** (compliant), with one **drift**: D2's agent first paused passively waiting for a monitor rather than polling actively, needing a parent nudge — an orchestration deviation from expected sub-agent behavior under the dispatch model |
| **Safety gates** | Lightweight immutable-chunk compute-gate discipline (embedded in plan, not full Design 66 admission slice): pinned commit, canary chunk, guarded launcher, **incremental CSV writes** to `~/gllvm_work/results`, rsync-back; D-139 estimate-before-run + pre-run test on all runs >30 min | Pinned commit YES; canary YES (caught the two defects above); guarded launcher YES; rsync-back YES. **Incremental writes: NOT implemented** — confirmed by reading `dev/coxreid-ab/run-ab.R`: results accumulate in memory via `mirai_map()` and are written once at the end (`write.csv(out, ...)` at line 364, no per-row/per-chunk write). D-139 canary-before-full-launch was honored (twice, in effect, after the two fix cycles); D2's smoke-first stop rule fired correctly | **Drift** on incremental writes (stated discipline not built; inconsequential here only because the full run completed in 16.5 s — a longer run would have risked losing all in-flight results on a crash); **adaptive** on canary and D-139 discipline otherwise |
| **Public claims** | No promotion of `allow_nongaussian_reml` regardless of K-outcome; K-adjudication is a reportable result, not a package claim; Design 66 one-pager gets "measured numbers on every claimant" | K1 (Cox–Reid worsens bias, both families) reported as a finding, not a promotion — constraint honored. One-pager: claimant 2 marked RESOLVED, claimant 1 repriced (not overclaimed) | **Adaptive** — no deviation found |
| **Handoff state** | E0: one-pager updated, after-task + brain deltas, commit/rebase/push, PR comment, PR CI green (Verification #4) | Commit `fa35f502` rebased onto moved `main` (one check-log conflict); during resolution the agent found and fixed a **stray conflict marker from a previous session's resolution already pushed to the branch** — an unplanned catch; pushed `--force-with-lease`; PR comment posted; AGENT_LOG + vault committed. **CI was pending, not green, at report time** | **Adaptive** on the stray-conflict-marker catch (protects published state, exactly the diligence the after-task discipline exists for); **drift** on CI: the plan's own Verification #4 ("PR CI green") was not satisfied at the point E0 was reported done |

## Deviations (tagged, owner-routed)

1. **[adaptive]** Canary chunk caught two real harness defects (mirai
   worker-env closure resolution → silent 0-row failures; env-var
   naming) before the full 1,600-row launch — the plan's own
   verification step (canary-before-launch) doing exactly its job.
   No owner action needed.
2. **[adaptive]** Fix for the canary-caught defects was routed back to
   C0's author rather than respawned as a new child — reuse-before-
   respawn discipline, consistent with fan-out economy even though not
   named explicitly in this plan's text. No owner action needed.
3. **[adaptive]** D2 stopped pre-registered — one VGH fit at n=1600
   exceeded 17.3 min, tripping the plan's explicit contingency ("if the
   smoke projects > ~25 min total, STOP and report the estimate per
   D-139 instead of running"). The stop rule fired as designed.
4. **[unclear]** D2's deliverable ("pre-run RUN and reported," Fisher's
   F1 binding TEST A optimum certification) is only partially
   discharged: 0/120 sentinel fits ran, TEST A validated on toys only
   (VGH partial), SD(Δ)/seeds-per-cell not measured. Whether the
   correctly-fired stop rule (item 3) fully discharges F1's BINDING
   requirement, or leaves a real certification gap the full Design 122
   campaign cannot launch without closing, is a judgment call the plan
   text does not resolve. **Route to domain reviewer** (statistical-
   reviewer) to confirm F1's status before any full-campaign launch.
5. **[drift]** D2's agent initially paused passively waiting for a
   monitor instead of polling actively, requiring a parent nudge — an
   orchestration deviation from expected autonomous sub-agent behavior.
   **Route to Ada** (routing).
6. **[unclear]** C2 adjudicated only K1 of the four kill criteria
   (K2/K3/K4 explicitly left unadjudicated). Plan text says "Adjudicate
   K1–K4." Whether K1 firing (Cox–Reid worsens bias) moots K2–K4 under
   standard kill-criteria logic, or whether the deliverable is simply
   incomplete against the letter of the slice, is unresolved. **Route
   to domain reviewer** (statistical-reviewer).
7. **[adaptive]** C2 reported both the literal-spec-text MCSE (fails
   governance, due to a runaway tail) and the paired bootstrap-median
   MCSE (clears governance) rather than silently picking the
   favorable one — matches the plan's verification ethos.
8. **[drift]** The compute-gate reconciliation embedded in the plan
   commits to "incremental CSV writes to `~/gllvm_work/results`";
   `dev/coxreid-ab/run-ab.R` performs only a single final write after
   all mirai tasks complete (confirmed at line 364). Inconsequential
   for this 16.5 s run but a real gap in the stated discipline for any
   longer future run. **Route to Ada** (scope/compute-gate discipline).
9. **[unclear]** Design 122 §14 was appended by the parent at E0, not
   by D2 as the slice table's natural owner of the pre-run write-up.
   Consolidation-at-E0 is plausible under E0's stated scope ("refresh
   decision boxes"), but the plan does not explicitly assign this
   append to either slice. **Route to Rose** (closeout).
10. **[adaptive]** During the E0 rebase, the agent found and fixed a
    stray conflict marker from a *previous session's* resolution
    already pushed to the branch — an unplanned but valuable catch
    that prevented corrupted state from reaching the PR. No owner
    action needed beyond noting it in the after-task record.
11. **[drift]** Verification item 4 ("E0: PR CI green") was not
    satisfied at the point E0 was reported — CI was pending, not
    green. **Route to Rose** (closeout) — confirm CI resolves green
    before treating E0 as closed.

## Verdict

Six of eight slices executed materially as planned (C0, C1, D0, D1, E0,
E1); the two structurally interesting departures — D2's stop-rule halt
and the compute-gate's non-incremental writes — are, respectively, the
plan's own contingency firing correctly and a genuine (if
inconsequential-so-far) discipline gap. 5 adaptive, 3 drift, 3 unclear
across 11 tagged deviations; model routing and public-claims axes are
fully compliant with no deviations. **CONDITIONAL PASS** — the arc's
core finding (K1 fires) and its process discipline (canary-first,
D-139 stop rules, budget-held routing) hold; close out only after Rose
confirms E0's CI is green and the domain reviewer resolves items 4 and
6 (F1 certification status, K2–K4 disposition) before any full Design
122 campaign is authorized to launch.
