# G2k all-attempt gradient diagnostic certificate

**Status:** `G2K_CALIBRATION_HOLD` remains in force.  This is a private,
read-only diagnosis of the 150 retained G2k attempts at commit `9c9ca277`.
It makes no model, likelihood, DGP, seed-grid, map, threshold, or recovery
criterion change.

## Evidence object and symbolic alignment

For cell \(c\), species \(s\), and PA visit \(v\), the locked state and
observation laws are

\[
 \eta_{cs}=x_c^\top\beta_s+\lambda_s z_c+e_{cs},\qquad
 e_{cs}\sim N(0,\psi_s^2),\qquad
 \Lambda=(\lambda_1,\ldots,\lambda_6)^\top,
\]
\[
 Y^G_{cs}\sim\operatorname{Poisson}\{a_c^G
 \exp(\eta_{cs}+\delta_s+b_c\gamma_s)\},
 \quad
 Y^S_{csv}\sim\operatorname{Bernoulli}\{1-\exp[-a^S_{cv}\exp(\eta_{cs})]\}.
\]

The diagnostic does not evaluate those laws anew.  It reads the retained
outer objective \(\ell(\theta)\), where \(\theta\) includes `b_fix`,
`theta_rr_B` (the rank-one loading coordinates), and `theta_diag_B`.  The
diagonal transform is \(\psi_s=\exp(\theta_{\mathrm{diag},s})\), hence
\(\Psi_{ss}=\exp(2\theta_{\mathrm{diag},s})\).  The raw numerical gate is
\(\|g(\theta)\|_\infty\le 10^{-3}\), with
\(g(\theta)=\nabla_\theta\ell(\theta)\).  The package's descriptive scaled
quantity is exactly

\[
 g_{\rm scaled}=\|g(\theta)\|_\infty/(1+|\ell(\theta)|).
\]

It is deliberately not a convergence certificate: `R/diagnose.R` documents
that it changes under arbitrary additive/replicate scaling of the objective.
The retained covariance matrix \(V\) is the inverse fixed-parameter Hessian
when it exists; therefore \(\kappa(V)=\kappa(H)\).  The frozen profile
curvature evidence is the six-coordinate lower-direction difference
\(\Delta\ell_{s,-1}=\ell(\hat\theta_{\mathrm{diag},s}-1)-\ell(\hat\theta)\);
values at or below 2 are recorded as weak local lower curvature.

| Symbol / quantity | Retained implementation field | Diagnostic use |
| --- | --- | --- |
| \(\|g\|_\infty\) | `ledger$final_gradient`, `polish$raw$max_gradient` | frozen raw admission gate |
| \(g_{\rm scaled}\) | `fit$fit_health$scaled_gradient` | descriptive scale check only |
| \(\theta_{\rm rr}\), \(\theta_{\rm diag}\) | raw maximum block/index and boundary records | distinguish loading/fixed-effect residuals from diagonal boundary geometry |
| \(H,V\) | `sd_report$pdHess`, `cov.fixed` | positive-definiteness and \(\kappa(V)\) |
| \(\Delta\ell_{s,-1}\) | six retained `profiles.rds` tables | local information/identifiability signal |

## All-attempt decomposition

The validated read-only artifact root is
`dev/isdm-package-recovery/results/g2k-gradient-diagnostic-20260812-007/`.
It contains all 150 input ledgers, the 150-row extraction, criterion and
interaction tables, and an RDS evidence bundle.  The campaign receipt confirms
150 requested, 150 started, and zero missing attempts.

| Frozen criterion | Pass | Fail |
| --- | ---:| ---:|
| Raw gradient \(\le10^{-3}\) | 61 | 89 |
| \(\Psi\) variance error \(\le0.20\) | 125 | 25 |
| Minimum map correlation \(\ge0.70\) | 130 | 20 |
| Fixed effects | 147 | 3 |
| GBIF bias | 150 | 0 |
| Shared covariance | 150 | 0 |

The joint cross-tab is 69 recovery-metric passes with raw-gradient failure,
37 with both recovery metrics and the raw-gradient gate, 24 gradient-only
passes, and 20 failures of both.  Thus the raw-gradient gate is the largest
single loss, but it is not the entire 22/150 strict result.

Among raw-gradient, Psi, and map criteria, 71 attempts fail only raw gradient
while passing both Psi and map; 38 pass all three; the remaining 41 reveal
Psi/map interactions.  No GBIF-bias or shared-covariance failure is present.

## Adversarial alternatives

### Genuine nonstationarity

The retained gate has direct evidence of an unresolved raw score in 89/150
attempts.  It must remain a HOLD signal under the frozen campaign rule.  This
does **not** establish an optimizer crash: every attempt has optimizer code
zero; 147/150 have a positive-definite fixed Hessian; and all 150 scaled
gradients are below \(10^{-3}\).  The last fact is non-exculpatory because
the median scaled value is \(2.46\times10^{-7}\), a denominator effect, while
the median raw gradient is \(1.68\times10^{-3}\).

### Near-boundary geometry

Forty attempts flag `near_zero_sd_B`.  Thirty-one are eligible for the
predeclared same-objective polish, all 31 are attempted and accepted, and all
finish below the raw gate.  Of those, 22 pass all recovery metrics and become
strict passes; the other nine fail recovery metrics.  Boundary geometry is
therefore real and the existing narrow polish works in its own admissible
region, but it cannot explain the principal block: 69 recovery-metric passes
still fail the raw gradient, of which 68 carry no boundary flag and one is
boundary-flagged but ineligible.

### Inadequately targeted polish

No retained evidence supports extending that candidate automatically.  In the
69 recovery-pass/raw-gradient-fail group, the maximum raw component is
`b_fix` for 58 attempts and `theta_rr_B` for 11; it is not the named diagonal
boundary pattern for which the one-call polish was designed.  A retry with
different tolerances, starts, or a rebuilt objective would be a new estimator
and is forbidden here.  Conversely, all 31 already eligible candidates passed,
so the evidence does not show that the existing candidate is inadequately
executed.

### Information and identifiability limitation

Weak lower profile curvature is pervasive: the median is 4.5 of six diagonal
coordinates with \(\Delta\ell_{s,-1}\le2\) (distribution: 2/3/4/5/6 weak
coordinates in 2/22/51/52/23 attempts).  The median \(\kappa(V)\) is
\(4.45\times10^3\), with a large upper tail to \(2.49\times10^{10}\).
This coheres with the 25 Psi and 20 map failures, and with a weakly identified
diagonal component in this DGP.  It does not uniquely explain the raw score:
weak profiles also occur in both gradient-admission groups.  It is supporting
evidence for a component-information limitation, not a proof that changing
the DGP or estimand is warranted.

## Gate interaction retained separately

Fifteen attempts have three restarts, valid profiles, all five known-truth
metrics, and raw gradient at or below \(10^{-3}\), but are strict holds because
the G2i `valid_polish()` admission rule requires an *accepted* polish record.
They were not eligible for its narrow boundary-only predicate.  This is a
frozen campaign-rule interaction, not numerical evidence against their fitted
state.  It accounts for 15 of the 37 recovery-plus-gradient attempts not
appearing as strict passes.  It is reported, not changed.

## Certificate conclusion

The evidence rejects the easy explanations: scaled gradients do not override
raw gradients; the named boundary polish is successful where admissible; and
neither GBIF bias nor shared covariance causes the HOLD.  It supports retaining
`G2K_CALIBRATION_HOLD` and proceeding only through a separately approved
numerical-admission design review.  It does not support rerunning the same
campaign, relaxing the raw threshold, or changing the ecological model.
