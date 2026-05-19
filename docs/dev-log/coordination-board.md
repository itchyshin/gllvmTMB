# Agent Coordination Board

**Purpose.** Single live status doc both agents (Claude, Codex)
edit so that "what is the other agent working on right now?" has
a one-file answer. Complements the existing channels:

- `docs/dev-log/shannon-audits/` -- per-pass audit snapshots
  (point-in-time deliverables).
- `docs/dev-log/check-log.md` -- durable append-only lessons
  learned (per PR #22 codification).
- `docs/dev-log/after-task/*.md` -- per-PR retrospectives.
- `docs/dev-log/while-away/*.md` -- overnight reports to the
  maintainer.
- PR comments + descriptions -- real-time discussion.

This file is **live**: replace stale entries rather than
appending. Sections "Active lanes" and "Pending coordination
questions" should be edited as state changes. The "Recently
resolved" section is a 24-48 hour rolling window; older items
move to per-PR after-task reports or the check-log.

Both agents commit edits to this file with a short message like:

```
coord-board: <agent> picked up <lane>
coord-board: <agent> resolved <question>
```

## Codex-return status (effective 2026-05-18)

**Codex is back for a bounded review / hygiene lane.** The
2026-05-14 Codex-absent assumption is no longer the current
working state, but it remains a useful historical explanation
for why Claude carried several Codex-owned lanes during the
pause.

Current operating rule:

- PR #181 (sparse pedigree A-inverse engine pass-through) and
  PR #182 (M3.4 warm-start + phi-clamp) were reviewed by Codex
  and merged to `main` on 2026-05-18.
- PR #184 (drmTMB-parity hygiene cascade) was green on three OSes
  before merge and merged to `main` on 2026-05-18. Its first
  post-merge main run failed once, then the failed-job rerun recovered.
- PR #186 (red-main M3.4 test hygiene) merged on 2026-05-18 to
  stabilize the smoke-test contract exposed by that failed main run.
- PR #185 (Slice 1 PR slice contract) merged on 2026-05-18.
- PR #187 (CI tiered gates) merged on 2026-05-18; the process-only
  fast-pass behaviour was verified in real CI on PR #188.
- PR #188 (process-only Shannon handoff snapshots) merged on 2026-05-19.
- PR #189 (pkgdown Response families reference index) merged on 2026-05-18.
- PR #195 (Slice 2 after-task templates) merged on 2026-05-19.
- PR #197 (M3.3 production grid workflow) merged on 2026-05-19.
- PR #199 (M3.3 production artifact review) merged on 2026-05-19
  after 3-OS R-CMD-check passed.
- PR #200 (post-M3 ROADMAP evidence refresh) merged on 2026-05-19
  after 3-OS R-CMD-check passed.
- PR #201 (M3.3 failure-mode ledger) merged on 2026-05-19 after
  3-OS R-CMD-check passed.
- PR #202 (M3.3 target-scale audit) merged on 2026-05-19 after
  3-OS R-CMD-check passed.
- Both teams should keep write scopes explicit in this file until
  the open PR count returns to zero.

## Active lanes

| Agent | Lane | PR / branch | Files touched | Status |
|---|---|---|---|---|
| Ada (Codex) | CI ignored-source fast path | `codex/ci-ignored-docs-fast-path-2026-05-19` | `.github/workflows/R-CMD-check.yaml`, CONTRIBUTING, check-log, after-task, coordination board | in progress |

**WIP**: 1. Avoid parallel R-CMD-check workflow, CONTRIBUTING,
check-log, after-task, and coordination-board edits until this lane
lands or is explicitly held.

Update protocol: when you start a lane, add a row. When the lane's
PR opens, fill `PR / branch`. When the PR merges, move the row to
"Recently resolved" with the merge date.

## Queued lanes (not yet picked up)

Per `docs/dev-log/audits/2026-05-13-post-overnight-drift-scan.md`
batching plan + the 2026-05-14 strategic plan revision. Many older
rows below were completed or superseded during the Codex pause; keep
new queued rows current and move stale history to after-task reports
instead of expanding this table.

| Agent | Lane | Wait condition |
|---|---|---|
| Codex + Claude | Revisit `drmTMB` workflow lessons for reader path and pkgdown shape | after Slice 1/2 discipline surfaces are in place |
| Codex | Next small reader-facing lane | after maintainer chooses whether this should be README/pkgdown navigation, a Tier-1 article re-read, or validation-debt surfacing |

Move a row to "Active lanes" when you start it.

## File ownership for the current docs / navigation pass

Current ownership is lane-specific. Lock these files behind the
named owner; if the other agent needs to touch them, they should
leave a coordination comment first and wait for acknowledgement.

| File | Owner (this pass) |
|---|---|
| `.github/workflows/R-CMD-check.yaml` | Ada (Codex) for CI ignored-source fast path |
| `.github/pull_request_template.md` | no active owner in this lane; do not edit |
| `CONTRIBUTING.md` | Ada (Codex) for CI ignored-source fast path |
| `docs/dev-log/coordination-board.md` | Ada (Codex) for current CI ignored-source lane |
| `docs/dev-log/check-log.md` | Ada (Codex) for current CI ignored-source entry |
| `docs/dev-log/after-task/2026-05-18-pr-slice-contract.md` | Codex for current Slice 1 after-task report |
| `CLAUDE.md`, `AGENTS.md` | no active owner in this lane; do not edit |
| `_pkgdown.yml`, `README.md` | no active owner in this lane; do not edit |
| `docs/design/42-m3-dgp-grid.md`, `docs/design/44-m3-3-inference-replacement.md` | Ada (Codex) for target-scale clarification only |
| `vignettes/articles/covariance-correlation.Rmd` | no active owner in this lane; do not edit here |
| `docs/design/*` | coordinate per file; this lane only touches stale source-of-truth wording |
| `docs/dev-log/*` | each agent owns its own `after-task/*.md` and `shannon-audits/*.md` |
| Tier-1 article rewrites (`choose-your-model`, `phylogenetic-gllvm`, etc.) | paused; revisit after this hygiene stop point |
| `R/*` | no active engine owner after #181 / #182 merged. This hygiene lane made narrow wording-only roxygen/comment updates in `R/gllvmTMB.R`, `R/traits-keyword.R`, `R/brms-sugar.R`, `R/two-stage.R`, and `R/animal-keyword.R`; engine logic now on `main` came from #181 / #182. Coordinate before further R edits. |
| `tests/testthat/*` | no active owner after #181 / #182 merged; new tests from those PRs are now on `main` |
| `src/gllvmTMB.cpp` | no owner in this lane; do not edit |

If a file's owner needs to change (e.g. Claude needs to touch
`_pkgdown.yml` for a one-line reason), update the row, leave a
PR comment, wait for the other agent's acknowledgement.

## Pending coordination questions

None open.

Resolved 2026-05-18: maintainer asked Codex to review and merge
the held engine PRs before the next `drmTMB` workflow revisit.
Codex reviewed #181 and #182, simulated the combined merge order,
ran the targeted tests, and merged #181 then #182.

Active question template (when adding):

```
**Q (yyyy-mm-dd hh:mm MT, <asker>)**: <question>
Open until: <when answer is needed>
Touches: <files>
```

Resolved questions move to "Recently resolved" with the answer.

## Recently resolved (rolling 24-48h)

- **2026-05-19 ~12:33 MT**: PR #200 (post-M3 ROADMAP evidence
  refresh) merged to `main` after three-OS R-CMD-check passed. The
  roadmap now records PR #199's production-evidence outcome and keeps
  M3.3 in failure-mode triage.
- **2026-05-19 ~13:31 MT**: PR #201 (M3.3 failure-mode ledger)
  merged to `main` after three-OS R-CMD-check passed. The ledger found
  systematic above-upper-bound `psi` misses and recorded glmmTMB /
  galamm comparator scope.
- **2026-05-19 ~14:13 MT**: PR #202 (M3.3 target-scale audit) merged
  to `main` after three-OS R-CMD-check passed. The audit split `psi`
  into a diagnostic target and total `Sigma_unit[tt]` into the primary
  promotion target for the next M3.3 pilot.
- **2026-05-19 ~11:43 MT**: PR #199 (M3.3 production artifact review)
  merged to `main` after three-OS R-CMD-check passed. The production
  workflow passed compute but failed the statistical coverage gate, so
  CI-08 / CI-10 stayed partial and M3.3 moved to failure-mode triage.
- **2026-05-19 ~07:23 MT**: PR #197 (M3.3 production grid
  `workflow_dispatch` wiring) merged to `main` after 3-OS
  R-CMD-check passed.
- **2026-05-19 ~06:32 MT**: PR #195 (Slice 2 after-task templates)
  merged to `main`.
- **2026-05-19 ~05:47 MT**: PR #193 (in-prep citation discipline)
  merged to `main`.
- **2026-05-19 ~05:19 MT**: PR #190 (Families help topic mixed-family
  selector-column documentation) merged to `main`.
- **2026-05-18 ~16:35 MT**: PR #187 CI tiered gates passed full
  three-OS R-CMD-check after a macOS Bash 3.2 classifier fix. The
  workflow now preserves the OS-named required checks while fast-
  passing known process-only paths inside the job.
- **2026-05-18 ~14:02 MT**: PR #184 drmTMB-parity hygiene cascade
  merged after three-OS R-CMD-check success. Open PR count returned
  to zero before Slice 1 (`codex/pr-slice-contract`) started.
- **2026-05-18 ~13:00 MT**: PR #181 sparse pedigree A-inverse
  engine pass-through and PR #182 M3.4 warm-start + phi-clamp
  were reviewed by Codex and merged to `main`. Combined
  #181 -> #182 tree was simulated before merge; targeted checks
  passed with `NOT_CRAN=true` + `devtools::load_all(".")`:
  sparse-Ainv engine 8/8 and M3.4 warm-start / phi-clamp 14/14.
  #184 is now the only open PR and has been synced with the
  post-merge `main`.
- **2026-05-13 ~20:30 MT**: Seven-PR evening sweep merged after
  maintainer authorization. In chronological merge order on
  main: #76 (cov-corr misleading-section removal, landed
  mid-day), then #75 (choose-your-model rewrite), #78
  (functional-biogeography no-M-labels), #79 (check-log Kaizen
  + post-overnight drift-scan audit + coord-board sync), #80
  (README Tiny example wide-form + drop `gllvmTMB_wide`
  mention), #77 (pitfalls section 5 paired+three-piece phylo
  with general-Omega note), #74 (article cleanup + long+wide
  pair sweep). Three maintainer corrections were stacked into
  PR #77 over the evening: identifiability nuance ("can't get
  2 Ss → omega is usual"), three-piece naming ("4 parts
  vs 3 parts"), and general-Omega framing ("omega can be used
  for any combinations of adding all variance components").
  All three are durably captured in the merged
  `check-log.md` point 8 and the merged
  `audits/2026-05-13-post-overnight-drift-scan.md`. WIP back
  to 0. Batches A-E (R/ + a few articles) queued; Batches A
  and B remain blocked by the Codex-pause R/ rule.
- **2026-05-13 ~08:12 MT**: Codex's `covariance-correlation`
  post-#61 Pat/Rose re-read landed (PR #69 merged on Codex's
  behalf per their handoff). PR #69 reopens the article with the
  applied behavioural-syndrome framing, adds early long+wide
  examples, uses the single-entry `gllvmTMB()` with `traits(...)`,
  defines `level` before `Sigma_level`, drops the stale OLRE
  "Future work" heading, replaces stale See-also links.
- **2026-05-13 ~07:00 MT**: Codex pause handoff (maintainer
  relay). Codex stops after PR #69; treated as paused until
  re-dispatch ~2026-05-17. Codex's queued lanes
  (`_pkgdown.yml` navbar, article cleanup, `choose-your-model`
  rewrite) reassigned to Claude during the pause window.
- **2026-05-13 ~06:30 MT**: Claude's README D1+D2+D4 lane
  landed (PR #67 merged). README opener rewrite + section
  reorder ("What can I model now?" up to position 4) +
  "What 'stacked-trait' means" definition section. Codex's
  `_pkgdown.yml` navbar lane now unblocked (wait condition
  cleared). The navbar's vocabulary should echo the
  README's new section labels ("Model guides", concept-and-
  reference split per PR #64 Section I, with Codex's
  preferred label "Concepts" for the second menu).
- **2026-05-13 ~05:40 MT**: Joint plan (PR #64) ratified by
  Codex. Two small qualifications:
  - Navbar second-menu label preferred "Concepts" (cleanest)
    over "Concepts and reference" -- Codex's call when the
    navbar PR lands.
  - `covariance-correlation` verdict is "post-#61 Pat/Rose
    re-read; rewrite only if the re-read still fails Tier-1
    rules" rather than a flat "rewrite". Audit's "rewrite"
    label is a placeholder; final decision after the re-read.
  Claude picked up the first implementation lane: README
  D1+D2+D4. Codex will own the navbar PR after the README
  PR lands.
- **2026-05-13 ~05:10 MT**: Codex acknowledged the board and
  agreed to use it for the next 1-2 days. Active-lane schema
  amended (Codex's "covariance-correlation re-read" moved
  from `dispatched` to a Queued lanes subsection, since Codex
  has not picked it up yet).
- **2026-05-13 ~05:00 MT**: Maintainer asked whether to create a
  dedicated coordination channel beyond the existing Shannon
  audit + check-log channels. **Resolved**: yes, this file is
  the dedicated channel.
- **2026-05-13 ~04:30 MT**: Should `gllvmTMB_wide()` be
  deprecated? **Resolved**: yes (maintainer answer "Yes, deprecate
  via single bundled PR"). Implemented in PR #65.
- **2026-05-13 ~04:25 MT**: README is hard for new users to
  read; Rose audit needed. **Resolved**: PR #64 (Rose audit)
  covers the README + cross-doc framing drift; extended with
  Sections G-L for the joint plan.
- **2026-05-13 ~03:30 MT**: `covariance-correlation.Rmd` has
  substantive mistakes that Codex should fix. **Resolved**: PR
  #61 (Codex) merged.

## Pointers (where else to look)

- **Current open PRs**: `gh pr list --repo itchyshin/gllvmTMB --state open`
- **Active joint plan**: PR #64 (Rose audit, Sections G-L).
- **Per-PR retrospectives**: `docs/dev-log/after-task/`.
- **Durable lessons**: `docs/dev-log/check-log.md`.
- **Codex's coordination message format**: usually relayed via
  maintainer through chat; format is "scope X, files Y, lanes
  Z". Reply via this board + the relevant PR comment.
- **Claude's plan file** (`~/.claude/plans/please-have-a-robust-elephant.md`):
  private to Claude; mirrors the public state of this board for
  Claude's own execution view. Codex has a similar private
  context.

## Update history (last 5)

- 2026-05-14 ~21:00 MT: Codex-absent assumption codified
  (maintainer "codex might not come back so you should
  plan to do it"). R/ + tests/testthat/ + src/ ownership
  reassigned to Claude under heavy persona-review discipline.
  Active lanes: 3 docs-only Claude PRs (#83, #84, this PR).
  Queued lanes restructured around Phase 1a/1b/1b'/1c plan.
  Restoration rule documented if Codex returns (Claude).
- 2026-05-13 ~20:30 MT: Seven-PR evening sweep merged via
  maintainer authorization; active-lane table reset to
  "(none active)"; WIP back to 0 (Claude).
- 2026-05-13 ~17:30 MT: Active-lane table populated with the six
  in-flight Claude PRs (#74-#79); Codex's three queued lanes
  marked done (navbar PR #73, article cleanup PR #74, choose-your-model
  PR #75); Batch A-E queue inserted for the post-overnight drift
  scan campaign; WIP-cap suspension acknowledged in-line (Claude).
- 2026-05-13 ~08:15 MT: Codex paused after PR #69; queued lanes
  reassigned to Claude during pause window; file-ownership
  rows tagged `(Codex pause)` (Claude).
- 2026-05-13 ~06:30 MT: PR #67 merged (README D1+D2+D4);
  Claude's row moved to "(none active)"; Codex's
  `_pkgdown.yml` lane unblocked (Claude).
- 2026-05-13 ~05:40 MT: PR #64 merged; Claude picked up the
  README D1+D2+D4 lane; Codex's queued lanes updated (Claude).
- 2026-05-13 ~05:11 MT: Active-lane schema amended per Codex
  feedback; "Queued lanes" subsection added (Claude).
