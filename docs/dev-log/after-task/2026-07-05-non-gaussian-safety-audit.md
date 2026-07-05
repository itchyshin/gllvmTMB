# Non-Gaussian Safety Audit (Day 3b of the completion arc)

Date: 2026-07-05
Branch: `codex/r-bridge-grouped-dispersion`
Commit before task: `4d8f7589`
Agent: Claude (read-only audit; one Explore sub-agent gathered evidence)

## Goal

Audit the non-Gaussian safety / parameterization surface for the completion
arc, against the guards "no non-Gaussian REML claim" and "no Gaussian residual
semantics borrowed for non-Gaussian families." Confirm the #622 Gamma
dispersion decoupling has no `sigma_eps` leak. No code changed.

## Outcome

**All five safety items are (A) correct/safe with fail-loud behaviour where
applicable.** The named non-Gaussian correctness boundaries are enforced at fit
time and test-backed.

Epistemic scope: this verifies the specifically-named safety boundaries against
existing guards and tests. It is a boundary/guard audit, not adversarial fuzzing
or coverage calibration; "safe" here means the named risk is guarded and tested,
not that the package is proven bug-free.

## Findings

1. **Positivity guards -- (A) fail-loud, masked-exempt.**
   `R/fit-multi.R:2010-2020` aborts when any observed (`!masked_response`)
   lognormal/Gamma row has `y <= 0` ("must be strictly positive ... need a
   hurdle/delta, zero-inflated, or count-family model"); masked `y = 0`
   sentinels are exempt by the `& !masked_response` conjunction. Tests:
   `test-family-lognormal.R:46-60` ("strictly positive"), `test-family-gamma.R`.
   Matches register FAM-09 (#659) and FAM-11.

2. **Gamma dispersion decoupling (#622) -- (A) no `sigma_eps` leak.**
   `src/gllvmTMB.cpp:1948-1958` computes Gamma (fid 4) with
   `shape = exp(log_phi_gamma(t))`, `scale = mu / shape`; `sigma_eps` is read
   only for Gaussian (fid 0) and lognormal (fid 3). The mixed Gaussian/Gamma
   independence test (`test-family-gamma.R:57-100`) asserts Gaussian `sigma_eps`
   and Gamma per-trait `phi_gamma`/CV recover separately.

3. **Family-specific residual -- (A) per-family, not blanket Gaussian.**
   `link_residual_per_trait()` (`R/extract-sigma.R:116-300`) maps each family id
   to its own latent-scale residual (Gaussian/lognormal 0; binomial link-wise
   `pi^2/3`/`1`/`pi^2/6`; Poisson `log1p(1/mu)`; Gamma `trigamma(phi_gamma)`;
   NB2 `trigamma`; Beta/Student-t precision/df terms). Test:
   `test-link-residual-15-family-fixture.R` (one hand-computed reference per fid,
   e.g. Gamma `trigamma(4)` at lines 106-117).

4. **Ordinal link boundary (#658) -- (A) AD-safe clamp.**
   `src/gllvmTMB.cpp:2100` clamps the category probability with
   `p_k = CppAD::CondExpLt(p_k, tiny_p, tiny_p, p_k)` (tape-aware), not an
   AD-value ternary. Test: `test-ordinal-probit.R` (K=2 byte-identical reduction
   to `binomial(probit)` per Hadfield 2015 eqn 10; K=3/4 recovery).

5. **Non-Gaussian REML gate -- (A) fail-loud, no silent fallback.**
   `R/fit-multi.R:1951-1985` aborts `REML = TRUE` when `any(family_id_vec != 0L)`
   ("implemented for Gaussian-only fits"), plus guardrails rejecting weights,
   masked responses, MI predictors, and rank-deficient design. Only outcomes:
   Gaussian accepts REML, or non-Gaussian errors. Test:
   `test-gaussian-reml.R:100-149` (poisson + `REML = TRUE` rejected).

## Checks Run

Read-only audit; no test, `devtools::check()`, or `pkgdown::check_pkgdown()`
run because no code changed. Evidence via one Explore sub-agent over
`R/fit-multi.R`, `R/extract-sigma.R`, `src/gllvmTMB.cpp`, and the named
`test-*.R` files.

## Files Created / Modified

- Created this after-task report.
- Appended a check-log entry to `docs/dev-log/check-log.md`.

No R, C++, Rd, NEWS, README, vignette, design doc, or validation-register file
changed by this audit.

## Team Notes

Gauss/Noether: the Gamma (fid 4) likelihood block reads only `log_phi_gamma(t)`;
no `sigma_eps` cross-contamination; ordinal clamp is AD-safe.

Fisher: REML stays Gaussian-only with a hard fail-loud gate; no non-Gaussian
REML pathway exists.

Rose: no overclaim; the non-Gaussian safety boundaries match the hard guards.

Shannon: no push or PR; branch remains local, ahead 201.

## Known Limitations And Next Actions

- With the profile-route, missing/mixed, structural-slope, and non-Gaussian
  audits all confirmatory, the Phase 1-4 correctness truth-lock is complete as
  a boundary/guard audit. Remaining arc is release-hardening (Codex-led local
  checks + register/NEWS/README wording, which Claude can draft) and capability
  promotion (Codex code slices).
- An adversarial fuzz / empirical coverage study (Curie/Fisher, later, on
  Totoro/DRAC per the compute-escalation gates) would complement these
  boundary audits; not started here.
- No push/PR/merge without Shinichi's authorization.
