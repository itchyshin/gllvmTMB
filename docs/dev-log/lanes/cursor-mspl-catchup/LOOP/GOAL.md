# GOAL — cursor-mspl-catchup-ml-laplace (IMMUTABLE — re-read at the top of EVERY arc)

Read this first, every cycle. Auto-compact eats messages, not this file.

This kit lives at `docs/dev-log/lanes/cursor-mspl-catchup/LOOP/`.
**Do not write repo-root `LOOP/`.** That path is the 0.6 release kit on `main`.

## Mission

Catch LA-MSPL up to LA-ML as a *parallel research estimator* on this
Cursor lane, as far as reversible work allows. Finish line for this
run: current Bernoulli surface is an explicit cell registry (Phase 2)
with unchanged admits/aborts/numbers; Gaussian Heywood is designed
and fenced as the next scientific route (Phase 3 prep), not silently
admitted.

## Headline

Re-express the live Bernoulli MSPL surface as named cells, then prepare
the matched Gaussian factor/Heywood route — without pretending MSPL
already matches Laplace-ML on new families.

## Invariants

- Workspace ONLY `/private/tmp/gllvmtmb-mspl-estimator-programme-roadmap`.
- Do NOT edit the Dropbox checkout or Design 117 / iSDM / G3P / #872 /
  #855 / AA-03 / interval-feasibility files.
- Do NOT write repo-root `LOOP/`.
- TMB `estimator_id` stays 0/1/2. No C++ tape change without a HOLD.
- No accepted-call change. That is Phase 1B — OPEN GATE.
- No merge to main. No NEWS. No register promotion. No default change.
- No campaign. Local targeted tests only. `OMP_NUM_THREADS=1`.
  Any fit >30 min STOP.
- Do not merge the interval/jackknife lane.
- Do not admit Gaussian (or any new family) into `estimator = "mspl"`
  until Phase 3 has its own derivation + local smoke + Shinichi gate.

## Authoritative WHAT

Programme: `docs/dev-log/after-task/2026-08-14-laplace-mspl-estimator-programme.md`
(Phases 2 then 3; 1B/4–8 gated or deferred).

## Definition of done (this run)

1. Explicit Bernoulli registry lists every current admitted cell and
   the current exclusions. B2 is marked `partial_incomplete`, not
   averaged away.
2. `.gllvmTMB_mspl_prepare()` still admits and rejects the same calls
   with the same error classes. `test-mspl-api.R` stays green.
3. Successful MSPL fits carry a registry cell id.
4. Phase 3 Gaussian Heywood is a written design + planned registry
   rows (`status = planned`), not a live admission.
5. After-task + check-log + stacked PR. No merge.

## OPEN GATES

- merge to main
- Phase 1B typed error / deprecation / new criterion API
- NEWS / public claim / validation-register promotion
- C++ tape change
- admitting a new family/link/structure to MSPL
- any campaign / Totoro / DRAC
