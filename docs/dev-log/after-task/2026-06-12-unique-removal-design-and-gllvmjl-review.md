# After-task: unique-family removal (design/audit/review) + GLLVM.jl review

**Date:** 2026-06-12 · **Author:** Claude (gllvmTMB thread) · **Type:**
read-only design/audit/review + one shipped docs change. **No gllvmTMB R code,
grammar, `src/`, `NAMESPACE`, or `man/` changed.**

## Scope

Three threads this session:

1. **Dev-status pkgdown badges** — shipped (a README badge block).
2. **Remove the whole `unique` keyword family** — maintainer decision; the
   Gaussian residual Ψ folds into `latent` by default. Full design, audit,
   migration spec, and code-review produced and **handed off to the implementing
   team** (the parallel Claude thread run from GLLVM.jl).
3. **Full read-only review of the sister repo GLLVM.jl** (docs text + figures,
   source + docstrings, tests + API, plus a correctness code-review) — **handed
   off** to that thread as two reports + a cover message.

## Outcome

- **Badges live** on the pkgdown site (`Dev status` box: R-CMD-check / pkgdown /
  lifecycle-experimental).
- **unique-removal trail on `main`:** #474 (badges), #475 audit + #476 correction
  (the "merge into `indep`" framing was caught as wrong — the engine forbids
  `latent + indep`), #477 design proposal + #478 refinement, #479 Slice 1 brief +
  implementer-ref fix, #480 migration spec, #481 removal code-review (3 deep
  passes). Scope settled: **whole family + `kernel_unique` IN**.
- **Key design facts established:** removal is **R-side only** (the C++ handles Ψ
  generically via `use_diag_*` flags); `part = "unique"` must be **rewired** (not a
  free survivor); the auto-emitted Ψ must be **exempted** from the `indep/unique +
  latent` over-param guard; the surviving `indep` family shares the `diag`/
  `phylo_rr`/`spde` slots and `.indep`/`.phylo_unique` markers.
- **GLLVM.jl review delivered:** the engine **math verified clean** (numerically —
  ForwardDiff / brute-force MvNormal / re-run gradient gates); 3 doc-example FAILs;
  the machine-precision parity claim outruns its (Gaussian-only, opt-in) tests.
  Two handoff reports sit in `GLLVM.jl/docs/dev-log/` (untracked).

## Checks

- Badges: `pkgdown::check_pkgdown()` clean; homepage box verified in rendered
  `index.html`; deploy workflow green.
- `unique` ≠ `indep` in the decomposition: **empirically verified** —
  `latent(1|id,d=1) + unique(1|id)` fits (logLik −258.67); `+ indep(...)` aborts.
- GLLVM.jl engine correctness: verified numerically by the review pass.
- `git diff --check` clean on every merged doc.

## Definition of Done (which items apply)

This was design/audit/review, not feature implementation, so the 6-item DoD is
**deferred to the implementation** (the other team): implementation, simulation
recovery test, runnable example, and the likelihood/scope review pass all land
**with the removal code**, not here. What this session owns: **documentation**
(the design/audit/spec/review trail) and the **check-log entry** — both done.

## Follow-up / open

- **Four maintainer decisions** before/during the removal: (1) free-correlation
  reaction norms — `*_unique(1+x|g)` is the only free-correlation slope path
  (`*_indep` pins ρ=0); re-home into `latent(1+x|g)` or drop; (2) the `common=`
  knob; (3) keep `part="unique"` (repointed) vs rename to `"psi"`; (4) bare-`latent`
  transition (clean-break leaning).
- **The other team** implements the removal (R-side only per the code-review).
- **PR #473 (the Julia bridge) is still open with no `testthat` tests** —
  independent loose end, predates this session.
- The migration spec's scope was corrected to whole-family (banner, this PR).

## Artifacts

Design/audit/spec/review docs under `docs/dev-log/`: `…-unique-deprecation-audit.md`,
`…-latent-psi-fold-design.md`, `…-slice1-latent-psi-fold-brief.md`,
`…-unique-migration-spec.md`, `…-unique-removal-codereview.md`. GLLVM.jl handoffs:
`GLLVM.jl/docs/dev-log/2026-06-12-gllvmTMB-thread-{audit,code-review}.md` and the
refreshed inbox note.
