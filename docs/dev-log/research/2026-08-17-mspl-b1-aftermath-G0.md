# G0 — B1 aftermath: park, redesign the calibrator, or new construction

**Status:** SIGNED — **PARK** (brain **D-157**, 2026-08-17).
**When:** 2026-08-17 05:00 (overnight track); signed 2026-08-17 morning.
**Reader:** Shinichi.
**Author:** Cursor (Ada / Fisher / Rose). Docs only. No Totoro relaunch.
**Question:** Design 118 Phase B failed its official hold-out. What happens to binary LA-MSPL intervals now?

**Shinichi paste (exact):**

> Park. No second campaign. MSPL-04 stays blocked. No Totoro relaunch. If we want intervals later, that is a new construction and a new pre-registration, not a Design 118 recalibration and not n to 2000.

This closes the call document D-155 left open. Decision id: **D-157**. It does not promote an interval, does not edit `MSPL-04` off blocked, and does not start compute.

---

## What is already true

The overnight track closed on these facts. They are not the decision.

| Fact | Source |
|---|---|
| B1 table complete: 7920/7920 shards, 132/132 cells, 0 fatals | harvest `docs/dev-log/research/2026-08-16-mspl-b1-complete.md` |
| Calibrator map frozen from the **calibration split only** at **M0** (\(h=0\), \(\alpha^*=0.05\)) | [#1040](https://github.com/itchyshin/gllvmTMB/pull/1040); `2026-08-16-mspl-b1-calibrator-map-freeze.md` |
| Official post-freeze `--holdout`: conjunction **G1–G5 FAIL** | #1040; `2026-08-16-mspl-b1-holdout-gate.md` |
| G1 | **14/132 = 10.6% PASS** (need ≥90%). 93 FAIL, 25 INDETERMINATE |
| G2 | **FAIL.** Min coverage **0.0218** (B106 H1 probit \(\pi=0.97\), \(q=2\), median) |
| G3 | **FAIL.** 10/132 rows availability < 0.95; min **0.200** (B126 H3 cloglog \(\pi=0.20\), min) |
| G4 | PASS. Anchor refusal 0.000–0.043 |
| G5 | PASS (vacuous: M0 has no \(\gamma\)) |
| DEV-10 (#1020) does not save the gate | Excluding those 15 rows: 13/117 = 11.1% PASS; min coverage still 0.0218 |
| Design 118 §5.6 on gate fail | Do not promote. Design 88 point-only fence stands. Write the negative result. |
| Design 118 §5.7 | Hold-out is read once. No refit on hold-out. A second campaign needs a written deviation, a **retired** hold-out, and a **fresh** hold-out. |
| Public `confint()` / `vcov()` / `se=TRUE` | Still withheld. `MSPL-04` stays `blocked`. |
| \(n\to 2000\) | **Not launched.** Cannot reach 90% PASS (see below). |

Train-only preview, used only to freeze M0 and **not** the gate: 63 PASS / 163 FAIL / 38 INDETERMINATE of 264 (cell, target) rows. OVER and UNDER were almost equal (64 vs 60). That is why the freeze stopped at the identity map and refused Phase A's M1 lift (\(\alpha^*\approx 0.14\)): a constant narrowing would help the small-\(n\) overcoverage pocket and worsen the large-\(n\) undercoverage pocket.

---

## Two hold-out reads. Do not collapse them.

The overnight track's official gate is **#1040 / M0**. A later Claude evaluator (#1056, Design 118 §8 DEV-11/DEV-12, vault D-155) scored a **different frozen map (M2)** and also failed. They are both negative results. They are not one number.

| | Official overnight gate (#1040) | Later evaluator (#1056 / DEV-11) |
|---|---|---|
| Frozen map | **M0** identity, \(\alpha^*=0.05\) | **M2** \(\gamma_0=-1.8733\), \(\gamma_{c_n}=+0.3259\), \(\alpha^*\approx 0.0086\)–\(0.0097\) |
| G1 | 14/132 = **10.6%** PASS | **0.0%** (0 PASS / 12 FAIL / 105 NO_DATA of 117) |
| G2 | FAIL (min 0.0218) | MEETS (scored rows overcover at 1.000) |
| G3 | FAIL (10/132 avail < 0.95) | MEETS (1.0000 among surviving rows) |
| G4 | PASS | FAIL |
| What it shows | Nominal profile intervals do not cover on the declared hold-out | The §2.4 objective has a degenerate optimum: refusing hard cells beat calibrating them (0.0690 over 30 units vs 12.985 over 264) |

#1056 also records DEV-12: on the B1 **training** grid, 131 of 264 units cover **below** 0.95 (min 0.0078). Phase A's "failures run toward overcoverage, the calibratable direction" did not transfer. That finding is independent of which map you freeze.

The #1056 verdict write-up (`docs/dev-log/2026-08-16-phase-b-verdict-and-recommendation.md`) is referenced from Design 118 and the check-log but is **not on `origin/main`**; it lives on `claude/mspl-b0-prereqs`. This G0 does not need that file. #1040 plus Design 118 §5.6/§5.7 are enough to decide.

---

## The three options

\(n\to 2000\) is **not** an option. Design 118 §2.5 named it for INDETERMINATE hold-out cells only. #1040 listed 17 such cells and did not launch them. Even if every INDETERMINATE row flipped to PASS, G1 would be \(14+25=39/132=29.5\%\). G2's 0.0218 is a location failure, not a Wilson-width problem. Escalation cannot reach the gate.

### A. Park — **DEFAULT**

Do what Design 118 §5.6 already requires on a failed gate.

- Do not promote the construction.
- Do not launch a second Totoro or DRAC campaign.
- Do not refit \(\gamma\) on the spent hold-out.
- Keep `MSPL-04` `blocked`. Keep public `confint()` / `vcov()` / `se=TRUE` withheld.
- Keep the 7920-shard table as a re-analysable archive (Totoro `~/gllvmtmb-local-artifacts/b1-full-20260816/`).
- Continue the live Cursor work (SE-series pins, planned doors). Binary intervals stay fenced.

This is a negative result, which Design 117 §6.3 already said was worth writing. The campaign bought a complete table, a working fence on well-identified anchors (G4), and the DEV-12 finding that the overcoverage premise does not hold on this grid.

### B. Redesign the calibrator

Reuse Design 118's construction (level-calibrated penalised profile + global \(h(v)\)) with a repaired map: price refusal, make the admission rule denominator-invariant, then evaluate on a **fresh** hold-out (Design 118 §5.7 rule 2). The used H1 ∪ H2 ∪ H3 blocks are retired. This is a second campaign. It is not a free re-score of the same 44 cells.

Why this is the weaker 05:00 pick:

1. **M0 already is the honest map for this construction.** The train split was split in half (OVER ≈ UNDER). #1040 froze identity for that reason. G1 at 10.6% is the identity map failing, not a near-miss that a \(\gamma\) tweak closes.
2. **A single global monotone \(h(v)\) may be the wrong target.** Half the training units want \(\alpha^*<0.05\) and half want \(\alpha^*>0.05\) (DEV-12). That is a representability problem, not a coefficient problem.
3. **#1056 shows the registered ladder can win by refusing.** Repairing \(\gamma\) without first changing how refusal is priced repeats DEV-11.
4. Rule 2 still costs a new hold-out and new seeds. That is compute. This sitting does not relaunch Totoro.

Rule 2 remains legal if you later want one recalibration attempt. It is not the default.

### C. New construction

Change the interval, not only \(\alpha^*\). Candidates the protocol already named and set aside: Wald, BCa (A4; literature gate uncleared), union CI (wrong direction for an over/under mix), unpenalised profile, a regime-split rather than one global map. This needs a **new Design number** and a **new pre-registration**. Design 118 is discharged (#1056). D-155 already says the remedy is a new packet, not an amendment.

This is the right *later* programme if you still want shipped binary MSPL intervals. It is the wrong 05:00 default: it authorises a new methods arc, new compute, and a new hold-out before the SE-series pins are finished. The B1 table stays usable as design evidence for that packet. No fits run until that packet is signed.

---

## Recommendation

**Park.**

#1040 already applied Design 118 as written: freeze M0 from train, read hold-out once, stop. The conjunction failed by a wide margin (10.6% vs 90%; min coverage 0.0218). §5.6's prescribed action is "do not promote; write the negative result." That is park.

Redesign assumes the construction is right. The train split and DEV-12 say the construction's motivating asymmetry is false on this grid. New construction is the honest follow-on if intervals come back, and it waits for a signed packet. Neither is a 05:00 launch.

If you later reopen intervals, pick **C**, not B, and not \(n\to 2000\).

---

## Draft reply (D-148)

Paste one. Edit or ignore.

> **Park.** No second campaign. MSPL-04 stays blocked. No Totoro relaunch. If we want intervals later, that is a new construction and a new pre-registration, not a Design 118 recalibration and not n to 2000.

Alternatives, same register:

> Redesign the calibrator. One Design 118 rule-2 reuse: price refusal, new hold-out, same profile construction. No n to 2000. Do not start Totoro until the deviation note is written.

> New construction. Write a new pre-registration first. No Totoro until that is signed. Do not reuse the spent hold-out.

> Leave it unsigned. I will decide later. Still no campaign.

---

## If you sign park

| Action | Who | When |
|---|---|---|
| Treat this file as the signed G0 | whoever appends "SIGNED" + date | after your paste |
| Vault D-155: outcome = park | Cursor or Claude | same sitting |
| `MSPL-04` | no edit | stays `blocked` |
| Design 118 | already discharged (#1056) | no reopen |
| Totoro / DRAC B1 | none | no relaunch |
| Live Cursor lane | SE-series pins / planned doors | continue |
| Codex Lane B | still PROTECTED | classify-only |

No NEWS. No public `confint()`. No second campaign.

---

## Signature (SIGNED)

**Decision id:** brain `D-157` (2026-08-17). Numbering note: vault D-155/D-156 were already claimed the same morning (roster symlink / one-day grace); the B1 park paste is D-157.

**Paste:**

> Park. No second campaign. MSPL-04 stays blocked. No Totoro relaunch. If we want intervals later, that is a new construction and a new pre-registration, not a Design 118 recalibration and not n to 2000.

**Effect:** B1 PARKED. No second campaign. `MSPL-04` stays `blocked`. No Totoro relaunch. No public `confint()` / `vcov()` / `se=TRUE`. Later intervals = new construction + new pre-registration — not Design 118 recalibration and not \(n\to 2000\).
