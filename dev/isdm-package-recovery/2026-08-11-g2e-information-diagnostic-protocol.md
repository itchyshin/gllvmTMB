# G2e private observation-support diagnostic protocol

## Purpose and frozen boundary

G2e is a one-fixture, local **information diagnostic**, not a G2d rerun or a
recovery campaign. G2c remains `G2C_SMOKE_ADMISSION_HOLD`; G2d remains
`G2D_SMOKE_HOLD`. G2e does not change their results or eligibility rules.

The ecological truth remains six species, 120 cells, three conditionally
independent PA-cloglog visits, rank-one `Lambda`, free diagonal `Psi`, relative
ecological intensity, and the GBIF-only bias gate. Its sole change is

\[
a_c^{G,\mathrm{G2e}}=2a_c^G,\qquad a_c^{S,\mathrm{G2e}}=2a_c^S.
\]

Thus the two observation laws are

\[
Y^G_{cs}\sim\operatorname{Poisson}\{2a_c^G\exp(\eta_{cs}+\delta_s+b_c\gamma_s)\},
\qquad
D_{csv}\sim\operatorname{Bernoulli}\{1-\exp[-2a_c^S\exp(\eta_{cs})]\}.
\]

No likelihood, covariate, seed (`86101`), cell count, species count, visit
count, `Lambda`, `Psi`, or GBIF-bias mechanism changes. `B` is finite on GBIF
rows and structurally `NA` on survey rows.

## Pre-fit requirements

The no-fit fixture must prove: exact 2x supports; six species and 120 cells;
three unique PA events per cell/species; identical GBIF plus visit-1 rows in
the one- and three-visit arms; finite Poisson information for every `gamma_s`;
and PA probabilities strictly between zero and one. It must serialize and
re-read a fresh root receipt, truth, analytic information oracle, and manifest.

## Future smoke boundary

No fit is authorised by this protocol alone. Following review and explicit
maintainer approval, one ordinary G2e local smoke may use the private
package-native fit route with exactly three retained restarts and all six
`theta_diag_B` profile ledgers. It retains every artifact and makes no Totoro,
campaign, recovery, or Paper 2 claim.

## Interpretation

The future smoke has only three possible classifications. `SUPPORT_RESPONSIVE`
requires a predeclared improvement in lower profile tails and GBIF-bias error;
`PROFILE_LIMITED` means bias recovery improves without adequate profile response;
and `NONRESPONSIVE` collects every remaining pattern, including stronger profile
tails without improved GBIF-bias recovery. None is a recovery PASS.
