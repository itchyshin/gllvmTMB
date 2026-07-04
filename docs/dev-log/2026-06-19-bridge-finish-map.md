# R↔Julia bridge — honest finish map (2026-06-19, Claude/Ada)

Grounded by a 4-investigator read-only sweep of gllvmTMB (R bridge), GLLVM.jl
(`codex/non-gaussian-fitter-gradients` @ 1b42e35, the **editable** local engine),
and GLLVM.jl-integration (`codex/julia-per-trait-dispersion` @ f7be594 = **PR #101
branch, no-touch**, the engine the live R bridge tests run against).

## The structural truth that governs "bridge done"

- The R bridge exposes a **19-gate registry** (`R/julia-bridge.R:115-205`) of
  deliberate `engine = "julia"` refusals, plus a capability **drift guard** that
  compares `gllvm_julia_capabilities()` (R) against the engine's
  `bridge_capabilities()`.
- The **wide** engine surface (X, masks, grouped dispersion, mixed-family,
  fixed-X CIs, `bridge_capabilities` with `cbind_binomial = true`) exists **only
  in the no-touch integration tree @ f7be594**.
- The **local editable engine** has `bridge_fit` with `N` (binomial trials)
  acceptance but **hard-rejects X / mask / mixed** and has **no
  `bridge_capabilities()`** (verified by loading it: `has bridge_fit: true`,
  `has bridge_capabilities: false`).
- Live R bridge tests resolve Julia via `GLLVM_JL_PATH` → integration tree; the
  pure-R inner loop is **357 pass / 0 fail / 14 skip** (the 14 are the live rows).
- Julia 1.10.0 is available at `~/.juliaup/bin/julia` (juliaup; not on PATH).

**Therefore "make the bridge done" cannot mean "lift all 19 gates" in one night.**
Most gates need engine changes that live only in the no-touch tree, or undecided
semantics. Below is the honest classification.

## ⭐ Key insight: the Julia engine is largely BUILT, not missing

The integration engine `@ f7be594` (PR #101's tree) already implements a wide
surface — verified by reading its source and by 1212 passing live Julia-via-R
bridge tests:
- families: gaussian, poisson, binomial, NB1, NB2, beta, gamma, ordinal
  (`_BRIDGE_ONEPART_FAMILIES`);
- fixed-effect **X** for poisson/binomial/NB/beta/gamma (`_BRIDGE_X_FAMILIES`);
- response **masks** (`_BRIDGE_MASK_FAMILIES`);
- **mixed-family** vectors; **grouped dispersion**; post-fit **simulate**;
  **Wald/profile/bootstrap** CI fan-out.

So the "heaps of Julia stuff" is mostly **already written and tested — it lives
in PR #101 awaiting reconciliation into `main`**, and the R bridge already
exposes much of it. The real path to "Julia + bridge done" is therefore a
**landing/reconciliation + merge-decision program**, not a Julia-coding sprint:
1. land PR #101 (the wide engine) into GLLVM.jl `main`;
2. reconcile the local `codex/non-gaussian-fitter-gradients` engine with it
   (the local engine is the narrow subset — do NOT re-implement #101's features
   on it, that only creates merge conflicts);
3. land the gllvmTMB bridge PR #492 and decide bridge family/feature exposure;
4. then promote the JUL-01/JUL-01A register rows with parity evidence.
These are maintainer-authority steps, not autonomous one-night coding.

## Classification of the remaining bridge work

### A. R-bridge-routing — closeable + verifiable in R against f7be594 (no engine edit)
- **S1 `cbind(successes, failures)` binomial** [GJL-GATE-CBIND-BINOMIAL].
  Marshal col-1 = successes → `Y`, `rowSums` = trials → `N` matrix →
  `gllvm_julia_fit(..., N=)`. Engine already accepts `N`. Flip `cbind_binomial`
  capability, drop the matching expected-drift row + gate row (19→18 gates).
  **✅ DONE + LIVE-VERIFIED** on `claude/bridge-finish-20260619` (commit
  `d2b3e2f`): pure-R 357→358, **LIVE 1188→1195 (FAIL 0)**, drift frame 0
  unregistered rows, and `cbind(...)` fit == direct `N=` fit with logLik /
  loadings / alpha delta **exactly 0**. **Caveat: response-grammar change →
  maintainer sign-off before merge** (built + verified on a branch, NOT merged).
- **S2 correlation-interval point-only contract** [GJL-GATE-CORRELATION-INTERVALS,
  JUL-01A]. Convert the `extract_correlations()` abort for `gllvmTMB_julia`
  (`R/extract-correlations.R:185-193`) into point rows with
  `lower=NA, upper=NA, interval_status="none"`, mirroring the Sigma-table route.
  Pure-R; lowest-risk; agent-mergeable. **✅ DONE** (`cec51a9`): +11 pure-R
  tests, pkgdown clean; `GJL-GATE-CORRELATION-INTERVALS` kept live because
  `plot_correlations()` still genuinely needs interval rows.
- **S3 gate hardening** — covering pure-R tests for the *correct* refusals
  GJL-GATE-NO-CI-PAYLOAD and GJL-GATE-PROB-CLASS-NONORDINAL. Test only.
  **✅ DONE** (`6217540`): +6 pure-R tests asserting the full `[GJL-GATE-*]` ids.

### B. Julia-engine — editable local checkout (NOT #101), verified via `runtests.jl`
- **J1** confirm local `julia --project=. test/runtests.jl` is green (baseline).
- **J2** add a local-honest `bridge_capabilities()` to the local engine. Engine
  work; changes a public-ish surface → note for maintainer. **✅ DONE**
  (`claude/jl-bridge-capabilities-20260619` @ `34e8d93`): exported, runtests exit
  0, new behavioural cross-check test 60/60, with two honest divergences from the
  integration table fixed to local reality (ordinal Wald = true; simulate =
  false). (Note: because the R bridge targets the *wide* integration engine, it
  is broader than the narrow local engine on X/mask/CI — so this does NOT make
  the local engine a clean R-drift target; its value is engine contract-completeness.)
- **J3** analytic Wald Hessian — **ALREADY DONE.** The engine computes the Wald
  Hessian via `ForwardDiff.hessian(nll, θ̂)` (exact AD, `src/confint.jl:261`) and
  already verifies it against a central finite-difference Hessian to tolerance
  (`src/confint_nongaussian.jl:3-4`). There is no FD-Hessian to replace.

### Read-only scouting of genuinely-new local-engine work (2026-06-20)
Scoped to find a slice that is genuinely-new (not in #101), verifiable, tractable,
and safe. Result: **none cleanly available.**
- Analytic Hessian → already AD-based + FD-checked (above).
- Per-family analytic gradients (incl. **Gamma**, the roadmap's "recheck") →
  already FD-tested to ≤1e-6 in `test/test_family_forwarddiff_gradients.jl:68-94`;
  `gamma.jl:65` notes closed-form Gamma derivatives. Effectively done.
- `simulate()` → `src/simulate.jl` is a local placeholder, but the integration
  (#101) engine already ships post-fit simulate → re-implementing it locally is
  duplicative (creates merge conflicts).
- The one genuinely-OPEN robustness item is **#91 high-rate Poisson divergence**
  (roadmap Phase 5) — a numerical-divergence bug with no clean reproduction in
  hand; debugging it overnight risks a wrong/partial fix. Recommend the maintainer
  scope it explicitly before an autonomous attempt.
**Conclusion:** further substantive Julia-engine progress is either already done,
duplicative of #101, or genuine debugging/research — confirming that "Julia +
bridge done" is a landing/reconciliation program, not an autonomous coding sprint.

### C. Decision-gated (NOT a one-night job — needs maintainer)
- **New families through the bridge** (Tweedie / Exponential / ZIP / ZINB /
  Delta-Gamma): the **engine implements these** (CI-gated), but the bridge
  family map that exposes them lives in the **no-touch #101 tree**; bridge
  exposure also needs R labels/scale-maps + a per-family ADEMP recovery gate.
- **Structured-term routing** (phylo / spatial / animal / kernel through the flat
  bridge): the largest gap. Engine has the fitters but none are wired into
  `bridge_fit`; needs a new structured payload contract over the ASCII bridge +
  R + CI + article. Phase-scale program.
- **R-side VA/EVA path** (Design 72): PARKED by maintainer 2026-06-03; separate
  TMB DLL, multi-week.
- **Broad native-vs-Julia parity promotion** (JUL-01/JUL-01A → `covered`): a
  sustained validation campaign + status sign-off, not a slice.
- **PR #492 / draft #489 disposition**: the serial gate for everything above.

### Gates that are simply NOT R-finishable (engine kernels absent)
NB1-X / ordinal-X CIs (no engine kernel); newdata predict/simulate (engine is
structurally in-sample); mixed-CI / ordinal-CI (no engine confint);
structured-terms / multi-RR / unconditional-simulate / ordinal-residuals (need a
new Julia bridge entry point in the no-touch tree).

## What "bridge done tonight" honestly is
One user-facing gate genuinely closed end-to-end (S1 cbind, **pending sign-off**),
one extractor refusal converted to a defined point-only contract (S2,
agent-mergeable), refusal-gates hardened with tests (S3), and the local engine
made drift-checkable (J2). Everything else is engine- or decision-gated and
cannot be honestly marked "done" without touching the no-touch tree or a
maintainer status sign-off. This map is the authoritative scope for that work.
