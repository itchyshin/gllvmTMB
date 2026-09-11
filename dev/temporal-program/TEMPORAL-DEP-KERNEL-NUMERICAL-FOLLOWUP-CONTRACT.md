# Dependent temporal--kernel positive-persistence numerical follow-up

## Status and purpose

This is a **diagnostic contract**, not a promotion or recovery claim.  It
addresses the retained failed positive-persistence stratum of
`temporal_dep() + kernel_indep()` in
`run-dep-kernel-recovery.R`.  The frozen campaign is immutable: its data
generator, nine `(phi, seed)` cells, optimizer receipts, `.35` kernel-variance
bound, and failed decision remain evidence.

The observed failure is narrow.  At `phi = .6`, every retained fit has a
finite objective, both requested BFGS passes accepted, an outer gradient at
most `1e-3`, and passing fixed-effect, persistence, and temporal-covariance
criteria.  The first two kernel-variance medians are `.3951228` and `.3617466`,
above the frozen `.35` bound.  This contract asks whether that deficit is
explained by weak information in the **additive model itself**, or by a
reproducible numerical defect.  It does not assume either answer.

## Invariants

The fitted covariance remains exactly

\[
 I(g_i=g_{i'})\phi^{|t_i-t_{i'}|}\Sigma_T[j_i,j_{i'}]
 + K_S(h_i,h_{i'})I(j_i=j_{i'})v_{S,j_i}
 + I(i=i')\sigma_\epsilon^2.
\]

There is no product source-by-time field, change in likelihood constants,
altered loading packing, source attenuation, residual floor, optimiser
tolerance, fixture, seed, threshold, or replacement attempt.  The positive
AR1 parameter and the static-kernel variances remain separately estimated on
their existing unconstrained transformed coordinates.

## Diagnostic stages

1. **Independent curvature calculation.**  A new, standalone R fixture must
   reconstruct the direct DGP from the frozen generator without calling
   package simulation.  At each retained `phi=.6` data set it must construct
   the dense marginal covariance and compute central derivatives and an
   observed-information approximation for the three kernel log-variance
   coordinates, `theta_temporal_time`, and the packed temporal covariance.
   It must report conditioning and standardized parameter correlations; it
   must not manufacture a pass/fail threshold from those diagnostics.

2. **Native-to-dense agreement.**  At at least three fixed parameter points
   per data set, including the fitted point and a perturbation in each failing
   kernel direction, independently computed marginal NLL differences and
   central gradients must agree with the native objective.  A disagreement is
   an implementation defect.  Agreement only shows that the retained failure
   belongs to the specified additive likelihood.

3. **One predeclared numerical intervention only if stage 2 passes.**  The
   intervention may be a deterministic transformed-coordinate scaling or a
   data-free start derived from the same labelled kernel and time bases.  It
   must preserve the objective and maps, be applied to every one of the nine
   frozen cells, retain every old and new receipt side by side, and have an
   independently calculated fixed-parameter oracle showing that the
   transformation is algebraically equivalent.  Random restarts, seed
   replacement, selecting a favourable candidate, a third generic BFGS pass,
   and tolerance or threshold changes are prohibited.

4. **Decision.**  The original recovery gate remains failed unless the
   prespecified all-nine replay satisfies the original criteria.  If the
   curvature diagnosis shows genuine weak information, no solver change is
   justified and the cell remains partial.  Neither outcome is a general
   recovery or coverage claim.

## Required artefacts before a replay

- A new test file under `tests/testthat/` owned by this slice, with the
  independent dense oracle and a wrong product-kernel control.
- A versioned diagnostic script and per-cell retained outputs under
  `dev/temporal-program/results/`.
- A measured one-cell pre-run before any replay projected above 30 minutes;
  separate compute approval remains required for a retained remote campaign.
- Independent Gauss/Noether review of the coordinate equivalence and Curie
  review of the DGP and retention rules.

## Non-claims

This work does not admit dependent phylogenetic, animal, or spatial pairs;
OU; temporal Psi; source-pair forecasts, intervals, profiles, bootstrap, or
selection; a release; or cross-platform verification of any source-pair
model.  It also does not alter the publication status of the bounded base
temporal provider.
