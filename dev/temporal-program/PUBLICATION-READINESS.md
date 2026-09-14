# Publication readiness boundary

At the 2026-09-10 audit, `codex/temporal-program-20260909` contained local-only
temporal work. Local temporal tests and package checks were evidence for local
behavior only.

## Current three-OS package evidence

On 2026-09-14, GitHub Actions run
[`34842749688`](https://github.com/itchyshin/gllvmTMB/actions/runs/34842749688)
completed successfully on Linux, macOS, and Windows for exact branch head
`ae0dd8b0f3fd13c0d39413c38e4d74cfeb81e24a`. The retained receipt is
`results/publication-ci-34842749688-20260914.rds`; the publication verifier
re-queried the live run and emitted `TEMPORAL_PROGRAM_PUBLICATION_PASS`.

This verifies that the package test suite passed on those three platforms at
that commit. It does not establish a merged or released feature, turn local
recovery fixtures into general recovery or coverage evidence, or erase any
retained failed source-pair gate.

Before any merge or release decision, split or review the branch at least by
the base temporal provider and each later lifecycle route, rerun the release
documentation gates, and reconcile every advertised feature against its
acceptance ledger. The narrow
replicated-AR1 `temporal_indep() + kernel_indep()` cell has retained passing
local recovery evidence. The phylogenetic, animal, and spatial source-pair
recovery gates remain failed; all source-pair evidence is local and partial.
