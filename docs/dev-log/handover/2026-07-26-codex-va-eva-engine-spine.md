# VA/EVA private engine spine — handoff

## State

Worktree: `/private/tmp/gllvmtmb-va-eva-engine-spine`
Branch: `codex/va-eva-engine-spine-20260726`
Base: `966d24bb` (`origin/main` at lane creation)

At continuation closeout the branch has local commits and remains behind the
moving `origin/main`.  Do not rebase or merge it automatically: first repeat
lane preflight and resolve the package-boundary decision below against the
then-current main.

The branch contains a private VA/EVA adapter, sealed EVA Gate-1 files,
comparator, provenance gate, receipts, and after-task record.  No public API
or documentation surface was altered.

## Resume safely

```sh
cd /private/tmp/gllvmtmb-va-eva-engine-spine
Rscript --vanilla dev/va-eva-engine-spine/check-sealed-sources.R .
Rscript --vanilla -e 'devtools::test(filter = "approximation-engine")'
VA_EVA_COMPARATOR_SMOKE=true Rscript --vanilla dev/va-eva-comparator.R
sh dev/va-eva-executable-comparisons.sh multitrial
sh dev/va-eva-executable-comparisons.sh bernoulli
sh dev/va-eva-executable-comparisons.sh va_exact
sh dev/va-eva-executable-comparisons.sh eva_exact
sh dev/va-eva-executable-comparisons.sh assemble
Rscript --vanilla dev/va-eva-engine-spine/check-executable-comparison.R .
```

Each executable-comparison command is intentionally a separate shell/R
process.  Do not combine them into one R session: the prototype template DLL
reload order is not evidence.

The Bernoulli external calls currently finish at a separated boundary and are
recorded as `boundary_or_invalid_for_comparison`.  Do not reinterpret their
optimizer status as agreement with sealed EVA.

## Blocking decision

`R/eva-proto.R` is byte-identical sealed source and uses `jsonlite`, while
`DESCRIPTION` has no `jsonlite` declaration and this Arc was forbidden to edit
it.  Do not merge or expose this as package-supported code until the maintainer
chooses one of:

1. approve an explicit metadata dependency, then run the package gate; or
2. approve a dev-only containment design that preserves the sealed source
   checksum and does not pretend to be package code.

Do not solve this by editing the sealed EVA blob, importing Gate-2R, adding the
VA Bernoulli widening, or exposing `method =` in `gllvmTMB()`.

## Truth boundary updated upstream

Before extending exact comparisons beyond the retained scalar probes, read
`origin/main:docs/dev-log/handover/2026-07-26-codex-handover-va-variance-gate.md`.
It records a non-convergent brute-force ladder in the high-variance/sparse
regime.  Do not use its reported value as truth or average it into a result.
