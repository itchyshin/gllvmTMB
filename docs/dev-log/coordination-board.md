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

## Codex-absent assumption (effective 2026-05-14)

**Codex is assumed absent for the foreseeable future.**
Maintainer guidance 2026-05-14: *"codex might not come back so
you should plan to do it"*. Original pause was 2026-05-13 ->
~2026-05-17 (Codex completed PR #69 and handed off via
maintainer). With no confirmed return date, all lanes
formerly reserved for Codex are reassigned to Claude on a
working-assumption basis.

Operational rules under the absent assumption:

- All R/ implementation work is Claude's. Discipline gates
  (Gauss + Noether + Fisher + Rose persona reviews per PR)
  remain in force; reviews are persona-style read-only
  Explore agents, not separate human agents.
- All previously-queued Codex lanes (drift-scan Batches A +
  B; further `_pkgdown.yml` work; cross-package validation
  port) are reassigned to Claude.
- The audit trail for each Claude-handled R/ PR records that
  Codex was absent (no Codex review available) and lists the
  persona-side reviews that substituted.
- **If Codex returns**, restore the original file-ownership
  rows below, hand back any in-flight R/ work that hasn't
  reached CI green, and finish near-merge work before
  rolling over.

## Active lanes

| Agent | Lane | PR / branch | Files touched | Status |
|---|---|---|---|---|
| Claude | 2026-05-13 evening-sweep retrospective | #83 / `agent/post-merge-retrospective-2026-05-13` | `docs/dev-log/check-log.md` | CI pending; self-merge eligible |
| Claude | 2026-05-14 strategic-plan-revision after-task | #84 / `agent/after-task-strategic-plan-revision` | `docs/dev-log/after-task/...` | CI pending; self-merge eligible |
| Claude | Coord-board: Codex-absent assumption | this PR / `agent/coord-board-codex-absent` | this file | CI pending; self-merge eligible |
| Codex | -- (assumed absent for the foreseeable future) | -- | -- | maintainer 2026-05-14: "plan to do it" |

**WIP**: 3 Claude PRs open. At the soft cap of 3 -- the three
PRs are all docs-only / dev-log and self-merge eligible; new
lanes wait until they merge.

Update protocol: when you start a lane, add a row. When the lane's
PR opens, fill `PR / branch`. When the PR merges, move the row to
"Recently resolved" with the merge date.

## Queued lanes (not yet picked up)

Per `docs/dev-log/audits/2026-05-13-post-overnight-drift-scan.md`
batching plan + the 2026-05-14 strategic plan revision. With
Codex absent, Claude carries all of these:

| Agent | Lane | Wait condition |
|---|---|---|
| Claude | Phase 1a Batch A: paired-canon corrections in `R/unique-keyword.R`, `R/fit-multi.R` (roxygen + cli_inform prose; expanded scope per 2026-05-14 plan) | #83, #84, this PR merged |
| Claude | Phase 1a Batch B: drop in-prep `Eq. N` citations across R/diagnose.R, R/methods-gllvmTMB.R, R/extract-omega.R (incl. an `@title`), R/unique-keyword.R, R/extractors.R (2 `@title` lines) | #83, #84, this PR merged |
| Claude | Phase 1a Batch D: convert active `gllvmTMB_wide()` recommendations to `traits(...)` form in `morphometrics.Rmd` + `response-families.Rmd` | #83, #84, this PR merged |
| Claude | Phase 1a Batch E: `\mathbf{U} -> \mathbf{S}` in `behavioural-syndromes.Rmd` math; roxygen-only sweep of `R/extract-two-U-via-PIC.R` (function name stays) | #83, #84, this PR merged |
| Claude | Phase 1b: `extract_correlations()` `link_residual = "auto"` + `check_auto_residual()` + `check_identifiability()` + expanded profile-CI edge tests | After 1a |
| Claude | Phase 1b': Profile-CI Validation milestone (Jason pre-scan + coverage study + `confint_inspect()` + `troubleshooting-profile.Rmd` Concepts article) | After 1b |
| Claude | Phase 1c: 13-PR article-port programme (9 ports + 4 new pedagogy articles) | After 1b' |

Move a row to "Active lanes" when you start it.

## File ownership for the current docs / navigation pass

Per PR #64 Section K (the joint plan) + 2026-05-14 Codex-absent
reassignment. Lock these files behind the named owner; if the
other agent (Codex if/when they return) needs to touch them,
they should leave a coordination comment first and wait for
acknowledgement.

| File | Owner (this pass) |
|---|---|
| `vignettes/articles/covariance-correlation.Rmd` | Claude (Codex absent; PR #61 + #69 done by Codex earlier; settled content-wise) |
| `_pkgdown.yml` | Claude (Codex absent); restore to Codex if/when Codex returns |
| `README.md` | Claude (PR #65 dropped wide-matrix block; PR #67 D1+D2+D4 landed; PR #80 added wide-form Tiny example) |
| `CLAUDE.md`, `AGENTS.md`, `CONTRIBUTING.md` | Claude (rule files) |
| `docs/design/*` | open; coordinate per file |
| `docs/dev-log/*` | each agent owns its own `after-task/*.md` and `shannon-audits/*.md` |
| Tier-1 article rewrites (`choose-your-model`, `phylogenetic-gllvm`, etc.) | Claude (Codex absent) |
| `R/*` | **Claude (Codex absent assumption, effective 2026-05-14)**; restore to Codex if/when Codex returns. Claude PRs to R/ must carry Gauss + Noether + Fisher + Rose persona reviews. |
| `tests/testthat/*` | Claude (Codex absent); persona reviews include Curie + Fisher for test design |
| `src/gllvmTMB.cpp` | **Claude (Codex absent)** for any prose / comment / header changes; engine code is more fragile -- consult Gauss persona before any C++ edit; defer non-trivial C++ to Codex return |

If a file's owner needs to change (e.g. Claude needs to touch
`_pkgdown.yml` for a one-line reason), update the row, leave a
PR comment, wait for the other agent's acknowledgement.

## Pending coordination questions

(None as of 2026-05-13 05:00 MT.)

Active question template (when adding):

```
**Q (yyyy-mm-dd hh:mm MT, <asker>)**: <question>
Open until: <when answer is needed>
Touches: <files>
```

Resolved questions move to "Recently resolved" with the answer.

## Recently resolved (rolling 24-48h)

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
