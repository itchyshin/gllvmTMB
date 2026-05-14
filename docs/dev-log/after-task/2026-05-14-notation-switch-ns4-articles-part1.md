# After-task: Notation switch NS-4 -- articles part 1 math prose -- 2026-05-14

**Tag**: `docs` (article math prose; no R code, no API, no math
content change -- only the symbol used in math prose).

**PR / branch**: this PR / `agent/notation-switch-ns4-articles-part1`.

**Lane**: Claude (Codex absent).

**Dispatched by**: continuing the maintainer-authorised
2026-05-14 notation switch. NS-1..NS-3b merged earlier in
this session. NS-4 is article part 1; NS-5 is article part 2
+ NEWS.

**Files touched** (5 articles + this after-task; 1 article
in scope had 0 hits):

- `vignettes/articles/pitfalls.Rmd` (3 hits: bare `$S$` inline
  + `+ S` in $$ equation block + identifiability prose)
- `vignettes/articles/covariance-correlation.Rmd` (~6 hits:
  `diag(s)`, `S_{tt}` x 4, math prose)
- `vignettes/articles/api-keyword-grid.Rmd` (1 hit: `diag(s)`
  on the canonical grid line)
- `vignettes/articles/morphometrics.Rmd` (~10 hits: `s_t^2`
  in math prose, `s_t` in code comments, `\mathbf{S}`,
  `S_{tt}`)
- `vignettes/articles/joint-sdm.Rmd` (~6 hits: `\mathbf S`,
  `S_{tt}` x 4)
- `vignettes/articles/choose-your-model.Rmd` (0 hits;
  already clean after NS-3a code-chunk pass)

Plus the after-task file.

## Math contract

No model / parser / likelihood / family change. Only the
math-prose symbol used. Same convention as NS-1..NS-3b:

- **Matrices**: `\boldsymbol{\Psi}` (bold capital) for the
  unique-variance diagonal matrix.
- **Per-trait diagonal entries / scalars**: `\psi_t`
  (italic lowercase, subscripted by trait). `S_{tt}` -> 
  `\psi_{tt}` (lowercase, the (t,t) entry of the matrix
  `\boldsymbol{\Psi}`).
- **`diag(s)` in code-style equations**: `diag(psi)`.

## Substitutions applied (two-pass perl)

```perl
# Pass 1: matrix-form + bare-S patterns
s/\$S\$/\$\\boldsymbol{\\Psi}\$/g;
s/\+ S$/+ \\boldsymbol\\Psi/g;
s/\+ S\b/+ \\boldsymbol\\Psi/g;
s/\\mathbf\{S\}/\\boldsymbol{\\Psi}/g;
s/\\mathbf S\b/\\boldsymbol\\Psi/g;
s/diag\(s\)/diag(psi)/g;
s/\$s_t\^2\$/\$\\psi_t^2\$/g;
s/\$s_t\$/\$\\psi_t\$/g;
s/\bs_t\^2\b/psi_t^2/g;
s/\bs_t\b/psi_t/g;
s/\bs2_true\b/psi2_true/g;
s/\bs_hat\b/psi_hat/g;

# Pass 2: matrix-entry subscripts
s/S_\{tt\}/\\psi_{tt}/g;
s/\bS_t\b/\\psi_t/g;
```

## Checks run

- `rg -n 'S_\{tt\}|\\bS_t\\b|\\\\mathbf\\{?S\\}?|\\\\boldsymbol\\{?S\\}?|\\bS_phy\\b|\\bS_non\\b|diag\\(s\\)'`
  across the 6 articles: **zero remaining hits**.
- No `devtools::document()` regen (no R/ touched).
- No `devtools::test()` run: article math prose only; no R
  code or test fixture touched.

## Consistency audit

After NS-4 merges, the 6 NS-4 articles are on the new
convention. The 3 NS-5 articles (`behavioural-syndromes`,
`functional-biogeography`, `phylogenetic-gllvm`) and
`NEWS.md` are the remaining work. The 2 articles outside
NS-4/5 scope (`ordinal-probit.Rmd`, `response-families.Rmd`)
had no S-notation math prose; no sweep needed there.

Function- and file-name "two-U" task labels preserved.

## Tests of the tests

No tests in this PR. Article math is LaTeX in
`\eqn{...}` / `$$...$$` / `$...$` blocks; not parsed by R.
`pkgdown::check_pkgdown()` will run on NS-5 final sweep.

## What went well

- The 6 articles took a two-pass perl. Pass 1 caught the
  bare-S and `\mathbf{S}` forms (covered by my earlier NS-3b
  patterns); pass 2 caught the `S_{tt}` matrix-entry
  subscripts which I'd missed in the initial pattern set.
- `joint-sdm.Rmd` and `pitfalls.Rmd` had the heaviest
  context-sensitive substitutions (inline `$S$`, `+ S` at
  end of equation lines, identifiability prose). All
  handled by pattern, no manual edits required.
- `choose-your-model.Rmd` ended up requiring zero changes;
  the article was already clean after NS-3a's code-chunk
  pass.

## What did not go smoothly

- **`S_{tt}` pattern missed in initial pass**. The
  matrix-entry subscript (`S_{tt}` = (t,t) entry of S) wasn't
  in my NS-3b perl substitution set. Two-pass sweep caught
  it. Lesson: when math prose has both matrices and entries,
  scope grep should explicitly enumerate the entry-subscript
  forms (`S_{tt}`, `S_{tt'}`, etc.) before designing the
  substitution.

## Team learning, per AGENTS.md role

- **Ada (maintainer)**: bulk sweep continues to work; this
  is the 4th sweep PR in the notation switch (NS-1 = rule
  files; NS-2 = README + design docs; NS-3a = R/ source +
  tests + article code chunks; NS-3b = R/ roxygen; NS-4 =
  article math prose part 1). Each one a single perl pass
  + verify.
- **Boole (R API)**: no API change; standing brief.
- **Gauss (TMB likelihood / numerical)**: no engine change.
- **Noether (math consistency)**: the article math now uses
  `\boldsymbol\Psi` (matrix) + `\psi_t` (scalar) +
  `\psi_{tt}` (diagonal entry). All three forms are
  internally consistent and match decisions.md
  2026-05-14 entry.
- **Darwin (biology audience)**: no biology-content change;
  the math notation switch is invisible to the biological
  argument.
- **Fisher (statistical inference)**: no inference-machinery
  change. The `\psi_t` per-trait scalar will appear in the
  Phase 1b' coverage study output and in
  `troubleshooting-profile.Rmd`'s profile-curve anatomy
  section.
- **Emmy (R package architecture)**: no S3 method change.
- **Pat (applied PhD user)**: the 6 articles now read
  internally consistently with the rebuilt convention; the
  Phase 1c `gllvm-vocabulary.Rmd` article will introduce the
  Greek-letter convention for new readers.
- **Jason (literature scout)**: no scan in NS-4; standing
  brief.
- **Curie (simulation / testing)**: no test fixture
  touched. Standing brief.
- **Grace (CI / pkgdown / CRAN)**: pkgdown re-render
  scheduled for NS-5; will produce the final rendered
  articles + reference index with `\boldsymbol\Psi`
  everywhere.
- **Rose (systems audit)**: pre-publish audit confirms the
  two-pass perl sweep was complete (zero remaining hits in
  NS-4 scope across the 6 articles).
- **Shannon (cross-team)**: Codex absent.

## Design-doc + pkgdown updates

- No design-doc edits in NS-4 (handled in NS-2).
- `pkgdown::check_pkgdown()` scheduled for NS-5 final sweep.

## Known limitations and next actions

**Known limitations**:

- 3 articles (`behavioural-syndromes`, `functional-biogeography`,
  `phylogenetic-gllvm`) and `NEWS.md` still use S-notation.
  NS-5 closes this.

**Next actions**:

1. NS-5: articles part 2 math prose (`behavioural-syndromes`,
   `functional-biogeography`, `phylogenetic-gllvm`) +
   `NEWS.md` entry (notation-switch summary + drop "ML or
   REML" overstatement per the 2026-05-14 REML scope
   decision) + final `pkgdown::check_pkgdown()` sanity.
2. After NS-1..NS-5 merged: start Phase 1a Batch A.
