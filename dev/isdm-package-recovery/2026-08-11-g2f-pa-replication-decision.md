# G2f decision record

G2f tests within-cell PA replication, not total observation support. Its
pre-fit oracle proves two-fold conditional PA Fisher information and leaves the
GBIF information invariant; it does not promise two-fold fitted-profile
information. A future separately approved smoke must use the same six free
`theta_diag_B` lower-profile offsets and three retained initializations as G2e.

The immutable comparison is the retained G2d lower-profile vector
`c(sp1=0.0319798, sp2=1.2044196, sp3=0.1211327, sp4=0.8805146, sp5=1.4706107, sp6=0.3712282)`.
Let A mean that all six profiles are valid (five fixed offsets, finite NLL and
delta, convergence zero) and at least four lower endpoints exceed their G2d
counterpart by at least 1. Let B mean that the maximum absolute GBIF-bias
coefficient error is lower than the retained G2d error 0.371326. The complete
decision partition is:

| Future smoke result | Frozen classification |
| --- | --- |
| A and B | `REPLICATION_RESPONSIVE` |
| not A and B | `PROFILE_LIMITED` |
| not B (including A and not B) | `NONRESPONSIVE` |
| invalid fit/profile or missing retained ledger | `G2F_SMOKE_HOLD` (unclassified) |

Neither a classification nor convergence is recovery evidence. No result can
authorize a campaign; that requires a new explicit approval.
