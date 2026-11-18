# 2026-08-17 — One-outer-penalty wording pass (rare-species + evidence-synthesis articles)

**Lane:** `claude/one-outer-penalty-wording-20260817` (docs-only, off `origin/main` @ `e3e813f4`)
**Scope:** `vignettes/articles/rare-species-jsdm.Rmd`, `vignettes/articles/mspl-binary-jsdm.Rmd` — prose and YAML only. No R chunk, no code, no exported surface touched.

## Why

Shinichi passed on a review note (2026-08-16, Grok-bot discussion) arguing the two
articles *sound* like two tools a reader might use together — a loading ridge plus
`estimator = "mspl"` — when the package's rule is **one fit, one outer penalty**
(the hybrid is refused with a typed error and has no supporting theorem). The note
also asked that the framing not equate the disease with *rarity*: complete
separation is a perfect split on the fixed design, which occurs at both prevalence
tails.

Claim-by-claim check against `origin/main` found the note partly overstated —
"do not compose", the refuse-hybrid error, and "not rarity itself" were already in
the text — but four genuine wording deltas remained. This pass makes only those.

## What changed

`rare-species-jsdm.Rmd`:
1. YAML description now names the disease (complete separation), says the loading
   ridge does not fix it, and that the two are never combined in one fit.
2. Added the both-tails sentence after the "not rarity itself" paragraph: the same
   certificate fires for a near-ubiquitous species; a perfect split, not rarity,
   is the definition.
3. "Why not the loading ridge?" closing: replaced the parenthetical "do not
   compose" with the explicit one-outer-penalty-per-fit statement (ridge shrinks
   loadings; this species' boundary is in the fixed-effect slope).
4. Final section: "demonstrates the two side by side" → "demonstrates each remedy
   against its own disease — one outer penalty per fit, never both."

`mspl-binary-jsdm.Rmd` (kept minimal per the note's own fence — no rewrite):
5. YAML description: the matched-remedy list now reads "for one / for the other,
   never both in one fit" instead of a bare "and".
6. Intro: "The remedies do not substitute" → "Each remedy treats only its own
   disease … and they are never combined in one fit."
7. "Which remedy, when" table, *Both at once* row: prefixed "Still one fit, one
   outer penalty:".

## Explicitly NOT done

- No ridge+MSPL hybrid implemented; the refuse-hybrid error is untouched.
- No SE/CI/logLik fence changes; MSPL fences stay as shipped.
- No worked-example or code-chunk changes; the MSPL curve and three-route demo
  render identically.
- No sibling rewrite beyond the three touches above.

## Checks

- Wording-only diff verified (no chunk fences or R code in the diff).
- Both files' YAML remains parseable (single-line description strings).

## Done-when (from the pass-on note)

A reader of `rare-species-jsdm.html` cannot think the recommended fit is ridge
plus MSPL; the refuse-hybrid error stays; the worked MSPL curve stays; no new
SE/CI. All four hold.
