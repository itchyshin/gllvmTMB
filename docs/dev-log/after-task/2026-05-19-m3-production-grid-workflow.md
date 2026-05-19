# After Task: M3.3 production grid workflow

**Branch**: `codex/m3-production-grid-workflow-2026-05-19`
**Date**: 2026-05-19
**Roles (engaged)**: Ada, Curie, Fisher, Grace, Rose

## 1. Goal

Install the reproducible GitHub Actions dispatch lane for the M3.3
R = 200 production grid, without changing the inference method or
claiming new coverage evidence before artifacts exist.

## 2. Implemented

- Added `.github/workflows/m3-production-grid.yaml`, a manual
  `workflow_dispatch` workflow with a 5-family x 3-dimension matrix.
- Added per-cell CLI filters to `dev/precompute-m3-grid.R`:
  `--family=`, `--d=`, `--n-reps=`, `--init-strategy=`,
  `--out-dir=`, and `--out-prefix=`.
- Threaded the already-implemented `gllvmTMBcontrol(init_strategy = ...)`
  option through `dev/m3-grid.R`.
- Updated Design 44 so its CI plan matches the current manual
  Actions/artifact workflow and names the profile-primary M3.3a path.
- Refreshed `ROADMAP.md` top-level queue and marked this branch active
  in the coordination board.

No public R API, likelihood, formula grammar, family, NAMESPACE,
generated Rd, vignette, or pkgdown navigation changed.

## 3. Files Changed

- `.github/workflows/m3-production-grid.yaml` (new)
- `dev/m3-grid.R`
- `dev/precompute-m3-grid.R`
- `docs/design/44-m3-3-inference-replacement.md`
- `ROADMAP.md`
- `docs/dev-log/coordination-board.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/after-task/2026-05-19-m3-production-grid-workflow.md`

## 3a. Decisions and Rejected Alternatives

- **Decision**: matrix one GitHub Actions job per M3 cell.
  **Rationale**: each cell produces a separable artifact; `fail-fast:
  false` preserves partial evidence when one cell fails.
  **Rejected alternative**: run all 15 cells in one job.
  **Confidence**: high.
- **Decision**: upload per-cell artifacts, not commit production RDS in
  this PR.
  **Rationale**: this PR installs dispatch only; evidence classification
  needs the completed manual run.
  **Rejected alternative**: precommit placeholder production outputs.
  **Confidence**: high.
- **Decision**: default the workflow input to
  `init_strategy = "single_trait_warmup"`.
  **Rationale**: M3.4 made this the intended production-grid mitigation
  path while leaving the package default unchanged.
  **Rejected alternative**: run the production grid with default
  initialization first.
  **Confidence**: medium-high.

## 4. Checks Run

- `gh pr list --state open --limit 20` -> no open PR rows before this
  branch.
- `git log --all --oneline --since="6 hours ago"` -> inspected recent
  merge order through PR #196.
- GitHub Actions documentation consulted:
  workflow syntax `workflow_dispatch` inputs, matrix `max-parallel`,
  and `actions/upload-artifact@v4` retention/artifact naming.
- `ruby -e 'require "yaml"; YAML.load_file(".github/workflows/m3-production-grid.yaml"); puts "yaml ok"'`
  -> `yaml ok`.
- `air format dev/m3-grid.R dev/precompute-m3-grid.R` -> completed.
- `Rscript --vanilla -e 'parse("dev/m3-grid.R"); parse("dev/precompute-m3-grid.R")'`
  -> both scripts parsed.
- `Rscript --vanilla dev/precompute-m3-grid.R --full --family=gaussian --d=1 --n-reps=1 --init-strategy=default --out-dir=/tmp/gllvmtmb-m3-test --out-prefix=test-gaussian-d1`
  -> passed; wrote prefixed grid and summary RDS files.
- `Rscript --vanilla dev/precompute-m3-grid.R --full --family=gaussian --d=1 --n-reps=1 --init-strategy=single_trait_warmup --out-dir=/tmp/gllvmtmb-m3-test-warmup --out-prefix=test-gaussian-d1-warmup`
  -> passed; wrote prefixed grid and summary RDS files.
- `Rscript --vanilla dev/precompute-m3-grid.R --full --family=gaussian --d=1 --n-reps=1 --init-strategy=single_trait_warmup --out-dir=/tmp/gllvmtmb-m3-test-final --out-prefix=test-gaussian-d1-final`
  -> passed after formatting.
- `bash -lc 'set +e; Rscript --vanilla dev/precompute-m3-grid.R --full --family=bogus --d=1 --n-reps=1 --out-dir=/tmp/gllvmtmb-m3-test-bad >/tmp/gllvmtmb-m3-bad.out 2>&1; status=$?; cat /tmp/gllvmtmb-m3-bad.out; echo status=$status; test $status -ne 0'`
  -> passed as an expected-failure check; status was 1 with
  `Unknown --family value(s): bogus`.
- `Rscript --vanilla -e 'devtools::test(filter = "m3-4-warmstart-phi-clamp")'`
  -> PASS 16, WARN 0, SKIP 0, FAIL 0.
- `git diff --check` -> clean.

## 5. Tests of the Tests

The driver checks include one positive default-initialization run, one
positive warm-start run matching the workflow default, and one malformed
`--family` run that must fail loudly. The package-side warmup regression
test still passes.

## 6. Consistency Audit

- `rg -n "M3\\.3 production|workflow_dispatch|m3-production-grid|init_strategy|placeholder Wald" .github/workflows/m3-production-grid.yaml dev docs/design/44-m3-3-inference-replacement.md docs/dev-log/after-task/2026-05-18-m3-3a-profile-primary.md ROADMAP.md`
  -> confirmed the workflow, dev scripts, design note, prior after-task,
  and roadmap now point at the same production-grid dispatch lane.
- `rg -n "M3\\.3 production grid workflow|codex/m3-production-grid-workflow-2026-05-19|WIP" docs/dev-log/coordination-board.md`
  -> confirmed the active lane and WIP count are visible.
- `rg -n "bootstrap.*default|Parametric bootstrap.*default|profile-primary|profile-CI grid" docs/design/44-m3-3-inference-replacement.md docs/dev-log/after-task/2026-05-18-m3-3a-profile-primary.md dev/m3-grid.R dev/precompute-m3-grid.R`
  -> found historical bootstrap wording in Design 44, but the new
  implementation-update note classifies it as historical rationale and
  points production dispatch to the profile-primary path.

## 7. Roadmap Tick

**Roadmap tick**: M3 progress stays `███░░░░░` 3/8. This PR wires
production dispatch but does not move any coverage cell to covered,
partial, or blocked. The top "Next small steps" queue was refreshed.

## 8. What Did Not Go Smoothly

An old local `codex/m3-production-grid-workflow` branch existed from
the interrupted run, but it was based on a stale `main` and would have
reverted recent docs. A fresh branch was started from current `main`,
and only the relevant workflow/script ideas were carried forward.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

- Ada: kept the branch to dispatch plumbing plus consistency notes.
- Curie: ensured the production grid can run one cell at a time with
  explicit cell filters.
- Fisher: kept coverage evidence claims unchanged until R = 200
  artifacts exist.
- Grace: used `workflow_dispatch`, matrix jobs, `fail-fast: false`,
  bounded `max-parallel`, and artifact retention.
- Rose: updated the board, Design 44, and roadmap queue so the next
  agent does not rediscover the same conflict.

## 10. Known Limitations And Next Actions

- The production grid has not been dispatched in this PR. It can only be
  triggered after the workflow file lands on the default branch.
- The follow-up lane should run the manual workflow with
  `n_reps = 200` and `init_strategy = "single_trait_warmup"`, download
  artifacts, aggregate coverage cells, update the validation-debt
  register, and decide whether any cell activates Design 49.
