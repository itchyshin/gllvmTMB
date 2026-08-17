# Decision queue — mspl-profile-led-ci

**Lane:** `claude/lane-mspl-profile-led-ci` @
`/Users/z3437171/local-scratch/lanes/gllvmTMB-mspl-profile-led-ci`  
**Updated:** 2026-08-17 (**SIGNED** — Shinichi *"approve all things in this lane"*).  
Empty/OPEN does **not** waive `LOOP/GOAL.md` hard stops.

---

## SIGNED 2026-08-17 — mspl-profile-led-ci decision queue

**Author:** cursor/Shinichi-via-chat (*"approve all things in this lane"* / interrupt paste).

```text
SIGNED 2026-08-17 — mspl-profile-led-ci decision queue
G1 PARK SE doors
G2 OPEN-READY-PR
G3 WAIT
G4a BINARY-FIRST
G4b E1-E2-ONLY
G4c FORK-DEFER
G4d THRESHOLDS-SIGN-NOW
G4e BOOT-PARAMETRIC
Still NOT: undraft #1077 · Totoro · public se=TRUE · Design 118 reopen
```

| Gate | State | Record |
|---|---|---|
| **G1** | **SIGNED PARK SE doors** | Card `docs/dev-log/research/2026-08-17-mspl-poisson-W-G0.md` — freeze new SE doors; tape unchanged; KEEP/REPLACE not invented |
| **G2** | **SIGNED OPEN-READY-PR** | Non-draft docs PR of Design 125 + Confirm + LOOP/pre-reg kit → `main`; does **not** undraft #1077 |
| **G3** | **SIGNED WAIT** | No local profile smoke; re-ask after fork A/B/C |
| **G4a** | **SIGNED BINARY-FIRST** | Design 125 §3.1 Bernoulli first; Poisson off coverage claim |
| **G4b** | **SIGNED E1-E2-ONLY** | E1 intercept; E2 loading; E3 = Wald(\(Q_0\)) diagnostic only |
| **G4c** | **SIGNED FORK-DEFER** | Profile fork A/B/C open; blocks G3 smoke and live profile impl |
| **G4d** | **SIGNED THRESHOLDS-SIGN-NOW** | Freeze ADEMP L\* proposed numbers; T\* still need explicit numbers before Totoro |
| **G4e** | **SIGNED BOOT-PARAMETRIC** | Parametric bootstrap; percentile; BCa ablation-only |

**Already locked (do not re-open):**

| Item | State |
|---|---|
| Triad Confirm | **SIGNED** 2026-08-17 (D-157 + D-12) |
| Design **125** | **APPROVED** programme stub @ `b68b20b4` |
| ADEMP pre-reg | **SIGNED** (this queue + card) |
| Design 118 / B1 / Arc 1A | **PARKED** (D-157; Arc 1A historical) |
| #1077 tip | draft `fb44d7b5` — undraft **not-ready** |
| Totoro / public `se=TRUE` / live MSPL `confint` | **not-ready** |

---

## Still blocked / not-ready

| Gate | Default | Unlocks only when |
|---|---|---|
| Undraft #1077 | **not-ready** | Design 125 + pre-reg + fork + tests + **explicit** undraft ask |
| Live `confint(method="profile")` for MSPL | **not-ready** | Design G0 + fork pick + tests |
| Local profile smoke (H1) | **blocked** (G3 WAIT + G4c FORK-DEFER) | Fork A/B/C + new smoke G0 |
| Public `se=TRUE` / `vcov` | **not-ready** | Separate G0 (D-148/D-149) |
| Totoro / claim campaign | **not-ready** | Fork + T\* freeze + L1–L2 + Design 124-style admission + D-50/D-139 G0 |
| Poisson \(W\) KEEP / REPLACE | **open later** | Explicit KEEP or REPLACE paste (PARK freeze holds until then) |

---

## Historical paste menu (superseded by SIGNED block above)

<details>
<summary>Original OPEN GATES paste options (kept for audit)</summary>

### Gate 1 — Poisson \(W\)

- G1 KEEP / G1 REPLACE / G1 PARK SE doors — **chose PARK SE doors**

### Gate 2 — PR to main

- G2 OPEN-DRAFT-PR / **G2 OPEN-READY-PR** / G2 HOLD-BRANCH / G2 SQUASH-LATER

### Gate 3 — Local smoke

- **G3 WAIT** / G3 LOCAL-SMOKE-YES / … / G3 NO-SMOKE

### Gate 4

- **G4a BINARY-FIRST** · **G4b E1-E2-ONLY** · **G4c FORK-DEFER** · **G4d THRESHOLDS-SIGN-NOW** · **G4e BOOT-PARAMETRIC**

</details>
