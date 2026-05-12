# After-Task: Documentation wording bundle (long/wide mine + sister-package scope)

## Goal

Two complementary documentation refinements bundled into one PR:

1. **Long/wide wording mine** -- PR #37 dispatch queue item #3.
   Mine the legacy `gllvmTMB-legacy/dev/design/08-wide-format-formula-api.md`
   ("Pat / Design 08") for one or two motivation sentences that
   improve the current `docs/design/02-data-shape-and-weights.md`
   "Goal" section. The legacy doc had a sharper "users arrive with
   wide-format data; doing the long-pivot by hand is error-prone
   and boilerplate-heavy" framing that the current doc didn't carry
   forward.
2. **Cross-package coherence reference** -- a new
   `docs/design/04-sister-package-scope.md` enumerating where
   `gllvmTMB` sits relative to `drmTMB`, `sdmTMB`, `glmmTMB`,
   `gllvm`, `MCMCglmm`, and `brms`. Includes one-line summaries,
   a decision matrix ("if your data is X, use Y"), an
   overlap-zone analysis for each sister package, and a "what
   gllvmTMB does NOT do" section to make scope decisions easy
   to find.

After-task report added at branch start per `CONTRIBUTING.md`.

## Implemented

- **`docs/design/02-data-shape-and-weights.md`** (M): "Goal"
  section gains a one-paragraph opening that mines the legacy
  Pat / Design 08 motivation: "Most ecological, evolutionary,
  behavioural, and morphometric datasets arrive in wide format
  -- one column per response trait. The user shouldn't have to
  long-pivot by hand and write `0 + trait + (0 + trait):x`
  boilerplate before they can fit a multivariate GLLVM."
  Also pulls in the brms / metafor / gllvm one-line comparators
  for context.
- **`docs/design/04-sister-package-scope.md`** (NEW, ~200
  lines): one-line summaries, decision matrix, "why pick
  gllvmTMB specifically" five-bullet identity, pairwise
  overlap-zone analyses (gllvmTMB vs glmmTMB / sdmTMB / gllvm /
  drmTMB / MCMCglmm / brms), "what gllvmTMB does NOT do" scope
  guard, and a See-also list pointing at decisions.md, design
  doc 02, README, and CLAUDE.md for the canonical scope record.
- **`README.md`** "Sister packages" (M): expanded the three-
  bullet list to a five-bullet list adding `gllvm` (Niku et al.)
  and the Bayesian alternatives (`MCMCglmm`, `brms`); appended
  a pointer to the new `docs/design/04-sister-package-scope.md`
  for the full scope comparison.
- **`docs/dev-log/after-task/2026-05-12-docs-wording-bundle.md`**
  (NEW, this file).

The PR does NOT:
- Modify any source / R / NAMESPACE / Rd / vignette / pkgdown
  navigation. Documentation prose only.
- Modify `_pkgdown.yml`. The new design doc lives under
  `docs/design/` which is already a top-level navigation entry
  (or accessible via the dev-log structure, depending on the
  pkgdown navbar).
- Change any scope decision. The new doc records the existing
  scope decisions in one place; it does not introduce new ones.

## Mathematical Contract

No public R API, likelihood, formula grammar, family, NAMESPACE,
generated Rd, vignette, or pkgdown navigation change. Three
prose updates and one new markdown file under `docs/design/`.

## Files Changed

- `docs/design/02-data-shape-and-weights.md` (M)
- `docs/design/04-sister-package-scope.md` (new)
- `README.md` (M)
- `docs/dev-log/after-task/2026-05-12-docs-wording-bundle.md`
  (new, this file)

## Checks Run

- Pre-edit lane check: 1 open PR (#47, Claude skills refresh on
  `.agents/skills/`; disjoint scope). Safe.
- Legacy mining source verified:
  `/Users/z3437171/Dropbox/Github Local/gllvmTMB-legacy/dev/design/08-wide-format-formula-api.md`
  is the legacy Pat / Design 08 doc. Its "Problem" section had
  the wide-format motivation phrasing that the current doc
  didn't carry forward (verified by reading both side-by-side).
- Sister-package scope cross-check: each pair (gllvmTMB vs each
  sister) was checked against the existing scope record in
  `CLAUDE.md`, `README.md`, and `docs/dev-log/decisions.md`.
  No new scope claims; the new doc consolidates what's already
  decided elsewhere.

## Tests Of The Tests

This is a documentation PR. The "tests" are:

1. A new user reading the README "Sister packages" section can
   click through to `docs/design/04-sister-package-scope.md` and
   find a clear answer to "which package should I install?"
2. A future maintainer scope-creep proposal (e.g., "should we
   add Bayesian inference?") runs into the "What gllvmTMB does
   NOT do" section first.
3. The Pat / Design 08 motivation that was lost in the bootstrap
   transition is now in the current design doc again, so a
   reader who lands on
   `docs/design/02-data-shape-and-weights.md` sees the wide-
   format-is-natural framing in the first paragraph.

If a future scope proposal slips past the "What gllvmTMB does
NOT do" section, the doc didn't do its job and needs
strengthening. If the README's new five-bullet sister-package
list gets stale (e.g., `gllvm` releases a major version with a
new API), the README and the design doc both need a sweep.

## Consistency Audit

```sh
rg -n "drmTMB|sdmTMB|glmmTMB|gllvm |MCMCglmm|brms" docs/design/04-sister-package-scope.md README.md CLAUDE.md AGENTS.md
```

verdict: every sister package named in `CLAUDE.md` is also
covered in the new design doc and in the README. No package is
named in one source but missing from another. The new doc adds
`MCMCglmm` and `brms` as Bayesian alternatives -- those weren't
previously enumerated in `CLAUDE.md` or `README.md`, but their
mention here doesn't conflict with anything.

```sh
rg -n "What gllvmTMB does NOT do|out of scope|scope-creep" docs/design/04-sister-package-scope.md docs/dev-log/decisions.md
```

verdict: the new doc has a "What gllvmTMB does NOT do" section
that mirrors the `decisions.md` 2026-05-12 archive entry. Both
say the same thing; one is the durable scope record, the other
is the user-facing positioning.

```sh
rg -n "wide format|long format|long-pivot|0 \\+ trait" docs/design/02-data-shape-and-weights.md
```

verdict: the new "Goal" paragraph uses the "wide format / long
format / long-pivot / 0 + trait boilerplate" terminology
consistently with the rest of the doc.

## What Did Not Go Smoothly

Nothing. Three small documentation edits, each inside an
existing structure or as a clean new file. The hardest part
was deciding what NOT to write in the cross-package doc -- the
temptation to enumerate every R package's positioning is
strong, but the bounded list of six (`drmTMB`, `sdmTMB`,
`glmmTMB`, `gllvm`, `MCMCglmm`, `brms`) is what users actually
deliberate over.

## Team Learning

By standing-review role per `AGENTS.md`:

- **Jason (landscape / source-map scout)** -- the
  cross-package coherence doc is exactly Jason's lane. The
  decision matrix and the per-package overlap analysis are
  Jason's framing of "what do related packages already do, and
  what should `gllvmTMB` learn or avoid?".
- **Pat (applied user / contributor)** -- the new decision
  matrix is the artifact a new applied user needs to choose
  the right tool. README's pointer makes the doc findable in
  one click.
- **Ada (orchestrator)** -- the cross-package doc records
  scope so future scope-creep proposals run into it first.
  Less re-litigation.
- **Rose (cross-file consistency)** -- the audit cross-
  checked the new doc against the existing scope record in
  `CLAUDE.md`, `README.md`, and `decisions.md`. No drift.

## Known Limitations

- The decision matrix may grow stale if any sister package
  changes scope (e.g., `gllvm` adds phylogenetic support, or
  `drmTMB` adds multivariate). The doc should be updated when
  that happens. Not urgent.
- The `MCMCglmm` and `brms` rows in the decision matrix are
  the most likely to drift (Bayesian R-package landscape moves
  faster than the TMB landscape). The recommendation "use the
  Bayesian packages when you need posterior samples" is stable;
  the specific function recommendations may need refreshing.
- The Pat / Design 08 mining lifted one paragraph. The legacy
  doc has other useful phrasings (about brms's `mvbind` vs
  `traits()`, about the `factor(trait, levels = ...)` gotcha)
  that could be lifted in future tutorial / pitfalls article
  ports; not in scope for this PR.

## Next Actions

1. Maintainer reviews / merges. Self-merge eligible:
   documentation prose updates + new design doc, no source
   change.
2. After merge, future tutorial article ports (per PR #41 Tier-
   2 queue) can reference the new design doc to motivate the
   wide vs long choice each article makes.
3. When Codex's item #1 phylo doc-validation PR opens (PR #37
   queue item #1), the cross-package doc is useful background:
   the new phylo article should reference how `gllvmTMB`'s
   phylo lane relates to `MCMCglmm` and `brms`'s phylo paths.
