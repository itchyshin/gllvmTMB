# Design 86 Arc 5 — Gate-A diagnostic specification

**Status:** frozen for the controlled-probe lane; this is not a Gate-2
amendment or runner authority.  It was derived from the two immutable smoke
records and the static source audit at `e0e16079`.

## Question and decision rule

The question is deliberately narrower than “how can the smoke be made to
pass?”: does one falsifiable numerical mechanism explain the repeated failure
of the frozen health screen?  A `GO` requires every receipt, mapping, AD, and
optimizer-semantic check below, plus exactly one candidate change whose
prediction is borne out by the controlled EVA probe.  A missing result, a
mixed result, or two competing mechanisms is `INCONCLUSIVE`, and stops the
arc without a V2 amendment or runner invocation.

Nothing in this specification changes the historical records, their health
threshold (`max_abs_gradient < 1e-4`), their starts, their seeds, their
denominator, or their interpretation.

## Locked evidence

The historical root is
`docs/dev-log/simulation-artifacts/2026-07-22-design86-gate2-anchor-smoke-rerun2`;
the V1 root is
`docs/dev-log/simulation-artifacts/2026-07-23-design86-gate2r-v1-one-seed`.
Their input-manifest digests are respectively
`dc01e37b02634f5b0de02f6c1b83e2941aafeb53ca5e4969f06a4ec62d585f63` and
`c5a3fbb93f04aa58ea725c73a19ec3d1d7a8d77797941d7c63b608ee896c9fb8`.

Both records have four code-zero but unhealthy starts and no selected winner
or interval.  Their source, driver, runner, and realised-input provenance is
not identical, so they are comparable frozen-contract failures, not executable
replications.  The common engine and DLL hashes therefore cannot establish an
engine-level cause.

The receipt field called `output_manifest_sha256` is cryptographically linked
to the corresponding result JSON, not to a stored output-manifest object:
`dev/design86-gate2-eva-runner.R` writes
`sha256(result_path)` into that field.  This is a schema-name discrepancy, not
a missing historical artifact.  It is not corrected retrospectively.

## Static coordinate ledger

For V1 (`N = 80`, `T = 12`, `q = 2`), the 424-vector has the source-defined
flat block map below.  Indexes are one-based in the flattened parameter
vector.

| Block | Flat indices | Role / transform |
|---|---:|---|
| `beta` | 1 | unconstrained fixed effect |
| `theta_rr` | 2–24 | unconstrained, signed lower-triangular reduced-rank loading coordinates |
| `a` | 25–184 | unconstrained variational means |
| `log_A_diag` | 185–344 | log-Cholesky diagonals; exponentiated to positive Cholesky diagonals |
| `A_off` | 345–424 | unconstrained strictly-lower Cholesky entries |

All recorded coordinates above 1,000 are in `theta_rr`, rather than either
transformed covariance block.  The static map identifies them as raw loading
entries, but the controlled probe must also demonstrate the TMB flattening
round-trip used to produce the named ledger.

## Controlled probes

Each probe is deterministic, labelled `NON_GATE2`, and uses the tiny frozen
Gate-1 EVA objective only.  It must not call either Design-86 runner, construct
a Gate-2 input, use a smoke seed, write beneath a historical or prospective
artifact root, score a gate, or invoke a Laplace fit.  Compilation of the tiny
prototype in the temporary build directory is permitted solely to obtain its
AD objective; it is not a change to the package engine.

| ID | Hypothesis | Procedure | Predeclared pass / stop rule |
|---|---|---|---|
| A0 | Receipt semantics are closed | Recompute every manifest and result SHA; source-trace the receipt assignment | Pass only if each input link and each result-digest link agrees; otherwise `PARK` |
| A1 | Parameter mapping is known | `parList` round-trip on the controlled TMB objective, then compare the ordered blocks against the source ledger | Pass only if flattened coordinates reproduce exactly and every historical extreme is named; otherwise `PARK` |
| A2 | The TMB AD gradient is locally faithful | At two fixed, interior controlled points, compare `obj$gr` with central differences at `h = 10^-4, 10^-5, 10^-6` per coordinate | Pass only if two adjacent finite step sizes have maximum normalized discrepancy <= `1e-4`, with no step-size-instability flag; otherwise `PARK` |
| A3 | Code-zero/gradient divergence is interpretable | Run the frozen four-stage `nlminb`, `nlminb`, `nlminb`, BFGS trace on a convergent quadratic and a nonstationary linear objective | Pass only if the trace separately records convergence code, message, and recomputed gradient, and the nonstationary case does not appear healthy; otherwise `PARK` |
| A4 | A single scaling mechanism is discriminating | On the same controlled EVA objective and a predeclared raw-loading scale transformation, compare unscaled versus transformed-coordinate optimization after mapping back to original coordinates | `GO` candidate only if one formulation consistently satisfies the stated health predicate while the counterpart does not, reaches the same controlled target within `1e-8`, and A1–A3 passed.  No separation is `INCONCLUSIVE`. |

For A2, normalized discrepancy is
`abs(g_AD - g_FD) / (1 + pmax(abs(g_AD), abs(g_FD)))`.  The tolerance is an
engineering screen for this controlled code path, not an inference threshold
or a general proof of likelihood correctness.  The finite-difference record
must retain all step sizes, objective evaluations, per-coordinate discrepancies,
the maximum, the median, and any failed coordinates.

## Candidate-change discipline

Before any optimization is evaluated, the probe ledger must state one raw
loading scaling parameterization and its predicted signature.  The frozen
candidate is `z_theta = theta_rr / 10`: the transformed wrapper maps back by
`theta_rr = 10 * z_theta`, maps the AD gradient by multiplication by 10, and
uses the `bernoulli_q2` Gate-1 fixture with its original finite parameter
vector except that all raw loading coordinates start at 5.  The prediction is
limited and falsifiable: if loading-coordinate scale drives the observed
nonstationarity, the transformed trace will be healthy after back-transformation
where the raw trace is not, while both reach the same controlled objective
within `1e-8`.  The candidate may affect only the controlled objective wrapper;
it cannot relax the health threshold, add starts, choose a different seed,
change historical scoring, or modify the runner, package C++, or public API. A
controlled scaling effect is not by itself authority to modify V1: the later
Gate-A review must conclude that it identifies a single mechanism relevant to
the historical failure.

AD/finite-difference agreement establishes only local derivative agreement for
the compiled controlled objective.  Similarly, an optimizer code documents
the optimizer’s termination condition, not stationarity, identifiability,
model correctness, a global optimum, recovery, coverage, or Gate-2 admission.

## Gate-A review and stop conditions

Gauss and Rose independently review the raw probe receipt.  `GO` requires A0–
A4, one mechanism, one justified prospective change, and no boundary breach.
`PARK` applies to a failed integrity, mapping, AD, or telemetry check;
`INCONCLUSIVE` applies to a sound but nondiscriminating probe.  Either outcome
closes Arc 5 with an audit report only.

Even a `GO` authorizes neither a V2 draft nor a run.  Those require a fresh,
explicit maintainer authorization of the exact amendment/fixture hash (Gate B)
after this review.

## Method sources

The controlled checks use the documented scope of
[TMB automatic differentiation](https://kaskr.github.io/adcomp/Introduction.html),
the local finite-difference convention in
[`numDeriv::grad`](https://rdrr.io/cran/numDeriv/man/grad.html), and the
documented termination/scaling semantics of
[`stats::nlminb`](https://svn.r-project.org/R/trunk/src/library/stats/R/nlminb.R)
and [`stats::optim`](https://stat.ethz.ch/R-manual/R-devel/library/stats/html/optim.html).
These sources motivate diagnostics; they do not supply a Design-86 remedy.
