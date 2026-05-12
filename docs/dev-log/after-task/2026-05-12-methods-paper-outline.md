# After-Task: Methods-paper outline draft (Phase 6 prep)

## Goal

Sketch the structural outline of the eventual gllvmTMB methods
paper (JSS / MEE / similar venue) so the maintainer has a
concrete artefact to revise rather than a blank page. Phase 6
per `ROADMAP.md` is months away; this is read-ahead preparation
that costs little to produce now and is high-friction if left
until the submission window.

The outline is structural -- section headings, bullet-point
expected content, target word counts, and open questions for
the maintainer -- not draft prose. Prose drafting follows
ratification.

After-task report added at branch start per `CONTRIBUTING.md`.

## Implemented

- **`docs/dev-log/methods-paper/outline.md`** (NEW, ~250 lines):
  full paper outline.
  - Title candidates (3 options)
  - Abstract sketch (~200 word target)
  - Section 1 Introduction (~3-4 pages: gap, related software
    referencing the new `docs/design/04-sister-package-scope.md`,
    what this paper adds)
  - Section 2 Methods (~10-12 pages: stacked-trait model in
    mathematical notation with S/s notation per PR #40, the
    3 x 5 keyword grid, two data shapes, inference, phylogenetic
    representation, spatial representation, mixed-family fits)
  - Section 3 Simulation studies (~4-5 pages: four canonical use
    cases with the 5-row alignment table)
  - Section 4 Applied examples (~4-5 pages: condensed Tier-1
    examples)
  - Section 5 Comparator validation (~2-3 pages: gllvmTMB vs
    gllvm / glmmTMB / MCMCglmm)
  - Section 6 Discussion (strengths, limitations, software dev
    practice)
  - Section 7 Code availability
  - Section 8 Acknowledgements (TMB / sdmTMB / gllvm / MCMCglmm
    / brms communities + maintainer's lab + funding TBD)
  - Section 9 Author contributions (CRediT)
  - Section 10 References (core citations identified)
  - Open questions for maintainer (7 items: first author /
    co-authors, target venue, simulation scope, dataset choice,
    comparator depth, timeline, CRAN-vs-paper sequencing)
  - "What this outline is NOT" scope guard
- **`docs/dev-log/after-task/2026-05-12-methods-paper-outline.md`**
  (NEW, this file).

The outline lives under `docs/dev-log/methods-paper/` (new
sub-directory) rather than `docs/design/` because it is
preparation for an external artefact (the published paper), not
an internal design decision. Future paper-adjacent files (figure
scripts, simulation outputs, draft sections) can also live under
`docs/dev-log/methods-paper/`.

## Mathematical Contract

No public R API, likelihood, formula grammar, family, NAMESPACE,
generated Rd, vignette, or pkgdown navigation change. One new
markdown file in a new dev-log sub-directory.

The outline itself uses `S` / `s` notation throughout the
mathematical sections (per `decisions.md` 2026-05-12 naming
convention). The model equations in section 2.1 write
`Sigma_phy = Lambda_phy Lambda_phy^T + diag(s_phy)` etc., not
`diag(U_phy)`. When prose drafting starts, this convention
should hold throughout.

## Files Changed

- `docs/dev-log/methods-paper/outline.md` (new)
- `docs/dev-log/after-task/2026-05-12-methods-paper-outline.md`
  (new, this file)

## Checks Run

- Pre-edit lane check: 2 open PRs at branch start (#47 Claude
  skills refresh; #48 Claude docs wording bundle). Neither
  touches `docs/dev-log/methods-paper/` (new dir) or the
  outline. Safe.
- Notation consistency: every mathematical expression in the
  outline uses `S` / `s` for the unique-variance diagonal, per
  PR #40 naming convention. Spot-check verified.
- Source-of-truth alignment: each section's content references
  existing repo artefacts (`decisions.md`, `AGENTS.md`,
  `docs/design/02-data-shape-and-weights.md`,
  `docs/design/04-sister-package-scope.md`, the Tier-1
  articles). The outline doesn't introduce new claims.

## Tests Of The Tests

This is a draft outline; the "test" is whether the maintainer
revises the structure (showing the outline is useful enough to
engage with) or rejects it as wrong-shape (showing the outline
needed a different approach).

The outline is rebuttal-friendly: each section has a target word
count, expected content as bullets, and (where applicable)
specific open questions for the maintainer to answer. If the
maintainer's revision diverges substantially from the proposed
structure, the diff between this outline and their version is
the evidence about what's actually wanted.

## Consistency Audit

```sh
rg -n "Sigma_phy|Lambda_phy|diag\\(s_phy\\)|diag\\(s_non\\)" docs/dev-log/methods-paper/outline.md
```

verdict: the outline uses `S` / `s` notation consistently. No
`diag(U_phy)` or `U_non` appears in math.

```sh
rg -n "gllvm |glmmTMB|sdmTMB|MCMCglmm|brms|drmTMB" docs/dev-log/methods-paper/outline.md
```

verdict: each sister package mentioned in
`docs/design/04-sister-package-scope.md` is also covered in the
outline's Related-Software section. Consistent.

```sh
rg -n "TBD|maintainer's call|open question" docs/dev-log/methods-paper/outline.md
```

verdict: the outline names every open decision explicitly
(author list, venue, dataset choice, simulation scope,
comparator depth, timeline, CRAN-vs-paper sequencing). No
covert assumptions about what the maintainer wants.

## What Did Not Go Smoothly

Nothing. The hardest decision was where to file the outline.
`docs/design/` would make it look like a design decision (the
paper structure is not a project decision); `docs/dev-log/`
keeps it as preparation material. A new sub-directory
`docs/dev-log/methods-paper/` lets future paper-adjacent files
(figure scripts, simulation outputs, draft sections) cluster
together without polluting the existing dev-log structure.

## Team Learning

By standing-review role per `AGENTS.md`:

- **Ada (orchestrator)** -- pre-stages the outline so the
  Phase 6 work doesn't start blank. A revised version of this
  outline becomes the next-step input for Pat / Darwin /
  Gauss / Noether / Fisher.
- **Jason (landscape / source-map scout)** -- the Introduction's
  Related-Software section reuses the cross-package coherence
  doc from PR #48 (gllvm / glmmTMB / sdmTMB / MCMCglmm / brms /
  drmTMB positions). The two documents stay aligned.
- **Pat (applied user)** -- the Applied-Examples section
  mirrors the Tier-1 articles in `vignettes/articles/`. When
  Pat / Darwin revise, they're revising the same structure
  that the public-facing articles already use.
- **Noether (math consistency)** -- the Methods section
  writes the full model in `S` / `s` notation. When prose
  drafting starts, Noether is the gatekeeper for the math
  staying consistent across the paper, the package, and the
  Tier-1 articles.
- **Fisher (statistical inference)** -- the Inference section
  (2.4) and the Simulation-Studies section (3) are Fisher's
  lanes. The simulation recovery uses the 5-row alignment
  table per the `add-simulation-test` skill.

## Known Limitations

- The outline is structural, not substantive. The actual
  difficulty of writing the paper is in the prose, the
  simulation studies, the comparator benchmarks, and the
  reproducibility deposit. None of that is in this PR.
- The "Related software" section reuses
  `docs/design/04-sister-package-scope.md` (PR #48); if that
  doc evolves, the outline's section 1.2 should be re-synced.
- The applied examples (section 4) reuse the Tier-1 articles;
  when the articles get revised (per the in-flight phylo
  doc-validation lane PR #37 item #1 + the Tier-2 ports per
  PR #41), the paper's section 4 needs a refresh.
- Author list, target venue, simulation scope, dataset
  selection, comparator depth, timeline, and CRAN-vs-paper
  sequencing are all explicit "open questions" left for the
  maintainer to answer.
- The acknowledgements are placeholder: real names of
  collaborators / funding sources / lab members are TBD.

## Next Actions

1. Maintainer reviews / merges the outline. Self-merge eligible:
   read-only draft + after-task in `docs/dev-log/`. No source
   change.
2. After merge, the maintainer answers the seven open questions
   in a follow-up chat session (or annotates them inline).
3. After the questions are answered, prose drafting can begin
   one section at a time. Pat / Darwin / Gauss / Noether /
   Fisher review per section.
4. Simulation studies (section 3) become a Codex implementation
   task: produce the four simulation scripts, run recovery,
   generate figures. Probably 2-3 weeks of focused work.
5. Applied examples (section 4) cross-reference the existing
   Tier-1 articles + the planned phylogenetic-gllvm article
   (per PR #37 item #1).
6. Comparator validation (section 5) is a separate Codex task:
   cross-check against `gllvm`, `glmmTMB`, `MCMCglmm`. Probably
   1-2 weeks of focused work.
7. References list grows continuously as prose is drafted.
8. Reproducibility deposit (Zenodo / OSF) at submission time.
