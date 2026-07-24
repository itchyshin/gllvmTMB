```text
🎯 GOAL
PLATFORM: Codex | DESIGN: 96 | DELIVERABLE: a private, predeclared local
recovery-smoke record for the Design-95 q=2 free Jaakkola--Jordan prototype.
HEADLINE: test whether recovery is visibly reproducible across fixed starts
and two information levels, using invariant covariance and probability targets.
IN PARALLEL: algebra/estimand review and scope/telemetry review. DEFER: all
remote campaigns, threshold amendments, additional starts/fixtures, package
integration, public claims, structured priors, upstream parity, and all prior
Design 72/85/86/90/91 artifacts. DISCIPLINE: six attempts only; retain each
attempt and stop after the predeclared local verdict.
```

# Design 96 — JJ q=2 recovery smoke

## Prior-work receipt

| Surface | Evidence | Finding | Call |
|---|---|---|---|
| Design 95 | commit `8b76a9db`; after-task report | One fixed-start probe passed mechanics but covariance diagnostic was 1.236890. | New multi-start, multi-fixture recovery smoke required. |
| Design 72/85 | `docs/design/72-variational-approximation-feasibility.md`; decision ledger | VA did not cure under-identification; historical q1/q2 extension is no-go. | This is not an EVA/VA revival or package admission. |
| Brain | search-all-projects query `gllvmTMB Design 95 free JJ recovery` | New Design 96 must predeclare starts, fixtures, and evidence; no retry/tuning. | Freeze six attempts exactly. |
| Sister repo | `rg -i 'Jaakkola|Pólya|variational' GLLVM.jl` | No reusable Bernoulli recovery runner found. | Build minimal private runner only. |

## ADEMP contract

### A — aim

Determine whether the private q=2 JJ fit produces nontrivially recoverable,
rotation-invariant signal in two complete Bernoulli-logit fixtures across three
fixed starts. This is a discriminator, not a calibration study.

### D — data-generating mechanisms

For fixture `f`, with fixed seed `96001 + f`, generate `u_i ~ N_2(0,I)`, then
\(Y_{it}\sim\operatorname{Bernoulli}\{\operatorname{logit}^{-1}(\beta_t+
\lambda_t^\top u_i)\}\). Trait order is frozen. Both fixtures have `T = 6`,
q=2, complete observations, and identified true leading loading block:

| Fixture | n | signal multiplier | seed |
|---|---:|---:|---:|
| `strong` | 160 | 1.00 | 96002 |
| `moderate` | 240 | 0.65 | 96003 |

The exact intercept vector is
\(\beta=(-.50,-.20,.10,.40,-.30,.25)\), and the base loading matrix is

\[
\Lambda_0=\begin{pmatrix}.85&0\\ .25&.75\\ -.40&.35\\ .50&-.20\\
-.20&-.50\\ .35&.25\end{pmatrix},\qquad \Lambda_f=c_f\Lambda_0.
\]

No rejection sampling, separation filtering, or response resimulation occurs.
The 61-node Gaussian-Hermite marginal trait prevalences are respectively
`0.393513, 0.456181, 0.523427, 0.592606, 0.430212, 0.559573` (`strong`) and
`0.385294, 0.453063, 0.524277, 0.595938, 0.427665, 0.561024` (`moderate`);
their Bernoulli entropies are all `0.666596--0.692049`. The two nonzero truth
eigenvalues of \(\Sigma_{\Lambda,f}\) are `(1.406844, 0.988156)` and
`(0.594392, 0.417496)`.

### E — estimands

Truth is \(\Sigma_\Lambda=\Lambda\Lambda^\top\), `beta`, and the marginal
trait probability \(\pi_t=E_{u\sim N(0,I)}\{\operatorname{logit}^{-1}
(\beta_t+\lambda_t^\top u)\}\), evaluated with the same 61-node
Gaussian-Hermite rule for truth and fit. The fit reports
\(\hat\Sigma_\Lambda=\hat\Lambda\hat\Lambda^\top\), \(\hat\beta\), and
\(\hat\pi\). No raw latent-coordinate or posterior-mean plug-in probability
is an estimand.

### M — method

The only fitted method is the private Design-95 JJ q=2 TMB objective, with
three predeclared deterministic starts per fixture. Every attempt uses
`nlminb` (`iter.max = 1000`, `eval.max = 1200`) then BFGS refinement
(`reltol = 1e-12`, `maxit = 1500`), with the gradient evaluated at the BFGS
parameters. `mean` is zero and `log_sd = log(.8)` for all starts; the intercept
start is `qlogis(pmin(.95, pmax(.05, colMeans(y))))`. The loading-free vectors
are, for `T = 6`,

```
A = c(log(.45), 0, log(.45), 0, 0, 0, 0, 0, 0, 0, 0)
B = c(log(.80), .10, log(.70), .20, -.15, .20, -.15, .20, -.15, .20, -.15)
C = c(log(.25), -.30, log(.30), -.15, .20, -.15, .20, -.15, .20, -.15, .20)
```

No Laplace, gllvm, or package comparator is fitted.

### P — measures and gate

For each attempt retain: convergence codes, finite objective/parameters,
post-BFGS maximum gradient, mechanical positive leading diagonals, marginal
probability RMSE \(\sqrt{T^{-1}\sum_t(\hat\pi_t-\pi_t)^2}\), covariance
maximum error \(\max_{tt'}|\hat\Sigma_{tt'}-\Sigma_{tt'}|\), beta RMSE, and
the two positive covariance eigenvalues. A health pass requires finite fields,
both convergence codes zero, gradient `< 1e-4`, and finite positive second
eigenvalue. A fixture's recovery signal pass requires **every** start healthy
and every start to meet marginal probability RMSE `< 0.10`, covariance maximum
error `< 0.75`, beta RMSE `< 0.50`, and relative error
\(|\hat d_j-d_j|/d_j < 0.75\) for each of the first two covariance eigenvalues
\(d_j\). It additionally requires maximum pairwise
start disagreement `< 0.25` for covariance entries, `< 0.25` for beta entries,
and `< 0.05` for marginal probabilities. Medians are reported only as summaries.
The smoke passes only if both fixtures pass. These thresholds are one-shot and
cannot be tuned.

## Symbolic alignment

| Symbol | Prototype component | DGP | Reported target | Truth |
|---|---|---|---|---|
| \(u_i\) | variational `mean[i,]` | `N_2(0,I)` | no direct recovery target | none |
| \(\beta_t\) | `beta[t]` | fixed vector | beta RMSE | `beta` |
| \(\Lambda\) | identified `loading_free` decoder | lower-triangular base × signal | covariance max error | \(\Lambda\Lambda^\top\) |
| \(\pi\) | 61-node marginal expectation | Bernoulli probability | marginal probability RMSE | \(\pi\) |
| \(s_{ik}\) | `exp(log_sd)` | not a DGP estimand | health only | no target |

## Stop rules and telemetry

The only executable-code allowlist is `dev/design96-jj-recovery/`. Before the
first attempt, an empty-diff guard covers `src/`, `R/`, `man/`, `NAMESPACE`,
`DESCRIPTION`, `inst/`, `vignettes/`, `README*`, `NEWS*`, `_pkgdown.yml`, and
the terminal Design 72/85/86/90/91/94/95 records. The only permitted new
records are the Design 96 contract, check-log/after-task/reconciliation, and
the Design 96 developer directory.

The runner writes one non-overwriting JSON attempt record for each of the six
predeclared `(fixture, start)` pairs under `dev/design96-jj-recovery/results/`.
Each fixture, attempt, manifest, and summary uses atomic exclusive-create. If
the results directory is nonempty or any target exists, the runner aborts
before generating or writing anything. It never retries a record. Missing,
malformed, non-binary, all-one/all-zero trait, or non-finite fixture is
`PRECHECK_FAIL` and consumes that attempt. The summary is computed only after
all six attempted records exist. Any smoke failure ends Design 96; closeout can
say only `passed/failed this predeclared local smoke`, never that the JJ method
generally recovers. Failure cannot trigger altered seeds, starts, thresholds, a
campaign, or package work.

## Williams transparency self-audit

| Item | Coverage |
|---|---|
| 1 Aim | ADEMP A |
| 2 DGP | ADEMP D, seeds and equations |
| 3 Estimands | ADEMP E and alignment table |
| 4 Methods | ADEMP M, one private method |
| 5 Measures | ADEMP P with formulas/thresholds |
| 6 Software/provenance | runner receipt records R/TMB/platform |
| 7 Code | private `dev/design96-jj-recovery/` only |
| 8 Reproducibility | fixed seeds, no overwrite, all records retained |
| 9 Case study | deliberately not applicable to private smoke |
| 10 Results | attempt-level records plus summary |
| 11 MCSE | deliberately not applicable: `R=1` per fixed smoke cell; no aggregate inference |

## Execution slices

| Slice | Member/model/effort | Output | Dependency |
|---|---|---|---|
| Recovery-contract review | Fisher + Gauss, Terra-high | PASS/WARN/FAIL | this contract |
| Scope/telemetry review | Rose, Terra-medium | PASS/WARN/FAIL | this contract |
| Runner | Ada | fixture/runner/summary files | both reviews pass |
| Local smoke | Ada | six records + summary | runner static checks pass |
| Closeout | Fisher/Rose, Terra-high | verdict | smoke summary |

No Luna session is planned: the current runtime exposes Terra/Sol but no Luna
selector; the bounded mechanical checks are run locally and this is recorded.
