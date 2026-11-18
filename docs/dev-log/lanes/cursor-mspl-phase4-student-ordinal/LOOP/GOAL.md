# GOAL — cursor-mspl-phase4-student-ordinal (IMMUTABLE — re-read every cycle)

Read this first, every cycle. Auto-compact eats messages, not this file.

This kit lives at `docs/dev-log/lanes/cursor-mspl-phase4-student-ordinal/LOOP/`.
**Do not write repo-root `LOOP/`.** That path is the 0.6 EVA/VA kit on `main`.

Closed kits (`cursor-mspl-catchup`, `cursor-mspl-gaussian`,
`cursor-mspl-arc-1a`, `cursor-mspl-point-continue`,
`cursor-mspl-phase4-tapes-planned`) are historical for *this*
lane — do not reopen their GOALs. Sibling family kits
(`-poisson`, `-nbinom1`, `-nbinom2`, `-beta`, `-tweedie`) own
their own science; do not rewrite them.

This is **LA-MSPL**, not EVA, not VA, not AGHQ-MSPL.

## Mission

```text
Solo: Cursor
Deliverable: planned-only Phase-4 prep for Student-t (identity)
and ordinal_probit — notes + failing-then-green pure-R oracles +
LOOP + DRAFT PR
HEADLINE: move student + ordinal_probit from na to planned prep;
          no registry row; no public door; not admitted
DEFER: admit; registry planned row; prepare widen; C++ tape;
      estimator="mspl" on either family; NEWS covered; public se=TRUE; merge
DISCIPLINE: OMP=1; verify by logs; never git add -A; no root LOOP/;
            never use /private/tmp/gllvmtmb-mspl-estimator-programme-roadmap
```

## Headline

Move Student-t (identity) and `ordinal_probit` from **na** to
**planned prep only** with family-specific notes and oracles —
without a registry row, without a public door, without admission.

## Invariants

- Workspace ONLY `/tmp/gllvmtmb-mspl-student-ordinal`.
- Branch `cursor/mspl-phase4-student-ordinal` from `origin/main`.
- Lane LOOP only under
  `docs/dev-log/lanes/cursor-mspl-phase4-student-ordinal/LOOP/`.
- Do NOT edit `R/mspl.R`, `src/`, `.gllvmTMB_mspl_prepare()`,
  or add/admit a student or ordinal_probit registry row.
- Do NOT implement SE / intervals / NEWS covered / C++.
- Do NOT merge. DRAFT PR only.
- Local tests only; `OMP_NUM_THREADS=1`.
- Never `git add -A`. Stage explicit paths. Never write repo-root `LOOP/`.
- Never use Dropbox. Never use
  `/private/tmp/gllvmtmb-mspl-estimator-programme-roadmap`.

## Authoritative WHAT

- `docs/dev-log/research/2026-08-15-mspl-phase4-student-prep.md`
- `docs/dev-log/research/2026-08-15-mspl-phase4-ordinal-prep.md`
- `tests/testthat/test-mspl-student-phase4-oracles.R`
- `tests/testthat/test-mspl-ordinal-phase4-oracles.R`
- Programme constitution Phase 4 / ordinal cut class:
  `docs/dev-log/after-task/2026-08-14-laplace-mspl-estimator-programme.md`

## Definition of done

1. **(A)** Both research notes present; board status na → planned
   prep; no registry row.
2. **(B)** Oracles present, watched RED then GREEN; structured
   expect counts recorded; no live `estimator = "mspl"`.
3. **(C)** LOOP kit under this lane folder.
4. **(D)** Explicit-path commit + push + DRAFT PR.
   No merge. Not admitted.

Finish line is **not** admission.
