# G2g symbolic identifiability certificate

## Frozen object

For each cell \(c\) and species \(s\), G2d--G2f retain

\[
\eta_{cs}=\alpha_s+x_c\beta_s+z_c\lambda_s+e_{cs},\quad
z_c\sim N(0,1),\quad e_{cs}\sim N(0,\psi_s^2),
\]

\[
Y^G_{cs}\sim\operatorname{Poisson}\{a_c^G\exp(\eta_{cs}+\delta_s+b_c\gamma_s)\},
\qquad
D_{csv}\sim\operatorname{Bernoulli}\{1-\exp[-a_c^S\exp(\eta_{cs})]\}.
\]

`B=b` is finite only for GBIF rows; PA rows have a structural zero gate in the
assembled design. The fit has one rank-one \(\Lambda\) plus six free diagonal
\(\psi_s\) coordinates. This certificate concerns the fixed six-species,
120-cell, nonspatial relative-intensity DGP only.

## What is locally identified

Conditional on \(\eta\), the GBIF score for \(\gamma_s\) has information

\[
I_{\gamma_s\gamma_s}^{G}=\sum_{c=1}^{120}
\mu^G_{cs} b_c^2,\qquad
\mu^G_{cs}=a_c^G\exp(\eta_{cs}+\delta_s+b_c\gamma_s).
\]

Thus PA replication does not directly add a \(\gamma_s\) score term; it can
only help indirectly through sharper inference on \(\eta\). Doubling GBIF
support doubles this conditional information. The retained fixed-effect design
has full rank (24/24) and \(\operatorname{cor}(x,b)=0.1999\), so an exact
linear alias between ecological and GBIF-bias covariates is ruled out for this
fixture. The no-fit reader also verifies six named GBIF-bias terms, a zero
survey gate, a finite/varying GBIF gate, and the private relative-intensity
route in all three retained fits.

The fitted extractor intentionally reports the two covariance pieces
separately: `report$Sigma_B=\Lambda\Lambda^\mathsf{T}` is the shared rank-one
component, while `report$sd_B` is the free diagonal \(\psi\) component. The
full model covariance is reconstructed as
`report$Sigma_B + diag(report$sd_B^2)`. The no-fit reader verifies this shared
extractor identity, six free diagonal coordinates, and rank-one loading map in
every retained fit; it does not mistake `Sigma_B` alone for the full covariance.

For one PA visit, with \(\ell_{cs}=a_c^S\exp(\eta_{cs})\),

\[
I^{(1)}_{\eta,cs}=\ell_{cs}^2e^{-\ell_{cs}}/(1-e^{-\ell_{cs}}).
\]

Six independent visits make this \(6I^{(1)}_{\eta,cs}\), twice the three-visit
quantity. This is conditional information, not a guarantee of marginal
profile curvature for \(\psi_s\).

## Remaining weak direction

The covariance decomposition has a single shared factor plus species-specific
variance:

\[
\Sigma=\Lambda\Lambda^\mathsf{T}+\operatorname{diag}(\psi_1^2,\ldots,\psi_6^2).
\]

With one realised 120-cell latent field, the data must allocate each species'
within-cell variation between the shared rank-one component and its diagonal
remainder. Adding replicated PA outcomes observes the same realised
\(\eta_{cs}\) more often; it does not create a second realised ecological
field. Therefore it need not steepen each \(\psi_s\) profile. The retained
artifact reader tests this claim against profile curvature and the local
\(\Lambda\)--\(\theta_{\mathrm{diag}}\) covariance, rather than assuming it.

## Retained evidence and verdict

The read-only table at `results/g2g-retained-audit-20260811-003/` has valid
source manifests for all three roots. G2d, G2e, and G2f each have full-rank
24-column fixed designs and the same non-aliasing \(x,b\) contrast. Their
maximum absolute local \(\gamma\)--\(\Lambda\) correlations are 0.141, 0.087,
and 0.093; corresponding \(\gamma\)--\(\theta_{\mathrm{diag}}\) maxima are
0.090, 0.188, and 0.102. Hence the retained Hessians do not support a direct
local bias-versus-covariance confounding explanation.

In contrast, the maximum \(\Lambda\)--\(\theta_{\mathrm{diag}}\) correlations
are 0.444, 0.282, and 0.368, while the numbers of lower \(\psi\)-profile
endpoints with delta NLL at least 2 are 0, 1, and 1 of six. This is retained
evidence for a covariance-information limitation, not proof of a universal
non-identifiability theorem.

G2f's raw maximum gradient 0.001056337 narrowly misses its 0.001 smoke rule,
but its retained scaled- and raw-stationarity flags and positive-definite
Hessian are all true. The numerical HOLD is therefore an admission threshold,
not an alternative explanation for the `NONRESPONSIVE` classification. Under
the frozen G2g tree it is an ancillary `NUMERICAL_THRESHOLD_NOTE`, while the
scientific diagnosis is `COVARIANCE_INFORMATION_LIMITED`.

## Redesign implication

The one recommended redesign is **sample geometry**: increase from 120 to 360
independent cells while keeping six species and three PA visits, retain the
GBIF-only gate, and draw the GBIF bias covariate with
\(|\operatorname{cor}(x,b)|\le0.10\). With the retained support scale, this
triples the current minimum conditional GBIF information from 44.34 to about
133, so the next fixture must predeclare a minimum of 130 for every
\(\sum_c\mu^G_{cs}b_c^2\). This is a design hypothesis to test, not recovery
evidence. No redesigned fit is authorized by this certificate.
