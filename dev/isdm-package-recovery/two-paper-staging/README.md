# Private two-paper staging package

This directory is a private, non-package staging area for two distinct future
articles. It contains only their evidence-aware narrative architecture and
design prototypes. It does not contain empirical records, fitted models,
recovery results, or reader-facing material.

| Package | Question | Presently permitted material | Not yet earned |
| --- | --- | --- | --- |
| Paper 1: spatial source separation | Can a two-field spatial iSDM keep shared ecological variation distinct from GBIF-only spatial sampling bias? | Synthetic known-truth design schematic and methods/background draft | Fitted field maps, empirical QA maps, recovery claims, and empirical predictions |
| Paper 2: numerical and Psi diagnostics | Are numerical admission and diagonal-Psi recovery separate all-attempt properties of the frozen estimator? | Frozen-model/gate schematic and methods/background draft | Frequency claims, Psi-error results, profiles, empirical analysis, and reader promotion |

`render-prototype-figures.R` creates P1-F1 and P2-F1 only. It has a
hard non-fit boundary: it must not call the estimator, an optimiser, a profile,
or a simulation campaign. Output is deliberately written beneath the ignored
`dev/isdm-package-recovery/results/` root with a provenance sidecar.

The gate and caption rules are authoritative in
`../2026-08-13-two-paper-figure-claims-contract.md` and
`../2026-08-13-two-paper-figure-storyboard.md`.
