# Design 122 confirmatory campaign — measured results

`campaign_id = design122-confirmatory-20260817-646005cf`, pinned commit
`646005cf`. Source: `docs/design/122-va-vs-laplace-recovery.md` (§§1-17).
Raw data: `dev/design122-campaign/results/chunk-001.csv` .. `chunk-024.csv`,
verified against `~/gllvm_work/campaigns/design122-confirmatory-20260817-646005cf/chunk-*.csv`
on Totoro — every chunk's md5 matches the Totoro source byte-for-byte
(no re-sync needed; the local copies already matched exactly).

**Scope of this document: measurement only. K1-K4 (Design 122 §6.2) are
NOT adjudicated here — that is a separate reviewer's task with fresh eyes.
This report states the numbers those criteria need and does not compute or
imply which arm "wins," whether any kill rule fires, or any verdict on
"VA wins" / "cheap remedy wins" / "mixed."** Every estimand below is
stratified by (truth strength × n) per Design 122 §F4; no marginal-over-truth
number stands in for a stratified one.

---

## 0. Data-integrity findings (read this section first)

### 0.1 The 28,261 vs 21,600 discrepancy — RESOLVED, two additive causes

**True row count: exactly 21,600 rows, parsed correctly (`read.csv()` in R,
which is quote-aware).** This equals the design exactly:
24 cells × 3 arms × 300 seeds = 21,600. Verified independently: 21,600 unique
`(cell_id, arm, seed)` combinations, **zero duplicates**, and every one of
the 24 cell_id × arm cross-tabulations has count 300 in the raw file (before
any data-quality exclusion — see §0.2).

The naive `grep -vc "^campaign_id"` count of 28,261 is fully explained by
**two additive effects**, not one:

| Component | Count | Mechanism |
|---|---:|---|
| True data rows | 21,600 | 24 cells × 3 arms × 300 seeds |
| Extra physical lines from embedded newlines in quoted `warning`/`error` fields | 6,637 | 573 rows have a literal `\n` inside the captured `warning` text, 170 rows inside `error`; each embedded newline makes one logical CSV row span 2+ physical lines. `wc -l`/`grep -c` count physical lines, not logical rows. |
| Header lines NOT excluded by the naive filter | 24 | The stated hypothesis was **embedded newlines** — confirmed as the dominant term — but the grep pattern `^campaign_id` (unquoted) never matches the actual header line, which starts `"campaign_id",...` (quoted). All 24 per-chunk headers pass the `-v` filter uninverted and get counted. |
| **Total naive count** | **21,600 + 6,637 + 24 = 28,261** | Matches the reported figure exactly. |

**Verdict: the stated hypothesis is confirmed as the dominant mechanism
(99.6% of the gap) but is incomplete on its own** — the remaining 24 lines
come from the header-quoting mismatch, not mentioned in the original
hypothesis. Once both effects are counted, the reconciliation is exact to
the line. **This is a counting artefact of the naive grep, not a data-
integrity problem** — no genuinely duplicate or extra rows exist.

### 0.2 A second, distinct finding: a one-time compiler race cost 120 VGH rows at one cell

Not part of the row-count question above (those 120 rows count correctly
toward 21,600) but a real data-quality issue in the VGH arm, confined to a
single cell, and it leads every VGH number below.

**What happened**, from the campaign operator's own contemporaneous log
(`dev/design122-campaign/driver-remaining-chunks.sh` header comment) and the
raw compile transcript (`dev/design122-campaign/rung-verify-chunk023.log`,
which shows dozens of concurrent `g++ ... -c gllvmTMB_va_r3.cpp` and
`-shared ... -o gllvmTMB_va_r3.so` invocations against the same target path):
chunk 023 (`ordinal_probit, n=400, p=27, T-mid`, cell 23) was the **first
use** of the shared `GLLVMTMB_VA_R3_BUILD_ROOT` directory. Ninety-six Totoro
workers found that directory empty simultaneously, all began compiling the
VA-R3 TMB template into it concurrently, and the resulting shared `.so` was
corrupted for part of that run. 120 of that cell's 300 VGH rows carry
`status = "error"` with messages `"getParameterOrder" not available for
.Call()` (116 rows) or `unable to load shared object` (4 rows) — a broken
toolchain artefact, not an estimator outcome. **Confirmed identification
rule** (reproducible): `arm == "VGH" & status == "error" &
grepl("getParameterOrder|unable to load shared object", error)` — exactly
120 rows, all in `cell_id == 23`, all with `wall_time_s` under 51.1s (median
0.44s, sum 873s ≈ 0.24 core-hours) — i.e. they failed near-instantly, never
running an actual VA fit. The remaining 180 VGH rows in that cell, and every
VGH row in every other cell (run after the race settled — verified directly
by the operator: `dyn.load()` succeeds and `getParameterOrder` is
registered), are unaffected. **Chunk 001, run immediately after, came back
clean, confirming the shared `.so` was stable from that point on**, and no
further rebuild was triggered for the remaining 21 chunks. Per
`dev/campaign-admission/RESULT-SCHEMA.md`'s no-automatic-retry policy, the
affected chunk was **not** re-run; the 120 rows are recorded as error-as-rows
rather than silently dropped.

**Treatment applied throughout the rest of this report:**

1. **These 120 rows are excluded from every estimator comparison below**
   (convergence, degeneracy denominators, `max|Lambda|`, TEST A, wall/core-hour
   totals) — an infrastructure race is not a VGH convergence failure or a VGH
   degeneracy outcome, and counting it as one would misattribute a compiler
   defect to the estimator this campaign exists to evaluate.
2. They are reported here, separately and prominently, rather than folded
   silently into any denominator.
3. **Consequence for cell 23 specifically: its VGH arm has n = 180, not 300.**
   Its rate MCSE is inflated by a factor of `sqrt(300/180) ≈ 1.29` relative to
   every other cell's VGH arm, and it drops out of the all-arm intersection
   denominator's 300-seed baseline for that cell (§4.1). Any claim resting on
   cell 23's VGH numbers specifically must carry this caveat. **A clean re-run
   of chunk 023 under a fresh campaign id is the remedy if that cell's VGH
   arm turns out to be load-bearing for a downstream conclusion; it has not
   been re-run here.**

**Distinguished from a second, legitimate VGH outcome that stays in every
denominator below:** 50 further rows (across 14 other cells — 1, 2, 4, 6, 7,
8, 10, 13, 14, 15, 16, 17, 19, 20) carry `status == "error"` with message
`"The variational fit did not pass its own health gate"`
(`failed_health_gate`, 46 rows, or `failed_variance_domain`, 4 rows). These
are genuine VA-engine self-rejections — the estimator declined the fit — and
are the Design 122 §F2 "guard-rejected" outcome. They are **kept in** the raw
and guard-inclusive denominators throughout, marked `degenerate = TRUE` by
construction (§3), exactly as pre-registered. **The two failure classes are
never conflated in this report**: 120 rows = toolchain broke (excluded); 50
rows = the estimator declined the fit (retained as data).

After excluding the 120 infra rows, the **analysis set is 21,480 rows**, used
throughout §§1-6 below.

---

## 1. Completion

24/24 cells present, all 3 arms, matching the confirmatory grid
(2 families × 2 n × 2 p × 3 truths; `n = 1600` is out of scope per the
§15 pre-run disposition — confirmatory `n ∈ {100, 400}` only, `n = 1600`
exploratory-budgeted and not part of this campaign; the binomial-logit VJJ
continuity block, §5.3, was also not run).

**Every cell/arm has exactly 300 rows except one:**

| cell_id | family | n | p | truth | L0 | L2 | VGH |
|---:|---|---:|---:|---|---:|---:|---:|
| 23 | ordinal_probit | 400 | 27 | T-mid | 300 | 300 | **180** (120 excluded, §0.2) |

All other 23 cells × 3 arms = 900/900 (69 cell-arm combinations) present at
full n = 300. No missing cell, no missing arm anywhere in the grid.

Full table: `dev/design122-campaign/tab-completion-by-cell-arm.csv`.

---

## 2. Convergence

### 2.1 Overall (infra-excluded, 21,480 rows)

| Arm | n attempted | n converged | rate |
|---|---:|---:|---:|
| L0 | 7,200 | 7,114 | 98.81% |
| L2 | 7,200 | 6,499 | 90.26% |
| VGH | 7,080 | 7,030 | 99.29% |

### 2.2 Cells below the design's 70% convergence bar (K2 trigger threshold)

Three cell × arm combinations, **all L2, all `binomial_probit, n = 100`,**
fall under 70%:

| cell_id | family | n | p | truth | arm | n | n_conv | rate |
|---:|---|---:|---:|---|---|---:|---:|---:|
| 1 | binomial_probit | 100 | 12 | T-weak | L2 | 300 | 186 | 62.00% |
| 2 | binomial_probit | 100 | 12 | T-mid | L2 | 300 | 208 | 69.33% |
| 4 | binomial_probit | 100 | 27 | T-weak | L2 | 300 | 161 | 53.67% |

No L0 or VGH cell falls below 70% anywhere in the grid. Full per-cell table:
`dev/design122-campaign/tab-convergence-by-cell-arm.csv`.

---

## 3. TEST A (per-fit optimum certificate, Design 122 §F1/§6.1)

### 3.1 Pass rates per arm (infra-excluded)

| Arm | n tested | n pass | rate | n NA |
|---|---:|---:|---:|---:|
| L0 | 7,200 | 6,984 | 97.00% | 0 |
| L2 | 7,200 | 7,200 | 100.00% | 0 |
| VGH | 7,030 | 7,030 | 100.00% | 50 (guard-rejected, no fit to test) |

Overall (all arms pooled, infra-excluded): 21,214 / 21,430 = 98.99%.

### 3.2 Reading the VGH 100% figure — the pre-registered partial mode, not the primary test

**Every one of the 7,030 usable VGH rows carries `testA_vgh_partial = TRUE`**
and `testA_note = "FIXED-VARIATIONAL fallback (m_i/S_i at fitted optimum, not
re-optimised per c)"`. Design 122 §F1 specifies the *primary* TEST A for VGH
as re-optimising the variational parameters (`m_i`, `S_i`) at every perturbed
scale `c`, and explicitly warns: *"Re-evaluating the ELBO at a rescaled
Lambda while holding the variational parameters fixed... would let VGH pass
TEST A trivially."* The full confirmatory campaign ran the fixed-variational
fallback throughout — which §7 pre-registers as an allowed partial mode, not
an ad hoc deviation, but the resulting 100% VGH pass rate is a measurement
of that weaker, fallback instrument, not of the primary re-optimized-per-c
certificate. Stated here as a measurement fact only.

### 3.3 L0's 216 TEST A failures — where they concentrate

All 216 L0 failures carry `testA_note = "unpenalised (ridge_tau=Inf)"` (the
unpenalised default arm) and cluster in small-n, weak/mid-signal, large-p
cells:

| cell_id | family | n | p | truth | n L0 TEST A fails |
|---:|---|---:|---:|---|---:|
| 4 | binomial_probit | 100 | 27 | T-weak | 79 |
| 5 | binomial_probit | 100 | 27 | T-mid | 49 |
| 16 | ordinal_probit | 100 | 27 | T-weak | 27 |
| 3 | binomial_probit | 100 | 12 | T-strong | 14 |
| 2 | binomial_probit | 100 | 12 | T-mid | 11 |
| 17 | ordinal_probit | 100 | 27 | T-mid | 10 |
| 1 | binomial_probit | 100 | 12 | T-weak | 9 |
| 13, 15 | ordinal_probit | 100 | 12 | T-weak / T-strong | 6, 6 |
| 14 | ordinal_probit | 100 | 12 | T-mid | 4 |
| 9 | binomial_probit | 400 | 12 | T-strong | 1 |

Every failure is at `n = 100` except one (cell 9, `n = 400`, 1 row); `p = 27`
cells carry the largest share.

### 3.4 `max_abs_gradient > 1e-3` (the declared `grad_tol`, §F1/K1)

| Arm | n | rate `> 1e-3` |
|---|---:|---:|
| L0 | 7,200 | 35.96% |
| L2 | 7,200 | **100.00%** (min observed value 0.0859, far above 1e-3) |
| VGH | 7,030 | 0.00% |

L2's uniform breach is consistent with — and likely explained by — the same
instrument mismatch Design 122 §15 already documents for TEST A itself: the
`aghq_ridge` penalty is applied at the R level (`R/fit-multi.R:5586-5592`),
not inside `tmb_obj$fn()`, so the gradient of the *raw* (unpenalized) TMB
objective evaluated at the *penalized* optimum need not be near zero. This
report states the measurement and its most likely mechanism; it does not
decide what this means for K1.

---

## 4. Degeneracy (two-sided detector, `rel_frob > 10 OR kappa < 1/3`, applied identically to all arms)

Guard-rejected VGH rows (the 50 retained health-gate/variance-domain rows,
§0.2) have no `Sigma_hat` and therefore `NA` `rel_frob`/`kappa`; per Design
122 §F2 they are set `degenerate = TRUE` by construction for the raw and
guard-inclusive denominators below. **The shipped `degenerate` column itself
left these 50 rows `NA`** — the harness never implemented a distinct
`guard_rejected` status string, so this construction was applied manually
here; that gap from the pre-registered instrumentation text is itself worth
naming.

### 4.1 Three denominators, per arm, pooled over the whole grid (informative only — see §4.2 for the F4-required stratified view)

| Denominator | Arm | n | n degenerate | rate |
|---|---|---:|---:|---:|
| **Raw** (n_attempted, infra excluded) | L0 | 7,200 | 1,067 | 14.82% |
| | L2 | 7,200 | 381 | 5.29% |
| | VGH | 7,080 | 61 | 0.86% |
| **Guard-inclusive** (identical to raw here — no separate hard-error class remains once infra rows are excluded; the only remaining VGH `status == "error"` rows are the 50 guard rejections, which the design requires to stay in) | L0 | 7,200 | 1,067 | 14.82% |
| | L2 | 7,200 | 381 | 5.29% |
| | VGH | 7,080 | 61 | 0.86% |
| **All-arm intersection** (paired subset: seed retained only if L0, L2, VGH all produced a usable `Sigma_hat`) | L0 | 7,030 | 1,055 | 15.01% |
| | L2 | 7,030 | 377 | 5.36% |
| | VGH | 7,030 | 11 | 0.16% |

7,030 of 7,200 attempted seed-cells have all three arms usable (170 dropped:
120 infra-excluded + 50 guard-rejected).

**Note on the VGH raw/guard-inclusive rate (61, 0.86%)**: this includes the
50 guard-rejected rows counted as degenerate by construction (11 are
genuine `rel_frob`/`kappa` breaches among "ok" fits, 50 are the constructed
guard-rejection count). The all-arm intersection column (11, 0.16%) excludes
guard-rejected seeds entirely from its denominator rather than counting them
as degenerate, since intersection requires a *usable* `Sigma_hat` in every
arm — the two are different, both pre-registered, questions.

### 4.2 Stratified by truth × n (Design 122 §F4 — never pooled across truth)

**Raw denominator:**

| truth | n | arm | n_attempted | n_deg | rate |
|---|---:|---|---:|---:|---:|
| T-weak | 100 | L0 | 1,200 | 374 | 31.17% |
| T-weak | 100 | L2 | 1,200 | 237 | 19.75% |
| T-weak | 100 | VGH | 1,200 | 24 | 2.00% |
| T-weak | 400 | L0 | 1,200 | 85 | 7.08% |
| T-weak | 400 | L2 | 1,200 | 80 | 6.67% |
| T-weak | 400 | VGH | 1,200 | 18 | 1.50% |
| T-mid | 100 | L0 | 1,200 | 288 | 24.00% |
| T-mid | 100 | L2 | 1,200 | 58 | 4.83% |
| T-mid | 100 | VGH | 1,200 | 11 | 0.92% |
| T-mid | 400 | L0 | 1,200 | 7 | 0.58% |
| T-mid | 400 | L2 | 1,200 | 6 | 0.50% |
| T-mid | 400 | VGH | 1,080 | 4 | 0.37% |
| T-strong | 100 | L0 | 1,200 | 284 | 23.67% |
| T-strong | 100 | L2 | 1,200 | 0 | 0.00% |
| T-strong | 100 | VGH | 1,200 | 4 | 0.33% |
| T-strong | 400 | L0 | 1,200 | 29 | 2.42% |
| T-strong | 400 | L2 | 1,200 | 0 | 0.00% |
| T-strong | 400 | VGH | 1,200 | 0 | 0.00% |

(T-mid/n=400/VGH uses denominator 1,080 = 1,200 − 120 infra-excluded, all in
cell 23.) Full CSV:
`dev/design122-campaign/tab-degeneracy-raw-by-truth-n-arm.csv`.

**All-arm intersection denominator** (paired subset per stratum):
`dev/design122-campaign/tab-degeneracy-intersection-by-truth-n-arm.csv`
(18 rows, same truth × n × arm structure; n_paired ranges 1,076–1,200 per
stratum, reflecting the seeds dropped by any arm's non-usable outcome in
that stratum).

---

## 5. `max|Lambda_hat|` distribution per arm (the runaway signature), stratified by truth × n

| truth | n | arm | n | median | mean | p90 | max |
|---|---:|---|---:|---:|---:|---:|---:|
| T-weak | 100 | L0 | 1,200 | 1.130 | 20.545 | 53.110 | 2,180.99 |
| T-weak | 100 | L2 | 1,200 | 1.026 | 1.696 | 4.644 | 8.78 |
| T-weak | 100 | VGH | 1,187 | 1.149 | 1.175 | 1.580 | 2.47 |
| T-weak | 400 | L0 | 1,200 | 0.593 | 1.425 | 0.837 | 13.12 |
| T-weak | 400 | L2 | 1,200 | 0.587 | 1.048 | 0.811 | 7.88 |
| T-weak | 400 | VGH | 1,182 | 0.660 | 0.685 | 0.918 | 1.25 |
| T-mid | 100 | L0 | 1,200 | 1.169 | 15.325 | 32.178 | 3,822.49 |
| T-mid | 100 | L2 | 1,200 | 1.093 | 1.419 | 2.545 | 8.87 |
| T-mid | 100 | VGH | 1,189 | 1.187 | 1.224 | 1.642 | 2.88 |
| T-mid | 400 | L0 | 1,200 | 0.791 | 0.865 | 0.956 | 12.37 |
| T-mid | 400 | L2 | 1,200 | 0.787 | 0.830 | 0.947 | 7.84 |
| T-mid | 400 | VGH | 1,076 | 0.831 | 0.854 | 1.037 | 1.44 |
| T-strong | 100 | L0 | 1,200 | 1.845 | 6.897 | 20.434 | 245.13 |
| T-strong | 100 | L2 | 1,200 | 1.604 | 1.781 | 2.638 | 6.51 |
| T-strong | 100 | VGH | 1,196 | 1.607 | 1.671 | 2.195 | 3.25 |
| T-strong | 400 | L0 | 1,200 | 1.406 | 1.742 | 1.941 | 22.83 |
| T-strong | 400 | L2 | 1,200 | 1.383 | 1.468 | 1.844 | 5.80 |
| T-strong | 400 | VGH | 1,200 | 1.394 | 1.411 | 1.748 | 2.37 |

(n < 1,200 for some VGH strata reflects the 120 infra-excluded rows in the
T-mid/n=400 stratum, plus a small number of guard-rejected rows removed from
whichever stratum they fell in — those rows have no `max|Lambda_hat|` at all,
so they are absent from n, not zero-filled.) Full CSV:
`dev/design122-campaign/tab-max-abs-lambda-by-truth-n-arm.csv`.

**Pattern common to every stratum**: L0's mean is pulled far above its own
median by a heavy right tail (e.g. T-mid/n=100: median 1.17 vs mean 15.3,
max 3,822), consistent with the runaway-loading pathology; L2's tail is
markedly shorter at matched cells; VGH's max never exceeds ~3.3 anywhere in
the grid.

---

## 6. Wall-clock and core-hours: actual vs the 382 core-hour projection

### 6.1 Core-hours (sum of per-fit `wall_time_s`, the CPU-time-weighted total)

| | core-hours |
|---|---:|
| Design 122 §16 measured projection (from the rung-3/canary extrapolation) | ~382 |
| **Actual, infra-excluded (21,480 rows)** | **365.19** |
| Actual, including the 120 near-instant infra failures (873s) | 365.43 |

The actual run came in **~4.4% below** the 382-core-hour projection.

### 6.2 Real elapsed wall-clock, and the build-root verdict

Per-chunk wall-clock (each chunk = 900 fits across 96 Totoro workers, chunks
run sequentially in this driver architecture), summed from every chunk's own
reported `wall=` line in `driver-chunks.log` / `rung3-chunk022.log` /
`rung-verify-chunk023.log`:

| Segment | Wall-clock |
|---|---:|
| Chunk 22 (`ordinal_probit, n=400, p=27, T-weak`) — banked from the pre-registered Rung 3 verification, §16, run *before* the shared build root was warmed | 56.52 min |
| Chunk 23 (`ordinal_probit, n=400, p=27, T-mid`) — the build-root verification run that hit the one-time compile race, §0.2 | 34.67 min |
| Chunks 1-2 (first driver attempt, before restart) + chunks 3-21, 24 (post-restart, sequential, shared `.so` already warm and stable) | ≈173.5 min |
| **Sum, all 24 chunks** | **4.41 h** |
| Driver-observed elapsed clock for the post-restart main run alone (chunk 1 start → chunk 24 finish, per `driver.log`/`driver2.log` timestamps) | 2h 55m 30s ≈ 2.93 h |

Design §16's own framing: unoptimized (24 independent compiles, ~7 min DLL
burst each) projected to **~6.5-7 h**; with `GLLVMTMB_VA_R3_BUILD_ROOT` set,
projected to collapse toward **~4.0 h** (the pure-compute floor at 96
workers). **The measured total — 4.41 h across all 24 chunks — lands almost
exactly on the optimized ~4.0 h projection and nowhere near the unoptimized
~6.5-7 h figure.** The shared build root did produce close to its predicted
~2.8 h saving.

**The one-time race (§0.2) was a data-loss cost, not a wall-clock cost.**
Chunk 23's own wall-clock (34.67 min) is *shorter* than chunk 22's (56.52
min) precisely because the 120 race-affected VGH fits failed in well under a
second each rather than running a full ~600+s VA fit — the race shows up in
the row-completeness ledger (§0.2, §1), not in the timing ledger.

---

## 7. Ordinal cutpoint columns (Design 122 §17 pre-registered scope-out)

**Confirmed exactly as pre-registered: VGH's `tau2_hat`/`tau3_hat`/
`max_abs_tau_error` are `NA` on every ordinal_probit VGH row, with a captured
error string, never silently dropped.**

- VGH-ordinal nominal population: `ordinal_probit` occupies cells 13-24
  (12 cells) × 300 seeds = 3,600 VGH-ordinal rows nominal. Cell 23's 120
  infra-excluded rows (§0.2) are the only ones removed, leaving **3,480**
  infra-excluded VGH-ordinal rows analysed here.
- **All 3,480 of these VGH-ordinal rows have `tau2_hat`, `tau3_hat`, AND
  `max_abs_tau_error` = `NA`** — 100%, matching §17's statement that
  `extract_cutpoints()` rejects every VA-route fit.
- L0/L2 ordinal rows (7,200 rows, 3,600 each, cells 13-24): **zero** `NA` on
  `tau2_hat`/`tau3_hat` — cutpoints are measured normally for both Laplace
  arms on every ordinal row, exactly as §17 states ("Not withdrawn for
  Laplace").

**Count of ordinal-VGH `NA` cutpoint rows: 3,480 (100% of the usable VGH
ordinal_probit population, i.e. 3,600 nominal minus the 120 infra-excluded
rows at cell 23).**

---

## 8. File provenance

- Raw chunks: `dev/design122-campaign/results/chunk-001.csv` .. `chunk-024.csv`
  — md5-verified identical to
  `~/gllvm_work/campaigns/design122-confirmatory-20260817-646005cf/chunk-*.csv`
  on Totoro (all 24 checksums match byte-for-byte).
- Parsed combined data: `dev/design122-campaign/campaign-all-rows.rds`
  (21,600 rows, all statuses), `dev/design122-campaign/campaign-clean-rows.rds`
  (21,480 rows, infra-excluded analysis set used in §§1-6).
- Row-count reconciliation: `dev/design122-campaign/rowcount-check.csv`.
- Summary tables: `dev/design122-campaign/tab-completion-by-cell-arm.csv`,
  `tab-convergence-by-cell-arm.csv`,
  `tab-degeneracy-raw-by-truth-n-arm.csv`,
  `tab-degeneracy-intersection-by-truth-n-arm.csv`,
  `tab-max-abs-lambda-by-truth-n-arm.csv`.
- Operator logs establishing the compile-race timeline:
  `dev/design122-campaign/driver-remaining-chunks.sh` (header comment),
  `dev/design122-campaign/rung-verify-chunk023.log`,
  `dev/design122-campaign/rung3-chunk022.log`,
  `dev/design122-campaign/driver.log`, `driver2.log`, `driver-chunks.log`.

This document was written on branch `claude/design122-results-20260817`
(off `origin/main`); nothing has been committed.
