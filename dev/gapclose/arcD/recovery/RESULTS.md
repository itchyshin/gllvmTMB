# Arc O3: 50-seed recovery campaign for the zero-inflated families

Branch: `claude/overnight-zi-recovery`. Worktree:
`~/local-scratch/lanes/gllvmTMB-zi-recovery`. Persona: Curie (recovery/
simulation), Fisher's discipline (predeclared bars, no post-hoc widening).

This is the **owed multi-seed evidence** behind register rows FAM-21
(`zi_poisson`), FAM-22 (`zi_nbinom2`), FAM-23 (`zi_binomial`), which
Arc D1 (`dev/gapclose/arcD/D1-report.md`) established at 4-8 seeds per
family. This campaign runs **50 seeds per cell**, at three sample sizes
per family, to answer the register's actual question: **at what `n` do
the predeclared recovery bars hold for ≥ 90% of seeds** -- the number a
`covered`-tier claim needs, not a handful of seeds that happened to pass.

## Compute and provenance

Totoro (384 cores, capped at 100), `OPENBLAS_NUM_THREADS=1`,
`OMP_NUM_THREADS=1`. gllvmTMB built from **origin/main @ `5855e2ad9`**
(the merge commit for PR #1240, which shipped the zi families) into a
private library; installed version `0.7.1`; DLL SHA-256
`7d5556194d68126db4f08d0a6233568783f470f7df0fbf0ca08a515ee70602e5`.
`zi_poisson()$family` / `zi_nbinom2()$family` / `zi_binomial()$family`
all resolve. Full provenance: `PROVENANCE.txt` (this directory).

## DGP (lifted, not re-invented)

Exactly the DGP in `tests/testthat/test-zi-recovery.R`: rank-1 latent
`latent(0 + trait | site, d = 1, unique = FALSE)`, 6 traits, per-trait
zero probabilities `pi_true = c(0.1, 0.2, 0.3, 0.4, 0.15, 0.25)`,
loadings `lambda_true = c(0.5, -0.4, 0.35, -0.3, 0.4, -0.35)`. Intercepts
`beta_true = c(1.4, 1.1, 1.7, 1.2, 1.5, 1.0)` (log scale, zi_poisson/
zi_nbinom2) or `c(0.3, -0.2, 0.5, -0.4, 0.2, 0.1)` (logit scale,
zi_binomial, N=10 trials). zi_nbinom2 additionally: `phi_true = c(4, 5,
3, 6, 4, 5)`. Fits use `gllvmTMBcontrol(se = FALSE)`, matching the
shipped test (so `pd_hessian` is genuinely **not computed** in this
campaign, not a failure -- `sdreport` is skipped for speed exactly as
the test does).

Script: `campaign.R` (single-fit CLI, kept for one-off reruns) and
`run_grid.R` (the driver actually used: loads the package once, forks
450 jobs via `parallel::mclapply`).

## Grid

| Family | n_site cells | seeds | fits |
|---|---|---|---|
| zi_poisson | 150, 200, 400 | 1:50 | 150 |
| zi_nbinom2 | 200, 400, 800 | 1:50 | 150 |
| zi_binomial (N=10) | 150, 250, 500 | 1:50 | 150 |
| **Total** | | | **450** |

## D-139 pre-run timing

One seed (9001, outside the campaign's 1:50 set) per family at its
**largest** n, single fit, timed on Totoro:

| Family | n (largest) | seconds/fit |
|---|---|---|
| zi_poisson | 400 | 0.759 |
| zi_nbinom2 | 800 | 3.759 |
| zi_binomial | 500 | 1.115 |

**Projected total (conservative, using each family's worst-case n for
every cell in that family):** 150 fits x 0.759s + 150 x 3.759s + 150 x
1.115s = **845s (14.1 min) serial**. Under `mclapply(mc.cores = 100)`
this collapses to a handful of parallel batches (450 fits / 100 cores)
-- projected wall clock well under 1 minute, confirmed by measurement
below. This is far under the 30-minute D-139 line, so the full grid was
launched directly after the pre-run, no separate approval sought.

**Measured:** all 450 fits completed; the write-timestamps of the 450
output files span **6.8 seconds** (the compute itself; total session
wall time including SSH round trips, package build, and aggregation was
a few minutes).

## Bug caught and fixed before reporting

The first pass computed `max_gradient` by calling `fit$tmb_obj$gr(par)`
with `par = fit$tmb_obj$env$last.par.best` (the **full** joint
fixed+random parameter vector, length 418 for the n=400 zi_poisson
fixture) against a `gr()` that expects only the **outer** (fixed-effect)
parameters (length 18) once `random=` is set. This silently produced a
meaningless number (e.g. 181.6) rather than erroring. Fixed by reading
the value the package itself already computes and validates,
`fit$fit_health$max_gradient` / `fit$fit_health$pd_hessian` (confirmed
on the same fixture: `max_gradient = 0.00378`, matching
`fit$opt$par`-based `gr()` exactly; `pd_hessian = NA` because
`se = FALSE` skips `sdreport`). The full 450-fit grid was rerun with the
fix; point estimates and errors were unaffected by the bug (only the two
diagnostic fields were wrong), but the corrected run is what this report
uses. The superseded run is kept on Totoro
(`~/gllvmtmb-zi-recovery/out_v1_badgrad/`) for traceability only.

## Per-cell results (50 seeds each)

Predeclared bars (from `test-zi-recovery.R`): intercepts max abs error
< 0.15; `zi` max abs error < 0.08 (zi_poisson/zi_binomial) or < 0.10
(zi_nbinom2); loadings relative Frobenius < 0.25; zi_nbinom2 additionally
median (not max) per-trait `phi` relative error < 0.30.

| Family | n | conv=0 | ALL bars hold (int+zi+frob) | median int_err | p90 int_err | median zi_err | p90 zi_err | median rel_frob | p90 rel_frob |
|---|---|---|---|---|---|---|---|---|---|
| zi_poisson | 150 | 94% | **54%** | 0.103 | 0.163 | 0.055 | 0.088 | 0.212 | 0.305 |
| zi_poisson | 200 | 98% | **82%** | 0.088 | 0.134 | 0.040 | 0.057 | 0.148 | 0.211 |
| zi_poisson | 400 | 100% | **98%** | 0.062 | 0.092 | 0.033 | 0.045 | 0.124 | 0.169 |
| zi_nbinom2 | 200 | 100% | **36%** | 0.127 | 0.186 | 0.057 | 0.083 | 0.235 | 0.346 |
| zi_nbinom2 | 400 | 100% | **84%** | 0.086 | 0.118 | 0.041 | 0.060 | 0.172 | 0.254 |
| zi_nbinom2 | 800 | 100% | **98%** | 0.064 | 0.095 | 0.031 | 0.044 | 0.111 | 0.157 |
| zi_binomial | 150 | 100% | **48%** | 0.108 | 0.172 | 0.060 | 0.095 | 0.168 | 0.251 |
| zi_binomial | 250 | 98% | **92%** | 0.109 | 0.143 | 0.046 | 0.073 | 0.152 | 0.222 |
| zi_binomial | 500 | 100% | **100%** | 0.068 | 0.106 | 0.039 | 0.054 | 0.092 | 0.127 |

zi_nbinom2's additional `phi` bar (median relative error < 0.30 across
the 6 traits, per seed):

| n | median(seed medians) | fraction of seeds with median < 0.30 | mean # traits/seed > 30% |
|---|---|---|---|
| 200 | 0.299 | 50% | 3.04 / 6 |
| 400 | 0.223 | 74% | 2.02 / 6 |
| 800 | 0.159 | 98% | 1.16 / 6 |

Per-metric breach counts (of 50 seeds), showing which bar actually drives
each cell's failures:

| Family | n | fail conv | fail int (>=0.15) | fail zi | fail frob (>=0.25) |
|---|---|---|---|---|---|
| zi_poisson | 150 | 3 | 10 | 13 | 6 |
| zi_poisson | 200 | 1 | 5 | 2 | 2 |
| zi_poisson | 400 | 0 | 0 | 1 | 0 |
| zi_nbinom2 | 200 | 0 | 16 | 0 | 24 |
| zi_nbinom2 | 400 | 0 | 1 | 0 | 7 |
| zi_nbinom2 | 800 | 0 | 0 | 0 | 1 |
| zi_binomial | 150 | 0 | 10 | 7 | 13 |
| zi_binomial | 250 | 1 | 3 | 0 | 2 |
| zi_binomial | 500 | 0 | 0 | 0 | 0 |

## Honest verdict, per family

**zi_poisson.** The register/test currently quote **n = 200** (raised
from 150 in Arc D1's review R6, verified there across 8 seeds). At 50
seeds, n = 200 holds all three bars simultaneously in only **82%** of
seeds -- below the 90% line a `covered` claim needs. **n = 400** clears
it at **98%**. The 8-seed check that motivated n = 200 was not wrong on
its own terms (all 8 of *those* seeds did pass), but 8 seeds cannot
detect an ~18% base failure rate; this is exactly the generalisation gap
the register's own text should now name.

**zi_nbinom2.** The register currently quotes **n = 400** (chosen because
`phi` is not identifiable at n = 150). At 50 seeds, n = 400 holds the
three point-estimate bars in **84%** of seeds and the `phi` median-<30%
bar in **74%** of seeds -- both below 90%. **n = 800** clears both
(**98%** and **98%**). This is a larger jump than the other two families
because zi_nbinom2 carries an extra identifiability burden (per-trait
dispersion under a shared random effect, the same small-sample
phenomenon Arc D1 already documented for Gamma/Beta/student).

**zi_binomial.** The register currently quotes **n = 250** (raised from
150 in review R6). At 50 seeds, n = 250 holds all three bars in **92%**
of seeds -- **above** the 90% line, though with a thin 2-seed margin (1
non-convergence + a couple of borderline breaches). n = 500 is
comfortably clear at **100%**. Of the three families, zi_binomial's
existing register number is the only one this larger sample actually
sustains.

## Comparison with GLLVM.jl

**CORRECTED 2026-09-03 after the GLLVM.jl lane replied.** This section
first reported that no ADEMP or recovery campaign existed on the Julia
side. That was wrong, and the way it was wrong is worth recording: the
search found dated August after-task reports
(`docs/dev-log/after-task/2026-08-09-zip-x-engine.md:40`,
`...-zip-x-identity.md:38`, `...2026-08-14-zinb-x-engine.md:54`) whose
"Not OK: ADEMP/coverage" lines were that day's honest status, and read
them as a live ledger. They are not; that lane does not rewrite past
reports. **A narrow search returning nothing is not evidence of absence.**

The Julia campaign DID run: Totoro, 2026-09-02 11:57-14:07Z, 240 chunks,
**6,000 fits, 0 errors**, summarised in
`docs/dev-log/core070/zi-ademp-recovery-findings.md` (commit `14364043`)
on branch `codex/core070-aghq-20260830`, with raw per-fit CSVs under
`docs/dev-log/core070/zi-ademp-out/`. It is not on their `origin/main`
because nothing from that programme lands until their draft PR #277
merges -- which is why a `git show origin/main:` search could not see it.

**The two campaigns vary different axes, so they corroborate by regime,
not cell-for-cell.** Theirs: p in {5, 25} x n in {50, 200} x 500 seeds,
intercept-only zero inflation by construction, dispersion `r = 2` shared
(their parameterisation), estimands beta_z / beta_c / Lambda Lambda';
ours: p = 6 x n in {150 ... 800} x 50 seeds, per-trait `phi_nbinom2`.
They varied the number of responses; we varied the number of units.

Where they agree, and it is the conclusion that matters:

1. **Recovery holds only once n is large relative to p.** Their
   convergence collapses at (p=25, n=50) -- zip 35.0%, zinb 70.0% -- and
   recovers at n=200 (96.2% / 98.6%); ours holds for >=90% of seeds only
   at n=400 (zi_poisson) and n=800 (zi_nbinom2) with p = 6. Same shape,
   two implementations, two grids.
2. **The zinb dispersion problem is small-sample identifiability, not
   zero-inflation.** They reach this independently and tie it to the same
   class we do -- a "healthy" per-trait NB2 fixture sitting at the Poisson
   limit (`docs/dev-log/core070/t14-nb2-wald-nan-diagnosis.md`). Our
   register text made this claim from the R side alone; it now has
   independent support from a separate codebase.
3. **zi_binomial is the well-behaved one of the three** in both: 100%
   convergence in all four of their cells, and the only family here whose
   shipped test size already clears a 90%-of-seeds standard.

Neither campaign evaluated standard errors or interval coverage, so
neither supports any interval claim. If a same-DGP comparison is wanted
later, their worker is `tools/core070_zi_ademp_chunk.jl`
(argv: family p n seed_start seed_end outdir) and runs unchanged under a
Slurm array -- that would be a new arc, with its own estimate, not a
re-reading of either result.

(Separately, GLLVM.jl's ZINB parameterises dispersion as one shared
scalar `r`, unlike gllvmTMB's per-trait `phi_nbinom2` -- already recorded
as a deliberate divergence in Arc D1's capability ledger.)

## Proposed register wording

**Do not edit the register rows** (per instructions) -- proposed text
only, for Rose review before the maintainer applies it.

**FAM-21 (zi_poisson):** replace "n=200 ... re-verified at seeds
202/303/404" with: *"Known-DGP recovery (rank-1 latent, 6 traits):
50-seed campaign (dev/gapclose/arcD/recovery/RESULTS.md) shows the three
predeclared bars (intercepts < 0.15, zi < 0.08, loadings rel. Frobenius
< 0.25) hold simultaneously in 98% of seeds at n=400, but only 82% at
n=200 -- the n=200 number quoted from Arc D1's 8-seed check does not
generalise to a 90%-of-seeds standard. **n should be raised to 400** for
any `covered`-tier claim; the shipped test still uses n=200 as a fast
CI smoke check, not evidence of 90%-level recovery."*

**FAM-22 (zi_nbinom2), the wording asked for verbatim:** *"Known-DGP
recovery (rank-1 latent, 6 traits): 50-seed campaign
(dev/gapclose/arcD/recovery/RESULTS.md) shows intercepts/zi/loadings
hold simultaneously in 84% of seeds at n=400 and 98% at n=800; the
per-trait dispersion bar (median relative phi error < 0.30) holds in 74%
of seeds at n=400 and 98% at n=800. **n=400 (the current test/register
number) does not reach a 90%-of-seeds standard on either bar; n=800
does, on both.** The underlying mechanism is unchanged from Arc D1: a
small-sample per-trait dispersion identifiability issue shared with
Gamma/Beta/student, not zero-inflation-specific."*

**FAM-23 (zi_binomial):** replace the recovery sentence with: *"50-seed
campaign (dev/gapclose/arcD/recovery/RESULTS.md): the three bars hold
simultaneously in 92% of 50 seeds at n=250 (the current test/register
number) and 100% at n=500 -- n=250 clears a 90%-of-seeds standard, with
a thin margin (4 of 50 seeds fail: 1 non-convergence, a few borderline
breaches)."*

## What this campaign does NOT establish

- No calibrated intervals -- point-estimate recovery only, as before.
- `phi_relerr` uses the median-of-6-traits rule from the shipped test;
  it does not characterise which specific trait(s) run away, only that
  ~1-3 of 6 do at every n tested (consistent with Arc D1's seed-303
  finding, not a new discovery).
- `pd_hessian` is `NA` throughout (`se = FALSE`), by design, matching the
  shipped test -- this campaign did not check Hessian PD-ness at all.
- Runtime medians (0.8-4.2s/fit) are single-thread Totoro numbers, not a
  claim about typical user hardware.
- Seeds 1:50 are a fresh, independent draw from Arc D1's 101/202/303/404
  -- no seed overlap, so this is genuinely new evidence, not a
  re-verification of the same four seeds at larger n.

## Files in this directory

- `campaign.R` -- single (family, n, seed) fit CLI (kept for reruns/spot
  checks).
- `run_grid.R` -- the actual driver used (450-fit `mclapply` grid).
- `summary/per_trait_results.csv` -- 2,700 rows (450 fits x 6 traits).
- `summary/per_seed_summary.csv` -- 450 rows (one per fit).
- `summary/per_cell_summary.csv` -- 9 rows (one per family x n_site cell).
- `PROVENANCE.txt` -- build SHAs, DLL hash, file manifest.
