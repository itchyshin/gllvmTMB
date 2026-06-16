# After Task: Cross-Twin Argument And Wording Contract

**Branch**: `codex/r-bridge-grouped-dispersion`
**Date**: `2026-06-16`
**Roles (engaged)**: `Ada / Shannon / Boole / Hopper / Jason / Rose / Grace`

## 1. Goal

Add an explicit consistency gate for wording and argument names across
`gllvmTMB` / `GLLVM.jl` and `drmTMB` / `DRM.jl`, so future bridge and docs
slices do not drift on `engine = "julia"`, `engine_control`, response masks,
coefficient masks, per-trait dispersion, ordinal cutpoints, REML/AI-REML, CI
status, or `pdHess`.

## 2. Implemented

- Added `docs/dev-log/2026-06-16-cross-twin-argument-wording-contract.md`.
- Updated the live coordination board to make the contract a standing gate for
  bridge, engine, and public-docs lanes.
- Updated the draft bridge-landing readout so any future PR opening/rebase uses
  the contract before public wording is promoted.
- Recorded this docs-only audit in the check log.

## 3. Files Changed

- `docs/dev-log/2026-06-16-cross-twin-argument-wording-contract.md`
- `docs/dev-log/2026-06-16-engine-julia-draft-landing.md`
- `docs/dev-log/coordination-board.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-06-16-cross-twin-argument-wording-contract.md`

## 3a. Decisions and Rejected Alternatives

- Decision: reserve `engine_control` for future Julia-side solver, algorithm,
  tolerance, threading, REML, and CI controls. Rationale: using `control`,
  `gllvmTMBcontrol()`, or `drm_control()` for engine-specific choices would
  blur native R/TMB and Julia bridge semantics.
- Decision: keep package-specific names where the estimand differs. Rationale:
  GLLVM `d`, per-trait dispersion, and per-trait ordinal cutpoints are not the
  same concepts as DRM `K`, per-observation `sigma` regression, or one-response
  cumulative-logit cutpoints.
- Rejected alternative: force a single vocabulary across DRM and GLLVM. That
  would make the docs look tidy while hiding real model differences.

## 4. Checks Run

- `git status --short --branch` -> clean before edits.
- `gh pr list --state open --limit 20` -> no open PRs.
- `git log --all --oneline --since="6 hours ago"` -> current Codex programme
  commits only.
- `ls -1 /Users/z3437171/Dropbox/Github\ Local | rg '^(gllvmTMB|GLLVM\.jl|GLLVM\.jl-integration|drmTMB|DRM\.jl)$'`
  -> all four target repos plus the GLLVM integration checkout exist locally.
- `rg -n "engine\s*=\s*[\"']julia|engine_control|gllvmTMBcontrol|gllvm_julia_|GLLVM\.bridge|bridge_capabilities|pdHess|REML|AI-REML|per-trait|grouped dispersion|cutpoints|Xcoef|response mask|missing_response|mixed.family|mixed-family|fixed_effect_X|fixed-effect-X" .`
  in `gllvmTMB` -> confirmed live GLLVM bridge names and status wording.
- `rg -n "engine\s*=\s*[\"']julia|engine_control|drmTMBcontrol|drm_julia_|DRM\.bridge|bridge_capabilities|pdHess|REML|AI-REML|per-trait|grouped dispersion|cutpoints|Xcoef|response mask|missing_response|fixed_effect_X" .`
  in `drmTMB` -> confirmed sibling bridge wording and `pdHess` / missing-data
  wording patterns.
- `rg -n "bridge_fit|bridge_capabilities|engine_control|REML|AI-REML|pdHess|per.trait|per-trait|dispersion|cutpoints|missing_response|fixed_effect_X|Xcoef|mask" .`
  in `GLLVM.jl-integration` -> confirmed `bridge_fit()`,
  `bridge_capabilities()`, grouped dispersion, per-trait ordinal, and mask
  vocabulary.
- `rg -n "bridge_fit|bridge_capabilities|engine_control|REML|AI-REML|pdHess|dispersion|cutpoints|missing_response|fixed_effect_X|Xcoef|mask|engine\s*=\s*[\"']julia|drm_julia" .`
  in `DRM.jl` -> confirmed `drm_bridge()`, `drm_bridge_inference()`,
  `method = :REML`, and response-mask wording.
- `sed -n '360,740p' R/gllvmTMB.R` -> checked the current `gllvmTMB()` R
  signature and `engine = "julia"` dispatch.
- `sed -n '1,180p' ../drmTMB/R/drmTMB.R` -> checked the current `drmTMB()` R
  signature and sibling bridge dispatch.
- `sed -n '1,180p' ../GLLVM.jl-integration/src/bridge.jl` -> checked the
  current GLLVM bridge payload contract.
- `sed -n '1,120p' ../DRM.jl/src/bridge.jl` -> checked the current DRM bridge
  primitive contract.

## 5. Tests Of The Tests

N/A. This is a documentation and governance slice. No executable tests were
added or modified.

## 6. Consistency Audit

The contract now marks these as required future scan handles:

- `engine = "julia"`
- `engine_control`
- `gllvmTMBcontrol`
- `drm_control`
- `REML`
- `AI-REML`
- `pdHess`
- `full parity`
- `complete bridge`
- `CRAN-ready bridge`

Verdict: the current docs now have one explicit location that distinguishes
shared bridge vocabulary from package-specific model terms.

## 7. Roadmap Tick

No `ROADMAP.md` row changed. The contract updates the Twin Finish Programme
coordination layer and applies to future bridge/engine/public-doc lanes.

## 7a. GitHub Issue Ledger

No issue was commented on or closed. The contract should be linked from future
updates to `gllvmTMB#488` and any sibling DRM/GLLVM bridge-drift issue after a
live issue read.

## 8. What Did Not Go Smoothly

The earlier `codex/twin-truth-and-issue-map` commit added a top-level truth-map
file, but that file is not present at the current branch tip. I used
`git show 33287b1:docs/dev-log/2026-06-16-twin-truth-and-issue-map.md` as a
historical source and added a current contract file rather than resurrecting
the old snapshot wholesale.

## 9. Team Learning

- Ada: the next implementation lane should treat wording consistency as a gate,
  not a cleanup after code lands.
- Shannon: pre-edit checks were clean, with no open PRs and no conflicting live
  branch evidence.
- Boole: shared argument names are useful only when the same model concept is
  being exposed.
- Hopper: bridge payload fields must carry labels and scales, especially when
  the R public scale differs from the Julia engine-native scale.
- Jason: DRM is a sibling lesson source, not a vocabulary source to copy
  blindly into GLLVM.
- Rose: status words and CI booleans need fixed meanings before public bridge
  prose expands.
- Grace: docs-only governance did not need package tests, but future PRs still
  need roxygen/pkgdown/check gates when exported docs or examples change.

## 10. Known Limitations And Next Actions

- This contract does not implement `engine_control`.
- This contract does not add `Xcoef_mask` / `Xcoef_fixed`; it only fixes their
  proposed meanings for future design.
- The next implementation lane should still be the grouped-dispersion native
  parity work unless Ada chooses bridge PR publication first.
