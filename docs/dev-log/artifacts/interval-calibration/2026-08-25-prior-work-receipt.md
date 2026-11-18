# Prior-work receipt — interval-calibration release

Date: 2026-08-25
Branch: `codex/interval-calibration-release`

## Evidence

- repo git state: `HEAD=f5ba7bdb2e454f3d3cda34936f0bb9b746459e68`, `origin/main=482c9d372c7dc100f988f41f80d1b4cc3ce8a8e4`; branch base is exact `f5ba7bdb2e454f3d3cda34936f0bb9b746459e68` atop `origin/main` `482c9d372c7dc100f988f41f80d1b4cc3ce8a8e4`.
- lane preflight: `/Users/z3437171/shinichi-brain/tools/lane_preflight.sh` succeeded with `SECOND codex LANE ACTIVE`; current branch `codex/interval-calibration-release`; six other active lanes; no overlapping interval leases, then the exact lease was granted.
- Ask-Brain: queried the prior-work record with `search_all_projects: true` for `interval calibration`, `CI-08` through `CI-15`, and `GLLVM.jl`; no cloud/web search was used.
- deterministic: `git log --all --oneline --grep='interval\\|calibration' -i` and `git show codex/methods-superarc-plan:docs/dev-log/artifacts/methods-superarc/interval-target-ledger.md` were used to identify prior routes and the target ledger.
- GLLVM.jl: sister-package check was limited to repository/history evidence and found no basis to transfer interval-calibration claims from GLLVM.jl to gllvmTMB.
- lease: the initial lease write failed (the target path was not writable under the first lease attempt); a genuine granted lease was then obtained for `docs/dev-log/artifacts/interval-calibration/**`.

## Verdict

`resume existing routes + build-the-gap`

The ledger is the source for route status and denominator rules. Existing certified or limited evidence is retained as route-specific; missing calibration remains a gap rather than being inferred from availability.
