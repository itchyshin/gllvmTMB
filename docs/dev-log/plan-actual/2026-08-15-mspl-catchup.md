# Plan versus actual — MSPL catch-up (Phase 2 + Phase 3 prep)

**Plan:** `docs/dev-log/plans/2026-08-15-cursor-mspl-catchup-ultra-plan.md`
**G0:** approved 2026-08-15 (implement attached fence; do not wait on #962; Phase 3 = derivation + oracles only)
**Branch:** `cursor/mspl-catchup-ml-laplace`

| Slice | Planned | Actual | Drift |
|---|---|---|---|
| S0 | Recon; no C++/NEWS/root LOOP in Phase 2 | Done before this closeout | none |
| S1 | Land Phase 2 registry | `5f306119`; registry 13 / api 241 | none |
| S2 | Heywood derivation; Sol + Opus review | Prep note written here; Opus folded after interrupt; Sol not waited on | **adaptive** — G0 said do not wait; Opus kill list / E1–E7 / Jeffreys drop / #856 gate folded in without overwriting the (3.2)/(4.1) table |
| S3 | Local R oracles; no Gaussian MSPL fit | `test-mspl-gaussian-heywood-oracles.R`; PASS 68 | **adaptive** — E1–E7 from Opus added on top of the original six algebra/scale/rotation checks |
| S4 | Rose boundary | Written into the prep note §9 and this after-task | none |
| S5 | After-task + check-log + stacked PR | this closeout | none |
| V | `git diff -- src/` empty; no NEWS; no foreign-lane files | confirmed at closeout | none |
| R | This file | this file | none |

**DECISION RECEIPT**

- Questions asked — merge #962 first?; how far is Phase 3?
- Answers received — “do not wait on #962”; “derivation + oracles only”
- Defaults accepted — Hirose as preferred later atom; helpers kept in the test file
- Adaptive decisions — fold Opus without waiting; keep oracles on textbook \((\Lambda,\psi,S)\); drop Jeffreys
- Unresolved — #856 / flat-ridge coordinate map; C++ tape; Gaussian admission; merge

**Not done (declared):** Phase 1B; merge #962 or #961; Gaussian `admitted`; C++; NEWS; campaigns; EVA/VA; E8 two-face diagnostic.

**Material deviations (Melissa axes):**

| Axis | Planned → actual | Tag | Owner |
|---|---|---|---|
| evidence/verification | Sol/Opus before C++ → Opus folded after writeup; Sol unread as a file | adaptive | Ada |
| safety gates | Gaussian stays planned; no C++ | none | — |
| public claims | no NEWS / register promotion | none | — |
