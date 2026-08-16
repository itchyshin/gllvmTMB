# B1 hold-out gate — G1–G5 FAIL

**Date:** 2026-08-16T18:38Z
**Roles:** Fisher / Rose
**Frozen map:** M0 (`docs/dev-log/research/2026-08-16-mspl-b1-calibrator-map-freeze.md`,
PR #1040). \(\alpha^*=0.05\).
**Read:** one official `consolidate-b1.R --expect-full --holdout` on Totoro
after that freeze was committed and PRed. Log:
`totoro:~/gllvmtmb-local-artifacts/b1-full-20260816/HARVEST/holdout-20260816T1836Z.txt`
(27.1 s wall, exit 0).

This is the Design 118 §5.6 / §5.7 rule-1 read. It is **not** a public
interval admit and does **not** edit MSPL-04.

---

## Verdict

| Gate | Rule | Result | Number |
|---|---|---|---|
| **G1** | ≥90% of hold-out (cell, target) rows PASS (Wilson 90% \(\subset[0.92,0.98]\)) | **FAIL** | **14/132 = 10.6%** PASS (93 FAIL, 25 INDETERMINATE) |
| **G2** | no hold-out coverage < 0.90 | **FAIL** | min coverage **0.0218** (B106 H1 probit \(\pi=0.97\) \(q=2\) median) |
| **G3** | availability ≥0.95 per hold-out row among non-refused fits | **FAIL** | 10/132 rows below 0.95; min **0.200** (B126 H3 cloglog \(\pi=0.20\) min) |
| **G4** | refusal ≤0.10 on well-identified anchors (\(\pi=0.50\), largest \(n_{\mathrm{site}}\)) | **PASS** | B101/B105/B127/B128 refusal **0.000–0.043** |
| **G5** | every fitted \(\gamma_k\) has its registered sign | **PASS** | M0 carries no \(\gamma\) (vacuous) |

**Conjunction G1–G5: FAIL.** Design 118 §5.6: the construction is not
promoted; Design 88's point-only fence stands; this is a negative
result, not a NEWS-covered interval.

DEV-10 (H3 cloglog \(n_{\mathrm{site}}=192\): B124, B126, B128, B130,
B132; 15 rows) does not save the gate: excluding them leaves
**13/117 = 11.1%** PASS, min coverage still **0.0218**, and G3 still
FAIL (5 remaining rows, min 0.784 on B121).

---

## Escalation (not run)

§2.5 one-shot \(n\to 2000\) named by the consolidator for INDETERMINATE
hold-out cells: B090, B091, B097, B098, B101, B102, B105, B107, B108,
B109, B115, B116, B117, B118, B125, B128, B130. **Not launched.** G1
is already 10.6%; escalation cannot reach 90% PASS.

---

## What this is not

- Not permission to refit the map on hold-out.
- Not a second Totoro/DRAC campaign.
- Not public `se=TRUE` / `vcov()` / `confint()`.
- Not MSPL-04 `covered`.

A pre-freeze `--holdout` headline already existed in
`~/b1-consolidate.log` at 2026-08-16T17:19Z (same 10.6% / G2 FAIL).
That read was before the written freeze. The **official** post-freeze
read is the 18:37Z job above; the numbers match.
