# Two-paper figure storyboard and provenance grammar

## Paper 1 — applied spatial source separation

| ID | Panel purpose | Gate |
| --- | --- | --- |
| P1-F1 | Source-flow schematic; synthetic ecological and GBIF-only bias truths; two-field/diagonal-Psi decomposition | Prototype now; label as synthetic design |
| P1-F2 | Empirical data version, seasonal coverage, source counts and observed sampling-pattern maps | Empirical Gate A only |
| P1-F3 | Ecological and GBIF-bias truth, estimate and error maps with uncertainty | Private spatial numerical + recovery GO |
| P1-F4 | Supported empirical relative-intensity, bias and uncertainty maps | Separate empirical observation/prediction approval |

Use a common extent, visibly separate field palettes/scales, and masks for
unsupported empirical regions.  Never use a before/after “bias correction”
panel.

## Paper 2 — numerical admission and diagonal Psi

| ID | Panel purpose | Gate |
| --- | --- | --- |
| P2-F1 | Nonspatial mixed-source model, Lambda-Lambda-transpose plus Psi, and A-D gate flow | Prototype now; diagnostic design |
| P2-F2 | Private n=1 Case-C/HOLD audit card | Private layout only; never reader-facing |
| P2-F3 | Per-S all-attempt A by P mosaic/table with count/20 and binomial MCSE | Approved C2 campaign and private GO |
| P2-F4 | Psi-error distributions, signed errors and weak-profile counts by fixed S cell | Same C2 campaign and private GO |

Paper 2 has no geographic maps, empirical fitted results, or biological
conclusions.  S=6/20/60 are bundled design cells, not a causal species-number
gradient.

## Required sidecar and caption fence

Every figure stores `figure_id`, role/estimand, authorising gate, code commit
and environment, data/fixture hashes, denominator, exclusions/missingness,
uncertainty method, licence/privacy state, and (for spatial figures) CRS/grid,
mask and source support.  A caption must state its role, named estimand, data
or DGP, denominator, colour/interval meaning, prohibited inference and
authorising gate.  Rendering alone never authorises a claim.
