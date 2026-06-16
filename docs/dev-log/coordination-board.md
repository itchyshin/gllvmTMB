# Agent Coordination Board

**Purpose.** Single live status doc both agents (Claude, Codex)
edit so that "what is the other agent working on right now?" has
a one-file answer. Complements the existing channels:

- `docs/dev-log/shannon-audits/` -- per-pass audit snapshots
  (point-in-time deliverables).
- `docs/dev-log/check-log.md` -- durable append-only lessons
  learned (per PR #22 codification).
- `docs/dev-log/after-task/*.md` -- per-PR retrospectives.
- `docs/dev-log/while-away/*.md` -- overnight reports to the
  maintainer.
- PR comments + descriptions -- real-time discussion.

This file is **live**: replace stale entries rather than
appending. Sections "Active lanes" and "Pending coordination
questions" should be edited as state changes. The "Recently
resolved" section is a 24-48 hour rolling window; older items
move to per-PR after-task reports or the check-log.

## 2026-06-16 Twin Finish Programme Reset

Current Codex state:

- `codex/twin-truth-and-issue-map` is committed locally at `33287b1`.
- `codex/bridge-gate-registry` is committed locally at `2324646`.
- `codex/engine-julia-draft-landing` is committed locally through `6701ae5`
  and carries the draft-landing readout plus the Xcoef structural-zero
  addendum.
- `codex/r-bridge-grouped-dispersion` is the current implementation/evidence
  branch. It has local grouped-dispersion, per-trait ordinal, Gamma shared-route,
  one-part no-X response-mask, complete-response fixed-effect-X,
  `coef()` / `summary()`, direct-wrapper CI/status, grouped post-fit, and
  ordinal probability/class prediction bridge evidence through the current
  Codex slice.
- No GitHub PR is open for this programme yet.

Current bridge landing state:

- `origin/engine-julia` is at `9aed585` and differs from `origin/main`
  by `18 74` commits.
- Synthetic merge conflict scan reports conflicts in `NAMESPACE`,
  `NEWS.md`, `cran-comments.md`, `docs/dev-log/check-log.md`, and
  `man/gllvm_julia_fit.Rd`.
- The paired bridge runtime is `GLLVM.jl-integration` at `ab8c4e4`;
  the main `GLLVM.jl` checkout on `codex/non-gaussian-fitter-gradients`
  is salvage-only for this lane.

Active lane guidance:

- Keep CRAN-main and bridge landing separate until Ada chooses release
  timing.
- Do not close `#483`, `#485`, `#486`, or `#488` from chat memory.
- Before a draft bridge PR is opened, use the body and conflict plan in
  `docs/dev-log/2026-06-16-engine-julia-draft-landing.md`.
- New planned lane from the GLLVM team note:
  `codex/xcoef-structural-zero-spec`. Scope is a structural-zero mask for
  selected entries of the species/trait-specific fixed-effect coefficient
  matrix. Keep it separate from observation-by-response covariates
  (`z[i, j, k]`) and from response-mask / missing-data lanes. See
  `docs/dev-log/2026-06-16-xcoef-structural-zero-plan-addendum.md`.
- Current per-trait nuisance-parameter contract:
  `docs/dev-log/2026-06-16-julia-per-trait-dispersion-cutpoints-spec.md`.
  It records that `GLLVM.jl-integration` has grouped dispersion fitters for
  NB2/NB1/Beta/Gamma and per-trait ordinal cutpoints, while the R bridge row
  remains partial until parity evidence, CI/status, and claim wording agree.
  Follow-up audit:
  `docs/dev-log/2026-06-16-nb1-gamma-bridge-parameterisation-audit.md`.
  NB1 is on the same scale as native `phi_nbinom1` and now has
  fixed-parameter kernel evidence, no-latent fitted-object parity, and selected
  reduced-rank (`d = 1`) fitted-object point parity on the small complete
  balanced bridge fixture. Gamma now uses shared grouped-Gamma routing in the
  bridge to match the current native scalar-`sigma_eps` Gamma oracle on the
  small complete balanced reduced-rank fixture (`df = 5`, native-vs-Julia
  `logLik` delta about `2.8e-07`); native per-trait Gamma remains a later
  expansion, not a current claim. The earlier reduced-rank audit
  `docs/dev-log/2026-06-16-nb1-reduced-rank-parity-audit.md` is superseded by
  `docs/dev-log/2026-06-16-nb1-reduced-rank-fisher-fix.md`; the paired Julia
  fix stabilised tiny-`phi` NB1 Fisher information near the Poisson boundary.
  Gamma no longer uses per-trait bridge grouping for current-oracle parity.
  The R bridge now passes response masks through to the paired Julia mask
  contract for one-part no-X point fits in Poisson, Bernoulli binomial, NB2,
  NB1, Beta, Gamma, ordinal, and ordinal-probit rows. Gaussian masks,
  mixed-family masks, X+mask, and masked CIs remain loud gates.
  The R bridge now also registers `coef()`, `summary()`, and scoped no-X
  `confint()` methods for `gllvmTMB_julia` objects. Direct
  `gllvm_julia_fit(..., ci_method = "wald" / "profile" / "bootstrap")` calls
  can request no-X CI payloads for Gaussian, Poisson, and Bernoulli binomial
  rows. Ordinary `gllvmTMB(..., engine = "julia", ci_method = "wald" /
  "profile" / "bootstrap")` fits can request the same admitted no-X CI payloads
  at fit time, and they retain their bridge input so `confint(fit, method =
  "wald" / "profile" / "bootstrap")` can recompute those payloads post-fit.
  Grouped-dispersion CIs, per-trait ordinal CIs, masked CIs, mixed-family CIs,
  and X-row CIs remain gated. Retained-score `predict()` / `fitted()` /
  response-Pearson
  `residuals()` are now routed for the live-tested no-X Gaussian, Poisson,
  Bernoulli, NB2, NB1, Beta, and Gamma rows. Ordinal and ordinal-probit bridge
  rows now route response-scale category probabilities and modal-class
  predictions from the retained score/cutpoint payload. Scalar-response
  conditional in-sample `simulate()` is now routed for Gaussian, Poisson,
  Bernoulli binomial, NB2, NB1, Beta, and Gamma rows and keeps masked response
  cells as `NA`. Unit-tier covariance and raw ordination accessors are now
  routed on the retained engine scale through `extract_Sigma()`,
  `extract_Sigma_B()`, `getResidualCov()`, `getResidualCor()`,
  `extract_ordination()`, `getLoadings()`, and `getLV()`. `newdata`
  prediction/simulation, unconditional random-effect redraws, ordinal
  residuals/simulation, mixed-family residuals/simulation, link-residual
  augmentation, rotations, structured-tier extractors, and richer extractor
  parity remain gated.
  The R bridge also routes complete-response fixed-effect-X point fits for
  Gaussian, Poisson, Bernoulli binomial, NB2, Beta, and Gamma rows. For
  non-Gaussian rows the main dispatch requires the canonical `0 + trait + ...`
  fixed-effect design and sends only the extra fixed-effect columns to
  `GLLVM.bridge_fit(X = ...)`, matching the paired Julia `fit_gllvm_cov`
  contract. NB1-X, ordinal-X, mixed-family-X, masks+X, CIs for X rows, and
  non-canonical fixed-effect designs remain gated.
- Cross-twin argument and wording contract:
  `docs/dev-log/2026-06-16-cross-twin-argument-wording-contract.md`.
  Before bridge, engine, or public-docs lanes, scan R/Julia and DRM/GLLVM
  wording for `engine = "julia"`, future `engine_control`, response masks,
  `Xcoef_mask` / `Xcoef_fixed`, per-trait dispersion, ordinal cutpoints,
  REML / AI-REML, CI-status columns, and `pdHess`. Share meanings where the
  model concept is the same; keep package-specific names where DRM and GLLVM
  target different estimands.
- MultiTraits visual-scout note for the later public-learning-path lane:
  borrow the applied teaching pattern from `biodiversity-monitoring/MultiTraits`
  (named ecological modules, fast example data, trait-strategy spaces, and
  trait-network/multilayer-network displays), but compute gllvmTMB visuals from
  model-estimated `Sigma`, fitted values, diagnostics, and uncertainty/status
  rather than raw trait correlations. Check GPL-3/provenance before reusing data
  or code; prefer an independent example implementation.
- Grouped post-fit score payload lane:
  paired `GLLVM.jl-integration` now returns finite `n x K` scores for grouped
  NB2, NB1, Beta, and shared-Gamma bridge rows through `getLV()`; the R bridge
  admits retained-payload `predict()` / `fitted()` / response-Pearson
  `residuals()` plus conditional in-sample `simulate()` and raw unit-tier
  covariance/ordination accessors for those grouped rows. Grouped-dispersion
  CIs, richer extractor parity, unconditional simulation, and broad parity
  remain later rows.
- Ordinal probability/class prediction lane:
  R now converts retained ordinal and ordinal-probit score/cutpoint payloads to
  response-scale category probabilities and modal-class predictions. Ordinal
  residuals, ordinal-X, per-trait ordinal CIs, and `newdata` prediction remain
  later rows.
- Next safe implementation lane: grouped-dispersion CI endpoints/status,
  masked CI/status, richer extractor parity,
  mixed-family admission, NB1/ordinal fixed-effect-X design, X-row CI/status,
  or the native per-trait Gamma expansion spec, unless the maintainer
  explicitly asks to publish or rebase the bridge PR first.

Both agents commit edits to this file with a short message like:

```
coord-board: <agent> picked up <lane>
coord-board: <agent> resolved <question>
```

## Codex-return status (effective 2026-05-18)

**Codex is back for a bounded review / hygiene lane.** The
2026-05-14 Codex-absent assumption is no longer the current
working state, but it remains a useful historical explanation
for why Claude carried several Codex-owned lanes during the
pause.

Current operating rule:

- PR #181 (sparse pedigree A-inverse engine pass-through) and
  PR #182 (M3.4 warm-start + phi-clamp) were reviewed by Codex
  and merged to `main` on 2026-05-18.
- PR #184 (drmTMB-parity hygiene cascade) was green on three OSes
  before merge and merged to `main` on 2026-05-18. Its first
  post-merge main run failed once, then the failed-job rerun recovered.
- PR #186 (red-main M3.4 test hygiene) merged on 2026-05-18 to
  stabilize the smoke-test contract exposed by that failed main run.
- PR #185 (Slice 1 PR slice contract) merged on 2026-05-18.
- PR #187 (CI tiered gates) merged on 2026-05-18; the process-only
  fast-pass behaviour was verified in real CI on PR #188.
- PR #188 (process-only Shannon handoff snapshots) merged on 2026-05-19.
- PR #189 (pkgdown Response families reference index) merged on 2026-05-18.
- PR #195 (Slice 2 after-task templates) merged on 2026-05-19.
- PR #197 (M3.3 production grid workflow) merged on 2026-05-19.
- PR #199 (M3.3 production artifact review) merged on 2026-05-19
  after 3-OS R-CMD-check passed.
- PR #200 (post-M3 ROADMAP evidence refresh) merged on 2026-05-19
  after 3-OS R-CMD-check passed.
- PR #201 (M3.3 failure-mode ledger) merged on 2026-05-19 after
  3-OS R-CMD-check passed.
- PR #202 (M3.3 target-scale audit) merged on 2026-05-19 after
  3-OS R-CMD-check passed.
- PR #203 (CI ignored-source fast path) merged on 2026-05-19 after
  3-OS R-CMD-check passed.
- PR #205 (M3.3 target-explicit pilot grid) merged on 2026-05-19
  after the fast-path R-CMD-check parser gate passed on all three
  OS-named jobs.
- PR #206 (robust modeling diagnostics and starts) merged on
  2026-05-19 after 3-OS R-CMD-check passed on the PR branch.
- PR #207 (M3.3a fit-health pilot metadata) merged on 2026-05-19
  after 3-OS R-CMD-check passed on the PR branch.
- PR #210 (M3.3a `nbinom2` r10 stress pilot evidence) merged on
  2026-05-19 after fast-path R-CMD-check passed on the PR branch;
  post-merge main R-CMD-check and pkgdown also passed.
- PR #211 (M3.3a `nbinom2` target-construction audit) merged on
  2026-05-20 after 3-OS R-CMD-check passed on the PR branch;
  post-merge main R-CMD-check and pkgdown also passed.
- PR #212 (M3.3a corrected `nbinom2` r20 stress audit) merged on
  2026-05-20 after fast-path R-CMD-check passed on the PR branch;
  post-merge main R-CMD-check and pkgdown also passed.
- PR #213 (M3.3a `nbinom2` fitted phi / link-residual diagnostics)
  merged on 2026-05-20 after 3-OS R-CMD-check passed on the PR
  branch; post-merge main R-CMD-check and pkgdown also passed.
- PR #214 (M3.3a `nbinom2` known-phi point diagnostic) merged on
  2026-05-20. Post-merge main R-CMD-check and pkgdown passed.
- PR #215 (M3.3 drmTMB cross-learning checkpoint) merged on
  2026-05-20 after the PR fast-path R-CMD-check passed on all three
  OS-named jobs; post-merge main R-CMD-check and pkgdown also passed.
- PR #219 (issue-ledger after-task protocol) merged on 2026-05-20;
  post-merge main R-CMD-check and pkgdown passed.
- PR #220 (M3.3b surface-admission + diagnostic visualization gate)
  merged on 2026-05-20 after PR R-CMD-check, post-merge main
  R-CMD-check, and pkgdown all passed.
- Both teams should keep write scopes explicit in this file until
  the open PR count returns to zero.

## Active lanes

| Agent | Lane | PR / branch | Files touched | Status |
|---|---|---|---|---|
| Codex | **Phase 56.5 — anchor-adjacent fan-out by backend/risk** (start: `phylo_unique(..., vcv = A_user)`) | branch TBD (PR not yet open) | `tests/testthat/test-relmat-unique-slope-gaussian.R` (remove `skip_until_stage3()` gate, attach recovery + byte-identity + forced-mismatch tests; reuse anchor `b_phy_aug` machinery) | Per Codex 2026-05-26 evidence-first sequencing: with anchor cell green (#298), the fan-out is by **backend / risk grouping**, not one PR per cell. Expected ordering: (a) `phylo_unique(..., vcv = A_user)` first — reuses anchor's `b_phy_aug` machinery directly, smallest delta; (b) `animal_unique` after its bar-form sugar routes to that same path; (c) `spatial_*` after SPDE augmented plumbing; (d) `*_latent` / `*_indep` / `*_dep` after their distinct Σ_b / map semantics ship. **15 skeleton tests remain `skip_until_stage3()`-gated** until each backend lands. Shannon role when PR opens: Rose pre-publish + coord-board sync + after-task cross-reference (same pattern as #289 / #293 / #295 / #298). |
| Claude/Shannon | Standing by post-#298 close-out | — | — | Phase 56.4 close-out PR (this one) lands the #297 → #298 cross-reference, moves the prior 56.4 row to Recently resolved, and queues the new Codex Phase 56.5 lane. **Auto-poll cron `62caabb4` (every 10 min)** running for hands-free pickup; caveat: session-only, may not survive soft session resets — pair with explicit Ada pings on key merges. **A6 prep memo (#291) + #287 §2 pre-spec tidy (#296) both staged**; A6 itself blocked behind Phase 56.5 close. **Hard scope unchanged (Ada 2026-05-26):** the four engine/parser files Codex-owned through Phase 56.x. |

**WIP**: 1 active (Codex Phase 56.5 fan-out; PR not yet open).

**Stack discipline (Shannon, 2026-05-26):** worktrees current after #298 + this PR.

- `gllvmTMB` (main worktree) — at `main` tip `dd3b2be` (#298).
- `gllvmTMB-codex-morphometrics` — Codex's prior morphometrics worktree on `codex/morphometrics-long-wide` (**paused per Codex 2026-05-26**; no Phase 56 reactivation).
- `gllvmTMB-56-4-closeout` — Claude's worktree for the present #298 close-out PR only, branch `agent/phase56-4-merge-closeout`.
- Codex's Phase 56.5 worktree (when started) wherever Codex prefers locally.

## Validation Factory plan — Hidden Article Restoration + Validation (Ada, 2026-05-25)

Coordinated work allocation: **Codex takes validation-heavy and
rendered-QA work; Claude/Shannon holds the r200 + coordination
guardrails.** All five Codex items below are framed as sequential
PR slices unless a small enough batch makes sense to combine.

### Codex agent outputs bundled into PR #268 (draft)

The four background lanes Codex/Ada dispatched on 2026-05-25
returned. Codex bundled their outputs + Ada's joint-SDM scope
rewrite + a after-task report into draft **PR #268** ("Prep
joint-SDM validation and scope rewrite"). The PR is draft until
the maintainer decides merge order vs #261 / #265 and whether to
keep the bundle as one PR or split per the Validation Factory
queue. The pieces (do not edit from any other branch):

- `tests/testthat/test-joint-sdm-binary-long-wide.R` —
  Curie's binary JSDM long-vs-wide parity test (Codex queue
  item 2 content; PR body reports `PASS 11`).
- `docs/dev-log/audits/2026-05-25-hidden-article-validation-map.md`
  — Rose + Shannon's Restoration Queue audit (feeds queue
  item 5 prioritisation).
- `docs/dev-log/audits/2026-05-25-joint-sdm-rendered-figure-qa.md`
  — Boole + Grace + Pat's figure QA (feeds queue item 3
  scope).
- `docs/dev-log/audits/2026-05-25-r200-readiness-review.md`
  — Grace + Curie + Fisher's r200 readiness review (feeds
  queue item 4; identifies the 120-minute timeout as a
  dispatch blocker and recommends binomial-focused 4-cell
  scope: binomial d=1/2/3 + mixed d=2).
- `vignettes/articles/joint-sdm.Rmd` — joint-SDM scope
  rewrite reframing binary `unique()` / `dep()` / `indep()`
  prose around current validation row status.
- `docs/design/04-random-effects.md` — stale status wording
  refresh for binary `lambda_constraint` /
  `suggest_lambda_constraint()` paths (now covered by LAM-03
  / LAM-04).
- `docs/dev-log/after-task/2026-05-25-joint-sdm-binary-scope-rewrite.md`
  — after-task report for the slice.

### Codex queue (sequential, by Ada 2026-05-25)

1. **Finish #261, then #265.** Stack discipline above. Undraft
   #265 after the rebase on ROADMAP.md + check-log.md is clean.

2. **Binary JSDM long/wide validation PR (test-only).** Wraps
   `tests/testthat/test-joint-sdm-binary-long-wide.R` (already
   produced by Curie in lane 1). Cleanest next Codex slice
   because test-only. **Do not** mix with Ada's local
   joint-sdm rewrite unless a combined restoration branch is
   chosen later.

3. **Joint-SDM figure repair PR.** Per Boole+Grace+Pat figure
   QA: page is not Tier-1 ready. Smallest viable repair —
   replace hand-built biplot with the package ordination
   helper and add `fig.cap` / `fig.alt`. Larger blockers
   (extreme Sigma scale, raw covariance heatmap vs latent
   correlations, rotation caveat) are follow-up if scope grows.

4. **r200 plumbing PR (BEFORE dispatch).** Per
   Grace+Curie+Fisher r200 readiness review: current 120-
   minute timeout likely fails key cells. Required before
   dispatch is either sharding or explicit timeout change.
   **Statistical scope (recommended): binomial-focused 4-cell
   — binomial d=1/2/3 + mixed d=2.** No r200 launch from this
   PR; dispatch still maintainer-gated.

5. **Article-order correction** (Ada/Rose, 2026-05-26):
   pause public article expansion before any more local article
   fixes. No public promotion of `mixed-family-extractors`,
   `psychometrics-irt`, or `lambda-constraint` until the binary
   lambda/JSDM article plan lands. Keep mixed-family responses and
   loading constraints as separate teaching lanes.

6. **Next article lane after the correction PR:** rework
   `lambda-constraint` as the first binary loading-constraint
   teaching article, using a binary species/JSDM-style example.
   Any correlation matrix that displays interval columns should use
   `plot_correlations(..., style = "heatmap",
   matrix_layout = "estimate_ci")`, not `plot_Sigma_heatmap()`.

7. **Held internal until later:** `mixed-family-extractors` waits
   for a comprehensive mixed-response expansion covering Gaussian,
   binomial, Poisson/NB, beta/proportion, and blocked delta/hurdle
   cases. `psychometrics-irt` stays Preview/internal until the
   binary lambda/JSDM article is coherent and the `mirt` comparator
   path is explicitly designed.

### Claude/Shannon stance during the Validation Factory

- **No r200 dispatch** until (a) Codex queue item 4 lands the
  plumbing fix on main, and (b) maintainer authorises the
  dispatch.
- **No engine debugging** for the resolved binomial Scenario A
  signal; the DGP fix in PR #263 + #264 + #266 holds.
- **No edits to Codex stack files** (#261 / #265 file lists) or
  to Ada's local rewrite files (joint-sdm.Rmd,
  04-random-effects.md).
- **No `diagnostic_table()` cross-link** in joint-sdm.Rmd until
  #265 lands and a separate posterior-predictive teaching slice
  is opened with real evidence.
- Claude/Shannon's role for the factory window: coord-board
  sync (this PR), monitoring #261 / #265 CI green-bar,
  surfacing forwardable status notes for Ada when she returns,
  and standing by for any unblocker request from Codex's queue
  items 2–5.

### Codex's "unblocker?" answer (2026-05-25, recorded)

Codex's four background lanes returned with: **no Claude
unblocker required.**

- Lane 1 (binary parity test) is complete; no absence-fill
  ruling needed because the fixture uses a complete site ×
  species grid that sidesteps sparse-cell semantics.
- Lane 2 (Restoration Queue audit) is usable now as a map; row
  citations against `docs/design/35-validation-debt-register.md`
  will need a one-line refresh after #265 lands (#265 edits
  design/35).
- Lane 3 (figure QA) outputs hold against current main.
- Lane 4 (r200 readiness) can cite PR #267 on main directly.
- r200 dispatch is maintainer-gated AND workflow-plumbing-gated;
  no Claude action would change either gate.

Update protocol: when you start a lane, add a row. When the lane's
PR opens, fill `PR / branch`. When the PR merges, move the row to
"Recently resolved" with the merge date.

## Queued lanes (not yet picked up)

Per `docs/dev-log/audits/2026-05-13-post-overnight-drift-scan.md`
batching plan + the 2026-05-14 strategic plan revision. Many older
rows below were completed or superseded during the Codex pause; keep
new queued rows current and move stale history to after-task reports
instead of expanding this table.

| Agent | Lane | Wait condition |
|---|---|---|
| Codex | Next small reader-facing lane | after maintainer chooses whether this should be README/pkgdown navigation, a Tier-1 article re-read, or validation-debt surfacing |

Move a row to "Active lanes" when you start it.

## File ownership for the current docs / navigation pass

Current ownership is lane-specific. Lock these files behind the
named owner; if the other agent needs to touch them, they should
leave a coordination comment first and wait for acknowledgement.

| File | Owner (this pass) |
|---|---|
| `.github/workflows/R-CMD-check.yaml` | no active owner after PR #203 merged |
| `.github/pull_request_template.md` | no active owner in this lane; do not edit |
| `CONTRIBUTING.md` | no active owner after PR #203 merged |
| `docs/dev-log/coordination-board.md` | no active owner |
| `docs/dev-log/check-log.md` | no active owner |
| `docs/dev-log/after-task/2026-05-18-pr-slice-contract.md` | Codex for current Slice 1 after-task report |
| `CLAUDE.md`, `AGENTS.md` | no active owner in this lane; do not edit |
| `_pkgdown.yml`, `README.md` | no active owner in this lane; do not edit |
| `docs/design/42-m3-dgp-grid.md`, `docs/design/44-m3-3-inference-replacement.md` | no active owner after PR #205 merged |
| `docs/design/43-asreml-speed-techniques.md`, `docs/design/48-m3-4-boundary-regimes.md` | no active owner after PR #204 merged |
| `vignettes/articles/covariance-correlation.Rmd` | no active owner in this lane; do not edit here |
| `docs/design/*` | coordinate per file; this lane only touches stale source-of-truth wording |
| `docs/dev-log/*` | each agent owns its own `after-task/*.md` and `shannon-audits/*.md` |
| Tier-1 article rewrites (`choose-your-model`, `phylogenetic-gllvm`, etc.) | paused; revisit after this hygiene stop point |
| `R/*` (general) | no active engine owner for non-structural-slope files. Recent parser/API edits on `main` are from PR #226 (`meta_V(V = V)`, `type = "exact"`, wide `traits()` marker preservation). Coordinate before further R edits. |
| `R/fit-multi.R` | **Codex** (Phase 56.1 landed via #289 at `3133863`; Phase 56.2 closed via #293 at `72f67de` with no R-side edit required; future 56.3 may touch for parser wiring). Shannon stays out through Phase 56.4. |
| `R/brms-sugar.R`, `R/parse-multi-formula.R` | **Codex** (Phase 56.3 landed via #295 at `6026710`; future 56.4 backend-grouped extensions may touch). Augmented-LHS parser per Design 55 §4 + Design 56 §7 fail-loud invariant. Shannon soft-no-touch through Phase 56.4. |
| `tests/testthat/test-phylo-unique-slope-gaussian.R` (activated via #298 at `dd3b2be`) | **Active recovery test for anchor cell.** Three test_that blocks live: wide↔long byte-identity, Gaussian Σ_b recovery, forced `n_lhs_cols=1L` negative test. Status row in formula-grammar stays `claimed` until Phase 56.6. Shannon soft-no-touch (recovery numerics owned by Curie / Codex). |
| `tests/testthat/test-{phylo-{latent,indep,dep},animal,spatial,relmat}-{latent,unique,indep,dep}-slope-gaussian.R` (15 remaining files, merged via #282/#283/#284) | **Codex** activates per file during Phase 56.5 fan-out (by backend/risk grouping) by removing `skip_until_stage3()` gates. Until then, gated skeletons stay as-is. |
| `tests/testthat/*` (general) | no active owner for non-structural-slope tests after #226 merged. New `tests/testthat/test-phase56-1-phylo-augmented-stub.R` on `main` via #289 (Phase 56.1 regression test, PASS 9). |
| `src/gllvmTMB.cpp` | **Codex** (Phase 56.1 dormant promotion landed via #289 at `3133863`; future 56.2 / 56.3 may touch as needed): augmented-LHS engine block per Design 56 §5.2. Shannon stays out until Phase 56.4 close. |
| `inst/prototypes/ppcheck-diagnostics.R`, `docs/design/51-posterior-predictive-diagnostics.md` | no active owner after PR #229 merged |
| `.github/workflows/m3-production-grid.yaml`, `dev/precompute-m3-grid.R` (CLI surface only) | no active owner after PR #258 merged 2026-05-25. Both teams free to edit. |
| `dev/m3-grid.R` | **Claude** (PR #263 active 2026-05-25): targeted binomial-psi patch in `m3_sample_truth` + `m3_simulate_response` per maintainer's 2026-05-25 design ruling ("simulations cannot have psi bit — as psi for binary emerges from binomial error"). Gaussian / nbinom2 / ordinal-probit branches untouched. After PR #263 merges, ownership returns to "no active owner; free to edit". |
| `docs/dev-log/audits/2026-05-24-m3-sim-lane-pilot.md` | no active owner after the M3 sim lane closed 2026-05-25 (post-dispatch §8 results landed in PR #262, post-patch rerun in PR #266). |
| `docs/dev-log/audits/2026-05-25-set-c-joint-sdm-gate-matrix.md` | no active owner after PR #267 merged 2026-05-25. |
| `docs/dev-log/audits/2026-05-25-m3-r200-dispatch-plan.md` | no active owner after PR #267 merged 2026-05-25. **r200 dispatch remains maintainer-gated AND workflow-plumbing-gated** (Codex queue item 4). |
| `docs/design/54-cross-package-scout-protocol.md` | no active owner after PR #267 merged 2026-05-25 (incl. §3.5 anti-patterns from Codex review). |
| `vignettes/articles/joint-sdm.Rmd` | **PR #268 (draft)** — modified on `codex/joint-sdm-scope-rewrite-2026-05-25`. Do not edit from any other branch. |
| `docs/design/04-random-effects.md` | **PR #268 (draft)** — stale-status wording refresh. Do not edit from any other branch. |
| `tests/testthat/test-joint-sdm-binary-long-wide.R` | **PR #268 (draft)** — Curie's parity test (NEW; `PASS 11` per PR body). Codex queue item 2 content. |
| `docs/dev-log/audits/2026-05-25-hidden-article-validation-map.md` | **PR #268 (draft)** — Rose+Shannon Restoration Queue audit (NEW). Codex queue 5 prioritises against it. |
| `docs/dev-log/audits/2026-05-25-joint-sdm-rendered-figure-qa.md` | **PR #268 (draft)** — Boole+Grace+Pat figure QA (NEW). Codex queue 3 scope follows from it. |
| `docs/dev-log/audits/2026-05-25-r200-readiness-review.md` | **PR #268 (draft)** — Grace+Curie+Fisher r200 readiness review (NEW). Codex queue 4 (plumbing PR) implements its recommendation. |
| `docs/dev-log/after-task/2026-05-25-joint-sdm-binary-scope-rewrite.md` | **PR #268 (draft)** — after-task report for the bundled slice. |
| **Merge-order rule** (Shannon, 2026-05-25) | `#261` (diagnostic-teaching-reset) merges **before** `#265` (diagnostic-table helper). Both touch `ROADMAP.md` and `docs/dev-log/check-log.md`; #265 will need a small rebase after #261 lands and should be undrafted from there. The Validation Factory queue (items 2–5) begins after the stack settles. |

If a file's owner needs to change (e.g. Claude needs to touch
`_pkgdown.yml` for a one-line reason), update the row, leave a
PR comment, wait for the other agent's acknowledgement.

## Pending coordination questions

None open.

Resolved 2026-05-18: maintainer asked Codex to review and merge
the held engine PRs before the next `drmTMB` workflow revisit.
Codex reviewed #181 and #182, simulated the combined merge order,
ran the targeted tests, and merged #181 then #182.

Active question template (when adding):

```
**Q (yyyy-mm-dd hh:mm MT, <asker>)**: <question>
Open until: <when answer is needed>
Touches: <files>
```

Resolved questions move to "Recently resolved" with the answer.

## Recently resolved (rolling 24-48h)

- **2026-05-26 ~16:34 MT**: **PR [#298](https://github.com/itchyshin/gllvmTMB/pull/298)
  merged at `dd3b2be`** (2026-05-26T22:34:25Z) — Phase 56.4
  anchor-cell `phylo_unique(1 + x | species)` Gaussian recovery
  activation. Activates `test-phylo-unique-slope-gaussian.R` with
  three `test_that` blocks: (1) wide ↔ long byte-identity across 8
  invariants (`logLik`, objective, response vector, trait IDs,
  augmented species IDs, `Z_phy_aug`, `sd_b`, `cor_b`); (2)
  Gaussian Σ_b recovery against #287 §2.1 defaults
  (`n_sp=60, T=3, n_rep=4`; σ² ±20%; ρ ±0.30); (3) Design 56 §7.3
  forced `n_lhs_cols=1L` negative test — exercises the TMB shape
  guard. PASS 27 in the activated file; PASS 67 + 60 in adjacent
  regressions. Status row in `docs/design/01-formula-grammar.md`
  stays **`claimed`** (not `covered`) — validation-debt / NEWS /
  articles / deprecation parked for Phase 56.6. Honest
  seed-discipline noted: original seed gave 25.6% relative σ²
  error → seed `5640` chosen because it lands in target, *tolerance
  not widened*. Rose pre-publish
  ([#issuecomment-4549389351](https://github.com/itchyshin/gllvmTMB/pull/298#issuecomment-4549389351))
  posted before merge: APPROVE. 3-OS green: ubuntu 25m33s, macOS
  24m25s, windows 37m40s. Next Codex lane: **Phase 56.5 fan-out by
  backend/risk** starting with `phylo_unique(..., vcv = A_user)`.
  Cross-reference after-task at
  `docs/dev-log/after-task/2026-05-26-phase-56-4-merge-closeout.md`.
  (Ada / Codex / Claude)
- **2026-05-26 ~14:00 MT**: **PR [#295](https://github.com/itchyshin/gllvmTMB/pull/295)
  merged at `6026710`** (2026-05-26T19:58:34Z) — Phase 56.3 anchor
  parser slice. Wires `phylo_unique(1 + x | species)` (wide) and
  `phylo_unique(0 + trait + (0 + trait):x | species)` (long) into
  the augmented phylo path with two-column `Z_phy_aug` and
  `n_lhs_cols = 2L`. Legacy `phylo_unique(0 + trait | species)`
  preserved. Design 56 §7 fail-loud preserved (double-guard at
  parser + R-side wiring). Status recorded as **`claimed`** (not
  `covered`) in `docs/design/01-formula-grammar.md`; CLAUDE.md
  scope-honesty marker added. Rose pre-publish
  ([#issuecomment-4547768272](https://github.com/itchyshin/gllvmTMB/pull/295#issuecomment-4547768272))
  posted before merge: APPROVE. 3-OS green: ubuntu 26m19s, macOS
  23m28s, windows 30m46s. Next Codex lane: **Phase 56.4 anchor-cell
  recovery activation** (this same `phylo_unique` cell first, per
  Codex evidence-first sequencing) before any fan-out. Cross-
  reference after-task at
  `docs/dev-log/after-task/2026-05-26-phase-56-3-merge-closeout.md`.
  (Ada / Codex / Claude)
- **2026-05-26 ~12:00 MT**: **PR [#296](https://github.com/itchyshin/gllvmTMB/pull/296)
  merged at `e443b6a`** — #287 audit-only tidy. Adds the §2
  pre-spec defaults note (Curie / Codex adjusts only in the
  activation PR if first recovery fit surfaces identifiability /
  runtime trouble) and the evidence-first sequencing reminder
  (anchor cell → recovery → backend/risk-grouped fan-out). §6
  cross-refs gained #289 / #293 / #295 entries. Codex authorized
  the tidy explicitly; no test-code, register, NEWS, article, or
  deprecation edits. (Claude)
- **2026-05-26 ~11:30 MT**: **PR [#293](https://github.com/itchyshin/gllvmTMB/pull/293)
  merged at `72f67de`** — Phase 56.2 classify n_traits audit sites.
  Five-file docs/design/dev-log slice (+404/−21): Design 56 §4
  wording fix (mechanical replacement list → classification
  checklist), after-task report, check-log, recovery checkpoint,
  audit memo (re-shipped clean on top of #289's earlier landing).
  **No R-side code edit was needed** because #289's
  `use_phylo_slope_correlated == 0` guard already preserves the
  legacy phylogenetic covariance paths. Codex's coordination
  answers (recorded for posterity): cadence is one PR per
  sub-phase unless Ada bundles; next lane is Phase 56.3 parser
  work; A6 stays audit-only until later evidence gates close;
  `codex/morphometrics-long-wide` paused/unknown.
  Cross-reference after-task at
  `docs/dev-log/after-task/2026-05-26-phase-56-2-merge-closeout.md`.
  (Ada / Codex / Claude)
- **2026-05-26 ~11:00 MT**: **PR [#289](https://github.com/itchyshin/gllvmTMB/pull/289)
  merged at `3133863`** — Phase 56.1 dormant TMB promotion. Engine surface
  now carries the augmented-LHS plumbing
  (`use_phylo_slope_correlated` default 0; block-local
  `n_lhs_cols ∈ {1, 2}`; `b_phy_aug` / `Z_phy_aug` arrays;
  `log_sd_b` / `atanh_cor_b` vectors; defensive `error()` guards on
  every dim/length). Legacy `phylo_slope()` byte-identity preserved
  by the `use_phylo_slope_correlated == 0` guard. Rose pre-publish
  ([#issuecomment-4545836209](https://github.com/itchyshin/gllvmTMB/pull/289#issuecomment-4545836209))
  posted before merge; Design 56 §9.1 validation contract met
  (3-OS green; legacy recovery preserved; `n_lhs_cols = 2` smoke
  passes; after-task cross-references Design 56 §5.2 / §7 / §9.1).
  Phase 56.2 now active on `codex/phase56-2-rside-audit-2026-05-26`;
  audit memo landed in #289 at
  `docs/dev-log/audits/2026-05-26-phase56-2-rside-audit.md`.
  Cross-reference after-task at
  `docs/dev-log/after-task/2026-05-26-phase-56-1-merge-closeout.md`.
  (Ada / Codex / Claude)
- **2026-05-26 ~10:50 MT**: **PR [#291](https://github.com/itchyshin/gllvmTMB/pull/291)
  merged at `6f413cf`** — Phase A6 prep audit memo. Pre-stages
  three error-prone bookkeeping pieces of the future A6 slice:
  articles inventory (9 locations across 6 articles), `NEWS.md`
  pre-draft, and validation-debt register pre-draft (RE-02 / FG-15 /
  PHY-06 / ANI-06 walk wording plus new `SPA-slope` row).
  Audit-only docs/dev-log memo; no engine / parser / R / register /
  article edits. A6 itself remains blocked behind Phase 56.5 close
  per Active Plan 2026-05-26. (Claude)
- **2026-05-26 ~10:30 MT**: **Phase A scaffold close + Phase 56.1 handoff to Codex.**
  Phase A of the Structural-dependence × random-slope plan
  (Design 55 / Design 56) closed Shannon-side. Merged 3-OS green:
  #277 (Design 55 grammar contract), #279 + #280 + #286 (Design 56
  engine-work design + scalable-name amendment), #282 + #283 + #284
  (16 skeleton tests covering APPLICABLE matrix per Design 55 §5,
  all gated by `skip_until_stage3()`), #285 (Phase A scaffold-close
  after-task report), #287 + #288 (Phase 56.5 per-cell + Phase B0
  non-Gaussian audit memos). Phase 56.1 (TMB template promotion per
  Design 56 §5.2) handed off to Codex on
  `codex/phase56-1-tmb-promotion-2026-05-26`. **Hard scope (Ada
  2026-05-26):** Codex owns `src/gllvmTMB.cpp`, `R/fit-multi.R` for
  56.1–56.2 and `R/brms-sugar.R`, `R/parse-multi-formula.R` from
  56.3; Shannon stays out of those four files through 56.4. Shannon
  role when 56.1 PR opens (Design 56 §9.1): coord-board sync, Rose
  pre-publish, after-task cross-reference. (Claude)
- **2026-05-25 ~14:30 UTC**: PR #258 (M3 sim lane — workflow + script
  + pre-dispatch audit memo) merged to `main` at 14:07 UTC.
  GHA dispatch [run 26404672871](https://github.com/itchyshin/gllvmTMB/actions/runs/26404672871)
  completed at 15:xx UTC: 15/15 jobs returned `success`; 5 cells
  flagged `COMPUTE_FAIL` per Design 50 §5 (3 ordinal-probit
  expected per §6 bootstrap guard; 1 nbinom2 d=2 boot-fail-rate
  22%; 1 mixed d=3 fit-fail 40%). **Verdict: Scenario A confirmed;
  broader than nbinom2** — binomial all three d-levels show severe
  under-estimate of `Sigma_unit[tt]` (median ratios 0.24/0.32/0.42
  vs band [0.80, 1.15]); nbinom2 d=1 and d=3 also outside their
  band; Gaussian d=1 just over. Hand-off to Codex's #257/#228 lane
  per pre-registered trigger. CI-08 and CI-10 stay `partial`
  (Design 50 §9). See `docs/dev-log/audits/2026-05-24-m3-sim-lane-pilot.md`
  §8 for full per-cell table.
- **2026-05-20 ~16:08 MT**: PR #229 (fitted-model predictive /
  simulation-rank diagnostic prototype) merged to `main` as squash
  commit `2479a9d` after PR R-CMD-check run `26190941251` passed on
  ubuntu, macOS, and Windows. The lane closed #222, added
  non-exported `inst/prototypes/ppcheck-diagnostics.R`, Design 51,
  DIA-11 / DIA-12 partial rows, Gaussian / Poisson / NB2 prototype
  tests, and follow-up issue #228 for public `pp_check()` / exact
  randomized-quantile residual promotion.
- **2026-05-20 ~13:37 MT**: PR #226 (sister-package citation
  hygiene + `meta_V()` V-only syntax) merged to `main` as squash
  commit `f71de5f` after PR R-CMD-check run `26183610311` passed on
  ubuntu, macOS, and Windows. The lane closed #223 and #227, updated
  citation/provenance boundaries, made `meta_V(V = V)` /
  `meta_V(V, type = "exact")` canonical, preserved compatibility for
  old parser spelling, reserved `type = "proportional"` as blocked
  future work, fixed wide `traits(...)` marker preservation, and
  updated NEWS, roxygen/Rd, design docs, validation-debt rows,
  check-log, and the after-task report.
- **2026-05-20 ~11:18 MT**: PR #225 (M3.3b source-map dashboard /
  Florence contact sheet) merged to `main` as squash commit
  `223919b` after PR R-CMD-check run `26176399868` passed on ubuntu,
  macOS, and Windows. The lane added the dev-only PNG source-map
  dashboard, a Florence review note, Design 46/50 implementation
  notes, and issue-ledger closeout. Issue #218 auto-closed on merge.
- **2026-05-20 ~09:51 MT**: PR #224 (M3.3b NB2 start/local-basin
  probe scaffold) merged to `main` as squash commit `ae7d1f8` after
  PR R-CMD-check run `26171605952` passed on ubuntu, macOS, and
  Windows. The lane added dev-only `--nb2-start-probe`,
  `--probe-config`, probe metadata in summaries/reports, and local
  smoke evidence showing the full four-config one-rep probe took
  749.4 s while the selected-config smoke took 60.6 s. Issue #217 was
  closed after this lane; #218 later closed via PR #225.
- **2026-05-20 ~08:48 MT**: PR #221 (M3.3b NB2 stress-map/report
  scaffold) merged to `main` as squash commit `2266336` after PR
  R-CMD-check run `26168086992` passed on ubuntu, macOS, and Windows.
  The lane added the point-only NB2 stress-map surfaces, r10/r20
  source-map evidence, diagnostic report semantics for
  `POINT_ONLY` / `NOT_EVALUATED`, and issue-ledger updates for #217
  and #218. No NB2 surface was admitted to r50; #217 later closed via
  the start/local-basin probe, while #218 later closed via PR #225.
- **2026-05-20 ~06:55 MT**: PR #220 (M3.3b surface-admission +
  diagnostic visualization gate) merged to `main` as merge commit
  `f7e5a35`. PR R-CMD-check run `26163165179`, post-merge main
  R-CMD-check run `26163201467`, and pkgdown run `26163219728` all
  passed. Issues #217 and #218 remain open; PR #220 advances both by
  adding Design 50 and the M3 diagnostic-report / Florence gate, but
  does not close them until real surface evidence and a rendered
  report exist.
- **2026-05-20 ~06:22 MT**: PR #219 (issue-ledger after-task
  protocol) merged to `main` as merge commit `2e516ec`. PR
  R-CMD-check run `26161369265`, post-merge main R-CMD-check run
  `26161403057`, and pkgdown run `26161420569` all passed. Issue #216
  auto-closed; #217 now carries the rolling next-30-slice queue, and
  #218 carries the Florence / diagnostic visualization cross-link.
- **2026-05-20 ~05:42 MT**: PR #215 (M3.3 drmTMB cross-learning
  checkpoint) merged to `main` as merge commit `26dbc1e`. PR
  R-CMD-check run `26160169174`, post-merge main R-CMD-check run
  `26160261072`, and pkgdown run `26160276713` all passed. The
  checkpoint moved the next M3 step to M3.3b surface admission and
  made Florence's diagnostic visualization gate part of the M3
  critical path, not just the later Phase 1c-viz layer.
- **2026-05-20 ~04:57 MT**: PR #214 (M3.3a `nbinom2` known-phi
  point diagnostic) merged to `main` as merge commit `66d7b6b`. The
  diagnostic fixed `phi_nbinom2` at the DGP value in point fits and
  improved median `Sigma_unit_diag` estimate/truth ratios, but the
  baseline scenario remained below truth. EXT-13 / CI-08 / CI-10 stay
  partial; fixed-phi bootstrap needs a refit path before any coverage
  claim.
- **2026-05-20 ~03:31 MT**: PR #213 (M3.3a `nbinom2` fitted
  phi / link-residual diagnostics) merged to `main` as squash commit
  `b652063` after PR R-CMD-check run `26150065112` passed on ubuntu,
  macOS, and Windows. Post-merge main R-CMD-check run `26151851845`
  and pkgdown run `26153970065` also passed. The lane added M3 row
  diagnostics for fitted `phi_nbinom2` and fitted link-residual
  increments; EXT-13 / CI-08 / CI-10 remain partial because the r20/b20
  diagnostic grid still showed low latent+unique `Sigma_unit_diag`
  estimates.
- **2026-05-20 ~01:23 MT**: PR #212 (M3.3a corrected
  `nbinom2` r20 stress audit) merged to `main` as squash commit
  `ff395ce` after the PR fast-path R-CMD-check run `26147568512`
  passed on ubuntu, macOS, and Windows. Post-merge main
  R-CMD-check run `26147643167` and pkgdown run `26147660756`
  also passed. The corrected r20/b20 artifact still failed the 0.94
  coverage gate, with coverage 0.77 in the baseline scenario and
  0.58 in the low-dispersion scenario; the next M3.3a slice should
  add fitted `phi` / link-residual diagnostics before another grid.
- **2026-05-20 ~00:54 MT**: PR #211 (M3.3a `nbinom2`
  target-construction audit) merged to `main` as squash commit
  `bfad49c` after the PR R-CMD-check run `26143597267` passed on
  ubuntu, macOS, and Windows. Post-merge main R-CMD-check run
  `26145028175` and pkgdown run `26146548419` also passed. The lane
  added explicit `bootstrap_Sigma(link_residual = "none")` target
  handling for M3 `Sigma_unit_diag`; EXT-13 / CI-08 / CI-10 remain
  partial pending corrected stress-grid evidence.
- **2026-05-19 ~22:34 MT**: PR #210 (M3.3a `nbinom2` r10
  stress-pilot evidence) merged to `main` as squash commit `6fdf45f`
  after the PR fast-path R-CMD-check passed on ubuntu, macOS, and
  Windows. Post-merge main R-CMD-check run `26141523308` and pkgdown
  run `26141533866` also passed.
- **2026-05-19 ~22:12 MT**: PR #209 (M3.3a `nbinom2`
  stress-grid controls) merged to `main` as squash commit `34e74ec`
  after the PR fast-path R-CMD-check passed on ubuntu, macOS, and
  Windows. Post-merge main run `26140777583` also passed on all three
  OS-named jobs.
- **2026-05-19 ~21:18 MT**: PR #208 (convergence/start-values
  article) merged to `main` as squash commit `3bb01c8` after three-OS
  R-CMD-check passed on the final PR head. Post-merge main
  R-CMD-check run `26139437409` also passed on ubuntu, macOS, and
  Windows before the next M3.3a stress-smoke branch was pushed.
- **2026-05-19 ~20:24 MT**: PR #206 (robust modeling diagnostics and
  start provenance) merged to `main` as squash commit `a89aac8` after
  three-OS R-CMD-check passed on the PR branch. Branches #207 and #208
  were rebased onto `main`.
- **2026-05-19 ~20:45 MT**: PR #207 (M3.3a fit-health pilot
  metadata) merged to `main` as squash commit `2af6a61` after
  three-OS R-CMD-check passed on the final PR head. PR #208 was then
  rebased onto the new `main` with both check-log append blocks
  preserved.
- **2026-05-19 ~15:52 MT**: PR #205 (M3.3 target-explicit pilot
  grid) merged to `main` after the fast-path R-CMD-check parser gate
  passed on ubuntu, macOS, and Windows. The dev grid now records
  `psi/profile` diagnostic rows and `Sigma_unit_diag/bootstrap`
  primary pilot rows, with bootstrap refit failure accounting and the
  M3 `cluster = "unit"` grouping bug removed.
- **2026-05-19 ~12:33 MT**: PR #200 (post-M3 ROADMAP evidence
  refresh) merged to `main` after three-OS R-CMD-check passed. The
  roadmap now records PR #199's production-evidence outcome and keeps
  M3.3 in failure-mode triage.
- **2026-05-19 ~13:31 MT**: PR #201 (M3.3 failure-mode ledger)
  merged to `main` after three-OS R-CMD-check passed. The ledger found
  systematic above-upper-bound `psi` misses and recorded glmmTMB /
  galamm comparator scope.
- **2026-05-19 ~14:13 MT**: PR #202 (M3.3 target-scale audit) merged
  to `main` after three-OS R-CMD-check passed. The audit split `psi`
  into a diagnostic target and total `Sigma_unit[tt]` into the primary
  promotion target for the next M3.3 pilot.
- **2026-05-19 ~15:05 MT**: PR #203 (CI ignored-source fast path)
  merged to `main` after three-OS R-CMD-check passed. The in-job
  classifier now fast-passes ignored-source planning/doc changes with
  visible replacement gates instead of relying on workflow-level path
  skips.
- **2026-05-19 ~15:10 MT**: PR #204 (M3 target-explicit roadmap
  refresh) merged to `main` after the new fast-path CI completed in
  seconds on all three OS-named checks. ROADMAP and Design 42 / 43 /
  44 / 48 now agree that `psi` is diagnostic and total
  `Sigma_unit[tt]` is the primary M3.3 promotion target.
- **2026-05-19 ~11:43 MT**: PR #199 (M3.3 production artifact review)
  merged to `main` after three-OS R-CMD-check passed. The production
  workflow passed compute but failed the statistical coverage gate, so
  CI-08 / CI-10 stayed partial and M3.3 moved to failure-mode triage.
- **2026-05-19 ~07:23 MT**: PR #197 (M3.3 production grid
  `workflow_dispatch` wiring) merged to `main` after 3-OS
  R-CMD-check passed.
- **2026-05-19 ~06:32 MT**: PR #195 (Slice 2 after-task templates)
  merged to `main`.
- **2026-05-19 ~05:47 MT**: PR #193 (in-prep citation discipline)
  merged to `main`.
- **2026-05-19 ~05:19 MT**: PR #190 (Families help topic mixed-family
  selector-column documentation) merged to `main`.
- **2026-05-18 ~16:35 MT**: PR #187 CI tiered gates passed full
  three-OS R-CMD-check after a macOS Bash 3.2 classifier fix. The
  workflow now preserves the OS-named required checks while fast-
  passing known process-only paths inside the job.
- **2026-05-18 ~14:02 MT**: PR #184 drmTMB-parity hygiene cascade
  merged after three-OS R-CMD-check success. Open PR count returned
  to zero before Slice 1 (`codex/pr-slice-contract`) started.
- **2026-05-18 ~13:00 MT**: PR #181 sparse pedigree A-inverse
  engine pass-through and PR #182 M3.4 warm-start + phi-clamp
  were reviewed by Codex and merged to `main`. Combined
  #181 -> #182 tree was simulated before merge; targeted checks
  passed with `NOT_CRAN=true` + `devtools::load_all(".")`:
  sparse-Ainv engine 8/8 and M3.4 warm-start / phi-clamp 14/14.
  #184 is now the only open PR and has been synced with the
  post-merge `main`.
- **2026-05-13 ~20:30 MT**: Seven-PR evening sweep merged after
  maintainer authorization. In chronological merge order on
  main: #76 (cov-corr misleading-section removal, landed
  mid-day), then #75 (choose-your-model rewrite), #78
  (functional-biogeography no-M-labels), #79 (check-log Kaizen
  + post-overnight drift-scan audit + coord-board sync), #80
  (README Tiny example wide-form + drop `gllvmTMB_wide`
  mention), #77 (pitfalls section 5 paired+three-piece phylo
  with general-Omega note), #74 (article cleanup + long+wide
  pair sweep). Three maintainer corrections were stacked into
  PR #77 over the evening: identifiability nuance ("can't get
  2 Ss → omega is usual"), three-piece naming ("4 parts
  vs 3 parts"), and general-Omega framing ("omega can be used
  for any combinations of adding all variance components").
  All three are durably captured in the merged
  `check-log.md` point 8 and the merged
  `audits/2026-05-13-post-overnight-drift-scan.md`. WIP back
  to 0. Batches A-E (R/ + a few articles) queued; Batches A
  and B remain blocked by the Codex-pause R/ rule.
- **2026-05-13 ~08:12 MT**: Codex's `covariance-correlation`
  post-#61 Pat/Rose re-read landed (PR #69 merged on Codex's
  behalf per their handoff). PR #69 reopens the article with the
  applied behavioural-syndrome framing, adds early long+wide
  examples, uses the single-entry `gllvmTMB()` with `traits(...)`,
  defines `level` before `Sigma_level`, drops the stale OLRE
  "Future work" heading, replaces stale See-also links.
- **2026-05-13 ~07:00 MT**: Codex pause handoff (maintainer
  relay). Codex stops after PR #69; treated as paused until
  re-dispatch ~2026-05-17. Codex's queued lanes
  (`_pkgdown.yml` navbar, article cleanup, `choose-your-model`
  rewrite) reassigned to Claude during the pause window.
- **2026-05-13 ~06:30 MT**: Claude's README D1+D2+D4 lane
  landed (PR #67 merged). README opener rewrite + section
  reorder ("What can I model now?" up to position 4) +
  "What 'stacked-trait' means" definition section. Codex's
  `_pkgdown.yml` navbar lane now unblocked (wait condition
  cleared). The navbar's vocabulary should echo the
  README's new section labels ("Model guides", concept-and-
  reference split per PR #64 Section I, with Codex's
  preferred label "Concepts" for the second menu).
- **2026-05-13 ~05:40 MT**: Joint plan (PR #64) ratified by
  Codex. Two small qualifications:
  - Navbar second-menu label preferred "Concepts" (cleanest)
    over "Concepts and reference" -- Codex's call when the
    navbar PR lands.
  - `covariance-correlation` verdict is "post-#61 Pat/Rose
    re-read; rewrite only if the re-read still fails Tier-1
    rules" rather than a flat "rewrite". Audit's "rewrite"
    label is a placeholder; final decision after the re-read.
  Claude picked up the first implementation lane: README
  D1+D2+D4. Codex will own the navbar PR after the README
  PR lands.
- **2026-05-13 ~05:10 MT**: Codex acknowledged the board and
  agreed to use it for the next 1-2 days. Active-lane schema
  amended (Codex's "covariance-correlation re-read" moved
  from `dispatched` to a Queued lanes subsection, since Codex
  has not picked it up yet).
- **2026-05-13 ~05:00 MT**: Maintainer asked whether to create a
  dedicated coordination channel beyond the existing Shannon
  audit + check-log channels. **Resolved**: yes, this file is
  the dedicated channel.
- **2026-05-13 ~04:30 MT**: Should `gllvmTMB_wide()` be
  deprecated? **Resolved**: yes (maintainer answer "Yes, deprecate
  via single bundled PR"). Implemented in PR #65.
- **2026-05-13 ~04:25 MT**: README is hard for new users to
  read; Rose audit needed. **Resolved**: PR #64 (Rose audit)
  covers the README + cross-doc framing drift; extended with
  Sections G-L for the joint plan.
- **2026-05-13 ~03:30 MT**: `covariance-correlation.Rmd` has
  substantive mistakes that Codex should fix. **Resolved**: PR
  #61 (Codex) merged.

## Pointers (where else to look)

- **Current open PRs**: `gh pr list --repo itchyshin/gllvmTMB --state open`
- **Active joint plan**: PR #64 (Rose audit, Sections G-L).
- **Per-PR retrospectives**: `docs/dev-log/after-task/`.
- **Durable lessons**: `docs/dev-log/check-log.md`.
- **Codex's coordination message format**: usually relayed via
  maintainer through chat; format is "scope X, files Y, lanes
  Z". Reply via this board + the relevant PR comment.
- **Claude's plan file** (`~/.claude/plans/please-have-a-robust-elephant.md`):
  private to Claude; mirrors the public state of this board for
  Claude's own execution view. Codex has a similar private
  context.

## Update history (last 5)

- 2026-05-25 ~18:30 UTC: Set C joint-SDM prep + r200 dispatch plan
  + Jason scout-protocol lane opens on `agent/set-c-r200-prep`
  (worktree `gllvmTMB-set-c-r200-prep`). Three new docs-only
  artefacts; **no joint-sdm.Rmd edit, no R/ edit, no r200 dispatch
  fired.** Merge-order rule recorded: #261 before #265
  (ROADMAP.md + check-log.md overlap). Claude's prep PR shares no
  files with the Codex stack. (Claude)
- 2026-05-25 ~17:00 UTC: M3 post-DGP-patch rerun (PR #266) merged.
  Under patched DGP at r10, binomial × d=2 and mixed × d=2 hit
  `PASS_TO_SCALE`; r200 dispatch on those two cells is the next
  authorized slice, but **maintainer has not yet authorized** —
  CI-08 / CI-10 remain `partial` per Design 50 §9 (n=10 is below
  r200 floor). See `audits/2026-05-25-m3-postpatch-rerun.md`. (Claude)
- 2026-05-25 ~15:30 UTC: M3 sim lane closes. PR #258 merged at 14:07
  UTC; GHA dispatch run 26404672871 completed 15/15 success.
  **Scenario A confirmed broader than nbinom2** — binomial all
  three d-levels show severe under-estimate of `Sigma_unit[tt]`.
  Root cause: m3-grid DGP added unidentifiable `psi` for binomial
  rows (resolved as DGP bug, not engine bug, per maintainer design
  ruling and PR #263 four-round Jason scout). Hand-off to Codex's
  #257/#228 explicitly **not implicated**. CI-08 / CI-10 stay
  `partial` (Design 50 §9). (Claude)
- 2026-05-24 ~07:30 MT: Claude picked up the M3 sim lane
  (accuracy + reliability check at n_reps=10, NOT comprehensive
  coverage — that's a future post-functionality-freeze slice per
  maintainer 2026-05-24). PR #258 opens with three new
  `workflow_dispatch` inputs (`targets`, `n_boot`, `seed_base`)
  on the M3 production grid + a pre-dispatch audit memo with
  pre-registered estimate/truth-ratio bands. Fisher + Curie + Rose
  lens consults completed before the plan was finalised. Codex
  review requested on PR #258. File-ownership rows added for
  `.github/workflows/m3-production-grid.yaml`,
  `dev/precompute-m3-grid.R` (CLI surface), and the audit memo
  (Claude).
- 2026-05-14 ~21:00 MT: Codex-absent assumption codified
  (maintainer "codex might not come back so you should
  plan to do it"). R/ + tests/testthat/ + src/ ownership
  reassigned to Claude under heavy persona-review discipline.
  Active lanes: 3 docs-only Claude PRs (#83, #84, this PR).
  Queued lanes restructured around Phase 1a/1b/1b'/1c plan.
  Restoration rule documented if Codex returns (Claude).
- 2026-05-13 ~20:30 MT: Seven-PR evening sweep merged via
  maintainer authorization; active-lane table reset to
  "(none active)"; WIP back to 0 (Claude).
- 2026-05-13 ~17:30 MT: Active-lane table populated with the six
  in-flight Claude PRs (#74-#79); Codex's three queued lanes
  marked done (navbar PR #73, article cleanup PR #74, choose-your-model
  PR #75); Batch A-E queue inserted for the post-overnight drift
  scan campaign; WIP-cap suspension acknowledged in-line (Claude).
- 2026-05-13 ~08:15 MT: Codex paused after PR #69; queued lanes
  reassigned to Claude during pause window; file-ownership
  rows tagged `(Codex pause)` (Claude).
- 2026-05-13 ~06:30 MT: PR #67 merged (README D1+D2+D4);
  Claude's row moved to "(none active)"; Codex's
  `_pkgdown.yml` lane unblocked (Claude).
- 2026-05-13 ~05:40 MT: PR #64 merged; Claude picked up the
  README D1+D2+D4 lane; Codex's queued lanes updated (Claude).
- 2026-05-13 ~05:11 MT: Active-lane schema amended per Codex
  feedback; "Queued lanes" subsection added (Claude).
