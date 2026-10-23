# Decision queue — mspl-profile-led-ci

**Lane:** `claude/lane-mspl-profile-led-ci` @
`/Users/z3437171/local-scratch/lanes/gllvmTMB-mspl-profile-led-ci`  
**Updated:** 2026-08-18 — **G4c discharged: fork B.** (Base sign 2026-08-17,
Shinichi *"approve all things in this lane"*.)

Empty/OPEN does **not** waive `LOOP/GOAL.md` hard stops.

> **2026-08-18 amendments (both supersede the 2026-08-17 block below).**
> **G4c `FORK-DEFER` → `FORK-B`**: the profile arm is the **unpenalized
> Laplace at fixed MSPL nuisance**; fork A (penalised MSPL profile) is an
> **ablation arm only**; fork C is not picked. Reason: Kosmidis & Firth (2021)
> §2.2 p. 5 — the finiteness-penalty coverage failure *"is also true when the
> penalized likelihood is profiled"*, which pre-refutes a fork-A coverage
> programme. **G1 `PARK SE doors` → Poisson \(W\) `SIGNED REPLACE`**, landed as
> [#1111](https://github.com/itchyshin/gllvmTMB/pull/1111) (merge `3053fce3`).
> Recorded in `docs/dev-log/decisions.md` (2026-08-18).
> **Unchanged:** G3 `WAIT` is *not* auto-lifted — smoke needs its own G0;
> #1077 stays draft; no public `se=TRUE`; `MSPL-04` `blocked`; no Totoro.

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
| **G1** | **SIGNED REPLACE** *(2026-08-18 sync; the 2026-08-17 `PARK SE doors` reading is superseded)* | Card `docs/dev-log/research/2026-08-17-mspl-poisson-W-G0.md` — working \(W_*\) landed (#1111, `3053fce3`); SE-series **family doors stay closed** |
| **G2** | **SIGNED OPEN-READY-PR** | Non-draft docs PR of Design 125 + Confirm + LOOP/pre-reg kit → `main`; does **not** undraft #1077 |
| **G3** | **SIGNED WAIT** | No local profile smoke; re-ask after fork A/B/C |
| **G4a** | **SIGNED BINARY-FIRST** | Design 125 §3.1 Bernoulli first; Poisson off coverage claim |
| **G4b** | **SIGNED E1-E2-ONLY** | E1 intercept; E2 loading; E3 = Wald(\(Q_0\)) diagnostic only |
| **G4c** | **SIGNED FORK-B** *(2026-08-18; was `FORK-DEFER` 2026-08-17)* | Fork **B** = unpenalized Laplace at fixed MSPL nuisance. Fork **A** = ablation only; **C** not picked. No longer blocks the fork axis; G3 smoke still needs its own G0 |
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
| Undraft #1077 | **not-ready** | Fork is picked (B); still needs tests + **explicit** undraft ask |
| Live `confint(method="profile")` for MSPL | **not-ready** | Fork is picked (B); still needs public-door G0 + tests |
| Local profile smoke (H1/L1) | **blocked** (G3 `WAIT` only — the G4c fork block is **cleared**) | New smoke G0 |
| Public `se=TRUE` / `vcov` | **not-ready** | Separate G0 (D-159/D-149) |
| Totoro / claim campaign | **not-ready** | T\* freeze + L1–L2 + Design 124-style admission + D-50/D-139 G0 (fork no longer outstanding) |
| Poisson \(W\) KEEP / REPLACE | **CLOSED — REPLACE** | Signed 2026-08-17; landed #1111. SE-series family doors stay closed until rematch/recovery evidence carries them |

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
