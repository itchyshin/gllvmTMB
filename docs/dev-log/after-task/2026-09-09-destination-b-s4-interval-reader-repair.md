# After Task: Destination B S4 stored-interval reader repair

## Goal

Repair the authorised R bridge reader so an `available` stored Julia Wald
interval cannot be reversed, collapsed, non-finite, or incompatible with its
named estimate. This is not a new model or a widened engine route.

## Implemented

`confint.gllvmTMB_julia_phylo_rr()` now checks every row marked
`status = "available"` before it filters unavailable rows. It rejects a
non-finite estimate, lower endpoint, or upper endpoint; requires strictly
positive width; and requires the estimate to lie in the closed interval. The
diagnostic identifies the offending target. Unavailable rows retain their
previous behaviour.

## Mathematical Contract

For an available target with estimate \(\hat\theta\) and stored endpoints
\((L,U)\), the reader requires finite values and
\[
L < U, \qquad L \leq \hat\theta \leq U.
\]
This validates internal consistency of stored transformed-Wald output; it does
not assert endpoint equality with native R profiles or any coverage property.

## Files Changed

- `R/julia-bridge.R`
- `tests/testthat/test-julia-phylo-rr-bridge.R`
- `docs/dev-log/check-log.md`
- this report

No roxygen text, generated Rd file, NAMESPACE entry, public signature,
vignette, formula grammar, TMB C++, or R likelihood code changed. Therefore
no documentation regeneration or article render is required for this
reader-only validation repair.

## Checks Run

- RED: unchanged reader, hostile endpoint tests — 26 passing expectations and
  six expected failures; zero errors, warnings, and skips; exit 1.
- RED for the estimate-only guard: a test-local mutation removing that exact
  predicate produced the expected named-diagnostic failure. Production code
  was not regressed.
- GREEN: exact repaired source method rebound into the established unchanged
  S4 package namespace, focused Tree reader set — **11 tests, 35/35
  expectations**, no failures/errors/warnings/skips, 3.3 s.
- `git diff --check` — pass.

The repair worktree lacks a compiled DLL, so no compilation, refit, full
`devtools::test()`, `devtools::check()`, or pkgdown build was run. The changed
method is pure R post-fit validation; the focused runner loaded the unchanged
base namespace with `compile = FALSE` and bound the exact candidate method.

## Tests Of The Tests

The new hostile tests cover a real reproduced defect: reversed `[2,-2]` was
previously returned as `available`. They also cover zero width, estimates below
and above bounds, `NA`/`Inf`/`-Inf` in each endpoint and estimate, plus the
two boundary acceptances where the estimate equals the lower or upper endpoint.
The estimate guard's test was proven effective by a test-local predicate
mutation before the intact method passed.

## Consistency Audit

Searched the public wrapper and limits wording with:

```sh
rg -n "gllvm_julia_phylo_rr|engine = \"julia\"|phylo_rr|0.7 parity" README.md NEWS.md docs vignettes R tests
```

The result remains consistently described as an explicit experimental
post-fit Tree exception, not general `engine = "julia"` support or 0.7 parity.
No stale claim was introduced.

## What Did Not Go Smoothly

The initial candidate predicate coupled finiteness to interval availability,
which would have silently filtered a corrupt `available` row. Independent
review exposed the hole. Splitting status, finite-value, and bound checks made
the diagnostic fail closed and made the test contract legible.

## Team Learning

Fisher's interval lens found that a non-empty `confint()` is insufficient:
each required stored target must be internally coherent before user-facing
output is returned. The adversarial reader check also prevented a false S4
acceptance claim.

## Known Limitations

This repair does not settle the remaining S4 acceptance gates: exact seven
target availability, immutable frozen-pair provenance and replay, the one
authoritative public Tree route, dense-VCV/pedigree routing boundaries,
phylogenetic signal, recovery, coverage, or any broad R--Julia parity claim.

## Next Actions

Harden the S3b frozen-pair receipt runner and reconcile the S4 route/census
before rerunning the single authoritative Tree workflow against the repaired
bridge and current Julia consumer.
