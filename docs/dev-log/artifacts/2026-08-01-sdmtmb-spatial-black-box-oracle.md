# Isolated sdmTMB black-box oracle receipt — 2026-08-01

Purpose: compare overlapping observable mesh/FEM/CRS outputs only after the
independent gllvmTMB implementation existed. This is not a source, runtime
dependency, package test, or proof of code provenance.

- Script: `dev/verify-sdmtmb-spatial-oracle.R`
- Invocation: `SDMTMB_ORACLE_LIB=/private/tmp/gllvmtmb-sdmtmb-oracle Rscript --vanilla dev/verify-sdmtmb-spatial-oracle.R`
- Oracle package: sdmTMB 1.1.0 in the isolated library above.
- Native implementation dependencies: fmesher 0.8.0 and sf 1.1.1.
- Fixture: six fixed planar coordinates in the script; two fixed longitude/
  latitude coordinates for CRS conversion.
- Tolerance: `1e-10`, applied to dense representations of `A_st`, `c0`, `g1`,
  `g2`, and to projected `X`/`Y` coordinates.
- Result: PASS. All compared matrices and coordinates agreed within tolerance.

If a later comparison differs, adjudicate against the public fmesher API and
the SPDE/FEM literature; do not inspect or copy sdmTMB source.
