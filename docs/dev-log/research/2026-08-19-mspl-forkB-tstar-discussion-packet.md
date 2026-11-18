# T\* discussion packet — Design 125 fork B (after T1; **not frozen**)

- **Date:** 2026-08-19
- **Lane:** `cursor/mspl-tstar-drac-next-20260819`
- **Purpose:** Give Shinichi a **decision menu** for T\* numeric thresholds.
  This file **does not freeze T\***. No compute is launched from this sitting.
- **Upstream receipt:**
  `docs/dev-log/research/2026-08-18-mspl-forkB-t1-receipt.md` ([#1173](https://github.com/itchyshin/gllvmTMB/pull/1173))
- **calibrated:** FALSE
- **public_confint:** refused
- **coverage_claim:** none
- **tstar_status:** **NOT-FROZEN**

## Executive summary

T1 on Totoro (**800 fits**, four new hold-out cells) is **RECORDED**.
Anchors look strong (cov_eff **0.940** / **0.975** at \(n=200\)). Near-tail
and far-tail are **weak** (0.710 / 0.580 effective coverage) with expected
refusals — far-tail was always **RECORD-ONLY**.

**Recommendation (Ada / Fisher, not a freeze):** do **not** copy L1's
**C-L1** rule (Wilson upper \(\ge 0.80\)) as T\*. It is too weak at
\(n=200\) and would have **passed** L2 near-tail **0.780**, which we already
know is fragile. If you want a numeric T\* at all, the only interior rule
with teeth is **C-lo80** (Wilson **lower** \(\ge 0.80\)) on **anchor cells
only**, with near-tail and far-tail permanently **RECORD-ONLY**. Even then,
T\* freeze is a **separate G0** — this packet is input, not a signature.

Until T\* is explicitly signed: **no FAIL band**, **no MSPL-04 promotion**,
**no undraft #1077**, **no public `se` / `vcov` / `confint`**.

## Evidence stack (do not rewrite)

| Gate | Cell | seed | n_rep | avail | refusal | cov_eff | Wilson 95% (eff) | Role |
|---|---|---:|---:|---:|---:|---:|---|---|
| L1 #1128 | `L1-anchor-n80-T8` | 20260818 | 50 | 1.000 | 0.000 | **0.880** | [0.7620, 0.9438] | local anchor |
| L2 #1162 Seed B | `L1-anchor-n80-T8` | 20260819 | 50 | 1.000 | 0.000 | **0.900** | [0.7864, 0.9565] | multi-seed interior |
| L2 #1162 Seed C | `L1-anchor-n80-T8` | 20260820 | 50 | 1.000 | 0.000 | **0.900** | [0.7864, 0.9565] | multi-seed interior |
| L2 #1162 near-tail | `L1-neartail-n40-T4` | 20260821 | 50 | 1.000 | 0.000 | **0.780** | [0.6476, 0.8725] | tail stress |
| T1 hold-out | `T1-anchor-n40-T8` | 20260830 | 200 | 1.000 | 0.000 | **0.940** | [0.8981, 0.9653] | new \((n,T)\) |
| T1 hold-out | `T1-anchor-n160-T8` | 20260831 | 200 | 1.000 | 0.000 | **0.975** | [0.9428, 0.9893] | \(n\) expansion |
| T1 hold-out | `T1-neartail-n80-T8` | 20260832 | 200 | 0.995 | 0.005 | **0.710** | [0.6436, 0.7685] | prev × \(n\) |
| T1 hold-out | `T1-fartail-n40-T4` | 20260833 | 200 | 0.930 | 0.070 | **0.580** | [0.5107, 0.6463] | far-tail (RECORD-ONLY) |

Companion L1 walk **0.935** / 400-row harness is **out of band** — do not
mix with the official column above.

## Candidate rules scored on T1 (unfrozen)

Declared in
`docs/dev-log/research/2026-08-18-mspl-forkB-totoro-grid-proposal.md`.
Scored on the T1 receipt; **not applied as gates**.

| Rule | Definition | `n40-T8` | `n160-T8` | `neartail-n80-T8` | `fartail-n40-T4` |
|---|---|---|---|---|---|
| **C-L1** | Wilson upper \(\ge 0.80\) | yes | yes | **no** | **no** |
| **C-lo80** | Wilson lower \(\ge 0.80\) | yes | yes | **no** | **no** |
| **C-avail** | availability \(\ge 0.95\) | yes | yes | yes | **no** (0.930) |
| **C-ref** | refusal \(\le 0.10\) | yes | yes | yes | yes |

**Reading:**

- **C-L1** fails near-tail and far-tail but would still PASS a point estimate
  around **\(p=0.75\)** at \(n=200\) — too weak to be T\*.
- **C-lo80** is the first rule that **fails** near-tail (lower **0.644**)
  while **passing** both anchors — that is why T1 was sized at \(n=200\).
- **C-avail** is ADEMP **T2** territory — do not steal it for T\*.
- Far-tail fails everything except C-ref; it stays **RECORD-ONLY** forever
  unless a new G0 widens the programme.

L2 near-tail **0.780** already shows why a blind **0.80 point** FAIL band
is wrong: Wilson lower was **0.648** at \(n=50\); copying C-L1 would not
have caught it.

## Three options for Shinichi (pick one at G0)

### Option A — **Refuse T\* for now** (default recommendation)

Keep **`tstar_status: NOT-FROZEN`**. Treat T1 as **measurement only**.
Next work = DRAC multi-seed confirm panel
(`docs/dev-log/lanes/cursor-mspl-fork-B-drac-confirm/LOOP/`) before any
numeric freeze. **No public interval doors.**

*When this is right:* you want more seeds on the \(n=160\) anchor and the
optional L1 confirm cell before committing thresholds.

### Option B — **Freeze C-lo80 on anchor cells only**

Sign T\* =: on cells tagged **`anchor`**, require cov_eff Wilson **lower**
\(\ge 0.80\) at declared \(n_{\mathrm{rep}}\). Near-tail and far-tail cells
are **excluded** from PASS/FAIL (RECORD-ONLY forever on this programme
stub). Availability floor stays a separate **T2** gate.

*T1 anchors would PASS today.* Near-tail would **FAIL** (by design — tail
cells are not anchors).

*Risk:* one hold-out draw at \(n=200\); multi-seed confirm on DRAC is still
wise before treating this as load-bearing.

### Option C — **Explicit non-freeze with written refusal**

Record in `docs/dev-log/decisions.md` that T\* numeric thresholds are
**deferred** until E2 or a second family arm exists. Keep reporting
dual coverage + Wilson on every rung. MSPL-04 stays **`blocked`**.

*When this is right:* you believe tail pathology is structural and no single
number on anchors certifies the whole MSPL interval programme.

## What T\* freeze would **not** unlock

Even under Option B:

- Public `se = TRUE`, `vcov()`, `confint()` — still **separate G0** (D-149 /
  D-159)
- Undraft [#1077](https://github.com/itchyshin/gllvmTMB/pull/1077) — still
  **explicit ask**
- Register **MSPL-04** off `blocked` — still needs evidence path + ask
- NEWS / README / article **`covered`** — still fenced
- E2 (loadings) coverage — still **NOT-EVALUABLE** on current probe

## Suggested next step (item 3 — DRAC fleet)

If Option A or B: launch the **DRAC confirm kit** (not this file) — locked
**~800-fit** follow-on:

- `T1-confirm-n80-T8` / seed `20260834` / \(n=200\) — same DGP as L1, new
  seed, scale check
- `T1-anchor-n160-T8` × **3 seeds** × \(n=200\) — cheap multi-seed on the
  strongest T1 cell (+600 fits)

Fir / Nibi / Rorqual job arrays; Totoro smoke only. See
`docs/dev-log/lanes/cursor-mspl-fork-B-drac-confirm/LOOP/GOAL.md`.

## Sign-off block (for maintainer)

| Field | Value |
|---|---|
| **tstar_status** | NOT-FROZEN (until you sign below) |
| **Chosen option** | _A / B / C — fill at G0_ |
| **Signed** | _date / initials_ |
| **Notes** | _optional_ |
