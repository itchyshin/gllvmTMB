# Article estate — Fable-tier quality re-audit + cleanup (2026-07-10)

A two-pass audit of all 34 pkgdown articles for the v1.0 CRAN release: a readiness pass, then a **top-tier (Fable) editorial-quality re-audit** ("is it genuinely good, or rubbish?"). Fable verdict: **6 keep · 26 improve · 2 cut**. The safe, mechanical fixes were auto-applied; the deeper editorial/rewrite items are listed as maintainer follow-ups.

## Cut (retired to `dev/held-articles/`)
| Article | Why |
|---|---|
| **data-shape-flowchart** | A competent but not-ready, orphaned path-finder that routes readers into two non-existent articles and duplicates choose-your-model's data-shape entry — cut and fold its one asset (the mermaid) into choose-your-model. |
| **stacked-trait-gllvm** | A self-declared "retire candidate" whose two core teaching chunks don't even execute — a stale, non-executing, strictly weaker duplicate of the live functional-biogeography article; cut it. |

## Keep — ship-quality (6)
| Article | q | Fable's read |
|---|---|---|
| model-selection-latent-rank | 4 | A clear, live-running, statistically correct rank-selection tutorial that genuinely earns its place — one of the best pages in the set, not rubbish. |
| pre-fit-response-screening | 4 | A clear, accurate, honestly-scoped tutorial for screen_gllvmTMB() that teaches a real pre-fit workflow and earns its place; only a leaked internal reg |
| fit-diagnostics | 4 | A clean, reproducible, correctly-scoped diagnostics tutorial that earns its place — the antithesis of the "complete rubbish" articles, needing only mi |
| pitfalls | 4 | A genuinely strong, correct, self-executing troubleshooting page — the best of the diagnostics group; keep with light polish, nowhere near the "rubbis |
| behavioural-syndromes | 4 | A well-structured, technically correct two-level GLLVM worked example — genuinely ship-quality as a developer-note page, needing only minor polish; em |
| cross-package-validation | 4 | An accurate, honestly-scoped developer validation note that earns its place — the one real risk is its flagship gllvm demo rendering as an empty stub  |

## Improve — auto-fixed this PR (26)
Fable named specific defects (duplicate blocks from botched merges, register-code jargon in reader prose, stacked disclaimer banners, internal `$report$` reach-ins, two correctness bugs). The agents applied **103 surgical edits**; each article's remaining editorial/rewrite items are the *maintainer carry-overs* below.

| Article | q | auto-fixed | maintainer carry-over |
|---|---|---|---|
| animal-model | 3 | 5 edits | The internal reach-ins for the CENTRAL quantities cannot be swapped to the exported API because no exported phy-tier acc… |
| api-keyword-grid | 3 | 5 edits | The 4x4-vs-4x5 grid-arity mismatch (action item 5) is left unresolved. This article presents a 4x4 grid after dropping t… |
| choose-your-model | 3 | 4 edits | Action point 3 (destination gating) is the only unapplied item: the article still routes to four non-public 'internal dr… |
| convergence-start-values | 3 | 5 edits | Two action items were left unapplied as too risky/editorial for a surgical pass: (3) De-duplicating the opening 'Fit A S… |
| covariance-correlation | 4 | 4 edits | None of the required edits were too risky to auto-apply. The optional overlap-boundary note (stating this article owns t… |
| cross-lineage-coevolution | 3 | 4 edits | Nothing blocking. Two items the audit noted but that are out of scope for a surgical cleanup and left for the maintainer… |
| fixed-effect-zero-constraints | 4 | 2 edits | — |
| functional-biogeography | 3 | 4 edits | Two editorial/risky pieces were left: (1) the deeper half of action item (1) -- bumping the fixture to n_sites>=50 / n_s… |
| gllvm-vocabulary | 3 | 4 edits | The Quantitative-genetics section trim (action item 3) is too editorial to auto-apply: it asks to trim the section to te… |
| joint-sdm | 3 | 4 edits | Action item (5) not applied: the vague loading-constraint pointer (See also, final section: 'the full public loading-con… |
| lambda-constraint | 3 | 1 edits | The primary ship-blocker in the action is NOT auto-applied because it requires running/rendering R and is a broad rewrit… |
| lambda-constraint-suggest | 2 | 3 edits | Three of the four action items are too heavy/editorial to auto-apply surgically: (1) Make the payoff render (cache the p… |
| missing-data | 3 | 5 edits | Two action items are subjective restructures/rewrites and were left unapplied to avoid altering the (correct) teaching c… |
| mixed-family-extractors | 3 | 7 edits | Doc-coherence with capability-status doc 61 is unresolved and left for the maintainer. docs/design/61-capability-status.… |
| morphometrics | 3 | 6 edits | Two flagged items were left for the maintainer as editorial/cross-file decisions. (1) Title vs navbar-label mismatch: th… |
| ordinal-probit | 3 | 4 edits | — |
| phylogenetic-gllvm | 3 | 2 edits | Three items were too structural/risky to auto-apply and need the maintainer. (1) The two-section cut + migration (Reacti… |
| profile-likelihood-ci | 3 | 4 edits | None. All four surgical edits in the action were safe to apply and verified against R/. The action's optional alternativ… |
| psychometrics-irt | 3 | 4 edits | Fully replacing fit_cfa$report$Lambda_B with the exported extract_rotated_loadings_table() (and correspondingly compare_… |
| random-regression-reaction-norms | 3 | 5 edits | — |
| random-slopes-nongaussian | 3 | 3 edits | The eval=FALSE headline evidence cells for phylo_dep and spatial_indep were intentionally left as-is (the action directs… |
| response-families | 2 | 7 edits | Item 7 (set eval=TRUE on the two single-family fits so the page carries rendered evidence) was NOT applied. The example … |
| roadmap | 2 | 0 edits | The entire action requires maintainer judgment; nothing was auto-applied, because the target article vignettes/articles/… |
| simulation-recovery-validated | 4 | 2 edits | The headline fix — renaming the file/slug from `simulation-recovery-validated` to an honest name (e.g. `simulation-recov… |
| simulation-verification | 3 | 4 edits | Optional trim of section 5 (profile-curve shape taxonomy) to a short pointer was left for the maintainer: it is a subjec… |
| troubleshooting-profile | 3 | 5 edits | Two MINOR items from the audit were left as-is because they are editorial, not defects: (a) the 'When to switch to boots… |

## Notable correctness fixes landed
- **joint-sdm** — resolved a Ψ estimated-vs-set self-contradiction (verified against `R/`; the agent correctly overrode Fable's literal line instruction after checking the code).
- **morphometrics** — removed all six duplicate blocks from an old botched merge; the flagship tutorial is now clean.
- **animal-model** (the QG article) — de-scaffolded (triple banner → one), register codes stripped from reader prose. NOTE: the `$report$lam_phy`/`Lambda_phy` reach-ins for h²/loadings could **not** be swapped to an exported accessor (none exists for phylo loadings) — flagged for a maintainer/Codex follow-up.
- **gllvm-vocabulary** — the `animal_slope()` claim (advertised as the reaction-norm tool but a do-nothing parser stub) flagged; QG-section trim left as a maintainer editorial call.

## `_pkgdown.yml` changes
- Dropped the 2 cut articles from the navbar + article index; swept their dangling links (choose-your-model, simulation-verification).
- Fixed the duplicate listing (`lambda-constraint` / `lambda-constraint-suggest` were in both *Model Guides* and *Under-audit*; now only under-audit — the confirmatory-loadings path is parked).
- Added the 26 previously-ungrouped exports to the reference index (new **Profile-likelihood confidence intervals** group + a **Deprecated and compatibility aliases** group). `pkgdown::check_pkgdown()` passes.

## Follow-ups for the maintainer (editorial / live-render / Codex-lane)
Several "improve" items need judgment, a larger fixture, or a live R render and were deliberately left:
- **animal-model**: The internal reach-ins for the CENTRAL quantities cannot be swapped to the exported API because no exported phy-tier accessor exists: (1) single-trait h^2 in Tutorial 1 pulls V_A from fit1$report$lam_
- **api-keyword-grid**: The 4x4-vs-4x5 grid-arity mismatch (action item 5) is left unresolved. This article presents a 4x4 grid after dropping the soft-deprecated unique() column, but CLAUDE.md and _pkgdown.yml still describ
- **choose-your-model**: Action point 3 (destination gating) is the only unapplied item: the article still routes to four non-public 'internal draft' pages (behavioural-syndromes.html, phylogenetic-gllvm.html, animal-model.ht
- **convergence-start-values**: Two action items were left unapplied as too risky/editorial for a surgical pass: (3) De-duplicating the opening 'Fit A Small Model' + 'Read Fit Health' sections against fit-diagnostics.Rmd — this is a
- **covariance-correlation**: None of the required edits were too risky to auto-apply. The optional overlap-boundary note (stating this article owns the Sigma decomposition mechanism vs. pitfalls.html and behavioural-syndromes.htm
- **cross-lineage-coevolution**: Nothing blocking. Two items the audit noted but that are out of scope for a surgical cleanup and left for the maintainer: (a) the article reproduces zero real numbers because every heavy chunk is eval
- **functional-biogeography**: Two editorial/risky pieces were left: (1) the deeper half of action item (1) -- bumping the fixture to n_sites>=50 / n_species>=50 so recovery claims are literally earned -- is a DGP/code change (and 
- **gllvm-vocabulary**: The Quantitative-genetics section trim (action item 3) is too editorial to auto-apply: it asks to trim the section to terms used by currently-public articles and move kinship, reaction norm, three-pie
- **joint-sdm**: Action item (5) not applied: the vague loading-constraint pointer (See also, final section: 'the full public loading-constraint teaching path is still under article-council review') should be replaced
- **lambda-constraint**: The primary ship-blocker in the action is NOT auto-applied because it requires running/rendering R and is a broad rewrite, both outside surgical scope. Two mutually exclusive maintainer paths for the 
- **lambda-constraint-suggest**: Three of the four action items are too heavy/editorial to auto-apply surgically: (1) Make the payoff render (cache the profile_retention + data-driven refits so the model-comparison table and the two 
- **missing-data**: Two action items are subjective restructures/rewrites and were left unapplied to avoid altering the (correct) teaching content: (1) TRIM the opening -- replacing the ~80-line phase-by-phase 'shipped v
- **mixed-family-extractors**: Doc-coherence with capability-status doc 61 is unresolved and left for the maintainer. docs/design/61-capability-status.md:119 still marks delta/hurdle latent-scale correlation as 'blocked' with 'Do n
- **morphometrics**: Two flagged items were left for the maintainer as editorial/cross-file decisions. (1) Title vs navbar-label mismatch: the article title is 'Individual morphometrics: the simplest GLLVM' while _pkgdown
- **phylogenetic-gllvm**: Three items were too structural/risky to auto-apply and need the maintainer. (1) The two-section cut + migration (Reaction norms ~423-586 → random-regression-reaction-norms.Rmd; Trait covariance acros
- **profile-likelihood-ci**: None. All four surgical edits in the action were safe to apply and verified against R/. The action's optional alternative for point (3) — promoting the tmbprofile_wrapper variance-component example to
- **psychometrics-irt**: Fully replacing fit_cfa$report$Lambda_B with the exported extract_rotated_loadings_table() (and correspondingly compare_loadings() against Lambda_true) rather than only annotating it. The accessor exi
- **random-slopes-nongaussian**: The eval=FALSE headline evidence cells for phylo_dep and spatial_indep were intentionally left as-is (the action directs keeping them for the Tier-3 draft). Reproducible-on-render evidence for those t
- **response-families**: Item 7 (set eval=TRUE on the two single-family fits so the page carries rendered evidence) was NOT applied. The example chunks reference `df_long`, `df_wide`, and a `df_long$family` selector that are 
- **roadmap**: The entire action requires maintainer judgment; nothing was auto-applied, because the target article vignettes/articles/roadmap.Rmd has no defect of its own (the wrapper is correct) and all fixes fall
- **simulation-recovery-validated**: The headline fix — renaming the file/slug from `simulation-recovery-validated` to an honest name (e.g. `simulation-recovery-smoke-grid`) — was NOT auto-applied. It is a repo-wide rename with real ripp
- **simulation-verification**: Optional trim of section 5 (profile-curve shape taxonomy) to a short pointer was left for the maintainer: it is a subjective editorial restructure, not a correctness fix, and the section already cross
- **troubleshooting-profile**: Two MINOR items from the audit were left as-is because they are editorial, not defects: (a) the 'When to switch to bootstrap' section overlaps the sibling article's fallback list -- consolidating to a