# Codex -> Claude Special Handover

Date: 2026-06-19 18:35 MDT

Active user goal:

> Finish the suggested Big 4 really well. Use agents well. Complete, test well,
> and make sure it is working in R, in Julia, and Julia via R.

Do not shrink success to a current slice. The whole goal remains active.

Hard guard:

> PR green != bridge complete != release ready != scientific coverage passed.

Hard boundaries:

- Do not push unless the maintainer explicitly asks.
- Do not mutate GLLVM.jl #101.
- Never use `git add -A`.
- Before editing shared files, run the pre-edit lane check:
  `gh pr list --state open` and
  `git log --all --oneline --since="6 hours ago"`.
- Work from repository state, not private chat memory.

## Where Claude Should Start

Read these first:

1. `/Users/z3437171/Dropbox/Github Local/gllvmTMB/AGENTS.md`
2. This checkpoint:
   `docs/dev-log/recovery-checkpoints/2026-06-19-183508-codex-claude-special-handover.md`
3. `git status --short --branch` in the main checkout.
4. `git -C /private/tmp/gllvmtmb-bridge-admission-split status --short --branch`
5. `git -C /private/tmp/gllvmtmb-coevolution-engine-split status --short --branch`
6. Latest entries in `docs/dev-log/check-log.md`.
7. Dashboard files under `docs/dev-log/dashboard/`.
8. `docs/design/35-validation-debt-register.md` rows JUL-01/JUL-01A and
   COE-03/COE-04.
9. `docs/design/65-cross-lineage-coevolution-kernel.md` C3.

## Current Branch / Worktree State

Main mission-control checkout:

- Path: `/Users/z3437171/Dropbox/Github Local/gllvmTMB`
- Branch: `codex/r-bridge-grouped-dispersion`
- State: ahead of origin by 56 and very dirty. It contains broad accumulated
  mission-control/dashboard/article/unique/co-evolution work. Do not use it as
  a clean PR basis.

Bridge split:

- Path: `/private/tmp/gllvmtmb-bridge-admission-split`
- Branch: `codex/bridge-admission-split-20260619`
- Head: `c061ce2 docs: refresh bridge split validation`
- State at handover: clean.
- Purpose: clean local Julia bridge admission split.
- Evidence already run: R-only no-Julia tests, pinned Julia-only GLLVM.jl tests,
  live Julia-via-R tests, full `devtools::test()`,
  `pkgdown::check_pkgdown()`, and R CMD check. Known R CMD check warning only:
  Apple Clang / R header `R_ext/Boolean.h` warning.
- Important: PR #489 still points to the broader remote branch, not this local
  split. Do not treat PR #489 green as proof for this split.

Coevolution split:

- Path: `/private/tmp/gllvmtmb-coevolution-engine-split`
- Branch: `codex/coevolution-engine-split-20260619`
- Head: `ad88ecb test: add coevolution sigma recovery gate`
- State at handover: clean.
- Stack: now rebased on the latest bridge split head `c061ce2`.
- Recent stack:
  - `ebf9043 feat: add fixed multi-kernel coevolution gate`
  - `90220d6 test: strengthen coevolution kernel split gates`
  - `ad88ecb test: add coevolution sigma recovery gate`
- Post-rebase smoke run:
  `Rscript --vanilla -e 'devtools::test(filter = "coevolution-two-kernel", reporter = "summary")'`
  -> exit code 0; heavy rows skipped as expected.
- Before the rebase, focused and broad heavy `kernel|coevolution` gates passed.
  If Claude continues this lane, rerun the broad heavy gate after the rebase
  before making stronger claims:
  `GLLVMTMB_HEAVY_TESTS=1 Rscript --vanilla -e 'devtools::test(filter = "kernel|coevolution", reporter = "summary")'`.

Unique / ordinary latent Psi split:

- Path: `/private/tmp/gllvmtmb-unique-latent-psi-split`
- Branch: `codex/unique-latent-psi-split-20260619`
- Head: `e2866f7 docs: close unique latent psi split audit`
- State at last check: clean.
- Purpose: closes the `unique()` compatibility / ordinary `latent()` Psi wording
  and audit lane locally.

## Widget / Dashboard

- Current in-app browser URL: `http://127.0.0.1:8770/`
- Checked immediately before this checkpoint:
  - `http://127.0.0.1:8765/` -> HTTP 200
  - `http://127.0.0.1:8770/` -> HTTP 200
- Dashboard source: `docs/dev-log/dashboard/`
- Serving copy: `/tmp/gllvm-dashboard/`
- After dashboard edits, refresh with:
  `rsync -a docs/dev-log/dashboard/ /tmp/gllvm-dashboard/`
- Dashboard edits belong in the mission-control checkout, not the clean split
  worktrees, unless the maintainer explicitly asks to fold dashboard state into
  a split branch.

## Plan / Big 4

1. **Bridge admission split.**
   Decide how to land the clean bridge split without confusing it with PR #489.
   Current local evidence is strong for R, Julia, and Julia-via-R, but there is
   no split-branch PR and no 3-OS CI for the split. Next safe action is a
   landing decision, not another broad implementation.

2. **Coevolution fixed-kernel evidence.**
   Continue one narrow COE-04 gate at a time. The latest local work added
   mixed-rank offset/gradient checks and a Gaussian fixed-effect/shared-Sigma
   recovery gate. COE-04 remains `partial`: no in-engine `rho`, no rho
   intervals, no formal null/Type-I calibration, no mixed-family coverage, no
   module/rank calibration, and no broad scientific coverage.

3. **Article / public surface estate.**
   Continue browser-review and public/internal placement decisions one article
   at a time. The dashboard/article-council backlog is the source of truth.
   Do not make an article public merely because it renders.

4. **Release-readiness map.**
   Only after split branches are clean and intended landing order is explicit,
   reconcile NEWS, validation debt, pkgdown, check-log, after-task coverage,
   dashboard status, and CI evidence. Release readiness requires merged code,
   3-OS CI, pkgdown, validation-register alignment, and no scientific overclaim.

## Recommended First Claude Action

Start with the clean split status, not the dirty main checkout:

```sh
cd "/Users/z3437171/Dropbox/Github Local/gllvmTMB"
git status --short --branch
git -C /private/tmp/gllvmtmb-bridge-admission-split status --short --branch
git -C /private/tmp/gllvmtmb-coevolution-engine-split status --short --branch
git -C /private/tmp/gllvmtmb-coevolution-engine-split log --oneline --decorate --graph --max-count=8
curl -s -o /dev/null -w '8765 %{http_code}\n' http://127.0.0.1:8765/
curl -s -o /dev/null -w '8770 %{http_code}\n' http://127.0.0.1:8770/
```

Then choose one narrow next gate:

- If bridge lane: prepare/ask for maintainer decision on pushing or replacing
  PR #489 with the clean bridge split.
- If coevolution lane: rerun post-rebase heavy
  `GLLVMTMB_HEAVY_TESTS=1 devtools::test(filter = "kernel|coevolution")`,
  then decide the next single COE-04 evidence gap.
- If dashboard/article lane: inspect `docs/dev-log/dashboard/status.json`,
  `docs/dev-log/dashboard/sweep.json`, and the article council ledger before
  editing; keep `8765` / `8770` live and refresh `/tmp/gllvm-dashboard/` after
  edits.

## Do Not Claim

- Do not claim bridge completion.
- Do not claim release readiness.
- Do not claim scientific coverage passed.
- Do not claim in-engine `rho` estimation, rho intervals, interval calibration,
  formal null/Type-I calibration, mixed-family coevolution coverage, or broad
  COE-04 coverage.
- Do not treat PR #489 green as evidence for the local clean bridge split.
