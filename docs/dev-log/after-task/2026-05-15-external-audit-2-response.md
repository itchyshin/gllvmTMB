# 2026-05-15 -- External audit #2 response (triage + canon update)

**PR type tag**: audit + dev-log

## Scope

A second external audit landed 2026-05-15 evening, titled
*"Architectural Review and Strategic Evaluation of the drmTMB and
gllvmTMB Statistical Computing Frameworks"*. The audit explicitly
acknowledged it did not have access to the source code (*"explicit
source code repositories... remain in restricted, private, or
temporarily inaccessible development states"*), so its
recommendations were back-inferred from the lab's published
track record plus general TMB / GLLVM theory.

This PR records the triage and the two queued action items it
produced. It is a docs-only PR.

## Files changed

- `docs/dev-log/audits/2026-05-15-external-audit-2-response.md`
  (NEW): full triage document. Tags each audit recommendation as
  {already-shipped, new-action, hallucinated/confused}. Catalogues
  9 already-shipped items, 2 new actions, 4 hallucinations.
- `docs/dev-log/decisions.md`: appended a 2026-05-15 evening entry
  summarising the triage decision and the two queued actions.
- `docs/dev-log/after-task/2026-05-15-external-audit-2-response.md`
  (this file).

## Triage summary

**Already-shipped (audit recommends what we already do)**:

1. Rotation-invariance constraints on $\boldsymbol{\Lambda}$ --
   inherited from `glmmTMB::rr()` since 0.2.0.
2. `equalto` known-variance paradigm -- shipped as
   `meta_known_V(value, V = V)` + `block_V()` helper.
3. Model selection / CV for number of latent factors --
   `check_identifiability()` (PR #105) covers the
   spurious-extra-factor case via Procrustes alignment.
4. Bias correction / coverage module -- `coverage_study()`
   (PR #122) with the audit-1 ≥ 94% gate.
5. Hessian / Laplace breakdown diagnosis --
   `gllvmTMB_check_consistency()` (PR #121) +
   `sanity_multi()` (already in main).
6. Visual interpretation aids -- `confint_inspect()` (PR #120)
   for profile-curve verification with diagnostic flags.
7. Robust multi-start -- the P0 fix from earlier today
   (`R/fit-multi.R:1700-1702`) is bundled in PR #122.
8. Pedagogical GitHub Pages -- 13 Phase 1c articles in main
   once #126-#129 land. Concepts tier includes the audit-style
   pedagogy slots (`gllvm-vocabulary`,
   `data-shape-flowchart`, `troubleshooting-profile`,
   `simulation-verification`).
9. Continuous integration across R versions -- 3-OS
   R-CMD-check on every push + PR.

**Genuinely new (resolution after 2026-05-15 evening refinement)**:

- **A1 (deprioritised: "stay Laplacian", maintainer 2026-05-15
  evening)**: the audit's adaptive Gauss-Hermite quadrature
  prescription is theoretically correct but practically
  low-impact at the gllvmTMB user base's typical data shapes
  (20--50 items per person, $d = 2$--$3$; $\ge 20$ species per
  site for JSDM). Literature (Pinheiro & Chao 2006; Joe 2008;
  Niku et al. 2017, 2019) shows Laplace and AGHQ agree to 3
  decimals on most parameters in this regime. Resolution: no
  engine implementation; single-paragraph pedagogy note in
  `psychometrics-irt.Rmd` (Phase 1e) routing problematic
  cases to `mirt` (AGHQ-capable) or Bayesian alternatives.
- **A2 (Phase 1e)**: single-paragraph "measurement error vs
  biological heterogeneity" callout. Bundled into the Phase
  1e Rose+Darwin reframe sweep PR (probably with `pitfalls.Rmd`).
- **A3 (new, higher-priority post-CRAN integrator candidate)**:
  variational approximation (VA) for high-$d$ binary JSDM. The
  regime where Laplace genuinely degrades and AGHQ is
  infeasible anyway. Still not committed; implement only if
  Phase 5.5 external validation surfaces real user cases.

**Hallucinated / confused (4 items, recorded for the canon)**:

- Misattribution of the `rr() / equalto` paper to
  "Williams + Nakagawa" -- the actual paper is McGillycuddy,
  Popovic, Bolker, Warton 2025.
- Cross-pollination with `pigauto` as a major near-term
  opportunity -- speculative; long-horizon Phase 6 idea.
- Blurring drmTMB and gllvmTMB into "one coordinated pipeline"
  -- per `CLAUDE.md`, they have deliberately separate scopes.
- Reference [1] cited as "Williams-McGillycuddy" -- citation
  confusion of the meta-analysis paper and the rr()/equalto
  paper.

## Test plan / verification

- [x] No code changes; docs-only PR.
- [x] `pkgdown::check_pkgdown()` not affected (no Rmd or
  NAMESPACE changes).
- [x] Banned-pattern self-audit (per Kaizen 11): no `[f()]`
  without parens; no `[vignette(...)]`; no `[0, 1]` interval
  autolinks.
- [x] Cross-references to PR numbers verified against
  `gh pr list --state merged`.

## Roadmap tick

No `ROADMAP.md` row status change. This is a triage filing;
the two queued action items will tick rows when they execute:
- A1 will tick a Phase 6 / 0.3.0 row when scoped.
- A2 will tick `Phase 1e` when the reframe sweep PR opens.

## What went well

- The triage discipline established by audit #1 earlier today
  (the multi-start `obj$report()` audit) gave us a clean
  template: tag findings as {already-shipped, new-action,
  hallucinated/confused}, file the response under
  `docs/dev-log/audits/`, append a decisions.md entry. Same
  shape for audit #2. The triage took ~30 min once the
  framework was clear.
- Audit #1 vs audit #2 contrast is now durable in the canon:
  one audit read the code and produced a P0 fix; the other
  pattern-matched on public outputs and produced two queued
  items. The decisions.md entry articulates this distinction
  so we don't conflate the two kinds of audit signal in
  future.
- Recording the 4 hallucinations is protective: a later
  inferred-from-track-record audit might re-introduce the
  same false claims (e.g. "Williams + Nakagawa introduced
  `equalto`"), and the canon now has the correct citation on
  file.

## What did not go smoothly

- No major friction. The audit was substantial in word count
  but low in new information density; the time cost of
  triage was mostly in reading the audit carefully to
  distinguish "real concern we already addressed" from "real
  concern that's new". 9-to-2 ratio.

## Team learning (per AGENTS.md Standing Review Roles)

- **Rose** (pre-publish audit): The triage matrix
  ({already-shipped, new-action, hallucinated/confused}) is
  the right canonical shape for any external audit response.
  Every audit gets this treatment so we don't accumulate
  shadow backlog from speculative recommendations.
- **Jason** (literature scout): An audit that doesn't read
  the code but quotes the lab's published outputs accurately
  is a useful **confidence check** that our published record
  represents the actual package state. A reader who comes in
  cold should be able to predict roughly the right feature
  set from our recent papers / pkgdown / R-universe. This
  audit shows that's working.
- **Fisher** (statistical inference): The audit's Gauss-Hermite
  prescription for sparse Bernoulli is correct and not
  addressed by the current engine. Queued post-CRAN
  appropriately. Phase 5.5 external validation sprint may
  surface specific cases where this is actually limiting (vs
  theoretically limiting); if so, escalate priority.
- **Gauss** (numerical correctness): The audit's TMB substrate
  background section is correct -- AD + Laplace + sparse
  Cholesky -- but not novel. The audit's drmTMB sections are
  largely orthogonal to gllvmTMB's lane per the CLAUDE.md
  scope split.
- **Pat** (applied PhD user): The "measurement error vs
  biological heterogeneity" callout (A2) is good defensive
  pedagogy that I'd not have prompted us to add otherwise.
  Single-paragraph addition during Phase 1e is the right
  scope. The audit's framing here is genuinely useful for
  the applied-ecology reader.

## Follow-up

- A1: when Phase 6 / 0.3.0 scoping starts, evaluate the
  adaptive Gauss-Hermite implementation cost against the
  diagnostic-only approach (`check_consistency()` plus a
  troubleshooting note in `troubleshooting-profile.Rmd`).
- A2: bundle the "measurement error" callout into the Phase
  1e Rose+Darwin reframe sweep PR.
- No PR sequencing implications: this PR is independent of
  the in-flight Phase 1c PRs (#126-#129) and can land in any
  order.

## Closing observation

This response codifies a discipline that will pay off as more
external readers engage with the package: distinguish *audits
that read the code* (high signal, can produce blocking fixes)
from *audits that synthesise from the published record* (useful
calibration of how the published artefacts represent us, but
prescribe what we already do). Both are valuable; they
warrant different scoping.
