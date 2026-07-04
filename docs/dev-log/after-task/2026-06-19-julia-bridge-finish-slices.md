# After-task — R↔Julia bridge finish slices (S1–S3 + J2)

Date: 2026-06-19 (Claude / Ada, autonomous overnight; ultracode). Maintainer
directive: "make the R and Julia bridge done; do the Julia stuff too."

Grounded by `docs/dev-log/2026-06-19-bridge-finish-map.md` (a 4-investigator
read-only sweep). All work is on local branches, **un-pushed**, verified. The
GLLVM.jl-integration tree (PR #101, f7be594) was never mutated.

## Verified toolchain
Julia 1.10.0 at `~/.juliaup/bin/julia`. Live Julia-via-R bridge runs against the
integration engine via `GLLVM_JL_PATH`; baseline LIVE suite = **FAIL 0 / PASS
1188**. Local GLLVM.jl `runtests.jl` baseline = green (exit 0).

## Slices

### S1 — `cbind(successes, failures)` binomial routing  [R bridge]
Branch `claude/bridge-finish-20260619` @ `d2b3e2f`. Marshals a 2-column response
to successes→`Y` and `rowSums`→`N` (the engine already accepts `N`), flips the
`cbind_binomial` capability, and drops the `GJL-GATE-CBIND-BINOMIAL` gate +
expected-drift rows (19→18 gates).
- **Verify:** pure-R 357→358; **LIVE 1188→1195 (FAIL 0)**; drift frame 0
  unregistered rows; `cbind(...)` fit == direct `gllvm_julia_fit(N=)` with
  logLik / loadings / alpha delta **exactly 0**.
- **⚠ Response-grammar change → maintainer sign-off before merge.** Built and
  live-verified on the branch; NOT merged.

### S2 — `extract_correlations()` point-only contract for `gllvmTMB_julia`  [R bridge]
Branch `claude/bridge-finish-20260619` @ `cec51a9`. Replaces the
`GJL-GATE-CORRELATION-INTERVALS` abort with point-only rows
(`lower=NA, upper=NA, interval_status="none", validation_row="JUL-01A"`),
reading the unit-tier correlation via the existing
`extract_Sigma(level="unit")$R` path. Schema is a strict superset of the
normal-fit frame (base columns identical). Roxygen `@return` updated;
`man/extract_correlations.Rd` regenerated. `GJL-GATE-CORRELATION-INTERVALS`
stays live because `plot_correlations()` still genuinely needs interval rows.
- **Verify:** +11 pure-R tests; pkgdown clean. Lower-risk extractor-behavior
  change (agent-merge-eligible per CLAUDE.md), but surfaced for review.

### S3 — harden two correct refusal gates  [R bridge, test-only]
Branch `claude/bridge-finish-20260619` @ `6217540`. Adds full bracketed
`[GJL-GATE-*]`-id assertions for every documented trigger of
`GJL-GATE-PROB-CLASS-NONORDINAL` (predict/fitted × prob/class) and
`GJL-GATE-NO-CI-PAYLOAD` (confint default + stored). No behavior change.
- **Verify:** +6 pure-R tests.

**Bridge-finish branch combined (independently re-verified):** pure-R 358→375
(+17); **LIVE FAIL 0 / SKIP 0 / PASS 1212**; tree clean.

### J2 — honest local `bridge_capabilities()`  [GLLVM.jl engine]
Branch `claude/jl-bridge-capabilities-20260619` @ `34e8d93` (off
`codex/non-gaussian-fitter-gradients`; NOT #101). Adds and exports a
`bridge_capabilities()` to the local engine that reports the **narrow local
truth** (7 families; X / mask / mixed all false; cbind binomial-only; Wald CI
all incl. ordinal; profile never; bootstrap gaussian-only; simulate false), with
a behavioural cross-check test (binomial+`N` succeeds; X and mixed throw; ordinal
Wald `status="ok"`; poisson bootstrap `unsupported`).
- **Two honesty divergences from the integration table, fixed to match local
  reality:** ordinal Wald = true locally (native `confint(::OrdinalFit)`);
  `simulate` = false everywhere (the local `simulate.jl` is a placeholder).
- **Verify:** new test 60/60; `julia --project=. test/runtests.jl` exit 0;
  independent smoke confirmed the honest values.

## Definition-of-Done status (honest)
Real bridge progress, but NOT "bridge done": one user-facing capability closed
end-to-end (S1, sign-off-pending), one extractor refusal converted to a defined
point-only contract (S2), two refusal-gates hardened (S3), and the local engine
made capability-introspectable (J2). The remaining bridge gates are engine- or
decision-gated per the finish-map and cannot be honestly marked done without the
no-touch #101 tree or maintainer status sign-off.

## Follow-up (maintainer)
- 🔴 **Sign off S1** (cbind response-grammar change) before merge.
- The dedicated validation-register / NEWS slice should update
  `docs/design/35-validation-debt-register.md` lines ~523-524 (still reference
  the removed `GJL-GATE-CBIND-BINOMIAL` / binomial-cbind intentional drift) and
  record the 19→18 gate count.
- J2 changes a public-ish engine surface (`bridge_capabilities` export) on the
  non-#101 branch — fold into branch reconciliation.
- Everything else (new families through the bridge, structured-term routing,
  VA/EVA, broad parity promotion) remains engine/decision-gated — see the
  finish-map.
