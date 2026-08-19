# Decision queue — cursor-mspl-fork-B-totoro

**Lane:** `cursor-mspl-fork-B-totoro`
**Updated:** 2026-08-18 (G0 signed: Totoro T1 RECORD only; kit landing)

An empty or OPEN row here **does not waive** a `LOOP/GOAL.md` hard stop.

---

## Already SIGNED — do not re-ask, do not re-open

| Item | State | Record |
|---|---|---|
| **G4c fork pick** | **SIGNED — B** | `docs/dev-log/decisions.md` 2026-08-18; A = ablation only |
| Gate **L0** | **RECORDED PASS** | [#1130](https://github.com/itchyshin/gllvmTMB/pull/1130) `d7f526d4` |
| Gate **L1** | **RECORDED PASS** (not calibrated, not public) | [#1128](https://github.com/itchyshin/gllvmTMB/pull/1128); official cov_eff **0.880** Wilson [0.7620, 0.9438] |
| Gate **L2** | **RECORDED** (GOAL_MET) | [#1162](https://github.com/itchyshin/gllvmTMB/pull/1162) / [#1168](https://github.com/itchyshin/gllvmTMB/pull/1168); Seed B/C **0.900**; near-tail **0.780** |
| **Totoro T1 G0** | **SIGNED 2026-08-18** (unattended) | this kit; 800-fit RECORD-only grid; Totoro allowed |
| **T1 hold-out grid** | **LOCKED** | `docs/dev-log/research/2026-08-18-mspl-forkB-totoro-grid-proposal.md`; 4×200; seeds `20260830`–`33` |
| Design **125** + ADEMP | APPROVED / SIGNED | read-only; G4d froze **L\*** only |
| G4a BINARY-FIRST · G4b E1-E2-ONLY · G4d THRESHOLDS(L\*) · G4e BOOT-PARAMETRIC | **SIGNED** | T\* still open |
| Design 118 / B1 / Arc 1A | **PARKED** D-157 | not reopened |
| Closed L2 kit | **GOAL_MET** | `docs/dev-log/lanes/cursor-mspl-fork-B-L2/` — do not reopen |
| Closed g0_unlock kit | **GOAL_MET** | `docs/dev-log/lanes/cursor-mspl-fork-B/` — do not reopen |
| Repo-root `LOOP/` | **GOAL_MET** REPLACE | do not overwrite |

---

## Still blocked — default **not-ready**

| Gate | Default | Unlocks only when |
|---|---|---|
| **T\*** numeric thresholds | **not frozen** | its own G0 after these 800 rows are read |
| Undraft **#1077** | **not-ready** | explicit undraft ask |
| Public `se = TRUE` / `vcov()` / `confint()` | **not-ready** | separate G0 (D-159 / D-149) |
| Register row **MSPL-04** off `blocked` | **not-ready** | evidence path complete, then an explicit ask |
| NEWS / README / article `covered` | **not-ready** | same |
| Applying L1's 0.80 Wilson rule as a T\* freeze | **never this sitting** | that would silently fail L2 near-tail 0.780 and is too weak at \(n=200\) |
| Optional confirm `T1-confirm-n80-T8` / seed `20260834` | **out of primary 800** | only after the four hold-outs have inspected 1-rep objects on Totoro |
| Widening family / structure / E2 | **not-ready** | new G0 |
| Editing closed L2 / g0_unlock kits or root `LOOP/` | **never** | — |

---

## Open questions for Shinichi

1. **T\* option A / B / C** — read
   `docs/dev-log/research/2026-08-19-mspl-forkB-tstar-discussion-packet.md`
   (landing PR for items 2–4, 2026-08-19). **Not frozen** by that file.
2. **DRAC confirm `/goal`?** — kit at
   `docs/dev-log/lanes/cursor-mspl-fork-B-drac-confirm/LOOP/` (recommended if
   Option A or B).
