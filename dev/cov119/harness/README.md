# Design 119 §4 coverage campaign — gaussian wave 1 (`predict_missing(se = TRUE)`)

**Status: DRAFT harness. Nothing here has been executed. No fit has been run.**
This directory is a scratchpad draft written READ-ONLY against the repo; the
`predict_missing(fit, type, se = TRUE)` interface it codes against
(`se_confidence`, `se_prediction` columns at masked rows, gaussian only) is
being wired by a parallel builder and **must exist in the installed package
before the pre-run can even be attempted**.

## What this campaign decides

Design 119 §4 (branch `claude/predict-missing-se-20260815`,
`docs/design/119-predict-missing-uncertainty.md`): interval claims die
without pre-registered coverage evidence. The gaussian `se =` surface lands
as register status `heuristic_unvalidated`; **this campaign is the evidence
that either flips it to `calibrated` (gaussian only) or leaves it where it
is. No pass = no claim, no export advertising, no NEWS line.** Over-coverage
fails too — the repo's own lesson is that over-coverage is a calibration
failure, not a safe error.

## Estimands (Design 119 §2 — never conflated)

For each designed-masked cell `(u, t)` under `response = "include"`,
gaussian identity link (`mu = eta`):

| interval    | target      | indicator (per cell)                                  |
|-------------|-------------|-------------------------------------------------------|
| confidence  | `mu_ut` (= `eta_ut`) | `abs(eta_true - est) <= z * se_confidence`   |
| prediction  | `y_ut`      | `abs(y_true  - est) <= z * se_prediction`             |

Nominal levels and frozen critical values: **90% (z = 1.6449)** and
**95% (z = 1.96)**. Aggregation: per-cell indicator → per-trait mean →
unweighted per-fit mean (one CSV row per fit) → per-cell-of-the-grid mean
over 400 replicates.

## Grid (4 cells × 400 reps = 1,600 fits)

Arc0 DGP, reused verbatim (`dev/missing-accuracy-dgp.R`): gaussian,
`n_units = 50 × p_traits = 25`, `q_true = 2`, anisotropic per-trait residual
sd; fitted loadings-only (the deliberate anisotropy mismatch is inherited —
the intervals must survive it or fail honestly). Mechanisms: `mcar05`,
`mcar20`, `trait_clustered`, `unit_clustered`. Deterministic seeds
`119000 + 1000*mech + rep`. Failure-inclusive: every attempt writes a row;
errors, non-convergence and non-finite/non-positive SEs are counted, never
dropped (a bad SE at a cell scores as NON-coverage).

## Pass bands (pre-registered, applied to `cov119-summary.csv`)

Per cell of the grid, per estimand, per nominal level:

1. **Convergence floor:** `conv_rate >= 0.95`. Below that the cell is an
   automatic FAIL regardless of coverage (failure-inclusive discipline).
2. **Coarse binomial screen** (MC-SE at 400 reps): mean per-fit coverage in
   - 95% nominal: **[0.928, 0.972]**  (0.95 ± 2·√(.95·.05/400))
   - 90% nominal: **[0.870, 0.930]**  (0.90 ± 2·√(.90·.10/400))
3. **Operative gate:** `|mean coverage − nominal| ≤ 2 × empirical MCSE`
   (the `mcse*` columns; per-fit aggregation makes the binomial band
   miscalibrated when cells within a fit are correlated, which they are —
   the empirical band is the one that decides). Both directions: too high
   fails exactly like too low.
4. Also reported, must not contradict: the failure-inclusive coverage
   (`fi_cov*`, failed fits scored 0) must stay inside band (2) — with the
   convergence floor met it can differ from converged-only by ≤ 5 points.

**Decision rule:** all 4 cells pass (1)–(4) at BOTH levels for BOTH
estimands → register row `calibrated` for **gaussian only** (poisson and
every other family stay `heuristic_unvalidated` until their own wave).
Any cell fails → status unchanged, the failing cell's mechanism is named in
the register note, and the fix is a route change (Design 119 §3 R1-joint →
R1-quad → R2), not a re-run of the same estimator at higher precision.

## Cost estimate (D-139 — stated before anything runs)

Arc0 measured ~5 s/fit for fit + predict (n=50×p=25, includes an oracle
refit this campaign does not do). The `se = TRUE` path adds sdreport work;
assume **3× → ~15 s/fit**.

- **1,600 fits × 15 s ≈ 6.7 core-hours** (lower bound if se is cheap:
  1,600 × 5 s ≈ 2.2 core-hours).
- Wall at `COV119_CORES=40`: **~10 min** (lower bound ~3.5 min).
- Pre-run (8 fits, single core): ~1–2 min.

The 3× is an **assumption, not a measurement** — the pre-run exists to
replace it. If the pre-run projects > 2× this estimate, stop and re-report
before launching (D-139: a run that overruns its estimate stops).

## Running it on Totoro

Totoro: no GPU, no queue, **shared — stay ≤ 150 cores (D-143); 40 here**.
Use the existing ControlMaster socket (`~/.ssh/cm-*totoro*`); no fresh
login needed.

### 1. Stage the package (from the Mac)

```sh
# Source of truth: the pm-se worktree on branch claude/predict-missing-se-20260815
# (confirm the se = TRUE contract has LANDED on the branch first).
rsync -a --delete --exclude '.git' \
  /private/tmp/gllvmtmb-pm-se/ \
  snakagaw@totoro.biology.ualberta.ca:~/cov119-src/gllvmTMB/

# Stage the harness (this directory)
rsync -a cov119-dgp.R cov119-driver.R cov119-prerun.R README.md \
  snakagaw@totoro.biology.ualberta.ca:~/cov119/
```

### 2. Install (on Totoro)

```sh
ssh snakagaw@totoro.biology.ualberta.ca   # via the cm- socket
cd ~/cov119-src
R CMD build gllvmTMB --no-build-vignettes
R CMD INSTALL gllvmTMB_*.tar.gz
# Sanity: the contract must be present before anything runs
Rscript -e 'stopifnot("se" %in% names(formals(gllvmTMB::predict_missing)))'
```

### 3. D-139 pre-run (MANDATORY, single core)

```sh
cd ~/cov119
export OPENBLAS_NUM_THREADS=1
export COV119_REPO_ROOT=~/cov119-src/gllvmTMB
Rscript cov119-prerun.R | tee cov119-prerun.log
```

Report the per-fit seconds, the projected core-hours, and the 8 per-fit
coverage values to Shinichi. **Do not proceed without approval.**

### 4. Full campaign

```sh
cd ~/cov119
export OPENBLAS_NUM_THREADS=1
export COV119_REPO_ROOT=~/cov119-src/gllvmTMB
export COV119_CORES=40
nohup Rscript cov119-driver.R > cov119-driver.log 2>&1 &
tail -f cov119-driver.log      # chunk progress lines every ~2*cores fits
```

`cov119-cells.csv` is appended after every parallel chunk (parent-only
writes). A crash or kill loses at most one chunk; **re-running the same
command resumes**, skipping seeds already in the CSV.

### 5. Retrieve (from the Mac)

```sh
rsync -a snakagaw@totoro.biology.ualberta.ca:~/cov119/cov119-cells.csv \
         snakagaw@totoro.biology.ualberta.ca:~/cov119/cov119-summary.csv \
         snakagaw@totoro.biology.ualberta.ca:~/cov119/cov119-driver.log \
         <local-results-dir>/
```

Apply the pass bands above to `cov119-summary.csv`; the write-up goes to
`dev/missing-accuracy/` alongside the Arc0 RESULTS.md pattern, and the
register row moves (or does not) in `docs/design/35-validation-debt-register.md`
only on a full pass.

## Files

| file              | role                                                        |
|-------------------|-------------------------------------------------------------|
| `cov119-dgp.R`    | sources the Arc0 DGP + mask generators; truth helpers; frozen campaign constants |
| `cov119-driver.R` | 4 cells × 400 reps, chunked `mclapply`, crash-safe/resumable CSV, per-cell summary |
| `cov119-prerun.R` | D-139 pre-run: 2 reps × 4 cells, single core, prints s/fit + coverage indicators |
| `README.md`       | this file: staging, pass bands, decision rule                |
