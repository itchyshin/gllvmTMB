# Binomial 0.0000 stall-rate interrogation (Slice B0), 2026-07-29

**Role: Gauss.** Zero new compute. Read-only analysis of the existing 432,000-row
`~/h4_work/regime.csv` (113 MB) on Totoro, via the passwordless ControlMaster socket. Raw data
was never copied off Totoro (D-50); only these summary tables were brought back. Source: the
sibling doc `2026-07-29-flat-regime-campaign-results.md` and the campaign script
`dev/aghq-evidence/23-flat-regime-campaign.R` (read locally, not on Totoro).

## VERDICT

**UPDATED 2026-07-29 (follow-up slice — see "Corrected re-derivation" below for full detail).**
**The 🔴 hypothesis (AGHQ eligibility fence → silent Laplace fallback) is REFUTED.**
`aghq_used` is `TRUE` for **100% of binomial rows** (144,000/144,000) — identical to gaussian
(100%) and effectively identical to poisson (99.99%). AGHQ ran for every binomial fit; nothing
was silently measured-as-Laplace. **The mystery is not dissolved — it is relocated into a
concrete, source-confirmed labeling bug, and the follow-up slice shows that bug is large enough
to overturn one of the campaign's three quadrature-hypothesis verdicts.** The campaign's `stalled`
column is derived as `grepl("^STALLED", stop_reason)` — case-sensitive, anchored to the literal
uppercase string `"STALLED"` (`dev/aghq-evidence/23-flat-regime-campaign.R:108`). The AGHQ engine
(`R/fit-multi.R`) emits **three different English messages for three different "stuck" code
paths**: uppercase `"STALLED at the warm start: ..."` (`:5524`, the only one the regex matches),
lowercase `"stalled (no honest descent at cap 1 after backtracking)"` (`:5482`, binomial's
dominant message, 45.49% of its rows, invisible to the regex), and `"stopped: adaptation mode
fixed and objective stagnated, ..."` (`:5531`, excluded from `stalled` by the engine's own design,
not a bug, but disproportionately common for binomial, 43.83% vs 25.66% poisson / 8.92% gaussian).
The follow-up slice below tested three explicit stall definitions on the same data: **D1
(as-published, `^STALLED` only) exactly reproduces the published 0.0000/0.7401/0.8956 family
numbers** (confirmed to 4 decimal places — the discrepancy is not larger than a regex). **Under
D2** (`:5482`+`:5524`), the family spread narrows sharply (0.4549/0.7419/0.8956) — binomial closes
roughly half the gap. **Under D3** (`:5482`+`:5524`+`:5531`, every terminal "did-not-converge"
state), **all three families cluster near ceiling** (binomial 0.8932, gaussian 0.9848, poisson
0.9986) — a 10.5-point spread instead of the original 89.6-point spread, and **poisson and
gaussian swap rank order** (poisson becomes the highest, not the lowest of the two). The
"family dominates lam_sd" ranking survives numerically at every definition, but its substance
does not: D1's story ("binomial is categorically immune") is false under any broader definition;
the true picture is "all three families overwhelmingly land in a not-fully-resolved terminal
state, and binomial's residual advantage is real but an order of magnitude smaller than 89.6
points."

> 🔴 **SUPERSEDED — read the D-43 disposition in the final section before using anything below
> about H3, D2 or D3.** This section originally concluded that **H3 does not survive** — that
> under D2/D3 there is a clear, monotonic, highly significant `aghq_k` effect the D1 metric was
> blind to. **A three-lens adversarial panel WITHHELD that conclusion, 2-1, both refutations at
> high confidence.** In short: (1) **D3 is not a stall definition** — `:5531` fires only when the
> optimiser *did* move, so D3 relabels ~157,000-168,000 fits as "stalled" that shifted the estimate
> by a median of 0.4; (2) **the design is PAIRED** — every DGP is fit three times, once per
> `aghq_k`, so the unpaired 2·MCSE ratios (12.5x, 12.6x) are the wrong statistic, and under the
> correct paired test even D1 is "significant" (McNemar p=1.4e-4), which means significance at
> N=144k cannot adjudicate H3 at all; (3) the pooled effect is **~100% binomial** — gaussian is
> *bit-identical* across `aghq_k`. **H3's verdict stands. Its wording does not.** What survives
> is narrower and is stated in the disposition section.

A genuinely new,
non-artefactual finding also emerged: binomial's two dominant failure branches (`:5482` vs
`:5531`) trade off with regime — `:5482` becomes dominant at high `lam_sd` and low `n`, `:5531`
at low `lam_sd` and high `n` — a real family-specific structural pattern that has nothing to do
with the labeling bug. Distributional evidence (passes, elapsed time, `par_shift`) still shows
binomial fits running far longer than gaussian/poisson, the opposite of the "binomial converges
fast and cleanly" picture the 0.0000 headline implied.

---

## 1. `aghq_used` by family — THE DECIDING QUESTION

Command run on Totoro (`~/h4_work/binomial_stall_interrogation.R`, via
`OPENBLAS_NUM_THREADS=1 Rscript binomial_stall_interrogation.R`):

```r
dt[, .N, by = .(fam, aghq_used)]
```

| fam | aghq_used | N |
|---|---|---|
| binomial | TRUE | 144,000 |
| gaussian | TRUE | 144,000 |
| poisson | FALSE | 15 |
| poisson | TRUE | 143,985 |

Fraction TRUE per family:

| fam | n_total | n_aghq_TRUE | n_aghq_FALSE | n_aghq_NA | frac_aghq_TRUE |
|---|---|---|---|---|---|
| gaussian | 144,000 | 144,000 | 0 | 0 | 1.0000 |
| poisson | 144,000 | 143,985 | 15 | 0 | 0.99990 |
| binomial | 144,000 | 144,000 | 0 | 0 | 1.0000 |

**Answer: `aghq_used` is TRUE for every single binomial row.** The eligibility-fence hypothesis
is false for this campaign — binomial never routed to Laplace fallback. The mystery of why
binomial's *measured* stall rate is 0.0000 must have another cause (see §2 and the VERDICT).

---

## 2. `stop_reason` verbatim by family

Command:

```r
dt[, .N, by = .(fam, stop_reason)]        # raw strings (numeric values embedded → thousands of
                                            # near-unique strings per family, because each message
                                            # interpolates gradient/pass values to full precision)
dt[fam == "binomial", .N, by = stop_reason]
```

The raw `stop_reason` strings embed a formatted numeric (`max |grad| = %.3g`, or a pass number),
so there are 9,134 distinct `(fam, stop_reason)` combinations overall and 461 distinct strings
for binomial alone — almost all differing only in the trailing gradient value. To honor "actual
strings, not summarised categories" while keeping the table readable, two views are given below:
(a) the exact top-count raw strings, and (b) a **template** view that replaces only the numeric
substrings with `#` (a mechanical `gsub`, not a semantic recategorisation) so the small number of
distinct *message kinds* is visible. Both were computed from the same column; no row was dropped
or reclassified by hand.

### 2a. Binomial — top raw `stop_reason` strings by count

| stop_reason (verbatim) | N |
|---|---|
| `stalled (no honest descent at cap 1 after backtracking)` | 65,506 |
| `converged (adaptation mode fixed; gradient below tolerance)` | 12,050 |
| `adaptation failed at pass 13; kept the last honest iterate` | 2,036 |
| `stopped: adaptation mode fixed and objective stagnated, but max \|grad\| = 0.000156 exceeds the tolerance of 0.0001` | 353 |
| `stopped: adaptation mode fixed and objective stagnated, but max \|grad\| = 0.000141 exceeds the tolerance of 0.0001` | 343 |
| … (456 further strings, each differing only in the interpolated gradient/pass value) | 1 – few each |

### 2b. Binomial — template-collapsed message kinds (numeric substrings replaced by `#`)

| template | N | frac of binomial |
|---|---|---|
| `stalled (no honest descent at cap # after backtracking)` | 65,506 | 0.45490 |
| `stopped: adaptation mode fixed and objective stagnated, but max \|grad\| = # exceeds the tolerance of #` | 63,108 | 0.43825 |
| `converged (adaptation mode fixed; gradient below tolerance)` | 12,050 | 0.08368 |
| `adaptation failed at pass #; kept the last honest iterate` | 3,223 | 0.02238 |
| `adaptation cap reached` | 113 | 0.00078 |

**Binomial never emits the uppercase `"STALLED at the warm start: ..."` message at all** — 0
occurrences (confirmed in §5c). Its dominant stopping message (45.49%) is the lowercase
`"stalled (no honest descent ...)"` string, which the campaign's `stalled` column cannot see.

### 2c. Poisson — template-collapsed message kinds (for contrast)

| template | N | frac |
|---|---|---|
| `STALLED at the warm start: ... NOT converged.` | 106,559 | 0.73999 |
| `stopped: adaptation mode fixed and objective stagnated, but max \|grad\| = # exceeds the tolerance of #` | 36,951 | 0.25660 |
| `stalled (no honest descent at cap # after backtracking)` | 262 | 0.00182 |
| `converged (adaptation mode fixed; gradient below tolerance)` | 188 | 0.00131 |
| `stopped: ... max \|grad\| = Inf exceeds the tolerance of #` | 18 | 0.000125 |
| `NA` | 15 | 0.000104 |
| `adaptation cap reached` | 7 | 0.0000486 |

### 2d. Gaussian — template-collapsed message kinds (for contrast)

| template | N | frac |
|---|---|---|
| `STALLED at the warm start: ... NOT converged.` | 128,961 | 0.89563 |
| `stopped: adaptation mode fixed and objective stagnated, but max \|grad\| = # exceeds the tolerance of #` | 12,846 | 0.08921 |
| `converged (adaptation mode fixed; gradient below tolerance)` | 2,193 | 0.01523 |

**Answer to "what do binomial fits stop for, if not stalling":** overwhelmingly for the
lowercase `stalled (no honest descent ...)` message (45.5%) and the `stopped: ... stagnated`
message (43.8%) — both of which describe the optimiser failing to make further honest progress,
worded differently from (and, for the first, invisible to) the campaign's case-sensitive
`^STALLED` regex.

---

## 3. Distributional contrasts across families

Command (per variable `v`): `dt[, as.list(qsumm(get(v))), by = fam]` with
`qsumm <- function(x) c(min, q25, median, q75, max, mean)` (NA-stripped).

### `passes`

| fam | min | q25 | median | q75 | max | mean |
|---|---|---|---|---|---|---|
| gaussian | 2 | 2 | 2 | 2 | 9 | 2.081 |
| poisson | 2 | 2 | 2 | 3 | 400 | 2.362 |
| binomial | 8 | 12 | **14** | 36 | **400** | 24.434 |

### `par_shift`

| fam | min | q25 | median | q75 | max | mean |
|---|---|---|---|---|---|---|
| gaussian | 0 | 0 | 0 | 0 | 1.11e-04 | 1.06e-06 |
| poisson | 0 | 0 | 0 | 6.48e-04 | 0.2328 | 1.97e-03 |
| binomial | 0 | 0.3219 | 0.7049 | 2.0939 | 6807.6 | 3.797 |

### `objective`

| fam | min | q25 | median | q75 | max | mean |
|---|---|---|---|---|---|---|
| gaussian | 793.8 | 1021.0 | 1932.9 | 3651.0 | 5460.7 | 2268.5 |
| poisson | 945.3 | 1428.5 | 2533.3 | 4701.9 | 7.13e13 | 1.79e9 |
| binomial | 225.2 | 391.3 | 764.3 | 1434.4 | 1657.7 | 870.9 |

### `convergence` (raw `fit$opt$convergence` code, standard nlminb convention: 0 = success)

| fam | min | q25 | median | q75 | max | mean(=frac code 1) |
|---|---|---|---|---|---|---|
| gaussian | 0 | 1 | 1 | 1 | 1 | 0.9411 |
| poisson | 0 | 1 | 1 | 1 | 1 | 0.9901 |
| binomial | 0 | 0 | 0 | 1 | 1 | 0.4516 |

Counts: binomial convergence=0 (success) 78,976 / convergence=1 (failure) 65,024; gaussian
success 8,480 / failure 135,520; poisson success 1,424 / failure 142,576. This column is
`fit$opt$convergence` verbatim (`dev/aghq-evidence/23-flat-regime-campaign.R:110`), the raw
optimizer return code (0 = converged is the standard `nlminb`/`optim` convention — not verified
against the campaign author's own labeling beyond the source line cited). **Note the sign is
opposite to a naive "convergence flag" reading**: under this convention, binomial's *outer*
optimizer success rate (54.8%) is actually the *highest* of the three families, not the lowest —
this is a MEASURED fact but its relationship to the AGHQ-specific "stalled" text is not settled
by this slice (see §5's cross-tab, which shows the two do not align simply); flagged here as
raw data, not as resolved causal interpretation.

### `elapsed_s`

| fam | min | q25 | median | q75 | max | mean |
|---|---|---|---|---|---|---|
| gaussian | 0.149 | 0.303 | 0.426 | 0.624 | 3.12 | 0.511 |
| poisson | 0.160 | 0.340 | 0.501 | 0.747 | 38.22 | 0.599 |
| binomial | 0.352 | 1.419 | **2.646** | 4.767 | 171.14 | 3.725 |

### Floor/ceiling fractions

`max_passes` observed: gaussian 9, poisson 400, binomial 400 (both poisson and binomial reach
the iteration cap for some seeds). `frac_par_shift_eq0`: gaussian 0.9094, poisson 0.7419,
binomial **0.00832** (binomial almost never shows literally-zero parameter movement).

**Answer:** binomial does **not** look like a family that converges fast and cleanly. It takes
7× the median passes and ~5–6× the median wall-clock time of poisson/gaussian, hits the same
400-pass cap poisson does, and shows large nonzero `par_shift` (median 0.70, max 6,808 — far
above gaussian/poisson). This pattern is inconsistent with "the AGHQ stall test never fires
because there's nothing to stall" — binomial fits are working hard and often not settling; they
are simply not being *counted* as stalled by the case-sensitive regex.

---

## 4. Is the binomial 0.0000 exact, and what's excluded from the denominator?

Commands:

```r
dt[fam == "binomial", .N, by = stalled]
sum(!is.na(bin$error) & trimws(as.character(bin$error)) != "")
sum(bin$aghq_used == FALSE, na.rm = TRUE); sum(is.na(bin$aghq_used))
```

| stalled | N |
|---|---|
| FALSE | 144,000 |

**Confirmed exact: `stalled` is FALSE for literally all 144,000 binomial rows** — 0.0000 is not
a rounding artefact of a very small nonzero count; the count is exactly zero.

- `error` field: class `logical`, **144,000/144,000 are `NA`** (0 empty-string, 0 non-empty) — no
  binomial rows carry an error flag that would exclude them from any denominator.
- `aghq_used` FALSE or NA count for binomial: **0 and 0** — no exclusions there either.
- Restricting to `aghq_used == TRUE` only (i.e., the correct denominator if one *were* excluding
  non-AGHQ rows) changes nothing: `stalled` is still FALSE for all 144,000/144,000.

**Answer: the 0.0000 is an exact, unrounded zero over the full, unfiltered 144,000-row
denominator.** It is not diluted or produced by an exclusion artefact — it comes entirely from
the regex's blindness to binomial's lowercase message (§2, VERDICT).

---

## 5. Interaction check — is binomial's pattern flat across `lam_sd` and `aghq_k`?

Command:

```r
bin[, .(n, frac_aghq_used_TRUE = mean(aghq_used==TRUE), frac_stalled_TRUE = mean(stalled==TRUE)),
    by = .(lam_sd, aghq_k)]
bin[, .(...), by = .(lam_sd, n, eta_cap, aghq_k)]   # full 72-cell grid
```

### 5a. By `lam_sd × aghq_k` (12 cells, 12,000 rows each)

`frac_aghq_used_TRUE = 1.0000` and `frac_stalled_TRUE = 0.0000` in **every one of the 12 cells**
(`lam_sd` ∈ {0.5, 1, 2, 3} × `aghq_k` ∈ {9, 25, 51}).

### 5b. Full grid: `lam_sd × n × eta_cap × aghq_k` (72 cells, 2,000 rows each)

Every one of the 72 cells shows `frac_aghq_used_TRUE = 1.0000` and `frac_stalled_TRUE = 0.0000`,
with no exceptions (full table generated; identical pattern in all 72 rows, so not reproduced
verbatim here — see the interrogation script output for the complete listing).

### 5c. Sanity check

`unique(bin$aghq_used)` → `TRUE` only (no other values present at all for binomial).

**Answer: the 0.0000 `stalled` rate and the 1.0000 `aghq_used` rate are both perfectly flat
across every regime cell tested** — `lam_sd`, `aghq_k`, `n`, and `eta_cap` all checked, 72/72
cells identical. This is exactly the signature of a **structural labeling artefact** (the regex
bug applies identically regardless of simulation regime) rather than a regime-dependent
statistical phenomenon — a genuine dose-response effect (like the `lam_sd` monotonicity reported
elsewhere in the campaign for the stall rate overall) would not be perfectly flat at 0/1 in every
cell.

---

## Root-cause corroboration (source code, read locally — not part of the Totoro data pull)

`dev/aghq-evidence/23-flat-regime-campaign.R:108`:
```r
stalled = if (is.null(a$stop_reason)) NA else grepl("^STALLED", a$stop_reason),
```
`grepl()` is case-sensitive by default (`ignore.case = FALSE`).

`R/fit-multi.R:5482` (backtracking-exhaustion branch, stage 1):
```r
aghq_stop <- "stalled (no honest descent at cap 1 after backtracking)"
```

`R/fit-multi.R:5521-5534` (the `n_ok >= 2` stationarity-test branch):
```r
stalled <- isTRUE(identical(par_cur, par_start_aghq)) &&
  is.finite(g_cur) && g_cur >= grad_tol
aghq_stop <- if (stalled) {
  sprintf(paste0("STALLED at the warm start: the optimiser moved nothing, ...
```
This second branch's own code comment (`R/fit-multi.R:5504-5519`) already discusses the risk of
mislabeling: *"forcing them risks the binomial path that genuinely converges here (12 passes,
par_shift 0.55)"* — i.e., the engine's author was aware binomial's convergence behaviour differs
from the "zero movement" `STALLED` test at least for some cases, though this comment concerns the
`identical(par_cur, par_start_aghq)` branch specifically, not the separate line-5482
backtracking-exhaustion branch that produces binomial's dominant lowercase message. Whether that
lowercase message represents a genuine stall or a genuine (if slow) convergence path is not
settled by this data-only slice — see the `convergence`-code cross-tab note in §3, which shows
the outer-optimizer success/failure split for that message template does not resolve cleanly
either way (94.5% `convergence`-code failure for the "no honest descent" template vs 99.9%
`convergence`-code success for the "stopped: ... stagnated" template) and would need a follow-up
audit of the AGHQ-vs-outer-optimizer relationship, which is out of scope for this B0 slice.

---

## Reproducibility — exact commands run

All commands run via:
```bash
SOCK=$(ls ~/.ssh/cm-*totoro* 2>/dev/null | head -1)
ssh -o ControlPath="$SOCK" -o ControlMaster=no -o BatchMode=yes -o ConnectTimeout=15 totoro '<cmd>'
```

1. Confirmed socket and file: `ssh ... totoro 'echo OK; hostname; ls -la ~/h4_work/regime.csv'`
2. Confirmed R/data.table on Totoro: `Rscript -e 'cat(R.version.string); requireNamespace("data.table")'`
3. Copied (not the data — the analysis scripts) to Totoro via `scp` and ran with
   `cd ~/h4_work && OPENBLAS_NUM_THREADS=1 Rscript <script>.R`, output piped back over SSH and
   captured locally as plain text (no CSV/data left the machine beyond what is reproduced in the
   tables above). Three scripts were run in sequence:
   - `binomial_stall_interrogation.R` — Q1–Q5 primary tables (§1–5 above).
   - `binomial_stall_followup.R` — case-sensitivity confirmation (`^STALLED` vs
     `^stalled`/`ignore.case`), template collapsing, and the "combined stall-like" recomputation
     quoted in the VERDICT.
   - `binomial_stall_followup2.R` — `template × convergence` cross-tabs per family (the
     `fit$opt$convergence`-code corroboration noted in §3 and the root-cause section).
4. Root cause was corroborated by reading `dev/aghq-evidence/23-flat-regime-campaign.R` and
   `R/fit-multi.R` **locally** in the gllvmTMB repo (not on Totoro) — this is package source, not
   simulation output, so it involves no data transfer.

**Per D-50, the raw 113 MB `~/h4_work/regime.csv` was never copied off Totoro.** Only the summary
tables above (all well under a few KB) were brought back to this machine.

---
---

# Corrected re-derivation (follow-up slice, 2026-07-29, same data, zero new compute)

Coordinator-confirmed both load-bearing source claims independently (`23-flat-regime-campaign.R:108`
uses `grepl("^STALLED", ...)`; `R/fit-multi.R` has the three distinct messages at `:5482`, `:5524`,
`:5531`, only `:5524` matched). This section re-derives the campaign's headline and its three
sub-verdicts (H1/H2/H3) under three explicit stall definitions, reports the full sensitivity rather
than picking one, and asks whether the published conclusions survive. The original interrogation
section above is left intact — the artefact discovery is part of the record.

All numbers below come from three scripts run on Totoro exactly as in the primary interrogation
(same `ssh`/`scp` pattern, `cd ~/h4_work && OPENBLAS_NUM_THREADS=1 Rscript <script>.R`, output piped
back and captured locally): `binomial_stall_corrected_rederivation.R` (definitions, family tables,
H1/H2/H3) and `binomial_stall_branch_profile.R` (the `dcast`-based per-regime branch tables, built
to avoid transcription risk in wide printed output). Raw data stayed on Totoro throughout (D-50).

## Definitions

- **D1 (as-published):** `stalled = grepl("^STALLED", stop_reason)` — matches only `:5524`
  (`"STALLED at the warm start: ..."`).
- **D2 (narrow-substantive):** `:5482` (`"stalled (no honest descent ...)"`) **or** `:5524` — the
  two messages that explicitly say the optimiser did not move / found no honest descent.
- **D3 (broad-substantive):** `:5482` **or** `:5524` **or** `:5531`
  (`"stopped: adaptation mode fixed and objective stagnated, ..."`) — every terminal state that is
  "did not converge and stopped moving," excluding only genuine convergence, adaptation-failure
  (a distinct exception path, `:5353`), and cap-reached (`:5328`).

**Sanity check — D1 must equal the original `stalled` column exactly, row for row:**

```r
chk <- dt[, .(n = .N, n_match = sum(D1 == stalled, na.rm = TRUE),
              n_mismatch = sum(D1 != stalled, na.rm = TRUE),
              n_either_na = sum(is.na(D1) | is.na(stalled)))]
```

| n | n_match | n_mismatch | n_either_na |
|---|---|---|---|
| 432,000 | 431,985 | **0** | 15 |

Zero mismatches across all 431,985 non-NA rows (the 15 NA rows are poisson's `aghq_used == FALSE`
rows, NA on both sides by construction). `D1` is a faithful re-implementation.

## 1. Full cross-tab — `stop_reason` template × family, counts and row percentages

Command: `dt[, .N, by = .(fam, template)]; tab[, pct_of_fam := 100*N/sum(N), by = fam]`, with the
same numeric-stripping `gsub` used in the primary section (mechanical only, no hand recategorisation).

| fam | template | N | % of family |
|---|---|---|---|
| binomial | `stalled (no honest descent at cap # after backtracking)` | 65,506 | 45.4903 |
| binomial | `stopped: adaptation mode fixed and objective stagnated, but max\|grad\|=# exceeds tolerance #` | 63,108 | 43.8250 |
| binomial | `converged (adaptation mode fixed; gradient below tolerance)` | 12,050 | 8.3681 |
| binomial | `adaptation failed at pass #; kept the last honest iterate` | 3,223 | 2.2382 |
| binomial | `adaptation cap reached` | 113 | 0.0785 |
| gaussian | `STALLED at the warm start: ... NOT converged.` | 128,961 | 89.5563 |
| gaussian | `stopped: adaptation mode fixed and objective stagnated, ...` | 12,846 | 8.9208 |
| gaussian | `converged (adaptation mode fixed; gradient below tolerance)` | 2,193 | 1.5229 |
| poisson | `STALLED at the warm start: ... NOT converged.` | 106,559 | 73.9993 |
| poisson | `stopped: adaptation mode fixed and objective stagnated, ...` | 36,951 | 25.6604 |
| poisson | `stalled (no honest descent at cap # after backtracking)` | 262 | 0.1819 |
| poisson | `converged (adaptation mode fixed; gradient below tolerance)` | 188 | 0.1306 |
| poisson | `stopped: ... max\|grad\|=Inf exceeds the tolerance of #` | 18 | 0.0125 |
| poisson | `NA` (aghq_used == FALSE, no AGHQ run) | 15 | 0.0104 |
| poisson | `adaptation cap reached` | 7 | 0.0049 |

Each family's percentages sum to 100% (144,000 rows each); 15 distinct `(fam, template)` combinations
cover all 432,000 rows exactly — no `"retape failed"`, `"non-finite AGHQ objective"`, or `"optimiser
failed"` messages (other branches present in the source, `:5394`/`:5406`/`:5548`) occur anywhere in
this campaign.

## 2. Three candidate stall definitions, all three families

Command: `dt[!is.na(D), .(n=.N, rate=mean(D)), by=fam]; mcse2 = 2*sqrt(rate*(1-rate)/n)`.

### D1 — reproduction check (must match published 0.0000 / 0.7401 / 0.8956)

| fam | n | rate | 2·MCSE |
|---|---|---|---|
| binomial | 144,000 | **0.0000** | 0.0000 |
| poisson | 143,985 | **0.7401** | 0.0023 |
| gaussian | 144,000 | **0.8956** | 0.0016 |

**Reproduced exactly** (to the 4 decimal places the published doc reports). D1 is not a
mis-derivation on this slice's part — the discrepancy the original doc's headline hides is real and
is exactly the regex/message-case issue diagnosed above, not a computational error.

### D2 — narrow-substantive (`:5482` + `:5524`)

| fam | n | rate | 2·MCSE |
|---|---|---|---|
| binomial | 144,000 | **0.4549** | 0.0026 |
| poisson | 143,985 | **0.7419** | 0.0023 |
| gaussian | 144,000 | **0.8956** | 0.0016 |

(Gaussian is unchanged from D1 — it never produces a `:5482` message at all, per §1's cross-tab.
Poisson barely moves, +0.0018 — `:5482` is nearly absent for poisson too, 0.18% of its rows.
Binomial jumps from 0.0000 to 0.4549 — this is the whole effect of the case-sensitivity bug.)

### D3 — broad-substantive (`:5482` + `:5524` + `:5531`)

| fam | n | rate | 2·MCSE |
|---|---|---|---|
| binomial | 144,000 | **0.8932** | 0.0016 |
| poisson | 143,985 | **0.9986** | 0.0002 |
| gaussian | 144,000 | **0.9848** | 0.0006 |

All three families are now within an 10.5-point band near ceiling. **Poisson and gaussian swap rank
order** relative to D1/D2 (poisson 0.9986 > gaussian 0.9848 here; gaussian 0.8956 > poisson 0.7401 /
0.7419 under D1/D2) — a genuine rank inversion, not just a magnitude change.

## 3. Does the headline survive?

Published claim: *"family dominates: 0.00 → 0.74 → 0.90, a stronger predictor than `lam_sd`."*
Comparing the marginal family range to the marginal `lam_sd` range (§4, H2) at each definition:

| definition | family range | `lam_sd` range (H2) | family / `lam_sd` ratio |
|---|---|---|---|
| D1 | 0.8956 (0.0000→0.8956) | 0.1827 (0.4274→0.6101) | 4.9× |
| D2 | 0.4407 (0.4549→0.8956) | 0.3137 (0.5291→0.8428) | 1.4× |
| D3 | 0.1055 (0.8932→0.9986) | 0.0157 (0.9505→0.9662) | 6.7× |

**The numeric ranking ("family range > `lam_sd` range") survives under all three definitions** — so
the narrow claim "family is a bigger axis of variation than `lam_sd` in this design" is not overturned
by the labeling bug. **But what "family dominates" *means* does not survive.** Under D1 it means
"binomial is categorically immune, gaussian usually stalls." Under D3 it means "every family
overwhelmingly ends in a not-fully-resolved terminal state (89–100%), and binomial's residual
advantage, while real and still the largest single-factor margin in the design, is 10.5 points, not
89.6." **Verdict: weakens sharply in substance; the bare ranking survives; poisson and gaussian
invert rank between D1/D2 and D3.** Anyone citing "0.00/0.74/0.90" as-is is citing an artefact-laden
number; anyone citing "family is the dominant axis" is on firmer ground but should not describe
binomial as immune.

## 4. Do H1/H2/H3 survive under D3?

All three were originally computed as pooled marginals across the full factorial design (each level
of `aghq_k`/`eta_cap`/`lam_sd` has equal representation of every other factor, including family, so
a marginal comparison is unconfounded). Comparing each definition's group-to-group gap against the
**sum of the two groups' own 2·MCSE** (the convention the original doc used for its own "marginally
outside combined MCSE" call on H1).

### H3 — quadrature artefact (published: REFUTED, flat across `aghq_k` 9/25/51)

| aghq_k | D1 rate | D2 rate | D3 rate |
|---|---|---|---|
| 9 | 0.5455 | 0.7277 | 0.9727 |
| 25 | 0.5451 | 0.6971 | 0.9569 |
| 51 | 0.5451 | 0.6675 | 0.9470 |

D1 (9 vs 51): gap 0.0004 vs combined 2·MCSE 0.0052 — flat, REFUTED, matches published.
D2 (9 vs 51): gap 0.0603 vs combined 0.0048 — **12.5× the combined MCSE, monotonic decrease.**
D3 (9 vs 51): gap 0.0257 vs combined 0.0020 — **12.6× the combined MCSE, monotonic decrease.**

**H3 does NOT survive. It reverses** from "REFUTED — flat" (D1) to a clear, monotonic, highly
significant `aghq_k` effect under D2 and D3: **more quadrature nodes → lower stall-like rate.** This
is exactly the adaptive-quadrature-literature mechanism the campaign set out to test (too few nodes
flattens the objective) — it was real, and the narrow `^STALLED`-only metric was blind to it because
adding nodes changes whether the optimiser eventually gets unstuck (`:5482`/`:5531`), not whether it
moves literally nothing on the very first pass (`:5524`'s `identical()` test).

### H1 — `eta_cap`, restricted to `lam_sd ≥ 2` (published: REFUTED, small wrong-direction effect)

| eta_cap | D1 rate | D2 rate | D3 rate |
|---|---|---|---|
| FALSE (uncapped) | 0.6069 | 0.8182 | 0.9658 |
| TRUE (capped) | 0.6005 | 0.8087 | 0.9647 |

D1: gap 0.0065 vs combined 2·MCSE 0.0060 — marginally outside (1.09×), matches published "marginally
outside combined MCSE, small, wrong direction."
D2: gap 0.0095 vs combined 0.0047 — 2.0× combined MCSE, now clearly significant, same direction.
D3: gap 0.0011 vs combined 0.0022 — **inside combined MCSE, not significant.**

**H1's qualitative conclusion ("the cap is not the cause, effect is tiny") survives under all three
definitions in the sense that mattered to the original argument** — the gap never exceeds ~1
percentage point anywhere. Its formal significance is definition-sensitive (marginal under D1, clear
under D2, absent under D3, a ceiling-compression effect), which the original doc should not be read
as settling one way; but no definition makes `eta_cap` a material driver of the family effect.

### H2 — inherent regime, `lam_sd` (published: SUPPORTED, monotone)

| lam_sd | D1 rate | D2 rate | D3 rate |
|---|---|---|---|
| 0.5 | 0.4274 | 0.5291 | 0.9505 |
| 1.0 | 0.5460 | 0.6339 | 0.9544 |
| 2.0 | 0.5973 | 0.7841 | 0.9643 |
| 3.0 | 0.6101 | 0.8428 | 0.9662 |

D1 (0.5 vs 3.0): gap 0.1827 vs combined 0.0060 — 30.6× combined MCSE, clearly monotonic.
D2 (0.5 vs 3.0): gap 0.3137 vs combined 0.0053 — 60× combined MCSE, even more pronounced.
D3 (0.5 vs 3.0): gap 0.0157 vs combined 0.0024 — 6.5× combined MCSE, still clearly monotonic.

**H2 SURVIVES cleanly under all three definitions** — monotonic and far outside MCSE in every case.
It is the most robust of the three verdicts, though its practical size compresses from an 18.3-point
range (D1) to a 1.6-point range (D3) as the ceiling effect takes hold.

**Summary: 2 of 3 published sub-verdicts (H1, H2) hold their qualitative conclusion under the broad
definition. H3 does not — it inverts.** The campaign document's H3 section ("Adding nodes changes
nothing") is the one claim in the whole document this follow-up slice contradicts outright.

## 5. Per-family branch profile — a real, non-artefactual finding

Command (per grouping variable `g`): `dt[, .N, by=.(fam, g, tshort)]` then `dcast(fam+g ~ tshort)`,
where `tshort` classifies each row into one of the six named branches (`b5482_stalled_lower`,
`b5524_STALLED_upper`, `b5531_stopped_stagnated`, `converged`, `adaptation_failed`,
`adaptation_cap`) by regex-matching the message prefix.

**Gaussian and poisson never produce `:5482`** (gaussian: 0.00% at every regime cell checked;
poisson: 0.01–0.62%, rising slightly with `lam_sd` but never material). Their dominant branch is
always `:5524` (uppercase `STALLED`), and for both families its share **rises sharply with `n`**:
gaussian 77.4% (n=100) → 92.1% (n=200) → 99.1% (n=400); poisson 64.7% → 78.2% → 79.0%. This matches
the campaign's own published "more data makes it worse, not better" finding and extends it to the
branch level.

**Binomial is qualitatively different: its two dominant branches (`:5482` and `:5531`) trade
dominance depending on regime**, a genuine structural pattern with nothing to do with the labeling
bug:

| by `lam_sd` | `:5482` % | `:5531` % | dominant |
|---|---|---|---|
| 0.5 | 30.49 | 55.39 | `:5531` |
| 1.0 | 26.33 | 60.71 | `:5531` |
| 2.0 | 55.96 | 35.47 | `:5482` |
| 3.0 | 69.18 | 23.73 | `:5482` |

| by `n` | `:5482` % | `:5531` % | dominant |
|---|---|---|---|
| 100 | 56.54 | 23.50 | `:5482` |
| 200 | 44.92 | 48.06 | `:5531` (narrowly) |
| 400 | 35.01 | 59.92 | `:5531` |

There is a **crossover near `lam_sd` ≈ 1.5–2** (backtracking-exhaustion `:5482` becomes dominant at
high latent-signal strength) and an **opposite crossover near `n` ≈ 150–200** (`:5531`,
stagnation-with-nonzero-gradient, becomes dominant at larger `n`). Binomial's `converged` share
shrinks sharply with `n` (18.48% → 5.28% → 1.34%) — same direction as gaussian/poisson, consistent
with the "more data, less genuine convergence" pattern holding across all three families even though
its branch-level expression differs. By `aghq_k`, binomial's `:5482` share falls (54.50% → 45.42% →
36.55%) while `converged`+`adaptation_failed` rises (6.35% → 11.25% → 14.22%) as node count
increases — the same node-count effect quantified in H3, visible directly at the branch level for
binomial specifically. `eta_cap` shows no material shift for any family (binomial `:5482` 45.54% vs
45.44%, `:5531` 43.78% vs 43.87%), consistent with H1's near-null verdict.

**This is a genuinely new finding, not an artefact:** binomial's optimiser gets stuck for a
regime-dependent *mix* of reasons — sometimes exhausting backtracking with no honest descent step
available (`:5482`, dominant at high signal / small `n`), sometimes reaching a fixed adaptation mode
with a still-too-large gradient (`:5531`, dominant at low signal / large `n`) — while gaussian and
poisson show a simpler pattern: one dominant branch (`:5524`) whose share just grows monotonically
with `n`. Understanding *why* binomial's failure mode reallocates this way (an outer-optimizer /
inner-AGHQ-loop interaction question) is outside the scope of this data-only slice.

## Reproducibility — exact commands (follow-up slice)

Same connection pattern as the primary section:
```bash
SOCK=$(ls ~/.ssh/cm-*totoro* 2>/dev/null | head -1)
ssh -o ControlPath="$SOCK" -o ControlMaster=no -o BatchMode=yes -o ConnectTimeout=15 totoro '<cmd>'
```
Two scripts were `scp`'d to `~/h4_work/` on Totoro and run with
`cd ~/h4_work && OPENBLAS_NUM_THREADS=1 Rscript <script>.R`, output captured locally over SSH:
- `binomial_stall_corrected_rederivation.R` — sanity check, §1 cross-tab, §2 definitions/family
  tables, §3 headline ratios, §4 H1/H2/H3 re-derivation.
- `binomial_stall_branch_profile.R` — §5 `dcast`-based branch-share tables by `lam_sd`, `n`,
  `aghq_k`, `eta_cap`.

**Per D-50, the raw `~/h4_work/regime.csv` was never copied off Totoro** — only the summary tables
above (well under a few KB total) were brought back.

---

# D-43 disposition — the H3-inversion claim is WITHHELD

**2026-07-29.** Three fresh adversarial lenses, each instructed to REFUTE, default WITHHELD.
Result: **2 of 3 refuted, both at high confidence.** Chair's disposition: **WITHHELD.**

## What every lens agreed on (no dissent)

1. **The metric defect is real.** `dev/aghq-evidence/23-flat-regime-campaign.R:108` is
   `stalled = grepl("^STALLED", stop_reason)`. It matches only the warm-start branch
   (`R/fit-multi.R:5524`). Two other stuck-state messages were silently excluded from the count.
2. **D1 reproduces the published column bit-for-bit** — 431,985/431,985 non-NA rows, 0 mismatches,
   verified independently by two lenses. The published numbers contain no arithmetic error.
3. **The pooled D2/D3 `aghq_k` effect is ~100% binomial.** D2: binomial 99.3%, poisson 0.7%,
   gaussian **0.000000**. Gaussian is *bit-identical* across node counts (warm-stall
   42987/42987/42987 at k=9/25/51). Poisson's D3 movement has the **wrong sign**.
4. **D3's decline is a cancellation.** No-honest-descent falls 0.1822 → 0.1224 while stagnation
   rises 0.2450 → 0.2795 and adaptation-failure rises **17x** (108 → 1,865). Within binomial, ~47%
   of the D3 "improvement" is fits relabelled from one failure mode to another.

## The two load-bearing refutations

**(A) D3 is not a stall metric.** `:5531` is reachable only when `par_cur` is *not* identical to
the warm start — the optimiser moved. It sits in the same `if/else` as
`"converged (adaptation mode fixed; gradient below tolerance)"`, separated from it only by where
`max|grad|` falls relative to `1e-4`. So D3 is `1 - P(clean gradient convergence)`, a
tolerance-sensitive non-convergence rate. Using the campaign's own Materiality section (median
`par_shift` = 0.399 among non-stalled fits, only 8.5% below the 3e-4 floor), D3 must label
**157,000-168,000 fits as "stalled" that moved the estimate by a median of 0.4**. D2 is
contaminated by the same argument at 68-79%.

**(B) The design is PAIRED, so the variance used was wrong.** Every one of the 143,995 DGP keys is
fit three times, once per `aghq_k`, with `eta_max` byte-identical across all three — the simulator
never sees `aghq_k`. The unpaired `2*MCSE` comparison (the 12.5x and 12.6x ratios) is therefore the
wrong statistic. Under the correct paired test **even D1 is "significant"** (McNemar chi-square
14.5, p = 1.4e-4). At N = 144,000 significance flags every definition including the published one,
so **it cannot adjudicate H3 either way.**

## What survives, and what the campaign document should say

- **H3's verdict stands.** `:5524` is a defensible stall predicate and is precisely the pathology
  H3 was posed against: `identical(par_cur, par_start_aghq) && g_cur >= grad_tol` — AGHQ returned
  the Laplace warm start bit-for-bit at a gradient above tolerance. Adding nodes does not dissolve
  *that*.
- **The wording is over-broad and should be narrowed** from "stall rate" to **"warm-start stall
  rate"** throughout. Three stuck states exist; one was counted.
- **"Adding nodes changes nothing" is too strong.** The *converged* rate rises monotonically with
  node count (0.0259 / 0.0343 / 0.0399, a 7.5x margin) — a signal needing no stall definition at
  all. But it is family-confined: gaussian's converged count is 731/731/731, identical. The
  sentence is refuted; the verdict is not.
- **"Binomial never stalls" overstates what was measured.** Binomial never *warm-start* stalls —
  0 in 144,000, exact and flat across all 72 regime cells. It reaches other stuck states at ~89%.
  The published "family dominates" framing rests on the narrow metric and should be qualified.
- **A real, non-artefactual finding stands:** binomial's two failure branches trade dominance with
  regime (crossover near `lam_sd` ~1.5-2 and n ~150-200), while poisson and gaussian show one
  branch strengthening monotonically with n.

## Correction to the record

An earlier summary in this session stated that H3 "inverts". **It does not.** That claim was made
from a single agent's analysis before adversarial review, and the review killed it on two
independent grounds. The defect that prompted the re-derivation is real; the inference drawn from
it was not. Recorded here rather than quietly dropped.

## Not checked

No lens re-ran any fit; `regime.csv` is taken as the record of what the engine did. Node counts
outside {9, 25, 51} were not tested. One lens reported the campaign script as absent from `main` —
that is **wrong**, it was reading a different worktree; both
`dev/aghq-evidence/23-flat-regime-campaign.R` and the results document are on `origin/main`.
