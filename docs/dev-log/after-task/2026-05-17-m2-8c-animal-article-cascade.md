# After Task: M2.8c — Article cascade for animal_* (5 articles)

**Branch**: `agent/m2-8c-animal-article-cascade`
**Slice**: M2.8c (follow-up to M2.8; completes the article-side doc cascade for the animal_* family)
**PR type tag**: `docs` (article edits only — no R/ source, NAMESPACE, generated Rd, family-registry, formula-grammar, or extractor change)
**Lead persona**: Pat (reader UX) + Rose (cross-doc consistency)
**Maintained by**: Pat + Rose; reviewers: Darwin (QG audience), Boole (API references), Ada (close gate)

## 1. Goal

Complete the article-side doc cascade for M2.8's `animal_*`
keyword family. The M2.8 PR (#167) ratified the math, design doc,
and reference-index entries; this slice surfaces the `animal_*`
family in the 5 Concepts / decision-aid articles users actually
read first.

**Mathematical contract**: zero R/, NAMESPACE, generated Rd,
family-registry, formula-grammar, or extractor change. Pure
article-side additions.

Per Pat's reader-UX lens: an exported keyword family that doesn't
appear in the decision-tree articles is effectively invisible to
the user. Per Rose's audit lens: the A-vs-V naming boundary needs
to be reinforced in the user-facing entry points, not just in the
design doc.

## 2. Implemented

### Article 1/5: `vignettes/articles/choose-your-model.Rmd`

New subsection **§3a "Are individuals related by a pedigree
(animal model)?"** inserted between §3 (phylogeny) and §4 (spatial).
Single paragraph + 3 code blocks showing the three input forms
(`pedigree =`, `A =`, `Ainv =`). Cross-links to Design 14 for the
math + A-vs-V boundary.

### Article 2/5: `vignettes/articles/data-shape-flowchart.Rmd`

- New Mermaid-flowchart branch: `A -->|Pedigree available: id /
  sire / dam| F[Animal-model quantitative genetics]` (5th
  top-level branch alongside cross-sectional / site×species /
  IRT / species-level).
- Static-fallback list gains "(5) Pedigree available" entry.
- New paragraph in "Notes on the branches" explaining the animal
  model with the canonical formula + reference to `pedigree_to_A()`
  and Design 14.
- "3x5 keyword reference" → "4x5 keyword reference" in "See also".

### Article 3/5: `vignettes/articles/gllvm-vocabulary.Rmd`

New top-level section **"Quantitative-genetics terms"** with 7
glossary entries:

- **Animal model** — what it is + how it maps to `animal_*()`
- **Pedigree** — 3-column id/sire/dam table; Henderson 1976
- **A matrix** — additive-genetic relatedness; full-sib = 0.5
  etc.
- **Kinship coefficient** ($\phi_{ij}$) — $A_{ij}/2$
- **Additive genetic variance** ($V_A$, $\sigma^2_A$) — numerator
  of $h^2$
- **Narrow-sense heritability** ($h^2 = V_A / V_P$)
- **G matrix** — multi-trait analogue of $V_A$;
  Kirkpatrick-Meyer factor-analytic decomposition
- **Reaction norm / random regression** — `animal_slope()`
- **A vs V naming boundary** — the Rose rule, stated once in
  the glossary so other articles can cross-link to it

"See also" updated: "3x5 keyword reference" → "4x5 keyword
reference".

### Article 4/5: `vignettes/articles/pitfalls.Rmd`

- Lead changed from "Six recurring mistakes" to "Seven recurring
  mistakes".
- New **§7 "A vs V: relatedness covariance vs sampling variance"**.
  Symptom / Diagnosis / table contrasting `animal_*(A =)` /
  `phylo_*(A =)` vs `meta_known_V(V =)` / Wrong-vs-Right code
  example / Rule of thumb. Cross-references Design 14 §3 and
  the new vocabulary glossary entry.

### Article 5/5: `vignettes/articles/phylogenetic-gllvm.Rmd`

- New bullet in **"What to read next"**: "Animal models with
  individual pedigrees" — 6-keyword cross-reference table plus
  `pedigree_to_A()` link. Notes the math identity (pedigree vs
  phylogeny = same A, different source).
- **Stale-wording cleanup**: removed the existing paragraph that
  said *"`gllvmTMB_wide()` is not the right shortcut for this
  row-phylogeny example"*. That paragraph dissuaded users from a
  function that was deprecated and removed in 0.2.0 (FG-16 + MIS-03
  in the validation-debt register, both `blocked`). With the
  function gone, the warning has no referent.

## 3. Files Changed

```
Modified:
  vignettes/articles/choose-your-model.Rmd                                          (+30 lines; new §3a)
  vignettes/articles/data-shape-flowchart.Rmd                                       (+18 / -2; new flowchart branch + paragraph)
  vignettes/articles/gllvm-vocabulary.Rmd                                           (+62 lines; new "Quantitative-genetics terms" section)
  vignettes/articles/pitfalls.Rmd                                                   (+45 / -1; new §7 + lead sentence)
  vignettes/articles/phylogenetic-gllvm.Rmd                                         (+18 / -7; "What to read next" expansion + stale `gllvmTMB_wide()` paragraph removed)

Added:
  docs/dev-log/after-task/2026-05-17-m2-8c-animal-article-cascade.md                (this file)
```

No R/, NAMESPACE, generated Rd, family-registry, formula-grammar,
extractor, ROADMAP, README, NEWS, or design-doc change. **Article-
side only.**

## 4. Checks Run

- `pkgdown::check_pkgdown()` → ✔ No problems found.
- Stale-wording rg sweep on the 5 edited articles after the
  cleanup:
  `rg "S_B\\b|S_W\\b|gllvmTMB_wide|trio|phylo_rr\\(|gr\\(|block_V\\(" vignettes/articles/{choose-your-model,data-shape-flowchart,gllvm-vocabulary,pitfalls,phylogenetic-gllvm}.Rmd`
  → **0 hits.**

## 5. Tests of the Tests

3-rule contract (article PRs don't ship tests, but the parallel
3 rules apply to reader-UX checks):

- **Rule 1** (would have failed before fix): without these
  edits, an article reader who started at `choose-your-model.Rmd`
  or `data-shape-flowchart.Rmd` would never encounter the
  `animal_*()` family. The 5 entry-point articles now name the
  family + link to Design 14.
- **Rule 2** (boundary): the pitfalls §7 directly addresses the
  A-vs-V conflation boundary — the failure mode a reader is
  most likely to hit when mixing animal models with meta-analysis.
- **Rule 3** (feature combination): the article cascade exercises
  the cross-doc cross-reference graph (choose-your-model →
  phylogenetic-gllvm → animal_* roxygen; data-shape-flowchart →
  Design 14; gllvm-vocabulary → Design 14 + pitfalls; pitfalls
  → Design 14 + gllvm-vocabulary). Coherent multi-article
  navigation for the new family.

## 6. Consistency Audit

- Stale-wording rg sweep clean (0 hits).
- A-vs-V naming boundary stated in identical wording across:
  Design 14 §3, README, NEWS, the api-keyword-grid article (from
  M2.8), the new gllvm-vocabulary entry, the new pitfalls §7.
  Six surfaces, same canonical phrasing.
- Persona-active-naming: lead Pat + Rose; reviewers Darwin +
  Boole + Ada.

Convention-Change Cascade (AGENTS.md Rule #10): article-side
cascade for the M2.8 animal_* shipment. The full M2.8 cascade
list (Design 14 + 7 design docs + register + README + NEWS +
ROADMAP + pkgdown + api-keyword-grid) was completed in PR #167;
this slice fills in the remaining 5 reader-facing articles.

## 7. Roadmap Tick

- No ROADMAP M-row tick. M2.8c is a small docs-only follow-up to
  M2.8.
- No validation-debt register changes. The article cascade does
  not add new advertised capabilities — it documents existing
  M2.8 capabilities in the user-facing articles. The ANI-* rows
  in Section 6.5 (M2.8) already track the underlying machinery.

## 8. What Did Not Go Smoothly

- **One stale `gllvmTMB_wide()` reference surfaced** in
  `phylogenetic-gllvm.Rmd` during the rg sweep. The paragraph
  warned readers against using `gllvmTMB_wide()` for row-phylogeny
  examples — but the function was deprecated and removed in 0.2.0
  (FG-16 + MIS-03, `blocked`). The whole paragraph had no referent
  and was removed. **Lesson**: when adding article content,
  also rg-sweep the touched files for stale references to
  removed APIs and clean them up. Logged this pattern under the
  precision feedback memory.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

**Pat** (lead — reader UX): the 5 articles are now navigationally
coherent for a quantitative-genetics reader: a QG user landing
on choose-your-model.html or data-shape-flowchart.html will
encounter the animal model as a first-class branch; landing on
gllvm-vocabulary.html will find the QG terms defined; landing on
pitfalls.html will hit the A-vs-V boundary.

**Rose** (co-lead — A-vs-V cross-doc consistency): the boundary
rule is now stated 6+ times across the doc surface in identical
wording. This is what makes the rule sticky — a future PR that
blurs A and V will collide with multiple cross-references and
get caught in review.

**Darwin** (review — QG audience): the new vocabulary entries
(animal model, A matrix, kinship coefficient, $V_A$, $h^2$, G
matrix, reaction norm) match the QG literature's terminology.
A reader from a behavioural-ecology or breeding background will
recognise the vocabulary on day one.

**Boole** (review — API references): every animal_* keyword
mentioned in the articles cross-refs the reference index entry.
`pedigree_to_A()` link works. No broken cross-refs found by
`pkgdown::check_pkgdown()`.

**Ada** (review — orchestration): M2.8 → M2.8b (phylo soft-
deprecate) → M2.8c (article cascade) closes the M2.8 deliverable
end-to-end. Next: M2.5 (psychometrics-irt rewrite — needs
maintainer FINAL CHECKPOINT before I start).

## 10. Known Limitations and Next Actions

- **M2.5 dispatches next** but **requires maintainer FINAL
  CHECKPOINT** before I start. Article rewrite per CLAUDE.md
  "stop for discussion before broad article rewrites".
- **Worked-example article** for the animal model (`animal-model-
  introduction.Rmd` or similar) deferred to v0.3.0 (ANI-09).
  The current 5-article cascade is the "decision-tree and
  vocabulary" layer; the worked example is a separate
  pedagogical slice that needs a real pedigree fixture.
- **Stale-wording sweep** as a precaution before each article-
  edit slice should become routine; logged in the precision
  feedback memory (`feedback_precision.md`).
