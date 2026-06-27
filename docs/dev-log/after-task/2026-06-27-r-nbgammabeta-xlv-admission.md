# After Task: admit NB2 / Gamma / Beta X_lv on the R engine='julia' route

**Date**: `2026-06-27`
**Executed by**: Claude (Codex on leave).
**Branch**: `claude/nbgammabeta-xlv-r-20260627`, off `claude/poisson-xlv-r-20260626`
(the held R-Poisson admission). Mirrors that slice for three more families.

## 1. Goal

Extend the R-side `engine = 'julia'` predictor-informed latent-score (`X_lv`)
admission from {Gaussian, Poisson, binomial logit/probit/cloglog} to also include
**NB2, Gamma, and Beta** point fits, matching the Julia bridge's
`_BRIDGE_XLV_FAMILIES` (which already routes these on the held NB2/Gamma/Beta
Julia branches).

## 2. Implemented (`R/julia-bridge.R`)

- `.GLLVM_JULIA_XLV_FAMILIES` gains `"negbinomial"`, `"beta"`, `"gamma"`. Order
  matters: the capability-ledger test compares
  `caps$family[caps$predictor_informed_lv]` to this constant, and the ledger rows
  follow `.GLLVM_JULIA_BRIDGE_FAMILIES` order
  (`… binomial_cloglog, negbinomial, nb1, beta, gamma`), so the constant lists the
  binomials first, then `negbinomial, beta, gamma`.
- The `GJL-GATE-XLV-FAMILY` error message now names the admitted families
  (Gaussian, Poisson, NB2, Gamma, Beta, binomial logit/probit/cloglog) instead of
  the stale "Gaussian and binomial only".

## 3. Tests (`tests/testthat/test-julia-bridge.R`)

- The two `GJL-GATE-XLV-FAMILY` negative tests used `Gamma(link="log")` as the
  "unsupported" example (R-Poisson had flipped them off Poisson). Gamma is now
  admitted, so both are re-pointed to `nbinom1()` — which resolves to the
  Julia key `"nb1"`, confirmed absent from `.GLLVM_JULIA_XLV_FAMILIES`.
- New `test_that("gllvmTMB routes NB2/Gamma/Beta latent-score X_lv through the
  Julia bridge")` — a parametrized mocked test (`local_mocked_bindings` on
  `gllvm_julia_fit`) over `nbinom2()`/`Gamma(link="log")`/`glmmTMB::beta_family()`
  with family-appropriate responses, asserting the resolved key, no `X`, no mask,
  `ci_method = "none"`, and the `X_lv` request shape. Mirrors the proven Poisson
  mocked test.

## 4. Validation — STATIC ONLY (live blocked by env)

- `Rscript -e 'parse(...)'` on both edited files → **parse OK** (syntactically
  valid).
- Family resolution confirmed from `.gllvm_julia_family` source:
  `nbinom2 → negbinomial`, `Gamma → gamma`, `beta_family → beta`,
  `nbinom1 → nb1` (un-admitted).
- Ledger-order analysis confirms the order-sensitive
  `predictor_informed_lv` test will match the reordered constant.
- **Test EXECUTION is blocked:** the local R library is incomplete — `library(gllvmTMB)`
  aborts on a missing dependency (`assertthat`; `devtools`/`roxygen2` also absent),
  so `devtools::test()` / `testthat::test_file()` cannot run here. This is an
  environment gap, not a code issue.

## 5. To validate (when an R env is available)

- `devtools::test(filter = "julia-bridge")` — mocked + gate tests (no Julia
  needed).
- Live smoke against the **Beta Julia worktree** (which carries NB2/Gamma/Beta
  `X_lv`): `GLLVM_JL_PATH=/private/tmp/gllvmjl-beta-xlv-20260626` +
  `gllvm_julia_fit(Y, family = nbinom2()/Gamma(link="log")/beta_family(), num.lv = 1, X_lv = …)`
  → expect `model = "<key>_xlv_rr"`, finite `lv_effects`.

## 6. Held dependency

Like R-Poisson (held on GLLVM.jl #118), this is **held on the NB2/Gamma/Beta Julia
branches merging to `main`** — the R package's CI installs GLLVM.jl from `main`,
which does not yet carry these `X_lv` routes, so the new live paths only succeed
against the local Beta worktree until those merge. CI / X_lv interval admission on
the R side, and the roxygen `@param X_lv` doc refresh, remain follow-ups.
