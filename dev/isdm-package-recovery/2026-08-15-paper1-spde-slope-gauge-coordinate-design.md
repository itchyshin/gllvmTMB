# Paper 1 spatial-slope gauge-coordinate design

**Status:** design-only feasibility contract.  It authorises no fit, smoke,
recovery calculation, campaign, retry, source-likelihood edit, or public
claim.  It opens a new estimator-design lane only after the immutable MSPDE
state has passed the pure coordinate checks below.

## Why this is a new lane

The historical marginal-SPDE and BFGS roots remain immutable.  The MNCB and
BFGS continuations produced no provenance-admissible numerical result: their
terminalisation failures are infrastructure records, not evidence about the
ecological model or either numerical estimator.  They must not be repaired,
relabelled, resumed, or used to tune the next method.

The next candidate is not another finite-difference bracket or BFGS retry.
It changes the *fixed-coordinate chart* used for the GBIF spatial-slope
loading while preserving the same rank-one spatial covariance and the same
marginal TMB objective on its declared gauge domain.  The working estimator
name is

```
PAPER1_SPDE_SLOPE_GAUGE_TRUST_REGION_V1
```

It is a new, separately named estimator.  No execution is authorised by this
document.

## Frozen predecessor and local target

The only permissible scientific predecessor is the sealed MSPDE V3 packet,
not a copied state file in isolation:

```
canonical root: /private/tmp/gllvmtmb-isdm-paper1-qfixed-matched-spde/dev/isdm-package-recovery/results/MSPDE_P1_S3_C360_R3_V3
root: MSPDE_P1_S3_C360_R3_V3
commit: a6255290810269510bba87951ea2dee365861e21
all-attempt-ledger.rds: a9f19416c126a9f2054092835cdb8aaa
attempt-started.rds: 8b5421d35a4b50d46b690eee0c2b3cb2
file-manifest.csv: 32f93c4de1988dad08ac01f12e30a674
root-receipt.rds: 1940354271459b695e3ed2af70f1ca9c
session-info.rds: 817aea4f16c4ddc7d844bb7af342024e
time-estimate.md: e0a79bbfdb48668328d5f0224e6bd40f
v2-materialized-state.rds: e3b17636c9f5fa0e9e555a307c923724
required empty directory: .attempt-started.claim
```

Before any future preflight, its whole-root manifest, receipt, marker, ledger,
and production V3 terminal validator must all be re-read and pass.  Only then
may the materialized state supply the locked 22-coordinate order, objective
\(f_0=2549.0400257185738\), and exact outer gradient.  The relevant last six
coordinates are two rank-one, three-trait loading blocks:

\[
\lambda_{\mathrm{intercept}}=(21.61793515681646,-21.08106681592886,
14.56027253661505)^\top,
\]

\[
\lambda_{\mathrm{GBIF}}=(0.06615484034380216,-0.005920383591143399,
-0.07900112916196837)^\top.
\]

They are respectively positions 17--19 and 20--22 of
`theta_rr_spde_slope`.  The C++ engine uses rank \(d_{\rm spde,slope}=1\)
and two LHS columns.  Its second block is reported as
`Sigma_spde_slope_slope` and contributes through
`Lambda_spde_slope(t, 0, 1) * A_g_spde_slope(o, 0, 1)`.

The finite predecessor has \(\lambda_{\mathrm{GBIF},1}>0\) and
\(\lVert\lambda_{\mathrm{GBIF}}\rVert_2=0.1032118803803431\).  It is
therefore inside the open chart below; no boundary convention is being chosen
from an incomplete BFGS trace.

## Coordinate map and exact inverse

Leave the first 19 raw TMB coordinates unchanged.  Replace only the GBIF
block by \(\phi=(\eta,a,b)\in\mathbb R^3\):

\[
s(\phi)=\sqrt{1+a^2+b^2},\qquad
\lambda(\phi)=\frac{e^\eta}{s(\phi)}(1,a,b)^\top.
\]

This is a smooth bijection from \(\mathbb R^3\) to the open hemisphere
\(\{\lambda\in\mathbb R^3:\lambda_1>0\}\).  Its inverse is

\[
\eta=\log\lVert\lambda\rVert_2,\qquad
a=\lambda_2/\lambda_1,\qquad b=\lambda_3/\lambda_1.
\]

For the frozen start,

\[
\phi_0=(-2.270971312595905,-0.08949282562508763,
-1.1941851684835898)^\top,
\]

and forward--inverse reconstruction must have symmetric relative error

\[
\frac{\max_j|\operatorname{inverse}(\operatorname{map}(\phi))_j-\phi_j|}
{\max(1,\max_j|\phi_j|)}\le64\epsilon,
\]

with the same \(64\epsilon\) relative rule for
`map(inverse(lambda))` on the positive hemisphere.  The analytic Jacobian
must agree with a central finite-difference map Jacobian to relative
\(10^{-7}\) on the frozen point and predetermined nontrivial interior points.
Inputs with nonfinite coordinates, a nonpositive raw first loading, or a
nonfinite/nonpositive determinant are rejected; they are never repaired by a
sign flip selected after observing an objective.

The Jacobian used by the new estimator is retained explicitly:

\[
J(\phi)=\left[
\lambda,\quad
\frac{e^\eta}{s^3}(-a,1+b^2,-ab)^\top,\quad
\frac{e^\eta}{s^3}(-b,-ab,1+a^2)^\top
\right].
\]

Its determinant is \(e^{3\eta}/s^3>0\), so the chart itself introduces no
finite-coordinate singularity.  The raw surface \(\lambda_1=0\) is not in
the chart.  This is a deliberate local gauge domain, not a claim that the
chart covers every raw representation.

## Ecological-model equivalence on the gauge domain

For the GBIF slope column, the reported trait covariance is

\[
\Sigma_{\mathrm{GBIF,slope}}=\lambda\lambda^\top.
\]

Consequently the forward map preserves the covariance exactly:

\[
\Sigma(\phi)=\lambda(\phi)\lambda(\phi)^\top.
\]

The original rank-one spatial field is expected to have the simultaneous sign
symmetry \((\lambda,g)\mapsto(-\lambda,-g)\), but this is an executable
precondition, not an inference from the GMRF quadratic alone.  A future
no-fit gate must construct the full random-effect sign operator \(S\) that
negates **every** random-effect coordinate in the GBIF slope-field slice and
leaves all other random-effect blocks unchanged.  It must establish all of:

\[
S^\top Q S=Q,\qquad \operatorname{linpred}(\lambda,g)=\operatorname{linpred}(-\lambda,Sg),
\qquad f(\theta)=f(\theta_{\rm sign})
\]

to the retained objective replay tolerance, with unchanged maps, constraints,
data, random declaration, DLL, and positional order.  The last identity is a
live marginal-Laplace objective replay, not a symbolic assertion.  Only after
that gate passes may the positive-hemisphere choice be described as fixing one
representative of an existing sign orbit.  The covariance equality alone is
already exact, but full likelihood/estimand equivalence remains unclaimed
until this gate passes.  The starting state already lies in the positive
representative.  Any future implementation must stop with a typed
`GAUGE_DOMAIN_HOLD` if it cannot establish this nonzero, positive-hemisphere
start condition.

This is frequentist optimization of a re-expressed likelihood, not a change
of variables in a parameter prior.  **No Jacobian determinant is added to the
objective.**

## Objective and gradient alignment

Let \(T:\mathbb R^{22}\to\mathbb R^{22}\) replace the last three raw
coordinates by \(\lambda(\eta,a,b)\), leaving all other coordinates fixed.
The prospective estimator uses

\[
F(\varphi)=f(T(\varphi)),\qquad
G(\varphi)=\nabla F(\varphi)=D T(\varphi)^\top g(T(\varphi)).
\]

The full transform Jacobian is identity outside positions 20--22 and the
displayed \(J\) in that block.  `obj$fn` and `obj$gr` remain the original
TMB marginal Laplace callbacks; every raw gradient is still checked against
the immutable positional order before the chain rule is applied.  A candidate
is always projected back to the original raw coordinates before objective
replay, `sdreport`, covariance extraction, recovery, or any ecological claim.

The no-fit live frozen-state identity gate is conjunctive and uses no
optimizer.  With \(\epsilon=\texttt{.Machine\$double.eps}\), it must retain
the raw and transformed callback values and require:

\[
\frac{\lVert T(\varphi_0)-\theta_0\rVert_\infty}
{\max(1,\lVert\theta_0\rVert_\infty)}\le64\epsilon,
\qquad
\frac{|F(\varphi_0)-f_0|}{\max(1,|f_0|)}\le10^{-10},
\]

\[
\frac{\lVert g(T(\varphi_0))-g_0\rVert_\infty}
{\max(1,\lVert g(T(\varphi_0))\rVert_\infty,
\lVert g_0\rVert_\infty)}\le10^{-6}.
\]

For every transformed coordinate \(j\), the independently evaluated central
objective derivative uses the frozen step

\[
h_j=\epsilon^{1/3}\max(1,|\varphi_{0j}|),\qquad
G^{\rm FD}_j=\frac{F(\varphi_0+h_je_j)-F(\varphi_0-h_je_j)}{2h_j}.
\]

All calls must be finite and preserve the exact raw positional order.  The
analytic chain-rule gradient and this central difference must have symmetric
relative discrepancy at most \(10^{-5}\):

\[
\frac{\lVert G(\varphi_0)-G^{\rm FD}\rVert_\infty}
{\max(1,\lVert G(\varphi_0)\rVert_\infty,
\lVert G^{\rm FD}\rVert_\infty)}\le10^{-5}.
\]

No tolerance, step, coordinate, or source/DLL identity may be selected after
these results are observed.

| Mathematical object | Future implementation | Required pure validation | Retained evidence |
| --- | --- | --- | --- |
| \(\lambda\leftrightarrow(\eta,a,b)\) | pure R map, inverse, analytic \(J\) | round trip and finite positive determinant | map version and max error |
| \(\Sigma=\lambda\lambda^\top\) | raw C++ loading packet unchanged | entrywise equality before/after transform | covariance error |
| sign orbit | full random-effect sign operator | \(S^\top QS\), predictor, and live marginal replay | sign-map and replay records |
| \(G=D T^\top g\) | checked original `obj$gr` followed by chain rule | quadratic harness **and** no-fit live frozen-state replay | max relative errors |
| candidate curvature | candidate raw-coordinate `sdreport$cov.fixed` | original positional axes, finite/symmetric/PD/pdHess/condition gates | raw covariance and axes |
| ecological recovery | existing raw-coordinate extractor only | only after numerical admission | separate recovery ledger |

## No-fit adapter and process provenance

The callback-only contract above is deliberately not a source-to-state
certificate.  Its executable successor is a **non-scientific** gate named
`PAPER1_SPDE_SLOPE_GAUGE_NOFIT_GATE_V1`; it is neither an MNCB/BFGS retry nor
an estimator admission attempt.  It may run only after an implementation and
its tests have been reviewed.  Passing it establishes that the live frozen
state can be expressed in this chart.  It does not establish curvature,
accept a step, run a trust region, calculate recovery, or make an ecological
claim.

The gate is run in one clean `Rscript --vanilla` child.  The child starts with
no loaded `gllvmTMB` DLL, rejects any preloaded same-basename DLL rather than
unloading or replacing it, then loads the exact frozen DLL once and verifies
its canonical path and MD5.  It first re-enters the production MSPDE V3
terminal validator using the complete packet listed above.  Only after that
validator returns its exact success reason may it force collection of the
predecessor object and construct one fresh `TMB::MakeADFun` object from the
materialized state.  That object remains resident for the one start
objective, one raw gradient, and the fixed 44 objective calls.  It is released
and collected while the DLL remains loaded.  There is no `dyn.unload`, no
second DLL activation, no outer optimizer, and no callback/factory rebuilding
inside the finite-difference loop.

Before applying names to an otherwise unnamed TMB gradient, the adapter must
require the fresh object's `par` labels and length to equal the sealed
`block_labels` and 22-coordinate state order.  The resulting named gradient,
the original unnamed values, the raw input vector, the actual DLL identity,
and a monotone object identifier are retained together.  A supplied named
gradient must already have the exact sealed order; it is never silently
relabelled.  This is the only bridge from the generic callback rule to TMB's
positional gradient convention.

The parent retains a dedicated, sibling-staged, atomically renamed gate root
outside every scientific result root.  Its exact inventory is a root receipt,
the child receipt, the no-fit result (including all 22 ordered FD records), a
CSV manifest, session information, and the materializer source copy.  The
receipt binds the full MSPDE V3 packet hashes, current runner/contract/design
and map-helper hashes, the frozen historical MSPDE V3 validator path/MD5, the retained materializer hash, actual DLL path/MD5,
the frozen state hash, child/parent process identifiers, object/release
counts, and the exact control packet.  The parent rereads the sealed root,
recomputes its manifest, and applies the production validator before printing
any pass token.  A child failure yields only a typed infrastructure gate
record; it never manufactures missing callback evidence.

That new root has its own production validator and terminal schema; the MSPDE
validator validates only the predecessor.  Its sole non-scientific success is
`SPDE_SLOPE_GAUGE_NOFIT_VALID`.  Invalid predecessor evidence, DLL identity,
process receipt, factory order, raw-gradient order, callback result,
finite-difference record, or manifest produces a typed
`SPDE_SLOPE_GAUGE_NOFIT_INFRASTRUCTURE_HOLD` with only the evidence that was
actually materialized.  A mathematically complete callback result that fails
one of the frozen replay tolerances is
`SPDE_SLOPE_GAUGE_NOFIT_REPLAY_HOLD`.  Neither status is a numerical-admission
or ecological-model outcome.  A killed or otherwise non-reporting child has
no inferred callback result; its parent receipt records only the observed
process boundary.

Every child receipt records the exact `Rscript` command and arguments,
parent/child process IDs, started/ended timestamps and elapsed seconds, exit
status or signal, fixed deadline, and the disposition of stdout/stderr.  The
parent atomically copies the child receipt and any returned result into its
staging root before constructing its own receipt.  It retains stdout/stderr
only as bounded diagnostic fields or content hashes, never as a substitute for
the child RDS.  The root validator rereads the root receipt, child receipt,
result, session file, retained materializer, and manifest; it requires the
exact regular-file inventory with no extras, directories, or symlinks, checks
every declared hash, and then recomputes the gate status.  Any missing,
extra, partial, or symlinked artifact is infrastructure HOLD and no pass token
is printed.

The private materializer requires `processx` before it creates a staging root,
so the parent—not merely the R child—enforces the 1800-second deadline.  If
that supervisor is unavailable, the gate is not started.

The final root always has one empty, real `.attempt-started.claim` directory
and the regular files `child-receipt.rds`, `file-manifest.csv`,
`materializer.R`, `root-receipt.rds`, `session-info.rds`, and
`time-estimate.md`.  A reporting child adds exactly `no-fit-result.rds`; a
hard non-reporting child does not.  The root receipt has the ordered fields
`schema`, `gate`, `root`, `commit`, `status`, `reason`, `predecessor`,
`sources`, `dll`, `controls`, `parent_stage`, `process`, `child_result_md5`, and
`time_estimate_md5`.  The process receipt has the ordered fields `schema`,
`command`, `arguments`, `parent_pid`, `child_pid`, `started_at`, `ended_at`,
`elapsed_s`, `deadline_s`, `timed_out`, `exit_status`, `signal`, `stdout_md5`,
`stderr_md5`, and `child_result_md5`.  The receipt binds the copied
`materializer.R` to the committed materializer source as well as binding every
other source MD5.  A readable child result that fails its own exact schema or
audit is retained only as
`SPDE_SLOPE_GAUGE_NOFIT_INFRASTRUCTURE_HOLD / child_evidence_invalid`; a
non-reporting child is
`SPDE_SLOPE_GAUGE_NOFIT_INFRASTRUCTURE_HOLD / child_process_no_result` and has
no inferred DLL, factory, callback, or finite-difference evidence.

### V1 forensic closeout and V2 successor boundary

`PAPER1_SPDE_SLOPE_GAUGE_NOFIT_GATE_V1` is consumed and immutable at canonical
root `dev/isdm-package-recovery/results/PAPER1_SPDE_SLOPE_GAUGE_NOFIT_GATE_V1`.
At source commit `4eb710ed12cc5346d4ed4bcae0e8182d8ba3fbc3`, its complete
top-level inventory is six regular, non-symlink files, one ordered manifest,
and one real empty non-symlink `.attempt-started.claim` directory:

| path | MD5 |
| --- | --- |
| `child-receipt.rds` | `e5481430c170b8f3fa5c1eb1da33e27e` |
| `no-fit-result.rds` | `0af4bc98742861950896c1e79dadb2e0` |
| `materializer.R` | `38548a8e8c18f4e8f89c3e465ace8ad4` |
| `root-receipt.rds` | `1d9b1b0b31a993dc88427ce6989dea85` |
| `session-info.rds` | `e5a10dc9cb603476373cbea8ac84c8ba` |
| `time-estimate.md` | `b3167b86ae6660cd9422ef0b7e151312` |
| `file-manifest.csv` | `fd83183495b88a37c677682b9f9e6015` |

V2 must reread the V1 receipt, ordered manifest, and every listed byte from
that root; require the inventory and empty claim directory exactly; and bind
the receipt's V1 commit, terminal status
`SPDE_SLOPE_GAUGE_NOFIT_INFRASTRUCTURE_HOLD`, and reason
`child_evidence_invalid`.  This packet is not numerical, curvature, recovery,
or ecological evidence.

The sufficient source cause is narrow: V1's parent supplied only the retained
receipt and state MD5 to a complete-child predicate that also requires the
locked predecessor root and commit.  It is not a claim that the V1 child result
can be promoted or reused.  A successor is permitted only as the separately
named `PAPER1_SPDE_SLOPE_GAUGE_NOFIT_GATE_V2`, with a fresh root, stage prefix,
root/process/child schemas, receipt, manifest, and one child launch.  Its
receipt must consume the complete V1 forensic packet above and reject a
missing, substituted, rehashed, non-regular, or non-empty-claim packet.  It
must also retain the same MSPDE V3
root/commit/state/DLL/control/FD-order/tolerance bindings.  The sole execution
change is propagation of the full locked predecessor verdict
`root,commit,receipt,state_md5` into the already fixed child predicate.
Every V2 child receipt also retains the exact reached stage
(`v1_forensic`, `predecessor_bytes`, `dll`, `historical`, `factory`,
`callback`, `audit`, `release`, or `complete`). A caught deadline is a typed
`time_limit_exceeded` infrastructure record only when its retained stage,
predecessor, DLL, and object/release counts satisfy that stage's exact partial
schema; otherwise the parent records `child_evidence_invalid` rather than
inferring callback evidence.

V2 must not inspect or use V1's retained objective, gradient, FD values,
transformed values, or child status to select a chart, tolerance, callback
count, or later trust-region control.  The literal V1 subset
`predecessor[c("receipt", "state_md5")]` must fail V2 validation; the complete
V2 projection must pass a
production-shaped acceptance test.  V2 is still a non-scientific no-fit gate.
Its failure ends this no-fit adapter line; it authorises neither a V3 no-fit
retry nor a trust-region/numerical attempt.

## Future estimator boundary

If the pure map and full sign-orbit checks pass, a later, separately reviewed
execution design may specify one full-22-dimensional trust-region/Newton
procedure in \(\varphi\)-coordinates.  It must predeclare its radius
schedule, acceptance rule, exact-gradient callback count, candidate selection,
hard time limit, terminal schemas, and a fresh source-gate root.

At the retained nonstationary state, its transformed Hessian must not be
approximated by the congruence term alone.  It must use either

\[
H_\varphi=D T^\top H_\theta D T+
\sum_{k=1}^{22}g_{\theta,k}\nabla_\varphi^2T_k
\]

with every term retained and validated, or a separately predeclared symmetric
finite-difference construction of the already transformed exact gradient
\(G\).  A raw-coordinate Hessian, covariance inverse, or MNCB
finite-difference trace cannot be relabelled as \(H_\varphi\).  The future
design must test the chosen construction on a quadratic map harness and at
the frozen live state before an attempt is authorised.
It must not use the incomplete MNCB finite-difference prefix or either BFGS
partial trace to choose any control.

The later procedure must additionally lock all of the following to the MSPDE
predecessor: fixture and seed; data/map/random declarations; TMB source and
DLL contents; the 22 raw coordinate IDs; the starting objective and gradient;
all numerical-admission thresholds; and the recovery truth.  Its receipt must
bind the complete predecessor packet above, current runner/contract/design
and map-helper hashes, the actual DLL path/content hash, and both the raw and
transformed candidate vectors, gradients, objectives, and covariance axes.
It must retain the complete transformed and raw candidate states.  Its
numerical admission must be estimator-specific and cannot upgrade, repair, or
reinterpret the historical MNCB/BFGS records.

No recovery, Paper 1 result, model-performance claim, or public statement is
allowed unless that later estimator seals a provenance-valid numerical
admission terminal first.
