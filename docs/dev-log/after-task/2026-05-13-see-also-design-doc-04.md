# After-Task: Add "see also" pointers to design doc 04 from CLAUDE.md and AGENTS.md

## Goal

Light-touch addition of a pointer from CLAUDE.md and AGENTS.md to
`docs/design/04-sister-package-scope.md` (added in PR #48). The
rule files currently enumerate the TMB-family sister packages
(`drmTMB`, `glmmTMB`, `sdmTMB`) in their scope sections, but do
not mention `gllvm` (Niku et al.), `MCMCglmm`, or `brms`. The
full cross-package scope record lives in design doc 04; the rule
files now point at it so future agents discover the broader
record without forcing all of it into the rule files.

The need for this pointer was noted in PR #54's
"What Did Not Go Smoothly" section
(`docs/dev-log/after-task/2026-05-12-copyrights-stale-path.md`)
during the overnight cross-package coherence sweep.

After-task report at branch start per `CONTRIBUTING.md`.

## Implemented

- **`CLAUDE.md`** (M, 5 lines added after the "Project Identity"
  paragraph): pointer sentence
  "For the full cross-package scope record (including `gllvm`,
  `MCMCglmm`, `brms`, the decision matrix, and the
  'what gllvmTMB does NOT do' section), see
  [`docs/design/04-sister-package-scope.md`](docs/design/04-sister-package-scope.md)."
- **`AGENTS.md`** (M, 3 lines added to the existing
  single-response-routing bullet): same pointer sentence in
  bullet form, without the markdown link target (AGENTS.md
  uses plain prose, not rendered markdown).
- **`docs/dev-log/after-task/2026-05-13-see-also-design-doc-04.md`**
  (NEW, this file).

The PR does NOT:

- Change any scope rule. The TMB-family routing rule ("single-
  response models in `glmmTMB`; spatial single-response in
  `sdmTMB`") is unchanged. The pointer only references the
  broader record that already exists.
- Restructure the rule files. The pointer is added as a
  continuation sentence at the existing routing rule.

## Mathematical Contract

No public R API, likelihood, formula grammar, family, NAMESPACE,
generated Rd, vignette, or pkgdown navigation change. Two
rule-file pointer additions and an after-task report.

## Files Changed

- `CLAUDE.md` (M, 5 lines)
- `AGENTS.md` (M, 3 lines)
- `docs/dev-log/after-task/2026-05-13-see-also-design-doc-04.md`
  (new, this file)

## Checks Run

- Pre-edit lane check: 1 open Claude PR (#55 Rose article-sweep,
  awaiting maintainer); zero Codex PRs visible on remote. The
  Rose sweep does not touch CLAUDE.md or AGENTS.md. Safe.
- Target file existence: `docs/design/04-sister-package-scope.md`
  exists on `origin/main` (added in PR #48). The pointer
  resolves.
- Pointer wording cross-check: each location names the same
  three additions (`gllvm`, `MCMCglmm`, `brms`, the decision
  matrix, the "what gllvmTMB does NOT do" section) so the two
  pointers stay in sync.

## Tests Of The Tests

This is a documentation pointer addition. The "test" is whether
a future agent reading CLAUDE.md or AGENTS.md and noticing the
TMB-family routing rule can follow the pointer to discover the
broader scope record. After this PR, the pointer is in place
in both files; agents who read either file see the link.

If design doc 04 is ever renamed or moved, both pointers need
to update in the same PR. (Same single-renaming risk applies
to the README's `## Sister packages` section, which already
links to design doc 04 since PR #48.)

## Consistency Audit

```sh
rg -n '04-sister-package-scope.md' CLAUDE.md AGENTS.md README.md
```

verdict: three locations name the design doc by filename:
README.md (added in PR #48), CLAUDE.md (this PR), AGENTS.md
(this PR). Each pointer follows the same "see also" pattern.

```sh
rg -n 'gllvm |MCMCglmm|brms' CLAUDE.md AGENTS.md
```

verdict: the rule files still do not enumerate `gllvm` /
`MCMCglmm` / `brms` as TMB-family routing destinations (those
are not TMB-family packages); the pointer is the only mention.
This matches the intended rule-file/design-doc split.

## What Did Not Go Smoothly

Nothing. Two small text-block additions; design doc 04 already
exists as the link target.

The hardest decision was whether to also update CONTRIBUTING.md.
The file mentions `glmmTMB` and `sdmTMB` in its single-response-
boundary statement (line 43-44) but does not enumerate the
sister packages with the depth that CLAUDE.md and AGENTS.md
do. Adding the pointer to CONTRIBUTING.md would feel grafted;
CONTRIBUTING.md's audience is contributors writing patches, not
agents reading scope rules. The pointer was therefore not added
to CONTRIBUTING.md. If a future contributor needs the broader
record, the README link gets them there in one click.

## Team Learning

By standing-review role per `AGENTS.md`:

- **Jason (landscape / source-map scout)** -- the cross-package
  scope record was Jason's lane in design doc 04; this PR adds
  the pointer that lets future Jasons find it from the rule
  files.
- **Ada (orchestrator)** -- two-file pointer addition, no
  scope-rule change. Bounded.
- **Rose (cross-file consistency)** -- README, CLAUDE.md, and
  AGENTS.md now all reference design doc 04 by filename;
  pointer wording is consistent across the three.

## Known Limitations

- The pointer wording explicitly names three packages
  (`gllvm`, `MCMCglmm`, `brms`) as part of "the broader scope
  record". If design doc 04 ever drops or adds a package, the
  pointer wording in both rule files would need a one-line
  update to stay accurate. Not urgent.
- CONTRIBUTING.md is intentionally NOT updated (see above).
  If contributors start asking "which package should I use for
  X?", the right fix is the README link, not a CONTRIBUTING.md
  expansion.

## Next Actions

1. Maintainer reviews / merges. Self-merge eligible per
   `docs/dev-log/decisions.md`: light-touch rule-file edit
   adding a pointer to existing design doc; no scope-rule
   change.
2. After merge, the rule-file pointer is in place; design doc
   04 remains the durable canonical record for the broader
   sister-package surface.
