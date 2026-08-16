# Slice-1 recovery campaign — multinomial animal_latent / kernel_latent

Scripts preparing the Slice-1 recovery campaign for the approved
multinomial-structured arc: does `multinomial()` (family_id 16) recover a
known `(K-1)x(K-1)` among-category covariance `V` when the phylogenetic
correlation structure is supplied via `animal_latent()` (pedigree/A — sugar
over `phylo_latent`) or `kernel_latent()` (dense `K` — same engine, Design 65
C1 phylo-equivalence), rather than via `phylo_latent()`'s own `tree =`
argument (already admitted, Design 84).

**Admission status as of 2026-08-16:** `R/fit-multi.R`'s multinomial fence
currently admits fixed effects, `phylo_latent()`, and a shared `latent()`
only. `animal_latent()`/`kernel_latent()` on a multinomial trait will error
until Slice 1's admission lands (a separate lane in this worktree). These
scripts are written ahead of that landing so the campaign can run the moment
it does; they are not run to completion here.

## Files

- `dgp-multinomial-structured.R` — `dgp_multinomial_structured()`: simulates
  one dataset (tree, true `V`, softmax draw). Pure R, no gllvmTMB dependency;
  self-checks when run directly (`Rscript dgp-multinomial-structured.R`).
- `campaign-s1-animal-kernel-latent.R` — fits both keywords, three modes.
- `pass-criteria-s1.md` — the pre-registered (DRAFT) pass/fail block.
- `results/` — `--mode full` writes `s1-results-<timestamp>.rds` (raw
  per-seed list) and `s1-summary-<timestamp>.csv` (one row per fit) here.

## Running

```bash
# 1. Timing fit FIRST (D-139): 1 seed, 1 fit, prints elapsed time.
Rscript campaign-s1-animal-kernel-latent.R --mode timing

# 2. Smoke gate: 2 seeds x 2 keywords, prints str() of each result.
Rscript campaign-s1-animal-kernel-latent.R --mode smoke

# 3. Full campaign: 20 seeds x 2 keywords, parallel::mclapply.
OPENBLAS_NUM_THREADS=1 CAMPAIGN_CORES=4 \
  Rscript campaign-s1-animal-kernel-latent.R --mode full
```

### Totoro run line

```bash
OPENBLAS_NUM_THREADS=1 CAMPAIGN_CORES=20 \
  Rscript campaign-s1-animal-kernel-latent.R --mode full
```

`GLLVMTMB_DIR` may be set to point at a specific package checkout/worktree;
it defaults to `.` (run from the package root). `CAMPAIGN_CORES` defaults to
4 if unset; keep it ≤150 on Totoro (D-143 — Totoro is shared).

## D-139 rule (estimate before you run)

State a time guesstimate before any run over ~30 min. Concretely for this
campaign: run `--mode timing` first and read its printed elapsed time and
its naive `elapsed * 40 / 60` projection for the full 40-fit grid (20 seeds
x 2 keywords). If that projection is ≤30 min, `--mode full` may just be run.
If it projects >30 min, do NOT run `--mode full` directly — instead run a
small pre-run test (e.g. `--mode smoke`, or a short seed subset), report the
timing and any early red flags (non-convergence, rail rate), and get
Shinichi's approval before committing the full run. A run that overruns its
own estimate stops and re-reports rather than continuing quietly.

### D-139 estimate (measured 2026-08-16, Slice 1 admission)

`--mode timing` (n_sp = 60, animal_latent, 1 fit): **elapsed 1.08 sec**,
convergence = 0, pdHess = TRUE. `--mode smoke` (n_sp = 60, 2 seeds x 2
keywords, 4 fits): elapsed 1.10 / 5.48 / 0.37 / 0.37 sec (all convergence = 0,
pdHess = TRUE); animal_latent and kernel_latent gave numerically identical
`V_hat`/`rho_hat` per seed, as expected from the engine-identical route.
Seed 1 collapsed near-zero (`V_hat` ~1e-12, a degenerate fit) and seed 2
railed (`rho_hat` = 1, |rho_hat| > 0.99) — both are exactly the kind of
early red flag the pass-criteria block (`pass-criteria-s1.md`) is designed to
count, not evidence against running `--mode full`.

Projected full-campaign wall-clock: `--mode full` uses **n_sp = 800** — the
size the pre-registered pass criteria are calibrated on (the 2026-07-17
phylo-multinomial spike: N=800 recovers rho 0.6 → ~0.45; N=250 was
underpowered; do not lower n_sp without recalibrating the bands). Scaling
from the smoke-mode mean (~1.83 sec/fit at n_sp = 60), 40 fits / 20 cores =
2 sequential batches:
- Linear n_sp scaling (800/60 ≈ 13.3x): ~1.83 x 13.3 x 2 ≈ **49 sec**.
- Cubic n_sp scaling (dense n_sp x n_sp Cholesky dominates,
  (800/60)^3 ≈ 2370x): ~1.83 x 2370 x 2 ≈ **2.4 h** worst case.

**MEASURED (2026-08-16): one fit at n_sp = 800 took 65.6 sec** (animal_latent,
seed 1, conv = 0, PD Hessian) — so the D-139 estimate is settled: 40 fits ≈
**~2.2 min on 20 cores / ~8 min on 6 cores**, far under the 30-min line;
the full campaign runs LOCALLY, no Totoro needed. Honest observation from
that same fit: it railed at rho_hat = −1.0 (true 0.6) with clean
convergence and a PD Hessian — the exact silent-tail the pre-registered
rail-rate criterion counts separately; one seed is not an aggregate.
`--mode full` stays gated on `pass-criteria-s1.md`'s DRAFT status (needs
Shinichi's sign-off) and was **not run** as part of Slice 1.

## Extraction convention

Both keywords are extracted the same way:

```r
extract_Sigma(fit, level = "phy", part = "shared", link_residual = "none")
```

`animal_latent(species, d, A, unique = FALSE)` desugars to
`phylo_rr(species, vcv = A)` at parse time (same engine as `phylo_latent()`),
so its Sigma surfaces at `level = "phy"` automatically.
`kernel_latent(species, K, d, name = "phy", unique = FALSE)` is passed
`name = "phy"` explicitly in this campaign so that its Sigma surfaces at the
SAME extractor level (`fit$kernel_levels` maps the `name` argument to an
internal level that defaults to `"phy"`) — this is a deliberate campaign-side
choice, not a package default, so that one extraction call works for both
keywords. `part = "shared"` returns the loadings-only `Lambda Lambda^T`
(equal to `part = "total"` here since both keywords are fit with
`unique = FALSE`, i.e. no diagonal Psi companion).
