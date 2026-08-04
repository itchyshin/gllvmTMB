GOAL: see `lanes/mature-va-ordinal/LOOP/GOAL.md`.
STATE: lane scaffolded, G0 approved, Arc A0 (the retraction) starting.

ARCS DONE (verified): none yet.

ARC IN PROGRESS: **A0 — retract the false "VA is refuted" claim.**
  How to tell it landed: `dev/va-speed/46-VA-VS-LA-VERDICT.md`,
  `docs/dev-log/handover/2026-08-03-claude-handover-va-lane2-blockers-closed.md`,
  `dev/va-speed/20-CLAIMS-LEDGER.md` and `docs/dev-log/check-log.md` each carry a VISIBLE
  retraction banner naming the arm confusion (`eval_method` resolved to `gh` with
  `collapse = FALSE`, vs `f3df8193`'s `ac` + `collapse = TRUE`). A quiet edit does not count.

NEXT: A1 (harden the ladder harness) and A2 (ordinal ψ-collapse probe) — both parallel with A3.

OPEN GATES (need human):
  - **G1** after A2 — the ordinal shipping shape. Option **(b)** "also build an ordinal GH tier"
    doubles the arc and is a STOP; (a) and (c) are inside the approved fence.
  - **G3** standing — do NOT push `claude/va-lane2`. Maintainer's call.

TRUTH LIVES IN:
  - worktree `/private/tmp/gllvmtmb-va-lane2`, branch `claude/va-lane2`, **unpushed**,
    +27 commits vs `origin/main` @ `5bf18ab3`
  - the arc's own record: `docs/dev-log/handover/2026-08-03-claude-handover-mature-va-item1.md`
    (read FINAL STATE first, then SESSION 2, then the top)
  - the maths: `dev/va-speed/ALBERT-CHIB-DERIVATION.md` §5 (ordinal), §5.7 (stable CDF
    difference), §5.8 (cutpoints PINNED)
  - claim status: `dev/va-speed/20-CLAIMS-LEDGER.md` — **check status before citing anything**
  - Totoro lane `~/gllvm_work/va-lane2` (byte-identical at last sync; re-verify with md5sum)

KNOWN-GOOD NUMBERS (state the regime with each):
  - AC + collapse, N=250, T=20, q=2, n_trials=6, H=15, unique=FALSE: **4.10 s** vs our LA 23.93 s
    → **5.83× faster** (`f3df8193`, 3 seeds, local desktop at load ~12 — ratio transfers, absolute
    seconds do not)
  - AC alone vs gllvm's VA, like-for-like: **3.7× slower**. **AC + collapse vs gllvm at N=1000:
    1.76× faster** at indistinguishable accuracy — the collapse is what flipped the sign
  - Warm route (AC → GH): GH's accuracy at **36.8 vs 138.6 iterations**
  - **AC collapses a real ψ at low n_trials**: planted 0.6 → AC 0.0001 at n_trials=6, where GH
    recovers 0.6207. Disqualifying as a default. This is why the arc ends on GH.

RESUME: Read `lanes/mature-va-ordinal/LOOP/GOAL.md`, then this file, then
`lanes/mature-va-ordinal/LOOP/ultra-plan.md`, then `AGENTS.md`. Reattach to
`/private/tmp/gllvmtmb-va-lane2` (do NOT recreate it). Run the L2 arc-loop: re-read GOAL each arc,
verify by LOG not exit code, pause at every OPEN GATE, overwrite this file each arc. Continue from
NEXT above.
