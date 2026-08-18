# Design 125 — Profile-led MSPL intervals (new construction under D-157)

**Status: APPROVED (programme stub).** Docs-only claim of Design number **125**.
**SIGNED 2026-08-17** by cursor/Shinichi-via-chat — *"approve all things in this
lane"* — as the **D-157 new-construction Design** for profile-led MSPL
intervals. Soft scope **binary-first** (§3.1) is **APPROVED**. Companion ADEMP
pre-reg is signed separately
(`docs/dev-log/research/2026-08-17-mspl-profile-led-prereg-ademp.md`).

**Amended 2026-08-18 — G4c is discharged: the profile fork is B.** The gate that
this stub left open is now signed. **Fork B** (unpenalized Laplace at fixed MSPL
nuisance) is the signature construction; **fork A** (profiling the penalised MSPL
tape) is an **ablation arm only**; **fork C** (hybrid) is not picked. See §2.1 for
the fork definitions and the measured reason. Recorded in
`docs/dev-log/decisions.md` (2026-08-18). Also synced in this amendment: the
Poisson \(W\) card is **SIGNED — REPLACE** and the tape change has **landed**
([#1111](https://github.com/itchyshin/gllvmTMB/pull/1111), merge `3053fce3`), so
every *"PARK SE doors"* reading below is historical (§3.1, §5); and MSPL-interval
citations formerly written `D-148` now read **D-159** after the 2026-08-18 vault
renumbering. What this amendment does **not** change: `MSPL-04` stays `blocked`,
#1077 stays draft, no public `se=TRUE` / `vcov` / `confint`, no Totoro, no
Design 118 recalibration, and SE-series family doors stay closed.

This file opens the post–B1 construction path; it is **not** permission to run
Totoro/DRAC, **not** permission to undraft [#1077](https://github.com/itchyshin/gllvmTMB/pull/1077),
and **not** permission to ship public `confint` / `vcov` / `se=TRUE`.

**Number-ledger check:** `tools/lane_preflight.sh` on 2026-08-17 against this
lane reported **NEXT FREE = 125** (highest across all refs; Design 124 claimed
as `docs/design/124-campaign-admission.md`). Slot **125** is claimed by the
commit that adds this file.

**Lane:** `claude/lane-mspl-profile-led-ci` @
`/Users/z3437171/local-scratch/lanes/gllvmTMB-mspl-profile-led-ci`.

**Authority (no new vault D-):**

| Binding | Role here |
|---|---|
| **D-157** | B1 PARK; later intervals = **new** construction + **new** pre-registration — not Design 118 recalibration, not \(n\to 2000\), no Totoro relaunch |
| **D-12** | Profile = featured/hero CI; speed order Wald ≪ profile ≪ bootstrap |
| **Triad Confirm SIGNED 2026-08-17** | Profile = signature; Wald(\(Q_0\)) = availability; Bootstrap = asymmetry (`docs/dev-log/research/2026-08-17-mspl-ci-wald-plus-profile.md`) |
| **D-159 / D-149** | **D-159** = MSPL-interval withhold / build-the-calibrated-route (vault; was mis-cited as D-148). **D-149** = SE pins ≠ public CI; if/ever Wald SE → report \(Q_0\). Public calibrated intervals still withheld. **D-148** is the never-ask-bare draft-reply rule — not this fence. |
| **D-50 / D-139** | Campaign compute needs separate admission + G0; this stub authorises **docs only** |

**Provenance for this stub:** R0 inventory
(`docs/dev-log/research/2026-08-17-mspl-profile-led-r0-inventory.md`) and R1
negative lessons
(`docs/dev-log/research/2026-08-17-mspl-profile-led-r1-lessons.md`); frozen plan
`LOOP/ultra-plan.md`.

---

## 0. What this Design answers (and what it refuses)

**Answers (eventually, after pre-reg + separate G0s):** how to construct and
pre-register **profile-primary** uncertainty for LA-MSPL under the signed
triad, with Wald(\(Q_0\)) as availability triage and bootstrap as the asymmetry
arm — without reusing the spent Design 118 / B1 Wald-calibrator.

**Refuses in this stub sitting:**

- Reopening or editing `docs/design/118-mspl-interval-calibration-protocol.md`
- Relaunching B1 / Totoro / hold-out H1∪H2∪H3
- Undrafting #1077 or wiring MSPL into public `confint`
- Flipping register row **MSPL-04** off `blocked`
- NEWS / article / README claims of `covered` intervals
- Reopening Poisson \(W=\mathrm{diag}(\mu)\) KEEP (REPLACE is **SIGNED** and
  landed on `main` as #1111 — tape change is done; SE-series family doors
  stay closed)
- Recalibrating Design 118 (a 2026-08-18 **D-148→D-159 numbering note** in
  that file is the only authorised edit — not a protocol change)
- Reopening Arc 1A LOOP (`docs/dev-log/lanes/cursor-mspl-arc-1a/` is historical)

---

## 1. Parked predecessors — do not repeat (from R1)

1. **Wald-as-brand is dead.** B1 FAIL killed treating Wald / level-calibrated
   Wald as the house interval. New construction is **profile-primary**.
2. **Hold-out is spent.** Design 118 §5.7: H1∪H2∪H3 retired for that
   construction. A second campaign on the same gate needs written deviation —
   out of scope; D-157 chooses new construction instead.
3. **Do not recalibrate Design 118.** Not \(n\to 2000\); not M1/M2 map surgery;
   not Totoro relaunch of the parked protocol.
4. **Overcoverage premise failed transfer.** Train preview ≠ gate. Name
   estimands + asymmetry **before** any coverage campaign.
5. **Availability ≠ coverage.** G3 availability failures and G2 location
   failures are distinct; Wald(\(Q_0\)) here is **availability / quick
   baseline**, not a coverage claim.
6. **Refusal rules matter.** G4 anchor refusal was the rare PASS — pre-reg
   (Design 125 §S2) must name refusal / fence rules explicitly.
7. **MSPL-04 stays `blocked`** until this Design + pre-reg + evidence path
   succeeds.
8. **Public doors stay closed** until separate G0s (D-159/D-149).

---

## 2. Triad roles (binding for this construction)

| Method | Role in Design 125 | What it is **not** |
|---|---|---|
| **Profile** | **Signature / primary claim path** (D-12 hero) | Not “slow Wald”. Not Design 118. Not automatic public `confint` without pre-reg + G0 + tests |
| **Wald (\(Q_0\))** | **Quickest baseline / availability** — finite SE? PD \(Q_0\)? rough width? | Not the brand. Not a calibrated public interval programme (B1 FAIL) |
| **Bootstrap** | **Asymmetry / non-symmetric sampling** (percentile; saturation refuse) | Not a repair for Wald undercoverage on a misspecified centre. Not BCa-by-default |

Speed / cost order (D-12): **Wald → profile → bootstrap**.

### 2.1 Profile fork (G4c SIGNED 2026-08-18 — fork B)

The profile arm is **unpenalized Laplace at the fixed MSPL nuisance**.
Fork A (penalised MSPL profile) is ablation only — the #1090 probe
landing that tape must not be read as picking A. Fork C is not picked.
This Design records the fork; the L0 lane implements it. Public
`confint` stays refused. Reason: Kosmidis & Firth (2021) §2.2 — the
finiteness-penalty coverage failure survives profiling, so a fork-A
coverage programme is pre-refuted (`docs/dev-log/decisions.md`,
2026-08-18).

---

## 3. Scope fence (stub defaults — S2 pre-reg may refine, not silently widen)

### 3.1 Family

**SIGNED soft G0 (2026-08-17) — G4a BINARY-FIRST:** **binary / Bernoulli
LA-MSPL first** (logit / probit / cloglog as already admitted for MSPL point
estimation). Poisson (and other count families) stay on the **point / SE-atom**
track. Poisson \(W\) is **SIGNED REPLACE** (#1111) — that is a tape fix, not
a widen of this coverage claim. Count families remain **out** of the first
profile-led coverage claim set until a later widen G0.

### 3.2 Estimands (narrow — refuse silent expansion)

Stub names the **minimum** estimand set for the first pre-reg draft (S2).
Anything else is out until explicitly added:

| ID | Estimand | Notes |
|---|---|---|
| E1 | Per-trait **intercept** \(\beta_{0t}\) | Primary location target |
| E2 | Per-trait **loading** \(\Lambda_{t1}\) (and \(d=2\) second column only if the fitted model admits `d=2`) | Loadings are the MSPL signature surface; refuse saturated / pinned coordinates (§4) |
| E3 | **Optional diagnostic only:** Wald(\(Q_0\)) SE availability flags for E1–E2 | Not a coverage estimand |

**Explicitly out of first claim set:** communality, LV scores as public CI
targets, cross-family correlations, phylo/spatial tier parameters, model-level
`logLik` / AIC / LRT (all still under MSPL-04 blocked semantics).

### 3.3 Construction order (docs → smoke → campaign)

1. This stub (S1) — claim NN.
2. ADEMP-style pre-registration (S2) — estimands, families, local-then-Totoro
   gates, refusal taxonomy frozen.
3. **2026-08-18:** G4c fork **B** is signed. L0 implements the unpenalized
   profile path internally (`calibrated = FALSE`, public refuse). Undraft of
   #1077 still needs a **separate** explicit G0.
4. Local profile smoke (L1) only after L0 lands; not this docs arc.
5. Totoro / claim-bearing campaign only after Design 124-style admission +
   D-50/D-139 G0 — **not authorised by this stub**.

---

## 4. Refusal taxonomy (stub; freeze wording in S2)

Intervals (and later public doors) **must refuse** rather than silently widen
or nail a needle on a spent centre. Minimum classes:

| Code | Trigger (sketch) | Action |
|---|---|---|
| R-SAT | Response-column saturation / separation screen fires (Design 88 / 117 lineage) | **Refuse** coordinate interval; do not bootstrap-fallback on saturated coords |
| R-PIN | Penalty-determined / pinned loading (Design 118 A1b class) | **Refuse** as primary claim; optional secondary measurement only under pre-reg |
| R-NAVL | Profile root-finder / path unavailable (no finite profile CI) | Record **availability failure**; do not substitute uncalibrated Wald as “the” CI |
| R-Q0 | \(Q_0\) not PD or SE not finite | Wald arm reports **unavailable**; does not unblock profile |
| R-FENCE | Public API called on MSPL fit (`confint` / `vcov` / `se=TRUE`) while MSPL-04 blocked | Keep existing `.gllvmTMB_mspl_assert_inference` refusal; #1077 stub stays unexported |

S2 must turn these sketches into measurable, pre-registered rules (observables,
messages, and which arms may still report diagnostics).

---

## 5. Scaffold and register fences (mechanical)

| Surface | Required state under Design 125 stub |
|---|---|
| PR **#1077** (`cursor/mspl-profile-ci-scaffold`, tip `fb44d7b5`) | Remains **draft**; unexported helpers only; not wired into `R/z-confint-gllvmTMB.R` |
| Register **MSPL-04** | Remains **`blocked`** |
| Design **118** file | **Read-only**; no recalibration edits from this lane |
| Public `se=TRUE` / `vcov` / Wald `confint` | **Closed** until separate G0 |
| Poisson \(W\) card | **SIGNED REPLACE** (2026-08-17; landed #1111) — working \(W_*\); SE-series family doors stay closed |
| G4c profile fork | **SIGNED fork B** (2026-08-18) — unpenalized Laplace at fixed MSPL nuisance; A = ablation only |

---

## 6. What S2 must add (pre-registration — not this file’s job)

- ADEMP Aims / Data-generating mechanisms / Estimands / Methods / Performance
  measures (Morris et al. style), with local smoke gates before any Totoro
  gate.
- Frozen seed / cell / family grid for the **binary-first** claim.
- Explicit map from refusal codes (§4) to pass/fail / secondary outcomes.
- Statement that Design 118 hold-out is **not** reused.
- Explicit “does not undraft #1077” and “does not flip MSPL-04” until evidence
  lands.

---

## 7. Non-claims (Rose fence)

This stub does **not**:

- Authorise undraft of #1077 or implementation of real MSPL
  `confint(method = "profile")`.
- Authorise public `se=TRUE`.
- Unblock MSPL-04.
- Reopen Design 118, B1, Totoro, or Arc 1A.
- Reopen Poisson \(W\) KEEP (REPLACE is signed and landed; SE doors stay closed).
- Ship NEWS `covered` language.

**Companions:** ADEMP pre-reg
`docs/dev-log/research/2026-08-17-mspl-profile-led-prereg-ademp.md` (2026-08-18
G4c + REPLACE sync in the same PR); Poisson W
`docs/dev-log/research/2026-08-17-mspl-poisson-W-G0.md` (**SIGNED REPLACE**,
#1111). Next: L0 plumbing (sibling lane); **not** undraft #1077.

