# Plan versus actual — exact two-cell `engine = "julia"` gate

## Terminal outcome

`NO_RUN_SOURCE_CONTRACT`. Direct GLLVM.jl qualification passed for Gaussian and Poisson under Julia 1.12.6 and 1.10.10, but the JuliaCall embedding required by gllvmTMB exited 139 under both runtimes before any fit started. Exactly four planned records remain in the denominator: 0 started, 4 unavailable, 0 replacements.

## Ultra Plan reconciliation

| Plan item | Classification | Actual evidence |
|---|---|---|
| Freeze exact gllvmTMB and GLLVM.jl source pins | DONE | Commits, trees, archive SHA-256s, GLLVM.jl Project hash, installed DLL hash, R session, and both runtime Manifests retained. |
| Confirm Gaussian and Poisson, rank-1, loadings-only static eligibility | DONE | Immutable source audit and two direct-Julia capability logs admit both families. |
| Build deterministic fixtures and exact four-record ledger test-first | DONE | Pure-R harness freezes seeds, formula, thresholds, stop rule, denominator, and failure retention. |
| Qualify Totoro's one-thread R-to-Julia runtime | DONE, TERMINAL | Direct Julia exits 0; the JuliaCall bridge exits 139 twice. Raw commands, environments, logs, statuses, and hashes are retained. The terminal branch of the approved plan was executed. |
| Start Gaussian TMB fit | RETRACTED | Global paired-source prerequisite failed before fitting; record retained as unavailable. |
| Start Gaussian Julia fit | RETRACTED | JuliaCall embedding failed before fitting; record retained as unavailable. |
| Start Poisson TMB fit | RETRACTED | Global paired-source prerequisite failed before fitting; record retained as unavailable. |
| Start Poisson Julia fit | RETRACTED | JuliaCall embedding failed before fitting; record retained as unavailable. |
| Evaluate frozen parity thresholds | RETRACTED | No estimands exist; thresholds remain frozen and unused. No statistical verdict was issued. |
| Preserve every planned, failed, unavailable, or interrupted attempt | DONE | Four of four planned terminal attempt RDS files and `records.csv`; 0/4 started, 4/4 unavailable. |
| Stop and report at 30 minutes | DONE | Qualification terminated well below 30 minutes; no campaign or fit overran the boundary. |
| Independent method, scope, and provenance review | DONE | First method/provenance reviews failed missing raw proof; repair and terminal re-review are retained. |
| Checksum manifest and reproducible verifier | DONE | Standard `SHA256SUMS` covers the evidence bundle and passes a fresh independent read. |
| After-task, plan-actual, local evidence commit, exact-state verification, lease release | DONE at closeout | Protected closeout performed in that order; no remote landing action. |
| Diagnose or modify GLLVM.jl/JuliaCall/RCall | OWED | Fresh runtime lane needed; this gate localized but did not repair the embedding failure. |
| Re-run a future four-fit parity gate | OWED, NEW APPROVAL | Only after runtime repair, with fresh exact pins and a new immutable denominator; these records remain retained. |
| GLLVM.jl package-source edits | PROTECTED | None made; exact source archive remains immutable. |
| Intervals, X/X_lv, masks, missingness, offsets, mixed families, structured covariance, Psi, recovery, performance, API, CI, or public promotion | PROTECTED | Explicitly deferred; no implementation or claim. |
| Push, PR, merge, release, issue mutation, or public claim | PROTECTED | None performed. Local evidence commit only. |

## Interpretation boundary

This result does not show that GLLVM.jl's Gaussian or Poisson models are wrong, that native TMB is right, or that cross-engine parity passed or failed. It proves a narrower operational fact on one host: the exact GLLVM.jl source loads directly, while the embedded JuliaCall route required by `engine = "julia"` cannot reach fitting in the tested runtime pair.
