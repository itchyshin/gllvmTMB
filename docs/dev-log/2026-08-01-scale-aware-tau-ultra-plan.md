# Ultra Plan: #847 Scale-Aware Loading-Ridge Tau

```text
GOAL
Outcome:
  Give the validated pure single-trial Bernoulli ordinary-latent route a
  scale-aware loading ridge whose realised tau is calibrated by an unpenalised
  multi-start AGHQ pilot, while preserving numeric/Inf controls and ordinary
  Laplace behavior.

Done means:
  1. Default latent() and latent(..., unique = FALSE) are proved to have the
     same objective and gradient when every automatic B-tier Psi is pinned.
  2. R and C++ use one all-skipped-diagonal predicate; any free Psi remains
     outside AGHQ Stage 1a.
  3. The pilot is unpenalised multi-start AGHQ, never plain Laplace and never a
     penalised fit.
  4. tau_raw, tau_used, cap/clipping, source, and pilot status are retained on
     the fit; MAP and likelihood-at-MAP disclosures remain truthful.
  5. Numeric tau and Inf reproduce existing behavior; a missing ridge control
     never auto-penalises an ordinary Laplace fit.
  6. A cap passes paired selection and disjoint-seed confirmation against fixed
     tau = 2 before any default flip.
  7. Focused tests, pkgdown metadata, package checks, exact receipts, issue #847,
     and the PR all agree on the narrow claim.

Scope:
  IN: ordinary B-tier latent(), pure single-trial Bernoulli, every automatic
      B-tier Psi structurally skipped, current AGHQ Stage-1a rank/gate region.
  OUT: multi-trial binomial, mixed families, multinomial, explicit indep()/
       unique(), any free Psi, extra random blocks, other covariance tiers,
       broad estimator accuracy, and an automatic Laplace-derived scale.

Constraints:
  - Fixed capacity: at most 10 productive hours for this arc; external CI wait
    does not justify widening the claim.
  - Known-truth campaigns run on Totoro (<=100 cores), never GitHub Actions.
  - Failed and nonconverged pilots/fits remain in denominators.
  - Unpenalised multi-start AGHQ is the calibration yardstick. A plain Laplace
    pass is forbidden because it estimates tau correctly in only 0-1% of the
    sigma_lambda = 3 fits and overstates it by 5.5-8.6x.

Evidence required:
  - Exact objective/AD-gradient equivalence at the optimum and perturbations,
    across logit/probit/cloglog and q = 1/2.
  - Stored 12,000-fit tail rescore with paired keys retained.
  - Fresh paired cap-selection campaign on Totoro.
  - Fresh disjoint-seed confirmation for the locked cap.

Stop conditions:
  - Any free diagonal reaches the AGHQ tape.
  - R/C++ eligibility predicates disagree.
  - Numeric/Inf or ordinary-Laplace compatibility moves.
  - No cap clears every selection and confirmation gate.
  - A claim would have to rely on converged = TRUE as an accuracy filter.
```

## Scientific headline

The previous campaign does **not** answer which estimator is broadly more
accurate. Both proposed convergence-filter populations are invalid: every one
of 4,800 Laplace fits reported convergence even though 49.1% ran away. The
established result is a runaway-avoidance signal. At `n = 400`,
`sigma_lambda = 1`, the median paired difference is `+0.00014`, with exactly
half the replicates favoring each arm.

## Outcome after the selection gate (2026-08-01)

The preregistered selection gate returned **NO_CAP_PASSED_SELECTION**. Valid
unpenalised multi-start AGHQ pilots were sparse (162/600), and the strict
pilot-dependent cap policy was materially worse than the shipped fixed
`tau = 2` route at the first failure/runaway gate. No cap was locked, the
disjoint-seed confirmation was therefore not run, and the package default
remains `tau = 2`.

The maintainer subsequently authorised implementation at the narrower positive
evidence scope, with limits carried in warnings and documentation. A separately
labelled posthoc sensitivity therefore evaluated a transparent policy: use the
cap-6 auto fit only when its final AGHQ fit is valid, otherwise return an
independently started shipped-style `tau = 2` fit. The auto result was used in
135/600 replicates; no cell had a higher failure or runaway rate, all six cells
met the preregistered +0.02 loading-error non-inferiority margin, and the
six-cell macro-mean loading-error difference was +0.002819895. This admits an
explicit experimental runaway/failure-avoidance route only. It does **not**
support a default flip or a broad accuracy claim. Receipts live under
`docs/dev-log/artifacts/aghq-tau-847/`.

## Orientation and prior-work sweep

- Authoritative resume point:
  `docs/dev-log/handover/2026-07-31-codex-handover.md`.
- #877 landed first at merge commit `bca04b29`; its warning exposes the problem
  but does not claim to fix it.
- #847's jittered Laplace restarts were refuted: 70% runaway versus 65% for the
  single-start comparator at `n = 1600`, `sigma_lambda = 3`.
- The stored campaign identifies the usable scale yardstick: unpenalised
  multi-start AGHQ gives `tau_hat / true = 1.18 / 1.07 / 0.97` for
  `sigma_lambda = 3`. Plain Laplace is forbidden as the pilot.
- A local sister-repository sweep found no reusable AGHQ/tau implementation.

## Symbolic contract

For loading matrix `Lambda` with `p` traits and `q` latent axes, define the
unpenalised multi-start AGHQ pilot scale

\[
\tau_{\mathrm{raw}}
  = \max\left(1, \frac{\|\widehat\Lambda_{\mathrm{pilot}}\|_F}{\sqrt{pq}}\right),
\qquad
\tau_{\mathrm{used}} = \min(c, \tau_{\mathrm{raw}}).
\]

The final fit minimises

\[
Q(\theta)
  = -\ell_{\mathrm{AGHQ}}(\theta)
    + \frac{\|\Lambda\|_F^2}{2\tau_{\mathrm{used}}^2}.
\]

The denominator is `sqrt(p*q)`, not the number of free triangular loading
parameters: the calibration CSV stores the full `p x q` loading matrix,
including structural zeros, and the target is per-loading RMS.

For the grammar normalization, the effective free diagonal is

\[
d_{\mathrm{free}}
  = \texttt{use_diag_B}
    \land \operatorname{any}(\texttt{diag_B_skip}=0).
\]

Only `d_free = FALSE` allows `s_B` to leave the effective random vector. Its
mapped parameter stub remains fixed at zero. This is a plumbing normalization,
not removal of a covariance component that was being estimated.

## Ten-hour arc and gates

### Arc 0 — land the warning dependency and prove equivalence (1.5 h)

- Merge #877 only after its real GitHub check is green. **Complete.**
- Formalize the all-skipped Bernoulli equivalence test.
- Rescore the stored 12,000 fits and retain unsafe pilot tails.

**Gate G1:** exact objective/gradient equality; R/C++ agree; any free Psi stays
ineligible. Failure stops the arc.

### Arc 1 — bounded plumbing and experimental API (2 h)

- Normalize an all-skipped automatic `s_B` out of the effective random vector.
- Admit it through the C++ AGHQ fence only under the same predicate.
- Preserve numeric/Inf behavior and add explicit scale provenance.
- Keep missing `aghq_ridge` on AGHQ at fixed `2` until confirmation; an
  experimental automatic route may exist behind explicit selection.

**Gate G2:** compatibility tests are exact; unsupported auto requests error
before fitting; pilot failure or non-finite scale is never a silent fallback.

### Arc 2 — paired cap selection on Totoro (2.5 h)

Fresh seeds, same DGP cells (`n = 100/400/1600`, `sigma_lambda = 1/3`), paired
arms: fixed `2`, uncapped control, and caps `5`, `6`, `8`. Cap `4` is excluded
before fresh fitting because the stored campaign shows it clips 17.1% of
truth-classified non-runaway `sigma_lambda = 3` pilots.

A cap remains eligible only when every cell satisfies:

- one-sided 95% upper bound on runaway-rate increase versus fixed `2` <= 0.02;
- one-sided 95% upper bound on correlation-MAE increase <= 0.02;
- one-sided 95% upper bound on pilot/final failure increase <= 0.01;
- <=5% of truth-classified non-runaway pilot scales clipped.

Choose among eligible caps by smallest paired mean
`abs(log(||Lambda_hat||_F / ||Lambda_true||_F))`, not by runaway alone.

### Arc 3 — disjoint-seed confirmation and default decision (2 h)

Lock one cap before examining confirmation seeds. A default flip additionally
requires all selection gates to pass again, a 95% interval showing lower paired
loading-scale error than fixed `2` in the `sigma_lambda = 3` aggregate, and no
individual `n` cell with statistically supported deterioration.

If confirmation fails, retain fixed `2`. Do not reinterpret a failed default
gate as permission to ship the experimental route broadly.

### Arc 4 — package and publication gates (2 h)

- Focused tests, documentation generation, `pkgdown::check_pkgdown()`, and
  proportionate source/package checks.
- Update #847 with the full all-fits result and negative space.
- Append check-log and after-task receipts only after PR #883's shared
  check-log append lands; rebase first.
- Open one narrow PR and wait for GitHub R-CMD-check.

## Plan-versus-actual rule

Every deviation is recorded in the paired after-task report. In particular,
an unfinished external campaign is `CARRIED-OVER`, not silently summarized as
evidence, and an unconfirmed cap is not described as selected or default-ready.
