# Local package-check receipt — 2026-09-09

## Scope

This receipt covers the current local branch
`codex/temporal-program-20260909` at commit `00055da1f`, including the
bounded temporal bootstrap, direct-profile, and selection-helper acceptance
tests added after the source-pair work. It is local evidence only; it does not
substitute for the pending three-operating-system publication gate.

## Commands and results

```text
Rscript --vanilla -e 'pkgdown::check_pkgdown()'
PASS: No problems found.

Rscript --vanilla -e 'devtools::check(args = "--no-manual", quiet = TRUE)'
Duration: 22m 21s
0 errors | 0 warnings | 2 notes
```

The two `R CMD check` notes are environment observations: current system time
could not be remotely verified, and the temporary directory contained
`xcrun_db`. Neither names a package source, installed file, test, or example
failure.

The same branch also passed:

```text
Rscript --vanilla dev/temporal-program/verify.R lifecycle
TEMPORAL_PROGRAM_LIFECYCLE_PASS

Rscript --vanilla dev/temporal-program/verify.R simulation
TEMPORAL_PROGRAM_SIMULATION_PASS
```

## Boundary

This is not a merge, release, cross-platform verification, or general
recovery/coverage result. The three-OS receipt and retained phylogenetic
recovery campaign remain pending their separate gates.
