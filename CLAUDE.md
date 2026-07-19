# Claude Code Instructions for gllvmTMB

This repository is shared by humans, Codex, and Claude Code. Read
`AGENTS.md` first; it is the source of truth for project rules.
**🔴 FIRST, BEFORE ANYTHING: open the capability widget.** Every new session
opens `docs/dev-log/capability-surface.html` (live artifact
https://claude.ai/code/artifact/46e611f2-69d1-48e1-8b8b-ccab2e89983d) and shows
it to Shinichi as step 0 — it is the mission-control. Do this before reading
further or planning.

For the current handoff, read
`docs/dev-log/handover/2026-07-19-claude-handover-profile-cert-v3.md` (Claude→Claude, 2026-07-19;
**B3b Bartlett re-score COMPLETE — certificate WITHHELD at 0.95 (provisional)**: the opt-in Bartlett-corrected
χ²₁ crit lifted gaussian `Sigma_unit_diag` n≥150 coverage from the uncorrected 0.9455–0.9474 to 0.9486–0.9529
(closes ~half the residual gap; 0.94 floor held; honest ~2–4% widening) but did **not** reach a clean 0.95 (the
four 2·MCSE lower bands are all <0.95); **nothing promoted**; register CI-08/CI-10 updated non-promotingly with
the Design-73 disambiguation. the **formal 4-lens D-43 panel (2026-07-19) returned WITHHELD, unanimous for every n≥150 cell** — and found the
Bartlett route is a **NEGATIVE result (efficacy)**: the n≥150 correction is within MCSE of the uncorrected χ²₁
baseline (no demonstrable in-regime work). Nothing promoted. The n=400 b̂=318 anomaly is **diagnosed as a pooling
outlier** — a fresh n=400 b-estimation is normal (b̂=7.46), NOT a systematic large-n breakdown; fix = outlier-guard
in the b-estimator pooling. The Bartlett worktree was **DECIDED left UNCOMMITTED** (negative result). The gaussian
`Sigma_unit` diagonal profile remains a **0.94-gate** cell, not 0.95-certified. Do NOT re-run B3b — compute done,
results LOCAL D-50.) Prior handoff:
`docs/dev-log/handover/2026-07-18-claude-handover-profile-cert-v2.md` (the pre-B3b state). Earlier:
`docs/dev-log/handover/2026-07-18-claude-handover.md` (Claude→Claude, 2026-07-18; capstone coverage
RECONCILED — bootstrap is the WRONG route for `Sigma_unit_diag`; certificate path = PROFILE / log-SD-Wald,
Design 73). Prior handoff:
`docs/dev-log/handover/2026-07-17-claude-handover-750-spatial-done.md` (Claude→Claude, 2026-07-17;
**#750 spatial SPDE unconditional RE redraw SHIPPED** — `bootstrap_Sigma()`/`coverage_study()`/the other
simulate-based CIs are now valid (non-collapsed) for base spatial fits; the redraw is proven
distributionally exact (recovery test + adversarial Opus review; `perm=FALSE` crux) and the coverage DoD
is met IN-REGIME (n≥150, mean 0.946 = the Sigma_unit certificate); `spatial_latent`/`dep`/slope stay
fail-closed. 7 commits `dd80244a`…`051eb4e5`, pushed, lane clean. **NEXT ARC (Shinichi-chosen): the
CAPSTONE METRIC-REPAIR** — repair the coverage/power capstone harness (CI-08/CI-10 rows, binary-harness
mislabelling, ordinal-probit rows; #349/#346, Design 66) that gates CRAN + the methods paper; ultra-plan
it, compute on Totoro/DRAC, results LOCAL D-50). It supersedes the earlier coverage-certificate handover
`docs/dev-log/handover/2026-07-17-claude-handover-coverage-shipped.md` (which shipped the Sigma_unit
certificate `dd80244a` and holds the full "Remaining arcs" map). Earlier:
`docs/dev-log/handover/2026-07-13-claude-handover.md` (Claude→Claude; the `||`
uncorrelated random-slope coupling axis COMPLETE across all sources, merged to
`main` @ `8ec261bb`) before starting new work. **Strategy: 0.5 is the
"cover-everything" dev cycle — we do NOT release 0.5; we accumulate the
0.5.0→1.0 gap list and release at 0.6.** Next move: **ultra-plan the gap
closure** (interval coverage is the headline). (The premature `v0.5.0` tag was
DROPPED — 0.5 is not a release.) Earlier handover:
`docs/dev-log/handover/2026-07-12-claude-handover-covariance.md`. Standing rule:
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

- Use the canonical 4 x 5 keyword grid (correlation x mode):
  `latent`, `unique`, `indep`, `dep`, `scalar`, with `phylo_*` and
  `spatial_*` variants plus the `animal_*` known-pedigree row. As of
  2026-06-18, `unique()` / `*_unique()` are soft-deprecated
  compatibility syntax: new standalone diagonal examples use
  `indep()` / `*_indep()`, ordinary `latent()` now carries Psi by
  default, and `latent(..., unique = FALSE)` requests the old
  low-rank-only subset. Paired explicit-Psi examples and source-specific
  `*_unique()` forms remain accepted as compatibility syntax until
  their own fold/removal slices land.
- Design 65 adds the generic dense-kernel quartet outside that
  source-specific grid: `kernel_unique()`, `kernel_indep()`,
  `kernel_dep()`, and `kernel_latent()`. C1 must stay
  phylo-equivalent for dense `K` inputs to less than `1e-6`.
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

Claude Code and Codex can work in parallel only when the write scopes
are separate and the handoff is explicit. The default pattern is:

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
