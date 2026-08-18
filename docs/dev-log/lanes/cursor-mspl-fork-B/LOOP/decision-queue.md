# Decision queue — cursor-mspl-fork-B

**Lane:** `cursor/mspl-fork-B-goal-kit` @ `~/local-scratch/lanes/gllvmTMB-mspl-forkB-goal`
**Updated:** 2026-08-18 (kit scaffolded; execution not started)

An empty or OPEN row here **does not waive** a `LOOP/GOAL.md` hard stop. Signing a gate below
unlocks exactly what its row says and nothing adjacent.

---

## Already SIGNED — do not re-ask, do not re-open

| Item | State | Record |
|---|---|---|
| **G4c fork pick** | **SIGNED — B** (2026-08-18) | `docs/dev-log/decisions.md`; fork A retained as ablation only |
| Gate **L0** (plumbing) | **UNLOCKED** by that G0 | pre-reg §P5 |
| Gate **L1** (small local coverage smoke) | **UNLOCKED**, local compute only | pre-reg §P5 |
| Design **125** | APPROVED programme stub @ `b68b20b4` | read-only from this lane |
| ADEMP pre-reg | **SIGNED** 2026-08-17 | frozen; L\* numbers are the gate |
| G4a BINARY-FIRST · G4b E1-E2-ONLY · G4d THRESHOLDS(L\*) · G4e BOOT-PARAMETRIC | **SIGNED** | same pre-reg |
| Design 118 / B1 / Arc 1A | **PARKED** under D-157 | not reopened by anything here |

---

## Still blocked — default **not-ready**

| Gate | Default | Unlocks only when |
|---|---|---|
| **L2** and every gate above it | **blocked** | L1 recorded **and** an explicit Shinichi G0 |
| Totoro / DRAC / any campaign | **blocked** | separate G0 + Design 124-style admission (D-50 / D-139) |
| **T\*** numeric thresholds | **not frozen** | its own G0 — G4d froze **L\*** only |
| Undraft **#1077** | **not-ready** | fork (done) + tests + explicit undraft ask |
| Public `se = TRUE` / `vcov()` / `confint()` | **not-ready** | separate G0 (D-148 / D-149) |
| Register row **MSPL-04** off `blocked` | **not-ready** | evidence path complete, then an explicit ask |
| NEWS / README / article `covered` | **not-ready** | same |
| Widening family / structure / estimand set | **not-ready** | a new G0 — the pre-reg envelope is frozen |
| Editing `R/`, `src/`, `tests/`, `decisions.md`, Design 125 body from **this** kit | **never** | those belong to the sibling lanes; this kit is docs-only |
| Overwriting repo-root `LOOP/` | **never** | it is the closed REPLACE `GOAL_MET` record (#1124) |

---

## Open questions for Shinichi (ask only when an arc actually reaches them)

1. **The signed G0 is still uncommitted.** The 2026-08-18 fork-B decision text sits in a dirty
   worktree on `cursor/g0-unlock-design125-forkB`, alongside the live `R/mspl.R` selector. Should
   `cursor/mspl-forkB-decision` cherry-pick the `decisions.md` hunk, or should that whole branch be
   PR'd as one? *(Recommendation: PR the branch whole — splitting a decision from the code it
   authorises is how the two drift. Safe default if you do not mind: PR it whole.)*
2. **L0 test placement.** If the L0 lane is still holding `tests/testthat/` when A4b comes up, that
   arc can write test **specifications** into the L0 receipt instead of test files. *(Recommendation:
   write the specs — they are useful either way and cost nothing to move later.)*
3. **On an L1 PASS**, does the campaign stop at the recorded verdict, or do you want the L2 G0
   request drafted in the same sitting? *(Recommendation: stop and record. Drafting the ask is cheap
   later, and pre-drafting it invites exactly the scope creep the pre-reg was written to prevent.)*
