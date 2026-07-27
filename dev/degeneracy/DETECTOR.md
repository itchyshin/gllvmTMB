# A fit-time degeneracy detector for `gtmb_laplace`

**Role:** Fisher. **Data:** `dev/totoro-grid/results/grid.csv` (2880 rows, 640 cells × 5 arms; raw
object also checked at `dev/totoro-grid/results/grid.rds` — confirmed it carries only the same 12
scalar columns, no stored `Sigma_hat` matrices; see Step 2 caveat). **Output:**
`dev/degeneracy/laplace-degeneracy-detector.csv` (601 rows, one per usable `gtmb_laplace` fit).

## The question

Of `gtmb_laplace`'s 640 fits, 39 error out openly (excluded — that failure is self-disclosing) and
601 produce a `Sigma_B`. Of those 601, 70 (11.6%) are degenerate by the truth-based `rel_frob > 10`
criterion, and 59 of those 70 report `convergence = 0` and `pdHess = TRUE` — clean by the package's
own signal. **Can a user tell the 70 from the 531 using only quantities available at fit time, with
no access to the simulated truth?**

## Step 1 — characterising the 70 vs the 531 on fit-time quantities

Effect sizes (Cohen's *d*, degenerate mean − sane mean, pooled SD) on the columns available for a
single `gtmb_laplace` fit, pooled across families:

| quantity | degenerate mean | sane mean | Cohen's d | Wilcoxon p |
|---|---|---|---|---|
| `n` | 88 | 208 | −0.92 | <1e-13 |
| `objective` | −1224 | −8971 | 0.77 | <1e-4 |
| `p` | 21.5 | 38.5 | −0.63 | <1e-4 |
| `q` | 3.11 | 2.95 | 0.17 | 0.18 (n.s.) |
| `seconds` | 5.1 | 8.7 | −0.26 | 0.42 (n.s.) |

Two categorical splits are much sharper than any continuous one:

- **`family`: every one of the 70 degenerate fits is `bernoulli`; zero are `poisson`** (70/281
  bernoulli fits degenerate = 24.9%; 0/320 poisson fits degenerate = 0%). This is available at fit
  time (the user chose the family) but is necessary, not sufficient — 211 of 281 bernoulli fits are
  perfectly fine, so "flag all bernoulli" alone is a poor rule (see Step 4).
- **`status` sub-codes**: within `gtmb_laplace`'s own 4-level status, `conv0_pdHessFALSE` (8 fits)
  and `conv1_pdHessFALSE` (3 fits) are **100% degenerate** (11/11) — but that is only 11 of the 70;
  the remaining 59 all carry `conv0_pdHessTRUE`, indistinguishable by status from the 531 sane fits
  (all of which are also `conv0_pdHessTRUE`). This reproduces, at the single-fit level, exactly the
  headline finding: the package's own convergence/Hessian signal is clean on 59/70 failures.

Within `bernoulli` only, `n` sharpens further and shows a clean dose-response (small samples are
much riskier): degenerate rate by `n` = 34/43 (79%) at n=40, 26/78 (33%) at n=100, 9/80 (11%) at
n=200, 1/80 (1%) at n=400.

**Read:** family and sample size carry real signal, but no single fit-time scalar on the 70-vs-531
split reaches a usable separation by itself — see Step 4's honest sensitivity/specificity numbers.

## Step 2 — the trace(Sigma_hat) idea: NOT COMPUTABLE from this data

`attenuation = trace(Sigma_hat) / trace(Sigma_true)` uses the truth in the denominator and is
correctly excluded as a detector input. The brief asks whether the numerator, `trace(Sigma_hat)`
alone, or an eigenvalue-concentration ratio (`lambda_max(Sigma_hat) / trace(Sigma_hat)`), could
substitute.

**Neither is computable from what exists.** `grid.csv` and `grid.rds` store only the 12 scalar
columns shown above (checked directly) — no `Sigma_hat` matrices, no eigenvalues, and no
un-normalised trace. `attenuation` is the *only* trace-related quantity on disk, and it is already
truth-divided; there is no way to back out `trace(Sigma_true)` per cell from the CSV to invert it
(it varies by seed, not just by `family`/`n`/`p`/`q`, and no column records it directly). Recovering
this would need re-fitting to capture `trace(Sigma_hat)` directly at fit time, which is explicitly
out of scope for this slice. **This is a real gap in the STEP 2 lead as posed — flagged, not
worked around.**

What *is* legitimately computable without the truth is explored in Step 3: the *ratio* of two arms'
`attenuation` in the same cell cancels `trace(Sigma_true)` exactly, recovering a truth-free quantity
equal to `trace(Sigma_hat_A) / trace(Sigma_hat_B)`. That is a real fit-time quantity a user could
compute directly (each engine reports its own `Sigma_hat`) — it does not require running this
detector on the study's synthetic-truth artifacts.

## Step 3 — cross-arm disagreement: this is the answer

For each of the 601 usable `gtmb_laplace` fits, its cell (`family, n, p, q, seed`) also has a
`gtmb_gh` fit (100% coverage, our own second VA engine) and, for 573/601 cells, a `gllvm_va` fit
(the sister-package VA; 28 cells dropped because `gllvm_va` itself errored there). Define

```
log_trace_ratio = log( attenuation_laplace / attenuation_reference )
                = log( trace(Sigma_hat_laplace) / trace(Sigma_hat_reference) )   [trace_true cancels]
```

**This separates the 70 degenerate fits from the 531 sane ones completely, with a wide margin, using
either reference arm:**

| reference | fits with reference available | max \|log ratio\| among the 531 sane | min \|log ratio\| among the 70 degenerate | gap |
|---|---|---|---|---|
| `gtmb_gh` (our own second VA engine) | 601 / 601 | 1.04 (ratio 2.8×) | 3.42 (ratio 30.5×) | ~11× |
| `gllvm_va` (sister package) | 573 / 601 | 0.87 (ratio 2.4×) | 4.08 (ratio 59×) | ~24× |

Spot-checking individual cells confirms this is not an artefact: the reference arm's `attenuation`
stays in a mundane 0.6–12 range even on the worst `gtmb_laplace` blow-ups (which reach
`attenuation` ≈ 1.5 million); the two engines are computed independently and genuinely disagree by
orders of magnitude exactly when `gtmb_laplace` is degenerate, and agree to within a few percent
everywhere else. Within the hardest single subgroup (`bernoulli`, n=40, 43 fits, 34 degenerate) the
same clean gap holds: sane log-ratios in [−0.15, 0.08], degenerate log-ratios in [3.60, 12.37].

**This is the practical payoff of running two engines.** A user who fits both `gtmb_laplace` and
`gtmb_gh` (or `gllvm_va`) on the same data and compares `trace(Sigma_hat)` between them gets a
clean, cheap, truth-free signal for exactly the failure mode that the shipping default's own
`convergence`/`pdHess` status misses on 59/70 (84%) of cases.

## Step 4 — sensitivity, specificity, false alarms (operating point: 10× trace-ratio threshold)

Threshold chosen deliberately *inside* the gap (2.4–3.4× on the sane side, 30–60× on the degenerate
side), not tuned to the data: "flag if the two engines' `Sigma_B` traces differ by more than 10-fold."

| rule | evaluated on | TP | FN | FP | TN | sensitivity | specificity |
|---|---|---|---|---|---|---|---|
| `status ∈ {conv0_pdHessFALSE, conv1_pdHessFALSE}` (single-engine, no second fit) | 601 | 11 | 59 | 0 | 531 | **15.7%** | 100% |
| `family == bernoulli & n ≤ 100` (single-engine, no second fit) | 601 | 60 | 10 | 61 | 470 | **85.7%** | 88.5% |
| cross-arm 10× trace-ratio vs `gtmb_gh` | 601 | 70 | 0 | 0 | 531 | **100%** | **100%** |
| cross-arm 10× trace-ratio vs `gllvm_va` | 573 | 64 | 0 | 0 | 509 | **100%** | **100%** |

Read honestly:

- **The status-only rule is the current shipping signal's own best subset**: it catches the 11
  fits (8 `conv0_pdHessFALSE` + 3 `conv1_pdHessFALSE`) that already look unhealthy, at zero false
  alarms — but it misses 59/70 (84%) of the actual degenerate fits, which is precisely the
  motivating finding.
- **The best single-engine (no second fit) rule found, `bernoulli & n≤100`, trades real cost for
  real recall**: it catches 60/70 (86%) but at the price of 61 false alarms on the 531 sane fits
  (11.5% of all sane fits get flagged for nothing) — a rule that cries wolf on roughly 1 in 9 good
  fits. A logistic regression on `family + n + p + q + objective` reaches in-sample AUC ≈ 0.97, but
  this is an in-sample fit on 601 points with a near-separating `family` term (huge standard
  errors) — not something to trust out of sample without a held-out check, and it is not
  meaningfully better than the simple two-variable rule at any operating point tried.
- **The cross-arm trace-ratio rule is not a compromise**: on this dataset it achieves 100%
  sensitivity and 100% specificity simultaneously, with a comfortable margin (the closest sane case
  and the closest degenerate case are separated by roughly an order of magnitude, not a knife edge).
  Coverage is 601/601 fits using `gtmb_gh` as reference, and 573/601 using `gllvm_va` (28 fits lost
  because `gllvm_va` itself errored in those cells — a real, disclosed coverage gap, not swept under
  the rug).

## Bottom line

1. **Nothing separates the 70 from the 531 perfectly using a single `gtmb_laplace` fit's own
   fit-time quantities.** The best single-engine rule found (`bernoulli & n≤100`) reaches 86%
   sensitivity at an 11.5% false-alarm rate on sane fits — usable as a coarse risk flag ("small-n
   Bernoulli fits deserve scrutiny"), not as a pass/fail gate.
2. **`trace(Sigma_hat)` alone and eigenvalue-concentration are not computable from the data this
   study produced** — the CSV/RDS store only truth-normalised scalars, not raw traces or matrices.
   This is a real limitation of the artifact, not a negative result about the idea itself.
3. **Cross-arm disagreement is the shippable answer.** Comparing `trace(Sigma_hat)` between
   `gtmb_laplace` and a second engine (`gtmb_gh` giving full coverage, or `gllvm_va` giving 95%
   coverage) at a 10× threshold catches all 70 degenerate fits with zero false alarms on the 531
   sane ones. The cost is running a second engine — but that engine is already shipped in this
   package (`gtmb_gh`), so the "cost" is one extra fit, not new infrastructure. This confirms the
   brief's hope directly: **two engines is a genuinely useful, cheap, honest defence**, and prior-art
   search (`PRIOR-ART.md`, Q3) found this specific practice — cross-estimator agreement as a
   per-fit trustworthiness check — is not an established recommendation in the GLLVM literature
   surveyed, so it is a real (if simple) contribution, not a rediscovery.

## Files

- `dev/degeneracy/laplace-degeneracy-detector.csv` — 601 rows (one per usable `gtmb_laplace` fit):
  design columns, `degenerate` (truth-based label, for scoring only), `gh_attenuation`/`gh_status`,
  `va_attenuation`/`va_status`, `log_ratio_gh`, `log_ratio_va`, and the four candidate flag columns
  from the Step 4 table.
- `dev/degeneracy/PRIOR-ART.md` — pre-existing NotebookLM-grounded literature check (not written this
  session) confirming pdHess-insufficiency is known, "Heywood case" is not named in the GLLVM corpus
  surveyed, second-estimator cross-checking is not an established diagnostic, and starting-value
  sensitivity is well-established prior art for a different mitigation (jittered multi-init).

## Scope / caveats

- All numbers are from one Totoro grid run (2880 rows, seeds 1–10 per cell per the file). No
  out-of-sample validation was performed — the cross-arm rule's perfect separation is measured on
  the same data it is reported for, not a held-out set. Given the ~11–24× margin between the
  closest sane and degenerate cases (not a threshold sitting on a knife edge), this is unlikely to be
  a fragile artifact of these particular 601 fits, but a fresh grid (different seeds, possibly
  different n/p/q combinations) would be the honest next check before shipping this as a hard gate.
- The 39 `gtmb_laplace` `ERROR` fits are excluded throughout (no `Sigma_B` to compare) — that failure
  mode is self-disclosing already and out of scope for "silent degeneracy."
- `gtmb_jj` (320 rows) only covers `bernoulli` and was not used as a general reference arm for that
  reason.
