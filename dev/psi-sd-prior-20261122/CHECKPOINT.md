# R Psi SD prior checkpoint, 2026-11-22

## 1. Purpose and status

The R adapter adds normalized Gamma(shape, rate) densities on selected natural
Psi SDs. This phase has implementation and pure mathematical checks. Native
package validation, generalized-interface integration, and release are open.

## 2. Owner and source

Owner: bounded Codex R adapter, dispatched by the Psi lane coordinator.
Worktree: `/Users/z3437171/.codex/worktrees/psi-sd-r-20261122/gllvmTMB`.
Branch: `codex/psi-sd-prior-20261122`; base main pin
`49cf245d59f039818d16a8beaed5e48a4bde375c`. The coordinator explicitly requested
a local commit after this checkpoint; no push is authorized.

## 3. Ownership checks

The canonical contract, efficiency instructions, route manifest, active-lane
split, coordination board, Shannon checklist, and prior convergence contract
were read. Graft queries ran at the same source pin in the original worktree.
The file preflight found no missing-ref changes for the implementation path;
26 open R lanes and a dirty generalized-prior worktree were recorded.
`lane_lease.sh --claim` granted identity `codex-psi-sd-r-20261122` only
`R/kernel-psi-sd-priors.R`, `tests/testthat/test-psi-sd-priors.R`, and this
directory. Other lanes' files were not changed.

## 4. Mathematical contract

Each selected `kernel × trait` contributes once. For log SD eta, the penalty is
`rate*exp(eta) - (shape-1)*eta - shape*log(rate) + lgamma(shape)`. The density
is with respect to natural SD, with no log-SD Jacobian. Gamma shape exceeds
one and rate is positive. The source retains data objective, gradient and
eligible Hessian closures separately; Gamma metadata states penalized-criterion
curvature. Primary/published analyses stay unpenalized absent separate approval.

## 5. Changed files and compatibility

The adapter and its test file changed; this directory adds the comparison
driver and two internal receipts. The NULL-prior branch returns its input
object identically. Legacy scale-only half-normal values, gradients, and
Hessians match the original formulas exactly at three scales. The new schema
has exactly kernel, trait, shape, rate; mixed/extra/missing columns, invalid
hyperparameters and duplicate targets fail. Traits/kernels resolve by name.

## 6. Frozen reference

The independently authored oracle is
`/Users/z3437171/.codex/evidence/psi-sd-20261122/oracle`. Its final
`SHA256SUMS` hash is
`437977c4f7834f9bb8815aa0f992dccb13234eaeb6f1cd83abb7dfbbbf9f3fdb`,
verified before edits and again at closeout. The fixture has 4 sites, 3 traits,
2 kernels, fixed observation SD 0.2, and 15 free coordinates. No tolerances
or reference values changed.

## 7. Commands and results

The initial base-R Gamma resolver probe failed with the old scale-only error,
before the adapter change. The final pure command was:

```sh
OPENBLAS_NUM_THREADS=1 Rscript --vanilla dev/psi-sd-prior-20261122/compare.R pure \
  /Users/z3437171/.codex/evidence/psi-sd-20261122/oracle \
  /Users/z3437171/.codex/evidence/psi-sd-20261122/r-pure-final
```

Result: **316/316 checks passed, zero required failures, exit 0**. Full gradient
maximum absolute error was below `1.75e-9`; full Hessian maximum absolute error
was below `2.72e-6`, within the frozen per-entry tolerances. The receipt folder
contains all check rows, source hashes, source diff, oracle manifest and R
session details. The driver checks separate unpenalized and penalized full
derivatives, both kernel orders, exact-zero/near-zero/interior controls,
normalization, units, observation-SD sensitivity, schema failures, and all
specified wrong-prior mutations.

`git diff --check` returned exit 0. Base-R `parse()` checks passed for the
adapter, test file and driver. Targeted source scans used
`kernel_psi_sd_prior|kernel_has_psi|sigma_eps_fixed|log_sd_kernel_diag`,
`prior_held|pd_hessian_unpenalised`, `theta_rr_kernel|kernel_ridge|kernel_scale`,
`diag\(.*\).*1e-8|1e-8.*diag|Ainv_kernel\[|K_used|K_reg`, and
`gll_unpack_rr_loadings|known_sigma_eps.*multi|known_sigma_eps.*kernel|multi.*known_sigma_eps`.

## 8. Native checks still required

No R package fit/test, compiled model, embedded Julia process, or Totoro job
was launched. The existing jobs hold compute priority. After clearance, use
the native smoke command in README, measure it, then estimate the full driver.
The driver is written but unexecuted. The new testthat cases were parsed but
not run. Full package suite/check and normal user workflow remain required.

Native input adds `1e-8 I` to kernels. Literal-input matrix mismatch is recorded
as a separate result. The adjusted effective-covariance route supplies
`K_frozen - 1e-8 I`, proves effective K matches to `1e-12`, and preserves frozen
values/tolerances. It cannot count as literal identical-input parity. Native
loading diagonals are raw; the driver includes both chain-rule terms to
compare with oracle log-loading coordinates.

## 9. Shared integration and unsupported scope

The main generalized-interface owner owns public grammar:
`prior = gamma(mean, shape)`, `class = unique_variance`, `trait = <exact>`,
`kernel = <exact when needed>`, `scale = natural_sd`. `dpar` and `coef` must be
empty or absent. Missing kernel resolves only with one eligible block;
multi-kernel rows require it. Convert rate to `shape/mean`, reject overlap with
the compatibility control, and pass explicit shape/rate to this adapter.

R/gllvmTMB.R, R/fit-multi.R and R/diagnose.R are owned elsewhere. The hard-coded
half-normal warning, roxygen/Rd, fit metadata, common convergence checks,
unpenalized Hessian/prior-held reporting, validation register and public claims
need that owner. Named held parameters should use the adapter's target_names
and specification; repeated internal parameter-block names are ambiguous.
TMB's he() throws for random effects: use marginal likelihood-gradient finite
differences for the unpenalized diagnostic there. Ordinary/source-specific
non-kernel Psi is outside this endpoint. No likelihood C++ or grammar changed.

## 10. Review and definition of done

This is a source/pure-check checkpoint, not a completed package feature.
Implementation is local, not merged; three-OS CI is unrun. New likelihood or
simulation recovery is not claimed; the route adds an R penalty to the existing
Gaussian model. Public docs and a public worked example await integration.
Required package check-log and after-task files are reserved to the main
owner; this receipt supplies their exact evidence. No independent code or
inference review was dispatched by this worker. The coordinator must obtain
the required review before integration/publication.

## 11. Next safest action

Commit only leased files locally, report the new SHA and clean status, then
hand this bounded phase to the coordinator. Run the native smoke only after
resource clearance. Do not edit the generalized, Paper Two, convergence, or
other Psi worktrees. No push, merge, release, campaign, manuscript edit or
external contact is authorized. Prose assessment is NOTASSESSED by the exact
draft validator; the internal self-review is recorded in README.
