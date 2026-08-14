# Session Handoff: gllvmTMB 0.6 hardening complete → 0.7 integration intake

Meta: 2026-08-12 MDT · from Codex → a fresh Codex session · live R/TMB package
worktree.

## Critical Context

You are Codex, picking this up cold. The bounded 0.6 hardening/evidence phase
is complete. Do **not** use the experimental LA-MSPL B2 campaign as release
evidence or restart/aggregate it from this lane. The next task is a short,
read-first **0.7 integration intake**: decide what genuinely belongs before
0.7, what remains fenced/deferred, and what stays experimental.

Do not merge, bump `DESCRIPTION`, publish, create a release, or submit to
CRAN. Shinichi alone authorises an eventual upload.

This is a multi-lane repository. Read the lane map before any mutation and do
not overwrite the protected Profile, VA, or experimental worktrees.

## Goals and plan

The package mission remains the stacked-trait, long-format GLLVM surface and
its 5 × 3 covariance grid, with public claims bounded by evidence.

The completed phase reconciled accepted 0.6 work, public limitation fences,
high-priority issue handling, and exact artifact/platform evidence. The next
high-leverage plan is:

1. Inspect the two candidate pre-0.7 lanes, all live open issues, and current
   `origin/main`.
2. Classify every candidate as **integrate before 0.7**,
   **fence/defer**, or **experimental-only**.
3. Audit mergeability, implementation scope, validation evidence,
   documentation impact, and release risk for the genuinely eligible work.
4. Write one ranked implementation plan and stop for Shinichi before starting
   its first implementation slice or any substantial compute campaign.

This is an intake and decision lane, not a version-bump lane.

## What was accomplished

- PR #951 is merged at `origin/main` `cb3126893883ff9fb0c6114129c158fe0e649be8`.
  It supplied bounded ordinary-Laplace validation, the Current limitations
  reader path, high-priority issue fixes/fences, and three-OS package evidence.
- The public Current limitations page is deployed and returned HTTP 200 on
  2026-08-12:
  <https://itchyshin.github.io/gllvmTMB/articles/current-limits.html>.
- A fresh, normal-vignette 0.6 source artifact was built from merged main and
  checked end-to-end. It has SHA-256
  `9706809b9e2f52b130c21843a0396cafcfea602db74bb676eaa232f667f2e05a`,
  702 tar members, and `R CMD check --as-cran --run-donttest` passed installed
  documentation, vignettes, examples, and all tests. Its only result was the
  expected CRAN `New submission` NOTE.
- The package-bearing paths (`DESCRIPTION`, `NAMESPACE`, `R`, `src`, `inst`,
  `man`, `vignettes`, `tests`, `.Rbuildignore`) are byte-identical between
  the three-OS matrix source `ae340bdd` and merged `cb312689`; run
  `31321069365` succeeded on macOS, Ubuntu, and Windows. Therefore the
  matrix applies to this exact installed package surface.
- The current issue ledger gives all 49 live issues a disposition. Deliberate
  fences #945, #944, #935, #904, and #897 remain open; #345 remains the
  owner-gated release tracker. They are limits, not hidden release blockers.
- The Totoro B2 recovery handover was committed separately in the experimental
  MSPL lane as `2816a1ad`; it reports only partial artefacts. Rorqual array
  `18893251` must be authenticated by its owning lane before it can count as
  scientific evidence.

## Current working state

- **Working:** `origin/main` is at `cb312689`; the 0.6 package is hardened
  and evidence-bounded. This branch is a documentation-only continuation.
- **In progress:** no local build, test, simulation, or CI run from this lane.
  The next Codex session owns the integration-intake analysis only.
- **Protected / external:** LA-MSPL B2 is separate. At the last durable
  snapshot (12 Aug, 04:50 MDT), Totoro v3 had 445 authenticated raw/receipt
  pairs, 4,902 timeout blocks, and 380 workers; it must not be assembled or
  adjudicated. Rorqual `18893251` was a separate 60-minute array and likewise
  needs authentication. Do not alter either run.

## Key decisions and rationale

1. **0.6 is hardened, not released.** The exact check and inherited three-OS
   evidence are an engineering/evidence rung only; no 0.7 identity, tag, or
   CRAN authority follows from them.
2. **Reader-facing limitations stay prominent.** Current limits is the
   canonical practical boundary. A converged fit is not a broad inference
   claim.
3. **Experimental estimators stay fenced.** Laplace remains default. VA,
   AGHQ, EVA, broad intervals, ordinal calibration, and advanced structured
   routes are not promoted by this receipt.
4. **LA-MSPL is not a release gate.** It is experimental numerical work;
   partial artifacts must not influence the 0.7 decision.
5. **The next step is selection, not accumulation.** Do not absorb every open
   issue or use the 0.7 target to turn research ideas into release scope.

## Landing state

`handoff_gate.sh` reports unpushed branches across the shared git directory.
They are declared here rather than silently absorbed.

| Artifact / branch | Committed | Pushed | PR | State |
| --- | --- | --- | --- | --- |
| This worktree, `codex/mainline-06-issue-closeout`, `251e9b9b` + this handover commit | yes | pending | open after this handover push | **CARRIED-OVER** until the human merges; docs-only, no package bytes |
| `origin/main` `cb312689` / PR #951 | yes | yes | merged | **LANDED** |
| Experimental MSPL handover `2816a1ad` | yes | not checked here | none | **PROTECTED**; owned by its experimental lane |
| Hundreds of historical `agent/*`, `claude/*`, and `codex/*` branches reported by the gate | mixed | many unpushed | mixed | **PROTECTED**; not this lane, do not push/delete |
| Dirty primary `claude/design-117-separation-programme` checkout | n/a | n/a | n/a | **PROTECTED**; never stage or edit from this lane |

## Files created or modified in this handover branch

Relative to `origin/main`, before this handover commit:

- `docs/dev-log/check-log.md`
- `docs/dev-log/release/2026-08-12-0.6-post-deployment-artifact-receipt.md`

This handover adds:

- `docs/dev-log/handover/2026-08-12-codex-handover.md`
- `AGENTS.md` (multi-lane rehydrate pointer only)

Never stage foreign worktree files, `lanes/*/results`, raw campaign outputs,
temporary tarballs, private libraries, or secrets.

## Next immediate steps

1. Rehydrate and classify the existing handovers as `OWED`, `DONE`, `DEFER`,
   or `PROTECTED`; current git state wins over prose.
2. Run `~/shinichi-brain/tools/lane_preflight.sh <repo>` and inspect the two
   candidate pre-0.7 lanes plus open issues using narrow GitHub queries.
3. Ask Rose through `.codex/agents/systems-auditor.toml` for a read-only
   cross-lane consistency audit before making any public-surface judgment.
4. Produce the integration-intake matrix: candidate, owner/branch, evidence,
   release benefit, risk, required tests/docs, and recommendation.
5. Ask Shinichi to approve the resulting bounded implementation order. For any
   simulation estimated above 30 minutes, provide a pre-run test and estimate
   first; compute stays on Totoro/DRAC, never Actions.

## Gotchas and failed approaches

- `NOT_CRAN=true` is mandatory for meaningful local non-CRAN tests; without it
  many assertions skip. Inspect skip counts, not just exit status.
- For the artifact check, use normal vignettes. The old no-vignette tarball was
  diagnostic only and is explicitly excluded from evidence.
- A direct local check proves macOS only. The three-OS claim here relies on the
  verified package-byte identity with the successful matrix source.
- A `codex-exact-root` call tried to launch its interactive TUI in a non-TTY;
  use ordinary `git status` and explicit worktree paths in scripted contexts.
- Do not restart, expand, summarise, or interpret LA-MSPL runs from this lane.

## How to resume

From this worktree, start a fresh Codex session and paste exactly:

```text
Rehydrate from docs/dev-log/handover/2026-08-12-codex-handover.md + the AGENTS.md snapshot, then continue with the Next Immediate Steps.
```

Read in this order:

1. `AGENTS.md` (native)
2. this handover
3. `docs/dev-log/handover/2026-07-25-active-lane-split.md` (every row)
4. `docs/dev-log/release/2026-08-12-0.6-post-deployment-artifact-receipt.md`
5. `docs/dev-log/release/2026-08-09-pre-0.7-issue-disposition-ledger.md`
6. `docs/design/35-validation-debt-register.md` and
   `docs/design/05-testing-strategy.md`
7. `.codex/agents/systems-auditor.toml` (Rose) before public-claim changes.

Codex owns the live toolchain: real R/TMB fits, `R CMD check`, rendering, and
authorised Totoro/DRAC compute. Planning-only work may be routed elsewhere.

```sh
cd "/Users/z3437171/Dropbox/Github Local/gllvmTMB/.codex/worktrees/mainline-06-issue-closeout"
export NOT_CRAN=true
export OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1 MKL_NUM_THREADS=1
Rscript --vanilla -e 'devtools::load_all(".", compile = TRUE)'
```

Use `NOT_CRAN=false` only for a deliberate CRAN-style artifact check. Heavy
tests additionally require `GLLVMTMB_HEAVY_TESTS=1`; do not set that by
default. No compiler/PATH override is needed on this macOS worktree.

## Mission control

| repo | main | CI · what shipped | plan by leverage |
| --- | --- | --- | --- |
| gllvmTMB | `origin/main` `cb312689`; local handover branch ahead by docs commits | PR #951 merged; fresh 0.6 exact tarball is 0E/0W/1 expected NOTE; three-OS matrix green by byte identity; limits page live | 1. integration intake · 2. owner-approved bounded implementation · 3. fresh candidate evidence only when scope earns it |
| gllvmTMB LA-MSPL B2 | separate experimental lane | partial Totoro artifacts; Rorqual recovery pending authentication | owning lane authenticates and adjudicates; never a 0.7 blocker |
