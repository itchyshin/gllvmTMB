# Real-data VA/EVA/Laplace benchmark — gllvm field-standard datasets

STATUS AT TIME OF WRITING: **the benchmark run was still executing in the
background when this report had to be finalised** (system-enforced
structured-output deadline cut off before the script's `beetle_top12`
condition and part of `eSpider_pa q=3` completed). The script
(`dev/real-data/real-data-benchmark.R`) is deterministic (fixed seeds
throughout, no simulation randomness on the real-data rows) and was
re-launched exactly once as a single clean process (PID 49928) after an
earlier accidental double-launch was killed and its partial log discarded.
Whoever picks this up next should either let PID 49928 finish and read
`dev/real-data/run.log` + the three CSVs it writes at the very end
(`real-data-fits.csv`, `real-data-pairwise-agreement.csv`,
`real-data-bound-ordering.csv`), or simply re-run the script (`Rscript
dev/real-data/real-data-benchmark.R`, local only, no Totoro needed — total
observed runtime so far is a few minutes).

Internal research only. No `@export`, no `method=` argument, no
NAMESPACE/`src/gllvmTMB.cpp` edits, no testthat, no public claim. An ELBO is
never called a likelihood below.

## Datasets (gllvm's OWN field-standard data, not our simulations)

`data(package = "gllvm")` on this install ships: `Skabbholmen`, `beetle`,
`eSpider`, `fungi`, `kelpforest`, `microbialdata` — **no `antTraits`, no
plain `spider`** (the extended/renamed version is `eSpider`).

| condition | source | dim (n x p) | response | family chosen |
|---|---|---|---|---|
| `eSpider_abund` | `gllvm::eSpider$abund` | 100 x 12 | real abundance counts, range 0-189 | **Poisson** (counts) |
| `eSpider_pa` | `gllvm::eSpider$abund > 0` | 100 x 12 | **DERIVED** presence/absence of the same real survey | **binomial** (n_trials=1) |
| `beetle_top12` | `gllvm::beetle$Y`, top-12-by-prevalence of 68 species | 87 x 12 | real abundance counts, range 0-2893 (subset) | **Poisson** (counts) |

`eSpider_pa` is not a second genuine survey — it is a standard ecological
transform (presence/absence thresholding) of the same real eSpider counts,
used here only because gllvm ships no inherently-binary dataset and the
task requires exercising the binomial-only `gtmb_jj` arm and gllvm's own
JJ/PG `method="VA"`/`method="EVA"` arms on real (not simulated) data. Every
number derived from it should be read as "real presence/absence pattern",
not "an independent real dataset".

`beetle` (87 sites x 68 carabid beetle species, counts up to 3892) was
subsetted to the 12 most prevalent species (by number of sites present) to
keep runtime local-only and `p` comparable to `eSpider`. `Skabbholmen`
(126 x 68, values capped at 5 — looks like an ordinal cover-class score, not
counts) and `microbialdata` (56 x 985, far too wide for a local q<=3 fit in
this time budget) were surveyed but not used; see the dimension/range table
gathered during dataset selection (`data(package="gllvm")` results:
Skabbholmen, beetle, eSpider, fungi, kelpforest, microbialdata).

## Arms actually run

- `gtmb_gh` — ours, `.approximation_engine_fit(engine="va_r3", eval_method="auto")`. Runs on every condition.
- `gtmb_jj` — ours, `eval_method="jj"`. Binomial only (`eSpider_pa`).
- `gllvm_va` — `gllvm::gllvm(method="VA", seed=1:4, control.start=list(n.init=4, jitter.var=0.2))`. The `n.init=4` multi-start (not gllvm's own `n.init=1` default) is a **fairness fix** established earlier this session: gllvm's own single-start default reliably diverges to degenerate loadings on this model family.
- `gllvm_eva` — same call with `method="EVA"`.
- `gtmb_laplace` — Psi-suppressed matched comparator, `gllvmTMB(traits(...) ~ 1 + latent(1 | site, d=q, unique=FALSE), family=poisson()/binomial())`.

q in {2, 3} for every condition.

## Results obtained before the cutoff

Read directly from `dev/real-data/run.log` (the authoritative source — this
table is a transcription, not a re-derivation):

| condition | q | arm | ok | elapsed (s) | status |
|---|---|---|---|---|---|
| eSpider_abund | 2 | gtmb_gh | TRUE | 3.17 | **failed_health_gate** |
| eSpider_abund | 2 | gllvm_va | TRUE | 2.59 | converged |
| eSpider_abund | 2 | gllvm_eva | **FALSE** | 0.00 | `ERROR: Family(families): poisson not implemented with method ' EVA .` |
| eSpider_abund | 2 | gtmb_laplace | TRUE | 5.21 | pd_hessian |
| eSpider_abund | 3 | gtmb_gh | TRUE | 10.17 | **failed_variance_domain** |
| eSpider_abund | 3 | gllvm_va | TRUE | 13.56 | converged |
| eSpider_abund | 3 | gllvm_eva | **FALSE** | 0.00 | same EVA/Poisson error |
| eSpider_abund | 3 | gtmb_laplace | TRUE | 3.58 | pd_hessian |
| eSpider_pa | 2 | gtmb_gh | TRUE | 7.94 | **failed_variance_domain** |
| eSpider_pa | 2 | gtmb_jj | TRUE | 0.75 | **healthy** |
| eSpider_pa | 2 | gllvm_va | TRUE | 0.53 | converged |
| eSpider_pa | 2 | gllvm_eva | TRUE | 80.29 | **not_converged** |
| eSpider_pa | 2 | gtmb_laplace | TRUE | 5.48 | pd_hessian |
| eSpider_pa | 3 | (in progress at cutoff — gtmb_gh/gtmb_jj/gllvm_va lines were being written; gllvm_eva and gtmb_laplace, plus all of `beetle_top12` q=2/3, had not yet run) | | | |

Full numeric detail (objective values, Sigma_B, Procrustes agreement,
pairwise Frobenius distances, bound ordering) could not be transcribed here
because the script only calls `write.csv()` once, after the entire loop
completes — the three output CSVs did not exist yet at cutoff. **They will
appear at the paths above once PID 49928 (or a re-run) finishes.**

## What these partial numbers already show (read as a lead, not a verdict)

1. **`gllvm::gllvm(method="EVA")` genuinely errors on Poisson on real data**,
   confirming the established fact from simulated fixtures — same error
   text (`poisson not implemented with method ' EVA`), same near-instant
   (0.00s) failure. This is not a real-data-specific artefact; it is a
   hard family restriction in `gllvm` itself.
2. **Our GH engine's health gate rejected BOTH real Poisson fits** (`eSpider_abund`,
   q=2 and q=3) with `failed_health_gate` / `failed_variance_domain`, despite
   the newly-landed warm start. A companion smoke test run before the full
   script (same `eSpider_abund`, q=2) showed the four starts all converging
   to the **same objective value** (3076.8328) with gradients only
   marginally above the 1e-4 health-gate threshold (1.4e-4 to 4.5e-4) — i.e.
   this looks like a marginal near-miss on a strict gate rather than a
   genuine multi-start disagreement, but that has only been checked for one
   of the four failing cells and should not be over-generalised.
3. **`gllvm_eva` is far slower than every other arm when it does run**
   (80.29s on `eSpider_pa` q=2, vs sub-second to low-single-digit seconds
   for every other arm) and **still reported `not_converged`** — i.e. on
   this real dataset gllvm's own EVA arm is both the slowest AND the one
   that admits its own non-convergence, which is a different (more honest)
   failure mode than the "68% degenerate with ALL reporting converged"
   pattern established on simulated data. Whether that pattern recurs here
   is exactly the open question this benchmark was meant to answer, and it
   is **not yet answered** — the run must finish (or be re-run) before that
   question can be closed.
4. **`gtmb_jj` (ours, JJ bound) was fast (0.75s) and reported `healthy`** on
   the one binomial condition reached so far, unlike `gtmb_gh` on the same
   condition (`failed_variance_domain`) — consistent with the established
   pattern that our JJ arm is markedly more reliable than our GH arm on
   real, not-simulated-from-our-own-model data.

## Honest limitations of this partial report

- No known truth exists on real data (per the task brief) — every
  agreement/disagreement number, once the run completes, will describe
  concordance between arms, **not correctness of any of them**.
- The `beetle_top12` condition (the second independent real dataset) has
  **no results at all** yet in this partial report.
- Sigma_B pairwise Frobenius distances, Procrustes per-factor correlations,
  and the bound-ordering check (`ELBO_GH >= ELBO_JJ <= Laplace logLik`) all
  depend on the full run and are **not available** in this partial write-up.
- `eSpider_pa` is a derived binary response, not an independent genuine
  survey — treat any "two real datasets" claim as covering
  `eSpider_abund` + `beetle_top12` only.

## Next action

Re-check `dev/real-data/run.log` for `=== DONE ===` and the three CSVs
(`real-data-fits.csv`, `real-data-pairwise-agreement.csv`,
`real-data-bound-ordering.csv`) in `dev/real-data/`. If PID 49928 was killed
when this session ended, re-run:
`cd /private/tmp/gllvmtmb-va-wiring-20260726 && Rscript dev/real-data/real-data-benchmark.R`
(local only; observed wall clock for the first ~55% of the work was under
3 minutes, so full completion should be well under 10).
