# After-task: MSPL Tweedie Phase-4-style prep (planned only)

**Date:** 2026-08-15
**Lane:** `cursor/mspl-phase4-tweedie`
**Worktree:** `/private/tmp/gllvmtmb-mspl-phase4-tweedie`
**PR:** https://github.com/itchyshin/gllvmTMB/pull/973 (stacked on #971)

## Scope

Land the sibling Tweedie science on this isolated worktree with a
lane LOOP kit. Do **not** rewrite the note or oracles. Planned on
paper only. Not admission.

## Outcome

- Copied (not rewritten) from the shared worktree:
  `docs/dev-log/research/2026-08-15-mspl-phase4-tweedie-prep.md`
  `tests/testthat/test-mspl-tweedie-phase4-oracles.R`
- LOOP kit
  `docs/dev-log/lanes/cursor-mspl-phase4-tweedie/LOOP/`
- Registry and prepare **untouched**. No `R/mspl.R`, no `src/`.

## Checks

```sh
OMP_NUM_THREADS=1 NOT_CRAN=true
pkgload::load_all(".", compile = FALSE)
testthat::test_file("tests/testthat/test-mspl-tweedie-phase4-oracles.R")
# PASS 62
#   E1  6   information W = mu^{2-p}/phi; Poisson + Bernoulli differ
#   E2  4   mean path mu -> 0 sends P_J to -Inf
#   E3  8   phi -> Inf sends P_J to -Inf and P(Y=0) to 1; phi -> 0 raises P_J
#   E4 10   matched P(Y=0) identifies W, not the (mu, phi) pair
#   E5  4   p -> 2- makes W mean-inert; kills point mass
#   E6  4   p -> 1+ recovers mu/phi; Poisson W=mu only if phi=1
#   E7  8   information size is sum(mu^{2-p}/phi), not sum(mu) or P(Y=0)
#   E8  4   Hirose Psi refused
#   E9  6   V_loading is (mu, phi, p)-inert; P_J moves
#   E10 5   no Tweedie registry row; not admitted; not planned
#   no-live 3   never estimator=mspl; prepare not widened to 6L
testthat::test_file("tests/testthat/test-mspl-registry.R")  # PASS 26
git diff --stat -- src/ R/mspl.R R/mspl-registry.R         # empty
```

## Non-claims / OPEN GATE

- No C++ tape; no `estimator="mspl"` on Tweedie; no NEWS covered;
  no registry row; no prepare widen; no merge.
- **OPEN GATE:** Shinichi + Phase 4 Poisson/NB order before any
  Tweedie registry row or `admitted` flip.

## Mathematical contract

No public API / likelihood / grammar / family change. Science is
the sibling note: \(I(\beta_*)=X_*^\top\operatorname{diag}(\mu^{2-p}/\phi)X_*\);
\(\Pr(Y=0)=\exp(-\mu^{2-p}/(\phi(2-p)))\).

## Roadmap tick

N/A — planned prep; no ROADMAP row.

## GitHub issue ledger

No relevant open issue; no new issue created.

## Team learning

- **Rose:** this lane copies sibling science; it does not author a
  second Tweedie atom. LOOP lives here, not on the shared WT.
- **Curie:** 62/62 re-verified on this worktree after the copy.
