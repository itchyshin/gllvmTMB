# Claude Code Instructions for gllvmTMB

This repository is shared by humans, Codex, and Claude Code. Read
`AGENTS.md` first; it is the source of truth for project rules.

## Live Phase Snapshot — 2026-07-28

- **2026-07-28 (LATEST) — AGHQ ENGINE LANE: BUILT, OPT-IN, DEFAULT UNCHANGED.**
  Lane `claude/aghq-engine-20260728`, 20 commits, **not pushed, no PR**.
  **START HERE:** `docs/dev-log/handover/2026-07-28-claude-handover-aghq-engine.md`,
  then the lane map `docs/dev-log/handover/2026-07-25-active-lane-split.md`.
  AGHQ ships **opt-in** (`gllvmTMBcontrol(aghq = k)`); **the default is still Laplace and
  no existing user's numbers move**. Headline: Laplace carries a flat **~21% downward
  bias that 16× more data does not touch** (its error is O(1/T), per CLUSTER), while AGHQ
  reaches **1.0021 at n = 3200**. With a weakly-informative ridge on the loadings
  (`aghq_ridge = 2`, on when AGHQ is on) it beats the shipped Laplace on **both** latent
  SD and correlations at every n tested (954 fits, Totoro). **Name the comparator** — a
  hypothetical penalised Laplace edges rho at n ≤ 200. **NOT done:** the family axis
  (binomial-only evidence), the D-43 panel, and any coverage/interval evidence.
  The invariant to re-check after ANY engine edit: **gaussian exactness ~1e-13 and
  k-independent**. Durable finding in the brain: *"AGHQ exposes a flat likelihood
  direction in GLLVMs — the runaway is bimodal, not biased."*
- **2026-07-28 (earlier, superseded by the bullet above) — AGHQ IS THE MAIN
  ENGINE.** Maintainer decision, `docs/dev-log/decisions.md` 2026-07-28: AGHQ
  becomes gllvmTMB's integration engine across all 16 families and all model
  classes, adaptive and auto-by-default. **This reverses the 2026-05-15 "stay
  Laplacian" decision**, whose grounds were sound but rested on reading the
  literature's `n_i` as sites rather than **traits per site** — the gain is large
  exactly where `T` is small. **The Arc 0 fence is LIFTED**: the 59/70
  identifiability question no longer gates the build; it becomes AGHQ's first
  acceptance test (H4). **PR #798 is MERGED** (`72c2e53d`). Lane:
  `claude/aghq-engine-20260728`, worktree
  `/private/tmp/gllvmtmb-arc0-identifiability`. Plan:
  `~/.claude/plans/starry-booping-starfish.md`.
  **Two standing corrections.** (1) *"AGHQ inherits all 16 families, phylogeny,
  spatial and missing data"* is **NOT ESTABLISHED as stated** — families and
  missing data survive; phylogeny and spatial **break** under a product rule and
  need a nested AGHQ-inside-Laplace decomposition; `REML = TRUE` is excluded
  outright. Use the narrower form recorded in `decisions.md`. (2) The AGHQ spike's
  **`1.4e-9` agreement is at ONE node, and one node IS Laplace** — it proves the
  plumbing, not the quadrature. Never cite it as evidence about `k > 1`.
- **2026-07-28 — VA/EVA + AGHQ lane (historical; see the bullet above).** **PR #799 MERGED** (`dc10fa6a`):
  a collapsed variance component could pass every check the package had
  (`near_zero_psi_unit … PASS … 0.0006826` for a component whose *variance* was
  `4.7e-7`) — now detected relative to siblings; `start_method = "res"`
  soft-deprecated on 89 fit-pairs. **PR #798 OPEN and CI-GREEN** (no API change,
  nothing exported): per-family registry (4/16 families, proven by porting
  `nbinom2` through it), **calibrated** VA standard errors (`se_profile` covers
  0.935–0.950; a block-diagonal Schur replaced a 5.45 GB dense Hessian with
  9.1 s / 220 MB at n=5397), and an Ayumi-scale second opinion (Laplace
  `rel_frob` 0.167 vs VA-GH **0.103**). **DECISION: invest in Laplace + AGHQ,
  freeze VA** — AGHQ inherits all 16 families plus the phylo/missing surface,
  whereas VA reaches 4/16 and covers 2 of Ayumi's 27 responses. The AGHQ q=2
  transfer test passed 5/5 (`c_full` 1.064; kill rule cleared). **NEXT ARC:
  settle the 59/70 identifiability question BEFORE building anything** — three
  hypotheses have died and the survivor is that those fits are well-converged
  optima of *unidentified* models, in which case no fit-side diagnostic can flag
  them and the deliverable is a warning, not a better estimator. Brief:
  `docs/dev-log/2026-07-28-morning-brief.md`; handover:
  `docs/dev-log/handover/2026-07-28-claude-handover.md`.
- **Multi-lane split:** do not assume one active writer.  The current Claude
  release/profile lanes and the remaining Codex-owned eta-simulation lane are
  separately fenced.  Do not edit or run the eta lane from Claude.
- **Current state:** Design-103 direct-GH mechanism diagnosis is privately
  closed `TECHNICAL_PARTIAL`; it produced no package/public claim.  The
  release/0.6 and profile/Tier-2a states must be re-derived from their named
  handovers before any edit.
- **2026-07-25 (latest):** the Site × Species phylo arc is **CLOSED** — capability
  **CANCELLED** by decision (no new API; the M3 freeze holds), two user-facing bug
  fixes plus the first `gllvm` fit-level comparators landed on `main`
  `a0f568d1..84ca8290`, and a D-43 panel returned **3/3 NOT-DONE** so **nothing was
  promoted**. The keyword grid was corrected to **5 × 3** across the rule files.
  **Next arc is UNCHOSEN** (not CRAN, not the paper — Shinichi reserved the choice);
  standing interest recorded in **EVA**. Handover:
  `docs/dev-log/handover/2026-07-25-claude-handover-arc-closed.md`.
- **START HERE:**
  `docs/dev-log/handover/2026-07-25-active-lane-split.md`, then the
  target-specific handover it names.

The older handoff narrative below is historical and must not override this
snapshot, the latest handover, or `AGENTS.md`.

For historical context, the former handoff was
`docs/dev-log/handover/2026-07-18-claude-handover.md` (Claude→Claude, 2026-07-18;
**the multinomial cross-family arc is SHIPPED to `main`** — item 1 matrix
`link_residual` (#758), item 2a-ii cross-family correlations +
`extract_cross_correlations()` (#761), and `unique = TRUE` default + the
`Psi = unique + link-specific` consistency fix (#762). A `multinomial()` trait now
shares a shared `latent()` factor with Gaussian/binary/count/ordinal traits and
reports genuine cross-family correlations. **NEXT arc (chosen 2026-07-18):
calibrated cross-family intervals** — attach certified-coverage uncertainty to
`extract_cross_correlations()`, closing the CI-08/CI-10 `heuristic_unvalidated`
debt (the 0.6→1.0 headline); the item-3 recovery certificate is deferred behind it.
Multi-seed always; Rose before any covered claim; compute local→Totoro (D-50).) Earlier:
`docs/dev-log/handover/2026-07-12-claude-handover-covariance.md` (Claude→Claude,
evening; the covariance-mode grammar campaign — Design 79/80, `scalar()`/
`kernel_scalar()`, `indep(1+x)` per-trait) before starting new work. Branch
`claude/release-0.5.0` is PUSHED with the doc-honesty cleanups (pages 4–6, LV +
register sweeps, reference/roxygen sweep, `validation_row` print-fix); the
`1.0.0 → 0.5.0` version correction (PR #748) is MERGED to `main`. Standing rule:
reader-facing content shows only what makes sense to the reader — no internal
register codes on any surface (articles, reference/roxygen, NEWS, printed output).
**gllvmTMB's first CRAN release is `0.5.0`, NOT 1.0 (D-42, 2026-07-11) — 1.0 is
reserved for the capability-maturity milestone (complete surface + full story +
committed-stable API), mirroring drmTMB's D-40.** The engineering (all five arcs
A–E, merged #737–#745, on `main` `e4188105`) is cross-OS verified — local
`--as-cran` 0E/0W/0N, 3-OS `R CMD check` passed, 4478 tests / 0 failures — but the
package is NOT submitted to CRAN. **The one thing NOT done — and the next session's
job — is the one-by-one human review of the pkgdown pages and the function docs
WITH Shinichi** (slow, deliberate; not a batch rewrite), where the honesty-fencing
lands (intervals framed recovery-only; delta/hurdle latent-scale correlation "do
not advertise"). The automated article cleanup is **open PR #746** (2 cut, 26
improved, pkgdown reorganised); the QG `animal-model` cut-vs-keep call is open. The
issue closeout is staged at `dev/issue-closeout-2026-07-10.sh` (Shinichi runs it —
reword its version strings to 0.5.0 first; the agent is safety-blocked from bulk
closes). CRAN submission is Shinichi's act. Toward the 1.0 maturity milestone:
Julia parity, the paper, the full coverage campaign. Earlier arc detail:
`docs/dev-log/handover/2026-07-09-claude-handover-arcs.md`; ultra-plan at
`~/.claude/plans/misty-snacking-papert.md`.
**`phylo_latent(unique=TRUE)` = structured + DIAGONAL ψ, NOT a non-phylo
ordination** (that is a second `latent` term) — a standing guard.

## Project Identity

`gllvmTMB` is a sister package to `drmTMB`, but it has a different
role:

- `drmTMB`: univariate and bivariate distributional regression.
- `gllvmTMB`: multivariate stacked-trait GLLVMs with phylogenetic
  and spatial extensions.

Keep `gllvmTMB` focused on the stacked-trait, long-format multi-
response model. Single-response models live in `glmmTMB`; spatial
single-response models live in `sdmTMB`.

For the full cross-package scope record (including `gllvm`,
`MCMCglmm`, `brms`, the decision matrix, and the "what gllvmTMB
does NOT do" section), see
[`docs/design/04-sister-package-scope.md`](docs/design/04-sister-package-scope.md).

## Syntax Rules to Preserve

- Use the canonical **5 x 3 keyword grid**: five correlation **sources**
  (none, `animal_*`, `phylo_*`, `spatial_*`, `kernel_*`) x three
  trait-covariance **modes** (`indep`, `dep`, `latent`). Every cell is a
  live keyword. Canonical surface:
  `vignettes/articles/api-keyword-grid.Rmd`.
- **`scalar` and `unique` are MODIFIERS, not modes.** `scalar` is
  `indep(..., common = TRUE)` (trait variances tied to one shared
  value); `unique` is `latent(..., unique = TRUE)` (the trait-diagonal
  Psi companion). Never restate the grid as "4 x 5" or list `scalar` /
  `unique` as modes -- that framing is superseded.
- The named **scalar family** (`scalar()`, `phylo_scalar()`,
  `animal_scalar()`, `spatial_scalar()`, `kernel_scalar()`) is
  **soft-deprecated** and emits a one-time warning; it fits the same
  model as `indep(..., common = TRUE)`. Likewise `unique()` /
  `*_unique()` are soft-deprecated: new standalone diagonal examples use
  `indep()` / `*_indep()`, ordinary `latent()` carries Psi by default,
  and `latent(..., unique = FALSE)` requests the old low-rank-only
  subset. Both families remain accepted compatibility syntax until their
  own removal slices land.
- Design 65's dense-kernel row (`kernel_indep()`, `kernel_dep()`,
  `kernel_latent()`) is part of the grid above, not outside it. C1 must
  stay phylo-equivalent for dense `K` inputs to less than `1e-6`.
- Ordinary `latent()` carries its diagonal Psi companion by default:
  Sigma = Lambda Lambda^T + diag(psi) (the Greek letter
  Psi; see `decisions.md` 2026-05-14 notation reversal).
  Use `latent(..., unique = FALSE)` only for the old loadings-only /
  rotation-invariant ordinary subset (`residual =` is a soft-deprecated
  alias for ordinary `latent()` only). Source-specific and kernel
  latent terms are loadings-only by default; use
  `phylo_latent(..., unique = TRUE)`,
  `animal_latent(..., unique = TRUE)`,
  `spatial_latent(..., unique = TRUE)`, or
  `kernel_latent(..., unique = TRUE)` for source-tier
  `Lambda Lambda^T + diag(psi)` decompositions.
  `unique()` / source-specific `*_unique()` /
  `kernel_unique()` remain soft-deprecated compatibility syntax; new
  standalone diagonal examples use `indep()` / `*_indep()` /
  `kernel_indep()`.
- `*_latent(..., unique = TRUE)` is the canonical source/kernel folded
  decomposition; explicit `*_latent(..., unique = FALSE) + *_unique()`
  remains accepted compatibility syntax, and duplicate
  `*_latent(unique = TRUE) + *_unique()` is an error. Standalone
  `phylo_unique` / `animal_unique` carry diagonal-only structure.
- `meta_V(V = V)` is the canonical meta-analytic
  known-sampling-covariance keyword. `meta_known_V(V = V)` is
  a deprecated alias. `block_V(study, sampling_var, rho_within)` is
  the helper that builds V.
- Wide data-frame input uses the simplified `traits(...)` LHS grammar:
  `traits(t1, t2, ...) ~ 1 + latent(1 | unit, d = K)`.
  The same shorthand covers `indep()`, `dep()`, and `spatial_*()`;
  ordinary `(1 | group)` random intercepts pass through unchanged.
  Long-format `gllvmTMB()` uses the explicit `0 + trait` /
  `(0 + trait):x` grammar. Both shapes go through one entry point:
  `gllvmTMB()`. The legacy matrix wrapper `gllvmTMB_wide(Y, ...)` is
  soft-deprecated as of 0.2.0 -- new code should use the formula API,
  and removal must not be claimed while the export remains live.
- Phase 56.3 parser work admits `phylo_unique(1 + x | species)` and
  `phylo_unique(0 + trait + (0 + trait):x | species)` as augmented-LHS
  syntax. Phase 56.4 adds Gaussian recovery, wide/long byte-identity,
  and forced-`n_lhs_cols` negative-test evidence for the anchor
  `phylo_unique` cell. Keep user-facing advertising and validation-debt
  promotion parked until the Phase 56.6 register / NEWS / article slice.

## Before Finishing Work

- Run the narrow tests you touched, then `devtools::test()` more
  broadly when practical.
- Update design docs if grammar, likelihoods, families, random
  effects, phylogenetic, spatial, or meta-analysis behaviour
  changes.
- Add or update an after-task report in `docs/dev-log/after-task/`.
- For substantial prose, apply the `prose-style-review` skill.
- Do not revert Codex or human changes unless explicitly asked.

## Collaboration Rhythm

Claude Code and Codex work sequentially, never concurrently, in this
repository. The baton can move in either direction through a landed handoff.
The usual role pattern is:

- Claude Code gathers evidence, writes read-only audits, drafts
  decisions, and identifies the smallest safe PR shape.
- The maintainer chooses the next task at a discussion checkpoint.
- Codex implements bounded code, documentation, CI, pkgdown, or
  NAMESPACE changes and records checks.
- Claude Code or Codex can review the result, but the reviewer should
  not silently expand the implementation scope.

Stop for maintainer discussion before deletions, API changes, formula
grammar changes, likelihood changes, new families, or broad article
rewrites. For the current reader-path work, examples should present
long-format and wide-format calls together unless the function is
intrinsically one shape.

After-task reports are the closure rule. Any completed task or phase
that changes project state should leave
`docs/dev-log/after-task/YYYY-MM-DD-short-topic.md` with scope,
outcome, checks, and follow-up. This mirrors the `drmTMB` team habit
and is how the shared team learns without re-reading the whole diff.

Use Shannon before handoffs with branch switches, merge-order
questions, or more than one open coordination PR. Shannon is a
read-only cross-team audit: it checks working-tree hygiene, open PRs,
file overlap, CI state, message-bus coverage, and after-task report
coverage. Shannon reports; it does not edit or merge.

### Merge authority

For the active five-macro 0.6 lane, the handoff is stricter than the general
rule below: do not merge draft PR #778 without explicit maintainer authority.

Both Claude Code and Codex may merge their own PRs when CI is green
and the PR is **low-risk**: documentation, dev-log entries, audits,
after-task reports, design docs, CI workflow tweaks, asset additions,
or individual article rewrites against an approved snippet. For
**high-risk** changes -- deletions of public exports, API changes,
formula-grammar changes, likelihood / TMB / family changes, broad
article rewrites -- the agent must ask the maintainer before merging.
The `ROADMAP.md` "Discussion Checkpoints" list is the authoritative
high-risk set; the merge rule mirrors it.

### Integrate before adding

When the maintainer's input could fit an existing section in a doc or
plan file, integrate inline. Add a new section only for genuinely new
concerns. Reactive editing (every input becomes a new section) accretes
documents without improving them.

### Agent-to-agent handoffs go in the repo

When handing off a substantive task to the other agent, post a comment
addressed to them on the relevant PR, OR a directed line in
`docs/dev-log/check-log.md`. The async message bus is the repo; the
maintainer should not be the relay.

### Surface review asks explicitly

When opening a PR for maintainer review, follow up in chat with a
specific list of what the maintainer needs to check or decide. Do not
leave review items for the maintainer to discover by browsing the PR.

### Surface review touchpoints at stopping points (maintainer 2026-05-15)

At every natural stopping point -- task end, series-of-tasks end,
waiting on CI, waiting on permissions, end of a phase, before
switching context -- post a chat message that lists:

1. **Open PR links** (e.g. `https://github.com/itchyshin/gllvmTMB/pull/123`)
   that the maintainer can click to read.
2. **After-task report paths** that just landed or are about to land
   (e.g. `docs/dev-log/after-task/2026-05-15-day-recap.md`).
3. **Anything blocking** that the maintainer needs to decide or
   approve (prefixed with the 🔴 **Needs you:** chip per AGENTS.md).

The maintainer does not browse PRs on their own. The default
assumption is that if a stopping point arrives and the chat does not
surface links, the maintainer cannot review. This rule is durable and
applies to every session.

## Reusing sdmTMB / drmTMB Code

The R-side spatial helpers (`R/mesh.R`, `R/crs.R`, `R/plot.R`'s
`plot_anisotropy*`) are inherited from sdmTMB; `inst/COPYRIGHTS`
records the provenance and DESCRIPTION's `Authors@R` credits Sean
Anderson, Eric Ward, Philina English, and Lewis Barnett.

Selective reuse of A-inverse phylogenetic or further SPDE speed
modules from sister packages requires provenance notes in
`inst/COPYRIGHTS` and tests around the ported behaviour.
