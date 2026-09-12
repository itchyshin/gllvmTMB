# Dependent temporal--kernel curvature-scaled BFGS diagnostic

## Purpose

This is a one-cell numerical qualification diagnostic for the direct Gaussian,
replicated AR1 `temporal_dep() + kernel_indep()` model.  It follows the
rejected identical third BFGS pass at `phi = 0`, `seed = 2609373`: the second
pass had a maximum outer gradient of `0.00167243199`, and the identical third
pass worsened it to `0.00212697671`.  It does not change, replace, pool with,
or reinterpret that frozen qualification.

## Candidate

Fit the frozen two-pass BFGS baseline.  At its native endpoint, calculate each
diagonal curvature using symmetric central differences of the native outer
gradient,

\[
d_i = \{g_i(p + h_i e_i) - g_i(p - h_i e_i)\}/(2h_i), \qquad
h_i = 10^{-4}(1 + |p_i|).
\]

The candidate runs one BFGS pass from that fitted object through the ordinary
`start_from` mechanism.  Its `optim` `parscale` is

\[
s_i = \min(10^4,\max(10^{-4},d_i^{-1/2})).
\]

All diagonal curvatures must be finite and strictly positive; otherwise the
candidate is rejected before its continuation fit.  The bounds are a fixed
numerical safeguard, not fitted parameters.  The original formula, data
generator, maps, likelihood, starts before the warm start, optimizer method,
and convergence criterion remain unchanged.

## Acceptance and evidence

The candidate is accepted only if its continuation has convergence code zero,
a finite objective no greater than the baseline plus `1e-8`, maximum outer
gradient at most `1e-3`, and independent endpoint checks with NLL error at
most `1e-6` and maximum central-gradient error at most `1e-4`.  It retains a
receipt for either outcome, including curvature, scaling, both endpoints,
warnings, and independent checks.

The pre-run is this one cell.  The rejected three-pass diagnostic took about
139 seconds on this host, so a two-pass baseline plus one continuation and
twenty gradient evaluations is provisionally below 30 minutes.  If it exceeds
that estimate, stop and report before any broader campaign.

## Boundary

This diagnostic cannot support a recovery, optimizer-superiority, coverage,
admission, cross-platform, merge, or release claim.  A broader candidate would
require a separate frozen contract, independent review, timing evidence, and
approval when its retained campaign exceeds 30 minutes.
