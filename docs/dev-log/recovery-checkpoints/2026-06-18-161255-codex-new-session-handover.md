# Codex New-Session Handover: GLLVM Mission Control / Coevolution First

Timestamp: 2026-06-18 16:12:55 MDT

Source thread: closing current long-running Codex session at maintainer request.

## Active Goal

Finish the plan, but first finish the coevolution model and then stop.

Preserve the guard in every report/edit:

`PR green != bridge complete != release ready != scientific coverage passed`.

Do not redefine success around the current lane. The full objective remains the
GLLVM mission-control finish plan, but the immediate priority is the Paper 2 /
cross-lineage coevolution model evidence and gates before returning to the rest
of the plan.

## Hard Boundaries

- Do not push.
- Do not mutate GLLVM.jl #101.
- Never use `git add -A`.
- Run the pre-edit lane check before touching shared files:
  - `/opt/homebrew/bin/gh pr list --state open`
  - `git log --all --oneline --since="6 hours ago"`
- Keep repo/GitHub state authoritative; do not trust chat memory alone.
- `kernel_unique()` / `*_unique()` remains compatibility syntax for now, but
  it is not part of the Paper 2 multi-kernel path and should move to post-arc
  lifecycle/deprecation or replacement design.

## Files To Read First In New Session

1. `/Users/z3437171/Dropbox/Github Local/gllvmTMB/AGENTS.md`
2. This file:
   `/Users/z3437171/Dropbox/Github Local/gllvmTMB/docs/dev-log/recovery-checkpoints/2026-06-18-161255-codex-new-session-handover.md`
3. `git status --short --branch`
4. `git diff --stat`
5. `git diff --check`
6. Latest entries in
   `/Users/z3437171/Dropbox/Github Local/gllvmTMB/docs/dev-log/check-log.md`
7. Dashboard files under
   `/Users/z3437171/Dropbox/Github Local/gllvmTMB/docs/dev-log/dashboard/`
8. Coevolution design/evidence files:
   - `docs/design/65-cross-lineage-coevolution-kernel.md`
   - `docs/design/35-validation-debt-register.md`
   - `tests/testthat/test-coevolution-two-kernel.R`
   - `R/extract-sigma.R`
   - `R/kernel-helpers.R`

## Current Git State

Branch:

`codex/r-bridge-grouped-dispersion`

Status at handoff:

```text
## codex/r-bridge-grouped-dispersion...origin/codex/r-bridge-grouped-dispersion [ahead 56]
?? docs/dev-log/recovery-checkpoints/2026-06-17-050000-codex-handover-checkpoint.md
?? docs/dev-log/recovery-checkpoints/2026-06-17-151509-codex-stop-checkpoint.md
?? docs/dev-log/recovery-checkpoints/2026-06-17-160541-codex-progress-checkpoint.md
?? docs/dev-log/recovery-checkpoints/2026-06-17-180500-codex-restart-checkpoint.md
?? docs/dev-log/recovery-checkpoints/2026-06-17-181500-codex-new-session-handover.md
?? docs/dev-log/recovery-checkpoints/2026-06-17-191525-codex-monitor-checkpoint.md
?? docs/dev-log/recovery-checkpoints/2026-06-17-192858-codex-monitor-checkpoint.md
?? docs/dev-log/recovery-checkpoints/2026-06-17-195142-codex-monitor-checkpoint.md
?? docs/dev-log/recovery-checkpoints/2026-06-17-200837-codex-monitor-checkpoint.md
?? docs/dev-log/recovery-checkpoints/2026-06-17-205909-codex-monitor-checkpoint.md
?? docs/dev-log/recovery-checkpoints/2026-06-17-214510-codex-monitor-checkpoint.md
?? docs/dev-log/recovery-checkpoints/2026-06-17-221512-codex-monitor-checkpoint.md
?? docs/dev-log/recovery-checkpoints/2026-06-17-223101-codex-monitor-checkpoint.md
?? docs/dev-log/recovery-checkpoints/2026-06-17-225916-codex-monitor-checkpoint.md
?? docs/dev-log/recovery-checkpoints/2026-06-17-231819-codex-monitor-checkpoint.md
?? docs/dev-log/recovery-checkpoints/2026-06-18-001043-codex-monitor-checkpoint.md
?? docs/dev-log/recovery-checkpoints/2026-06-18-020230-codex-monitor-checkpoint.md
?? docs/dev-log/recovery-checkpoints/2026-06-18-023910-codex-monitor-checkpoint.md
?? docs/dev-log/recovery-checkpoints/2026-06-18-034323-codex-monitor-checkpoint.md
?? docs/dev-log/recovery-checkpoints/2026-06-18-040200-codex-monitor-checkpoint.md
?? docs/dev-log/recovery-checkpoints/2026-06-18-051512-codex-monitor-checkpoint.md
?? docs/dev-log/recovery-checkpoints/2026-06-18-052348-codex-new-session-handover.md
```

The checkpoint file itself was created after this status snapshot and is also
expected to appear as untracked until the maintainer decides what to do with
recovery notes.

Tracked diff at handoff:

```text
git diff --stat
# no tracked diff

git diff --check
# clean
```

Recent commits:

```text
5346391 test(coevolution): add poisson recovery gate
2475537 test(coevolution): add moderate edge boundary gate
c541af4 feat(coevolution): add fixed-rho profile helper
6793af4 feat(coevolution): add pair-specific covariance extractor
900227a test(coevolution): add poisson two-kernel smoke
```

## Pre-Handoff Coordination Check

Open PRs:

```text
489 Draft: route scoped Julia bridge admission rows
branch: codex/r-bridge-grouped-dispersion
```

Recent all-branch commits in the last six hours were the current mission-control
/ coevolution commits on this branch, newest:

```text
5346391 test(coevolution): add poisson recovery gate
2475537 test(coevolution): add moderate edge boundary gate
c541af4 feat(coevolution): add fixed-rho profile helper
6793af4 feat(coevolution): add pair-specific covariance extractor
900227a test(coevolution): add poisson two-kernel smoke
e085140 test(coevolution): expand null diagnostic grid
851faa1 test(coevolution): add high-overlap near-duplicate gate
4d733bf test(coevolution): expand moderate overlap grid
92de3f4 test(coevolution): add fixed rho sensitivity gate
735ce18 docs(dashboard): map laplace va capability gaps
a67c905 feat(coevolution): expose fixed rho Gamma effect
ab5d7d0 test(coevolution): add null signal grid gate
1c671fe test(coevolution): add high-overlap collapse gate
e5d025c feat(coevolution): warn on high-overlap Gamma extraction
9b04fea test(coevolution): add moderate overlap gate
1ddcf5d feat(coevolution): warn on high kernel overlap
52eb884 test(coevolution): add null smoke gate
c5c5792 test(coevolution): add selective absence gate
4d71dab feat(coevolution): expose kernel overlap diagnostics
bf67174 test(coevolution): add near-orthogonal recovery gate
89b4edc feat(kernel): add latent-only named multikernel tiers
```

## Current Coevolution Evidence

The Paper 2 / cross-lineage path is now a real fixed multi-kernel engine, but
not a complete scientific claim.

Current covered/partial shape:

- `KER-03`: covered for fixed dense named multi-kernel `kernel_latent()`
  tiers over the same grouping levels.
- `COE-03`: partial. Fixed latent-only two-component named-kernel fits work
  and extract component `Sigma`, `Gamma_shape`, fixed-`rho` `Gamma_effect`,
  and pair-specific point covariance.
- `COE-04`: partial. Evidence now includes:
  - near-orthogonal Gaussian latent-only recovery;
  - two-cell moderate-overlap recovery;
  - one tested 0.40 moderate-edge boundary cell;
  - high-overlap exact-duplicate and diagonal-shrink near-duplicate
    collapse-equivalence;
  - fitted-object kernel-similarity diagnostics;
  - high-overlap fit and `extract_Gamma()` warnings;
  - two-sided selective absence;
  - block-null smoke;
  - 12-seed null diagnostic plus medium-signal grid;
  - bounded Poisson construction fixtures;
  - two-cell known-DGP Poisson recovery gate;
  - fixed-`rho` profile/sensitivity via `profile_cross_rho()`;
  - fixed-`rho` `Gamma_effect` extraction;
  - pair-specific point covariance via `predict_cross_covariance()`.

Latest committed coevolution slice:

`5346391 test(coevolution): add poisson recovery gate`

What it added:

- `.c3_make_poisson_two_kernel_recovery_fixture()`
- `.c3_fit_poisson_two_kernel_set()`
- Heavy test:
  `"Poisson two-kernel coevolution recovers component Gamma shapes"`
- Deterministic seeds `2801` and `2804`.
- Full two-kernel Poisson model beats the best one-component comparator by
  more than 40 log-likelihood units.
- Both planted component `Gamma_shape` blocks recover above 0.98 correlation.
- Cross-component matches stay below 0.10.

Tests recorded for this slice:

```text
Rscript --vanilla -e 'devtools::test(filter = "coevolution-two-kernel")'
-> FAIL 0 | WARN 0 | SKIP 10 | PASS 67

GLLVMTMB_HEAVY_TESTS=1 Rscript --vanilla -e 'devtools::test(filter = "coevolution-two-kernel")'
-> FAIL 0 | WARN 0 | SKIP 0 | PASS 259

Rscript --vanilla -e 'devtools::test(filter = "kernel|coevolution")'
-> FAIL 0 | WARN 0 | SKIP 13 | PASS 171

GLLVMTMB_HEAVY_TESTS=1 Rscript --vanilla -e 'devtools::test(filter = "kernel|coevolution")'
-> FAIL 0 | WARN 0 | SKIP 0 | PASS 388
```

Dashboard JSON was validated and synced to the local widget server:

```text
python3 -m json.tool docs/dev-log/dashboard/status.json >/dev/null
python3 -m json.tool docs/dev-log/dashboard/sweep.json >/dev/null
rsync -a docs/dev-log/dashboard/ /tmp/gllvm-dashboard/
```

Widget URL:

`http://127.0.0.1:8770/`

## Current Coevolution Gaps

Do not claim the coevolution model is complete until these gates are either
implemented or deliberately scoped out with maintainer approval:

- No public Paper 2 promotion yet.
- No broad moderate-overlap calibration beyond the two promoted cells plus one
  boundary cell.
- No broader high-overlap truth-recovery/failure calibration beyond current
  collapse-equivalence and warning gates.
- No formal null-threshold / Type-I calibration beyond the diagnostic grid.
- No in-engine `rho` estimation.
- No `rho` profile intervals or interval coverage.
- No broader non-Gaussian/mixed-family recovery beyond the narrow Poisson cell
  pair.
- No explicit Paper 2 multi-kernel Psi support; current direction is to avoid
  expanding `kernel_unique()` here and instead plan `*_unique()` lifecycle /
  deprecation or replacement after the arc.
- No bridge completion, release readiness, or scientific coverage completion.

## Recommended Next Action

Start with a fresh audit, then choose the next coevolution gate. Do not start
article estate cleanup, bridge closure, or release work until the maintainer is
satisfied that the coevolution-first stop point is reached.

Best next technical gate:

1. Re-audit `docs/design/65-cross-lineage-coevolution-kernel.md`,
   `docs/design/35-validation-debt-register.md`, and
   `tests/testthat/test-coevolution-two-kernel.R`.
2. Pick one remaining COE-04 gate and implement it narrowly.
3. The most plausible next gates are:
   - formal null-threshold / Type-I calibration scaffold beyond the current
     12-seed diagnostic;
   - broader moderate-overlap calibration grid;
   - high-overlap failure/recovery calibration beyond collapse-equivalence;
   - `rho` profile interval design/evidence;
   - broader non-Gaussian gate after the narrow Poisson recovery pair.
4. Before editing shared evidence files, rerun:
   - `/opt/homebrew/bin/gh pr list --state open`
   - `git log --all --oneline --since="6 hours ago"`
5. For any simulation/test work, use the project-local `add-simulation-test`
   skill and keep the symbolic-math-to-implementation alignment table.
6. Update `docs/dev-log/check-log.md`, the dashboard JSON, and an after-task
   report for any meaningful slice.
7. Validate JSON, run `git diff --check`, sync `/tmp/gllvm-dashboard/`, stage
   by explicit file names only, and commit by name only.

## Suggested New-Session Prompt

You are taking over the GLLVM mission-control / coevolution-first lane.

Read, in this order:

1. `/Users/z3437171/Dropbox/Github Local/gllvmTMB/AGENTS.md`
2. `/Users/z3437171/Dropbox/Github Local/gllvmTMB/docs/dev-log/recovery-checkpoints/2026-06-18-161255-codex-new-session-handover.md`
3. `git status --short --branch`, `git diff --stat`, `git diff --check`
4. latest entries in `docs/dev-log/check-log.md`
5. dashboard files under `docs/dev-log/dashboard/`
6. `docs/design/65-cross-lineage-coevolution-kernel.md`
7. `docs/design/35-validation-debt-register.md`
8. `tests/testthat/test-coevolution-two-kernel.R`

Active goal: finish the plan, but first finish the coevolution model and then
stop. Preserve the guard:

`PR green != bridge complete != release ready != scientific coverage passed`.

Hard boundaries: do not push; do not mutate GLLVM.jl #101; never use
`git add -A`; run the pre-edit lane check before touching shared files.

Current state: latest committed slice is
`5346391 test(coevolution): add poisson recovery gate`; branch is ahead 56;
tracked diff is clean; only old recovery checkpoint files are untracked.

Start by auditing the remaining COE-04 gaps and propose or implement the next
narrow coevolution gate. Keep `kernel_unique()` / `*_unique()` as compatibility
syntax only for now; do not expand it for Paper 2 multi-kernel coevolution.
