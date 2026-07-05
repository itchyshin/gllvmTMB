# After Task: bootstrap_Sigma Auxiliary Forwarding Docs

Date: 2026-07-05

## Goal

Correct stale `bootstrap_Sigma()` documentation. The function already forwards
stored structured-fit auxiliary arguments for currently wired tiers, but the
caveat still said those arguments were not forwarded.

## Files Changed

- `R/bootstrap-sigma.R`
- `man/bootstrap_Sigma.Rd`
- `docs/dev-log/check-log.md`

## Implementation

- Updated the roxygen caveat to say `phylo_vcv`, `phylo_tree`, `mesh`, and
  `lambda_constraint` are forwarded when present on the fitted object.
- Kept the boundary that new structured engines still need their own bootstrap
  forwarding gate before bootstrap CIs are advertised.
- Regenerated the Rd with `devtools::document()`.

## Validation

```sh
Rscript --vanilla -e 'invisible(parse("R/bootstrap-sigma.R")); cat("parse-ok\n")'
Rscript --vanilla -e 'devtools::document(quiet = TRUE)'
```

Both commands passed.

## Claim Boundary

Documentation only. No bootstrap behavior changed, and no bootstrap calibration
claim moved.
