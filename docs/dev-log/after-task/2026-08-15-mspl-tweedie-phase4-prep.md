# After-task: MSPL Tweedie Phase-4-style prep (planned only)

**Date:** 2026-08-15
**Lane:** `cursor/mspl-phase4-tweedie`
**Worktree:** `/private/tmp/gllvmtmb-mspl-phase4-tweedie`
**Arcs:** A0–A3

## Scope

Phase-4-*style* prep for Tweedie LA-MSPL: pin power/dispersion
weights and mass-at-zero as **not** the Poisson all-zero atom.
Planned on paper only. Not admission. Constitution slot is
Phase 5; this lane does not promote Tweedie into Phase 4.

## Outcome

- LOOP kit
  `docs/dev-log/lanes/cursor-mspl-phase4-tweedie/LOOP/`
- Research note
  `docs/dev-log/research/2026-08-15-mspl-phase4-tweedie-prep.md`
  (\(W=\mu^{2-p}/\varphi\); \(\Pr(Y=0)=\exp(-\mu^{2-p}/(\varphi(2-p)))\);
  kill list for Poisson \(W=\mu\), Bernoulli \(V_{\mathrm{loading}}\),
  Gaussian Hirose).
- Oracles
  `tests/testthat/test-mspl-tweedie-phase4-oracles.R`
  (E1–E8 + fence; no live Tweedie MSPL fit).
- Registry and prepare **untouched**. Tweedie is not `admitted`.
  `family_id` fence still `{0,1}`.

## Checks

```sh
OMP_NUM_THREADS=1 NOT_CRAN=true
pkgload::load_all(".", compile = FALSE)
testthat::test_file("tests/testthat/test-mspl-tweedie-phase4-oracles.R")
# PASS 51  (E1 4, E2 3, E3 5, E4 6, E5 5, E6 8, E7 7, E8 6, fence 5, no-live 2)
testthat::test_file("tests/testthat/test-mspl-registry.R")  # PASS 26
git diff --stat -- src/ R/mspl.R R/mspl-registry.R         # empty
```

## Non-claims / OPEN GATE

- No C++ tape; no `estimator="mspl"` on Tweedie; no NEWS covered;
  no registry row; no prepare widen.
- **OPEN GATE:** Shinichi + smoke before any Tweedie `planned`
  registry row or `admitted` flip; \((\varphi,p)\) and loading
  atoms under Laplace still OPEN in the note.

## Mathematical contract

No public API / likelihood / grammar / family change. Paper atom
only: \(I(\beta_*)=X_*^\top\operatorname{diag}(\mu^{2-p}/\varphi)X_*\).

## Roadmap tick

N/A — planned prep; no ROADMAP row.

## GitHub issue ledger

No relevant open issue; no new issue created. This is estimator-
programme prep, not a user-facing bug.

## Team learning

- **Noether:** Tweedie \(W=\mu^{0.5}\) at \(p=1.5\) made a copied
  Poisson \(P^*_{\mathrm{J}}<-10\) gate fail; the slower decay is
  the contrast, not a bug.
- **Curie:** \(p\to 1^+\) is an \(O(\varepsilon)\) approach to
  \(e^{-\mu/\varphi}\); a \(10^{-3}\) absolute/relative mix was
  too tight at \(p=1.01\).
- **Rose:** planned-on-paper \(\neq\) registry `planned`. This
  lane left `nrow(planned)==2` (Poisson only) intact.
