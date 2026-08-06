# VA(GH) H=7 all-scalar-family campaign

**State:** INCOMPLETE Arc 2 scaffold, frozen at the 2026-08-06 context boundary.
**Do not submit or execute it.** An adversarial audit found launch, runtime,
receipt, plan, and scoring defects; repair began but was interrupted before
functional validation. Gate E has not been recorded as PASS. The next task must
finish and re-audit the scaffold before any Totoro/DRAC launch. This campaign
never runs on GitHub Actions and its results must never be uploaded as Actions
artifacts.

This directory implements the approved Arc 2 boundary in Design 110. It covers
the 18 scalar family/link cells, compares VA with this package's own matched
Laplace estimator, runs the H ladder `5, 7, 9, 15, 61`, and keeps every failed
replicate. Multinomial and other non-scalar likelihoods are excluded.

## ADEMP contract

### A — Aims

The primary aim is to determine, separately for each scalar family/link cell,
whether VA with H=7 has acceptable recovery and uncertainty behaviour relative
to known truth and the package's matched Laplace route. Secondary aims are to
measure H-ladder stability at q=2 and q=5, VA-Wald fixed-effect coverage,
rotation-invariant Sigma recovery, latent variational-posterior-SD calibration,
failure rate, and wall time.

### D — Data-generating mechanism

For unit i and trait t,

```
u_i ~ N_q(0, I_q)
eta_it = beta_t + lambda_t' u_i
y_it ~ F_cell(eta_it, family parameters)
Sigma_true = Lambda Lambda'
```

`Lambda` uses the engine's triangular identifying orientation. The default grid
has 18 family/link cells, H in `{5,7,9,15,61}`, q in `{2,5}`, estimators in
`{va,laplace}`, and 30 seeds per cell. `n` and `p` are explicit plan columns and
CLI arguments. Each plan row is one independent replicate; DRAC runs exactly
one row (hence one seed) per array task.

The 30-seed Totoro run is a broad failure-finding campaign, not final coverage
evidence: at true coverage 0.95 its binomial MCSE is about 0.040. The DRAC
confirmation should use at least 500 seeds for coverage MCSE <= 0.01, and 1000
for <= 0.007. Family verdicts remain separate; no pooled pass rate may conceal a
failing family.

### E — Estimands

Each RDS stores realised `beta_true`, `Lambda_true`, `Sigma_true`, and latent
scores. Each CSV stores replicate-level quantities from which MCSEs can be
computed: beta errors and VA-Wald coverage/width, relative Frobenius Sigma error,
Sigma diagonal RMSE, latent posterior-SD mean and empirical interval coverage,
convergence/health flags, gradient diagnostic, and elapsed seconds.

### M — Methods

The two fitted estimators are `integration="va"` with explicit GH order and the
package's own `integration="laplace"`. The latter is the primary fitted
comparator; `gllvm` is deliberately absent. H is retained in Laplace plan rows
only to keep paired output keys; it does not alter the Laplace fit.

### P — Performance measures

For each family x estimator x H x q x n x p cell, summaries report bias
`mean(theta_hat-theta_true)`, RMSE, 95% interval coverage, mean interval width,
relative Sigma Frobenius error, failure rate, and mean wall time. MCSE is
`sd(x)/sqrt(R)` for means/bias, `sqrt(p_hat(1-p_hat)/R)` for coverage/failure
proportions, and replicate bootstrap or the standard squared-error delta
approximation for RMSE. Failures are never dropped from denominators.

References: Morris, White & Crowther (2019), *Statistics in Medicine* 38:
2074–2102 (ADEMP); Williams et al. (2024), *Methods in Ecology and Evolution*
15:1926–1939 (transparent simulation reporting).

## Files and use

- `run-cell.R`: writes/validates a plan, dry-runs one configuration, executes one
  plan row, or summarises immutable per-seed CSV files.
- `launch-totoro.sh`: local/Totoro launcher, capped at 150 processes and one
  BLAS thread per worker. Default action is `dry-run`.
- `drac-array.sbatch`: DRAC array template. Depot, R library, plan, and results
  must all resolve under `/project`; one array task executes one plan row.

Local syntax and dry-run checks (no fits):

```sh
Rscript --vanilla run-cell.R --mode=dry-run --cell=binomial_logit \
  --seed=1 --H=7 --q=2 --n=30 --p=6 --estimator=va
bash -n launch-totoro.sh
bash -n drac-array.sbatch
ACTION=dry-run bash launch-totoro.sh
```

After Gate E only, create a receipt containing exactly `PASS`, then build an
immutable plan and execute it:

```sh
printf 'PASS\n' > /durable/path/GATE-E.receipt
GATE_E_RECEIPT=/durable/path/GATE-E.receipt ACTION=plan \
  OUTPUT_DIR=/durable/path/results bash launch-totoro.sh
GATE_E_RECEIPT=/durable/path/GATE-E.receipt ACTION=run CORES=100 \
  OUTPUT_DIR=/durable/path/results bash launch-totoro.sh
```

Do not overwrite a plan or result. To change a condition, use a new output
directory. Each result is written to a temporary file and renamed only after a
complete CSV/RDS pair exists.

## Williams et al. 11-item self-audit

| Item | Scaffold coverage |
|---|---|
| 1 aims | Primary and secondary aims above |
| 2 DGP | Equation, hierarchy, grid, and seed unit above |
| 3 estimands | Truth and fitted targets above |
| 4 methods | VA and own Laplace only |
| 5 performance measures | Definitions and denominators above |
| 6 software/computing | RDS includes session info and git revision |
| 7 code availability | All scripts are in this directory |
| 8 reproducibility | Immutable plan plus one deterministic seed per row |
| 9 worked case | Not applicable to this internal validation campaign |
| 10 complete results | Failures retained; no family pooling |
| 11 Monte Carlo uncertainty | MCSE columns produced by summarise mode |
