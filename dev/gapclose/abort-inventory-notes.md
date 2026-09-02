# Abort/Stop Call Inventory — gllvmTMB Scout Report

## Counts Per File

| File | Total | Bare | Internal | OK (has next step) |
|------|-------|------|----------|-------------------|
| R/gllvmTMB.R | 41 | 21 | 0 | 20 |
| R/parse-multi-formula.R | 10 | 7 | 0 | 3 |
| R/isdm-sources.R | 23 | 6 | 7 | 10 |
| R/family-cdf-args.R | 3 | 3 | 0 | 0 |
| R/fit-multi.R | 258 | 162 | 16 | 80 |
| R/brms-sugar.R | 66 | 47 | 0 | 19 |
| R/suggest-lambda-constraint.R | 14 | 12 | 0 | 2 |
| R/ridge-path.R | 2 | 2 | 0 | 0 |
| R/diagnose.R | 3 | 3 | 0 | 0 |
| R/methods-gllvmTMB.R | 34 | 17 | 1 | 16 |
| R/families.R | 11 | 10 | 0 | 1 |
| R/mesh.R | 30 | 28 | 0 | 2 |
| **TOTAL** | **495** | **318** | **24** | **153** |

**Key findings:**
- 318 bare errors (64.2%) — tell user WHAT is wrong but NOT WHAT TO DO
- 24 internal errors (4.8%) — user cannot act on these
- 153 ok errors (30.9%) — have next steps (instructions)

**Largest refusal pools:** fit-multi.R (162 bare), brms-sugar.R (47 bare)

---

## Verbatim Refusal Text — R/brms-sugar.R

### Lines 2380–2440: augmented LHS refusal (line 2418)

```r
cli::cli_abort(c(
  "{.fn {fn}} augmented LHS is not yet supported.",
  "i" = "You wrote {.code {fn}({deparse(bar)})}.",
  "x" = "This wrapper accepts only intercept-only {.code 0 + {trait_col} | g} or {.code 1 | g} forms.",
  ">" = "Use the source-specific {.fn *_indep}, {.fn *_latent}, or {.fn *_dep} keyword when you need a supported intercept-and-slope covariance."
))
```

**Status:** This already HAS a next step (the `">"` bullet).

---

### Lines 4540–4580: phylo_indep LHS refusal (line 4563)

```r
cli::cli_abort(c(
  "{.fn phylo_indep} LHS richer than {.code 0 + trait} is not yet supported.",
  "i" = "Got LHS: {.code {deparse(lhs_bar)}}.",
  ">" = "Trait-specific phylogenetic random slopes (e.g. {.code phylo_indep(0 + trait + trait:x | species)}) are reserved for a future release; use {.code phylo_indep(0 + trait | species)} for the per-trait phylogenetic variance fit."
))
```

**Status:** This already HAS a next step (the `">"` bullet).

---

## Hardcoded `unit = "site"` Defaults

| File | Line | Context |
|------|------|---------|
| R/gllvmTMB.R | 143 | Comment/doc example |
| R/gllvmTMB.R | 625 | Function argument default |
| R/brms-sugar.R | 510 | Doc example |
| R/brms-sugar.R | 519 | Doc example |
| R/brms-sugar.R | 601 | Doc example |
| R/brms-sugar.R | 830 | Doc example |
| R/brms-sugar.R | 1219 | Doc example |
| R/brms-sugar.R | 1278 | Doc example |
| R/brms-sugar.R | 1354 | Doc example |
| R/brms-sugar.R | 1454 | Doc example |
| R/brms-sugar.R | 1461 | Doc example |
| R/brms-sugar.R | 1468 | Doc example |
| R/brms-sugar.R | 1473 | Doc example |
| R/brms-sugar.R | 1520 | Doc example |
| R/brms-sugar.R | 1567 | Doc example |
| R/brms-sugar.R | 1628 | Doc example |
| R/brms-sugar.R | 1632 | Doc example |
| R/brms-sugar.R | 1671 | Doc example |
| R/brms-sugar.R | 1675 | Doc example |
| R/brms-sugar.R | 1856 | Doc example |
| R/brms-sugar.R | 1932 | Doc example |
| R/brms-sugar.R | 1936 | Doc example |
| R/brms-sugar.R | 2085 | Doc example |
| R/ridge-path.R | 133 | Function argument default |
| R/suggest-lambda-constraint.R | 85 | Doc example |
| R/suggest-lambda-constraint.R | 103 | Function argument default |
| R/suggest-lambda-constraint.R | 550 | Function argument default |
| R/families.R | 192 | Doc example |
| R/diagnose.R | 1548 | Doc example |
| R/diagnose.R | 2014 | Doc example |

**Key:** Most are in documentation/examples. The live defaults are at:
- R/gllvmTMB.R:625
- R/ridge-path.R:133
- R/suggest-lambda-constraint.R:103, 550

