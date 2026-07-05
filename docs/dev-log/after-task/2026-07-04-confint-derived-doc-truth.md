# After Task: Confint Derived Docs Truth

**Branch**: `codex/r-bridge-grouped-dispersion`
**Date**: `2026-07-04`
**Roles (engaged)**: `Ada / Fisher / Grace / Rose / Shannon`

## 1. Goal

Remove stale profile-only wording from the derived-CI `confint()` route docs.
The implementation already supports Wald/bootstrap routes for
`phylo_signal` and `proportion`; the comments and help page needed to say the
same thing.

## 2. Implemented

- `.confint_phylo_signal()` internal comment now names profile, Wald, and
  bootstrap routes.
- `.confint_proportion()` internal comment now names profile, Wald, and
  bootstrap routes.
- `confint.gllvmTMB_multi()` roxygen / Rd text now describes proportion Wald
  and bootstrap helper routing.

## 3. Files Changed

- `R/z-confint-gllvmTMB.R`
- `man/confint.gllvmTMB_multi.Rd`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-07-04-confint-derived-doc-truth.md`

## 3a. Decisions and Rejected Alternatives

Decision: treat this as documentation truth only.

Rejected alternative: expand the slice into new proportion or phylogenetic
signal interval implementation.

Reason rejected: the relevant routes already exist; the defect was stale
wording.

## 4. Checks Run

```sh
Rscript --vanilla -e 'invisible(parse("R/z-confint-gllvmTMB.R")); cat("parse-ok\n")'
```

Outcome: passed.

```sh
Rscript --vanilla -e 'devtools::document(quiet = TRUE)'
```

Outcome: passed; regenerated `man/confint.gllvmTMB_multi.Rd` with the same
unrelated unresolved-link warnings seen earlier in this session.

```sh
rg -n "Profile-only|wald / bootstrap error|proportion.*Profile-only|proportion.*extract_proportions\\(\\)" R/z-confint-gllvmTMB.R man/confint.gllvmTMB_multi.Rd
```

Outcome: no stale proportion / phylogenetic-signal profile-only wording remains.

## 5. Tests of the Tests

No new behavioral test was needed because this slice changed comments and Rd
text only. Existing route tests remain in `test-profile-proportions.R`,
`test-proportions-ci.R`, and `test-confint-derived.R`.

## 6. Consistency Audit

The patch aligns docs with existing code. It does not change any validation-debt
status or claim interval calibration.

## 7. Roadmap Tick

Phase 1 derived-CI route matrix: proportion / phylogenetic-signal doc truth
row closed.

## 7a. GitHub Issue Ledger

No GitHub issue was closed or commented in this slice.

## 8. What Did Not Go Smoothly

No blocker.

## 9. Team Learning

Rose's small stale-wording scan paid off: the implementation was already ahead
of the public help page.

## 10. Known Limitations And Next Actions

- Continue with `rho`, `icc`, spatial profile status, and explicit unavailable
  statuses for non-Gaussian or mixed-family surfaces.
- No Totoro or DRAC compute is needed for this docs-truth row.
