# After-Task: Translate Codex's legacy-excavation map into a dispatch queue

## Goal

Codex posted a read-only "legacy excavation -> co-opt / adapt /
archive" map as a comment on PR #35 (2026-05-12 ~10:56 MT). The
map was generated from a thorough comparison of the
`itchyshin/gllvmTMB-legacy` repo against the current cleaned
repo. Maintainer relayed it (~11:00 MT) and asked how to put it
into action.

This PR provides the Claude-lane translation: a sequenced
dispatch queue with role assignments, prerequisites, and bounded
deliverables. Read-only audit; no source change. Adds one new
file in `docs/dev-log/shannon-audits/` and this after-task
report.

After-task report at branch start per `CONTRIBUTING.md`.

## Implemented

- **`docs/dev-log/shannon-audits/2026-05-12-legacy-coopt-dispatch-queue.md`**
  (NEW). Sections:
  - Verdict (agree with Codex's WARN; legacy port must not mix
    into the long/wide sweep branch).
  - Already co-opted (canonical list of what the current repo
    has byte-identical from legacy).
  - Dispatch queue (#1 phylo / two-U doc-validation branch with
    full role allocation; #2 reference article salvage; #3
    long/wide wording mine; #4 Curie identifiability sim).
  - What stays archived (single-response sdmTMB code, PIC-MOM,
    legacy Tier-3 essays).
  - Suggested overall sequence.
  - Shannon checklist (state at audit time).
- **`docs/dev-log/after-task/2026-05-12-legacy-coopt-dispatch-queue.md`**
  (NEW, this file).

The PR does NOT:
- Modify any R source, Rd, vignette, or test file.
- Start the phylo / two-U port (that needs the sweep to merge or
  park first, plus a maintainer dispatch).
- Modify `decisions.md` to ratify the archive list (separate
  small PR after the maintainer reviews this dispatch queue).

## Mathematical Contract

No public R API, likelihood, formula grammar, family, NAMESPACE,
generated Rd, vignette, or pkgdown navigation change. Two new
markdown files under `docs/dev-log/`.

## Files Changed

- `docs/dev-log/shannon-audits/2026-05-12-legacy-coopt-dispatch-queue.md`
  (new)
- `docs/dev-log/after-task/2026-05-12-legacy-coopt-dispatch-queue.md`
  (new, this file)

## Checks Run

- **Pre-edit lane check**: 0 open PRs at branch start. No Codex
  push pending on `docs/dev-log/`. Safe.
- **Codex source verification**: PR #35 comment fetched via
  `gh api repos/.../issues/35/comments` to confirm the map text
  and to cite specific legacy / current files (e.g.,
  `R/fit-multi.R:335`, `dev/sim-two-U-identifiability.R`).
- **Codex's "do not mix lanes" rule**: cross-checked against
  `AGENTS.md` collaboration-stops list (broad article rewrites
  require explicit maintainer dispatch). Codex's WARN is exactly
  this rule in action.

## Tests Of The Tests

This is a planning / coordination doc, not behavioural code. The
implicit "test" is the next dispatch: when the maintainer
approves item #1 (phylogenetic / two-U doc-validation branch),
the Codex implementation PR should land cleanly because the
prerequisite (sweep merge or park) is already named, the role
allocation is already named, and the bounded deliverable list is
explicit.

If a Codex implementation PR strays beyond the bounded
deliverable (e.g., starts reviving single-response sdmTMB code
not on the archive list), the dispatch queue is the reference
that catches the drift.

## Consistency Audit

```sh
rg -n "two-U|two_U|phylo_diag|q_sp|extract-two-U-cross-check" R/ tests/ docs/
```

verdict: confirmed Codex's claim that the two-U core is already
in the current repo (`R/fit-multi.R`,
`R/extract-two-U-cross-check.R`,
`tests/testthat/test-phylo-two-U.R`,
`tests/testthat/test-two-U-cross-check.R`). The dispatch queue's
"Already co-opted" list is accurate.

```sh
ls /Users/z3437171/Dropbox/Github\ Local/gllvmTMB-legacy/vignettes/articles/ 2>/dev/null
```

(not run as part of this audit; the legacy article list is taken
from Codex's map text directly. A follow-up audit could verify
each legacy file path exists.)

```sh
rg -n "phylo_latent + phylo_unique|Lambda_phy|S_phy" docs/
```

verdict: the canonical two-U algebra is already documented in
`AGENTS.md` and `CLAUDE.md` (the 3 x 5 grid). The phylo doc lane
adapts the *article*, not the algebra.

## What Did Not Go Smoothly

Nothing significant. Codex's map was clear and concrete; this
translation was mostly reformatting from "Codex's bullet list of
findings" into "Claude's sequenced queue with role assignments
and prerequisites." Took ~30 min of read + write.

The most interesting decision: where to file Codex's "Leave
archived" list. I chose to summarise it in this dispatch-queue
doc AND propose a separate small follow-up PR to ratify it as a
`decisions.md` entry. That keeps the archive verdict durable
(decisions.md is the canonical record) without bloating this
audit doc.

## Team Learning

By standing-review role per `AGENTS.md`:

- **Shannon (cross-team coordination)** -- the agent-to-agent
  handoff worked exactly as designed: Codex's map landed on PR
  #35 (the most recent merged Shannon PR), I noticed it, fetched
  it, and translated. The PR-comment-as-handoff venue is the
  right shape; not an issue, not a new PR, not a new branch --
  just a durable comment on the relevant prior audit.
- **Ada (orchestrator)** -- this dispatch queue exists so the
  maintainer can pick the next bounded task without re-reading
  Codex's map AND making the sequencing/role decisions in real
  time. That's the orchestrator's job, but a written queue makes
  the decision repeatable.
- **Rose (cross-file consistency)** -- the verification that the
  current repo already has the two-U core byte-identical (per
  Codex's claim) is a Rose-style cross-file check. The current
  audit confirms Codex's findings rather than re-doing them.

## Known Limitations

- The dispatch queue's prerequisite chain (sweep merges or parks
  before any legacy port begins) is enforced by document, not by
  CI. If a future PR violates the rule (e.g., starts a legacy
  port while sweep is still open), there is no machine-readable
  blocker. The Shannon audit pattern is the soft enforcement
  layer.
- Items #2 (Tier-2 article salvage) and #3 (wording mine) are
  Claude-lane and could overlap each other in time; the audit
  recommends doing #2's audit first and #3 after, but the
  separation is partly stylistic.
- The "leave archived" list assumes the maintainer is happy with
  the current scope decisions. If they want to revisit any of
  those (e.g., re-export single-response sdmTMB code) that
  changes the package scope and is a maintainer-level decision,
  not Codex or Claude's call.

## Next Actions

1. Maintainer reviews this dispatch queue. Expected ratification
   path: a single chat reply ("yes to the queue; #1 next when
   sweep merges; archive list goes into `decisions.md`").
2. After approval: self-merge this PR.
3. After Codex's sweep merges: maintainer dispatches Codex to
   item #1 (phylogenetic / two-U doc-validation branch) and
   Claude to item #2's first deliverable (Tier-2 article-salvage
   audit doc).
4. A separate small Claude PR ratifies the archive list as a
   `decisions.md` entry.
