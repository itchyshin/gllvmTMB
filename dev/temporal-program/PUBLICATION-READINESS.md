# Publication readiness boundary

At the 2026-09-10 audit, `codex/temporal-program-20260909` contains local-only
temporal work. Local temporal tests and package checks are evidence for local
behavior only. This branch has not been pushed, reviewed as a PR, or exercised
on Linux/macOS/Windows CI.

Before any merge or release decision, split or review the branch at least by
the base temporal provider and each later lifecycle route; push the reviewed
candidate, obtain three-OS CI, rerun the release documentation gates, and
reconcile every advertised feature against its acceptance ledger. The narrow
replicated-AR1 `temporal_indep() + kernel_indep()` cell has retained passing
local recovery evidence. The phylogenetic, animal, and spatial source-pair
recovery gates remain failed; all source-pair evidence is local and partial.
