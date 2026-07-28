## Provenance

Codex implementation review task `task-ms52uh0u-4mcgsc` (session ID `019faa4d-7193-7422-8b45-17874bfea64d`)

**Source file:** `/Users/z3437171/.codex/sessions/2026/07/28/rollout-2026-07-28T13-57-09-019faa4d-7193-7422-8b45-17874bfea64d.jsonl`

**Date:** 2026-07-28 19:57:12 UTC

---

## Findings

1. **CONFIRMED — `aghq = "auto"` does not use its advertised auto-routing policy** · **BLOCKING**
   - `.aghq_auto_decide()` is dead code: it has no call site; therefore its trait-count cutoff and "decline on malformed/expensive gate" policy never affect a fit
   - `fit-multi.R` instead resolves a node count before the gate, then only rejects if *no* gate component is quadrature-routed
   - The per-family optimizer recommendation is also inert: `.aghq_resolve()` returns `optimizer` and `optArgs`, but `.gllvmTMB_aghq_k()` retains only `k`; `run_one()` uses `control$optimizer` instead
   - Impact: `"auto"` is materially less conservative than documented, and its claimed optimizer routing does not occur
   - Files: `R/fit-multi.R:5043`, `R/fit-multi.R:5073`, `R/fit-multi.R:6191`, `R/fit-multi.R:4888`

2. **CONFIRMED — the default cap can make the outer loop return the Laplace warm start without an optimizer step** · **BLOCKING**
   - With `nlminb`, cap 1 imposes `iter.max = 1` and `eval.max = 4`
   - If that optimizer call returns its input—as the supplied Poisson reproducer does—the next pass sees identical F, mode, and parameters
   - The `abs(dF) < f_tol` leg then fires despite a large gradient, and the code exits as `STALLED` 
   - This is neither a flat objective nor a stale tape: it is the combination of a too-small first `nlminb` budget and a stopping rule that terminates before continuation can escalate to cap 2
   - The code itself records the Poisson trace with gradient 0.5012 and zero movement
   - Minimal reproducer: Poisson `n=200, T=6, q=1, aghq=9, aghq_ridge=Inf`
   - Files: `R/fit-multi.R:4912`, `R/fit-multi.R:5445`, `R/fit-multi.R:5505`, `R/fit-multi.R:5454`

3. **CONFIRMED — several continuation controls mentioned by the engine are not accepted by `gllvmTMBcontrol()`** · **IMPORTANT**
   - The loop reads `aghq_continuation`, `aghq_shift_tol`, `aghq_grad_tol`, `aghq_f_tol`, `aghq_escalate_patience`, and `aghq_rho_min`, but none is a formal control argument
   - `...` is explicitly ignored with a warning; thus, for example, `gllvmTMBcontrol(aghq_continuation = FALSE)` does not do what the AGHQ comments say
   - Only manual mutation of the returned list can set these parameters
   - Files: `R/fit-multi.R:5241`, `R/gllvmTMB.R:1253`

4. **SUSPECTED — C++ does not validate aghq_n_node > 0** · **MINOR**
   - C++ validates grid dimensions but not `aghq_n_node > 0`; a direct TMB caller supplying a zero-row grid reaches `aghq_logw(0)`
   - The public API cannot create this state currently, so this is not user-facing
   - Files: `src/gllvmTMB.cpp:2651`

## What is Sound

- **Shadowed grids:** Confirmed present. `.aghq_grid()` is live when present; `.gllvmTMB_aghq_grid()` is the fallback. They are mathematically equivalent. Tensor-row ordering differs for `d > 1`, but each row's node and weight remain paired. The sanity gate catches normalization/second-moment disagreement.

- **Quadrature math:** Correct. R supplies `L^{-T}` and `-½ log|H|`; C++ evaluates the full joint integrand, including the standard-normal prior, and combines it with the same transformed GH weight. The `sqrt(2)` factor appears exactly once via the R grid.

- **State hygiene:** Sound on examined paths. The finalizer retapes at `par_best`; then the common finalization re-evaluates `obj$fn(opt$par)`, overwrites `last.par.best`, calls `report()` from that state, and gives `sdreport()` explicit fixed parameters. Laplace fallback also passes through this common state reset.

- **Ridge:** Correct on the examined path. `lam_idx` is checked against the AGHQ parameter-name vector, and both wrapper and convergence gradient add exactly `theta_rr_B / tau²`.

---

## Not Recoverable

None. The complete Codex review was successfully recovered from the session file.

