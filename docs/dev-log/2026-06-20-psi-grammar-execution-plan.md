# Execution plan: unique→Psi grammar migration (Item 5, approved 2026-06-20)

Maintainer approved the `latent()`-carries-Psi grammar migration (HELD-item 5).
This is the single highest-risk change in flight — a **formula-grammar + engine**
change subject to the strictest project gates (Boole sign-off, Definition-of-Done
recovery test, and the AGENTS.md rule #10 convention-change cascade, where a
partial cascade is a *hard violation*). It must NOT be rushed or self-merged. This
plan makes it executable in one dedicated pass.

**Do NOT cherry-pick the stale dirty-branch commit `d7826f0`** — it is 120+ commits
behind current `main` and carries stale doc versions. Re-derive against current
`main` (`89131d1`).

## The grammar decision (what is IN)

- Ordinary `latent(...)` carries its diagonal Psi companion **by default**
  (`residual = TRUE`), i.e. `Sigma = Lambda Lambda^T + diag(psi)`.
- `latent(..., residual = FALSE)` requests the old no-residual / rotation-invariant
  subset; `common = FALSE` default.
- `extract_Sigma(..., part = "psi")` alias added.
- `unique()` / `*_unique()` / `kernel_unique()` fire `lifecycle::deprecate_soft(when = "0.2.0")`
  but **stay compatibility syntax** — NO removal claim while exports/parser live
  (the dirty branch is already compliant: zero NAMESPACE removals, NEWS says
  "remains compatibility syntax").

## Code pathspecs (re-derive against current main)

1. `R/brms-sugar.R`: `latent()` gains `residual = TRUE`, `common = FALSE`; the
   parser auto-emits the paired diagonal Psi companion
   (`call('+', new_call, psi_call)` with `.latent_psi = TRUE`) unless
   `residual = FALSE`; add `.gllvmTMB_warn_unique_family_deprecated()`.
   **Normalise to space indentation** — the dirty version added 88 tab-indented
   lines into a space-only file; kill that churn.
2. `R/fit-multi.R`: `.auto_residual` / `.auto_psi` detection; `drop_psi`
   suppression (drop auto-Psi when an explicit diagonal on the same grouping
   exists, or for families 12/13/14); `diag_B_slope_is_default` reaction-norm
   default. **Engine dispatch — Noether review.**
3. `R/extract-sigma.R`: `part = "psi"` alias for `extract_Sigma()`. (NB: this file
   also now carries the salvaged coevolution exports from #500 — rebase order
   matters; sequence after #500 lands or resolve the append region.)
4. `R/unique-keyword.R` + the keyword roxygen files: soft-deprecation wording.

## Cascade targets (AGENTS.md rule #10 — ALL required in the SAME PR)

- Every roxygen `@examples` using `unique()`/`latent()` → regenerate `man/*.Rd`.
- `vignettes/articles/*.Rmd` chunks using the convention (run
  `pkgdown::build_articles(lazy = FALSE)`).
- The canonical example in `docs/design/00-vision.md`, the README Tiny example,
  the keyword grid in `AGENTS.md` + `CLAUDE.md`, and any NEWS code chunk.
- `NEWS.md` entry (scope-boundary statement, register row IDs).
- `docs/design/01-formula-grammar.md` (the canonical grammar contract) +
  `docs/design/35-validation-debt-register.md` rows.
- The after-task report must **enumerate every example file touched** and state
  which were verified clean.

## Verification gates (Definition of Done)

- `devtools::document()` clean; `devtools::test()` green, including a **Gaussian
  simulation recovery** on a known DGP showing `latent()` (auto-Psi) reproduces
  the explicit `latent(...) + unique(...)` fit (loglik + Sigma within tolerance) —
  the recovery evidence the grammar change requires.
- **Wide/long byte-identity**: `traits(...)` and the long `0 + trait` form produce
  the same fit.
- A negative/forced-`n_lhs_cols` test as in the Phase 56.4 anchor pattern.
- `pkgdown::check_pkgdown()` + `build_articles(lazy = FALSE)` clean.
- **Boole** (formula grammar) + **Noether** (engine contract) sign-off; **Rose**
  cross-file cascade audit; **Pat** reads one article as an applied user.

## Sequencing

- Land after (or coordinate with) gllvmTMB #500 (coevolution salvage) since both
  touch `R/extract-sigma.R`.
- One reviewable PR (the cascade must be atomic). No `src/`/C++ change → no
  recompile risk, but the parser/engine change is real — full local check before
  push, held for maintainer + Boole.

## Why this is a dedicated pass, not an inline slice

The cascade spans dozens of example/vignette/man files plus a parser/engine
change with a recovery-test gate and two named-reviewer sign-offs. Rushing it
risks an incomplete cascade (a hard violation) or a subtle parser regression.
This plan + the HELD-item audit memo (`2026-06-20-held-item-reconciliation-audit.md`)
are the executable handoff.
