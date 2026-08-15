# Morning brief — LA-MSPL SE feasibility pin

Meta: 2026-08-16 · from Cursor overnight → Shinichi @ ~05:00 local ·
AUTHOR=cursor · TARGET=cursor · lane `cursor/mspl-se-feasibility-pin`

You are Cursor. Reconcile with live `git` before any mutation.

## Done overnight

1. LOOP kit at
   `docs/dev-log/lanes/cursor-mspl-se-feasibility-pin/LOOP/`.
   Repo-root `LOOP/` was not touched.
2. Read-only teacher from
   `codex/lane-b-mspl-interval-feasibility` @ `e91c7b7c` via `git -C`.
   No Codex `R/mspl.R` copy.
3. Estimand pick: **both** numerical Hessians (\(Q_P\) and \(Q_0\)).
   Sandwich / profile / bootstrap / jackknife deferred.
4. Failing tests first, then
   `R/mspl-curvature-pin.R`. **No `src/`**. `R/fit-multi.R`
   withholding branch untouched.
5. Targeted tests GREEN: Bernoulli 24, Poisson 29, public-door 6,
   registry 26. `OMP_NUM_THREADS=1`.
6. Rose PASS: still planned, no NEWS covered, no public `vcov()`.
7. Compute: **local** `OMP_NUM_THREADS=1`. D-50 forbids campaign
   CI. Did not occupy Totoro/DRAC for the 8×3 smoke. Sibling
   Totoro/DRAC note was not on disk yet.

### Pin receipt (one tiny cell each — not a campaign)

| Family | \(Q_P\) | \(Q_0\) |
|---|---|---|
| Bernoulli logit | available (min ev 0.226) | **non-PD** (min ev −0.774), retained |
| Poisson log | available (min ev 3.300) | available (min ev 2.473) |

Public `gllvmTMBcontrol(se = TRUE)` still leaves `sd_report` NULL.
Poisson registry stays `planned`.

## RED leftover

- #978 CI was red, then a provenance/NB1 source-pin fix was pushed
  (`0df6ab30`). Re-run must be green before squash-merge.
- This SE branch is stacked on that tapes tip. After #978
  squash-merges, rebase onto `origin/main` before merging the SE PR.
- No all-zero / large-μ Poisson cell was run.
- No coverage numbers. Do not call this covered.
- #972–#976 still open. **Do not merge them.**
- Shannon WIP cap is still exceeded until those prep PRs are
  retargeted or closed by a human.

## PR URL

SE-pin PR is opened from `cursor/mspl-se-feasibility-pin` (see the
GitHub link in the chat / `gh pr view` if this file is read after
push). #978 remains
https://github.com/itchyshin/gllvmTMB/pull/978

## What Shinichi should do at 05:00

1. If #978 CI is green and not yet merged: squash-merge it
   (authorised overnight). Still **do not admit Poisson**.
2. If the SE-pin PR CI is green and #978 is on `main`: squash-merge
   the SE PR (authorised overnight). Still **no NEWS covered**.
3. If either CI is red: read the failing test names; do not admit;
   do not merge #972–#976.
4. Do **not** treat “an SE was formed” as “MSPL has standard
   errors.” Bernoulli \(Q_0\) was non-PD on the first cell.

## HARD STOP (unchanged)

planned → admitted · NEWS covered · public mspl on NB1/NB2/beta/
Tweedie · merge #972–#976 · Codex absorb · repo-root `LOOP/` ·
gaussian SE campaign · Totoro >30 min

## Resume

```text
Read AGENTS.md and docs/dev-log/handover/2026-08-16-cursor-handover-se-pin.md.
Reconcile with live git. Continue only OWED merge/CI items.
Do not admit. Do not merge #972-#976. Do not write repo-root LOOP/.
```
