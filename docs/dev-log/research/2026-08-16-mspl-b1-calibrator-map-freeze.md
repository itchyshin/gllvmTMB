# B1 calibrator map — FROZEN

**Status:** **FROZEN** 2026-08-16T18:36Z (UTC).
**G0:** Shinichi *"go ahead"* (2026-08-16) — freeze the map from the
calibration split and proceed to one official hold-out read.
**Roles:** Fisher / Rose.
**Lane:** Design 118 Phase B1 → written freeze (this file) → B2 hold-out.
**Hold-out at freeze time:** **sealed.** This file was written from
train-only evidence only. H1 ∪ H2 ∪ H3 were not summarised.

This is the Design 118 §5.2 written freeze. It is **not** a G1–G5
verdict, not a public `confint()` admit, and not an MSPL-04 register
edit. Machine-readable twin:
`docs/dev-log/research/2026-08-16-mspl-b1-calibrator-map.json`
and the harness object
`docs/dev-log/research/2026-08-16-mspl-b1-calibrator-fit.rds`
(`evaluate-holdout.R --fit` that path).

---

## Frozen map

| Field | Frozen value |
|---|---|
| Construction | Level-calibrated penalised profile (Design 118 §3.1). Fallback: percentile bootstrap on non-saturated coordinates only, reduced 1-in-3 budget (D2). |
| Selected rung | **M0** — \(h(v)=0\), so \(\alpha^*(v)=\alpha=0.05\) |
| \(\gamma\) | none (empty) |
| Clip | \(\alpha^*\in[0.01,0.40]\); landing on a clip = refusal (fence line 4) |
| Fence | F-AMD (DEV-3): screen / saturation **or** attractor-proximity **or** root-NA. The \(s_j\) probe is reported, not used for refusal. |
| Mode | `profile_only` (no separate \(h_{\mathrm{boot}}\) fitted) |
| G5 signs | vacuously **PASS** — M0 carries no \(\gamma_k\) |
| Weights | \(w_c=1\) per (cell, target) unit (INT-W1) |
| CV | leave-whole-cells-out \(K=8\), folds by `cell_id` sorted (INT-F1) — **not executed** on sidecars for this freeze |

**Formula.** \(\operatorname{logit}\alpha^*(v)=\operatorname{logit}\alpha+h(v)\)
with \(h\equiv 0\). Re-thresholding a stored profile at \(\alpha^*=0.05\)
is the nominal construction already stored on the shards.

---

## Selection rule (binding, Design 118 §2.4)

Copied here so the freeze names the rule it applied, not a later rewrite:

1. Fit to **coverage**: minimise \(\sum_c w_c(\widehat{\mathrm{cov}}_c(\gamma)-0.95)^2\)
   by re-evaluating stored per-replicate intervals at \(\alpha^*(v;\gamma)\) —
   no refitting.
2. Leave-whole-cells-out \(K=8\) CV within the **calibration split only**.
3. **Admission:** M\(_{k+1}\) admitted only if out-of-fold
   \(\max_c|\widehat{\mathrm{cov}}_c-0.95|\) drops by \(\ge 0.005\)
   **and** mean absolute error does not rise. Ties to the simpler model.
   **Stop at the first non-admission.**
4. Registered signs (M2–M4): \(\gamma_1,\gamma_2,\gamma_3\ge 0\). A
   wrong-signed new term is a non-admission (G5).
5. Clip \([0.01,0.40]\) = refusal, not a clipped interval.
6. **If M0 passes, ship nothing.**

**How this freeze applied that rule.** The official
`inst/sim/b2-calibrator/fit-calibrator.R` ladder was **not** run on the
Totoro sidecars before this writing (the train-only
`calibrator-input.csv` exists; the sidecar walk was not started). The
freeze therefore stops at **M0**, the registered simpler model, because:

- Train-only nominal coverage at \(\alpha=0.05\) is **63 PASS / 163 FAIL /
  38 INDETERMINATE** of 264 (cell, target) rows. M0 does **not** pass
  the §2.5 band, so this is a **gate-evaluation freeze of the identity
  map**, not a "ship nothing / M0 passed" claim.
- Phase A's M1 anchor (\(\gamma_0\approx+1.13\Rightarrow\alpha^*\approx0.14\))
  is **refused as the freeze**. Raising \(\alpha^*\) narrows intervals.
  On the train split, OVER (coverage \(>0.98\), \(n_{\mathrm{avail}}\ge30\))
  and UNDER (coverage \(<0.90\), \(n_{\mathrm{avail}}\ge30\), refusal
  \(<0.90\)) are almost equal (**64 vs 60** rows). UNDER concentrates at
  \(n_{\mathrm{site}}\in\{48,96\}\) × \(\pi\in\{0.03,0.97\}\); OVER
  concentrates at smaller \(n_{\mathrm{site}}\). A constant lift would
  help the small-\(n\) overcoverage pocket and **worsen** the large-\(n\)
  undercoverage pocket.
- M2 (\(h=\gamma_0+\gamma_1 c_n\), \(\gamma_1\ge0\)) is the
  mechanistically aligned next rung (soft-scaling: larger \(c_n\) at
  small \(n\)). It is **recorded as AGENT-INFERRED, not frozen.**
  Freezing M2 without the sidecar CV would invent \(\gamma\).

Deviation from a fully executed §2.4 ladder is named: **DEV-FREEZE-1**
(this file). A later sitting may replace this freeze only under Design
118 §5.7 rule 2 (written deviation; used hold-out then retired).

---

## Train-only evidence used (not the gate)

Source: Totoro
`/home/snakagaw/gllvmtmb-local-artifacts/b1-full-20260816/`
via `consolidate-b1.R --expect-full` **without** `--holdout`
(local scrap `/tmp/mspl-b1-consolidate-expect-full.txt`; harvest
`docs/dev-log/research/2026-08-16-mspl-b1-complete.md`). Joined to
`b1_grid()` from `claude/mspl-b0-prereqs`.

| Class (AGENT-INFERRED labels) | (cell, target) rows |
|---|---:|
| PASS (Wilson 90% \(\subset[0.92,0.98]\)) | 63 |
| OVER (coverage \(>0.98\), \(n_{\mathrm{avail}}\ge30\), not fence) | 64 |
| UNDER (coverage \(<0.90\), \(n_{\mathrm{avail}}\ge30\), refusal \(<0.90\)) | 60 |
| INDETERMINATE | 38 |
| FAIL_other (point in \([0.90,0.92)\)) | 13 |
| REFUSE_fence (refusal \(\ge0.90\)) | 26 |
| **Total train** | **264** |

\(\pi=0.50\) is already near-nominal (49 PASS, 0 OVER, 1 UNDER among
those rows). Extreme \(\pi\) carry almost all refuse / under / over.

Short cell (not 600 reps): **B048** C-q2 cloglog \(\pi=0.03\)
\(n_{\mathrm{site}}=96\) \(q=2\) has **372** rows. Also 598–599 on
B056, B057, B076, B088.

---

## Cells that refuse

Fence, not calibrator. Refusal rate \(\ge0.90\) on at least one
calibration target (F-AMD + screen). These cells are **declined**, not
mapped.

**All three targets refuse (\(\ge0.90\)):**

| cell | block | link | \(\pi\) | \(n_{\mathrm{site}}\) | \(q\) |
|---|---|---|---:|---:|---:|
| B001 | C-core | logit | 0.03 | 12 | 1 |
| B002 | C-core | cloglog | 0.03 | 12 | 1 |
| B009 | C-core | logit | 0.97 | 12 | 1 |
| B011 | C-core | logit | 0.03 | 24 | 1 |
| B019 | C-core | logit | 0.97 | 24 | 1 |
| B041 | C-q2 | logit | 0.03 | 24 | 2 |
| B045 | C-q2 | logit | 0.97 | 24 | 2 |

**At least one target refuses:** the seven above, plus **B010**
(cloglog \(\pi=0.97\), \(n=12\)), **B012** (cloglog \(\pi=0.03\),
\(n=24\)), **B042** (cloglog \(\pi=0.03\), \(n=24\), \(q=2\)).

Well-identified train anchors (\(\pi=0.50\), largest \(n\) in block)
stay usable: refusal \(0.00\)–\(0.06\) on B035/B036/B049/B050/B077/B080.

---

## What this freeze authorises, and what it does not

**Authorises:** one official hold-out read of H1 ∪ H2 ∪ H3 at this
frozen map (M0 = nominal \(\alpha=0.05\)), via
`consolidate-b1.R --holdout` and/or
`evaluate-holdout.R --fit docs/dev-log/research/2026-08-16-mspl-b1-calibrator-fit.rds`.
Hold-out is read **once** (Design 118 §5.7 rule 1).

**Does not authorise:** a second map fit on the same hold-out; public
`se=TRUE` / `vcov()` / `confint()`; MSPL-04 `covered`; NEWS "covered";
a second Totoro/DRAC campaign; treating the train 63/163/38 preview as
the campaign result.

---

## G0 record

Shinichi: *"go ahead"* (2026-08-16), treated as signature to freeze
from the calibration split and proceed. Draft answer that this freeze
implements: **freeze M0 (identity) + F-AMD fence in writing; do not
invent M1/M2 \(\gamma\); then one `--holdout` read.**
