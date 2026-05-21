# drmTMB Lessons For gllvmTMB's Article And Teamwork Reset

**Date:** 2026-05-20
**Prepared by:** Ada
**Review lenses:** Pat, Darwin, Fisher, Florence, Grace, Rose, Jason

## Purpose

This sweep asks why the `drmTMB` team can ship many examples without making
the public site feel careless, and what `gllvmTMB` should copy before revealing
more articles.

The short answer: `drmTMB` has many pages, but they are not a pile. They are
sorted by reader intent, each worked example has a model-shaped teaching arc,
and the team records process improvements when it catches itself making a
mistake. `gllvmTMB` should copy that discipline, while adding stricter gates
for long/wide formula pairs, latent-covariance recovery, simulation truth, and
figure interpretation.

## Evidence Read

From the local `drmTMB` repository:

- `_pkgdown.yml`: navbar and reference architecture.
- `docs/design/21-tutorial-style.md`: tutorial contract.
- `docs/design/37-worked-example-inventory.md`: per-article readiness
  inventory.
- `docs/design/39-visualization-grammar.md`: table-first plotting and
  Florence figure gate.
- `docs/design/46-pre-simulation-readiness-matrix.md`: admission gate before
  simulation grids.
- `docs/dev-log/team-improvements.md`: process-learning log.
- Representative tutorials:
  `vignettes/location-scale.Rmd`, `vignettes/count-nbinom2.Rmd`,
  `vignettes/model-map.Rmd`, `vignettes/simulation-plot-grammar.Rmd`.
- Representative after-task reports and check-log entries.
- `gh issue list --repo itchyshin/drmTMB --state all --limit 30`.

Key line evidence:

- Navbar separates Model Guides, Tutorials, Simulation & Comparison, and
  Developer Notes in `_pkgdown.yml` lines 20-76.
- The tutorial contract requires question, data, symbolic model, exact syntax,
  fitted output, interpretation, diagnostics, and limitations in
  `docs/design/21-tutorial-style.md` lines 15-29.
- The guide/tutorial split is explicit in `docs/design/21-tutorial-style.md`
  lines 31-51.
- The worked-example inventory labels pages conservatively as ready enough,
  needs polish, guide, or split pressure in
  `docs/design/37-worked-example-inventory.md` lines 24-51.
- The visualization grammar says tables come before plots, estimands and
  uncertainty provenance are named, and rendered output must be inspected in
  `docs/design/39-visualization-grammar.md` lines 31-41, 43-56, 74-93, and
  157-188.
- The pre-simulation readiness matrix says readiness is stricter than "fits
  once"; likelihood, parser boundary, extractors, diagnostics, interval status,
  recovery tests, and reader boundary must all be visible in
  `docs/design/46-pre-simulation-readiness-matrix.md` lines 1-12 and 20-47.
- The team-improvement log records start-of-task role status, figure judgment,
  issue maintenance, and CI-wait learning in
  `docs/dev-log/team-improvements.md` lines 26-37, 76-105, 121-148.

## Why drmTMB Works Better

### 1. Navigation Is A Reader Contract

`drmTMB` does not put every page into one "Articles" bucket. It separates:

- **Model Guides**: "What can I fit today?", scale vocabulary, family choice,
  workflow, convergence, and large-data advice.
- **Tutorials**: fitted examples that answer applied questions.
- **Simulation & Comparison**: likelihood tests, comparators, and simulation
  plot grammar.
- **Developer Notes**: formula grammar, family implementation, source maps.

This separation does two useful things. First, it tells the reader what mental
mode to use. Second, it prevents validation notes and developer references from
pretending to be public worked examples.

`gllvmTMB` currently mixes concept pages, validation pages, previews, and
worked examples too freely. The fix is not only "hide pages"; it is to rebuild
navigation around reader intent.

### 2. A Tutorial Has A Fixed Teaching Arc

The `drmTMB` tutorial style contract is simple and strong:

1. biological or applied question;
2. response, predictors, grouping factors, known matrices;
3. symbolic model paired with exact R syntax;
4. fitted model object and printed output;
5. plot or table mapping output back to the question;
6. plain-language interpretation;
7. unsupported-syntax boundary.

This is why `drmTMB` examples feel thought through. The pages are not just code
chunks. They tell the reader what is being estimated and how to interpret each
coefficient or component.

`gllvmTMB` needs the same article anatomy, with one extra rule: every Tier-1
worked example must show both long and wide formulas or explicitly record why
the wide route is unsupported.

### 3. Each Article Owns One Model Surface

`drmTMB` treats each model as precious. For example:

- `location-scale.Rmd` asks whether habitats differ in mean growth and
  predictability, then maps `mu` and `sigma` to equations, syntax, output, and
  interpretation.
- `count-nbinom2.Rmd` uses springtail counts and stays inside the implemented
  NB2 and zero-inflated NB2 surface, while saying what is not included.
- `model-map.Rmd` is explicitly a guide, not a tutorial.

The pages do not try to be universal tours. They resist the temptation to add
every adjacent feature into one article.

`gllvmTMB` should not restore broad articles such as functional biogeography,
animal models, phylogenetic GLLVMs, or behavioural syndromes until each has one
clear model surface, one DGP, one fitted pair of long/wide calls, and one
truth-vs-estimate interpretation.

### 4. Simulations Support The Story Instead Of Becoming The Story

`drmTMB` can include transparent simulations because the examples use them to
explain a biological world: springtails in traps, growth predictability, seed
germination, vegetation cover, residual coupling. The simulation is not just
random code. It defines the truth the fitted model should recover.

`gllvmTMB` examples currently expose too much raw DGP machinery. That makes
the articles feel like developer notes. We need scenario-level simulation
helpers that return:

- long data;
- wide data when possible;
- truth values;
- fitted estimand table;
- suggested long and wide formula calls;
- biological variable names.

Then the article can say: "we simulate a behavioural syndrome where boldness
and exploration share one latent axis", rather than showing 150 lines of
matrix construction before the reader knows why they should care.

### 5. Validation Gates Are Named Before Expansion

`drmTMB` has a pre-simulation readiness matrix that asks whether a surface is
ready for operating-characteristic grids. It does not equate "fits once" with
"validated". It requires implementation evidence, tests, diagnostics, interval
status, user-facing boundaries, and simulation admission.

This is the exact discipline `gllvmTMB` needs for articles. A page should not
return to the navbar because it renders. It returns only when the underlying
model surface has the corresponding register rows and tests.

### 6. Figures Are Treated As Scientific Evidence

`drmTMB`'s visualization grammar starts with tables and estimands. It requires
plot data to identify the target, reporting scale, data grain, uncertainty
source, and missing support. The team-improvement log makes figure review a
shared responsibility: Florence owns the final figure standard, but Fisher,
Pat, Rose, Grace, Darwin, Boole, and Noether all have failure modes to catch.

For `gllvmTMB`, this matters even more. Latent axes, covariance matrices,
correlations, profile intervals, bootstrap rows, and failed replicate fits are
easy to misread from tables alone. But figures can also overpromise quickly.
The rule should be: no figure-heavy article returns without rendered-HTML and
rendered-figure inspection.

### 7. Teamwork Lessons Are Written Down

`drmTMB` has `docs/dev-log/team-improvements.md`. It records process lessons
like:

- start substantial tasks with "who is working right now";
- say when named roles are perspectives rather than spawned subagents;
- use Florence for visual work;
- inspect issues in after-task reports;
- use CI-wait time for bounded learning, not random extra feature work.

This is why mistakes become process upgrades instead of recurring chat
complaints. `gllvmTMB` should copy this file pattern directly.

### 8. Issues Are Part Of The Memory Loop

The `drmTMB` issue list is not just bugs. It contains phase ledgers:
visualization, simulation, comparator benchmarks, CRAN readiness, structural
parity, animal/relmat, bootstrap intervals, and large-data readiness. Recent
after-task reports explicitly record which issues were inspected or updated.

For `gllvmTMB`, the issue tracker should become the same ledger. Article reset,
simulation-helper infrastructure, plotting infrastructure, long/wide formula
gates, and #228 diagnostics should all have issue-level homes or explicit
comments on existing issues.

## What gllvmTMB Should Copy Directly

### A. Navbar Shape

Use four public groups, not one overloaded Articles dropdown:

- **Model Guides**: what can I fit today, data shape, model choice, family
  choice, diagnostics.
- **Tutorials**: only polished worked examples.
- **Simulation & Validation**: simulation reports, recovery studies,
  comparator notes, figure grammar.
- **Developer Notes**: formula grammar, source maps, family implementation,
  validation-debt register links.

Until the pages are ready, show only the minimal Tutorials group and keep the
other groups hidden or sparse.

### B. Tutorial Contract

Create a gllvmTMB article contract copied from drmTMB but extended:

1. biological or applied question;
2. response, unit, trait, grouping factor, and known matrix;
3. symbolic model paired with long formula and wide `traits(...)` formula;
4. fitted long and wide objects with equality or near-equality check;
5. diagnostics before interpretation;
6. truth-vs-estimate comparison for simulations;
7. plot or table mapping output to the biological question;
8. plain-language interpretation of slopes, loadings, covariance,
   correlation, repeatability, communality, or phylogenetic/spatial signal;
9. unsupported-syntax boundary;
10. rendered HTML review with the maintainer before public reveal.

### C. Worked-Example Inventory

Create and maintain a `gllvmTMB` worked-example inventory. Use categories:

- ready candidate;
- needs focused polish;
- guide, not tutorial;
- technical reference;
- infrastructure-blocked;
- split pressure;
- project/internal.

Every article should have a main blocker and next action. This prevents a
large article count from looking like a large ready surface.

### D. Scenario Simulation Helpers

Before restoring more examples, build scenario helpers. Candidate helpers:

- `simulate_morphometrics_example()`
- `simulate_behavioural_syndrome_example()`
- `simulate_joint_sdm_example()`
- `simulate_animal_model_example()`
- `simulate_phylogenetic_gllvm_example()`
- `simulate_spatial_gllvm_example()`
- `simulate_meta_analysis_example()`

Each helper should be tested and return long data, wide data where possible,
truth, and an estimand table. The article should then explain the world and the
model, not raw simulator plumbing.

### E. Readiness Matrix Before Articles

Copy the pre-simulation readiness matrix idea. For each article candidate,
require:

- model surface implemented;
- tests or simulation recovery;
- extractor evidence;
- profile/bootstrap/interval status if uncertainty is discussed;
- plotting/helper evidence if figures are central;
- validation-debt rows;
- reader-facing boundary;
- HTML review.

### F. Team Improvements Log

Add a `gllvmTMB` equivalent of `docs/dev-log/team-improvements.md`. First
entries should include:

- long + wide formulas are a hard publication gate;
- no article reveal without rendered HTML review with the maintainer;
- article examples are infrastructure-dependent, not a way to explore future
  features casually;
- issue maintenance belongs in after-task reports;
- CI-wait time can be used for bounded audits only when it creates an artifact.

## What Not To Copy Blindly

Do not copy the number of drmTMB pages. `gllvmTMB` has higher-dimensional
latent covariance, rotation, long/wide data shapes, multiple response families,
phylogenetic/spatial layers, and simulation recovery issues. A gllvmTMB
article has more ways to overclaim.

Do not copy `drmTMB`'s univariate/bivariate article compactness as if it scales
directly. `gllvmTMB` needs stronger sample-size checks, truth alignment,
rotation handling, covariance decomposition explanations, and figure review.

Do not publish developer validation reports as beginner tutorials. Put them
under Simulation & Validation or Developer Notes.

## Proposed gllvmTMB Operating Model

The aim is not to make `gllvmTMB` a smaller, nervous version of `drmTMB`.
The aim is to copy the careful operating system and then become excellent in
the way a high-dimensional GLLVM package should be excellent: practical
simulation tools, clear extraction tables, honest uncertainty, publication-
quality plots, and examples that let biologists, ecologists, evolutionary
biologists, and environmental scientists understand what the fitted covariance
means for their data.

## Borrow, Adapt, Surpass

### Borrow From drmTMB

Copy the parts that are already working:

- reader-intent navigation;
- model guides separate from tutorials;
- simulation and comparison separate from examples;
- developer notes outside the beginner path;
- worked-example inventory;
- pre-simulation readiness matrix;
- table-first plotting grammar;
- figure-quality gate;
- issue maintenance in after-task reports;
- team-improvement log when process mistakes recur.

### Adapt For gllvmTMB

`gllvmTMB` needs stricter gates because its models are harder to read:

- every Tier-1 article shows long and wide `traits(...)` calls;
- every simulation article compares fitted estimates to known truth;
- every latent-axis article names rotation limits and focuses on
  rotation-invariant quantities unless the loading interpretation is the point;
- every covariance article distinguishes `Sigma`, `Lambda`, `psi`, correlation,
  communality, repeatability, phylogenetic signal, and residual terms;
- every figure names estimand, scale, data grain, uncertainty source, and
  missing support;
- every article says whether the feature is covered, partial, or blocked in
  the validation-debt register.

### Surpass In gllvmTMB's Own Way

`gllvmTMB` can become unusually useful if it gives applied users practical
tools before prose:

- scenario simulators that create realistic ecological/evolutionary datasets;
- extraction helpers that return report-ready covariance, correlation,
  communality, repeatability, and ordination tables;
- plotting helpers that make those tables interpretable without hiding weak
  support;
- diagnostics that tell users whether point estimates are interpretable and
  whether uncertainty should come from Wald, profile, bootstrap, or not at all;
- articles that explain one biological model at a time and show exactly what
  was estimated.

The articles should showcase tools that already work. They should not be used
to discover what the package might someday do.

## User-First Tooling Plan

### T0. Scenario Simulation Helpers

Build simulation helpers that think like the intended users. Each helper should
simulate a named biological world and hide routine DGP plumbing from the
article.

Candidate helpers:

| Helper | User story | Core estimands |
|---|---|---|
| `simulate_morphometrics_example()` | Individuals measured on several continuous body traits share a size/shape axis. | `Sigma`, correlations, communality, loadings, long/wide equivalence. |
| `simulate_behavioural_syndrome_example()` | Repeated behaviours covary because individuals differ consistently and also vary within individuals. | between/within covariance, repeatability, communality, long/wide equivalence. |
| `simulate_joint_sdm_example()` | Species occurrences across sites share residual co-occurrence after environmental filtering. | latent covariance, link residual, species correlations, ordination. |
| `simulate_animal_model_example()` | Related individuals resemble each other; traits have additive genetic covariance. | genetic variance/correlation, heritability-like summaries, pedigree/A matrix. |
| `simulate_phylogenetic_gllvm_example()` | Species traits or responses covary partly because of shared ancestry. | phylogenetic covariance, non-phylogenetic covariance, phylogenetic signal. |
| `simulate_spatial_gllvm_example()` | Nearby sites share latent environmental structure across traits/species. | spatial covariance, range/field diagnostics, residual trait covariance. |
| `simulate_meta_analysis_example()` | Studies estimate multiple outcomes with known sampling covariance. | known `V`, residual heterogeneity, exact/proportional mode boundary. |

Each helper should return:

- `data_long`;
- `data_wide` when a wide formula is meaningful;
- `truth`;
- `estimands`;
- `formula_long`;
- `formula_wide`;
- `fit_args`;
- optional `story` metadata with variable labels and biological explanation.

### T1. Extraction Tables

Before articles expand, make extraction outputs easy to teach:

- `extract_Sigma()` / `extract_correlations()` should be the report-ready path
  for covariance and correlation.
- `extract_communality()` and `extract_repeatability()` should map directly to
  biological interpretation tables.
- `extract_phylo_signal()` and future spatial/animal summaries should name the
  level and source of covariance.
- Every extractor used in an article should have an example table with columns
  that can be plotted without reverse-engineering internals.

### T2. Plotting Helpers

Plotting is infrastructure. The public plot layer should consume extraction or
prediction tables, not refit models or silently call hidden internals.

Required plot families before broad article reveal:

- covariance/correlation heatmap with truth-vs-fit option;
- communality/repeatability forest or interval plot;
- estimate-vs-truth recovery plot for simulation examples;
- ordination plot with rotation caveats;
- diagnostic figure for convergence, failed intervals, and weak Hessians;
- simulation-grid report plot with replicate/failure denominators.

Florence's gate applies before public use: rendered figure inspected, not just
source built.

### T3. Diagnostics And Uncertainty

Users need practical guidance when the model is hard:

- `check_gllvmTMB()` remains the first diagnostic table.
- `pdHess = FALSE` is an uncertainty warning, not automatic model death.
- Point estimates can remain useful when SEs fail, but the article must say how
  uncertainty will be handled.
- Profile/bootstrap paths need status labels and failure ledgers before they
  appear as polished uncertainty displays.
- #228 predictive diagnostics should resume only after the article/tooling
  surface has a place for them.

### T4. Article Reveal

Only after T0-T3 are ready for a model surface should an article return. The
article's job is to explain why the tool is useful:

1. name the biological question;
2. simulate or load a clear user-shaped dataset;
3. show long and wide fits;
4. diagnose the fit;
5. compare fitted estimates with truth or with a known reference;
6. interpret each estimand in plain language;
7. show a figure that teaches the result;
8. state what is not yet supported.

This is how `gllvmTMB` becomes as good as `drmTMB`, but in its own domain.

### Immediate

1. Keep all current article files on disk.
2. Hide all but the strongest public examples.
3. Treat `README.md` and Get Started as part of the same reset.
4. Write the article inventory and roadmap around infrastructure.
5. Create or update issues for article reset, scenario simulators, plotting
   infrastructure, and #228 diagnostics.

Issue #230 is the first ledger home for this reset. Split child issues only
when a tooling slice is ready to start, so the tracker does not become another
premature article pile.

### Next Infrastructure Slices

1. **Simulation helper contract**: one return shape for long data, wide data,
   truth, estimands, and formulas.
2. **Morphometrics helper and HTML review**: first polished example because it
   is the safest Gaussian latent+unique surface.
3. **Plotting helper contract**: return data first, ggplot second; every figure
   names estimand, scale, data grain, and uncertainty.
4. **Extractor/uncertainty map**: which `extract_*()` and CI paths are covered,
   partial, or blocked for article use.
5. **Article reveal protocol**: one article per PR, rendered HTML shown to the
   maintainer before merge.

### Later Article Reveal Order

1. Morphometrics.
2. Covariance versus correlation.
3. Pitfalls.
4. Behavioural syndrome, after simulation helper and long/wide fit pair.
5. Animal model, after larger fixture and recovery story.
6. Phylogenetic GLLVM, after reader question and validation boundaries are
   clean.
7. Joint SDM, after binary/M3 evidence and figure semantics are ready.
8. Functional biogeography, only after M3 validation and figure review.

## Bottom Line

`drmTMB` is careful because it has a system:

- reader-intent navigation;
- tutorial contract;
- worked-example inventory;
- validation readiness matrix;
- table-first plotting grammar;
- figure audit;
- after-task issue maintenance;
- team-improvement memory.

`gllvmTMB` should copy the system, not the volume. The right route is slower
and stronger: build the simulation, extraction, uncertainty, and plotting
infrastructure first, then reveal one carefully reviewed model example at a
time.
