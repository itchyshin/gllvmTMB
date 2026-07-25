# VA first light — Design 85 R3 prototype vs three oracles

**Date:** 2026-07-25
**Branch:** `claude/va-implementation-20260725` (worktree
`/Users/z3437171/local-scratch/worktrees/gllvmtmb-va-impl`)
**Script:** `dev/va-first-light.R` (scratch, not a test file)
**Purpose:** one diagnostic number — is the existing Design-85 R3 Gaussian-VA
prototype's ELBO broadly right, so the maintainer can estimate the remaining
work honestly, rather than re-designing a VA route from nothing.

## 1. What the prototype is and does

`R/va-r3-proto.R` (625 lines, on `main`, zero `@export`) is a deliberately
fenced, research-only Gaussian variational-approximation objective for a
**single, narrow model cell**:

- **Family:** complete multi-trial binomial-logit responses only
  (`n_trials >= 2` everywhere) or a Gaussian identity-link "algebra anchor"
  (`family = "gaussian_anchor"`). Bernoulli (`n_trials = 1`) is rejected
  outright by `.va_r3_validate_data()` (`R/va-r3-proto.R:208-214`) and by the
  C++ template itself (`inst/tmb/gllvmTMB_va_r3.cpp:142-148`).
- **Structure:** ordinary loadings-only `latent(..., unique = FALSE)`
  (glmmTMB's `rr()`) — i.e. `Sigma = Lambda Lambda^T` with **no** `diag()`/Psi
  term. `unique = TRUE`, `psi`, `structured`, `provider`, `lv`, and `missing`
  are all explicitly rejected (`R/va-r3-proto.R:196-201`).
- **Data shape:** a strictly complete N-unit x T-trait grid — every
  unit-trait cell present exactly once (`inst/tmb/gllvmTMB_va_r3.cpp:150-153`).
- **Rank:** `q` in `1..6`, `q <= T`.

Mechanically: `Lambda` is packed as a `T x q` matrix with a zero strict upper
triangle (`.va_r3_pack_theta_rr`/`.va_r3_unpack_theta_rr`), the per-unit
variational posterior is `q(u_i) = N(m_i, L_i L_i^T)` with `L_i` a `q x q`
Cholesky factor, and the ELBO is

```
ELBO = sum_i E_q[log p(y_i | u_i)]  -  sum_i KL(q(u_i) || N(0, I_q))
```

with the binomial expected log-likelihood term evaluated by 1-D physicists'
Gauss-Hermite quadrature (`H` in `{15, 25, 61}`) via a stable
softplus-expectation routine that switches to a small-`v` polynomial
(heat-kernel) expansion below `v = 1e-6` so AD never differentiates
`sqrt(v)` at zero. The TMB template's actual scalar objective
(`inst/tmb/gllvmTMB_va_r3.cpp:299-304`) is the **negative** ELBO:

```cpp
Type elbo = expected_loglik - total_kl;
Type negative_elbo = -elbo;
...
return negative_elbo;
```

`.va_r3_fit()` runs **four deterministic starts**, applies an `nlminb` +
conditional-BFGS polish, and only **admits** ("healthy") a fit when at least
3 of 4 starts converge (`max|gradient| < 1e-4`) and the best three objectives
agree to `<= 1e-6`, plus a variance-domain guard (`max projected variance
<= 4`). There is no public API, export, NAMESPACE entry, or `gllvmTMB` S3
class attached to its output — it returns a plain list with `status`,
`objective_type = "ELBO_GH"`, `best`, `report`, health diagnostics, and
source/checksum provenance.

## 2. What the NO-GO record says (read in full before this run)

- `docs/dev-log/audits/2026-07-20-va-r3-pilot-no-go.md`: **NO-GO; retain
  Laplace.** The stated reasons are procedural/experimental-design defects,
  **not** a numerical objective defect: (a) the pilot's rank-selection step
  used ML/BIC hand-off (Gate 4), not the required fixed-rank Gate-3 known-DGP
  comparison; (b) 8 of 50 applicable q1/q2 replicates failed the predeclared
  optimiser health gate; (c) a classifier bug initially mis-scored one healthy
  start. The audit explicitly states: "the ELBO, coordinate map, Gaussian
  anchor, O3 comparisons, and quadrature checks are coherent" (Noether lens) —
  i.e. the prior review believed the objective itself was fine and the
  problem was the experimental protocol around it.
- `docs/dev-log/after-task/2026-07-20-va-r3-prototype-no-go.md`: same
  decision; "Known Residuals" (§10) explicitly states the arc provides **no
  VA validation** of any kind. Nothing in either document reports an ELBO
  vs. Laplace sign check — that comparison was never made. This run is new
  evidence, not a re-trip of a documented failure.

## 3. Data and seed

Single fixed-seed simulation, chosen to be the narrowest cell the prototype
can actually accept (forced, not a free choice — see §1):

- **Family:** binomial-logit, `n_trials = 12` (multi-trial; NOT sparse
  binary — Bernoulli is rejected by the prototype's own gate).
- **Structure:** ordinary `rr()`-only (loadings, no Psi/diag), matching the
  prototype's sole admitted structure.
- **Size:** `N = 80` units x `T = 6` traits, `q = 2`, complete grid
  (`N*T = 480` cells). Sits inside the task's 60-100 x 6-trait target and
  matches `tools/va-r3-pilot.R`'s own q2 pilot cell in kind (scaled slightly
  up in `N`/`T`).
- **Seed:** `20260725` (`set.seed(20260725L)` in `dev/va-first-light.R`).
- **True parameters:** `beta = seq(-0.45, 0.45, length.out = 6)`;
  `Lambda` lower-triangular, diagonal `0.82, 0.86`, off-diagonal
  `0.30 * sin(...)` — the same generating convention as the pilot's
  `make_dgp()`.

## 4. The four fits and their objectives

| # | Method | Route | Objective (log scale, higher = better fit) | Wall time |
|---|---|---|---:|---:|
| 1 | VA prototype | `.va_r3_fit(q = 2, H = 61, rank_source = "fixed_fixture")` | **ELBO = -1014.9671261098** | 26.4 s (incl. one-time TMB compile) |
| 2 | gllvmTMB (own engine) | Laplace, `latent(0+trait\|unit, d=2, unique=FALSE)` | logLik = -1015.9431193939 | 0.89 s |
| 3 | `gllvm` | `method = "VA"` (its own default), `Ntrials` matrix | logL = -1021.1530240121 | 0.09 s |
| 4 | `glmmTMB` | Laplace, `rr(0+trait\|unit, d=2)` | logLik = -1015.9431193886 | 0.13 s |

**Sign reconciliation (Design 85 §10 warning heeded):** `.va_r3_fit()`'s
stored `best$objective` is the **minimized negative ELBO** (`nlminb`
minimizes `obj$fn`, which returns `negative_elbo`; see
`inst/tmb/gllvmTMB_va_r3.cpp:301-304`). It is *not* directly comparable to
`fit_gt$opt$objective` (gllvmTMB's own negative marginal log-likelihood under
Laplace) without flipping its sign. The table above already reports the
sign-corrected value: `ELBO = -best$objective`. All four rows are now on the
same "log-scale, higher is better" axis and can be compared directly.

All four fits **converged cleanly with zero warnings** captured verbatim
(only console noise: the package's own experimental-lifecycle startup
banner and the one-time C++ compiler invocation line; `grep -i warning` over
the full run log matches nothing else). The VA fit is not a degenerate
optimum: 3 of 4 starts converged to the identical objective (`1014.967` to
6 significant figures, `max|gradient|` between `4.6e-5` and `7.9e-5`), and
the recovered `beta` (`-0.502, -0.376, -0.088, 0.136, 0.209, 0.401`) and
`Lambda` diagonal (`-0.871, 1.021`, sign-flipped on the first column, which
is an admissible rotation/reflection ambiguity of a loadings-only structure)
track the true generating values in direction and rough magnitude.

## 5. The three gaps

```
gap_model  = gllvmTMB_logLik - glmmTMB_logLik   = -1015.9431193939 - (-1015.9431193886) = -0.0000000053
gap_method = gllvm_logL      - gllvmTMB_logLik  = -1021.1530240121 - (-1015.9431193939) = -5.2099046182
gap_elbo   = VA_ELBO         - gllvmTMB_logLik  = -1014.9671261098 - (-1015.9431193939) = +0.9759932841
```

- **`gap_model` ~ 0** (5e-9, at TMB numerical-agreement tolerance): gllvmTMB's
  own Laplace fit matches `glmmTMB`'s `rr()`-only Laplace fit on the *same
  formula and data* to the usual ~1e-4-and-tighter cross-check tolerance used
  elsewhere in this repo (`tests/testthat/test-stage2-rr-diag.R`). Per the
  oracle table in the task brief, this says **the model is not the problem**
  — gllvmTMB's own likelihood construction for this cell is correct, so any
  discrepancy found below is attributable to the VA route, not to a
  latent/model-side bug.
- **`gap_method` = -5.21**: `gllvm`'s own independently-implemented VA method
  sits **5.21 log-lik units below** the shared Laplace anchor. That is the
  *expected sign* for a valid variational lower bound (ELBO <= true log p(y),
  and Laplace approximates true log p(y) closely here given `gap_model ~ 0`
  against an independent implementation). `gllvm`'s VA method behaving this
  way is a sanity check that the "VA should sit below Laplace" expectation is
  itself reasonable on this exact DGP, not an artifact of this repo's own
  code.
- **`gap_elbo` = +0.976**: the R3 prototype's ELBO sits **ABOVE** the shared
  Laplace anchor by about 1 nat, not below it.

## 6. Is the ELBO below Laplace?

**NO.** `VA_ELBO (-1014.967) > gllvmTMB/glmmTMB Laplace logLik (-1015.943)`
by `+0.976`. A variational ELBO is a mathematically guaranteed lower bound on
the true marginal log-likelihood (`ELBO = log p(y) - KL(q||p(u|y)) <= log
p(y)`, since KL >= 0 always). The Laplace logLik here is not the exact
`log p(y)` either, but two independent facts argue it is a very close proxy
on this cell: (a) it agrees with an entirely separate implementation
(`glmmTMB`) to 5e-9, and (b) `gllvm`'s own independently-coded VA lower bound
correctly lands *below* it (by 5.21), in the direction the inequality
predicts. The R3 prototype landing *above* that anchor by nearly a full log
unit, while the other three fits all correctly straddle it, is the single
sharpest signal in this comparison and it points the wrong way.

This is not explained by a degenerate or non-converged fit (§4): the
objective is stable across 3 independent starts to 1e-9-scale agreement, and
recovered parameters are in the right neighbourhood of truth. That rules out
"nlminb stopped at a bad local point" as the explanation; it points instead
at the ELBO's own construction (the expected-log-likelihood quadrature term,
the KL term, or their combination) computing a value that is not, in fact, a
valid lower bound on this cell's log-likelihood.

## 7. Edits made to the prototype

**None.** `dev/va-first-light.R` calls `.va_r3_fit()` and the surrounding
helpers exactly as they exist on `main`; no change was needed to drive it on
this fixture. `R/va-r3-proto.R` and `inst/tmb/gllvmTMB_va_r3.cpp` are
untouched.

## 8. Warnings, verbatim

None were raised by any of the four fits (VA prototype, gllvmTMB, `gllvm`,
`glmmTMB`). The full captured run log
(`/private/tmp/claude-503/-Users-z3437171-Dropbox-Github-Local-gllvmTMB/ed064c95-cada-4788-83e8-ac5c0503c042/scratchpad/va-first-light-run1.log`,
local scratch, not committed) contains only: the package's own
experimental-lifecycle startup banner, and the one-time TMB `clang++` compile
invocation lines (which include the compiler flag literal
`-DTMB_EIGEN_DISABLE_WARNINGS`, a build define, not a runtime warning). `grep
-i warning` over that log matches nothing else. Absence of a warning here is
not reassuring on its own — the task brief is right to flag that a wrong
ELBO "returns plausible numbers without erroring," and that is exactly what
happened: a clean, silent, well-converged, wrong-signed number.

## 9. Verdict

**OBJECTIVE-SUSPECT.**

The prototype runs, converges stably from multiple starts, and recovers
roughly-correct parameters — so this is not a "cannot drive" result. But its
central mathematical property — the ELBO must lower-bound the true marginal
log-likelihood — fails on this fixture by a margin (+0.976 log units) far
larger than the ~5e-9 agreement gllvmTMB shows against an independent
Laplace implementation, and in the opposite direction from `gllvm`'s own
independently-implemented VA method on the same generative model. One seed,
one cell is not exhaustive evidence of a specific bug location, but it is
sufficient to say the objective does **not** look broadly right as currently
constructed, and that estimating the remaining VA work as "polish an
already-correct ELBO" would be premature. Before any further VA investment,
the next step should isolate which term is responsible (most likely
candidates, in order of suspicion given the code read in §1: the
Gauss-Hermite softplus-expectation quadrature/expansion switch, or the
`v_it = ||L_i' lambda_t||^2` projected-variance construction) rather than
scaling this prototype toward `q=4/q=6` as the NO-GO record's "reconsider
only under new evidence" clause would otherwise invite.
