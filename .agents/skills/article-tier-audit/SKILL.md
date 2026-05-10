---
name: article-tier-audit
description: Triage gllvmTMB pkgdown articles into tiers (1 = public worked example, 2 = technical reference, 3 = retire) and judge each against the 10 reader-first style rules. Use when adding, removing, or rewriting any vignette under `vignettes/` or `vignettes/articles/`.
---

# Article-tier audit

Use this skill whenever the article surface changes: a new article is
added, an existing article is rewritten, an existing article is moved
or retired. The skill is Pat's triage view (the applied PhD-student
user-tester) crossed with the reader-first style rules (rules 1-10
below).

## The default tier is 1

> **Every public article is Tier 1 by default. Tier 2 / Tier 3
> require explicit justification.**

The legacy package shipped 29 articles and the navbar showed all of
them. The 2026-05-10 audit found that ~10 of those served the
maintainers (validation studies, framework-extension previews,
internal benchmarks) and crowded out the worked-example articles
that served the reader landing from Google. The cure was cutting the
public surface to 7 Tier-1 worked examples plus the Get Started
vignette.

The default presumption is now reversed: a new article must justify
appearing in any tier other than 1. If you cannot answer "what
question does this article answer for a first-time reader?" in one
sentence, the article belongs in Tier 3 (retired) until you can.

## The three tiers

### Tier 1 -- public worked example (the default)

Serves a first-time reader who landed on this article from Google.
They have a data problem and want to decide (a) whether this model
fits, (b) how to write the code, (c) how to interpret the output.

The exemplar is `vignettes/articles/morphometrics.Rmd`. Lead with
the user's question, show working code within 30 lines, recover the
truth from the simulation in the same article, end with a
forward-link table.

Tier 1 articles appear in the pkgdown navbar's main "Articles"
dropdown.

### Tier 2 -- technical reference

Serves a reader who already knows what gllvmTMB is and needs to
look up the syntax for a specific keyword or families list. Format
is closer to a glossary than a worked example.

Tier 2 articles appear in the pkgdown navbar under a "Technical
reference" sub-dropdown, separated from the Tier-1 articles.

Justify Tier 2 over Tier 1 by writing a one-sentence reason in the
article's YAML front-matter `tier: 2 # ...reason...`.

### Tier 3 -- retire

Serves the maintainers, contributors, or reviewers, not the reader
landing from Google. Validation studies, internal benchmarks,
framework-extension previews, PLANNED-mode previews of unsupported
features.

Tier 3 articles do NOT appear in the pkgdown navbar but stay on
disk under `vignettes/articles/` so cross-references continue to
work. Mark the YAML front-matter with `tier: 3 # ...reason...` and
add a one-line note at the article's start saying which Tier-1 or
Tier-2 article supersedes it.

## The 10 reader-first style rules (apply to all Tier-1 articles)

1. **Lead with the user's question, not the math.** Open with the
   question; the model and math come after.
2. **Show working code before deriving symbols.** Within 30 lines of
   the start, the reader should see a `gllvmTMB(...)` block that fits
   the model the article is about.
3. **Active voice, present tense.** "The model fits" not "the model
   is fit".
4. **One topic per section. One question per paragraph.** If you
   write "additionally" or "furthermore" twice in a section, split
   the section.
5. **First use of each technical term gets a one-line gloss.**
   `Sigma`, `Lambda`, `latent`, `unique`, `indep`, `dep`,
   `phylo_*`, `spatial_*`, `meta_known_V` -- gloss each at first use.
6. **End each section with a forward link.** A code block the reader
   can run, a follow-up question the next section answers, or a
   cross-reference to a sibling article.
7. **Math display is for proofs, not for prose.** Inline `$x$` for
   passing terms; display `$$...$$` only for derivations the reader
   needs to follow line-by-line.
8. **Pictures over tables when comparing more than three rows.**
   Tables for cross-reference; plots for comparison.
9. **Cross-reference forward and backward.** Articles are read
   non-linearly.
10. **Show the failure mode the article protects against.** For
    every claim "use this model in case X", briefly show what
    happens when X is violated.

## Triage criteria (when to retire vs rewrite)

Use this checklist to decide, for any existing article, whether it
should be kept (Tier 1), demoted (Tier 2), or retired (Tier 3):

| Question | Tier | Action |
|---|---|---|
| Does the article open with a user-shaped question (rule 1)? | If yes -> 1. If no -> ask the next question. | |
| Could the article be a glossary entry (one keyword's syntax + a code block + 2-3 caveats)? | -> 2 | Move to "Technical reference" sub-dropdown. |
| Does the article validate the package against another implementation, benchmark performance, or preview an unsupported feature? | -> 3 | Retire from navbar. |
| Does the article fail 3+ of the 10 reader-first rules? | -> retire or rewrite | Cheaper to retire if a sibling Tier-1 article covers the topic; rewrite if not. |

The morphometrics article (`vignettes/articles/morphometrics.Rmd`) is
the canonical Tier-1 exemplar. When unsure how a Tier-1 article
should be structured, read morphometrics first, then write.

## Cross-references

- `_workshop/audits/article-readability-audit.md` (Pat's per-article
  triage, 2026-05-10) -- read for the worked examples of each tier
  judgment.
- `_workshop/audits/style-guide-articles.md` -- the source for the 10
  rules.
- `prose-style-review` skill -- for the prose-quality review pass on
  any article being reviewed.
