# GOAL — cursor-mspl-arc-1a-provenance (IMMUTABLE — re-read at the top of EVERY arc)

Read this first, every cycle. Auto-compact eats messages, not this file. Unsure after a compaction?
Re-read THIS, then `LOOP/checkpoint.md`, then continue.

This stacked-branch LOOP kit **replaces** the historical 0.6 release LOOP files for
**this branch only**. The 0.6 kit remains in git history on `main`.

## Mission

Deliver **internal estimator provenance** on every current admitted route, with
**exact numerical and accepted-call parity**. Finish line: every current fit that
already goes through the estimator surface carries inspectable-but-unadvertised
`fit$estimator_provenance`; TMB `estimator_id` stays 0/1/2; no result or accepted
call changes; after-task + check-log + stacked Cursor PR are open; handback before
Arc 2.

## Headline

Separate **integration**, **outer criterion**, **numerical kernel**, and
**penalty-eval** internally without changing any result or accepted call.

## Invariants

- One lane: Cursor MSPL Arc 1A. Workspace ONLY
  `/private/tmp/gllvmtmb-mspl-estimator-programme-roadmap`.
- Do NOT use or edit `/Users/z3437171/Dropbox/Github Local/gllvmTMB`.
- Do NOT touch Design 117, interval-feasibility (`8e9d`), iSDM, G3P, #872, #855,
  AA-03 files.
- TMB `estimator_id` stays 0/1/2. Prefer ZERO C++ edits. Any tape-changing C++
  edit = HOLD / OPEN GATE.
- No accepted-call change. `estimator="ml"` + `integration="va"` stays accepted;
  only record it.
- No Arc 1B typed errors, no NEWS, no register promotion, no default change, no
  new design number.
- No campaign. Local targeted tests only. `OMP_NUM_THREADS=1`. Any fit >30 min STOP.
- `estimator_id = 2` remains internal penalty-off stable kernel, never public ML.
- Never `git add -A`. Stage explicit paths only. Do not merge. Do not push until S6.

## Authoritative WHAT

`LOOP/ultra-plan.md` (copy of
`docs/dev-log/plans/2026-08-14-cursor-mspl-one-arc-ultra-plan.md`).
Detail wins there; this file wins on "what must never be lost".

## Definition of done

1. Implicit ML, explicit Laplace ML, current MSPL (logit/probit/cloglog; ordinary
   + existing spatial cells already in `test-mspl-api.R`), and currently accepted
   VA+ml all keep **exact** `opt$par`, `opt$objective`, report fields used today,
   warning/error **classes**, and acceptance.
2. Every such fit carries `estimator_provenance` whose fields match the adapter
   contract and the compatibility table.
3. `estimator_id` on the live tape remains 0/1/2 with the same meaning.
4. Gauss/Noether/Rose PASS (or HOLD with a named defect). No P0/P1 “and also do 1B.”
5. After-task + check-log written. Stacked PR open. No NEWS, no register promotion,
   no default change.
6. Handback before Arc 2.

## OPEN GATES (STOP and surface to Shinichi)

- merge to main
- NEWS / public claim
- any C++ tape change
- any new error for a currently accepted call (that is 1B)
