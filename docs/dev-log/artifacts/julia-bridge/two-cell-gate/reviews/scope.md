# Independent scope review — terminal two-cell Julia-engine gate

**Final scope verdict after proof repair: PASS, with two non-blocking
provenance/integrity warnings.**

Reviewer: Noether (Codex scope and mathematical-consistency reviewer)
Date: 2026-08-28
Review mode: read-only inspection of the worktree and retained artefacts; no fit was run.

## Proof-repair re-review

The added process receipts preserve the terminal boundary. For Julia 1.12.6
and 1.10.10, the recorded direct command only loads GLLVM and prints
`bridge_capabilities()`; it exits 0. The recorded bridge command calls only
`qualify-two-cell-source.R`; it exits 139. Both receipts explicitly record
`fit_started=false` (`process/julia-1_12_6.receipt` and
`process/julia-1_10_10.receipt`, lines 8–16). Neither command calls
`run-two-cell-gate.R` or a fitting function.

The source contract now binds each receipt and each runtime Manifest by
SHA-256. Recomputed hashes match all four bound values:

- Julia 1.12.6 receipt:
  `9e3b6dea458e7fcc3695e1065a7a7299c2ba6d3868007e5303e0573c38deb194`;
- Julia 1.10.10 receipt:
  `696cd060c66d1fb7ac0b00832186afd3b3d73ec34a75081e6ff24e7cf46bdaf7`;
- Julia 1.12.6 Manifest:
  `c019e07f5f83f6c85492b0da8760ef3870c68c3ddebef2984ac3041776d47bd9`;
- Julia 1.10.10 Manifest:
  `225213ebd8b329f1d39890c954a561f7350469d90fd86d6c3bbde44b948fd1fe`.

The retained attempt ledger remains unchanged: exactly four planned IDs,
zero `started = TRUE`, four `status = unavailable`, and no fifth or
replacement record. The proof repair therefore did not consume a fit attempt
or alter the 0/4 denominator.

## Scope findings

1. **PASS — the retained denominator is exactly four.**
   `records.csv` contains exactly the frozen IDs `gaussian-tmb`,
   `gaussian-julia`, `poisson-tmb`, and `poisson-julia`, each once. All four
   records have `planned = TRUE`, `started = FALSE`, `status = unavailable`,
   and terminal code `NO_RUN_SOURCE_CONTRACT` (`records.csv`, lines 2–5).
   The four matching RDS files are the only files under `attempts/`.

2. **PASS — zero of four fits started.**
   The CSV reports four `started = FALSE` values; each retained attempt RDS
   has the same record and `result = NULL`. `runtime-failures.txt`, line 5,
   independently records `FIT_ATTEMPTS_STARTED=0`; `source-contract.txt`,
   lines 1–2, and `verdict.txt`, line 1, both record `fit_started = FALSE`.
   There is no `started/` directory in the retained packet.

3. **PASS — there were no replacement attempts or retuning.**
   The retained attempt names exactly equal the four planned names. The
   verdict records `thresholds_frozen = TRUE` and
   `replacement_attempts = 0L` (`verdict.txt`, lines 1–2). No fifth attempt,
   retry, or replacement record exists.

4. **PASS — the terminal stop occurred at source qualification, before the
   production fit loop.**
   The receipt identifies `NO_RUN_SOURCE_CONTRACT`: direct GLLVM.jl loading
   admitted both frozen families, while the JuliaCall embedding exited 139
   under Julia 1.12.6 and 1.10.10 (`runtime-failures.txt`, lines 1–5). This is
   a retained bridge-environment failure, not a Gaussian, Poisson, recovery,
   or cross-engine estimand result.

5. **PASS — no forbidden scientific or product scope was added.**
   The gate uses only complete long-format Gaussian and Poisson fixtures with
   a rank-1 loadings-only term,
   `latent(0 + trait | unit, d = 1, unique = FALSE)`
   (`dev/julia-bridge-gate/two-cell-gate-lib.R`, lines 33–71). Inspection of
   the changed and untracked gate-owned paths found no implementation of
   intervals, `X`, `X_lv`, masks, missing-data handling, offsets, mixed
   families, structured sources, Psi, recovery, or performance work. It also
   found no exported API, package `R/`, `src/`, `NAMESPACE`, CI, README,
   vignette, NEWS, or other public-promotion change. Mentions such as
   `IntervalSets` and `Missings` inside the generated Julia Manifest are
   dependency metadata only, not work performed by this gate.

6. **PASS — no GLLVM.jl package-source mutation is attributable to this
   gate.**
   The source receipt pins GLLVM.jl commit
   `00a2d7b7024b21f55cb124bee2d2e4cf8a546b40`, tree
   `8a243605516a0d660d703135acb0b1bd9a0e4f15`, archive SHA-256
   `515ae818a0c66b2dddda4306ade9643310e7531c504183e352ac598b8d1bd4b7`,
   and Project SHA-256
   `bd85aa8977102a28872fa34b019dce1ad96e50171ad52907f2f34f37d06f0128`
   (`source-contract.txt`, lines 5–11). The gate consumed that immutable
   archive on Totoro; no GLLVM.jl edit, branch, lease, commit, or push appears
   among this worktree's changes.

   **WARN (non-blocking provenance caveat):** the separate local GLLVM.jl
   checkout was already dirty when reviewed, but only in `.claude/`,
   `.codex/`, `.cursor/`, and `.worktrees/` operational surfaces; its tracked
   package source is clean. Without a before/after status receipt, this review
   cannot prove the history of those foreign-lane metadata changes. They are
   not used by the gate, whose source identity is the retained archive pin and
   hashes above.

7. **PASS for scope — repaired process evidence is internally bound.**
   The two receipt hashes and two runtime-Manifest hashes recompute to the
   values recorded in `source-contract.rds` and `source-contract.txt`.

   **WARN (non-blocking for this scope verdict, blocking for a global manifest
   claim):** the top-level `SHA256SUMS` was not regenerated after the proof
   repair. Its old entries for `source-contract.rds` and
   `source-contract.txt` now fail, and it does not list the added process
   receipts or version-specific Manifests. A final packet-integrity gate must
   regenerate and recheck that manifest after reviews are frozen. This does
   not change the qualification-only command evidence or the exact 0/4
   denominator.

## Claim boundary

This review supports only the terminal statement: **0/4 planned fits started;
all four are retained as unavailable because the required JuliaCall embedding
failed source qualification.** It does not support engine parity, likelihood
agreement, parameter recovery, interval validity, performance, API readiness,
CI readiness, or public promotion.

No P0, P1, P2, or P3 mathematical or scope inconsistency was found in this
terminal packet. The provenance and stale-manifest warnings above do not alter
the terminal denominator or the final scope PASS verdict.
