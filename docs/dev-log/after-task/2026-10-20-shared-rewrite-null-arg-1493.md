# Literal NULL argument no longer crashes `.shared_rewrite()` (#1493)

## Scope
`.shared_rewrite()` (`R/column-coef-foundation.R`) rebuilt each call with
`out[[i]] <- .shared_rewrite(out[[i]], ...)`. For a literal `NULL` argument,
`[[<-` deletes the element, so the call shrank and the loop indexed past its
end ("subscript out of bounds"). Positional
`spatial_dep(0 + trait | group, NULL, mesh, 0.5)` hit this; the named form did not.

## Outcome
The loop now assigns with `out[i] <- list(...)`, which keeps a `NULL` in place.

## Checks
- `test-issue-1493-shared-rewrite-null-arg.R`: red on main (subscript out of
  bounds), 3 pass on this branch.
- `test-column-coef-foundation.R` 213 pass; `test-column-coef-spatial-parser.R` 23 pass.

## Follow-up
The second edge case in #1493 (a symbol `rho` in `.warn_spatial_grouping_token()`)
is not changed here.
