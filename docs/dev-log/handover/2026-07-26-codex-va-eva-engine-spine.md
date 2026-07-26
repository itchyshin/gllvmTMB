# VA/EVA private engine spine — handoff

## State

Worktree: `/private/tmp/gllvmtmb-va-eva-engine-spine`
Branch: `codex/va-eva-engine-spine-20260726`
Base: `966d24bb` (`origin/main` at lane creation)

At closeout the branch is `ahead 1, behind 1` of the moving `origin/main`.
Do not rebase or merge it automatically: first repeat the lane preflight and
resolve the package-boundary decision below against the then-current main.

The branch contains a private VA/EVA adapter, sealed EVA Gate-1 files,
comparator, provenance gate, receipts, and after-task record.  No public API
or documentation surface was altered.

## Resume safely

```sh
cd /private/tmp/gllvmtmb-va-eva-engine-spine
Rscript --vanilla dev/va-eva-engine-spine/check-sealed-sources.R .
Rscript --vanilla -e 'devtools::test(filter = "approximation-engine")'
VA_EVA_COMPARATOR_SMOKE=true Rscript --vanilla dev/va-eva-comparator.R
```

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
