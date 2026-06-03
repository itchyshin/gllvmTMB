# After Task: Variational approximation (VA) feasibility audit

**Branch**: `claude/va-feasibility-audit`
**Date**: `2026-06-03`
**Roles (engaged)**: Claude (gather-evidence / draft-decision), Rose
(overpromise prevention), Gauss (TMB engine boundary), Noether (phylo math)

## 1. Goal

Produce a READ-ONLY feasibility audit / design memo on adding variational
approximation (VA) as an alternative estimation method to gllvmTMB's current
TMB Laplace approximation, with the maintainer's explicit competitive frame
(beat `gllvm`, not just match it) and the concrete motivation that VA might
converge where our Laplace inner Hessian goes non-PD on hard non-Gaussian
augmented-slope cells. No engine code to be touched; output is a design doc +
draft PR only.

## 2. Implemented

- New design doc `docs/design/72-variational-approximation-feasibility.md`
  (next free design number; 71 was the prior highest). Covers: what gllvm
  does (VA/LA/EVA, closed-form family coverage, NNGP structured REs); the VA
  ELBO mechanism on TMB (variational params are ordinary params, no inner
  Laplace Hessian -- the structural reason VA can be more stable); the
  smallest VA insertion point into `R/fit-multi.R` + `src/gllvmTMB.cpp`; the
  structured-prior KL derivations for phylo `A^{-1}`, SPDE `Q`, and meta `V`
  (the "better than gllvm" frontier, with the Kronecker variational-covariance
  route as the scalable option); where EVA is required; the statistical
  caveats (downward variance bias, ELBO != marginal likelihood so AIC/LRT not
  cross-method comparable, optimistic SEs); a per-row mapping of the
  hypothesis onto our ACTUAL skips (PHY-17/18, SPA-08/09/10); a 4-phase plan
  with explicit go/no-go gates; a Recommendation; and Open questions.
- New after-task report (this file).

## 3. Files Changed

Docs only (no engine/likelihood/test code touched):
- `docs/design/72-variational-approximation-feasibility.md` (new)
- `docs/dev-log/after-task/2026-06-03-va-feasibility-audit.md` (new)

## 3a. Decisions and Rejected Alternatives

- **Decision:** headline recommendation is "conditional GO on Phase 1 only"
  (a falsifiable proof-of-mechanism), NOT a commit to full VA. **Rationale:**
  the convergence benefit is a mechanism-grounded hypothesis but VA's
  downward variance bias could make a "converged" VA fit worse than an honest
  LA skip; only a side-by-side VA-vs-LA-vs-truth benchmark on existing
  fixtures settles it. **Rejected:** recommending full VA adoption now (over-
  commits to high-risk TMB work before the mechanism is proven); recommending
  against VA (ignores that the non-PD inner Hessian is exactly what VA
  removes). **Confidence:** medium-high on the mechanism, medium on the
  structured-VA scalability (the named biggest risk).
- **Decision:** name the structured-covariance KL (sec 3.2) as the single
  biggest technical risk. **Rationale:** if the variational covariance can't
  stay sparse/Kronecker against our exact priors while staying accurate for
  non-Gaussian families, the whole differentiator collapses.

## 4. Checks Run

- `git log origin/main --oneline -3` -> branch cut tracks main HEAD `aa7315a`.
- `ls docs/design/` -> highest existing number 71; used 72.
- Read: Design 35 register (PHY-17/18, SPA-08/09/10 rows), Design 04 scope,
  Design 64 spatial derivation, `test-matrix-slope-phylo-dep.R`,
  `test-spatial-indep-slope-nongaussian.R` (the task's named
  `test-spatial-dep-slope-nongaussian.R` does not exist; the actual dep
  matrix file is `test-matrix-slope-spatial-dep.R` -- noted in the memo).
- Skimmed `src/gllvmTMB.cpp` (family `if (fid==k)` ladder 1621-1810+; GMRF /
  Ainv prior blocks) and `R/fit-multi.R` (the `random <- c(...)` block
  3062-3097 and the `MakeADFun(..., random=random)` call).
- WebSearch: 6 queries (Hui 2017, Niku 2019 MEE+PLOS, Korhonen 2023 EVA,
  gllvm 2.0 structured REs, VA closed-form bounds, VA bias) -- all returned.
- WebFetch: attempted JMLR PDF, arxiv, Springer, PMC, jenniniku.github.io,
  rdrr.io -- ALL returned HTTP 403. GitHub MCP scoped to itchyshin/gllvmtmb
  only, so gllvm source not directly readable. Provenance honesty section
  (memo sec 8) flags every gllvm internal as TO-VERIFY.
- No tests run (no code changed; docs-only PR).

## 5. Tests of the Tests

N/A -- no tests added or modified (read-only audit).

## 6. Consistency Audit

- Design number: `ls docs/design/ | grep -E '^7[0-9]'` -> 70, 71 highest;
  72 is free.
- Greek-letter / ASCII convention: memo uses ASCII-with-`(x)`-Kronecker
  matching Design 64/65 house style.
- Register row IDs referenced (PHY-17, PHY-18, SPA-08, SPA-09, SPA-10) all
  verified present in Design 35 sec 4 / sec 5.

## 7. Roadmap Tick

N/A -- this memo PROPOSES a work-stream (Phase 0); no roadmap row changes
until the maintainer funds Phase 1.

## 7a. GitHub Issue Ledger

No existing open issue located for VA estimation; no new issue created (the
memo + draft PR are the discussion artifact, per the gather-evidence role --
the maintainer decides whether to open a tracking issue at the Phase-1 gate).

## 8. What Did Not Go Smoothly

- WebFetch was blocked (403) on every academic / documentation domain, and
  the GitHub MCP is scoped to itchyshin/gllvmtmb, so I could not read the
  gllvm TMB templates or paper full texts directly. Worked from WebSearch
  summaries + first-principles VA-GLLVM knowledge; flagged all gllvm
  internals as TO-VERIFY.
- The task spec named `test-spatial-dep-slope-nongaussian.R`, which does not
  exist; the actual spatial-dep matrix fixture is
  `test-matrix-slope-spatial-dep.R` (the dep cells live there + in
  `test-spatial-dep-slope-gaussian.R`). Used the real files.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

- **Rose (overpromise prevention):** the memo's recommendation refuses to
  advertise VA anywhere until a register row carries VA-vs-LA recovery
  evidence, and forbids band-widening to force VA green -- directly applying
  the Design 35 discipline to a prospective feature.
- **Gauss (TMB engine):** identified the smallest VA insertion point and
  flagged it HIGH-RISK (TMB/likelihood) requiring maintainer + Codex, not a
  Claude auto-merge; recommended a separate VA template for Phase 1 isolation.
- **Noether (phylo math):** derived the structured KL for the exact sparse
  `A^{-1}` prior and the Kronecker variational-covariance route as the
  scalable, "better than NNGP" differentiator -- and named its non-Gaussian
  approximation quality as the biggest open risk.

## 10. Known Limitations And Next Actions

- This is Phase 0 (memo) only. The load-bearing experiment is Phase 1: a
  narrow Gaussian + Poisson VA prototype benchmarked against the existing
  skip fixtures. Until that runs, "VA helps our convergence skips" stays a
  hypothesis.
- gllvm internals (variational-covariance parameterisation, structured-VA KL,
  SE correction) are TO-VERIFY against actual sources before any C++.
- Next action: maintainer decision at the Phase-0/1 gate (fund Phase 1 or
  keep LA-only). Open questions for that decision are in memo sec 9.
