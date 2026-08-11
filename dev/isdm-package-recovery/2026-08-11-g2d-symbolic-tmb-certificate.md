# G2d S1 symbolic-to-TMB certificate

## Locked private model

For cell \(c\) and species \(s\), the frozen ecological state is

\[
\eta_{cs}=\alpha_s+x_c\beta_s+z_c\lambda_s+e_{cs},\qquad
\Sigma=\Lambda\Lambda^\mathsf{T}+\Psi,
\]

where \(\Lambda\) is six-by-one and \(\Psi\) is free diagonal. GBIF rows use

\[
Y^G_{cs}\sim\operatorname{Poisson}
\left[a^G_c\exp(\eta_{cs}+\delta_s+b_c\gamma_s)\right].
\]

Each PA visit uses

\[
Y^S_{csv}\sim\operatorname{Bernoulli}
\left\{1-\exp[-a^S_{cv}\exp(\eta_{cs})]\right\}.
\]

## Static alignment

| Contract | Evidence | Verdict |
| --- | --- | --- |
| private stacked long-table route | `R/isdm-developer-fit.R` and the public mixed-family guard test | aligned |
| shared ecological state | G2d runner, helper, and TMB shared-state assembly | aligned |
| Poisson GBIF and cloglog PA branches | helper, TMB dispatch, and R analytic oracle | aligned at ordinary values |
| rank-one \(\Lambda\), free diagonal \(\Psi\) | TMB packing, starts, and retained diagnostic audit | aligned; diagnostic assembly only |
| GBIF-only bias gate | contract, materialisation, and adversarial test | aligned |

## Earned and unearned evidence

The retained diagnostic verifies the six-coordinate TMB map and
`extract_Sigma` identities on one fit. The deterministic tests verify the row
contract and analytic oracle. Neither establishes smoke admission, recovery,
profile eligibility, detection, survey-count outcomes, spatial/two-field bias,
absolute intensity, empirical use, comparator performance, public API, or
Paper 2 readiness.

## Blocking numerical issue

The compiled PA branch computes `1 - exp(-exp(eta))` and clips its probability,
whereas the R oracle uses the stable `-expm1(-exp(eta))` without that floor.
The existing tests do not exercise the tail where this distinction matters.
Therefore this is **not** an exact symbolic-to-TMB certificate yet.

Before any new S3 fit, either make the compiled likelihood numerically
equivalent and add a tail regression test, or freeze and justify a
predictor-range gate and test that every admitted value lies within it. This is
a numerical-alignment gate, not evidence that zero inflation or an
occupancy/detection extension is needed.

## Frozen next-fit requirements

The next authorised diagnostic/smoke must use a new non-G2c root, bind the
protocol, runner, decision, and commit in an immutable receipt, validate the
no-fit sentinel and hashes, retain every fit/restart/profile/metric artifact,
and preserve all-attempt denominators. No threshold may be relaxed.
