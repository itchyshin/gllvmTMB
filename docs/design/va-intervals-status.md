# VA interval routes: integration status

**Scope.** This document records the end state of `R/va-intervals.R` after
integrating and closing the defects found by independent verification of the
four interval routes built for the VA coverage-measurement campaign
(`docs/design/va-interval-coverage-campaign.md`). It supersedes the
route-by-route "built"/"verdict" pairs handed to this session as a single,
current status per route.

**Standing invariant, unchanged by this pass.** Nothing in `R/va-intervals.R`
is wired into `confint.gllvmTMB_va()` / `vcov.gllvmTMB_va()` (`R/va-methods.R`).
Both still hard-refuse with their original message ("`calibrated = FALSE`:
the inverse variational Hessian is not calibrated frequentist uncertainty, so
no interval computed from it would have its nominal coverage."). `git diff`
on `R/va-methods.R` and `R/integration-fence.R` is empty. `default_tier`
stays `"gh"`. This is enforced going forward by a dedicated test
(`tests/testthat/test-va-intervals.R`, last `test_that()` block).

All four routes are opt-in and unexported (`gllvmTMB:::.va_*`). All four
hard-code `calibrated = FALSE` in every value they return. None of them fix
VA's documented point-estimate attenuation on discrete data -- a correctly
scaled interval width does not recentre a biased point estimate. None of
them has been measured for coverage; that is the campaign's job, not this
file's.

---

## Route 1: Wald-from-Schur-complement

**Status: BUILT. Usable by the campaign.**

- Entry points: `.va_wald_beta_ci(fit, level = 0.95)`,
  `.va_wald_loadings_ci(fit, T = NULL, level = 0.95)`.
- Statistical basis: inverts the Schur complement
  `H_ff - H_fv H_vv^-1 H_vf` (the same quantity `.va_r3_fixed_information_blocked()`
  computes, and the same quantity `gllvm::se.gllvm()` computes algebraically
  -- cross-checked to reproduce gllvm's numbers to 4-6 significant figures,
  `docs/design/schur-equivalence-check.md`).
- **Assumption the campaign is testing**: the information-matrix equality
  (ELBO curvature == log-likelihood curvature). This route ASSUMES it and is
  therefore the arm expected to fail first if the equality does not hold for
  VA.
- Caveats carried into the campaign: (a) single-tier only; (b)
  `.va_wald_loadings_ci()` targets `Sigma = Lambda %*% t(Lambda)`
  (rotation-invariant) via a first-order delta method, not raw loadings,
  which are unidentified up to rotation/sign; the delta method degrades near
  a rotation ambiguity or a near-zero loading; (c) **incompatible with
  `collapse_variational_cov = TRUE`** (the "A_i collapse" speed optimisation)
  -- fails closed with status `"va_variational_layout_unrecognised"`, not
  silently. A campaign wanting to measure this route on the collapsed
  configuration must fit with `collapse_variational_cov = FALSE` at the
  corresponding extra compute cost, or accept 0% completion on that arm.
- **Fixed this pass**: the shared fit-health gate (see "Cross-cutting fix"
  below) now also covers this route, though no reviewer had flagged it as a
  gap here specifically.
- Not fixed / not in scope: the `collapse_variational_cov = TRUE`
  incompatibility above was left as a documented, fail-closed limitation --
  it does not corrupt data (loud error, not a wrong number) and fixing it
  would mean reworking `.va_r3_variational_index_map()`'s layout assumptions,
  out of scope for this pass.

**Verdict for the campaign: use it.** It is the apples-to-apples arm against
`gllvm::se.gllvm()` and the whole point of running it is to see whether it
fails the way the equality-failure hypothesis predicts.

---

## Route 2: Profile (drop-in ELBO, chi-squared(1)/2)

**Status: BUILT. Usable by the campaign, with a real statistical caveat baked into its own output.**

- Entry point: `.va_profile_ci(fit, name, which = 1L, level = 0.95, ...)`.
- Mechanically sound: `TMB::tmbprofile()` is generic over what `obj$fn`
  computes; it runs on the VA ELBO objective the same way it runs on a
  genuine likelihood.
- **Statistically uncalibrated for two independent, code-documented
  reasons** (see the file-level comment above `.va_profile_ci()` in
  `R/va-intervals.R`): (1) the objective is a BOUND, not a likelihood, so
  Wilks' chi-squared(1) calibration is not established to transfer; (2) the
  profiler profiles the entire variational block out alongside `beta` at
  every grid point, conflating genuine model nuisance parameters with the
  variational family's own free parameters. `calibrated` is hard-coded
  `FALSE`; `basis` states both reasons in the returned object itself, not
  only in a comment.
- Scope restricted to `"beta"` (fixed-effect) entries; `"theta_rr"` (raw
  loadings) is refused with an explicit rotation-non-identifiability message
  -- the rotation-invariant `Sigma` target is a QUADRATIC function of
  `theta_rr`, out of reach of `tmbprofile()`'s linear-only `lincomb=`.
- **Fixed this pass**: no convergence/health gate previously existed --
  `.va_profile_ci()` (like every other route) now refuses via the shared
  fit-health gate (see below) rather than silently profiling an un-admitted
  fit.
- A previously-reported "stale doc comment referencing two non-existent
  sandwich functions" is **no longer applicable**: `.va_sandwich_beta_ci()`
  and `.va_sandwich_loadings_ci()` exist in this file (Route 4, built by a
  concurrent lane in the same session) -- verified by direct grep, not
  assumed.

**Verdict for the campaign: use it, and report `calibrated = FALSE` alongside
every number it produces.** It is the only route in this file that can be
described as "possibly right for reasons we haven't verified" rather than
"right by construction under an assumption we can name" -- treat its
coverage result, whatever it turns out to be, as informative but not
self-explanatory without also checking whether it happens to track the
Wald-from-Schur route's coverage.

---

## Route 3: Bootstrap (simulate-then-refit, percentile)

**Status: BUILT, was NOT_USABLE, now BUILT and usable after two fixes.**

- Entry points: `.va_bootstrap_replicates(fit, y, n_trials, X, unit_id, trait_id, n_boot = 49L, ...)`
  (workhorse), `.va_bootstrap_beta_ci()` / `.va_bootstrap_loadings_ci()`
  (percentile formatters; accept either raw refit args or a saved
  `.va_bootstrap_replicates()` object to reuse one run for both targets).
- Statistical basis: draws fresh unit-level latent scores from the fitted
  `N(0, I_q)` prior, forms a new response through the FITTED `beta`/`Lambda`
  and the ORIGINAL design, refits from scratch, repeats. Assumes the fitted
  generative model is a correct stand-in for the true DGP -- a genuinely
  different failure mode from the information-matrix-equality assumption the
  curvature-based routes make.
- **Two FATAL defects found and fixed this pass:**
  1. **Indexing-convention bug (SERIOUS).**
     `.va_bootstrap_simulate_one()` indexed `Lambda[trait_id + 1L, ]` /
     `U[unit_id + 1L, ]`, silently assuming 0-based input, while this
     package's own calling convention (and its own test suite,
     `rep(seq_len(N), each = T)`) is 1-based. Calling the function exactly as
     its own documentation instructs -- with the SAME `unit_id`/`trait_id`
     used to produce the fit -- made every replicate fail with a swallowed
     `subscript out of bounds`, surfacing only as the generic "every
     replicate failed" message. **Fixed**: the simulator now normalises
     `unit_id`/`trait_id` via `.va_r3_normalise_index()`, the same
     base-sniffing helper `.va_r3_fit()` itself uses internally, so it is
     robust to either base rather than assuming one. Verified: an
     identical-seed check that 1-based and 0-based inputs for the same
     underlying design now produce byte-identical simulated responses
     (`tests/testthat/test-va-intervals.R`).
  2. **No health check on the original fit (SERIOUS).** Now closed by the
     shared fit-health gate (below), which `.va_bootstrap_replicates()`
     inherits automatically because it calls `.va_profile_normalize_fit()`
     on its `fit` argument before anything else.
  3. **Swallowed per-replicate error (MINOR).** The "every replicate failed"
     abort previously gave no indication of the actual cause. Fixed: the
     per-replicate `tryCatch()` handlers now record the first captured error
     message, surfaced in the abort if every replicate fails.
- Caveats unchanged / not in scope for this pass: per-replicate refits
  default to `n_starts = 1`, cheaper but less robust than the original fit's
  own >= 3-healthy-multi-starts health gate -- a replicate landing in a
  different local optimum is caught only if the optimiser itself reports
  non-zero convergence; simulator implemented for binomial-logit,
  binomial_probit-probit, poisson-log only (any other family/link aborts
  loudly, verified by test); percentile CIs are first-order accurate with
  the same `(B-1)/(B+1)` arithmetic ceiling `bootstrap_Sigma()` documents,
  reported as `coverage_ceiling`.

**Verdict for the campaign: usable now.** Both defects that blocked it are
fixed and independently verified. The remaining caveats (single-start
per-replicate refits, three-family simulator coverage) are documented
limitations, not correctness bugs, and were already known before this pass.

---

## Route 4: Sandwich (robust / Huber-White)

**Status: BUILT, was blocking the campaign, now fixed.**

- Entry points: `.va_sandwich_beta_ci(fit, level = 0.95, step = 1e-5, grad_tol = 1e-2)`,
  `.va_sandwich_loadings_ci(fit, T = NULL, level = 0.95, step = 1e-5, grad_tol = 1e-2)`.
  Core: `.va_r3_sandwich_information()` (bread = the Schur complement, same
  as Route 1; meat = `sum_i s_i s_i'` from the per-unit PROFILED score, an
  envelope-theorem argument verified against an independent finite
  difference of the objective to 1.3e-8 agreement).
- **Assumption the campaign is testing**: drops the information-matrix
  equality (unlike Route 1) but keeps the ELBO's curvature as the bread,
  estimating the score variance ("meat") empirically instead. Diagnostic of
  exactly the same suspected defect Route 1 is exposed to, from the other
  side.
- **One FATAL defect found and fixed this pass: no internal stationarity
  gate.** The envelope-theorem argument that licenses treating the raw
  partial gradient as the profiled score is only exact AT a stationary
  point. `.va_r3_sandwich_information()` computed `max_abs_gradient` as a
  diagnostic but never gated on it -- a `par` manually perturbed 4-6 orders
  of magnitude off the fitted optimum (`max|gr|` from 5.7e-5 up to 54) still
  returned `status = "ok"` and a barely-changed, plausible SE, with nothing
  in the output to flag the difference. **Fixed**: `.va_r3_sandwich_information()`
  now takes a `grad_tol` argument (default `1e-2`, generous against every
  converged-fit value seen in this file's own smoke tests -- 1e-4 to 1e-9 --
  and well below the demonstrated drifted values) and returns status
  `"va_non_stationary_gradient"` -- caught by the existing
  `if (!identical(info$status, "ok")) cli_abort(...)` in both wrapper
  functions -- rather than `"ok"`, when the gate is not cleared. Verified by
  a dedicated regression test that perturbs a healthy fit's `$best$par`
  directly (not its `$status` label) and confirms both `.va_sandwich_beta_ci()`
  and `.va_sandwich_loadings_ci()` now refuse.
- This defect was distinct from, and in addition to, the general
  fit-level health gate below: it fires even when the input fit's own
  `$status` says `"healthy"`, because it re-checks stationarity at the exact
  point being differentiated, not just at the label on the fit object.
- Caveats unchanged / not in scope: single-tier only (same partition
  argument as Route 1); does not correct for VA point-estimate bias (a
  sandwich fixes variance, not the centre); on the one fixture tested,
  sandwich SEs were narrower than Route 1's Schur-only SEs (ratio 0.43-0.99)
  -- a real, reportable finding for the campaign to chase across more seeds,
  not a general pattern established here.

**Verdict for the campaign: usable now.** The defect that made this route
blocks_campaign is fixed and independently verified against the exact
adversarial reproduction that found it.

---

## Cross-cutting fix: a single fit-health gate for every route

**Problem found across three separate route reviews** (profile, sandwich,
bootstrap): none of the routes checked whether the `fit` object passed in
had actually cleared `.va_r3_fit()`'s own multi-start health gate
(`fit$status == "healthy"`; the alternative statuses are
`"failed_health_gate"` and `"failed_variance_domain"`,
R/va-r3-proto.R:2388-2394). An un-admitted fit -- one that failed to reach
agreement across >= 3 healthy starts -- produced an interval
indistinguishable in shape from one built on a genuinely healthy fit.

**Fix**: `.va_profile_normalize_fit()` -- the single function every route in
this file already called to accept both a raw `.va_r3_fit()` result and a
public `gllvmTMB_va` fit -- now also checks `raw$status` and aborts with a
clear message when it is present and not `"healthy"`. Because every one of
the four routes' public entry points funnels its `fit` argument through this
function first (`.va_wald_beta_ci()`, `.va_wald_loadings_ci()`,
`.va_profile_ci()`, `.va_sandwich_beta_ci()`, `.va_sandwich_loadings_ci()`,
and -- for the ORIGINAL fit a bootstrap resamples around --
`.va_bootstrap_replicates()`), fixing it once fixed it everywhere, rather
than requiring four separate patches that could drift out of sync.

A hand-built fit object with no `$status` field at all (e.g. a minimal test
fixture) is not refused on that basis alone -- absence of the field is not
evidence of ill health, and several existing/adversarial tests deliberately
construct such objects.

This gate is orthogonal to, and does not substitute for, Route 4's own
internal `max_abs_gradient` stationarity check: the health gate catches "the
FIT was never admitted"; the gradient gate catches "the SPECIFIC point being
differentiated has drifted from stationarity," which can happen even when
`fit$status` still says `"healthy"` (e.g. if a caller mutates `$best$par`
after the fact, as the adversarial review did to find the defect).

---

## What the campaign harness still must do itself

None of the fixes above make any route calibrated, and none of them can:

- Feed only fits it actually wants measured -- the health gate now refuses
  cleanly rather than silently, but a campaign that wants a coverage number
  for the "unhealthy fit" arm specifically must not simply retry until it
  gets a healthy one without recording the retry rate, since a non-trivial
  refit-failure rate is itself part of what a real deployment would see.
- Avoid `collapse_variational_cov = TRUE` when it wants Route 1/Route 4
  coverage (both fail closed on that layout; only Route 2 and Route 3 are
  robust to it, since Route 2 profiles rather than inverting a
  Schur-structured matrix and Route 3 never touches the Hessian at all).
- Interpret every route's output as an instrument reading, not a verdict:
  `calibrated` is `FALSE` everywhere in this file, by design, and no fix in
  this pass changes that.
