# After-task report — Design 95 free-parameter JJ prototype

## 1. Purpose

Test whether the Design 94 fixed-loading JJ kernel remains coherent when q=2
intercepts and identified loadings are free, while keeping the work private.

## 2. Scope

Only complete Bernoulli-logit observations, q=2 diagonal mean-field factors,
fixed trait order, and a local lower-triangular loading convention were used.

## 3. Prior-work boundary

Design 72 showed that VA cannot create information in rank-deficient data;
Design 85 is no-go; Designs 86/90/91 remain terminal.  Design 94 supplied a
fixed-loading kernel only.  None was altered, rerun, or scored.

## 4. Contract and implementation

`docs/design/95-free-jj-variational-arc.md` records the complete profiled-xi
JJ ELBO.  `dev/design95-free-jj-va/src/design95_free_jj_va.cpp` is an
unexported standalone TMB translation unit.  Its decoder imposes positive
leading diagonal loadings and one fixed upper entry; `log_sd` supplies positive
variational scales.

## 5. Tests run

`Rscript --vanilla dev/design95-free-jj-va/run-tests.R` compiled with Apple
clang and TMB 1.9.21 and passed: R/C++ objective equality, finite-difference
gradient agreement, JJ lower bound versus 61-node quadrature exact ELBO,
loading encode/decode, zero-xi limit, non-binary/invalid-loading rejection,
row-permutation invariance, and one fixed-start stability probe.

## 6. Stability diagnostic

The deterministic probe completed with covariance distance `1.236890` from its
known loading covariance.  It has no acceptance threshold and is sizeable. It
is retained specifically to prevent calling this recovery, calibration, or
general numerical-stability evidence.

## 7. Review

Gauss/Noether first failed the incomplete objective contract; the contract was
amended before code. Rose required an explicit private-path allowlist; it was
amended. Fisher/Rose then passed the experimental-only closeout, with the
stated covariance and single-start caveats.

## 8. Scope guard

`git diff c6297589 -- src R man NAMESPACE DESCRIPTION inst vignettes README.md
NEWS.md _pkgdown.yml` was empty.  No shipped C++, R API, documentation,
package test, external comparator, campaign, cluster job, merge, push, or PR
was performed.

## 9. What the result supports

Only a private developer statement: the narrow free-parameter objective and
its local identification transform compile and satisfy the listed deterministic
checks.

## 10. What it does not support

It does not establish recovery, calibration, convergence robustness,
identifiability away from the convention, upstream EVA/VA parity, structured
priors, long format, public availability, likelihood/AIC interpretation, or
integration into `gllvmTMB`.

## 11. Handoff

Branch: `codex/design95-free-jj-variational-20260723`; worktree:
`/private/tmp/gllvmtmb-design95-free-jj`.  Next safe action is a separately
approved recovery-design discussion; it must predeclare a multi-start,
multi-fixture evidence target before any further implementation.
