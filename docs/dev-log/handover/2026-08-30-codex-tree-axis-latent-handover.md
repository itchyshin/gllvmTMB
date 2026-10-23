# Codex handover: complete both phylogeny-article models

Date: 2026-08-30. From Codex to a fresh Codex task.

## Critical context and goal

You are Codex, picking up a new article-correction lane, not the completed
iJSDM diagnostic and not its proposed 400-fit replication pilot.

Shinichi explicitly requested a fresh lane and corrected the intended models
in <https://itchyshin.github.io/gllvmTMB/articles/where-does-the-tree-go.html>:

1. Example 1 is missing `latent()` for the non-phylogenetic component.
2. Example 2 is missing `latent()` or `spatial_latent()` for residual
   species correlation/co-occurrence.

Deliver two runnable, scientifically aligned worked examples that retain the
article's distinction between a tree among sampled species and a tree among
response-column coefficients, while including the requested additional
covariance component. Preserve the fixed C3/C4 pathway effects and the
phylogenetic coefficient comparison in Example 2.

## What was accomplished in this handover

- Read the handover skill/protocol, ran lane preflight and landing checks.
- Inspected the live HTML via HTTPS and the article source on main.
- Verified remote main is `9c265e76b54ea0f238d5487066964dd81e897f65` at intake.
- Verified six older open PRs have no changes to this article or AGENTS.md.
- Created this isolated docs-only handover and additive AGENTS pointer.
- No model, DGP, article, R implementation, test, or public claim was changed.

## Verified article findings

Source: `vignettes/articles/where-does-the-tree-go.Rmd` at the intake main SHA.
Chunk names are more durable than line numbers.

- `species-axis-fit` contains only
  `phylo_latent(0 + trait | species, tree = tree, d = 1, unique = TRUE)`.
  It has no ordinary non-phylogenetic latent component.
- `column-axis-fit` compares `column_coef(1 + latitude | trait)` with
  `phylo_coef(1 + latitude | trait, tree = tree, rho = NULL)`, with no
  site-level latent covariance in either fit.
- Prose after that chunk explicitly says the example deliberately has no
  second site-level covariance term. This was an intentional earlier teaching
  restriction; Shinichi's current request supersedes it for the worked model.
- Example 1 currently draws independent trait columns through the tree matrix;
  it does not plant the requested two-component latent covariance decomposition.
- Example 2 currently adds independent Gaussian observation noise to the
  planted coefficient effects; it does not plant a residual shared site factor.
- Update the wide call, compact formula recap, tables, figures/captions and
  teaching text as well as the primary long calls. Search the entire article.

## Key model decisions to resolve before editing

Write the equation, DGP, formula, extractor and interpretation alignment first.

For Example 1, distinguish phylogenetic covariance among sampled species from
non-phylogenetic covariance at the intended biological level. The natural
candidate is a separate IID species-level latent component alongside the
phylogenetic species-level component. A population-level `latent(... | plot_id)`
answers a different question; do not silently substitute it for non-phylogenetic
between-species variation. Confirm supported grouping/composition on current main.
`unique = TRUE` inside `phylo_latent()` is trait-diagonal variation carried by
the same phylogenetic source, not an independent non-phylogenetic source.

For Example 2, retain the response-column coefficient distribution and add a
site-level latent component for remaining cross-species covariance. Prefer
ordinary `latent()` for the existing nonspatial fixture. A `spatial_latent()`
alternative requires a justified spatial fixture, coordinates, and a supported
composition; it is not interchangeable with ordinary IID site scores.

The coefficient prior's IID mixture at rho < 1 is not a replacement for
residual site-level species covariance. Coefficient covariance describes
species' intercept/slope deviations; residual latent covariance describes
co-occurrence conditional on those effects. Neither residual association nor
a latent axis proves a direct ecological interaction.

Keep Gaussian scope unless separately authorized. Inspect any confounding of
lowest-level diagonal Psi with Gaussian observation dispersion; use an
identifiable supported specification and explain it, rather than silently
duplicating variance components. Do not reuse the diagnostic's failed gates
as permission to change thresholds or promote interval coverage.

## Classification

| Item | State | Required action |
|---|---|---|
| Fresh article lane and handover | DONE once app task is created | Rehydrate, do not reuse the dirty mission-control checkout |
| Two fuller article models | OWED | Align equations/DGP/formulas and validate supported compositions |
| Long/wide examples and all dependent prose/plots | OWED | Update together, render and inspect |
| Earlier instruction to omit site covariance in Example 2 | RETRACTED for this revision | Replace with the maintainer's fuller model |
| Sampled-species versus response-column tree distinction | PROTECTED | Preserve throughout the revised explanation |
| Existing coefficient implementation and unrelated lanes | PROTECTED | Read for support; no new API/likelihood work under this task |
| Prior 52-fit iJSDM diagnostic | DONE | PR #1228, 14 gates passed, lease released; do not rerun |
| Proposed 400-fit iJSDM pilot | PROTECTED / deferred | Separate proposal, no approved seed map or launch authority |

## Current working and landing state

| Repo/artifact | Branch/main | CI and state | Plan by leverage |
|---|---|---|---|
| gllvmTMB baseline | main `9c265e76` | Diagnostic closeout verified; recheck freshness | Start an isolated article worktree |
| This handover + AGENTS pointer | `codex/tree-axis-latent-handover-20260830` | Docs-only; to be pushed as a draft PR, not auto-merged | Read the committed handover via that ref |
| Article correction | not implemented | OWED | Align, fit small examples, render, review |
| iJSDM replication proposal | external local proposal | Deferred; not a campaign | Separate future task/approval |

FINDINGS-OF-RECORD: none

The main mission-control checkout was on
`claude/codex-handover-20260820-randslope-terrapin` and had three foreign
untracked paths: `.codex/worktrees/`, `.worktrees/`, and
`docs/dev-log/lanes/cursor-mspl-arc-1a/LOOP/README.md`. Its broad landing check
also reported many unrelated unpushed historical branches. All are PROTECTED,
not this lane's unfinished work. Do not stage, clean, switch, or merge them.

The isolated handover checkout is
`/private/tmp/gllvmTMB-tree-handover-U2JgsD`. After fetching real origin/main,
its pre-write landing gate passed. Its initial false unpushed-history report
was caused by an unset remote tracking ref and was resolved by fetching main.

CARRIED-OVER: this docs-only handover branch is intentionally not merged by
the outgoing session, per the handover skill. Fetch
`origin/codex/tree-axis-latent-handover-20260830` and read the doc from that ref.
The sender's final message/PR supplies the commit and PR number. Do not claim
the article is corrected merely because this handover exists.

## Files created or modified by this handover

- `AGENTS.md`: additive dated handover pointer; existing multi-lane entrypoint retained.
- `docs/dev-log/handover/2026-08-30-codex-tree-axis-latent-handover.md`: this file.

No other file is part of this handover commit.

## Other lanes and deferred work

Read every row of `docs/dev-log/handover/2026-07-25-active-lane-split.md`,
`docs/dev-log/coordination-board.md`, and the existing 2026-08-26 Codex handover.
These remain the cross-lane index; this article task does not supersede them.
Older open PRs at intake: #1209, #1198, #1077, #1070, #1065 and #981.

The completed iJSDM diagnostic is documented in
`docs/dev-log/after-task/2026-08-29-isdm-identifiability-diagnostic.md` and
PR #1228. Its final local G13/G14 ledger delta is generated closeout evidence,
not unlanded implementation. The deferred pilot proposal lives at
`/Users/z3437171/local-scratch/receipts/gllvmTMB-isdm-replication-pilot-proposal.md`.
It is not part of this article task and must not be launched here.

## Next immediate steps and acceptance

1. Rehydrate and classify against live main; run lane preflight and inspect
   current PRs/leases. Claim only the article, dedicated tests and narrow
   closeout paths. The sender releases its handover-only lease after dispatch.
2. Use a bounded Ultra Plan and Unlazy ledger for this article correction.
   Name proposed grouping levels, separate covariance components, and any
   consequential identification choice before fitting.
3. Have a method reviewer check the symbolic alignment and supported model
   composition. Rose reviews scope/consistency; Pat reviews the reader path.
4. Run small retained example fits with a stated estimate. Confirm extracted
   component dimensions, finite point targets and long/wide equivalence;
   inspect warnings rather than masking them. If a necessary composition is
   unsupported, report it and ask before expanding into engine/API work.
5. Update DGP, equations, long/wide calls, results, plots and captions together.
   Render `articles/where-does-the-tree-go` from the intended installed source.
   Inspect desktop/mobile output, not only source strings.
6. Run relevant tests, pkgdown checks, required reviews and after-task/check-log
   closeout. Prepare a reviewed PR; verify CI before proposing merge. Respect
   the handover PR's no-auto-merge boundary. Do not claim the live site changed
   until deployment and its rendered formulas are checked directly.

## Live toolchain and boundaries

Codex owns the live R/TMB fit/check/render work in the new lane. Start with
`Rscript --vanilla`, inspect `R.version.string`, `.libPaths()`, and
`R CMD config CC` / `R CMD config CXX17`; do not reuse an unknown old DLL.
For example runs pin `OPENBLAS_NUM_THREADS=1`, `OMP_NUM_THREADS=1`,
`MKL_NUM_THREADS=1`. Enable `NOT_CRAN=true` only for deliberately selected
opt-in checks after reading their code. No new fit ran in the handover session,
so no fit-time or compiler-readiness claim is being transferred.

No 400-fit campaign, interval work, new exported helper, version bump, release,
or broad coefficient/likelihood change is authorized by this task.

## How to resume

Read AGENTS.md and this handover, then run:

```sh
git status --short --branch
git diff --stat
git fetch origin main codex/tree-axis-latent-handover-20260830
git show origin/codex/tree-axis-latent-handover-20260830:docs/dev-log/handover/2026-08-30-codex-tree-axis-latent-handover.md
```

Single paste for the new task:

> Rehydrate from AGENTS.md and the 2026-08-30 tree-axis latent handover on
> origin/codex/tree-axis-latent-handover-20260830. Start a fresh exact-main
> article-correction lane, classify every item, and execute only OWED work.
> Correct both examples' missing latent components with aligned simulations,
> equations, long/wide fits, interpretation and validation. Keep the iJSDM
> replication pilot separate and unlaunched.
