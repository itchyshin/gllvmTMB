```text
🎯 GOAL
PLATFORM: Codex | DESIGN: 98 | DELIVERABLE: one private, reproducible
Bernoulli-logit q=2 factorial VA/JJ mechanism-discrimination packet.
HEADLINE: on fresh homologous fixtures, separate finite-data information,
mean-field variational geometry, JJ-bound bias, and residual Gaussian-family
or global-optimisation error using a converged deterministic 2D
Gaussian-Hermite marginal reference and a 2×2 variational design.
IN PARALLEL: mathematical review; worker-supervision design; provenance review.
DEFER: every earlier Design fixture/result; EVA; q4/q6; campaigns; structured
priors; package/public paths; rank selection; calibration; DRAC; Actions;
rebase, merge, push, and PR work.
DISCIPLINE: new source, fixtures, seeds, starts, thresholds, task DAG, output
UUID, and telemetry only. Global algebra/provenance failures stop before fits;
individual worker failures are retained and do not erase independent evidence.
```

# Design 98 — factorial direct-ELBO/JJ mechanism discriminator

## Prior-work receipt

| Surface | Evidence | Finding | Forced call |
|---|---|---|---|
| Repository | `git status -sb`; `git log --oneline -12`; `git worktree list`; `git stash list`; `branch_drift_check.sh` | Design 97 is clean and terminal at `7a725c5e`; the historical worktrees and dirty Design-87 lane remain separate. | Create a new worktree from `7a725c5e`; never resume an older lane. |
| Designs 94–97 | Their contracts, after-task reports, and immutable JSON | JJ mechanics exist, but Design 97 placed all free-global evidence behind one uninterrupted parent process. | Reuse equations only; replace the execution architecture. |
| Design 72 | `docs/design/72-variational-approximation-feasibility.md` | Richer variational covariance cannot create missing information. | Add a nested low/high information intervention. |
| Design 85 | `docs/design/85-highdim-nongaussian-va-formal-contract.md` and terminal after-task | Direct quadrature Gaussian ELBO supplies a missing comparator, but Design 85 remains NO-GO. | Independently derive the narrow q=2 objective; never reopen q4/q6 or rescore Design 85. |
| Sister repo | `rg -i 'variational|Jaakkola|Gauss.Hermite|marginal likelihood' GLLVM.jl` | No reusable Bernoulli factorial VA/JJ engine exists. | Build only this private gap. |
| Brain | `search_notes("gllvmTMB Design 97 full covariance JJ runner interrupted Gate 3 exact marginal likelihood next design variational", search_all_projects=true)` | The durable claim boundaries agree with the repo. | Mechanism evidence only; no admission claim. |

**Genuine new gap:** a failure-resilient 2×2 comparison of objective
approximation (`direct Gaussian ELBO` versus `JJ`) and posterior geometry
(`diagonal` versus `full`) on a common marginal-likelihood scale.

## Model, identification, and invariant estimands

For unit \(i\), trait \(t\), and \(q=2\),

\[
Y_{it}\sim\operatorname{Bernoulli}\{\operatorname{logit}^{-1}
(\beta_t+\lambda_t^\top u_i)\},\qquad u_i\sim N_2(0,I_2).
\]

The prototype-local loading convention is

\[
\lambda_{1\cdot}=(\exp d_1,0),\qquad
\lambda_{2\cdot}=(a_{21},\exp d_2),
\]

with remaining rows free. It fixes local sign/rotation only and is not a
package parameterisation claim. Report \(\beta\),
\(\Sigma=\Lambda\Lambda^\top\), its two positive eigenvalues, and 61-node
population-marginal probabilities. Never use raw scores or unaligned raw
loadings as recovery targets.

The loading-free vector is packed, without exception, as
\[
(d_1,a_{21},d_2,\lambda_{31},\lambda_{32},
\lambda_{41},\lambda_{42},\lambda_{51},\lambda_{52},
\lambda_{61},\lambda_{62}).
\]
“`0.90*Lambda_truth` encoded” therefore means multiply the matrix by 0.90
first and then apply this packer, including logs of the two positive diagonal
entries. All pack/unpack functions and start records use this order.

For every unit,

\[
q_i(u_i)=N_2(m_i,S_i),\qquad S_i=L_iL_i^\top.
\]

For full geometry,
\[
L_i=\begin{pmatrix}\exp a_i&0\\b_i&\exp c_i\end{pmatrix};
\]
for diagonal geometry set \(b_i=0\). Here \(S_i\) is posterior variational
covariance. It is not `dep()`, \(\Psi\), `unique`, or a package covariance.

## Four variational objectives

Let
\[
\mu_{it}=\beta_t+\lambda_t^\top m_i,\qquad
v_{it}=\lambda_t^\top S_i\lambda_t.
\]

The direct quadrature Gaussian ELBO uses

\[
Q(\theta,\phi)=
\sum_{it}\left[
y_{it}\mu_{it}
-E_{Z\sim N(0,1)}
\{\operatorname{softplus}(\mu_{it}+\sqrt{v_{it}}Z)\}
\right]
-\frac12\sum_i
\{\operatorname{tr}S_i+m_i^\top m_i-\log|S_i|-2\}.
\]

The expectation uses normalized standard-normal GH nodes and weights
\((z_h,w_h)\), with \(\sum_h w_h=1\). Thus no unrecorded `-log(pi)`
constant is present. The JJ objective uses the complete profiled bound, with
the algebraically cancelled stable form

\[
J(\theta,\phi)=
\sum_{it}\left[-\log\{2\cosh(\sqrt{r_{it}}/2)\}
+(y_{it}-1/2)\mu_{it}\right]
-\mathrm{KL}(q\|p),\quad r_{it}=\mu_{it}^2+v_{it},
\]

and the near-zero series
\(-\log2-r/8+r^2/192\).

The factorial methods are:

| Method | Observation objective | Geometry |
|---|---|---|
| `QD` | direct Gaussian ELBO | diagonal \(S_i\) |
| `QF` | direct Gaussian ELBO | full \(S_i\) |
| `JD` | JJ bound | diagonal \(S_i\) |
| `JF` | JJ bound | full \(S_i\) |

At identical coordinates the required chain is
\[
J_g\le Q_g\le\ell_{\mathrm{GH}},\qquad g\in\{D,F\},
\]
up to the declared quadrature discrepancy.

## Deterministic 2D GH marginal reference

Use normalized standard-normal tensor nodes and log-sum-exp:

\[
\ell_H(\beta,\Lambda)=
\sum_i\log\sum_{r,s}w_rw_s
\exp\left[
\sum_t\{y_{it}\eta_{it,rs}-\operatorname{softplus}(\eta_{it,rs})\}
\right],
\]
\[
\eta_{it,rs}=\beta_t+\lambda_{t1}z_r+\lambda_{t2}z_s.
\]

This is a deterministic numerical reference, not analytically exact
integration. Optimize with \(H=31\); evaluate all reported common-scale
objectives with \(H=61\). At fixed coordinates record
\[
\epsilon_{\mathrm{GH}}(\theta)=
\max(|\ell_{31}-\ell_{41}|,|\ell_{41}-\ell_{61}|).
\]
Every reported endpoint must satisfy
\(\epsilon_{\mathrm{GH}}(\theta)\le
10^{-6}\max\{1,|\ell_{61}(\theta)|\}\). A cross-coordinate contrast
\(\ell_{61}(\theta_a)-\ell_{61}(\theta_b)\) must exceed
\[
10\{\epsilon_{\mathrm{GH}}(\theta_a)+
\epsilon_{\mathrm{GH}}(\theta_b)\}.
\]
Every GH candidate additionally requires the 61-node central-gradient maximum
to be `<1e-3`. Thus the node ladder and numerical stationarity are health
conditions, not merely reported diagnostics.

## Fresh nested fixture

Use `RNGkind("Mersenne-Twister", "Inversion", "Rejection")`, master seed
`98001`, one column-major `rnorm(640*2)` draw, and then one column-major
`rbinom(640*6, 1, probability)` draw. Freeze

\[
\beta=(-.45,-.10,.30,.05,-.25,.40)
\]

and

\[
\Lambda=
\begin{pmatrix}
.82&0\\
.18&+.68\\
-.36&+.30\\
+.46&-.24\\
-.20&-.44\\
+.28&+.38
\end{pmatrix}.
\]

The low-information fixture is the first 160 units; the high-information
fixture is all 640. No rejection, filtering, redraw, separation repair, or
response resimulation is allowed. Require finite complete binary responses
and both outcomes in every trait. Record SHA-256 for
`serialize(y, NULL, version=2)` for both nested matrices.

## Predeclared starts and optimiser health

Every free-global method receives three starts, each as a different worker:

1. `A`: empirical-logit beta and loading free vector
   `(log(.40),0,log(.40),0,0,0,0,0,0,0,0)`;
2. `B`: truth-near diagnostic beta
   `beta_truth + (.05,-.04,.03,-.02,.01,-.05)` and `0.90*Lambda_truth`
   encoded under the same local convention;
3. `C`: empirical-logit beta plus
   `(.15,-.10,.05,.10,-.05,-.15)` and loading free vector
   `(log(.65),.10,log(.60),.10,-.10,-.10,.10,.15,-.10,-.10,-.15)`.

All variational means start at zero. Variational Cholesky diagonals start at
`log(.8)` and strict-lower entries at zero.

Each fit consists of a checkpointed `nlminb(iter.max=1000,
eval.max=1400)` phase followed by a checkpointed BFGS
`optim(reltol=1e-12,maxit=1500)` phase. The BFGS phase consumes the immutable
phase-1 terminal record; it is not a retry.

One start is healthy only when both phase codes are zero, all fields are
finite, final maximum gradient is `<1e-4`, the second covariance eigenvalue
is `>1e-6`, and its common-scale GH endpoint passes the node-ladder rule.
A method is comparable only when at least two starts are healthy and **all**
healthy starts agree pairwise: covariance maximum disagreement `<.25`, beta
maximum disagreement `<.25`, and marginal-probability maximum disagreement
`<.05`. This forbids choosing a convenient agreeing pair. Every attempted
start remains in the denominator.

The representative coordinate is selected deterministically from all healthy
starts: maximum 61-node marginal likelihood for GH, or maximum optimized
ELBO/bound for a variational method; an exact numerical tie is broken
`A < B < C`. The selected start and the complete healthy-start ordering are
recorded. Fixed-global work consumes only the selected low-GH coordinate.

The fixture-local accuracy flag is prospectively re-declared as:
beta RMSE `<.35`, covariance maximum error `<.50`, and marginal-probability
RMSE `<.08`. These values are never applied retrospectively to prior designs.

## Causal contrasts

At the healthy low-fixture GH optimum, fix \(\theta=\hat\theta_{\mathrm{GH}}\)
and optimize only local coordinates:

\[
G_Q=\max_\phi Q_F-\max_\phi Q_D,\qquad
G_J=\max_\phi J_F-\max_\phi J_D,
\]
\[
B_g=Q_g(\phi_{J_g})-J_g(\phi_{J_g}),\qquad
D_g=\max_\phi Q_g-Q_g(\phi_{J_g}),\quad g\in\{D,F\}.
\]

Compare each \(m_i,S_i\) with posterior moments obtained from normalized
2D-GH weights at the same fixed global coordinates.

Each fixed-global local fit has exactly one predeclared start: all means zero,
Cholesky diagonals `log(.8)`, and full-geometry strict-lower entries zero. It
uses the same separate `nlminb` then BFGS phase nodes and requires both codes
zero, finite fields, maximum gradient `<1e-4`, and positive-definite \(S_i\).
There are no alternative local starts or post-hoc selections. A failed local
fit makes only its dependent contrast unavailable.

After joint optimization evaluate all estimates on the 61-node marginal
scale:

\[
\Delta_{Q,\mathrm{geom}}=
\ell_{61}(\hat\theta_{QF})-\ell_{61}(\hat\theta_{QD}),
\]
\[
\Delta_{J,\mathrm{geom}}=
\ell_{61}(\hat\theta_{JF})-\ell_{61}(\hat\theta_{JD}),
\]
\[
\Delta_{\mathrm{JJ}}=
\ell_{61}(\hat\theta_{QF})-\ell_{61}(\hat\theta_{JF}),
\]
\[
\Delta_{\mathrm{Gauss}}=
\ell_{61}(\hat\theta_{\mathrm{GH}})-\ell_{61}(\hat\theta_{QF}).
\]

A mechanism flag needs both a common-scale improvement greater than the
sum-of-endpoint quadrature rule above and a change in the local accuracy flag.
It also needs the following fixed-global corroboration, where a local objective
contrast is numerically nonzero only when it exceeds `1e-4`:

- `MEAN_FIELD_SIGNAL` requires material
  \(\Delta_{Q,\mathrm{geom}}\), \(G_Q>10^{-4}\), and a reduction greater
  than `1e-3` in
  \[
  \max_i\|S_i-S_i^{\mathrm{GH}}\|_F
  \]
  on the unstandardized latent covariance scale, together with the directed
  accuracy transition `QD fail -> QF pass`;
- `JJ_SIGNAL` requires material \(\Delta_{\mathrm{JJ}}\),
  \(D_F>10^{-4}\), \(B_F>10^{-4}\), and the directed accuracy transition
  `JF fail -> QF pass`;
- the residual contrast is named `GAUSSIAN_OR_GLOBAL_SIGNAL`, because
  \(\Delta_{\mathrm{Gauss}}\) alone cannot distinguish Gaussian-family
  restriction from residual global optimization; it requires the directed
  accuracy transition `QF fail -> GH pass`.

## Supervised task DAG and immutable telemetry

Before any real UUID is created, the design exclusively creates
`dev/design98-factorial-va-jj/results/REAL_RUN.json`. This one-shot registry
contains the UUID, base commit `7a725c5e`, contract SHA-256, creation time,
and status. Its existence forbids every second real UUID, regardless of the
first run's outcome. Additional roots are allowed only when their manifests
say `fault_injection=true`; resume may aggregate records or launch
never-started tasks under the registered UUID only.

The real output root is `dev/design98-factorial-va-jj/results/<uuid>/`.
Its immutable manifest freezes the base commit, full
`git status --porcelain`, contract, R-oracle, C++ source, worker script, and
worker executable SHA-256 values; R, TMB, compiler, OS, and platform versions;
RNG kind; normalized GH node/weight checksums for every order; and the UUID.
The manifest exclusively creates the UUID root before any fixture or fit.
Every estimator phase is a separate `Rscript` worker with:

- immutable input JSON and its SHA-256;
- task ID, dependency IDs, PID, host, and start time;
- heartbeat updated every five seconds;
- captured stdout and stderr with hashes;
- explicit wall-time limit (`60 s` toy; `1800 s` low; `3600 s` high GH);
- atomic exclusive-create terminal JSON containing raw coordinates,
  transformed parameters, objective, phase code, gradient, warnings, error,
  signal/exit status, and realised inputs.

The supervisor may launch only `PENDING` tasks whose dependencies have
terminal healthy records. Completed, failed, timed-out, malformed, duplicate,
or orphaned tasks are never overwritten or retried. Resume mode may launch
only never-started tasks. `nlminb` and BFGS are separate DAG nodes.

The aggregation-only finalizer accepts existing records and writes a summary.
It has no code path that constructs an objective or starts a worker.

Fault injections use separately named disposable roots and cover worker
crash, timeout, malformed JSON, partial output, duplicate output, and parent
interruption after one child succeeds. They also assert that the finalizer
performs zero worker launches/objective constructions and that the supervisor
rejects a duplicate design-level real-run lock.

## Gates

1. **G0 isolation and contract.** New Design-98 paths only; empty diffs for
   package/public paths and Designs 72/85/86/90/91/94/95/96/97. Gauss/Noether
   and Rose approve before compilation. Record baseline and final SHA-256
   inventories for every named prior immutable path and require byte identity,
   not only an empty visible diff.
2. **G1 mechanics.** R/C++ equality `<1e-10`; AD/central-gradient relative
   error `<1e-5`; pack/unpack; SPD; row/sign invariance; GH normalization;
   zero-branch continuity; Gaussian exactness; 31/41/61 ladder; and the bound
   chain at identical coordinates.
3. **G2 supervision.** The task-DAG and every fault injection pass before the
   real output UUID is created.
4. **G3 fixture and toy smoke.** Freeze/hash nested fixtures, then run a
   separate `N=16,T=3` invocation smoke with non-empty valid output. Toy
   output is never evidence.
5. **G4 information gate.** Run three GH starts at `N=160` and `N=640`.
   Only healthy GH fits may inform finite-information interpretation.
6. **G5 fixed-global factorial.** At the low GH coordinates compute posterior
   moments and \(G_Q,G_J,B_g,D_g\).
7. **G6 joint low factorial.** Run `QD,QF,JD,JF`, three starts each, and
   evaluate all healthy estimates on the common marginal scale.
8. **G7 closeout.** Apply only dependency-valid labels, obtain independent
   method/scope/mechanical reviews, reconcile plan versus actual, and write
   after-task/check-log/handover records.

## Failure containment and ordered labels

A contract-hash, oracle/TMB, quadrature, provenance, fixture, or supervision
test failure writes a root stop receipt and launches no real estimators.

A worker timeout, signal, nonzero exit, malformed record, non-finite result,
health failure, or duplicate output terminates only that worker. Independent
workers continue. No start, threshold, fixture, method, or timeout is changed.

After all independent tasks reach terminal states:

1. any missing required comparable method → `TECHNICAL_INCOMPLETE`, with
   dependency-specific fields such as `COMPARATOR_UNAVAILABLE` or
   `JJ_ESTIMATOR_UNHEALTHY`;
2. calculate the complete valid flag vector:
   - healthy low-GH accuracy failure and healthy high-GH accuracy pass →
     `NESTED_FIXTURE_INFORMATION_SIGNAL`;
   - corroborated material direct-full improvement over direct-diagonal →
     `MEAN_FIELD_SIGNAL`;
   - corroborated material direct-full improvement over JJ-full →
     `JJ_SIGNAL`;
   - material GH improvement over direct-full →
     `GAUSSIAN_OR_GLOBAL_SIGNAL`;
3. count all four flags above, including the nested-fixture information flag;
   emit `MIXED_SIGNAL` when the count is at least two, the sole flag when the
   count is one, and `NO_DIAGNOSTIC` when the count is zero.

The summary reports the complete vector of mechanism flags even when the
headline is `MIXED_SIGNAL`. Design 98 may say its fresh-fixture finding is
consistent with an earlier failure; it cannot prove the retrospective cause
of Designs 96 or 97.

## Compute and claim boundary

Compile, test, fault-inject, smoke, and run the low fixture locally. If a
predeclared local high-GH benchmark exceeds ten minutes, run only the three
high-GH starts on Totoro, at most eight concurrent cores, with
`OPENBLAS_NUM_THREADS=1`, after verifying the existing ControlMaster and
deployed source hashes. The benchmark command is frozen in the manifest before
execution; any remote run records source, input, and returned-output hashes in
the local UUID packet. No DRAC or GitHub Actions.

No result authorizes EVA/VA revival, q4/q6, a campaign, public integration,
likelihood/AIC/BIC inference, rank selection, structured priors, calibration,
or package capability language.

## Planned durable packet

- `dev/design98-factorial-va-jj/`
- `docs/design/98-factorial-va-jj-discriminator.md`
- `docs/dev-log/plan-actual/2026-07-24-design98-factorial-va-jj.md`
- `docs/dev-log/after-task/2026-07-24-design98-*.md`
- `docs/dev-log/handover/2026-07-24-codex-handover-design98.md`
