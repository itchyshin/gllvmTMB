# After-Task: Refresh project-local skills for today's codified rules

## Goal

Today's session codified several rules and conventions that
project-local `.agents/skills/*/SKILL.md` files don't yet
reflect:

- drmTMB-style after-task patterns (PR #24): Mathematical
  Contract section, classified Consistency Audit verdicts,
  Tests-of-the-Tests "what would catch", Team Learning by role.
- Rendered-Rd spot-check protocol (PR #36): `tail -5
  man/<changed>.Rd` after `devtools::document()`.
- U vs S/s notation convention (PR #40): math always uses
  S/s; "two-U" is a task label only.
- Two-shape data framing (PR #32 + PR #39's Option B + sugar
  pivot): public-facing description is long + wide, not three
  entry points.
- Multi-agent collaboration rules (PR #22): pre-edit lane
  check, after-task at branch start, merge-authority rule,
  surface review asks explicitly, agent-to-agent handoffs in
  the repo.

This PR refreshes four skills with targeted additions so the
skill text matches the codified rules. Source skill files
referenced from running agents are kept callable; nothing in
this PR is breaking.

After-task report added at branch start per `CONTRIBUTING.md`.

## Implemented

- **`.agents/skills/after-task-audit/SKILL.md`** (M):
  - New "Canonical Reference" section at the top pointing at
    `docs/design/10-after-task-protocol.md` as the stable
    design note, listing the four drmTMB-style patterns and the
    Rendered-Rd spot-check as the canonical content owned by
    the design doc.
  - Step 7 of the Required Audit now includes the Rendered-Rd
    spot-check (`tail -5 man/<changed>.Rd` + `grep -c
    '^\\keyword' man/<changed>.Rd`) right next to the
    `devtools::document()` invocation.
- **`.agents/skills/prose-style-review/SKILL.md`** (M):
  - Item 7 (stable terms) now includes the U-vs-S notation
    convention: math uses `S` / `s`; "two-U" is a task label /
    function nickname only.
  - New item 8: two-shape data framing per Option B + sugar.
    Tier-1 and user-facing prose describes two shapes, not
    three. `traits()` LHS is a documented parser path, not a
    third recommended user-facing shape.
- **`.agents/skills/rose-pre-publish-audit/SKILL.md`** (M):
  - Check 7 (stale terminology) now explicitly names two
    drift patterns to flag: `diag(U)` / `U_phy` / `U_non` as
    math notation, and "three entry points" / "three shapes"
    user-facing framing.
- **`.agents/skills/shannon-coordination-audit/SKILL.md`** (M):
  - Check 6 (Rule drift) now enumerates six concrete rules to
    compare against: WIP limit, CI pacing, pre-edit lane
    check, after-task at branch start, merge authority, and
    agent-to-agent handoffs in the repo.
- **`docs/dev-log/after-task/2026-05-12-skills-refresh.md`**
  (NEW, this file).

The PR does NOT:
- Touch `add-family`, `add-simulation-test`,
  `article-tier-audit`, `tmb-likelihood-review`. Those were
  spot-checked and have no drift against today's codified
  rules.
- Restructure any skill. The edits are surgical
  additions/clarifications inside existing sections.
- Modify `docs/design/10-after-task-protocol.md` or any other
  authoritative source-of-truth doc. The skills point at those
  docs; the docs are the canonical record.

## Mathematical Contract

No public R API, likelihood, formula grammar, family, NAMESPACE,
generated Rd, vignette, or pkgdown navigation change. Skill-file
prose updates only.

## Files Changed

- `.agents/skills/after-task-audit/SKILL.md`
- `.agents/skills/prose-style-review/SKILL.md`
- `.agents/skills/rose-pre-publish-audit/SKILL.md`
- `.agents/skills/shannon-coordination-audit/SKILL.md`
- `docs/dev-log/after-task/2026-05-12-skills-refresh.md` (new)

## Checks Run

- Pre-edit lane check: 0 open PRs at branch start (PR #43 and
  #44 just merged). No Codex push pending on
  `.agents/skills/`. Safe.
- **Drift detection methodology**: read each skill front-to-back,
  cross-reference against today's `decisions.md` entries (Option
  B+sugar, Path A citations, archive list, naming convention) +
  the design docs (`10-after-task-protocol.md` post-PR-#24 + PR
  #36, `11-task-allocation.md`, `02-data-shape-and-weights.md`).
  Flagged items go into one of three buckets:
  - Already present in skill text -> no edit
  - Missing but trivially addable inside existing structure -> edit
  - Missing and would require new section -> defer (none today)
- Skill files that have NO drift: `add-family`,
  `add-simulation-test`, `article-tier-audit`,
  `tmb-likelihood-review`. These are about adding new families /
  simulation tests / tier audits / likelihood reviews; today's
  codified rules don't change those workflows.
- Skill files with drift (now patched): `after-task-audit`,
  `prose-style-review`, `rose-pre-publish-audit`,
  `shannon-coordination-audit`.

## Tests Of The Tests

This is a doc/skill update. The "test" is whether a future Codex
or Claude session that invokes one of these skills picks up the
new content. Specifically:

- The next session invoking `after-task-audit` should see the
  Rendered-Rd spot-check in step 7 and run it post-`document()`.
- The next session invoking `prose-style-review` should treat
  `diag(U)` in roxygen as drift to flag.
- The next session invoking `rose-pre-publish-audit` should grep
  for `diag(U)` / `three entry points` as stale-terminology
  signals.
- The next session invoking `shannon-coordination-audit` should
  compare current practice against the six enumerated rules in
  check 6.

If the patched skill is invoked and one of these expectations
fails (e.g., the agent still ships `diag(U)` math without the
session flagging it), the skill edit didn't take. That's a
process bug, not a content bug.

## Consistency Audit

```sh
rg -n "diag\\(U\\)|U_phy|U_non" .agents/skills/
```

verdict: `prose-style-review` and `rose-pre-publish-audit` now
both name `diag(U)` as a drift pattern. The names appear
exactly where they should (inside the stable-terms / stale-
terminology checks); no spillover into unrelated sections.

```sh
rg -n "two shapes|three entry points|three shapes" .agents/skills/
```

verdict: `prose-style-review` and `rose-pre-publish-audit` now
both reference "two shapes" framing. No skill claims "three
entry points" as canonical.

```sh
rg -n "tail -5|grep -c '\\^\\\\\\\\keyword'" .agents/skills/
```

verdict: `after-task-audit` step 7 has the rendered-Rd spot-check
invocation literally. The pattern is reproducible.

```sh
rg -n "pre-edit lane check|after-task at branch start|merge authority|surface review asks|agent-to-agent handoffs" .agents/skills/
```

verdict: `shannon-coordination-audit` check 6 names all five
PR-#22 rules. The rule list in the audit skill is the
operational counterpart of the AGENTS.md / CLAUDE.md /
CONTRIBUTING.md rule text.

## What Did Not Go Smoothly

Nothing. Four small edits, each inside an existing section, all
mechanical. The hardest part was deciding what NOT to add (the
methods-paper outline, the cross-package coherence doc) so the
skill text stays focused on what it owns.

## Team Learning

By standing-review role per `AGENTS.md`:

- **Ada (orchestrator)** -- the skill refresh is the kind of
  maintenance pass that gets forgotten. Today's session codified
  six rules; without this PR, the skill text drifts behind for
  weeks until someone audits.
- **Rose (cross-file consistency)** -- the refresh keeps the
  `.agents/skills/*` text in agreement with `decisions.md` and
  the design docs. Skill text is documentation; documentation
  drifts; this is a Rose-style sweep.
- **Pat (applied user / new contributor)** -- a new contributor
  invoking `after-task-audit` after this PR sees the rendered-Rd
  spot-check in the operational checklist, not just the design
  doc. Lower friction.

## Known Limitations

- The audit is surgical, not comprehensive. Each skill has a
  bunch of historical content that wasn't touched; it may have
  unrelated drift that this audit didn't surface. A future
  comprehensive skill-refresh PR could rewrite each skill from
  scratch against the current rule corpus; this PR doesn't.
- The skills that I judged as having NO drift (`add-family`,
  `add-simulation-test`, `article-tier-audit`,
  `tmb-likelihood-review`) may have small drifts I missed.
  Each spot-check was ~5 minutes; a deeper audit could find
  more.
- The plan file at `~/.claude/plans/please-have-a-robust-elephant.md`
  is updated separately (private to Claude's session; not part
  of this PR).

## Next Actions

1. Maintainer reviews / merges. Self-merge eligible: skill text
   updates + after-task; no source / R / NAMESPACE / Rd /
   vignette change.
2. After merge, the next session that invokes any of the four
   patched skills will pick up the new content. The next
   non-trivial audit run (post-merge of Codex's item #1 phylo
   doc-validation PR) is the natural validation.
