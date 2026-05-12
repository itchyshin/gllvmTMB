# After-Task: Ratify legacy archive scope into `decisions.md`

## Goal

Make Codex's "leave archived" verdict (from the 2026-05-12
legacy excavation map, posted as a PR #35 comment) durable in
`docs/dev-log/decisions.md` so the same scope-revisit
conversation does not need to happen on every future Codex /
Claude dispatch. The maintainer ratified the dispatch queue +
archive list 2026-05-12 ~11:30 MT in chat; this PR is the
record.

After-task report added at branch start per `CONTRIBUTING.md`.

## Implemented

- **`docs/dev-log/decisions.md`** (M): appended the
  "2026-05-12 -- Legacy gllvmTMB-legacy archive scope
  (ratified)" entry recording:
  - what stays archived (single-response sdmTMB code; legacy
    single-response tests; PIC-MOM as a public extractor path;
    legacy Tier-3 essays);
  - what is NOT archived (the four positive dispatch-queue
    items already in PR #37: phylo / two-U doc-validation,
    Tier-2 article salvage, Curie identifiability sim, low-cost
    wording mine);
  - the rationale (multivariate stacked-trait scope vs sister
    packages) and the revisit protocol (explicit maintainer
    decision recorded as an amendment).
- **`docs/dev-log/after-task/2026-05-12-archive-ratification.md`**
  (NEW, this file).

## Mathematical Contract

No public R API, likelihood, formula grammar, family, NAMESPACE,
generated Rd, vignette, or pkgdown navigation change. Append-only
decisions.md entry + after-task report.

## Files Changed

- `docs/dev-log/decisions.md`
- `docs/dev-log/after-task/2026-05-12-archive-ratification.md`
  (new)

## Checks Run

- Pre-edit lane check: 0 open PRs (PR #37 just merged; main at
  `4450e1b`). No Codex push pending on `decisions.md`. Safe.
- Cross-referenced the archive list against
  `docs/dev-log/shannon-audits/2026-05-12-legacy-coopt-dispatch-queue.md`
  (just merged) and the Codex map text (PR #35 comment) -- all
  three sources agree.

## Tests Of The Tests

No new test. The implicit test: when a future Codex / Claude
dispatch is about to start work that touches one of the
archived areas (e.g., a "should we add `R/visreg.R` back?"
question), the answer points at this `decisions.md` entry. If
the dispatcher does not consult `decisions.md` and re-litigates
the question, that is a process bug worth flagging.

## Consistency Audit

```sh
rg -n "single-response|sdmTMB inheritance|PIC-MOM|legacy Tier-3|Tier-2 reference article salvage" docs/dev-log/decisions.md docs/dev-log/shannon-audits/2026-05-12-legacy-coopt-dispatch-queue.md
```

verdict: all three terms appear consistently across the two
docs; no contradiction. The dispatch queue says "queue for
adapt-next" for the four positive items; `decisions.md` says
"stays archived" for the negative items. Together they form one
coherent scope record.

```sh
rg -n "compare_dep_vs_two_U|compare_indep_vs_two_U" R/ man/
```

verdict: `compare_dep_vs_two_U()` and `compare_indep_vs_two_U()`
both exist in `R/extract-two-U-cross-check.R` and have generated
Rd entries. Confirms the decisions.md claim that these are the
canonical user-facing two-U checks.

## What Did Not Go Smoothly

Nothing. Append-only entry, single section, no edits to existing
prose.

## Team Learning

By standing-review role per `AGENTS.md`:

- **Shannon (cross-team coordination)** -- the
  Codex-map -> Claude-dispatch-queue -> maintainer-ratify ->
  `decisions.md` record sequence is the canonical agent-to-agent
  pattern. Codex did the legacy excavation; Claude translated;
  maintainer ratified; decisions.md captures. Four steps,
  durable artefact.
- **Ada (orchestrator)** -- the archive line is a scope decision,
  not an implementation detail. Recording in `decisions.md`
  rather than in a code comment keeps the rationale findable.
- **Pat (applied user)** -- a future contributor who wonders why
  the public reference lacks DHARMa support has a one-page
  answer instead of a multi-thread chat archaeology task.

## Known Limitations

- The archive list is not enforced by code or CI. It is a
  documentation discipline. Future Codex / Claude dispatches
  could violate it without machine-readable blockers. The
  Shannon audit pattern is the soft enforcement layer; if a PR
  starts reviving an archived item, the next Shannon audit
  should catch it.
- The rationale ("scope vs sister packages") may be revisited
  if a maintainer decides to broaden the package scope. That
  would be a maintainer-level decision and would need an
  amendment to this `decisions.md` entry.
- The dispatch queue's positive items (phylo / two-U doc lane,
  Tier-2 salvage, identifiability sim, wording mine) are NOT
  ratified by this PR -- only the negative archive list. The
  positive items are queued in PR #37 and trigger on the
  prerequisites named there (sweep merges or parks first).

## Next Actions

1. Maintainer reviews / merges. Self-merge eligible: append-only
   `decisions.md` entry + after-task report, no source change.
2. After merge, the queue from PR #37 + the archive line from
   this PR together form the complete scope record. Future
   dispatches consult both before starting work in any
   adjacent territory.
3. Standing by for Codex's reader-facing sweep PR. After it
   merges or is parked, the maintainer dispatches Codex to
   queue item #1 (phylo / two-U doc-validation branch) and
   Claude to queue item #2's audit deliverable in parallel.
