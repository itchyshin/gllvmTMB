# GOAL — cursor-mspl-catchup-ml-laplace (IMMUTABLE — re-read at the top of EVERY arc)

Read this first, every cycle. Auto-compact eats messages, not this file.

This kit lives at `docs/dev-log/lanes/cursor-mspl-catchup/LOOP/`.
**Do not write repo-root `LOOP/`.** That path is the 0.6 EVA/VA kit on `main`.

This is **LA-MSPL**, not EVA.

## Mission

Solo platform: Cursor.

Landed Phase 2 Bernoulli cell registry with unchanged admits /
aborts / numbers, plus a Sol/Opus-reviewed Gaussian Heywood
derivation and local oracles that do not admit Gaussian MSPL.

Finish line for this run: those artefacts are on `main` via
authorized merge of PR **#963** only.

## Headline

Make LA-MSPL a truthful parallel to LA-ML on the live binary
surface, then earn the first matched Gaussian cell on paper and
in oracles — not by transplanting the Bernoulli penalty.

## Invariants

- Workspace ONLY `/private/tmp/gllvmtmb-mspl-estimator-programme-roadmap`.
- Branch `cursor/mspl-catchup-ml-laplace`. Lane LOOP only.
- Do NOT edit the Dropbox checkout or Design 117 / iSDM / G3P /
  #872 / #855 / AA-03 / interval-feasibility files.
- Do NOT write repo-root `LOOP/`.
- TMB `estimator_id` stays 0/1/2. No C++ tape change.
- No Phase 1B accepted-call change.
- Merge **#963** is authorized. Do **not** merge #962 or #961.
- No NEWS. No register promotion. No default change.
- No campaign. Local targeted tests only. `OMP_NUM_THREADS=1`.
  Any fit >30 min STOP.
- Do not admit Gaussian (or any new family) into
  `estimator = "mspl"`. Do not flip `planned` → `admitted`.
- "Keep going" means finish this GOAL and merge #963. It does
  **not** mean start Phase 3 live admission.

## Authoritative WHAT

`docs/dev-log/lanes/cursor-mspl-catchup/LOOP/ultra-plan.md`
(copy of `docs/dev-log/plans/2026-08-15-cursor-mspl-catchup-ultra-plan.md`).
Programme: `docs/dev-log/after-task/2026-08-14-laplace-mspl-estimator-programme.md`.

## Definition of done

1. Explicit Bernoulli registry lists every current admitted cell
   and the current exclusions. B2 stays `partial_b2_incomplete`.
2. `.gllvmTMB_mspl_prepare()` still admits and rejects the same
   calls with the same error classes. `test-mspl-api.R` stays green.
3. Successful MSPL fits carry a registry cell id.
4. Phase 3 Gaussian Heywood is a written design + planned registry
   rows (`status = planned`), not a live admission. Symbolic
   alignment table present. Oracles do not call Gaussian MSPL.
5. After-task + Melissa plan-actual exist.
6. PR #963 is merged (merge commit). `src/` still empty vs that PR.

## OPEN GATES (do not execute)

- Phase 1B typed error / deprecation / new criterion API
- merge #962 or #961
- Gaussian uniqueness mapping / #856
- C++ tape change
- flipping Gaussian rows to `admitted`
- NEWS / public claim / validation-register promotion
- any campaign / Totoro / DRAC
