```text
GOAL
PLATFORM: Codex | DESIGN: 97 | DELIVERABLE: a private q=2 full-covariance
Jaakkola--Jordan discrimination packet with a two-dimensional Gaussian-Hermite
marginal-likelihood comparator. HEADLINE: distinguish mean-field geometry,
JJ/global-objective bias, and finite-fixture information.
IN PARALLEL: symbolic review and scope review. DEFER: package paths, EVA,
structured priors, campaigns, public claims, and all earlier Design artifacts.
DISCIPLINE: new fixtures, starts, thresholds, telemetry, and output root only;
each gate stops on failure.
```

# Design 97 -- full-covariance JJ discrimination

## Prior-work receipt

| Surface | Evidence | Finding | Call |
|---|---|---|---|
| Git state | `git status -sb`; `git worktree list`; `branch_drift_check.sh` | The active Design-87 checkout is dirty and unrelated; Design 96 is committed at `1e113e32`. | New worktree from Design 96 only. |
| Design 96 | `docs/dev-log/after-task/2026-07-24-design96-jj-recovery-smoke-stop.md` | The six fixed attempts produced `SMOKE_STOP`; its summary checksum is fixed. | Never replay or rescore it. |
| Design 95 | `docs/design/95-free-jj-variational-arc.md` | Diagonal q=2 JJ passed objective mechanics only. | Reuse formulas, not recovery evidence. |
| Design 72 | `docs/design/72-variational-approximation-feasibility.md` | A richer q cannot manufacture information in rank-deficient data. | Include an exact-MLE discriminator. |
| Brain | `search_notes("gllvmTMB Design 96 JJ recovery smoke stop Design 97 full covariance JJ exact 2D marginal likelihood", search_all_projects=TRUE)` | Prior VA evidence is bounded and no Design-97 packet exists. | Build only this new gap. |

## Estimator contract

For complete binary (y_{it}), (q=2), and (u_i\sim N_2(0,I)), define

\[
\eta_{it}=\beta_t+\lambda_t^\top u_i,\quad
q_i(u_i)=N_2(m_i,S_i),\quad S_i=L_iL_i^\top,
\]

with (L_i=\begin{pmatrix}\exp(a_i)&0\\b_i&\exp(c_i)\end{pmatrix}).
Writing \(\kappa_{it}=y_{it}-1/2\),
\(\mu_{it}=\beta_t+\lambda_t^\top m_i\), and
\(v_{it}=\lambda_t^\top S_i\lambda_t\), profile
\(\xi_{it}=\sqrt{\mu_{it}^2+v_{it}}\). The private objective minimizes
the negative of

\[
\sum_{it}\{\kappa_{it}\mu_{it}-\omega(\xi_{it})(\mu_{it}^2+v_{it})+
\log\sigma(\xi_{it})-\xi_{it}/2+\omega(\xi_{it})\xi_{it}^2\}
-\tfrac12\sum_i\{\mathrm{tr}(S_i)+m_i^\top m_i-\log|S_i|-2\},
\]

where \(\omega(x)=\tanh(x/2)/(4x)\) and \(\omega(0)=1/8\). Since
\(\xi^2=\mu^2+v\), the two omega terms are cancelled before automatic
differentiation. The code evaluates \(-\log\{2\cosh(\sqrt r/2)\}+\kappa\mu\),
with \(r=\mu^2+v\), using \(-\log 2-r/8+r^2/192\) near zero; a zero start
therefore has a finite derivative. All constants are retained. The loading convention is Design 95's local
lower-triangular leading block: \(\lambda_{11}>0\), \(\lambda_{12}=0\),
and \(\lambda_{22}>0\). It is a private coordinate convention only.

The comparator is the deterministic 31-by-31 Gaussian-Hermite approximation

\[
\ell_{GH}(\beta,\Lambda)=\sum_i\log\sum_{r,s}w_rw_s
\prod_t p(y_{it}\mid \beta_t+\lambda_{t1}z_r+\lambda_{t2}z_s).
\]

It is an independent marginal-likelihood comparator, not a claim of exact
analytic integration or EVA parity.

## Gate sequence and predeclared tests

1. **G0 isolation.** Only `dev/design97-fullcov-jj/`, this contract, Design-97
   developer records, and Design-97 handover records may change. Guard
   `src/`, `R/`, `man/`, `NAMESPACE`, `DESCRIPTION`, `inst/`, `vignettes/`,
   `README*`, `NEWS*`, `_pkgdown.yml`, and every Design 72/85/86/90/91/94/95/96
   artifact.
2. **G1 mechanics.** At one fixed nondegenerate binary matrix: independent R
   and C++ objectives agree to `1e-10`; C++ autodiff and central differences
   agree to `1e-5`; Cholesky matrices are positive definite; row permutation
   leaves the objective unchanged; and JJ ELBO is no greater than a converged
   GH estimate of the per-observation Gaussian ELBO under the same q. The
   bound allowance is the 41-versus-61-node GH difference plus `1e-8`.
3. **G2 fixed-global approximation.** The `fixed` fixture uses seed `97002`,
   `n=48`, `T=5`, q=2, `RNGkind("Mersenne-Twister", "Inversion", "Rejection")`,
   one `rnorm(n*2)` matrix in column-major order, then one column-major
   `rbinom(n*T, 1, probability)` draw. Both fixtures use
   \(\beta=(-.40,.15,.35,-.25,.20)\) and
   \(\Lambda=((.80,0),(.20,.70),(-.35,.30),(.45,-.20),(-.20,-.45))^\top\).
   Require finite complete 0/1 data and both outcomes in every trait; record
   the canonical `sha256` of `serialize(y, NULL, version=2)`. Hold beta and
   Lambda exactly at truth. Optimize only local q coordinates from `m=0` and
   either diagonal `log_sd=log(.8)` (implemented as `b_i=0`) or full
   `a_i=c_i=log(.8), b_i=0`. Both use the predeclared two-stage optimizer.
   Health requires finite objective/coordinates, both convergence codes zero,
   and final gradient below `1e-4`. Retain both bounds and their 61-node GH
   marginal-likelihood gaps. This is approximation evidence only.
4. **G3 free-global discriminator.** The independently generated `free`
   fixture uses seed `97003`, `n=72`, and the same frozen truth/draw protocol.
   GH-MLE and full-JJ each start beta at clamped empirical logits
   `qlogis(pmin(.95,pmax(.05,colMeans(y))))`, loading free at
   `(log(.40),0,log(.40),0,0,0,0,0,0)`, and (for JJ) `m=0`,
   `a=c=log(.8),b=0`. Each predeclared fit is `nlminb(iter.max=800,
   eval.max=1000)` followed by BFGS (`reltol=1e-12,maxit=1000`), not a retry.
   The GH objective uses 31 nodes for optimization; all reported probabilities
   and metrics use 61 nodes. Health requires finite fields, both named phase
   codes zero, gradient below `1e-4`, and second eigenvalue of
   \(\hat\Sigma=\hat\Lambda\hat\Lambda^\top\) above `1e-6`. Report beta
   RMSE, max entry error in Sigma, and 61-node marginal-probability RMSE.
5. **G4 closeout.** A local recovery flag is predeclared solely to classify
   this fixture: healthy plus beta RMSE `< .35`, covariance max error `< .50`,
   and probability RMSE `< .08`. Let `E` and `J` be the GH-MLE and full-JJ
   flags, and let `I` mean full q has a strictly smaller G2 GH-gap than diagonal
   q by at least `1e-6`. Apply this ordered, mutually exclusive rule: any
   health failure is `SMOKE_STOP`; otherwise `!E` is `FIXTURE_INFORMATION_STOP`;
   otherwise `!J` is `JJ_GLOBAL_SIGNAL`; otherwise `I` is `MEAN_FIELD_SIGNAL`;
   otherwise it is `APPROXIMATION_ONLY`. These are descriptive local labels, not
   general recovery, calibration, or admission claims. Fisher/Gauss classify;
   Rose confirms boundaries. Nothing authorizes integration or a campaign.

## Telemetry and stop boundary

The result root is `dev/design97-fullcov-jj/results/`. Before any generation,
the runner requires that it does not exist; it creates it atomically and
exclusively, then exclusively creates `manifest.json`, each fixture record,
each estimator record, and `summary.json`. Existing or concurrently created
targets abort before evidence generation. Every record includes source hashes,
R/TMB/platform/RNG metadata, seed, realised binary fixture checksum,
quadrature order, full starts and transforms, raw final coordinates, objective,
phase convergence codes, gradient maximum, warnings/errors, invariant
estimates, and health code. Failed fits still write their record; no record is
overwritten or retried. Any G1 failure ends the arc before a fixture is made;
any later failure emits a stop receipt and ends the arc.
