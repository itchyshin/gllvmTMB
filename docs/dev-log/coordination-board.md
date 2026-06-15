# Agent Coordination Board

**Purpose.** Live status doc for `gllvmTMB` coordination. This file answers:
what is active now, who owns it, what evidence is banked, and which claims remain
blocked. Replace stale rows rather than appending new eras below old ones.

Related ledgers:

- `docs/dev-log/check-log.md` - append-only command and decision evidence.
- `docs/dev-log/after-task/*.md` - per-slice closure reports.
- `docs/dev-log/shannon-audits/` - point-in-time audit snapshots.
- GitHub issues and PR descriptions - public claim boundaries.

## Current Operating Rule (2026-06-15)

The finish sequence is **R-first**:

1. `gllvmTMB` native R/TMB functionality is the user-facing oracle.
2. The R object API, post-fit methods, CI or CI-status vocabulary, docs, and
   visuals must be stable before a capability is promoted.
3. `engine = "julia"` follows as a mirror, parity target, and acceleration path
   for rows the R ledger admits.
4. REML is Gaussian-only. HSquared-style AI-REML is future design input for exact
   Gaussian variance-component cells only, not non-Gaussian Laplace wording.

## Repo State

| Repo | Branch / head | State | Evidence |
| --- | --- | --- | --- |
| `gllvmTMB` | `engine-julia` at `17b2154` | clean, local branch ahead of origin | Julia bridge tests: no-Julia `175 pass / 17 skip`; live bridge `439/439` against `GLLVM.jl-integration`. |
| `GLLVM.jl-integration` | `codex/high-rate-poisson-safeguard` at `6056071` | clean paired runtime checkout | Provides the current `GLLVM.bridge_capabilities()` surface consumed by bridge drift guards. |
| `GLLVM.jl` board checkout | `codex/non-gaussian-fitter-gradients` at `f1894bc` | clean dashboard/docs worktree | Mission-control source for `http://127.0.0.1:8770/`; not the paired runtime for bridge tests. |

## Active Lanes

| Owner | Lane | Write scope | Status |
| --- | --- | --- | --- |
| Ada / Shannon | R-first governance sync | coordination board, dashboard JSON, capability matrices, handoff notes | Active. Fixing stale evidence rows before the next source slice. |
| Hopper / Fisher | Native mixed-family R oracle | `R/fit-multi.R`, `R/methods-gllvmTMB.R`, focused mixed-family tests | Queued next. Harden no-X/no-mask Gaussian + Binomial + Poisson reduced-rank fits as the R/TMB target before Julia bridge admission. |
| Rose | Claim audit | README, NEWS, docs, issue rows, after-task reports | Active. Blocks promotion when "done" wording lacks point-estimate/logLik/CI-status/test evidence. |
| Hopper / Gauss | Julia mixed-family bridge follow-on | `GLLVM.jl-integration/src/bridge.jl`, `gllvmTMB/R/julia-bridge.R`, live parity tests | Planned after the native R oracle. Do not admit family lists through `engine = "julia"` until per-trait family labels, CI-status, prediction, and simulation boundaries are tested. |

## Current Evidence Bank

| Claim | Status | Evidence |
| --- | --- | --- |
| `engine = "julia"` is partial, not complete | covered | README and NEWS describe paired-checkout requirements and deliberate unsupported cells. |
| NB1 complete-data no-X bridge route | partial | Formula-vs-direct Julia logLik equality, Wald `phi` smoke, post-fit `predict()`, `fitted()`, `residuals()`, `augment()`, and conditional `simulate()` tests. |
| Fixed-effect-X bridge rows | partial | Public formula-vs-direct evidence for Gaussian, Poisson, Binomial, NB2, Beta, and Gamma; NB1 X and ordinal X remain rejected. |
| Conditional bridge simulation | partial | Gaussian, Poisson, Binomial, NB2, NB1, Beta, and Gamma in-sample simulation routed for complete-data bridge payloads. Masked simulations remain rejected. |
| REML | partial | Gaussian-only pilot. Non-Gaussian and mixed-family REML remain rejected/deferred. |
| AI-REML | planned | Exact-Gaussian acceleration idea only; no non-Gaussian Laplace claim. |

## Next Safe Slice

Native mixed-family R oracle:

1. Fit a three-trait no-X/no-mask mixed-family model:
   Gaussian + Binomial + Poisson with `latent(0 + trait | unit, d = 1)`.
2. Assert `family_id_vec`, `link_id_vec`, `trait_id`, selector levels, and
   `family_input` are row-aligned and preserve `family_var`.
3. Assert finite logLik and clean convergence, without requiring `pdHess`.
4. Assert `summary()` exposes per-trait link labels.
5. Assert `predict(type = "response")` respects family ranges.
6. Assert `simulate()` produces family-valid draws.
7. Keep excluded cells explicit: missing-response include, fixed-effect X,
   delta/hurdle mixed-family claims, CIs, and Julia bridge family-list admission.

## Blockers / Deliberate Holds

- No push from this branch without maintainer approval.
- No CRAN, registry, or tag work until the issue ledger, docs, dashboard, and
  Rose audit agree.
- No `engine = "julia"` mixed-family admission until the native R oracle and
  Julia payload label bug are handled.
- No speed claim without point-estimate, objective/logLik, CI or CI-status, and
  benchmark metadata.

## Historical Note

May 2026 Phase 56 structural-slope coordination now lives in the corresponding
after-task and recovery-checkpoint files. It is no longer active board state.
