# Private shared-range spatial iSDM: symbolic alignment

**Status:** implementation contract; no fit, simulation, profile, or compute
is authorised by this note.

| Symbol | Private formula/input | DGP/recovery role | Deterministic safeguard | Truth/constraint |
| --- | --- | --- | --- | --- |
| `u_c Lambda_s` | intercept column of `spatial_latent(1 + isdm_gbif | cell_id, d = K)` | shared ecological field in a later DGP | formula contract | reaches GBIF and PA rows |
| `e_cs`, `Psi = diag(psi_s^2)` | `indep(0 + trait | cell_id)` | nonspatial cell-by-species ecological residual | formula contract | reaches both sources; not a second SPDE field |
| `h_c` | `isdm_gbif` slope column of the same term | GBIF-only spatial bias field | PA eta/NLL invariance under field perturbation | exactly zero on PA rows |
| `kappa` / mesh | one `mesh` argument, existing augmented-SPDE block | shared spatial scale | aligned `mesh$A_st` row count | one shared mesh/range/rank |
| `Y^G` | existing private Poisson/log row | GBIF observation process | exact family/link admission | family id 2, link id 0 |
| `D` | existing private Bernoulli/cloglog row | PA observation process | exact family/link admission | family id 1, link id 2 |

The existing engine computes the two SPDE contributions row-wise from this
two-column design.  This implementation does not add a second mesh, range,
rank, TMB block, likelihood family, or public route.
