# Decision queue — cursor-mspl-fork-B-L2

**Lane:** `cursor-mspl-fork-B-L2`
**Updated:** 2026-08-18 (G0 signed: local L2 only; kit landing)

An empty or OPEN row here **does not waive** a `LOOP/GOAL.md` hard stop.

---

## Already SIGNED — do not re-ask, do not re-open

| Item | State | Record |
|---|---|---|
| **G4c fork pick** | **SIGNED — B** | `docs/dev-log/decisions.md` 2026-08-18; A = ablation only |
| Gate **L0** | **RECORDED PASS** | [#1130](https://github.com/itchyshin/gllvmTMB/pull/1130) `d7f526d4` |
| Gate **L1** | **RECORDED PASS** (not calibrated, not public) | [#1128](https://github.com/itchyshin/gllvmTMB/pull/1128); official cov_eff **0.880** Wilson [0.7620, 0.9438] |
| **Local L2 G0** | **SIGNED 2026-08-18** (AskQuestion) | this kit; multi-seed + near-tail; local only |
| Design **125** + ADEMP | APPROVED / SIGNED | read-only |
| G4a BINARY-FIRST · G4b E1-E2-ONLY · G4d THRESHOLDS(L\*) · G4e BOOT-PARAMETRIC | **SIGNED** | T\* still open |
| Design 118 / B1 / Arc 1A | **PARKED** D-157 | not reopened |
| Closed g0_unlock kit | **GOAL_MET** | `docs/dev-log/lanes/cursor-mspl-fork-B/` — do not reopen |
| Repo-root `LOOP/` | **GOAL_MET** REPLACE | do not overwrite |

---

## Still blocked — default **not-ready**

| Gate | Default | Unlocks only when |
|---|---|---|
| Totoro / DRAC / T1 / T2 | **blocked** | L2 **recorded** *and* a **new** Shinichi G0 + Design 124-style admission |
| **T\*** numeric thresholds | **not frozen** | its own G0 — G4d froze **L\*** only |
| Undraft **#1077** | **not-ready** | explicit undraft ask |
| Public `se = TRUE` / `vcov()` / `confint()` | **not-ready** | separate G0 (D-159 / D-149) |
| Register row **MSPL-04** off `blocked` | **not-ready** | evidence path complete, then an explicit ask |
| NEWS / README / article `covered` | **not-ready** | same |
| Applying L1's 0.80 Wilson rule as a new L2 freeze | **never** | that would be a silent T\* |
| Widening family / structure / E2 | **not-ready** | new G0 |
| Editing closed g0_unlock kit or root `LOOP/` | **never** | — |

---

## Open questions for Shinichi

**None that block L2 recording.** Do not draft a Totoro ask from this kit
unless he asks.
