# G2f private PA-replication protocol

## Immutable truth and provenance

G2f follows G2e's `PROFILE_LIMITED` result. It preserves the six-species,
120-cell, nonspatial relative-intensity model and original G2d GBIF/PA support.
The frozen random seed is `86101L`; the truth constants are those returned by
`g2f_truth_constants()` in `g2f-pa-replication-fixture.R`. Its immutable
support formulae are

\[
a_c^G=\exp\{\operatorname{seq}(\log .8,\log 2;120)\},\qquad
a_c^S=\exp\{\operatorname{seq}(\log .6,\log 1.4;120)\}.
\]

These are the original G2d support vectors, not the doubled G2e supports. The
validator checks the exact vectors, the nested three-visit reference, and the
GBIF-only source gate. G2c remains `G2C_SMOKE_ADMISSION_HOLD`, G2d remains
`G2D_SMOKE_HOLD`, and G2e remains `PROFILE_LIMITED`; no retained result is
altered.

## Model and alignment

G2f changes only PA replication from three to six conditionally independent
cloglog events sharing each cell/species ecological state:

\[
D_{csv}\sim\operatorname{Bernoulli}\{1-\exp[-a_c^S\exp(\eta_{cs})]\},\quad v=1,\ldots,6.
\]

GBIF remains \(Y^G_{cs}\sim\mathrm{Poisson}\{a_c^G\exp(\eta_{cs}+\delta_s+b_c\gamma_s)\}\).
`B` is finite only on GBIF rows and structurally `NA` on PA rows. The first
three PA events are byte-identical to the G2f three-visit reference; visits
4--6 are the sole added observations. No fit is authorized by this protocol.

| Symbol | G2f private data contract | Future fitted coordinate | Frozen truth / check |
| --- | --- | --- | --- |
| \(\eta_{cs}\) | one realized `eta` matrix reused for all six PA visits | ecological linear predictor | `alpha`, `beta`, rank-one `lambda`, and free diagonal `psi_sd` |
| \(a_c^G,a_c^S\) | original G2d support vectors above | known quadrature offsets | exact-vector validator |
| \(b_c\gamma_s\) | GBIF count rows only | GBIF bias gate | finite `B` only for GBIF; PA `B=NA` |
| \(D_{csv}\) | six independent Bernoulli draws conditional on shared \(\eta_{cs}\) | six PA events | visits 1--3 exactly nested; visits 4--6 added |
| \(\theta_{\mathrm{diag},B}\) | no-fit only in G2f preparation | six free diagonal log-SD profiles | future smoke ledger; not inferred here |

## Conditional-information oracle

Put \(\lambda_{cs}=a_c^S\exp(\eta_{cs})\) and
\(p_{cs}=1-\exp(-\lambda_{cs})\). For one PA visit, the conditional
Bernoulli Fisher information for \(\eta_{cs}\) is

\[
I_{\eta,cs}^{(1)}=\frac{(\partial p_{cs}/\partial\eta_{cs})^2}
 {p_{cs}(1-p_{cs})}=
 \frac{\lambda_{cs}^2\exp(-\lambda_{cs})}{1-\exp(-\lambda_{cs})}.
\]

Thus the fixed six-visit design has \(6I_{\eta,cs}^{(1)}\), exactly twice the
three-visit conditional PA information, while the GBIF conditional information
is unchanged at \(I^G_{\eta,cs}=\mu^G_{cs}\). This is an oracle conditional
on the realized ecological state—not a claim that marginal fitted-profile
information or recovery must double.
