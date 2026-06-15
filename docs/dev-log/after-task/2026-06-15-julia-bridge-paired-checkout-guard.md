# After Task: Julia Bridge Paired-Checkout Guard

Date: 2026-06-15

## Goal

Prevent bridge claims from implying that every local GLLVM.jl worktree supports
the same payloads.

## Implemented

- Added a NEWS boundary stating that `engine = "julia"` support is only as broad
  as the paired GLLVM.jl checkout supplied through `GLLVM_JL_PATH`.
- Added a check-log guard explaining that the current green X/CI/post-fit bridge
  evidence targets `/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration`.
- Recorded that `/Users/z3437171/Dropbox/Github Local/GLLVM.jl` is currently a
  dashboard branch whose `src/bridge.jl` still rejects fixed-effect covariates.

## Files Changed

- `NEWS.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-15-julia-bridge-paired-checkout-guard.md`

## Tests Added

None. This is a claim-boundary patch following Rose's read-only audit.

## Benchmark Numbers

N/A -- documentation/ledger boundary only.

## R-Parity Verdict

Parity: N/A -- no fit behavior changed.

## Checks Run

```sh
rg -n "fixed-effect covariates X are not wired|function bridge_fit|bridge_fit\\(" src/bridge.jl
```

Result in `/Users/z3437171/Dropbox/Github Local/GLLVM.jl`: the dashboard
worktree still contains `bridge_fit: fixed-effect covariates X are not wired on
this branch`.

```sh
rg -n "fixed-effect covariates X are not wired|function bridge_fit|bridge_fit\\(" src/bridge.jl
```

Result in `/Users/z3437171/Dropbox/Github Local/GLLVM.jl-integration`: the paired
integration checkout contains the current X-aware bridge.

## Consistency Audit

Rose's sidecar audit reported that named-pair tests against the dashboard
worktree are not green. The ledger now keeps integration-checkout evidence
separate from dashboard-worktree state.

## GitHub Issue Maintenance

No issue action taken locally. The reconciliation of the integration branch into
the dashboard/main worktree remains a separate maintainer-gated Julia branch
decision.

## What Did Not Go Smoothly

The board and NEWS were accurate for the integration checkout used in the test
commands, but too easy to misread as evidence for the dashboard worktree.

## Team Learning

Rose lens: every bridge claim needs an explicit target engine checkout until the
Julia branches are reconciled.

## Remaining Risks

- Users with stale GLLVM.jl installations can still hit Julia-side payload
  rejection errors.
- Full branch reconciliation remains pending.

## Known Limitations

This patch does not merge GLLVM.jl branches, add capability negotiation, or make
the dashboard worktree support X payloads.

## Next Command

```sh
git diff --check
```

## Rose Verdict

Rose verdict: PASS WITH NOTES -- the target-checkout boundary is now explicit;
the actual GLLVM.jl branch reconciliation remains open.
