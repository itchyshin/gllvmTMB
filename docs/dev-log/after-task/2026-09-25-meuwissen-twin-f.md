# After-task: Meuwissen-Luo F twin for sparse pedigree precision (#1322)

Date: 2026-09-25
Lane: `cursor/meuwissen-twin-20260925`
Closes: #1322
Twin: drmTMB #1424 (cite only; no GPL source copied)

## Scope

Replace dense `Finb <- diag(A) - 1` on the fit path of `.gllvm_pedigree_precision`
with a Meuwissen & Luo (1992) inbreeding walk. Keep Quaas sparse `A^{-1}` assembly.
Keep dense tabular A as oracle / export only.

## Done

- `.gllvm_pedigree_inbreeding_meuwissen_luo` (R walk following HSquared.jl MIT
  `_meuwissen_luo_inbreeding` at `eee5f7aa…`)
- `.gllvm_pedigree_quaas_ainv` shared by fit path and dense-F oracle
- `.gllvm_pedigree_precision` uses Meuwissen-Luo F
- `.gllvm_pedigree_precision_dense_F` for identity tests
- Extended `tests/testthat/test-pedigree-precision.R` (F identity, Ainv vs dense-F
  and MCMCglmm, reciprocal sire/dam, existing order/validation gates)
- Help honesty on `pedigree_to_Ainv_sparse`; `inst/COPYRIGHTS` provenance

## Checks

- Focused pedigree-precision: 21 PASS / 0 FAIL
- Focused pedigree-sparse-ainv: 9 PASS / 0 FAIL
- No Totoro / Actions campaign (D-50)

## Rose

Claim boundary: capability twin of drmTMB #1424 (sparse end-to-end F + Ainv).
No public speed multiplier. Absolute seconds only if a later receipt is taken.

## Not done

Optional large-n Totoro receipt; C++ heap-walk rewrite if mid-n R walk is slower
than dense F in wall time (drmTMB gotcha).
