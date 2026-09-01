# Final spatial recovery adjudication

**Date:** 2026-08-31
**Evidence reviewed:** frozen fixture manifest
`692380327512a8ede39849eab813319469948d96c477f86b190e4f85d90181c3`;
`full-evidence/attempts.csv`, `full-evidence/cells.csv`, and
`full-evidence/paired-diagnostics.csv`; compact Totoro archive SHA-256
`f249e4c8e8de5bc089584eea03fb73b343df60187afe4f855daf50e4a82518f7`.

This is the final Fisher/Rose evidence adjudication required by G6. The
`*_pending_fisher` labels in `cells.csv` are the pre-adjudication mechanical
output retained for provenance; they are not the final public verdict.

| Regime | Mode | rho | Final verdict |
| --- | --- | ---: | --- |
| regular-short | indep | 0.3, 0.7 | partial |
| regular-short | dep | 0.3, 0.7 | partial |
| regular-short | latent | 0.3, 0.7 | partial |
| regular-short | latent-plus-Psi | 0.3, 0.7 | partial |
| irregular-long | indep | 0.3, 0.7 | partial |
| irregular-long | dep | 0.3 | blocked |
| irregular-long | dep | 0.7 | partial |
| irregular-long | latent | 0.3, 0.7 | partial |
| irregular-long | latent-plus-Psi | 0.3 | blocked |
| irregular-long | latent-plus-Psi | 0.7 | partial |

The two blocked cells meet the predeclared blocking predicates: irregular-long
`dep`, rho 0.3 has boundary frequency 0.789; irregular-long latent-plus-Psi,
rho 0.3 has boundary frequency 0.816 and rho/log-kappa error correlation
0.826. Every other estimated cell is partial because it misses at least one
bounded pass requirement but does not meet a blocking predicate. There are no
passing estimated-rho cells. These results do not establish universal spatial
non-identifiability and do not support a broad spatial range--rho recovery
claim.
