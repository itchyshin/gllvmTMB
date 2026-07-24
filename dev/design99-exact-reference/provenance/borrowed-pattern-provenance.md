# Design 99 borrowed-pattern provenance

This table records ideas that may inform a new implementation. It does not
authorize source import. Design 99 must not source or execute Design 98, and
GLLVM.jl/drmTMB contribute conceptual patterns only. Any implemented equation
or algorithm needs its own independent derivation, tests, and source note.

| Source | Pinned evidence | Pattern that may be learned | Explicit non-reuse boundary |
|---|---|---|---|
| Design 98 | `dev/design98-factorial-va-jj/R/oracle.R` at `7ca5da1c` | Standard-normal GH normalization, stable softplus/log-sum-exp, q=2 tensor enumeration, fixed-coordinate 31/41/61 comparison | Do not source the file, copy its functions verbatim, execute its C++ DLL, or reuse its fixtures, starts, thresholds, UUID, outputs, or scientific labels. |
| Design 98 | `dev/design98-factorial-va-jj/R/supervisor.R`, `R/records.R`, `R/task-plan.R` at `7ca5da1c` | One worker per phase, exclusive-create inputs/terminals, retained sibling failures, dependency-aware adjudication | Do not resume the Design-98 DAG or write inside its result root. Design 99 requires new task IDs, schemas, failure injections, UUID, and root. |
| Design 98 | `dev/design98-factorial-va-jj/R/provenance.R` and its immutable packet at `7ca5da1c` | Pre/post predecessor inventories and content-addressed telemetry | Use this Gate-0 inventory implementation instead; do not call Design-98 provenance functions. |
| GLLVM.jl | `/Users/z3437171/Dropbox/Github Local/GLLVM.jl/src/families/binomial.jl`, file commit `f442b78b7d7dfbf0f21447a8b77458d2ac4ec075` | Empirical link-scale intercept start, SVD-based loading start, cached latent modes, explicit gradient plus L-BFGS/backtracking | Julia code is not copied. The GLLVM.jl engine is Laplace, not an exact q=2 tensor-GH reference. Its objective and mode cache do not establish Design-99 correctness. |
| GLLVM.jl | `src/packing.jl`, file commit `501a54e7152978f5467933191a74e018991c9507`; `src/ppca_init.jl`, file commit `40736a29ce9f0681b2be14a7475f0f274446cae2` | Stable lower-triangular orientation, deterministic sign anchoring, and SVD/PPCA initialization discipline | Raw-diagonal Julia packing and Gaussian PPCA are not the Design-99 parameterization or estimator. Borrow orientation/start ideas only after restating the exact R coordinates. |
| GLLVM.jl | `src/fit.jl`, file commit `ffcdc5f9f044b4a43e6cdfa8fe33059e07f73b3f` | Explicit optimizer tolerances, residual-scale reparameterization, and separation of initialization from the target objective | Gaussian profiling/rescaling is not portable to the Bernoulli q=2 marginal target without a new derivation. |
| drmTMB | `/Users/z3437171/Dropbox/Github Local/drmTMB/R/drmTMB.R`, inspected at repository HEAD `85e78223aa69bf2539744671b4f43eeb96ab1a92` (HEAD blob `2f966db3bfbae5e42f8bab3005d93496e2a1901a`) | Retain every optimizer attempt, isolate multi-start RNG from the caller, and distinguish optimizer budgets, presets, retries, and fallback methods | drmTMB's working tree was dirty during inspection, so only the pinned HEAD blob is evidence. Design 99 has no adaptive retry or fallback unless prospectively frozen. |
| drmTMB | `docs/dev-log/ayumi-convergence/slices-363-372/2026-05-19-full-species-start-values.md`, file commit `31ab9d9fe9a4a9caf95d93a49b5e7cc0d240741c` | Increasing iterations, warm starts, and multi-start diagnostics answer different questions and must be recorded separately | This is process guidance, not a numerical implementation or evidence that any Design-99 fit will be healthy. |

## Source-state cautions

GLLVM.jl was inspected at `6694f43d29cb002dcb87c41adcb2de0b15187209`
with unrelated dirty preview files. drmTMB was inspected at
`85e78223aa69bf2539744671b4f43eeb96ab1a92` with a substantially dirty working
tree. Therefore all cross-repository evidence is pinned to committed file
history or HEAD blobs and remains conceptual. No uncommitted sibling content
may become load-bearing Design-99 evidence.
