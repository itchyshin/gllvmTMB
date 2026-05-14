# After-task: Roadmap page refresh + pkgdown exposure -- 2026-05-14

**Tag**: `docs` + `pkgdown`. No engine, API, parser, family,
likelihood, or NAMESPACE change. One small `_pkgdown.yml`
addition (navbar entry + roadmap component); one small
`docs/design/10-after-task-protocol.md` addition ("Roadmap
tick" required section); one substantive content rewrite
(`ROADMAP.md`); one new wrapper `vignettes/articles/roadmap.Rmd`;
one short README footer link; one new `decisions.md` Phase 5.5
ratification entry.

**PR / branch**: this PR / `agent/roadmap-page`.

**Lane**: Claude (Codex absent).

**Dispatched by**: maintainer 2026-05-14 evening. Initial ask:
*"https://itchyshin.github.io/drmTMB/ROADMAP.html. Hey, drmTMB
has this roadmap page. Can we have a similar page like this?"*
Then, after design choices were locked: *"You start making this
new refreshed roadmap. I would like to check it ... I think you
need to discuss with your team -- loading, ordinations,
correlations, communalities, etc. should all be visualized"*.
The visualization-layer additions came from that second-round
team consult (Pat / Emmy / Darwin). README footer link added
per a third-round maintainer instruction.

## Files touched

1. **`ROADMAP.md`** -- full rewrite. Was 185 lines dated
   2026-05-11; now ~720 lines dated 2026-05-14. New structure:
   "Last refreshed" header date; "Should I use this package
   today?" adoption traffic-light callout (🔴 🟡 🟢 with current
   state highlighted); "Phases at a glance" summary table
   (15 rows); per-phase sections with status chips
   (✅ 🟢 ⚪ 🔵), ASCII progress bars (`████░░░░ 4/8` style),
   sub-phase breakdowns, items chip-prefixed, close-gate tables,
   and 1 – 3 absolute GitHub URL cross-refs each; "Recent
   merges" rolling callout (last 12 PRs); "Out of scope"
   preserved + lightly polished; "How this roadmap is
   maintained" living-roadmap closing callout linking to the
   new Roadmap-tick discipline in the after-task protocol.
2. **`vignettes/articles/roadmap.Rmd`** -- new (10 lines).
   YAML front-matter + a single knitr `child` chunk including
   `../../ROADMAP.md`. This is the pkgdown render path; pkgdown
   does not auto-render root markdown so the wrapper article is
   required (per Grace's persona consult).
3. **`_pkgdown.yml`** -- add `roadmap` to `navbar.structure.left`
   between `articles` and `reference`; add
   `navbar.components.roadmap` with `text: Roadmap` and
   `href: articles/roadmap.html`. Total addition: 5 lines.
4. **`docs/dev-log/decisions.md`** -- append new dated entry
   "2026-05-14 Insert Phase 5.5 External Validation Sprint
   before CRAN submission" (~100 lines). Codifies the
   pre-submission external scrutiny sprint added to the
   strategic plan 2026-05-14 evening so the refreshed
   `ROADMAP.md` doesn't cite Phase 5.5 against vapour (Rose's
   flagged risk).
5. **`docs/design/10-after-task-protocol.md`** -- add
   "Roadmap tick" required section + add `Roadmap tick` to the
   Required Sections bullet list. ~30 lines total addition.
   Codifies the drift-prevention mechanism for the rendered
   roadmap (every after-task report names which row changed,
   bridging per-PR memory to the public page).
6. **`docs/dev-log/after-task/2026-05-14-roadmap-refresh.md`**
   -- this file.
7. **`README.md`** -- add a short "Roadmap" section at the
   bottom pointing to the rendered `articles/roadmap.html`
   page. Mirrors drmTMB's homepage-end-of-page pattern per
   maintainer instruction 2026-05-14.

## Math contract

No public R API, likelihood, formula grammar, family,
NAMESPACE, generated Rd, vignette code, or pkgdown navigation
(for an existing article) change. The only `_pkgdown.yml`
change is a new navbar entry + a new component for a new
article. No new exports.

## Persona consult summary

Three rounds of persona consults shaped the design. Raw
responses captured in the conversation log.

### Round 1 (roadmap design): Pat, Rose, Grace

- **Pat** (applied PhD user) flagged legibility gaps in the
  original "Option C" design (status chips + heavy cross-refs).
  Top fixes adopted: drop ⏸️ Blocked chip and merge into 🔵
  Deferred (4 chips, not 5); add a 🔴 🟡 🟢 "Should I use this?"
  adoption-state callout at the very top so applied users get
  the safety signal before the developer-detail; de-jargonise
  "NS notation switch" → "Math notation upgrade (S → Ψ)",
  "Profile-CI Validation" → "Profile-likelihood CI validation",
  "External Validation Sprint" → spelled out with the
  parenthetical (pilot users + sim grid + reviewers),
  "Phase 1b'" → "Phase 1b validation" in headings; introduce
  "Batch A/B/C/D/E" with a one-line explanation at first use.
- **Rose** (systems auditor) flagged canon gaps and
  drift-recurrence risk. Top fixes adopted: write the Phase
  5.5 `decisions.md` ratification entry in the same PR so the
  roadmap doesn't cite vapour; explicitly label Batch C as PR
  #82 (Rose flagged Batch C as "invisible" in the proposed
  structure); reconcile the `extract_ICC_site` / `getLoadings`
  / `ordiplot` stale-legacy claim from the old ROADMAP (these
  are in the 0.2.0 API; Phase 2 export audit decides their
  fate, they are not "legacy helpers to be removed before
  deletion"); add the "Roadmap tick" line to the after-task
  protocol as the drift-prevention mechanism. The Roadmap-tick
  discipline is the narrowest fix to the 2026-05-11 →
  2026-05-14 drift pattern.
- **Grace** (CI / pkgdown / CRAN) verified the rendering
  mechanics. Top decisions adopted: wrapper article via knitr
  child include (pkgdown does not auto-render root markdown);
  absolute GitHub URLs for all cross-refs (`destination:
  pkgdown-site` excludes `docs/` from render, so relative
  links to `docs/dev-log/...` 404 silently);
  `pkgdown::check_pkgdown()` validates `[fn()]` autolinks but
  not arbitrary markdown hrefs, so the breakage would have
  shipped silently if relative links were used. `.Rbuildignore`
  already has `^ROADMAP\.md$` (line 11) so CRAN concern is
  pre-handled. Emoji `✅ 🟢 ⚪ 🔵 🔴 🟡` all in safe Unicode
  ranges, bootstrap-5 pkgdown sets no emoji-blocking CSS, no
  fallback needed.

### Round 2 (visualization layer): Pat, Emmy, Darwin

Maintainer's flag: visualization (ggplot2 + plotly) is
"super-important for usability, presentation, interpretation"
and missing from the explicit roadmap.

- **Pat** (applied PhD user) listed the top 5 – 7 visualizations
  applied users hand-roll today from `extract_*()` numeric
  output: correlation heatmap, loadings bar/heatmap, ordination
  biplot, communality bar, variance-partition stacked bar,
  phylogenetic-signal panel, true-vs-fitted recovery scatter.
  Most urgent 3: correlation heatmap, biplot, communality.
  Pet-peeve interpretation trap: when `unique()` is missing,
  correlation magnitudes are inflated; the plot should annotate
  with shared / unique / total guard.
- **Emmy** (R package architecture) verified a critical fact:
  **`R/plot-gllvmTMB.R` already has the dispatcher pattern**
  with five plot types (`correlation`, `loadings`,
  `integration`, `variance`, `ordination`) and the
  `requireNamespace("ggplot2", quietly = TRUE)` guard at
  L72 – 73. So Phase 1c-viz is "complete + polish", not
  greenfield. Recommended Option (D) Hybrid -- public
  `plot.gllvmTMB_multi(x, type = ...)` with internal helpers
  -- which is what's already in place. ggplot2 stays in
  Suggests. Plot helpers return ggplot objects (composable).
  No companion package needed. CRAN concern: wrap examples in
  `\donttest{}`.
- **Darwin** (ecology / evolution audience) named the
  biological question each Tier-1 article answers and
  prioritised visualizations by cross-article reuse: trait-
  loading heatmap with rotation handled (5 / 5 articles need
  it); communality + variance-partition lollipop (4 / 5);
  ordination biplot (3 / 5); phylogenetic-signal partition
  stacked bar (H² + C²_non + ψ² = 1 per trait, ordered by H²,
  thin error overlay on H²) for phylo-GLLVM +
  functional-biogeography; ICC forest plot for
  behavioural-syndromes + functional-biogeography. Biology
  trap to enforce in every helper: rotational ambiguity --
  default varimax, document rotation method in caption, never
  auto-label LV1/LV2 with biological names. Secondary trap:
  communality (c²) ≠ heritability (h²).

### Maintainer additions

- **1D / 2D / 3D ordination dimension awareness**: dispatcher
  should detect the fit's latent rank `d` and dispatch
  appropriately. `d = 1` strip plot; `d = 2` standard biplot;
  `d = 3` pair-grid of three 2D panels via `patchwork`;
  `d > 3` user-selected `axes = c(i, j, k)` override.
- **First-class interactive options**: not stretch -- a
  baseline `interactive = TRUE` argument on `ordination` (and
  later other types if green-lit) that returns a `plotly`
  object. `plotly` stays in Suggests with `requireNamespace`
  guards.
- **Living-roadmap principle**: the page must surface that
  it's a snapshot, not a frozen plan. Concrete: "Last
  refreshed" date at top + "How this roadmap is maintained"
  section at bottom invoking the Roadmap-tick discipline.

## Checks run

- **Roadmap design**: three persona consults dispatched in
  parallel for the page design (Pat / Rose / Grace), then
  three more for the visualization-layer scope (Pat / Emmy /
  Darwin). Each persona's brief read the canonical files
  (decisions.md, audits, after-task reports) before reviewing.
- **Path verification**: confirmed `_pkgdown.yml destination:
  pkgdown-site` (line 5) excludes `docs/` from render; this
  is the reason cross-refs use absolute GitHub URLs.
- **`.Rbuildignore` verification**: `^ROADMAP\.md$` already
  present at line 11; no CRAN-build action required.
- **Recent merges list**: pulled from `git log --oneline
  origin/main -12` for the rolling callout.
- **Pkgdown render**: NOT run locally from this branch.
  Recommend the CI run be the first verification render;
  if `pkgdown::check_pkgdown()` flags anything, the
  follow-up is a small fix-up on this same branch before
  merge. (See "Known limitations" below.)

## Consistency audit

The refreshed roadmap aligns with current canon:

- Notation: every math reference uses `Ψ` / `ψ` (Greek), not
  `S` / `s`. Engine-algebra ASCII references say `Psi` /
  `psi`. Matches the 2026-05-14 `decisions.md` notation
  reversal.
- Phases: 15 rows in the at-a-glance table; covers NS,
  1a – 1f, 1c-viz (NEW), 2, 3, 4, 5, 5.5 (NEW), 6.
- Function-name retention: `two_U` task labels preserved per
  2026-05-12 + 2026-05-14 decisions; the refreshed roadmap
  uses `two_U` only where it's already a function or file name,
  never in math prose.
- Cross-link domains: every cross-ref uses
  `https://github.com/itchyshin/gllvmTMB/blob/main/...` or
  `tree/main/...`, never relative paths.
- Stale-legacy claim corrected: the old ROADMAP's mention of
  `extract_ICC_site`, `getLoadings`, `ordiplot` as "legacy
  helpers to be removed before deletion" is corrected (Phase
  2's export audit decides keep / internalise / delete).

## Tests of the tests

No new tests in this PR. `pkgdown::check_pkgdown()` is the
relevant verification; it runs on CI after R-CMD-check passes
on main. Local `check_pkgdown()` was not run from the
roadmap-page branch in this round (acknowledged limitation).

## What went well

- The drmTMB inspiration translated cleanly. The persona
  consults caught the key adaptation points (chips, TL;DR,
  cross-link mechanics) without me having to fight upstream
  for each one. Pat's TL;DR adoption-state callout is the
  best single design decision -- it gives applied users a 3-second
  safety signal that the old roadmap did not have.
- Emmy verifying the dispatcher pattern was already half-built
  saved a phase of greenfield work. Phase 1c-viz is "complete
  + polish" not "build from scratch", which is much smaller
  scope than the maintainer might have feared.
- The Roadmap-tick discipline is a real systemic fix, not a
  patch. It bridges per-PR memory to the public page; without
  it the 2026-05-11 → 2026-05-14 drift pattern would have
  recurred. Rose flagged it; codifying it in the after-task
  protocol is the durable form.
- Living-roadmap principle baked in at the top (`Last
  refreshed` date) and bottom ("How this roadmap is
  maintained" callout), so the page is honest about its
  snapshot-not-aspirational nature.

## What did not go smoothly

- **Plan-mode ExitPlanMode was rejected once**; the user
  wanted to see the 70-item phase / task / step table before
  approving. The table-in-chat was a useful intermediate
  artefact; in retrospect I should have offered it
  proactively rather than waiting for the rejection. Lesson:
  when a plan has many discrete items, render the table
  inline before calling ExitPlanMode.
- **The 2026-05-14 strategic plan revision** (Phase 5.5
  addition) lived in the plan file and after-task only, never
  in `docs/dev-log/decisions.md`. The refreshed roadmap had
  to write that ratification entry first, in the same PR, so
  the roadmap didn't cite vapour. This is a generalisable
  pattern: future strategic-plan additions should land in
  `decisions.md` first, plan file second.
- **Persona-consult round 2 needed an unplanned third
  consult** when the maintainer added 1D / 2D / 3D
  dimension-awareness and first-class interactive options
  mid-design. This was a reasonable scope expansion; the
  takeaway is that visualization design needs both the
  applied-user lens (Pat) and the dimension-aware
  architecture lens (Emmy + Boole) before locking scope.
- **Local pkgdown render was not performed from this branch.**
  Acknowledged; the first CI run on the PR is the verification.
  If it surfaces any rendering issue (broken knitr child
  inclusion, malformed table, etc.), a small fix-up commit on
  this branch is the response.

## Team learning, per AGENTS.md "Standing Review Roles"

- **Ada (maintainer)**: the "show me the table" pivot mid-plan
  was the right call -- it surfaced that the markdown nesting
  in my plan file wasn't scannable to a reviewer's eye. Lesson:
  for any plan with 50+ discrete items, render a flat table
  before asking for approval. Also: the three iterative scope
  refinements (visualization, 1D / 2D / 3D, interactive
  options, README footer) show the value of small, named
  scope additions over an attempted one-shot full plan.
- **Boole (R API / formula)**: standing brief; no formula
  grammar change. The `plot(fit, type = ...)` API surface
  reviewed in Phase 1c-viz will need Boole's signature audit
  when the dispatcher extension PRs open.
- **Gauss (TMB likelihood / numerical)**: standing brief; no
  engine change. The Phase 1b correlation fix and the Phase
  5 `mu_t` finite-check polish remain in the roadmap as
  Gauss-engaged items.
- **Noether (math consistency)**: confirmed the Ψ / ψ
  convention is honoured throughout the refreshed roadmap.
  No partition equation, decomposition formula, or notation
  drift surfaced during the write.
- **Darwin (ecology / evolution audience)**: persona consult
  on visualization layer named the biological question per
  article and ranked visualizations by cross-article reuse.
  The phylogenetic-signal partition stacked-bar choice (H² +
  C²_non + ψ² ordered by H², error overlay on H²) is a
  concrete, biologically motivated design decision now in
  Phase 1c-viz scope. Darwin's biology-first reframe items
  (`morphometrics.Rmd` and `functional-biogeography.Rmd`
  first sentences) remain queued for Phase 1e.
- **Fisher (statistical inference)**: standing brief for
  Phase 1b validation; the ≥ 94 % coverage exit criterion is
  preserved in the refreshed roadmap. galamm Wald-only
  comparator placement is preserved.
- **Emmy (R package architecture)**: verified the
  `plot.gllvmTMB_multi(x, type = ...)` dispatcher already
  exists in `R/plot-gllvmTMB.R` with five plot types. This
  finding changed Phase 1c-viz from "build greenfield" to
  "complete + polish" -- a substantial scope reduction.
  Recommended Option (D) Hybrid (which is in place) over
  standalone helpers or `autoplot()`-only. ggplot2 stays in
  Suggests; plotly joins Suggests for the interactive option.
- **Pat (applied PhD user)**: caught the legibility gaps that
  would have shipped the old roadmap as a developer artefact
  rather than a user-facing page. The 🔴 🟡 🟢 adoption-state
  callout is now the first thing a reader sees, before any
  phase breakdown. Pet-peeve interpretation traps (correlation
  inflation, communality ≠ heritability) are now in Phase
  1c-viz polish scope.
- **Jason (literature / scout)**: standing brief. No landscape
  scan triggered by this PR; next scan is the pre-Phase 1b'
  scan bundled into that milestone PR.
- **Curie (simulation / testing)**: standing brief.
  `vdiffr` snapshot tests for the plot types are in Phase
  1c-viz scope (Curie's lane). Phase 1b edge-case profile-CI
  tests remain in Phase 1b scope.
- **Grace (CI / pkgdown / CRAN)**: persona consult on
  rendering mechanics gave the precise `_pkgdown.yml`
  addition + the absolute-GitHub-URLs cross-link rule.
  Verified `.Rbuildignore` already excludes `ROADMAP.md`.
  Emoji rendering safe across platforms. No new CI risk;
  pkgdown deploys on `workflow_run` after R-CMD-check passes
  on main.
- **Rose (systems audit)**: flagged the Phase 5.5 vapour-citation
  risk and the drift-recurrence risk. The "Roadmap tick" line
  in the after-task protocol is the durable systemic fix; the
  Phase 5.5 `decisions.md` entry in this same PR is the
  immediate fix. Both adopted.
- **Shannon (cross-team)**: Codex absent. No cross-team
  coordination action needed; the roadmap-page branch is
  Claude-only.

## Roadmap tick

This is the first PR using the new "Roadmap tick" required
section codified in
[`docs/design/10-after-task-protocol.md`](https://github.com/itchyshin/gllvmTMB/blob/main/docs/design/10-after-task-protocol.md).

> **Roadmap tick**: `ROADMAP.md` did not previously exist as a
> rendered pkgdown article. This PR creates the rendered
> roadmap and ticks **every row** to its current chip +
> progress bar against canon (decisions.md, after-task
> reports, audits, recent merges). New phase rows added:
> Phase 1c-viz (Visualization layer completion, ⚪ Planned,
> 0/7); Phase 5.5 (External validation sprint, ⚪ Planned,
> 0/8). The full row inventory is in `ROADMAP.md` itself.

## Design-doc updates

- `docs/design/10-after-task-protocol.md` -- new "Roadmap
  Tick" required section + added line in the Required
  Sections list. This codifies the per-PR mechanism for
  keeping the rendered roadmap in sync with canon.

## pkgdown / documentation updates

- `_pkgdown.yml` -- new navbar entry `roadmap` between
  `articles` and `reference`; new `navbar.components.roadmap`
  with `text: Roadmap` and `href: articles/roadmap.html`.
- `vignettes/articles/roadmap.Rmd` -- new wrapper article
  that uses a knitr child chunk to include `../../ROADMAP.md`.
  The wrapper is the pkgdown render path; pkgdown does not
  auto-render root markdown.
- `ROADMAP.md` -- full rewrite as described above.
- `README.md` -- new "Roadmap" section at the bottom linking
  to the rendered roadmap article, mirroring drmTMB.

## Known limitations and next actions

**Known limitations**:

- Local `pkgdown::check_pkgdown()` not run from this branch.
  First CI run is the verification.
- The cross-link to
  `docs/dev-log/after-task/2026-05-14-phase-1a-batch-b.md`
  will 404 until Phase 1a Batch B's PR merges (Batch B is
  committed locally on `agent/phase1a-batch-b` but not pushed
  yet, awaiting maintainer review of its after-task report).
  This is acceptable: the cross-ref records the intended
  destination; it resolves once Batch B lands.
- Phase 1c-viz row in the roadmap cites an as-yet-unwritten
  `docs/dev-log/decisions.md` entry for the visualization
  scope. The Phase 5.5 entry IS in this PR, but the Phase
  1c-viz scope is currently only in the strategic plan + this
  after-task. Next-action item: when the first Phase 1c-viz
  PR opens, the maintainer's go-ahead becomes the formal
  ratification; a small `decisions.md` entry can land
  alongside.

**Next actions**:

1. Push `agent/roadmap-page`; open PR; let CI run.
2. After CI green: maintainer review (the maintainer
   explicitly asked to check the rendered page before
   merging).
3. Self-merge once approved; pkgdown re-renders the rendered
   article on the next push to main after R-CMD-check passes.
4. Concurrent: maintainer review of Phase 1a Batch B's
   after-task (`agent/phase1a-batch-b`); Batch B push + PR +
   merge follows that review.
5. After roadmap merges: the roadmap-tick discipline becomes
   live; every subsequent after-task report must include the
   Roadmap-tick line.
6. **Phase 1a continuation**: Batch D (`gllvmTMB_wide()` →
   `traits(...)` in 2 vignettes), then Batch E (`\mathbf{U}`
   → `\boldsymbol{\Psi}` in behavioural-syndromes + roxygen
   sweep of `R/extract-two-U-via-PIC.R`).
7. **Phase 1b**: engine + extractor fixes (P1 + P2 + Fisher
   diagnostics + edge-case tests).
