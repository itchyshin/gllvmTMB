# Arcs — profile-led MSPL intervals (from LOOP/ultra-plan.md)

Status: todo / doing / done / blocked. Gate = needs human before proceed.

| ID | arc | status | gate? | notes |
|---|-----|--------|-------|-------|
| R0 | Recon: #1077 scaffold + assert_inference map + Confirm-in-ref check | **done** | — | Critical: Confirm was uncommitted on overnight WT; now committed on this lane. #1077 tip `fb44d7b5` draft. |
| R1 | Read-only Design 118 / B1 negative lessons extract | **done** | — | See `docs/dev-log/research/2026-08-17-mspl-profile-led-r1-lessons.md`. No Design 118 edits. |
| S1 | Draft Design stub; claim NN by commit | **done** | — | Claimed `docs/design/125-mspl-profile-led-intervals.md` @ `b68b20b4`. **APPROVED** 2026-08-17 as D-157 new-construction Design. |
| S2 | ADEMP-style pre-registration | **done (SIGNED)** | — | Signed 2026-08-17: G4a BINARY-FIRST, G4b E1-E2-ONLY, G4c FORK-DEFER, G4d THRESHOLDS-SIGN-NOW, G4e BOOT-PARAMETRIC. |
| S3 | Parallel: Poisson W G0 / PARK SE doors note | **todo** (card **UNSIGNED**) | **OPEN if inventing KEEP/REPLACE/PARK SIGNED** | Card `2026-08-17-mspl-poisson-W-G0.md` remains **UNSIGNED**. Silent default = operational PARK further SE doors; Gate 1 PARK paste says card stays UNSIGNED until KEEP/REPLACE. Do **not** invent SIGNED. |
| S4 | Rose fence pass on S1–S2 | **done** | — | PASS; #1077 draft; MSPL-04 blocked. |
| V1 | Verify: #1077 draft; MSPL-04 blocked; no Design 118 edits | todo | — | Mechanical. |
| C1 | Melissa reconcile + after-task + handover refresh | doing | — | Sign + non-draft docs PR (G2). |
| H1 | Optional HANDS TO Codex: local profile smoke | **blocked** | **G3 WAIT + G4c FORK-DEFER** | No smoke until fork A/B/C picked + new G0. |

**PARALLEL:** {R0, R1, S3} then {S1 → S2 → S4 → V1 → C1}
**HARD STOPS:** no undraft #1077 · no real `confint(method="profile")` · no public `se=TRUE` · no Design 118/B1/Totoro · no Arc 1A reopen · no invent Poisson W KEEP/REPLACE/PARK as **SIGNED** (silent default PARK only)

## Gates (L2)

| Gate | When | Default |
|---|---|---|
| Undraft #1077 | After Design + pre-reg + fork + tests | **not-ready** until explicit ask |
| Live profile impl | After fork pick + Design G0 | **not-ready** (FORK-DEFER) |
| Local profile smoke | After fork + smoke G0 | **blocked** (G3 WAIT) |
| Public se=TRUE | Separate G0 | **not-ready** |
| Totoro/campaign | Separate G0 + T\* freeze (D-50/D-139/D-157) | **not-ready** |
| Poisson W KEEP/REPLACE/PARK | Shinichi paste only | leave card **UNSIGNED**; silent default PARK further SE doors |
