# Session Handoff: Claude resumes the gllvmTMB 0.6 M1 arc-loop

**Meta:** 2026-07-21 · from Codex to Claude Code · usage-limit handoff

You are Claude Code, picking up the one active `gllvmTMB` 0.6 lane from
Codex. Work in the existing isolated builder. Codex has stopped and must not
edit this repository concurrently.

## Critical Context

1. M1 is not closed. The repaired public-boundary surface is focused-green,
   but the current source still needs the complete non-heavy and touched-heavy
   tests, four article renders, pkgdown, source-tarball check, exact-SHA
   platform evidence, and three fresh D-43 reviews.
2. The maintainer intends to attempt EVA for 0.6, but that is not scientific
   admission. Design 85 remains a landed NO-GO; Design 72's sequential gates
   remain binding. M2 may begin only after M1 closes and only by drafting a new
   Design 86 for separate approval. No EVA implementation or scientific
   compute is authorised by this handoff.

## Goals / Mission

Run one continuously owned L2 arc-loop through the approved five serial
macro-arcs: M1 release truth and heavy baseline; M2 Design 86 EVA scientific
admission; M3 public-feature admission; M4 reader-ready candidate; M5
immutable platform/CRAN ceremony. For this resumed session, finish only the
remaining reversible M1 qualification work and stop at the M1-to-M2 human
gate. Laplace-only 0.6 is the automatic fallback if EVA fails any later gate.

The immutable mission and invariants are in `LOOP/GOAL.md`. Re-read it at the
start of every arc.

## Plans / Roadmap

The binding plan is `LOOP/ultra-plan.md`; statuses are in `LOOP/arcs.md` and
the current resume pointer is `LOOP/checkpoint.md`.

- **M1 — IN PROGRESS:** qualify the repaired exact head locally and on the
  package-check platforms, then obtain fresh NOT-DONE-default reviews.
- **M2 — PENDING and gated:** Design 86 contract, deterministic proof, Totoro
  smoke/reference, then DRAC pilot/confirmation only through separate gates.
- **M3 — PENDING:** public EVA only after scientific GO and package refusal/
  regression gates; otherwise take the Laplace-only route.
- **M4 — PENDING:** reconcile every public surface and freeze one reader-ready
  source/tarball identity.
- **M5 — PENDING:** separate RC, final-tag, and CRAN-submission authorities.

Current estimate from this handoff: M1 requires about 8–16 active hours plus
CI wait, normally 1–3 working days if no new load-bearing defect appears.

## What Was Accomplished

- Established exclusive single-lane ownership in the clean builder and kept
  the dirty primary plus parked worktrees quarantined.
- Repaired public profile-withdrawal precedence before Julia, fit, tier, link,
  or other validation.
- Fenced `extract_cross_correlations()` to ordinary unit/B covariance and
  added typed ordinal-probit `link_residual = "auto"` refusal.
- Made repeatability Wald-by-default, reconciled its full-covariance estimand,
  and added typed malformed-bootstrap validation.
- Reconciled binomial/multinomial auto-Psi messages and their once IDs.
- Corrected FAM-20/FAM-20A/FAM-20B prose, especially fitted phylogenetic
  covariance versus total covariance plus fixed softmax residual.
- Reworked the cross-family article to show both the intentional ordinal-auto
  refusal and a supported non-ordinal summary.
- Regenerated the two affected Rd topics.
- Passed the focused gate: 117 passes, zero failures, zero warnings, and 11
  declared heavy skips in 470.6 seconds.
- Ran the generated `extract_cross_correlations` example successfully.
- Passed the after-task structure validator, `git diff --check`, and the
  GitHub Actions package-check/docs-only boundary guard before handoff.
- Created and pushed the durable `LOOP/` arc-loop kit and bounded after-task
  receipt in repair commit `580e9801842b8edc88e93572f6fcef10ce5cd7b3`.
- Persisted the complete 141-branch mapping behind the global gate's 252
  unique stranded commits as an immutable, checksummed P0 inventory receipt.
- Updated the canonical live Mission Control board for Claude ownership and
  the M1 complete-non-heavy next action; local-only vault commit `bee1f33`.

Full detail: `docs/dev-log/after-task/2026-07-21-m1-public-boundary-repair.md`.

## Current Working State

- **Working:** focused public-boundary tests and generated example; the
  repair commit is pushed on draft PR #778.
- **In progress:** M1 complete-local and exact-head qualification. The
  automatic Ubuntu run `29828714275` passed for repair SHA `580e9801`, but
  the later handover-doc commit makes that run predecessor evidence. Qualify
  only the final unchanged branch head.
- **Not working / blocked:** nothing in the reversible M1 ladder is blocked.
  Entry to M2, Design 86 approval, Totoro/DRAC scientific compute, public EVA,
  merge, source/API or candidate freeze, tags, submission, and public
  readiness/release claims remain human-gated.

The active workspace is:

```text
/private/tmp/gllvmtmb-060-m1-builder
branch: codex/gllvmtmb-060-m1-baseline-20260720
PR: https://github.com/itchyshin/gllvmTMB/pull/778
```

## Key Decisions & Rationale

- **Focused PASS is not M1 PASS.** Predecessor platform receipts are retained
  but cannot qualify changed source.
- **Profile withdrawal wins validation precedence.** A withdrawn method may
  not leak a different error or silently become Wald.
- **Ordinal-probit auto fails.** Its residual variance is already fixed at
  one; adding another unit residual would attenuate correlations.
- **Fitted covariance is not default total covariance.** Use
  `part = "shared", link_residual = "none"` for the fitted phylogenetic
  multinomial covariance; default total adds the fixed softmax residual.
- **Design 85 stays NO-GO.** Do not relabel its mixed fixed-rank/ML-rank pilot,
  tune gates, run q4/q6, or salvage selected successes.
- **Design 86 is a new decision.** It starts narrow at complete balanced
  multi-trial binomial-logit, ordinary loadings-only latent structure, fixed
  q=1, and no public inference. The approved plan does not itself approve the
  contract or compute.
- **One writer.** Claude now owns the repo lane; Codex is inactive until a
  later landed handoff.
- **One mutation stream.** Bounded subagents may inspect, test, or review in
  parallel, but Claude owns integration and serialises repository edits,
  commits, pushes, and all outward actions. No subagent opens an independent
  writing lane.

## Landing State

| Artifact / branch | Committed | Pushed | PR | State |
|---|---:|---:|---|---|
| `gllvmTMB` repair commit `580e9801` on `codex/gllvmtmb-060-m1-baseline-20260720` | yes | yes | #778 draft/open | LANDED on branch; not merged |
| This handover + `CLAUDE.md` snapshot | yes, in the branch commit containing this file | yes when fetched from the named remote branch | #778 draft/open | LANDED on branch; not merged |
| P0 parked-branch inventory receipt | yes, in the branch commit containing this file | yes when fetched from the named remote branch | #778 draft/open | LANDED receipt; no parked branch admitted |
| Mission Control `live/status/gllvmTMB.json`, vault commit `bee1f33` | yes | local-only vault by D-37 | n/a | LANDED locally |
| Other parked branches/worktrees reported by the repository-wide gate | mixed legacy state | 252 commits reported unpushed across other branches | unrelated | CARRIED-OVER as the pre-existing P0 estate; not session artefacts; quarantined, not owned |

`/Users/z3437171/Dropbox/Github Local/Shinichi/tools/handoff_gate.sh` found
the active branch clean and pushed after the repair commit, but returned
nonzero because it inventories 252 historical unpushed commits on other
parked branches. This is the known P0 worktree estate, not undeclared work in
the active lane. It is explicitly carried over because changing or deleting
foreign parked state is outside this programme's authority. Its governing
branch-by-branch inventory is
`docs/dev-log/audits/2026-07-21-p0-parked-branch-inventory.md`, receipt
SHA-256 `1e30fed66f14df30f7c23211eb6242fff914b3b48ef0dd003aa9553161eada2d`;
the canonical sorted 141-row mapping within it has SHA-256
`cc0ebe1982dbeca00bd0024cb4fab73cc8c1ad8c83503f170c4abe97eb750f97`.
The earlier ownership context remains in
`docs/dev-log/after-task/2026-07-20-m1-heavy-baseline.md` and
`docs/dev-log/recovery-checkpoints/2026-07-21-021419-codex-m1-platform-closeout-checkpoint.md`.
There is deliberately no resume command for those foreign branches: Claude
must not attach, switch, clean, push, delete, or otherwise resume them.

To reattach the carried-over active programme state:

```sh
cd '/private/tmp/gllvmtmb-060-m1-builder'
git fetch origin
git checkout codex/gllvmtmb-060-m1-baseline-20260720
git pull --ff-only
```

## Files Created / Modified

Every path changed between predecessor `c6e1dd8` and the repair/handoff state:

- `CLAUDE.md`
- `LOOP/GOAL.md`
- `LOOP/arcs.md`
- `LOOP/checkpoint.md`
- `LOOP/decision-queue.md`
- `LOOP/ultra-plan.md`
- `NEWS.md`
- `R/extract-correlations.R`
- `R/extract-repeatability.R`
- `R/extract-sigma.R`
- `R/fit-multi.R`
- `docs/design/02-family-registry.md`
- `docs/design/06-extractors-contract.md`
- `docs/design/35-validation-debt-register.md`
- `docs/design/83-multinomial-response-family.md`
- `docs/design/84-phylogenetic-multinomial-tier2.md`
- `docs/dev-log/audits/2026-07-21-p0-parked-branch-inventory.md`
- `docs/dev-log/after-task/2026-07-21-m1-public-boundary-repair.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/handover/2026-07-21-claude-handover.md`
- `docs/dev-log/recovery-checkpoints/2026-07-21-044609-codex-m1-profile-boundary-repair-checkpoint.md`
- `man/extract_cross_correlations.Rd`
- `man/extract_repeatability.Rd`
- `tests/testthat/test-cross-family-intervals.R`
- `tests/testthat/test-cross-family-multinomial.R`
- `tests/testthat/test-link-residual-multinomial.R`
- `tests/testthat/test-profile-ci.R`
- `vignettes/articles/behavioural-syndromes.Rmd`
- `vignettes/articles/cross-family-correlations.Rmd`
- `vignettes/articles/multinomial.Rmd`
- `vignettes/articles/profile-likelihood-ci.Rmd`

Do not infer that this short session list is the complete PR #778 estate. The
predecessor M1 work and its complete inventory live in
`docs/dev-log/after-task/2026-07-20-m1-heavy-baseline.md` and the PR diff.

External durable state changed outside the package repository:

- `/Users/z3437171/Dropbox/Github Local/Shinichi/Shinichi/Dashboards/mission-control/live/status/gllvmTMB.json`
  in local-only Shinichi-vault commit `bee1f33`.

## Next Immediate Steps

Run the L2 loop from `LOOP/checkpoint.md`. At the top of every arc, re-read
`LOOP/GOAL.md`; keep the conductor lean and delegate bounded reviews/tests.

1. Prove exclusive ownership and exact checkout before editing:

   ```sh
   git status --short --branch
   git rev-parse HEAD
   git rev-parse origin/codex/gllvmtmb-060-m1-baseline-20260720
   gh pr list --state open
   ```

   Require a clean tree, identical local/remote SHA, and only draft PR #778.

2. Prove the loaded namespace is this checkout, then run complete non-heavy
   tests with one R/BLAS thread:

   ```sh
   NOT_CRAN=true GLLVMTMB_HEAVY_TESTS= \
   OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 MKL_NUM_THREADS=1 \
   Rscript --vanilla -e 'devtools::load_all(quiet = TRUE); stopifnot(normalizePath(pkgload::pkg_path()) == normalizePath(getwd())); devtools::test(stop_on_failure = TRUE)'
   ```

   Read the full log and classify every warning/skip; do not rely on exit code.

3. If green, run the touched heavy routes:

   ```sh
   NOT_CRAN=true GLLVMTMB_HEAVY_TESTS=1 \
   OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 MKL_NUM_THREADS=1 \
   Rscript --vanilla -e 'devtools::test(filter = "cross-family-intervals|cross-family-multinomial|link-residual-multinomial|profile-ci", stop_on_failure = TRUE)'
   ```

4. Execute all four changed articles and inspect the rendered pages:

   ```sh
   Rscript --vanilla -e 'pkgload::load_all(quiet = TRUE); for (a in c("articles/behavioural-syndromes", "articles/cross-family-correlations", "articles/multinomial", "articles/profile-likelihood-ci")) pkgdown::build_article(a, pkg = ".", lazy = FALSE, new_process = FALSE, quiet = FALSE)'
   Rscript --vanilla -e 'pkgdown::check_pkgdown()'
   bash tools/check-actions-boundary.sh
   ```

5. Run an independent precommit code/API/claim review. Repair only a proved
   load-bearing defect; any repair receives focused regression coverage and a
   checkpoint update.

6. Before the final source freeze, record all local evidence in the bounded
   after-task/check-log, update `LOOP/arcs.md`, and overwrite
   `LOOP/checkpoint.md`. The checkpoint must name the candidate SHA and declare
   PR #778 plus Mission Control as the post-freeze external checkpoint for CI
   and D-43 state. Validate the report, run `git diff --check`, commit the
   explicit paths, and require a clean tree. This is the last package-repo edit
   before platform qualification unless a gate fails.

7. Run the two reviewed durable exact-head runners from the clean final commit.
   First verify their immutable hashes:

   ```sh
   shasum -a 256 \
     /Users/z3437171/gllvmTMB-0.6-evidence/m1/final-receipt/runners/m1-final-receipt-head-check-runner.R \
     /Users/z3437171/gllvmTMB-0.6-evidence/m1/final-receipt/runners/m1-final-receipt-head-pkgdown-runner.R
   ```

   Expected hashes, in order:

   ```text
   fdee381f0cf7afa9b6cebe1ae0acc8b6ff4d0fbc987456c6e21f8b7a8030720c
   6bc5c7f20a9767f59d69fb11552838c522dcb195fb110b6ca02f722d17b6bb1c
   ```

   Then run:

   ```sh
   GLLVMTMB_HEAVY_TESTS= NOT_CRAN=true \
   OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 MKL_NUM_THREADS=1 \
   Rscript --vanilla \
     /Users/z3437171/gllvmTMB-0.6-evidence/m1/final-receipt/runners/m1-final-receipt-head-check-runner.R

   GLLVMTMB_HEAVY_TESTS= NOT_CRAN=true \
   OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 MKL_NUM_THREADS=1 \
   Rscript --vanilla \
     /Users/z3437171/gllvmTMB-0.6-evidence/m1/final-receipt/runners/m1-final-receipt-head-pkgdown-runner.R
   ```

   Both runners enforce the builder path, branch, and clean worktree; bind the
   receipt to the current source SHA; refuse overwrite; and print the exact RDS
   path. Read the full output, open each emitted RDS, require zero package-check
   errors/warnings/notes and no runner error/warning, and checksum the runner,
   RDS, and captured log into the durable non-Git evidence directory. If the
   existing runner assumptions no longer match the final state, stop and mint a
   reviewed copy with a new hash; never edit these retained runner files in
   place.

8. Push only after both exact-head local runners pass. Capture the frozen SHA
   and a pre-push timestamp, require the automatic Ubuntu run to match that SHA
   and take the full package-check path, then dispatch the two exact-branch
   workflows. The following recipe cannot accidentally select a historical
   run:

   ```sh
   final_m1_sha="$(git rev-parse HEAD)"
   push_marker_utc="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

   git push origin codex/gllvmtmb-060-m1-baseline-20260720
   test "$(git rev-parse origin/codex/gllvmtmb-060-m1-baseline-20260720)" = "$final_m1_sha"

   automatic_run_id="$(gh run list --repo itchyshin/gllvmTMB \
     --workflow R-CMD-check.yaml \
     --branch codex/gllvmtmb-060-m1-baseline-20260720 \
     --event pull_request --limit 20 \
     --json databaseId,headSha,createdAt \
     | jq -r --arg sha "$final_m1_sha" --arg marker "$push_marker_utc" \
       '[.[] | select(.headSha == $sha and .createdAt >= $marker)] | first | .databaseId // empty')"

   dispatch_marker_utc="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

   gh workflow run R-CMD-check.yaml --repo itchyshin/gllvmTMB \
     --ref codex/gllvmtmb-060-m1-baseline-20260720 \
     -f full_matrix=true

   gh workflow run full-check.yaml --repo itchyshin/gllvmTMB \
     --ref codex/gllvmtmb-060-m1-baseline-20260720

   matrix_run_id="$(gh run list --repo itchyshin/gllvmTMB \
     --workflow R-CMD-check.yaml \
     --branch codex/gllvmtmb-060-m1-baseline-20260720 \
     --event workflow_dispatch --limit 20 \
     --json databaseId,headSha,createdAt \
     | jq -r --arg sha "$final_m1_sha" --arg marker "$dispatch_marker_utc" \
       '[.[] | select(.headSha == $sha and .createdAt >= $marker)] | first | .databaseId // empty')"

   heavy_run_id="$(gh run list --repo itchyshin/gllvmTMB \
     --workflow full-check.yaml \
     --branch codex/gllvmtmb-060-m1-baseline-20260720 \
     --event workflow_dispatch --limit 20 \
     --json databaseId,headSha,createdAt \
     | jq -r --arg sha "$final_m1_sha" --arg marker "$dispatch_marker_utc" \
       '[.[] | select(.headSha == $sha and .createdAt >= $marker)] | first | .databaseId // empty')"

   test -n "$automatic_run_id"
   test -n "$matrix_run_id"
   test -n "$heavy_run_id"
   ```

   GitHub may take a few seconds to register a dispatch. If an ID is initially
   empty, poll the same SHA-and-timestamp-filtered command; never fall back to
   unfiltered `latest`. For each captured ID, retain and inspect:

   ```sh
   for exact_run_id in "$automatic_run_id" "$matrix_run_id" "$heavy_run_id"; do
     gh run view "$exact_run_id" --repo itchyshin/gllvmTMB \
       --json databaseId,headSha,status,conclusion,url,jobs
     gh run view "$exact_run_id" --repo itchyshin/gllvmTMB --log
   done
   ```

   Require automatic Ubuntu, manual Ubuntu/macOS/Windows, and Ubuntu-heavy to
   be terminal-green at one identical final SHA. Read the logs and denominators;
   a workflow conclusion alone is insufficient. GitHub Actions remains
   package-check/docs infrastructure only, not a scientific campaign.

9. After every exact-head receipt is terminal, follow the external-checkpoint
   declaration already committed in `LOOP/checkpoint.md`: make no further
   package-repo edit. Record external run URLs/results in PR #778 and Mission
   Control, then
   obtain three fresh independent NOT-DONE-default reviews: Rose for claims and
   receipts, Fisher/Noether for inference/API boundaries, and Pat for public
   user paths. Two NOT-DONE verdicts withhold M1; any load-bearing defect sends
   the loop back to the responsible earlier arc and creates a new exact head.

10. If and only if M1 meets every exit gate, record the terminal synthesis in
    PR #778 and Mission Control without changing the qualified package SHA,
    then stop and ask Shinichi whether to enter M2. Do not draft/implement
    Design 86 or connect to Totoro/DRAC first.

## Blockers / Open Questions

- No blocker for reversible M1 qualification.
- **Open human gate:** admit M2 after a terminal M1 synthesis.
- Later separate gates: Design 86 mathematical contract; Totoro smoke/DRAC
  pilot; 100-seed confirmation and every family wave; scientific GO; public
  EVA admission; source/API freeze; candidate freeze; RC/final tags; CRAN
  submission; and any public readiness/release claim.
- The 252 unpushed commits on other parked branches are not a cleanup request.
  Do not touch them without separate ownership and destructive-action review.

## Gotchas & Failed Approaches

- Do not reuse the green `c6e1dd8`, `9ee0ecd7`, or `580e9801` platform runs
  for a later source SHA. They are historical once the branch changes.
- Do not let invalid link/tier/fit inputs outrank the typed profile-withdrawal
  error. The focused tests intentionally combine invalid arguments.
- Do not silently substitute Wald for a withdrawn nonlinear profile route.
- Do not pass ordinal-probit through `link_residual = "auto"`; the deliberate
  typed refusal is part of the current contract.
- Do not describe `extract_Sigma(fit, level = "phy")` as fitted phylogenetic
  multinomial covariance. Its defaults return total covariance with the fixed
  softmax residual; use explicit `shared` + `none` for fitted covariance.
- Do not call a negative search proof. Read actual logs, inspect rendered
  artifacts, and prove the namespace/worktree identity.
- Do not reopen Design 85, run q4/q6, tune its gates, or hide failures.
- Do not launch scientific simulation on GitHub Actions. Totoro/DRAC remain
  separately gated M2 infrastructure.

## Mission Control

| Repository | Owner / branch | CI and evidence | What shipped | Plan by leverage |
|---|---|---|---|---|
| `gllvmTMB` | Claude sole writer; `codex/gllvmtmb-060-m1-baseline-20260720`; draft #778 | Focused 117/0/0 with 11 declared heavy skips; full local/platform qualification pending | M1 public-boundary repair + durable L2 loop kit, not merged | full non-heavy → touched heavy → four renders/pkgdown → source check → exact-SHA CI → fresh D-43 → stop at M2 gate |

The canonical live board is
`/Users/z3437171/Dropbox/Github Local/Shinichi/Shinichi/Dashboards/mission-control/live/status/gllvmTMB.json`.
Update it as material state changes; never treat this table as a release claim.

## How to Resume

Run this from the authenticated terminal in the existing builder:

```sh
cd '/private/tmp/gllvmtmb-060-m1-builder' && claude "You are the sole gllvmTMB 0.6 lane. Rehydrate from docs/dev-log/handover/2026-07-21-claude-handover.md plus CLAUDE.md and AGENTS.md. Read and follow /Users/z3437171/Dropbox/Github Local/Shinichi/skills/arc-loop/SKILL.md. Then read LOOP/GOAL.md, LOOP/checkpoint.md, and LOOP/ultra-plan.md, resume the L2 arc-loop at M1 complete non-heavy qualification, update Mission Control as material state changes, and stop at every recorded gate. Do not enter M2, launch Totoro/DRAC scientific compute, merge, tag, submit, or make a release/readiness claim without explicit authority."
```

Inside Claude, the first-read order is:

```text
AGENTS.md
CLAUDE.md live snapshot
docs/dev-log/handover/2026-07-21-claude-handover.md
/Users/z3437171/Dropbox/Github Local/Shinichi/skills/arc-loop/SKILL.md
LOOP/GOAL.md
LOOP/checkpoint.md
LOOP/ultra-plan.md
docs/dev-log/after-task/2026-07-21-m1-public-boundary-repair.md
```

The global `arc-loop` skill is Claude Code-only. It already exists; no skill
installation or repository copy is needed. If slash-command discovery does
not list it, reading and following the absolute `SKILL.md` path above is the
authoritative fallback.
