# Shannon Audit — 2026-05-12 ~09:15 MT

**Trigger**: post-merge checkpoint after PR #31 (Codex Phase 3
implementation), PR #32 (Claude Option B unification), PR #33
(Claude fix-up of Codex's three review items), plus issue #34
(parser-sugar design ticket) just opened. Three merges + one issue
within ~2 hours is a natural Shannon checkpoint. Codex is about to
push the reader-facing sweep PR. Read-only audit of the
coordination state before that next handoff.

## Verdict: **PASS** with one minor hygiene note.

The Claude / Codex collaboration loop is operating as designed:
careful agent-to-agent review caught a real defect that CI did
not (PR #33), the after-task discipline ran at branch start on
every PR including Codex's in-flight sweep, decisions are recorded
durably (`docs/dev-log/decisions.md`), and the sugar design idea
was filed cleanly as issue #34 instead of bloating the in-flight
sweep PR.

## 1. PR + after-task pairing

| PR | Lead | After-task report | Status |
|---|---|---|---|
| #29 | Claude (Air format Option D) | `2026-05-12-air-format-config.md` | ✅ paired, merged |
| #30 | Claude (site × species sweep) | `2026-05-12-site-species-to-unit-trait.md` | ✅ paired, merged |
| #31 | Codex (Phase 3 weights) | `2026-05-12-phase3-weights-unified.md` | ✅ paired, merged |
| #32 | Claude (Option B unification) | `2026-05-12-unification-long-or-wide.md` | ✅ paired, merged |
| #33 | Claude (fix-up of Codex review items) | `2026-05-12-traits-rd-cleanup.md` | ✅ paired, merged |
| #34 | (issue, no PR) | n/a | n/a (design discussion) |
| in-flight: Codex sweep | Codex | `2026-05-12-long-wide-reader-sweep.md` | ✅ at branch start (this audit's first finding -- new branch `codex/long-wide-example-sweep` exists locally with an after-task at branch start, not yet pushed) |

Every PR has its paired after-task report in the same commit
range. Codex's in-flight sweep already has its branch-start report
even though no PR is open yet -- the new at-branch-start rule
(PR #22) is being followed.

## 2. Working-tree hygiene

- **Main repo checkout** (`/Users/z3437171/Dropbox/Github Local/gllvmTMB`):
  currently on branch `codex/long-wide-example-sweep` -- Codex's
  active sweep work. Do not touch the working tree. The
  after-task report at `docs/dev-log/after-task/2026-05-12-long-wide-reader-sweep.md`
  is the visible signal that the branch is in active use.
- **Claude worktrees** (`/tmp/gllvmTMB-*`): only the current
  `gllvmTMB-shannon` worktree is in use (for this audit). All
  earlier worktrees from today (gllvmTMB-air, gllvmTMB-rose,
  gllvmTMB-report, gllvmTMB-pr22ev, gllvmTMB-protocol,
  gllvmTMB-phase3, gllvmTMB-citations, gllvmTMB-unify,
  gllvmTMB-fixup) were removed via `git worktree remove --force`
  after each merge. Verified clean.

## 3. Cross-PR file overlap

| Lane | Active scope |
|---|---|
| Codex (sweep, local) | `vignettes/articles/*.Rmd`, `docs/design/02-data-shape-and-weights.md`, possibly `README.md`, `docs/dev-log/` (stale-wording sweep) |
| Claude (this audit) | `docs/dev-log/shannon-audits/2026-05-12-post-phase3-and-unification.md`, `docs/dev-log/after-task/2026-05-12-shannon-audit.md` |
| Claude (queued housekeeping) | `DESCRIPTION` (tidyselect cleanup), `docs/design/10-after-task-protocol.md` (Rd spot-check process lesson) |

**No overlap** between Codex's sweep and Claude's audit or
queued housekeeping. Codex's sweep does not touch `DESCRIPTION`,
the `Shannon` audit doc, or the protocol doc. Claude's queued
housekeeping does not touch articles or the data-shape design
doc. Safe to run in parallel.

## 4. Branch / PR census

**Open PRs**: 0
**Open issues**: 1 (#34, parser-sugar design, no implementation yet)
**Active local branches**:
- `main` (in main checkout, currently checked out as the source
  for `codex/long-wide-example-sweep`)
- `codex/long-wide-example-sweep` (Codex, in flight)
- `agent/shannon-audit-2026-05-12` (this PR)

**WIP discipline**: 0 open PRs at audit start, 1 Claude PR
about to open (this audit). After Codex's sweep PR opens, WIP
goes to 2. Within the 3-cap. Healthy.

## 5. Rule-vs-practice drift

The collaboration-stops list in `ROADMAP.md` includes deletions,
API changes, formula-grammar changes, likelihood changes, new
families, and broad article rewrites.

| Rule | Today's evidence |
|---|---|
| Stop for maintainer before deletions / API / grammar / likelihood / family changes | ✅ Followed. PR #34 (parser-sugar) was filed as a *design issue*, not a PR. The sugar would be a formula-grammar change and was explicitly held back from the in-flight sweep. |
| Merge-authority: low-risk self-merge, high-risk ask maintainer | ✅ Mostly followed. PR #29, #30, #31, #32, #33 all merged today; #31 was parser-facing and maintainer merged it explicitly. Edge case: PR #32 self-merged despite touching `R/traits-keyword.R` -- arguably API-adjacent. Codex's review caught the malformed Rd that resulted; PR #33 cleaned it up. Process worked, but the post-edit spot-check discipline (recorded in PR #33's after-task) is the lesson. |
| After-task at branch start (PR #22 rule) | ✅ Codex's in-flight sweep already has its branch-start report. Working as designed. |
| Pre-edit lane check on shared files | ✅ Each of today's Claude PRs did the check. The post-edit issue with PR #32's malformed Rd was a rendered-output spot-check gap, not a lane-check gap. |
| Append-only logs (`decisions.md`, `check-log.md`) | ✅ Append-only convention worked under three-PR parallel pressure earlier today; PR #25's conflict on `check-log.md` was resolved by keeping both entries chronologically (the canonical fix). |

## 6. Sequencing

Today's merge order:
1. PR #29 (Air format Option D) -- merged 05:32 MT
2. PR #30 (site × species sweep) -- merged 05:38 MT
3. PR #31 (Codex Phase 3) -- merged 07:03 MT
4. PR #32 (Option B unification) -- merged 07:58 MT
5. PR #33 (fix-up) -- merged 08:45 MT
6. Issue #34 (sugar design) -- filed 09:00 MT
7. Codex sweep PR -- in flight, not yet pushed

The sequence respects:
- Codex's request to merge Phase 3 first (PR #31 → unblocks unification on the helper)
- The user's "do not start Phase 1a row 2 yet" instruction
- The "API direction locks before article work" sequence
- Issue #34 filed before any further parser/grammar work

No sequencing red flags. The "Codex sweep AFTER unification lands"
discipline held, even though the timing was tight.

## Findings

### One minor hygiene note (not a blocker)

**Old `agent/` and `codex/` branches accumulating on origin.** As
of audit time:

```
agent/after-task-protocol-enrich
agent/air-format-trial
agent/bootstrap
agent/bootstrap-after-task-report
agent/citations-cleanup-path-a
agent/extractor-examples
agent/first-shannon-audit
agent/handoff-readfirst-update
agent/logo-favicon
agent/long-wide-convention
agent/missing-after-tasks
agent/overnight-report-2026-05-11
agent/phase3-weights-contract
agent/phylo-keyword-examples
agent/pkgdown-destination-fix
agent/pkgdown-workflow-run-verification
agent/pr22-check-log-evidence
agent/priority-1a-proposal
agent/priority-2-audit
agent/r-cmd-check-drmtmb-parity
codex/merge-gate-11-12-after-task
codex/morphometrics-tier1-rewrite
```

These are merged branches that should have been auto-deleted by
the `gh pr merge --delete-branch` flag, but accumulated because
`git worktree` had local refs to them at merge time (the local
branch delete fails when a worktree is still using it; the remote
branch delete should still succeed but evidently did not for a
subset).

**Suggested follow-up**: a tiny housekeeping PR that runs
`git push origin --delete <branch>` for the merged ones. Not
urgent; the branches are inert. Out of scope for this audit; a
future Claude housekeeping PR can handle it.

## Recommendations

1. **Codex's sweep PR** can open whenever ready; no coordination
   conflicts. The lane is clean.
2. **Claude housekeeping while Codex's sweep is in flight**:
   - tiny PR moving `tidyselect` out of `Suggests:` (pre-existing
     NOTE);
   - tiny PR codifying the "tail -5 rendered Rd post-document()"
     lesson into `docs/design/10-after-task-protocol.md`;
   - optional: branch-cleanup PR for the accumulated origin
     branches noted above.
   These can be bundled into one or kept separate. Each is
   low-risk, doc/config-only, no overlap with Codex's sweep.
3. **Phase 1a row 2 (`covariance-correlation.Rmd`)** remains
   waiting on Codex's sweep to land. No premature dispatch.
4. **Issue #34** (parser-sugar) is parked. Maintainer-only to
   resume.

## Closing

The morning's high-tempo flow (5 merges + 1 issue + an active
Codex branch, all within ~4 hours) did not produce a Shannon
violation. The agent-to-agent review caught a real defect
(PR #33). The discipline recorded by PR #22 is what makes the
state legible.

Next audit trigger: post-sweep, before Phase 1a row 2 dispatch.
