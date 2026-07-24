# After-task report — Design 94 Jaakkola--Jordan variational prototype

## 1. Purpose

Implement and test a narrow, private C++ Bernoulli-logit variational objective
that is more defensible than the historical raw Taylor-EVA surrogate.

## 2. Scope

Fixed intercepts and loadings, `q = 2`, per-observation diagonal Gaussian
variational factors only.  No package source, API, documentation, long-form
mapping, structured prior, recovery campaign, or upstream-parity claim.

## 3. Inputs and provenance

The research record is `docs/design/94-ranga-research-record.md`; the exact
equation contract is `docs/design/94-jj-variational-prototype.md`.  The C++
file is new private developer code, not copied upstream code.

## 4. Implementation

`dev/design94-jj-va/src/design94_jj_va.cpp` evaluates the fixed-loading
Jaakkola--Jordan lower-bound negative ELBO with unconstrained `log_sd` and
`sd = exp(log_sd)`.  `jj-oracle.R` independently implements the same
mathematical contract.

## 5. Verification

`Rscript --vanilla dev/design94-jj-va/run-tests.R` passed after compiling with
Apple clang and TMB 1.9.21.  It checked C++/R objective equality, autodiff
against central finite differences, the JJ bound versus 61-node normal
quadrature of the exact ELBO, and a finite stationary optimisation after BFGS
refinement.

## 6. Numerical choices

`xi = sqrt(mu^2 + v + 1e-12)` is a deterministic positive stabilizer.  The
test keeps an absolute gradient threshold of `1e-5`; it did not relax that
threshold when `nlminb` reported relative convergence, and instead applied
deterministic BFGS refinement.

## 7. Evidence outcome

The narrow compiled prototype passes its deterministic contract.  This is
experimental developer evidence only; it is not admission of EVA, VA, or a
new estimator.

## 8. Deliberately not run

No Design 86--93 artifact was altered or rescored.  No DGP, recovery smoke,
multi-seed campaign, `gllvm` fit, public test suite, package compile, Totoro,
DRAC, GitHub Actions, merge, push, or PR was run.

## 9. Scope and provenance audit

`src/gllvmTMB.cpp`, `R/`, `DESCRIPTION`, and `NAMESPACE` remain unchanged from
the base commit.  Compiled `.o` and `.so` products are ignored within the new
developer directory.

## 10. Risks and next gate

The bound is only established for the stated fixed-loading, diagonal-Gaussian
prototype.  A future design must first add a scalar known-DGP recovery target
and separately review loading/identifiability parameterisation before package
integration is even considered.

## 11. Handoff

Branch: `codex/design94-jj-va-prototype-20260723`.  Resume with
`Rscript --vanilla dev/design94-jj-va/run-tests.R` in this worktree.  The next
safe action is a maintainer decision on whether Design 95 should test recovery;
it must not be treated as an automatic continuation.
