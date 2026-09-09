# Publication readiness boundary

At the 2026-09-09 audit, `codex/temporal-program-20260909` was clean and 26
commits ahead of `origin/main`, changing 103 files. Local temporal tests and
package checks are evidence for local behavior only. This branch has not been
pushed, reviewed as a PR, or exercised on Linux/macOS/Windows CI.

Before any merge or release decision, split or review the branch at least by
the base temporal provider and each later lifecycle route; push the reviewed
candidate, obtain three-OS CI, rerun the release documentation gates, and
reconcile every advertised feature against its acceptance ledger. Source pairs
remain refused, and the kernel recovery failure remains a negative admission
result.
