# Recovery checkpoint — Poisson MSPL W_* REPLACE

**When:** 2026-08-17 ~17:45 MDT  
**Agent:** Cursor  
**Branch:** `cursor/mspl-poisson-W-REPLACE-impl` @ `e2b13651`  
**Worktree:** `~/local-scratch/lanes/gllvmTMB-mspl-poisson-W-REPLACE`  
**PR:** https://github.com/itchyshin/gllvmTMB/pull/1111

## Status

- A0–A7 done (A7 mspl-api **293/0**; as-cran deferred).
- A8: after-task + check-log + PR open; waiting CI then merge (preapprove-all).
- Hard OUT holds: no public se claims; #1077 stays draft.

## Already run

- Focused MSPL filters 243/0; smoke se=FALSE admitted.
- `devtools::test(filter="mspl-api")` → 293/0.

## Still needed

- R-CMD-check green on #1111 → merge.
- Mark GOAL PR checkbox + LOOP A8 done after merge.

## Next safest action

`gh pr checks 1111` → `gh pr merge 1111 --merge` when green.
