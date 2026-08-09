# G1 source-provenance repair

Date: 2026-08-08  
Gate: G1 source truth  
Current verdict: **PASS for G1 source provenance**. Exact-tarball inventory,
remains a separate S13/S15 release gate. Maintainer GPL-3/role consent and logo
redistribution rights were explicitly confirmed on 2026-08-08 and are recorded
in `2026-08-08-maintainer-release-rights-authorization.md`.

## Why the initial source failed

The pre-G1 tree described the main loading unpacker as a direct glmmTMB port
while declaring the package GPL-3 and calling the C++ engine wholly native.
A package-wide follow-up found the same indexed expression in the installed VA
and EVA templates, an R constraint helper, and tests. It also found that
`R/families.R` substantially matched sdmTMB's family layer. The pinned sdmTMB
0.7.4.9024 copyright ledger records selected inherited glmmTMB material as
AGPL-3, so attribution alone cannot establish a clean GPL-3 chain for the
family file.

## Closed repairs

- `src/gllvmTMB.cpp` now uses one independently written cursor unpacker across
  all eight Laplace covariance routes.
- `inst/tmb/gllvmTMB_va_r3.cpp` and `inst/tmb/gllvmTMB_eva.cpp` use independent
  cursor traversal and exact-exhaustion checks.
- `R/lambda-constraint.R` and the phylogenetic-slope test helper no longer carry
  the old indexed expression.
- The loading contract uses explicit expected matrices rather than retaining
  the old expression as its oracle.
- Compiled Laplace, VA, and EVA checks reproduced the expected loadings and
  implied covariance exactly, with finite objectives and gradients. Focused
  ordinary, W-tier, kernel, phylogenetic-slope, spatial-slope, EVA, VA, and
  constraint tests passed.
- A build-included source scan found no old packed-index expression. Four
  historical textual references remain only under build-excluded `dev/`.
- Public and internal spatial wording now says the current helpers were
  substantially rewritten after an earlier GPL-3 sdmTMB-derived
  implementation. The false clean-room claim was removed.
- `inst/COPYRIGHTS` now records sdmTMB spatial lineage, same-author drmTMB
  missing-predictor reuse, Laplace/VA/EVA template boundaries, legacy plotting
  and logo lineage, generated fixtures, and lifecycle MIT badge assets.
- The missing `man/figures/lifecycle-experimental.svg` referenced by generated
  help was restored byte-identically from lifecycle 1.0.5.

## Independently authorised family-constructor repair

After explicit maintainer authorisation, `R/families.R` was replaced by a
data-driven constructor layer derived from the public family-object contract
and standard R link semantics. It preserves all 27 exported constructor
formals, classes, required fields, defaults, non-default delta controls, and
truncated inverse-link behaviour against the installed 0.6.0 black-box
contract. The new contract test passed 102 expectations. Existing enum,
integration-fence, Gamma, lognormal, delta-Gamma, delta-lognormal, and compiled
three- and five-family tests passed. `devtools::document()` regenerated only
`man/families.Rd` for this repair.

A post-rewrite scan of `R/families.R`, `man/families.Rd`, and the new contract
test found no inherited attribution marker or implementation vocabulary:
`modified from`, `derived from`, `sdmTMB`, `glmmTMB`, `linktemp`, `okLinks`,
`add_to_family`, `logspace_add`, or `logspace_sub`. `git diff --check` passed.
The complete ordinary suite and all 161 heavy files subsequently passed on the
post-rewrite source; the exact shard accounting is in the G1 heavy-suite
receipt.

This is a technical provenance assessment, not legal advice. It closes the G1
source-provenance discrepancy; the exact 0.7 tarball and maintainer/logo rights
must still close at S13/S15 before submission.
