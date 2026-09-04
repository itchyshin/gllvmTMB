# Arc F: 50-seed recovery campaign for ordinal_logit and censored_poisson

Branch: `claude/arcF-recovery-20260904`. Worktree:
`~/local-scratch/lanes/gllvmTMB-arcF`.

This is the **owed multi-seed evidence** behind register rows FAM-24
(`ordinal_logit`) and FAM-25 (`censored_poisson`), which currently quote
3 seeds (ordinal_logit) and 4 seeds (censored_poisson). This campaign
runs **50 seeds per cell**, at three sample sizes per family, to answer
the register's actual question: **does the shipped test size generalise
to a ≥ 90%-of-seeds standard, and if not, what size does?** This mirrors
Arc D's O3 campaign for the zero-inflated families
(`dev/gapclose/arcD/recovery/RESULTS.md`), which found the shipped sizes
did NOT generalise for two of three zi families. **This campaign finds
the opposite for both families here** -- see verdicts below.

## Compute and provenance

Totoro (384 cores, capped at 100), `OPENBLAS_NUM_THREADS=1`,
`OMP_NUM_THREADS=1`, attached through the existing ControlMaster socket
(no fresh login, no Duo prompt). gllvmTMB built from **origin/main @
`c9ce86489`**; installed version `0.7.1`; DLL SHA-256
`17a443a8a771142416fb0ff1b569ed24e24b823633ebf3f1e619064aa943723a`.
Full provenance: `PROVENANCE.txt` (this directory).

## DGPs (lifted, not re-invented)

**ordinal_logit** -- exactly the DGP in `tests/testthat/test-ordinal-logit.R`
(the `.ordlogit_*` block): 4 traits, `K = 4`, cutpoints
`taus = c(0, 0.7, 1.4)`, 2 replicate draws per unit x trait, rank-1
shared `latent(0 + trait | unit, d = 1)`, intercepts
`alpha = c(0.2, -0.1, 0.15, 0)`, loadings
`lambda = c(1.6, 1.3, -1.2, 1.1)`, formula
`value ~ 0 + trait + latent(0 + trait | unit, d = 1)`,
`family = ordinal_logit()`. Predeclared bars: median relative loading
error `< 0.25`, max relative loading error `< 0.40`, max absolute
cutpoint error `< 0.30`.

**censored_poisson** -- exactly the DGP in
`tests/testthat/test-censored-poisson.R` (the known-DGP recovery block):
6 traits, `beta = c(1.4, 1.1, 1.7, 1.2, 1.5, 1.0)`,
`lambda = c(0.5, -0.4, 0.35, -0.3, 0.4, -0.35)`, right-censoring limit
`C = 6`, rank-1 latent `latent(0 + trait | site, d = 1, unique = FALSE)`,
formula `cbind(y, censored) ~ 0 + trait + latent(0 + trait | site, d = 1,
unique = FALSE)`, `family = censored_poisson()`. Predeclared bars: max
absolute intercept error `< 0.15`, loadings relative Frobenius `< 0.25`.

**Deliberate deviation:** the shipped `censored_poisson` test fits with
`control = gllvmTMBcontrol(se = FALSE)`, which skips `sdreport()` and so
cannot report Hessian PD-ness. This campaign uses the package's own
DEFAULT control (`se = TRUE`) for **both** families, so `pd_hessian` is
reported throughout. Point estimates are unaffected by `se`; only
whether `sdreport()` runs.

Scripts: `campaign.R` (single-fit CLI, kept for one-off reruns),
`run_grid.R` (the driver actually used: loads the package once, forks
300 jobs via `parallel::mclapply`), `aggregate.R` (RDS -> CSV summaries).

## Grid

| Family | size cells | seeds | fits |
|---|---|---|---|
| ordinal_logit (n_unit) | 300 (shipped), 600, 1200 | 1:50 | 150 |
| censored_poisson (n_site) | 200 (shipped), 400, 800 | 1:50 | 150 |
| **Total** | | | **300** |

## D-139 pre-run timing vs. measured

Pre-run (one seed, 9001, outside 1:50, at each family's largest size,
single fit, on Totoro):

| Family | size (largest) | seconds/fit |
|---|---|---|
| ordinal_logit | 1200 | 1.965 |
| censored_poisson | 800 | 3.761 |

Both **faster** than the task brief's local single-core numbers at
those sizes (19.3 s and 5.4 s) -- Totoro's per-core throughput exceeds
the local machine's here. The D-139 "> ~3x slower, stop" trigger never
came close to firing; the full grid launched directly after the
pre-run.

**Measured for the full 300-fit grid:** all 300 output files present;
file-timestamp span **8 seconds** wall clock. Sum of per-fit runtimes
(the serial-time equivalent) = **666.7 core-seconds (~0.185
core-hours)** -- well under the task brief's ~2,600 core-second / 0.72
core-hour estimate.

## Per-cell results (50 seeds each)

Predeclared bars: ordinal_logit -- median relative loading `< 0.25`, max
relative loading `< 0.40`, max absolute cutpoint `< 0.30`.
censored_poisson -- max absolute intercept error `< 0.15`, loadings
relative Frobenius `< 0.25`.

| Family | size | conv=0 | PD Hessian | ALL bars hold (joint) | fraction, bar 1 | fraction, bar 2 | fraction, bar 3 |
|---|---|---|---|---|---|---|---|
| ordinal_logit | 300 | 100% | 100% | **100%** | 100% (median rel. loading) | 100% (max rel. loading) | 100% (max abs. cutpoint) |
| ordinal_logit | 600 | 100% | 100% | **100%** | 100% | 100% | 100% |
| ordinal_logit | 1200 | 100% | 100% | **100%** | 100% | 100% | 100% |
| censored_poisson | 200 | 100% | 100% | **96%** | 98% (max int. error) | 98% (rel. Frobenius) | -- |
| censored_poisson | 400 | 100% | 100% | **100%** | 100% | 100% | -- |
| censored_poisson | 800 | 100% | 100% | **100%** | 100% | 100% | -- |

Medians / p90 of each metric (from `summary/per_cell_summary.csv` and
`summary/per_cell_censored_poisson_extra.csv`):

| Family | size | median (bar 1) | p90 (bar 1) | median (bar 2) | p90 (bar 2) | median (bar 3) | p90 (bar 3) | median runtime (s) |
|---|---|---|---|---|---|---|---|---|
| ordinal_logit | 300 | 0.072 | 0.121 | 0.130 | 0.215 | 0.144 | 0.211 | 1.10 |
| ordinal_logit | 600 | 0.052 | 0.081 | 0.101 | 0.153 | 0.125 | 0.180 | 1.55 |
| ordinal_logit | 1200 | 0.036 | 0.065 | 0.072 | 0.135 | 0.086 | 0.149 | 2.32 |
| censored_poisson | 200 | 0.069 (int.) | 0.119 | 0.133 (frob.) | 0.197 | -- | -- | 1.65 |
| censored_poisson | 400 | 0.053 | 0.077 | 0.102 | 0.139 | -- | -- | 2.56 |
| censored_poisson | 800 | 0.038 | 0.062 | 0.070 | 0.100 | -- | -- | 4.13 |

Per-metric breach counts (of 50 seeds; ordinal_logit had zero breaches
of any kind at any size):

| Family | size | fail conv | fail bar 1 | fail bar 2 | fail bar 3 |
|---|---|---|---|---|---|
| ordinal_logit | 300 | 0 | 0 | 0 | 0 |
| ordinal_logit | 600 | 0 | 0 | 0 | 0 |
| ordinal_logit | 1200 | 0 | 0 | 0 | 0 |
| censored_poisson | 200 | 0 | 1 (max int. err) | 1 (rel. Frobenius) | -- |
| censored_poisson | 400 | 0 | 0 | 0 | -- |
| censored_poisson | 800 | 0 | 0 | 0 | -- |

At `n_site = 200`, the two breaches are **distinct seeds** (seed 35
breaches max intercept error at 0.158 with `rel_frob = 0.069`, well
inside its own bar; seed 17 breaches relative Frobenius at 0.266 with
`max_int_err = 0.090`, well inside its own bar) -- both converge cleanly
(`convergence = 0`, PD Hessian) and both breaches are borderline (0.008
and 0.016 over their respective 0.15 / 0.25 lines), not gross failures.
This gives a joint pass rate of 48/50 = 96%.

## Honest verdict, per family

**ordinal_logit.** The register/test currently quote **n_unit = 300**
(3 checked seeds). At 50 seeds, n_unit = 300 holds all three predeclared
bars simultaneously in **100%** of seeds, with comfortable margins
(median relative loading error 0.072 vs. the 0.25 bar; median max
cutpoint error 0.144 vs. the 0.30 bar). Doubling or quadrupling `n_unit`
(600, 1200) also holds at 100%, with tighter margins as expected, but
adds nothing the 300-seed level did not already establish. **The shipped
test size generalises comfortably** to a 90%-of-seeds standard -- unlike
the zi-family precedent, there is no gap between the 3-seed check and
the 50-seed evidence here.

**censored_poisson.** The register/test currently quote **n_site = 200**
(4 checked seeds, all passing). At 50 seeds, n_site = 200 holds both
predeclared bars simultaneously in **96%** of seeds (48/50) -- above the
90% line, with the two failures being distinct, borderline, fully
converged seeds rather than a systematic pattern. `n_site = 400` and
`n_site = 800` both clear 100%. **The shipped test size generalises**;
the earlier 4-seed check (101/202/303/404, all passing) was not a lucky
draw -- it reflects a genuinely high pass rate, not an unrepresentative
sample of a lower true rate (contrast with zi_poisson's 8-seed check,
which happened to catch all-passing seeds despite an underlying ~18%
failure rate at the same n).

## Contrast with Arc D's zi-family finding

Arc D's O3 campaign (`dev/gapclose/arcD/recovery/RESULTS.md`) found the
shipped test sizes did NOT generalise to 90% for zi_poisson (82% at
n=200) or zi_nbinom2 (84%/74% at n=400), and recommended raising `n` for
any `covered`-tier claim. **This campaign's finding is the opposite for
both families here**: the shipped sizes clear 96-100%. This is not a
contradiction between the two campaigns -- it reflects that different
families carry different small-sample identifiability burdens (zi's
per-trait dispersion / zero-probability parameters vs. ordinal_logit's
and censored_poisson's simpler intercept + rank-1 loading structure), a
mechanism Arc D's own report already names for the zi/Gamma/Beta family
class. No generic "50 seeds always finds a gap" claim would survive this
comparison.

## What this campaign does NOT establish

- No calibrated intervals -- point-estimate recovery only, matching the
  shipped tests' own scope.
- One DGP per family, one latent rank (`d = 1`) -- no sweep over trait
  count, cutpoint spacing (ordinal_logit), or censoring fraction
  (censored_poisson; median censored fraction here is ~0.26 throughout,
  matching the shipped test's ~26%).
- `pd_hessian` IS reported here (unlike Arc D's zi campaign, which left
  it `NA` under `se = FALSE`) -- both families report `pd_hessian = TRUE`
  in 100% of converged fits across all six cells, with the deliberate
  `se = TRUE` deviation documented above.
- Runtime medians (1.1-4.1 s/fit) are single-thread Totoro numbers, not
  a claim about typical user hardware.
- Seeds 1:50 are independent of the shipped tests' own seeds
  (20260903/2/3 for ordinal_logit; 101/202/303/404 for censored_poisson)
  -- no seed overlap, so this is genuinely new evidence.
- `ordinal_logit`'s `d = 1` shared-trait latent and `censored_poisson`'s
  `unique = FALSE` rank-1 latent are each the ONE structure tested; no
  augmented-slope, spatial, phylogenetic, or missing-data variant was
  run.

## Proposed register wording

Rows stay `partial` -- this campaign strengthens, but does not by itself
promote, either row (that call is the maintainer's). Proposed text for
Rose/maintainer review, to be appended to the existing FAM-24/FAM-25
recovery sentences (not a replacement -- the existing 3-/4-seed sentences
stay as the original characterisation; this is additive evidence):

**FAM-24 (ordinal_logit), addition:** *"A 50-seed campaign at n_unit =
300/600/1200 (dev/gapclose/arcF/recovery/RESULTS.md) confirms the
three predeclared bars (median rel. loading < 0.25, max rel. loading
< 0.40, max abs. cutpoint < 0.30) hold simultaneously in 100% of seeds
at ALL THREE sizes, including the shipped n_unit = 300 -- the 3-seed
check generalises; no larger n is needed for a 90%-of-seeds standard."*

**FAM-25 (censored_poisson), addition:** *"A 50-seed campaign at
n_site = 200/400/800 (dev/gapclose/arcF/recovery/RESULTS.md) shows the
two predeclared bars (max abs. intercept error < 0.15, loadings rel.
Frobenius < 0.25) hold simultaneously in 96% of seeds at the shipped
n_site = 200 (48/50; two distinct, borderline, fully-converged failures)
and 100% at n_site = 400/800 -- the shipped size clears a 90%-of-seeds
standard; the earlier 4-seed check was representative, not a lucky
draw."*

## Files in this directory

- `campaign.R` -- single (family, size, seed) fit CLI (kept for
  reruns/spot checks).
- `run_grid.R` -- the actual driver used (300-fit `mclapply` grid).
- `aggregate.R` -- RDS -> CSV aggregation (per-seed and per-cell).
- `summary/per_seed_summary.csv` -- 300 rows (one per fit).
- `summary/per_cell_summary.csv` -- 6 rows (one per family x size cell).
- `summary/per_cell_censored_poisson_extra.csv` -- 3 rows, censored_poisson's
  own bar columns kept out of the shared table.
- `PROVENANCE.txt` -- build SHAs, DLL hash, timing, file manifest.
