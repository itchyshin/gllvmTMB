# auto-d-recovery: verdict (lane-internal; no public claim)

Date 2026-09-30. Branch `claude/lane-auto-d-recovery`. Design: `design.md` (ADEMP; verdict rule fixed before any results). Full table: `results/recovery-table.md` and `.csv`. Pre-run: `prerun.md`. Ridge diagnostic: `ridgeoff.md`.

## What was measured
How often `select_lv()` with the default criterion `bic_sites`, which is what `gllvmTMB(..., latent(d = "auto"))` runs, picks the true latent rank. 4 families x n_units {50, 150, 400} x n_traits {8, 16} x true d {1, 2, 3}; candidates d = 1..5. 13,789 datasets: 200 per cell, except NB at n = 400, which ran 100 per cell by Shinichi's choice (97 to 99 landed; 11 long fits were stopped at the overrun line). `gllvmTMB(d = "auto")` matched `select_lv()$selected_d` on 4 of 4 checks; the recomputed pick matched the package's on every dataset. 0 degenerate redraws. 9 datasets had no eligible fit (3 binomial, 6 NB); they count as not correct. 282 CPU-hours on Totoro, package built from commit e68391469.

DGP in one line: loadings and scores N(0, 1), intercepts uniform, Gaussian noise sd 0.5, NB size 2, Bernoulli with one trial. Every number below is conditional on that signal strength.

## Verdict per family (rule: `bic_sites` P(correct) >= 0.90 in every cell with n_units >= 150)

| family | verdict | lowest P(correct), n >= 150 | lowest anywhere | note |
|---|---|---|---|---|
| Gaussian | recommended | 0.995 | 0.985 (n 50, p 8, d 3) | consistent with the Julia twin (0.948, different grid) |
| Poisson | recommended | 0.980 | 0.970 (n 50, p 8, d 3) | consistent with the Julia twin (0.999, different grid) |
| NB2 | recommended with a stated floor: 16 traits | 0.737 (n 400, p 8, d 3) | 0.385 (n 50, p 8, d 3) | every p = 16 cell >= 0.928; with p = 8 it fails at d = 3 at every n |
| Binomial (Bernoulli) | not recommended | 0.000 (n 150, p 8, d 3) | 0.000 | under-selects; AIC beats `bic_sites` by more than 3 MCSE in 8 of 18 cells |

MCSE is at most 0.035 per cell at 200 reps and at most 0.051 at 97 reps.

## Findings worth Shinichi's attention
1. **Binomial rank selection is conservative by design of the data, not by a bug.** Rank 1 is recovered almost always; ranks 2 and 3 are missed unless n and p are both large (n 400, p 16: 0.975 at d = 2, 0.780 at d = 3). The loading ridge is not the cause: switching it off makes recovery worse, because a third of the fits run away (`ridgeoff.md`). The binary data simply carry little information about a second factor at these sizes (n 150, p 8, d 2: median log-likelihood gain about 8 for 7 parameters, against a `bic_sites` penalty of about 17.5).
2. **AIC is the better binomial criterion here and the worse NB criterion.** On binomial data AIC wins in 8 cells; on NB it is wrong far more often, and worse as n grows (n 400, p 8, d 1: AIC 0.52 against `bic_sites` 0.99). A single default across families cannot be best for both. Whether `d = "auto"` should pick the criterion by family is a design decision for Shinichi, not something this lane changes.
3. **NB with few traits over-selects at large n.** At n = 400, p = 8, d = 3, `bic_sites` picks too high a rank in 21% of datasets and too low in 4%. The other NB failures are under-selection at small n. Candidate cause, not tested: the size-2 NB variance is absorbed by an extra factor when p is small. Treat it as a lead for a follow-up.
4. **Cost is almost all NB.** NB n = 400, p = 16 datasets take 10 to 60 minutes each for the d = 1..5 sweep; Gaussian takes seconds. A user running `d = "auto"` on a large NB dataset should expect a long wait, and the documentation should say so.

## Bugs
None found. The unpenalised log-likelihood falling with d on ridged binomial fits (for example n 400, p 8, d 3: median -2090.9 at d = 3, -2092.6 at d = 4) is documented behaviour (`R/select-lv.R:571-586`). No reproducer needed.

## What this does NOT cover
- True d = 0 (never a candidate) and true d > 3.
- Other signal strengths, NB sizes, Gaussian noise levels, or multi-trial binomial.
- Models with covariates, row effects, `unique = TRUE`, or structured latent terms (`d = "auto"` refuses those).
- The 11 NB n = 400 datasets stopped at the overrun line, and 144 ridge-off datasets at n = 400, p = 16.
- `require_converged = TRUE` and ridge scales other than 2 and off.
