# Gate 3 — early-abort check, 2026-07-31

The pre-registration's smoke discipline says read the FIRST cells early and abort the instant
output is empty, NA or broken, rather than waiting for the grid to finish before learning it
failed. This is that check, at 24 of 2,160 cells.

## Status by arm — 72 fits

| arm | ok | guard_rejected | nonconvergence | error |
|---|---:|---:|---:|---:|
| `ml_laplace` | 24 | 0 | 0 | 0 |
| `va_gh` | 20 | 2 | 2 | 0 |
| `va_jj` | 24 | 0 | 0 | 0 |

**No errors anywhere.** Every arm produces finite output. The exact status vocabulary is working
(no label in which a failure string contains a success substring).

## The specific risk this check existed to catch

`.va_r3_check_separation()` landed in this lane and the campaign is **Bernoulli**, which is exactly
where separation bites. A guard that mass-rejected would silently gut the denominator.

**It fires on 2 of 72 fits (2.8%)** — a sensible rate, and only on `va_gh`. Not a mass rejection.
The guard is doing its job rather than eating the campaign.

## Early κ, for orientation only — NOT a result

Median `kappa = tr(Sigma_hat)/tr(Sigma_true)` over the 68 `ok` rows so far:
`ml_laplace` **5.793** · `va_gh` **4.885** · `va_jj` **2.595`.

**Do not read anything into this.** Cells complete cheapest-first, so this is dominated by small `p`
and small `n` — historically the worst regime for every arm (the 2026-07-26 grid has `gtmb_laplace`
at 2088 and `gtmb_gh` at 4.302 at n=40). The cells where the arms actually separate — n=400, p=80 —
are the slowest and land last. JJ being lowest here is consistent with its known contraction, not
evidence of quality.

**Verdict: continue.** Nothing here justifies aborting.
