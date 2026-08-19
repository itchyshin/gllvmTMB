# Totoro T1 grid proposal — Design 125 fork B (measurement, not a freeze)

- **Date:** 2026-08-18
- **Lane:** `cursor/mspl-fork-B-totoro-20260818` @
  `~/local-scratch/lanes/gllvmTMB-mspl-fork-B-totoro`
- **Status:** **LOCKED** (sibling, 2026-08-18). Declares the hold-out grid
  so T\* can be *measured*. Does **not** freeze T\*. Does **not** launch
  Totoro from the kit sitting. Does **not** open public `se` / `vcov` /
  `confint`. Absorbed into
  `docs/dev-log/lanes/cursor-mspl-fork-B-totoro/LOOP/`.
- **calibrated:** FALSE
- **public_confint:** refused
- **coverage_claim:** none
- **MSPL-04:** stays `blocked`
- **#1077:** stays draft

## Why this is a proposal, not a freeze

Design 125 (`docs/design/125-mspl-profile-led-intervals.md`) is an approved
programme stub. It does **not** name Totoro cells, \(n_{\mathrm{rep}}\), or a
T\* PASS/FAIL band. It explicitly does not authorise Totoro.

ADEMP (`docs/dev-log/research/2026-08-17-mspl-profile-led-prereg-ademp.md`)
G4d froze **L\* only**. Remaining G0 item 2 is still open: *freeze T\* numeric
thresholds + Totoro \(n_{\mathrm{rep}}\) before any campaign.* §P5 T1 says
hold-out cells must be declared in advance and Wilson / PASS-FAIL thresholds
**must be filled before launch** — they are **not** filled by the ADEMP sign.
§D Totoro DGP: expanded prevalence × \(n\) hold-out; independent seeds; not
Design 118 H1∪H2∪H3. T\* stays open until a Totoro G0.

Official L2 (`docs/dev-log/research/2026-08-18-mspl-forkB-l2-smoke.md`,
[#1162](https://github.com/itchyshin/gllvmTMB/pull/1162)) is a **recording**
gate. It says in so many words that it does not freeze a T\* band. Closed L2
LOOP (`docs/dev-log/lanes/cursor-mspl-fork-B-L2/`) is GOAL_MET; cite, do not
edit.

The sibling Totoro `LOOP/GOAL.md` already sketches \(n_{\mathrm{rep}}=200\),
seeds `20260830`/`20260831`/`20260832`, and “T\* applied as frozen.” That
GOAL language is **ahead of ADEMP**. This file keeps those three seed bases
and the 200-rep size as the **measurement** rung, and **refuses** to treat
the L1 Wilson-not-entirely-below-0.80 rule as a signed T\* freeze.

## Inherited numbers (do not rewrite)

| Source | Cell | seed_base | n_rep | cov_eff | Wilson 95% (eff) |
|---|---|---|---|---|---|
| Official L1 #1128 | `L1-anchor-n80-T8` | `20260818` | 50 | 0.880 | [0.7620, 0.9438] |
| Official L2 Seed B | `L1-anchor-n80-T8` | `20260819` | 50 | 0.900 | [0.7864, 0.9565] |
| Official L2 Seed C | `L1-anchor-n80-T8` | `20260820` | 50 | 0.900 | [0.7864, 0.9565] |
| Official L2 near-tail | `L1-neartail-n40-T4` | `20260821` | 50 | 0.780 | [0.6476, 0.8725] |

Do **not** re-walk seeds `20260818`–`20260821` as T1 history. Do **not** mix
the companion 0.935 / 400-row walk. E2 stays out (`b_fix` probe). Family
stays Bernoulli **logit**. Structure stays `latent(d = 1, unique = FALSE)`.
Fork stays **B** (`tape = Q_0`).

## Declared T1 hold-out grid (recommended)

Four new cells. One independent seed each. \(n_{\mathrm{rep}}=200\).
None of these cells was an L1/L2 coverage cell.

| cell_id | n_site | n_trait | prevalence | first-trait \(\beta_0\) | role | seed_base | n_rep | T\* rule |
|---|---:|---:|---|---:|---|---:|---:|---|
| `T1-anchor-n40-T8` | 40 | 8 | `anchor` | 0.0 | unused \((n,T)\) in the G4d local rectangle | 20260830 | 200 | **RECORD** (candidate rules below; no FAIL band) |
| `T1-anchor-n160-T8` | 160 | 8 | `anchor` | 0.0 | first \(n\)-expansion after local L1 PASS | 20260831 | 200 | **RECORD** |
| `T1-neartail-n80-T8` | 80 | 8 | `near_tail` | −1.6 | prevalence × \(n\) (L2 near-tail was \(n=40,T=4\)) | 20260832 | 200 | **RECORD** |
| `T1-fartail-n40-T4` | 40 | 4 | `far_tail` **(new)** | −2.4 | far-tail prevalence hold-out | 20260833 | 200 | **RECORD-ONLY** |

**Fits:** \(4\times 200=800\). Estimand **E1** only. Method = fork-B profile
(unpenalized Laplace at fixed MSPL nuisance). Wald(\(Q_0\)) / bootstrap are
**not** on this rung.

**DGP reuse.** Anchor and near-tail intercepts stay the L1 harness vectors
(`dev/mspl-forkB-l1-ademp.R`):
`anchor = (0, 0.25, −0.25, 0.1)`,
`near_tail = (−1.6, −1.4, −1.8, −1.5)`,
`Lambda = (0.9, −0.6, 0.45, 0.7)`.
`far_tail` is **declared here** as
`(−2.4, −2.2, −2.6, −2.3)` so \(\mathrm{logit}^{-1}(−2.4)\approx 0.083\).
The T1 runner must extend `mspl_forkB_l1_dgp()` with that third prevalence;
do not silently reuse `near_tail`. Saturation (`R-SAT`) is expected to rise;
refusals price into \(\widehat{\mathrm{cov}}_{\mathrm{eff}}\) as 0.

**Why these four, not a re-walk of `L1-anchor-n80-T8`.** ADEMP T1 is a
**hold-out** declaration. Re-walking the L1/L2 interior cell at a new seed
is a confirm, not a hold-out. Optional confirm (not in the primary 800):

| cell_id | n_site | n_trait | prevalence | seed_base | n_rep | role |
|---|---:|---:|---|---:|---:|---|
| `T1-confirm-n80-T8` | 80 | 8 | `anchor` | 20260834 | 200 | same DGP as L1, new seed, \(n_{\mathrm{rep}}\) scale only |

Do **not** start the confirm until the four hold-outs have inspected 1-rep
objects on Totoro.

**Why not 3 seeds × every cell.** L2 already showed interior multi-seed
(0.880 / 0.900 / 0.900) at \(n_{\mathrm{rep}}=50\). T1’s job is new
\((n,T,\pi)\) cells at a size that can *inform* T\*. A 3-seed walk on
`T1-anchor-n160-T8` only (seeds `20260831` / `20260835` / `20260836`) is a
cheap follow-on (+400 fits) if the first 200-rep object is clean. It is
**not** in the primary panel.

**Seeds `20260830` / `20260831` / `20260832`** match the sibling GOAL for
the first three cells. `20260833` is the far-tail seed the GOAL named
without numbering.

## What to record (so T\* can be chosen later)

Every cell reports the ADEMP dual pair + Wilson + MCSE + refusal-by-reason.
Do **not** brand `calibrated` or `covered`. Do **not** apply a FAIL band.

Record, as **candidates**, whether each interior/anchor cell would have
passed these *unfrozen* rules at \(n_{\mathrm{rep}}=200\):

| ID | Candidate rule | Why it is only a candidate |
|---|---|---|
| C-L1 | cov_eff Wilson upper \(\ge 0.80\) (the signed **L1** rule) | At \(n=200\) this still PASSes around \(p\approx 0.75\). Copying it as T\* is too weak. |
| C-lo80 | cov_eff Wilson lower \(\ge 0.80\) | The measurement T1 is for: L1’s 0.880 at \(n=50\) had lower 0.762; the same point at \(n=200\) has lower \(\approx 0.828\). |
| C-avail | availability \(\ge 0.95\) on non–R-SAT rows | Already named as **T2** in ADEMP §P5 — do not steal T2’s gate. |
| C-ref | refusal \(\le 0.10\) on anchors (ADEMP P3 usability floor) | Named for anchors; far-tail is RECORD-ONLY because L2 near-tail 0.780 would fail a copied 0.80 band. |

Far-tail (`T1-fartail-n40-T4`) and the near-tail hold-out are
**RECORD-ONLY** for every candidate above. A copied 0.80 FAIL band would
silently fail the already-recorded L2 near-tail 0.780.

Wilson 95% / MCSE at \(n=200\) (planning arithmetic only):

| If cov_eff holds at | Wilson 95% | MCSE |
|---|---|---|
| 0.90 | ≈ [0.851, 0.934] | 0.021 |
| 0.88 | ≈ [0.828, 0.918] | 0.023 |
| 0.78 | ≈ [0.718, 0.832] | 0.029 |

## Cores

**16 workers**, `OMP_NUM_THREADS=1`, `OPENBLAS_NUM_THREADS=1`. Host
`totoro.biology.ualberta.ca`. Lane GOAL cap is 16 on a shared box. D-143
allows \(\le 150\); this job does not need it. Do not take 100 cores for
800 fits.

DRAC is fallback only if Totoro BatchMode SSH is dead. Not GitHub Actions
(D-50).

## Wall estimate

Two local clocks exist and they disagree. Use both.

| Clock | Source | Seconds / rep | Cell |
|---|---|---|---|
| Conservative | Official L1, 88.2 s / 50 (`pkgload`) | 1.76 | `L1-anchor-n80-T8` |
| Optimistic | Official L2, 30.6 s / 150 (`R CMD INSTALL`) | 0.20 | mix of n80-T8 and n40-T4 |

Scale from the n80-T8 clock (Laplace + profile roughly tracks \(n\)):

| Cell | Optimistic s/rep | Conservative s/rep | 200-rep serial (opt / cons) |
|---|---:|---:|---|
| `T1-anchor-n40-T8` | 0.12 | 1.06 | 0.4 min / 3.5 min |
| `T1-anchor-n160-T8` | 0.44 | 3.87 | 1.5 min / 12.9 min |
| `T1-neartail-n80-T8` | 0.20 | 1.76 | 0.7 min / 5.9 min |
| `T1-fartail-n40-T4` | 0.08 | 0.70 | 0.3 min / 2.3 min |
| **Primary 800** | — | — | **~3 min / ~25 min serial** |

At **16 cores**, the 200-rep panel itself is **~1–3 min** optimistic,
**~2–5 min** conservative, plus I/O.

**Sitting wall (honest):**

| Step | Wall |
|---|---|
| Local 1-rep × 4 cells | ~10–30 s after a compiled DLL |
| Totoro BatchMode + deploy + `R CMD INSTALL` | **5–15 min** (dominates) |
| Totoro 1-rep × 4, inspect objects | ~30 s |
| Totoro 200-rep panel, 16 cores | **2–5 min** (conservative serial 25 min if workers fail) |
| **Smoke-to-receipt** | **~20–40 min** including first deploy |

Abort the moment the first new cell is empty, `blocked-on-L0`, or returns
an untyped row. Cold TMB compile is **outside** the fit timer.

Optional confirm +400 (`T1-confirm-n80-T8`) or +400 (3-seed on n160) adds
about **1–4 min** at 16 cores. Still well under a D-139 30-minute
compute-ask once deploy is done.

## Smoke-first order (binding)

1. Extend the harness with `far_tail` and the four `T1-*` cell ids. Do not
   edit official L1/L2 receipts.
2. Local 1-rep on each of the four cells. Inspect the returned object:
   two-sided `Q_0` / fork B with `lo < hi`, **or** a typed ADEMP refusal
   (`R-SAT` / `R-NAVL`). A missing DLL (`R-FIT`) is not a typed refusal —
   reinstall and re-smoke (L2 already hit this).
3. Totoro BatchMode SSH, deploy this branch fast-forwarded onto
   `origin/main`, `R CMD INSTALL`, 1-rep × 4, inspect again.
4. Then the 800-rep panel. Write the T1 receipt with
   `calibrated: FALSE`, `public_confint: refused`, `coverage_claim: none`,
   `tstar_status: NOT-FROZEN`.

## Hard OUT

- Public `se = TRUE`, `vcov()`, `confint()` — `.gllvmTMB_mspl_assert_inference` stays.
- Undraft [#1077](https://github.com/itchyshin/gllvmTMB/pull/1077).
- Flip MSPL-04 off `blocked`; NEWS / README / article `covered`.
- Brand this grid `calibrated` or apply a T\* FAIL band.
- Reopen Design 118 / B1 / H1∪H2∪H3; \(n\to 2000\) “fix”.
- Re-walk L1/L2 seeds `20260818`–`20260821`.
- Edit closed L2 kit, closed g0_unlock kit, or repo-root `LOOP/`.
- Probit / cloglog / E2 / `d\ge 2` / any family beyond binomial logit.
- `git add -A`; `dev/isdm-package-recovery/**`.

## What this file does not do

It does not launch Totoro from the kit sitting. It does not sign T\*.
It is now the locked WHAT absorbed into
`docs/dev-log/lanes/cursor-mspl-fork-B-totoro/LOOP/`. Totoro compute is
G0-allowed for `/goal`. Next human gate after the 800-row receipt: a
**separate** T\* freeze (default not-ready).
