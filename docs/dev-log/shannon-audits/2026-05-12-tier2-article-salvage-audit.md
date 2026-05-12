# Shannon Audit: Tier-2 Reference Article Salvage from `gllvmTMB-legacy`

**Trigger**: PR #37 dispatch queue item #2 — "Tier-2 reference
article salvage audit." Codex's 2026-05-12 legacy excavation
identified six candidate Tier-2 articles ready to port; this
audit enumerates the full set of legacy `vignettes/articles/`
candidates and assigns a verdict to each.

**Prerequisite check**: PR #37 (dispatch queue) is merged;
PR #38 (archive scope) is merged; PR #39 (Codex sweep) is in
flight pending the maintainer's `extract_correlations` revert.
Codex's "do not interleave legacy port with sweep" rule still
holds, but this audit is read-only and produces only a doc, so
it runs in parallel with the sweep PR without scope collision.

**Output**: a sorted dispatch queue for Codex's *next* bounded
task after the in-flight sweep settles. Each row is a single
article with a verdict and rationale. Order: **port to Tier-2**
first (highest user-leverage), then **port to internal docs/**,
then **leave archived** (Tier-3 essays + out-of-scope demos).

## Methodology

Legacy candidates: every `.Rmd` file in
`/Users/z3437171/Dropbox/Github Local/gllvmTMB-legacy/vignettes/articles/`
that is not already in the current
`vignettes/articles/` directory and not already accounted for
in:

- PR #37 dispatch queue item #1 (phylogenetic / two-U doc-validation
  lane) -- `phylogenetic-gllvm.Rmd`, `two-U-phylogeny.Rmd`,
  `morphometric-phylogeny.Rmd` (when distinct from current
  `morphometrics.Rmd`).
- PR #38 archive list -- `cross-package-validation.Rmd`,
  `simulation-recovery.Rmd`, `stacked-trait-gllvm.Rmd`,
  `morphometric-phylogeny.Rmd`.

That leaves 15 candidate articles for this audit.

For each candidate the verdict is:

- **Port to Tier-2** -- the article covers a feature the current
  package already supports, and the article is a worked example
  / reference that would help users. Codex ports as one PR per
  article using the long-or-wide framing.
- **Port to internal `docs/`** -- the content is developer-
  facing reference, not user-facing. Lives under `docs/design/`
  or `docs/dev-log/` rather than `vignettes/articles/`.
- **Leave archived** -- legacy Tier-3 essay, out-of-scope demo,
  or content that depends on unimplemented features. Cross-link
  from a Tier-1/Tier-2 page only if needed.

The verdict is *advisory* -- when Codex ports an article, the
porting PR's roles (Boole for grammar, Gauss for math, Pat for
applied clarity, Rose for consistency) re-verify before the PR
opens.

## Dispatch queue (Tier-2 ports, priority order)

### #1 -- `api-keyword-grid.Rmd`

- **Verdict**: port to Tier-2 (top priority).
- **Rationale**: the 3 x 5 keyword grid is the canonical syntax
  table for `gllvmTMB`. Already documented in `AGENTS.md` /
  `CLAUDE.md` (and now in the design doc 02), but a dedicated
  Tier-2 article is the natural reference for users who want a
  single page enumerating every `latent / unique / indep / dep
  / scalar` cross `none / phylo_ / spatial_` cell. Highest
  leverage.
- **Port notes**: confirm each grid cell against the current
  source (the grid has not changed since PR #14 ratification);
  long+wide example for at least the `latent + unique` cell.
- **Sugar caveat**: under PR #39's compact-RHS sugar
  (pending merge), the keyword examples can use the short form
  (`latent(1 | unit, d = K)`) for the wide-formula path.

### #2 -- `response-families.Rmd`

- **Verdict**: port to Tier-2.
- **Rationale**: 15 supported families is a real user reference.
  The current package supports the full set named in
  `R/families.R`; an article enumerating them with a one-cell
  worked example per family is high-leverage Tier-2.
- **Port notes**: cross-reference each family against the
  current `R/families.R`; drop families legacy supported but
  current doesn't; add families current supports but legacy
  didn't (e.g., the canonical `ordinal_probit()` if absent in
  legacy).

### #3 -- `ordinal-probit.Rmd`

- **Verdict**: port to Tier-2.
- **Rationale**: `ordinal_probit()` is a gllvmTMB-native family
  with `sigma_d = 1` fixed exactly (per the design doc). It
  deserves its own walk-through showing why the latent-scale
  variance is what users want. High user-leverage when ordinal
  data lands.
- **Port notes**: keep the math centred on the latent-scale
  variance, not delta-method approximations. Use long+wide
  pairing.

### #4 -- `mixed-response.Rmd`

- **Verdict**: port to Tier-2.
- **Rationale**: mixed-family fits (`family = list(...)` keyed
  by trait) are supported in the current code path. A walk-
  through showing one model with Gaussian + binomial + Poisson
  rows is a strong applied demo.
- **Port notes**: confirm the `family = list(...)` API still
  works after the Phase 3 weights helper; this should fit the
  paired byte-identical contract from `docs/design/02-data-shape-and-weights.md`.

### #5 -- `profile-likelihood-ci.Rmd`

- **Verdict**: port to Tier-2.
- **Rationale**: profile-CI is one of the four CI methods in
  `extract_correlations()` / `extract_communality()`. A
  dedicated reference explaining the Lagrange-style fix-and-refit
  mechanics is genuinely useful Tier-2 content.
- **Port notes**: depends on the PR #39 `extract_correlations`
  default-name decision (currently `"fisher-z"`; flip-then-revert
  in flight). Whatever the final default, the profile-CI article
  uses `method = "profile"` explicitly so it's stable.

### #6 -- `lambda-constraint.Rmd`

- **Verdict**: port to Tier-2 *conditional on* `lambda_constraint`
  being supported in current code.
- **Rationale**: GALAMM-style confirmatory factor analysis is a
  niche but high-value Tier-2 use case. Requires the
  `lambda_constraint` / `suggest_lambda_constraint` machinery.
- **Port notes**: verify
  `R/lambda-constraint.R` and `R/suggest-lambda-constraint.R`
  are still present and functional; the current `R/` does carry
  these files. Port if the API matches; defer if the
  legacy article assumes a deprecated API.

### #7 -- `psychometrics-irt.Rmd`

- **Verdict**: port to Tier-2 (lower priority than #1-#6).
- **Rationale**: CFA / IRT with mixed-response items is a
  cross-domain demo that broadens the audience beyond
  ecology/evolution. Useful for the methods-paper push.
- **Port notes**: depends on `ordinal_probit()` + mixed-response
  + lambda-constraint all being working. Port AFTER #3 + #4 +
  #6 land so the building blocks are verified.

### #8 -- `behavioural-personality-with-year.Rmd`

- **Verdict**: port to Tier-2 (lower priority).
- **Rationale**: crossed-cluster designs (year x individual) are
  a real applied use case. Not covered by the current
  `behavioural-syndromes.Rmd` article (which is single-level).
  Demonstrates the engine's crossed-cluster support without
  invoking `phylo_*` / `spatial_*`.
- **Port notes**: verify the current code's `cluster` + `unit_obs`
  grammar handles year x individual crossed without errors.

### #9 -- `three-level-personality.Rmd`

- **Verdict**: port to Tier-2 (lower priority).
- **Rationale**: strictly nested 3-level designs (individual /
  session / population) are a complementary applied use case to
  #8. Together they demonstrate the engine's `unit / unit_obs /
  cluster` flexibility.
- **Port notes**: verify nesting semantics; the current package
  notes both crossed and nested designs fit (per `R/gllvmTMB.R`
  `@param cluster` roxygen), so this article should be in scope.

### #10 -- `phylo-spatial-meta-analysis.Rmd`

- **Verdict**: port to Tier-2 *after* item #1 phylogenetic
  doc-validation lane lands.
- **Rationale**: a unified phylogenetic + spatial +
  meta-analysis demo is the ambitious "everything together"
  Tier-2 piece. Builds on the phylo / two-U work, the
  `spatial_*` keywords, and the `meta_known_V` machinery. High
  showcase value once each component is documented separately.
- **Port notes**: hold until item #1 lands; this article is
  essentially "item #1 + spatial + meta" combined.

## Internal-docs ports (developer reference, not Tier-2)

### #11 -- `tests.Rmd` -> port to `docs/design/` or `docs/dev-log/`

- **Verdict**: port to internal docs as `docs/design/04-test-suite-structure.md`
  or similar.
- **Rationale**: "what gllvmTMB verifies, with live pass/fail" is
  developer-facing reference, not a user article. Lives more
  naturally next to the test-classification audit (planned for
  Phase 4) than in the public pkgdown navbar.
- **Port notes**: drop the "live pass/fail" framing; replace
  with a structured taxonomy (smoke / recovery / identifiability)
  matching what Phase 4 will codify.

## Leave archived

### #12 -- `spde-vs-glmmTMB.Rmd`

- **Verdict**: leave archived.
- **Rationale**: "Why gllvmTMB" is a positioning essay, not a
  worked example. The README + `docs/dev-log/decisions.md`
  archive entry already capture the scope rationale. Cross-link
  to legacy if a user asks.

### #13 -- `random-slopes-personality-plasticity.Rmd`

- **Verdict**: leave archived **until** random slopes land in
  current code.
- **Rationale**: random slopes are explicitly "planned work"
  per the `README.md` "Current boundaries" section. The article
  assumes a feature not yet implemented. When random slopes
  ship, this article is a natural Tier-2 port.
- **Port notes**: file under "Phase 6 / methods-paper extensions"
  in `ROADMAP.md` rather than the Tier-2 salvage queue.

### #14 -- `corvidae-two-stage.Rmd`

- **Verdict**: leave archived.
- **Rationale**: a domain-specific two-stage proxy demo. The
  underlying machinery (`R/two-stage.R`) exists in the current
  repo, but a Corvidae-specific example is too narrow for Tier-2;
  if two-stage workflow needs a Tier-2 article, write a new one
  with a generic dataset.

## Suggested overall sequence (Tier-2 port queue)

When Codex is free of the sweep + the phylo / two-U doc-validation
lane (item #1 from PR #37), this Tier-2 queue is the next
substantive Codex work. One PR per article, in priority order:

1. `api-keyword-grid.Rmd` (single-PR Tier-2)
2. `response-families.Rmd`
3. `ordinal-probit.Rmd`
4. `mixed-response.Rmd`
5. `profile-likelihood-ci.Rmd`
6. `lambda-constraint.Rmd` (after verifying the API is current)
7. `psychometrics-irt.Rmd` (after #3, #4, #6 land)
8. `behavioural-personality-with-year.Rmd`
9. `three-level-personality.Rmd`
10. `phylo-spatial-meta-analysis.Rmd` (after item #1 phylo lane)
11. `tests.Rmd` -> internal `docs/` only, not Tier-2

Articles #12-#14 stay archived; one of them (random-slopes)
re-enters the queue when its feature lands.

## Implementation reminders (carry over to each port PR)

- Each port follows the PR #14 canonical long+wide snippet
  pattern. When PR #39's sugar lands, wide-formula examples can
  use the compact `traits(...) ~ 1 + ...` form.
- Math notation uses `S` / `s` per PR #40's naming-convention
  entry, not `U`.
- Each port adds a `vignettes/articles/<slug>.Rmd` plus updates
  to `_pkgdown.yml` (Tier-1 vs Tier-2 group) plus an after-task
  report at branch start.
- Rose pre-publish gate runs on each port PR.
- Each port's PR description states which legacy article was
  the source and how it was adapted (vocabulary, formula
  grammar, helper names) -- the same discipline Codex used in
  the sweep PR #39.

## Shannon checklist (state at this audit's time)

| # | Check | Result |
|---|---|---|
| 1 | PR + after-task pairing | ✅ all six 2026-05-12 Claude merges have paired reports; PR #40 (in flight) has its at-branch-start; this audit also at branch start |
| 2 | Working-tree hygiene | ⚠️ main repo checkout is still on Codex's `codex/long-wide-example-sweep` (PR #39 in flight); do not touch the working tree |
| 3 | Cross-PR file overlap | ✅ this audit doc lives in `docs/dev-log/shannon-audits/`; no overlap with PR #39 (R / vignettes / man / etc.) or PR #40 (decisions.md naming entry) |
| 4 | Branch / PR census | 2 open PRs (#39, #40); after this PR opens, WIP=3 (at cap). All 24 stale origin branches cleaned (12 first pass + 12 straggler pass) |
| 5 | Rule-vs-practice drift | ⚠️ PR #39 scope expansion (sugar + restore + extract_corr default change) is the one drift; surfaced in chat to maintainer; revert ask outstanding |
| 6 | Sequencing | ✅ this audit produces queue for Codex's *next* task after PR #39 + item #1 phylo lane; not a parallel competitor |

**Verdict: PASS** with the one drift note (PR #39's scope expansion
already surfaced to maintainer; revert ask in flight). This
audit prepares the next Codex dispatch and does not interfere
with the in-flight resolution.
