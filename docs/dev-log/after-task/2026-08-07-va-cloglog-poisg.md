# After-task: cloglog PoisG closed-form VA (opt-in)

**Date:** 2026-08-07  
**Branch:** `codex/va-gh-all-families`  
**Lane:** VA GH all-families / S1 binomials

## Goal

Implement gllvm-matched truncated-Poisson / **PoisG** closed-form VA for
binomial-cloglog in the R3 template, without flipping Design-110 `auto` (GH).

## Mathematical contract

gllvm 2.0.13 `src/gllvm.cpp` ~3303–3311 (`method="VA"`, `extra==2` cloglog),
with `cQ = v/2` and `μ = exp(η + cQ)`:

\[
y\log\bigl(1-\mathrm{e}^{-\mu\mathrm{e}^{-cQ}}\bigr)
-(N-y)\mu + \mu(\mathrm{e}^{-cQ}-1).
\]

Algebraically (our `μ = E_q[η]`, `v = Var_q[η]`):

\[
y\cdot\mathrm{cloglog\_logp}(\mu) + \mathrm{e}^{\mu}
-(n-y+1)\,\mathrm{e}^{\mu+v/2}.
\]

This is a **different objective** from cloglog GH (which quadratures
`E[\mathrm{cloglog\_logp}(η)]` and uses the exact failure mean). Labelled
`ELBO_POISG`. No public likelihood / grammar / family change; private
`eval_method` only.

## Routing decision

| knob | choice |
|---|---|
| `auto` / Design 110 default | **stays GH** for `binomial_cloglog` |
| `eval_method = "poisg"` | opt-in, cloglog-only |
| public `gllvmTMBcontrol(va_eval_method=)` | **unchanged** (`auto`/`jj`/`gh` only); `poisg` refused like `ac`/`ac2` |
| NEWS / public fence | **no claim** |

## How to call

```r
# private R3 API only
fit <- gllvmTMB:::.va_r3_fit(
  ..., family = "binomial_cloglog",
  eval_method = "poisg", H = 7L
)
# objective_type == "ELBO_POISG"; template code 4
```

## Checks

- `NOT_CRAN=true` `testthat::test_file("tests/testthat/test-va-poisg-expectation.R")`
  → PASS (formula grid vs gllvm, compiled REPORT match, smoke fit, refuse
  non-cloglog, registry wiring).
- `test-va-control-exposure.R` → PASS (`poisg` refused on public control).
- Cheap H2H: 8 seeds, n=120 p=8 q=2, GH vs PoisG vs gllvm VA
  (`lanes/va-s1-binomials/scripts/probe-cloglog-poisg-h2h.R`,
  `/private/tmp/va-s1-binomial-poisg-h2h-20260807`).

### H2H smoke numbers (median over 8 seeds)

| arm | β RMSE | Σ rel Frob | Σ trace |
|---|---:|---:|---:|
| `gtmb_gh` | 0.169 | 1.86 | 3.90 |
| `gtmb_poisg` | 0.141 | **1.00** (Σ̂≈0) | ~1e−10 |
| `gllvm_va` | 0.141 | (runaway / scorer caveats) | large |

PoisG vs gllvm β RMSE agree to ~1e−7 abs per seed. **Σ caveat:** PoisG
collapses loadings-only Σ (rel Frob = 1 vs planted = zero estimator). Matching
gllvm VA on β is **not** a Σ-recovery claim.

## Files

- `inst/tmb/gllvmTMB_va_r3.cpp` — `va_r3_cloglog_poisg_expectation`, code 4
- `R/va-r3-proto.R` — registry tiers, resolve/code/objective labels
- `R/gllvmTMB.R` — comment that `poisg` stays internal
- `tests/testthat/test-va-poisg-expectation.R` — new
- `tests/testthat/test-va-control-exposure.R` — refuse public `poisg`
- `docs/design/110-va-gh-h7-all-scalar-families.md` — PoisG note; auto stays GH
- `lanes/va-s1-binomials/protocol/gllvm-comparator.md` — link-tier table
- `lanes/va-s1-binomials/scripts/probe-cloglog-poisg-h2h.R` — optional H2H

## Follow-up

None blocking. Optional: Totoro larger cloglog ladder with PoisG arm; do not
flip `auto` without G0.
