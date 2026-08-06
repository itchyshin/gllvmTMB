# VA(GH) H=7 all-scalar-family campaign

**State:** Gate E is PASS (18/18) and Arc 1 is committed. Arc 2 scaffold repair
is active. Do not submit the broad Totoro or DRAC campaign until the dedicated
local tests, structured receipt/runtime chain, one-row Totoro smoke, and one-row
DRAC smoke all pass. This campaign never runs on GitHub Actions and its results
must never be uploaded as Actions artifacts.

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

At `n=120`, `p=8`, the 30-seed Totoro full ladder has 5,520 plan rows.
It is a broad failure-finding campaign, not final coverage evidence: at true
coverage 0.95 its binomial MCSE is about 0.040. The DRAC
confirmation uses 500 seeds, H=7 plus matched Laplace, and both ranks: 36,000
rows and coverage MCSE below 0.01. Family/rank verdicts and calibration labels
follow Design 110 section 6.1; no pooled pass rate may conceal a failing family.

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
The Tweedie DGP uses `tweedie::rtweedie()` when available and the equivalent
`mgcv::rTweedie(mu, p=1.5, phi=0.8)` fallback otherwise; runtime preparation
requires at least one of these suggested packages.

### P — Performance measures

For each family x estimator x H x q x n x p cell, summaries report bias
`mean(theta_hat-theta_true)`, RMSE, 95% interval coverage, mean interval width,
relative Sigma Frobenius error, failure rate, and mean wall time. MCSE is
`sd(x)/sqrt(R)` for means/bias, `sqrt(p_hat(1-p_hat)/R)` for coverage/failure
proportions, and replicate bootstrap or the standard squared-error delta
approximation for RMSE. Failed and missing fits enter failure, availability,
and unconditional-coverage denominators. Bias and RMSE use finite estimates
only and report their eligible counts explicitly.

References: Morris, White & Crowther (2019), *Statistics in Medicine* 38:
2074–2102 (ADEMP); Williams et al. (2024), *Methods in Ecology and Evolution*
15:1926–1939 (transparent simulation reporting).

## Files and use

- `run-cell.R`: writes/validates a plan, dry-runs one configuration, executes one
  plan row, or summarises immutable per-seed CSV files.
- `prepare-runtime.sh`: installs one revision-bound runtime and writes its
  checksum-bound manifest without fitting.
- `run-preflight.sh`: runs the timed VA/Laplace preflight on local/Totoro or an
  allocated DRAC compute node, never an unallocated login node.
- `launch-totoro.sh`: local/Totoro launcher, capped at 150 processes and one
  BLAS thread per worker. Default action is `dry-run`.
- `submit-drac.sh` + `drac-array.sbatch`: login-safe validation/submission and
  compute-node execution. Array ranges are derived from the plan and split into
  scheduler-sized batches; one array task executes one plan row.

Local syntax and dry-run checks (no fits):

```sh
Rscript --vanilla dev/va-gh-h7-campaign/run-cell.R --mode=dry-run \
  --cells=binomial_logit --seeds=1 --Hs=7 --qs=2 --n=120 --p=6 \
  --estimators=va
bash -n dev/va-gh-h7-campaign/*.sh dev/va-gh-h7-campaign/drac-array.sbatch
ACTION=dry-run bash dev/va-gh-h7-campaign/launch-totoro.sh
```

From a clean, committed checkout, create the structured Gate-E receipt. It binds
the revision, VA template, ordered 18-cell CSV verdict, and their checksums:

```sh
Rscript --vanilla dev/va-gh-h7-campaign/run-cell.R --mode=gate-receipt \
  --gate-report=docs/dev-log/audits/2026-08-06-va-gh-h7-gate-e.csv \
  --gate-receipt=/durable/path/GATE-E.dcf
Rscript --vanilla dev/va-gh-h7-campaign/run-cell.R --mode=verify-gate \
  --gate-receipt=/durable/path/GATE-E.dcf
```

Prepare and preflight the runtime on Totoro (or in a DRAC allocation), then
exercise exactly one immutable plan row through the full bundle path:

```sh
export CAMPAIGN_PROJECT_ROOT=/durable/path/va-gh-h7
export GATE_E_RECEIPT=$CAMPAIGN_PROJECT_ROOT/GATE-E.dcf
bash dev/va-gh-h7-campaign/prepare-runtime.sh
export VA_RUNTIME_MANIFEST=$CAMPAIGN_PROJECT_ROOT/runtime/$(git rev-parse HEAD)/runtime.dcf
export VA_PREFLIGHT_RECEIPT=$CAMPAIGN_PROJECT_ROOT/runtime/$(git rev-parse HEAD)/preflight.dcf
PREFLIGHT_CONTEXT=totoro bash dev/va-gh-h7-campaign/run-preflight.sh
ACTION=smoke bash dev/va-gh-h7-campaign/launch-totoro.sh
```

Only after the smoke bundle verifies, create/run the 30-seed Totoro plan. Use a
new durable output root for any changed condition; plans and bundles are
immutable.

```sh
ACTION=plan bash dev/va-gh-h7-campaign/launch-totoro.sh
ACTION=run CORES=100 bash dev/va-gh-h7-campaign/launch-totoro.sh
ACTION=summarise bash dev/va-gh-h7-campaign/launch-totoro.sh
```

On a DRAC login node, `submit-drac.sh` may validate and submit but never fits.
Prepare/preflight the runtime in an allocation first. `ACTION=write` prints the
exact plan-derived batched commands; `ACTION=smoke` submits task 1 only; broad
`ACTION=submit` is permitted only after that smoke bundle is checked.

## Williams et al. 11-item self-audit

| Item | Scaffold coverage |
|---|---|
| 1 aims | Primary and secondary aims above |
| 2 DGP | Equation, hierarchy, grid, seed unit, and MCSE-derived 30/500 stages above |
| 3 estimands | Truth and fitted targets above |
| 4 methods | VA and own Laplace only |
| 5 performance measures | Definitions and denominators above |
| 6 software/computing | RDS includes session info and git revision |
| 7 code availability | All scripts are in this directory |
| 8 reproducibility | Immutable plan plus one deterministic seed per row |
| 9 worked case | One-row Totoro and DRAC smoke bundles exercise the complete workflow |
| 10 complete results | Failures retained; no family pooling |
| 11 Monte Carlo uncertainty | MCSE columns produced by summarise mode |
