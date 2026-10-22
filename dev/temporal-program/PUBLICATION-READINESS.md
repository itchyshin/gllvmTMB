# Publication readiness boundary

The base temporal provider was reviewed and squash-merged through PR #1278 on
2026-09-10. Its merge commit is `c8070797`. The PR's four release shards passed;
the corresponding `main` CI run remains the publication gate until it reaches a
terminal green state. Local temporal tests and package checks remain evidence
for local behavior only. No release, full cross-platform verification, or
general recovery/coverage claim is established by this record.

Before any release decision, record the terminal `main` CI outcome, rerun the
release documentation gates on the merged source, and reconcile every
advertised feature against its acceptance ledger. The narrow
replicated-AR1 `temporal_indep() + kernel_indep()` cell has retained passing
local recovery evidence. The phylogenetic, animal, and spatial source-pair
recovery gates remain failed; all source-pair evidence is local and partial.
