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
| `gllvmTMB` | `engine-julia`, current local branch | active local branch ahead of origin | Julia bridge evidence is refreshed per slice; no push without maintainer approval. |
| `GLLVM.jl-integration` | `codex/high-rate-poisson-safeguard`, paired local checkout | active paired runtime checkout | Provides the `GLLVM.bridge_capabilities()` surface consumed by bridge drift guards and live bridge tests. |
| `GLLVM.jl` board checkout | `codex/non-gaussian-fitter-gradients`, dashboard/docs worktree | active dashboard source | Mission-control source for `http://127.0.0.1:8770/`; not the paired runtime for bridge tests. |

## Active Lanes

| Owner | Lane | Write scope | Status |
| --- | --- | --- | --- |
| Ada / Shannon | R-first governance sync | coordination board, dashboard JSON, capability matrices, handoff notes | Active. Keeping the R ledger, Julia parity docs, and dashboard synchronized before promotion claims. |
| Hopper / Fisher | Native mixed-family R oracle | `R/fit-multi.R`, `R/methods-gllvmTMB.R`, focused mixed-family tests | Banked for the first no-X/no-mask selector slice; next work is CI/status and excluded-cell hardening, not blanket promotion. |
| Rose | Claim audit | README, NEWS, docs, issue rows, after-task reports | Active. Blocks promotion when "done" wording lacks point-estimate/logLik/CI-status/test evidence. |
| Hopper / Gauss | Julia bridge follow-on | `GLLVM.jl-integration/src/bridge.jl`, `gllvmTMB/R/julia-bridge.R`, live parity tests | Partial. Complete balanced mixed-family point fits and selected missing-response masks are admitted only where live tests cover them. |

## Current Evidence Bank

| Claim | Status | Evidence |
| --- | --- | --- |
| `engine = "julia"` is partial, not complete | covered | README and NEWS describe paired-checkout requirements and deliberate unsupported cells. |
| NB1 complete-data no-X bridge route | partial | Formula-vs-direct Julia logLik equality, Wald `phi` smoke, post-fit `predict()`, `fitted()`, `residuals()`, `augment()`, and conditional `simulate()` tests. |
| Fixed-effect-X bridge rows | partial | Public formula-vs-direct evidence for Gaussian, Poisson, Binomial, NB2, Beta, and Gamma; NB1 X and ordinal X remain rejected. |
| Non-Gaussian-X bridge CI-status | covered | Supported non-Gaussian fixed-effect-X point-fit rows now cache `ci_unavailable_non_gaussian_x`; direct `ci_method` and `confint()` requests report method-specific unavailable statuses for Wald/profile/bootstrap. |
| Missing-response bridge rows | partial | Poisson, Bernoulli Binomial, NB2, NB1, Beta, Gamma, and ordinal-probit no-X point fits are routed with observed-cell masks. Masked CIs and masked simulations remain rejected. |
| Mixed-family Julia bridge point fits | partial | Complete balanced trait-aligned no-X/no-mask/no-CI point fits are admitted for Gaussian, Poisson, Binomial, NB2, Beta, and Gamma components with family/link labels and explicit unavailable-CI status. |
| Conditional bridge simulation | partial | Gaussian, Poisson, Binomial, NB2, NB1, Beta, and Gamma in-sample simulation routed for complete-data bridge payloads. Mixed-family and masked simulations remain rejected. |
| REML | partial | Gaussian no-X `engine = "julia"` fits now route through the paired `GLLVM.jl` REML bridge with public formula-vs-direct logLik equality. Non-Gaussian, mixed-family, fixed-effect-X, and masked-response REML cells fail loudly; REML CIs report `*_unavailable_reml`. |
| AI-REML | planned | Exact-Gaussian acceleration idea only; no non-Gaussian Laplace claim. |

## Next Safe Slice

R-first capability ledger cleanup:

1. Reconcile README, NEWS, ROADMAP, issues, and bridge capabilities against the
   current R user surface.
2. Split rows into `covered`, `partial`, `experimental`, `planned`, and
   `unsupported`; do not use blanket "complete" language.
3. Give every promoted R row point-estimate/logLik evidence plus CI or explicit
   CI-status evidence before asking Julia to chase it.
4. Keep the next positive admission small: one family, method row, or
   unsupported-status row at a time.

## Blockers / Deliberate Holds

- No push from this branch without maintainer approval.
- No CRAN, registry, or tag work until the issue ledger, docs, dashboard, and
  Rose audit agree.
- No broader `engine = "julia"` mixed-family admission beyond the tested
  complete balanced no-X/no-mask/no-CI point-fit row.
- No speed claim without point-estimate, objective/logLik, CI or CI-status, and
  benchmark metadata.

## Historical Note

May 2026 Phase 56 structural-slope coordination now lives in the corresponding
after-task and recovery-checkpoint files. It is no longer active board state.
