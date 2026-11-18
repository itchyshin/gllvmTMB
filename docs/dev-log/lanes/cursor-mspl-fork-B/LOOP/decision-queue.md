# Decision queue — cursor-mspl-fork-B

**Lane:** `cursor-mspl-fork-B` (kit on `origin/main` after the reconcile PR)
**Updated:** 2026-08-18 (GOAL_MET; L0 #1130 + L1 #1128 on main)

An empty or OPEN row here **does not waive** a `LOOP/GOAL.md` hard stop. Signing a gate below
unlocks exactly what its row says and nothing adjacent.

---

## Already SIGNED — do not re-ask, do not re-open

| Item | State | Record |
|---|---|---|
| **G4c fork pick** | **SIGNED — B** (2026-08-18) | `docs/dev-log/decisions.md`; fork A retained as ablation only |
| Gate **L0** (plumbing) | **RECORDED PASS** | [#1130](https://github.com/itchyshin/gllvmTMB/pull/1130) `d7f526d4`; #1126 CLOSED |
| Gate **L1** (small local coverage smoke) | **RECORDED PASS** (not calibrated, not public) | [#1128](https://github.com/itchyshin/gllvmTMB/pull/1128) `715326af`; cov_eff 0.880 Wilson [0.762, 0.944] |
| Design **125** | APPROVED programme stub | read-only from this lane |
| ADEMP pre-reg | **SIGNED** 2026-08-17 | frozen; L\* numbers are the gate |
| G4a BINARY-FIRST · G4b E1-E2-ONLY · G4d THRESHOLDS(L\*) · G4e BOOT-PARAMETRIC | **SIGNED** | same pre-reg |
| Design 118 / B1 / Arc 1A | **PARKED** under D-157 | not reopened by anything here |

---

## Still blocked — default **not-ready**

| Gate | Default | Unlocks only when |
|---|---|---|
| **L2** and every gate above it | **blocked** | L1 recorded (done) **and** an explicit Shinichi G0 |
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

Previous queue items 1–3 are **closed by what ran**:

1. Signed G0 + authorising code shipped together as [#1130](https://github.com/itchyshin/gllvmTMB/pull/1130) (decision docs were [#1129](https://github.com/itchyshin/gllvmTMB/pull/1129)). Not uncommitted.
2. L0 tests landed on #1130, not as receipt-only specs.
3. L1 PASS → **stop and record**. This reconcile does **not** draft an L2 G0 request.

**Still open, and only when he asks:** should L2 be a new `/goal` kit (recommended) or an amendment of this one? Default if silent: **new kit**. Do not start it from here.
