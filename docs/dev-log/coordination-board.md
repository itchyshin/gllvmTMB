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
| (none) | -- | -- | -- | No active Codex lane after PR #229 merge |

**WIP**: 0.

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
| `R/*` | no active engine owner after #226 merged. Recent parser/API edits on `main` are from PR #226 (`meta_V(V = V)`, `type = "exact"`, wide `traits()` marker preservation). Coordinate before further R edits. |
| `tests/testthat/*` | no active owner after #226 merged; new `meta_V()` parser and wide-format tests are now on `main` |
| `src/gllvmTMB.cpp` | no owner in this lane; do not edit |
| `inst/prototypes/ppcheck-diagnostics.R`, `docs/design/51-posterior-predictive-diagnostics.md` | no active owner after PR #229 merged |

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
