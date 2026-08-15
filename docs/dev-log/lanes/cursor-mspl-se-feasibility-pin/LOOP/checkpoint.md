# checkpoint — cursor-mspl-se-feasibility-pin

GOAL: see GOAL.md.   STATE: science landed; PR/merge in flight.

ARCS DONE (verified):
- A0 LOOP kit committed
- A1 branch from tapes @ `0df6ab30`
- A2 teacher note on disk
- A3 estimand pick Q3=c
- A4 tests RED (`object not found`) then
- A5 `R/mspl-curvature-pin.R`
- A6 GREEN (Bernoulli 24, Poisson 29)
- A7 Rose PASS closeout
- A11 morning brief written

ARC IN PROGRESS: A8 open PR · A9 merge #978 · A10 merge SE PR

NEXT: push this branch; squash-merge #978 when CI green; open/retarget
SE PR onto `main`; squash-merge SE PR when CI green.

OPEN GATES (need human at 05:00 only if CI still red): none for
reversible work. Do not merge #972–#976. Do not admit.

COMPUTE: **local only.** D-50 (vault): recovery/power/coverage/sim
campaigns run on Totoro or DRAC, never GitHub Actions, never Actions
artifacts. Tonight's 8×3 se=TRUE pin is a smoke, not a campaign —
do not occupy Totoro/DRAC. Sibling note
`docs/dev-log/research/2026-08-15-mspl-compute-totoro-drac.md` was
absent at write time. Totoro/DRAC >30 min still needs a checkpoint
receipt; Gaussian SE campaign remains deferred.

TRUTH LIVES IN: `cursor/mspl-se-feasibility-pin` · this kit ·
after-task `docs/dev-log/after-task/2026-08-15-mspl-se-feasibility-pin.md`
· brief `docs/dev-log/handover/2026-08-16-cursor-handover-se-pin.md`

RESUME:
```text
You are lane cursor-mspl-se-feasibility-pin — RESUME.
READ FIRST: docs/dev-log/lanes/cursor-mspl-se-feasibility-pin/LOOP/GOAL.md -> checkpoint.md.
WORKSPACE: /private/tmp/gllvmtmb-mspl-estimator-programme-roadmap
SCIENCE LANDED: internal Q_P+Q_0 pin; public se=TRUE withholds; Poisson planned.
DO NOT: admit, NEWS covered, merge #972-#976, absorb Codex, write repo-root LOOP/.
NEXT: if #978 CI green, squash-merge it; rebase this branch onto origin/main;
open or retarget the SE PR; squash-merge when CI green.
```
