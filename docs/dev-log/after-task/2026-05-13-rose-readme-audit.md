# After-Task: Rose README + pkgdown front-page audit

## Goal

Maintainer flagged 2026-05-13 ~04:25 MT that the live pkgdown
front page (rendered from `README.md`) is hard for a new user
to read. Specifically:

- Abbreviations stacked without unpacking (jargon-heavy opener).
- Long vs wide format differentiation unclear.
- The page does not communicate why a user would reach for
  `gllvmTMB`.
- "Rose -- she sees one mistake like this and she can find a
  lot more": the audit should chase the drift across the
  cross-doc surface, not stop at the one flagged page.

The Pat audit (PR #62) covered `vignettes/articles/*.Rmd` but
skipped the README. This Rose audit fills that gap.

After-task report at branch start per `CONTRIBUTING.md`.

## Implemented

- **`docs/dev-log/shannon-audits/2026-05-13-rose-readme-and-front-page-audit.md`**
  (NEW): the audit doc. Six sections:
  - **A**: README friction (10 findings, top-down through the file).
  - **B**: cross-doc terminology drift (8 findings about
    `stacked-trait`, `communality`, `phylogenetic signal`,
    `ordination`, the `simulate_site_trait` smoke-test mismatch,
    `tier` vs `level`, `Sigma`/Σ notation mixing,
    singular/plural drift).
  - **C**: cross-doc inventory of opening paragraphs (Pat
    sees four different "what is gllvmTMB for" framings).
  - **D**: 7 recommended remediations, each with concrete
    suggested wording where applicable.
  - **E**: confidence and scope.
  - **F**: priority-ordered action items.
- **`docs/dev-log/after-task/2026-05-13-rose-readme-audit.md`**
  (NEW, this file).

The audit deliberately does NOT apply any fix. It is a Phase 5
prep audit; rewrites belong in follow-up PRs (each fix has a
distinct fix-shape and risk profile).

## Mathematical Contract

No public R API, likelihood, formula grammar, family, NAMESPACE,
generated Rd, vignette, or pkgdown navigation change. Two new
markdown files under `docs/dev-log/`.

## Files Changed

- `docs/dev-log/shannon-audits/2026-05-13-rose-readme-and-front-page-audit.md`
  (new)
- `docs/dev-log/after-task/2026-05-13-rose-readme-audit.md`
  (new, this file)

## Checks Run

- Pre-edit lane check: open Claude PRs (#62 Pat audit, #63
  WORDLIST) + Codex PR #61 covariance-correlation. None
  touches `README.md` or `docs/dev-log/`. Safe.
- `stacked-trait` occurrence count via
  `rg -n 'stacked-trait' README.md`: 4 uses in README, never
  defined.
- `communality` occurrence count via
  `rg -n 'communality' README.md vignettes/articles/`: 4 uses
  in README, definition deferred to articles.
- Cross-doc opener inventory: read the first 30 lines of
  `README.md`, `choose-your-model.Rmd`, `morphometrics.Rmd`,
  `phylogenetic-gllvm.Rmd`. Compared first-sentence claims;
  found 4 different "what is gllvmTMB for" framings.
- Two-shapes / three-paths contradiction: README says "either
  long or wide" at L9 and again at L185, but shows three
  named paths at L13-28 and L186-188. Same drift in 2 places.

## Tests Of The Tests

This is a Phase 5 prep audit. The "test" is whether a new applied
user reading the live pkgdown index page can:

1. Understand what `gllvmTMB` does from the first paragraph.
   (Currently fails: opener is 4 jargon terms in one sentence,
   no concrete example.)
2. Pick the right data shape (long / wide-data-frame /
   wide-matrix) without confusion.
   (Currently fails: "two paths" then three code blocks; no
   guidance on which to pick.)
3. Find the section answering "does it handle my problem?".
   (Currently buried at L128; user wades through six other
   sections first.)
4. Read "communality", "phylogenetic signal", "stacked-trait"
   without losing the thread.
   (Currently fails for "stacked-trait" — never defined.)

After remediation (per audit Section D), each of these tests
should pass.

## Consistency Audit

```sh
rg -n 'stacked-trait' README.md
```

verdict: 4 hits, no definition sentence. Audit B1.

```sh
rg -n 'either long or wide|two paths|three' README.md
```

verdict: 2 hits of "either long or wide" framing, plus two
sections (L13-28, L186-188) listing three code paths. Audit A2
+ A9.

```sh
for f in README.md vignettes/articles/choose-your-model.Rmd \
         vignettes/articles/morphometrics.Rmd \
         vignettes/articles/phylogenetic-gllvm.Rmd; do
  head -30 "$f" | grep -E '^([A-Z]|\\`)'
done
```

verdict: 4 different opener framings (jargon-stack /
selling-sentence / concrete-biology / question-driven). Audit
Section C.

## What Did Not Go Smoothly

Nothing substantive. The audit was bounded by design: read the
README cold, walk the cross-doc surface for the same class of
drift, propose remediations.

The hardest decision was scope: the audit could have included
`vignettes/gllvmTMB.Rmd` (Get Started vignette) and the
rendered pkgdown HTML output. I held both out of scope to keep
the audit focused on the maintainer's specific question (the
front-page friction). A follow-up audit can cover those.

The Pat audit (PR #62) and this Rose audit overlap on a few
findings (broken article links in choose-your-model; F1 / F2
in choose-your-model). The Rose audit references them rather
than re-stating, so the two audits are complementary, not
redundant.

## Team Learning

By standing-review role per `AGENTS.md`:

- **Rose (cross-file consistency)** -- this is the canonical
  Rose audit: one mistake flagged, many more in the same class
  surfaced. Audit Sections A and B together enumerate 18
  findings of three classes (jargon drift, framing drift,
  notation drift).
- **Pat (applied user)** -- the audit reads the front page as
  Pat would and surfaces the friction at the first sentence,
  not after a deep walk.
- **Grace (release readiness)** -- the README is the page CRAN
  reviewers and new users see first. A Phase 5 pre-flight
  rewrite here is high-leverage relative to its small file
  footprint.
- **Ada (orchestrator)** -- the audit deliberately does not
  apply fixes. Each recommendation has a distinct fix-shape
  and the maintainer should rule on D3 (two-shapes vs
  three-paths framing) before any rewrite lands.

## Known Limitations

- The audit reads the on-disk `.Rmd` / `.md` source, not the
  rendered pkgdown HTML. Rendered HTML may have additional
  friction (anchor links, syntax highlighting) that the
  source does not show.
- The audit does not include `vignettes/gllvmTMB.Rmd` (Get
  Started vignette). That file deserves the same opener-
  framing audit; deferred.
- `covariance-correlation.Rmd` (Codex PR #61 in flight) is
  referenced from the README and from Pat audit findings;
  this audit defers its content audit.
- The recommended D1 README opener is a SUGGESTION, not a
  ratified rewrite. Maintainer reviews / edits before any
  implementation PR applies it.

## Next Actions

1. Maintainer reviews / merges the audit. Self-merge eligible:
   audit doc + after-task report under `docs/dev-log/`, no
   source / API / NAMESPACE change.
2. Maintainer rules on D3 (two-shapes vs three-paths framing)
   so the remediation PRs have a consistent target.
3. Maintainer ratifies / edits the D1 opener suggestion.
4. Implementation PRs land in priority order (D1 → D2 → D4 →
   D3 → ...); one focused PR per remediation to keep diff
   sizes small.
5. Follow-up audit: read `vignettes/gllvmTMB.Rmd` with the
   same lens once the README rewrite has landed and the
   Get Started vignette can be aligned to it.
