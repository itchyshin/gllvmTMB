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

## Codex pause window (2026-05-13 -> ~2026-05-17)

**Codex is paused.** Codex completed PR #69
(`covariance-correlation` post-#61 Pat/Rose re-read; merged
2026-05-13 ~08:12 MT) and handed off via maintainer 2026-05-13
~07:00 MT. Codex is treated as away until maintainer
re-dispatch, likely after 2026-05-17.

During the pause window:

- Codex's queued lanes (`_pkgdown.yml` navbar, article cleanup)
  are temporarily reassigned to Claude.
- Codex's file-ownership rows in the table below are temporarily
  reassigned to Claude with a "(Codex pause)" tag.
- Each lane Claude picks up during the pause window gets a
  Recently resolved entry naming the temporary reassignment so
  that when Codex returns, the audit trail is clear.
- If maintainer dispatches Codex back early, restore the
  original ownership rows and move any in-flight Claude lane
  back to Queued (or finish it first if near-merge).

## Active lanes

| Agent | Lane | PR / branch | Files touched | Status |
|---|---|---|---|---|
| Claude | Article cleanup + long/wide sweep | #74 / `agent/article-cleanup-long-wide-sweep` | 5 articles + after-task | CI green; queued for merge |
| Claude | `choose-your-model.Rmd` rewrite (F1+F2+F3) | #75 / `agent/choose-your-model-rewrite` | `choose-your-model.Rmd` + after-task | CI green; queued for merge |
| Claude | Remove misleading `unique()` section | #76 / `agent/covariance-correlation-fix-unique-section` | `covariance-correlation.Rmd` + after-task | CI green; queued for merge |
| Claude | Pitfalls section 5 rewrite (paired phylo) | #77 / `agent/pitfalls-phylo-paired-fix` | `pitfalls.Rmd` | CI green; queued for merge (touches same file as #74 -- merge #77 first) |
| Claude | functional-biogeography: replace M1-M4 jargon | #78 / `agent/functional-biogeography-no-Mlabels` | `functional-biogeography.Rmd` | CI pending |
| Claude | check-log Kaizen + post-overnight drift scan | #79 / `agent/checklog-rebuild-canon-lesson` | `check-log.md` + new `audits/2026-05-13-*.md` | CI pending |
| Codex | -- (paused ~May 13 -> ~May 17) | -- | -- | paused per maintainer handoff |

**WIP**: 6 Claude PRs open (well past the soft cap of 3). The
maintainer explicitly requested this thoroughness today
("Kaizen!"); cap suspended for this in-flight batch. **No more
new Claude PRs until #74-#79 merge and WIP drops.**

Update protocol: when you start a lane, add a row. When the lane's
PR opens, fill `PR / branch`. When the PR merges, move the row to
"Recently resolved" with the merge date.

## Queued lanes (not yet picked up)

Per `docs/dev-log/audits/2026-05-13-post-overnight-drift-scan.md`
batching plan; opened only after the in-flight WIP drops.

| Agent | Lane | Wait condition |
|---|---|---|
| Claude (Codex pause) | Batch A: paired-canon corrections in `R/unique-keyword.R`, `R/extract-omega.R`, `R/fit-multi.R` (roxygen + cli_inform prose only) | #74-#79 merged |
| Claude (Codex pause) | Batch B: drop in-prep `(Eq. 13/14/15)` citations in `R/diagnose.R` | #74-#79 merged |
| Claude (Codex pause) | Batch C: replace `\Psi` notation + `Phase D / Phase K` jargon in `functional-biogeography.Rmd` + `joint-sdm.Rmd` | #74-#79 merged |
| Claude (Codex pause) | Batch D: convert active `gllvmTMB_wide()` recommendations to `traits(...)` form in `morphometrics.Rmd` + `response-families.Rmd` | #74-#79 merged |
| Claude (Codex pause) | Batch E: `\mathbf{U} -> \mathbf{S}` in `behavioural-syndromes.Rmd` math; roxygen-only sweep of `R/extract-two-U-via-PIC.R` (function name stays) | #74-#79 merged |

Move a row to "Active lanes" when you start it.

## File ownership for the current docs / navigation pass

Per PR #64 Section K (the joint plan). Lock these files behind
the named owner; if the other agent needs to touch them, leave a
coordination comment first. During the **Codex pause window**
(2026-05-13 -> ~2026-05-17), rows tagged `(Codex pause)` are
temporarily reassigned to Claude.

| File | Owner (this pass) |
|---|---|
| `vignettes/articles/covariance-correlation.Rmd` | Codex (PR #61 + #69 done; settled for now) |
| `_pkgdown.yml` | Claude (Codex pause); restore to Codex when Codex returns |
| `README.md` | Claude (PR #65 dropped wide-matrix block; PR #67 D1+D2+D4 landed) |
| `CLAUDE.md`, `AGENTS.md`, `CONTRIBUTING.md` | Claude (rule files) |
| `docs/design/*` | open; coordinate per file |
| `docs/dev-log/*` | each agent owns its own `after-task/*.md` and `shannon-audits/*.md` |
| Other Tier-1 article rewrites (`choose-your-model`, etc.) | Claude (Codex pause); coordinate when Codex returns |
| `R/*` | Codex by default; Claude only for rule-file-driven changes (e.g. PR #65 deprecation) -- **untouched during pause** |

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
