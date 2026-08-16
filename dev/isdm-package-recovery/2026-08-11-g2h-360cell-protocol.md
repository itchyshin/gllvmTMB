# G2h private 360-cell covariance-information protocol

G2h preserves the six-species nonspatial relative-intensity iJSDM, rank-one
Lambda, free diagonal Psi, GBIF Poisson branch, three shared-state PA-cloglog
visits, and GBIF-only bias gate. It changes only geometry from 120 to 360
independent cells. The frozen seed is `86121L`.

For every species, the fixture draws

\[
\eta_{cs}=\alpha_s+x_c\beta_s+z_c\lambda_s+e_{cs},\qquad
Y^G_{cs}\sim\mathrm{Poisson}\{a_c^G\exp(\eta_{cs}+\delta_s+b_c\gamma_s)\},
\]

and three conditionally independent PA-cloglog visits. The raw GBIF bias draw
is residualised on \(x\), centred, and standardized; the fixture must prove
\(|\operatorname{cor}(x,b)|\le0.10\), full three-column `(1,x,b)` rank, and
\(\sum_c\mu^G_{cs}b_c^2\ge130\) for every species. `B` remains finite only on
GBIF rows and `NA` on PA rows.

No fit, smoke, retry, campaign, public/package change, or empirical analysis is
authorized. G2c--G2f outcomes are immutable evidence.
