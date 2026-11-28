# R Gamma Psi SD adapter: bounded implementation receipt

This directory is for the package contributor integrating the optional prior.
The isolated branch extends the existing named-kernel half-normal control;
it does not modify the generalized prior-table owner’s files or any analysis.

For `s = sqrt(Psi[t,t])` and `eta = log(s)`, one selected kernel × trait
contributes `rate * exp(eta) - (shape - 1) * eta - shape * log(rate) +
lgamma(shape)` to the negative criterion. Its gradient is
`rate * exp(eta) - (shape - 1)` and its diagonal Hessian entry is
`rate * exp(eta)`. The other prior derivatives are zero. This is a normalized
Gamma density on natural SD, without a log-SD Jacobian, used in a penalized/MAP
criterion. It does not define a full posterior or calibrated sampling intervals.

The new low-level table has exactly `kernel`, `trait`, `shape`, and `rate`.
Shape must be finite and greater than one; rate must be finite and positive.
The old `kernel`, `trait`, `scale` table retains its half-normal density.
Ambiguous schemas and duplicate targets are errors. The generalized interface
owner will map `gamma(mean, shape)` to explicit shape/rate, using
`class = unique_variance`, exact `trait` and `kernel`, and `scale = natural_sd`.
Nonempty `coef` or `dpar` is rejected. A missing kernel resolves only with
exactly one eligible unique-variance block. The owner must reject collisions
with this compatibility control. Mixed density tables are outside
this adapter. Omitted targets remain unpenalized.

## Evidence and commands

The source pin is `49cf245d59f039818d16a8beaed5e48a4bde375c`, on local branch
`codex/psi-sd-prior-20261122`. The oracle directory is
`/Users/z3437171/.codex/evidence/psi-sd-20261122/oracle`; its final manifest
SHA256 is `437977c4f7834f9bb8815aa0f992dccb13234eaeb6f1cd83abb7dfbbbf9f3fdb`.
The independent oracle was frozen before implementation comparison.

From this worktree, the pure check takes about ten seconds on the current Mac:

```sh
OPENBLAS_NUM_THREADS=1 Rscript --vanilla dev/psi-sd-prior-20261122/compare.R pure \
  /Users/z3437171/.codex/evidence/psi-sd-20261122/oracle \
  /Users/z3437171/.codex/evidence/psi-sd-20261122/r-pure
```

The current pure receipt contains 316 passing checks, with zero failures. It
uses base R matrix calculations and finite differences, Python JSON input, and
the source adapter; it does not load the package or start Julia. The checks
cover five interior and six near-zero points, both kernel orders, the complete
15-coordinate gradient and Hessian including all cross terms, separate data
likelihood/prior contributions, seven exact-zero unpenalized references,
fixed observation-SD sensitivity, normalization, units, deliberate mutations,
invalid schemas, and exact half-normal density/derivative identity. The source
and test files parse; `git diff --check` is clean. The initial Gamma schema
probe failed under the old scale-only validator before the source change.

After resource clearance, run the normal-entry-point smoke first:

```sh
OPENBLAS_NUM_THREADS=1 Rscript --vanilla dev/psi-sd-prior-20261122/compare.R native \
  /Users/z3437171/.codex/evidence/psi-sd-20261122/oracle \
  /Users/z3437171/.codex/evidence/psi-sd-20261122/r-native-smoke smoke
```

Omit the final `smoke` for the full fixed-point driver, using a fresh output
directory. Neither native command has been run. Measure the smoke before
estimating and launching the full check. Native mode uses `devtools::load_all`
and the public fitter with zero optimizer iterations to build the objective;
it separately exercises the prior through `gllvmTMBcontrol`. It prevents
attaching a second prior to that public objective.

The native builder adds `1e-8 I` to supplied kernels (`R/fit-multi.R:5076`).
The literal-input route records that mismatch against the frozen zero-ridge
oracle and cannot establish identical-input parity. A separate adjusted route
supplies `K_frozen - 1e-8 I`, writes input/effective matrices, and requires the
effective matrix to equal the frozen kernel to `1e-12`. All frozen values and
tolerances remain unchanged. Raw R loading diagonals are transformed into the
oracle’s log-loading coordinates with the full second-order chain rule.

## Remaining integration gates

Native package checks, the full suite, and any fit/recovery claims remain
pending resource clearance. Ordinary/source-specific non-kernel Psi targets
are unsupported by this named-kernel endpoint. Public roxygen/Rd, capability
register, fit warning text, and adopted convergence/reporting changes remain
with the generalized-interface owner. The existing warning says half-normal
and must change before Gamma fits are offered to users. The adapter stores
normalized-density metadata and the unpenalized objective/gradient. It stores
an unpenalized Hessian only when TMB has no random-effect block; on Laplace
models, the diagnostics must difference the unpenalized marginal gradient.

Primary and published analyses remain unpenalized unless separately approved.
Do not select this prior in response to an observed boundary fit. No package
fit, simulation campaign, push, merge, release, manuscript edit, or
external message was performed by this bounded adapter task.

Draft review: self-review, 2026-11-22, whole internal receipt; perceived
formulaic style 2/10 (moderate confidence). The exact commands and pending
native checks make the limits concrete; no prose repair identified. Science:
checked against the frozen specification. Facts: checked against source and
the pure receipt. External references: not applicable. Exact-draft assessment
validator not run: NOTASSESSED.
