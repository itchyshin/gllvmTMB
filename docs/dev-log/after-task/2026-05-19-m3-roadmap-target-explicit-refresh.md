# After Task: M3 Roadmap Target-Explicit Refresh

**Branch**: `codex/m3-3-roadmap-refresh-2026-05-19`
**Date**: `2026-05-19`
**Roles (engaged)**: `Ada / Fisher / Curie / Gauss / Boole / Grace / Rose / Shannon`

## 1. Goal

Refresh the M3 source-of-truth documents after PR #201 and PR #202.
The aim was to stop treating the failed R = 200 production run as an
unexplained profile-coverage problem only, and instead make the next
slice explicit: `psi` remains a diagnostic target, while total
`Sigma_unit[tt]` is the primary promotion target for CI-08 / CI-10.

## 2. Implemented

- `ROADMAP.md` now names the M3.3 target-explicit pilot as the next
  small step and keeps the full rerun behind that pilot.
- Design 42 now points to CI-08 / CI-10 instead of the stale
  `M3-COV` placeholder, uses the current `dev/m3-grid.R` /
  `dev/precompute-m3-grid.R` pipeline names, and states that the next
  pilot must record `target` and `ci_method`.
- Design 43 now records single-trait warmup as implemented for M3.4
  phi starts, while keeping the remaining speed ideas as reference
  material.
- Design 44 now carries the target-explicit pilot plan: profile-`psi`
  diagnostic rows, bootstrap total-`Sigma_unit` primary rows, pilot
  cells, artifact columns, summary columns, and pass/fail labels.
- Design 48 now says the warmup + phi-clamp implementation has
  landed and that the remaining M3.4 work is empirical evidence and
  default-policy, not basic implementation.

## 3. Files Changed

- `ROADMAP.md`
- `docs/design/42-m3-dgp-grid.md`
- `docs/design/43-asreml-speed-techniques.md`
- `docs/design/44-m3-3-inference-replacement.md`
- `docs/design/48-m3-4-boundary-regimes.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/coordination-board.md`
- `docs/dev-log/after-task/2026-05-19-m3-roadmap-target-explicit-refresh.md`

## 3a. Decisions and Rejected Alternatives

**Decision**: Use a docs-source-only PR before touching README or
articles.
**Rationale**: Rose found that source-of-truth roadmap/design docs
were stale, while reader-facing honesty should be a separate Pat/Rose
lane after the source docs agree.
**Rejected alternative**: update README and
`simulation-recovery-validated.Rmd` in the same PR.
**Confidence**: high.

**Decision**: make bootstrap total `Sigma_unit[tt]` the next primary
pilot, with profile-`psi` retained as diagnostic.
**Rationale**: the current production columns validate `psi`; total
`Sigma_unit[tt]` is the rotation-invariant promotion target.
**Rejected alternative**: rerun the full 15-cell production grid
immediately.
**Confidence**: high.

**Decision**: keep `ordinal_probit-d1` out of the first bootstrap
pilot.
**Rationale**: ordinal-probit uses family ID 14, and the current
simulation path is not yet a legitimate ordinal bootstrap path.
**Rejected alternative**: include ordinal-probit in the first pilot
and interpret fallback simulation as evidence.
**Confidence**: high.

## 4. Checks Run

- `gh pr list --state open --repo itchyshin/gllvmTMB --json number,title,headRefName,files --jq '.[] | {number,title,headRefName,files: [.files[].path]}'`
  - Outcome: only PR #203 was open; it touches CI workflow,
    `CONTRIBUTING.md`, check-log, coordination board, and its own
    after-task report. No collision with the five roadmap/design
    files in this branch.
- `git log --all --oneline --since='6 hours ago'`
  - Outcome: recent commits were PR #203 plus M3 evidence PRs #199 -
    #202; no competing edit to the same roadmap/design files.
- `rg -n 'M3-COV|failure-mode triage|precompute-vignettes|follow-on PR per two-PR pattern|Implementation follow-on PR|Easy add, not implemented|No implementation in this PR|proposed M3.4 fix|profile-likelihood specifically|post-CRAN\\. No v0\\.2\\.0' ROADMAP.md docs/design/42-m3-dgp-grid.md docs/design/43-asreml-speed-techniques.md docs/design/44-m3-3-inference-replacement.md docs/design/48-m3-4-boundary-regimes.md`
  - Outcome: no hits.
- `git diff --check`
  - Outcome: clean.
- Coordination board update
  - Outcome: PR #203 moved out of active lane status; the M3 roadmap
    refresh branch became Ada's active lane.

## 5. Tests of the Tests

No tests were added or modified. This was a roadmap/design
source-of-truth refresh, not an engine or test-harness change.

## 6. Consistency Audit

- Stale target/status scan: the `rg` command in Section 4 returned no
  hits for the high-risk stale phrases Rose identified.
- M3.4 implementation status: Design 43, Design 48, and ROADMAP now
  agree that `init_strategy = "single_trait_warmup"` and the phi
  clamp are implemented, covered by MIS-16 / MIS-17, and still need
  target-explicit empirical evidence before default-policy changes.
- M3.3 target status: ROADMAP, Design 42, and Design 44 now agree
  that total `Sigma_unit[tt]` is the primary promotion target and
  `psi` is diagnostic.

## 7. Roadmap Tick

M3 remains `3/8` and in progress. This refresh changes the next
action, not the completion count: M3.3 moves from generic
failure-mode triage to target-explicit pilot planning, and M3.4 is
marked partial with implemented mitigations plus pending empirical
evidence.

## 8. What Did Not Go Smoothly

The roadmap was ready for revision while PR #203 still owned
append-only process files. Ada kept the branch in a separate worktree,
waited for PR #203 to merge, rebased cleanly, and only then appended
the check-log entry.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

**Ada** kept the slice bounded to source-of-truth docs and prevented
the reader-facing honesty lane from mixing into this PR.

**Fisher** reframed the M3.3 gate around the target of inference:
coverage is not meaningful unless the artifact says whether the row
validates `psi` or total `Sigma_unit[tt]`.

**Curie** specified the smallest useful pilot cells, artifact
columns, summary columns, and smoke/pilot/promotion replicate counts.

**Gauss** recommended bootstrap total-Sigma rows before a derived
profile fix-and-refit path, because the latter is a larger numerical
slice.

**Boole** kept the formula/API status clean: warmup is an opt-in
control surface, not a new grammar feature.

**Grace** kept PR #203 under watch so CI workflow work and roadmap
refresh work did not collide.

**Rose** found the stale roadmap/design wording and held the line
that README/article honesty belongs in a later Pat/Rose lane.

**Shannon** was applied as a coordination check via open-PR and
recent-commit inspection before editing shared docs.

## 10. Known Limitations And Next Actions

- The next implementation slice is the M3.3 target-explicit pilot:
  `gaussian-d2`, `nbinom2-d1`, and `mixed-d2`; `ordinal_probit-d1`
  waits until ordinal simulation supports family ID 14.
- The next reader-facing slice is Pat/Rose honesty for README and
  `vignettes/articles/simulation-recovery-validated.Rmd`.
