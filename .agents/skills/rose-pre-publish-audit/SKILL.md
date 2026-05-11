---
name: rose-pre-publish-audit
description: Run Rose's narrow pre-publish consistency gate for gllvmTMB README, vignettes, pkgdown navigation, NEWS, roxygen, or Rd changes.
---

# Rose Pre-Publish Audit

Use this skill before merging any `gllvmTMB` PR that touches public
prose or reference navigation:

- `README.md`
- `vignettes/**/*.Rmd`
- `_pkgdown.yml`
- `NEWS.md`
- roxygen blocks for exported functions in `R/*.R`
- generated `man/*.Rd`

This is a read-only consistency gate. Do not rewrite prose broadly and
do not implement features. Return pass, warn, or fail with concrete
file references.

## Checks

1. Method-list claims match the source `method = c(...)` or
   `match.arg()` choices. Pay special attention to `fisher-z`,
   `profile`, `wald`, and `bootstrap`.
2. Default-value claims match function formals or source defaults.
3. Function names mentioned in prose or references are exported or
   explicitly marked as internal.
4. The 3 x 5 keyword grid matches the current covariance keyword
   surface.
5. Argument-name claims match current function signatures, especially
   `unit`, `unit_obs`, `trait`, `cluster`, `tier`, and `level`.
6. Family lists match exported response-family constructors.
7. Stale terminology is absent from new or touched public prose:
   `trio`, obsolete keyword aliases presented as primary syntax,
   `profile-likelihood default` for correlations, or unsupported
   features described as implemented.

## Suggested Commands

```sh
rg -n "method *=|default|fisher-z|profile|wald|bootstrap" R README.md vignettes man
rg -n "latent|unique|indep|dep|phylo_|spatial_|meta_known_V|trio" README.md vignettes docs R man
rg -n "unit_obs|unit =|trait =|cluster =|tier =|level =" README.md vignettes R man
```

## Output

- `PASS`: no inconsistencies found.
- `WARN`: wording is correct but could mislead a named reader.
- `FAIL`: public prose, generated docs, pkgdown navigation, or source
  defaults disagree.

For every warning or failure, cite the file and the smallest line span
needed to fix it.
