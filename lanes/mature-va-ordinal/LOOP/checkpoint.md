GOAL: see `lanes/mature-va-ordinal/LOOP/GOAL.md` — but note the lane was REDIRECTED to **speed**
by Shinichi; `arcs.md` carries the current arc list. Ordinal Item 1(B) is deferred, not cancelled.

STATE: A0 landed. Two source-map scouts + an engine knob audit landed. First speed measurement
landed (profiling, 9.60×). AD-framework/supernodal A/B in flight.

ARCS DONE (verified):
- **A0 retraction** — `56dfd5f0`. Verified: visible banners on all four surfaces (verdict doc,
  the handover a fresh session rehydrates from, ledger row 46 + process lesson 3, check-log).
- **A2 scouts** — `6462fb61`. `50-GALAMM-REFERENCE-READ.md` (galamm + gllvm),
  `52-SDMTMB-GLMMTMB-REFERENCE-READ.md` (sdmTMB + glmmTMB).
- **A1 first measurement** — `6462fb61`. Profiling on a closed-form family, 3 cells.
- **Engine knob audit** — `35f16118`, `53-ENGINE-KNOB-AUDIT.md`. Two headline gaps
  hand-verified before being repeated.

MEASURED SO FAR (state the regime with every number):
- **`profile_variational = TRUE`, plain latent tier, `gaussian_anchor`, T=10, q=2:**
  N=100 1.73× · N=250 1.16× · **N=1000 9.60×**. Outer par **39 constant** vs 5039 at N=1000.
  Objectives agree to ~1e-11 → same optimum, zero statistical cost.
- **AD framework via `compile_flags = "-O2 -DTMBAD_FRAMEWORK"`: BROKEN, not slow.** Redefinition
  errors (`EvalADFunObjectTemplate`, `start_parallel.hpp` wanting CppAD's Forward/Reverse/
  Hessian). **That was MY method error** — `TMB::compile()` has its own `framework=` argument.
  Baseline arm timed fine: median 0.194 s, obj 2594.35082224.

IN FLIGHT:
- 4-arm A/B (`54-adframework-ab.R`): baseline · tmbad · supernodal · tmbad_supernodal, N=250.
  Uses the new `framework=`/`supernodal=` pass-through added to `.va_r3_load_dll()`.

NEXT:
1. Read the 4-arm A/B. `supernodal` is the interesting one — it partially REOPENS the
   sparse-Cholesky direction I had reported closed (that negative was about *custom*
   implementations; TMB exposes supernodal at compile time).
2. The **GH crossover cell** — `51-profile-variational-crossover.R` now takes a family argument.
   Running it on `binomial_probit` against the existing `gaussian_anchor` cells tests the
   hypothesis that per-evaluation derivative cost is the discriminator. **If it holds, that IS
   the heuristic glmmTMB has as an unshipped FIXME** (`glmmTMB/R/glmmTMB.R:1609-1613`).
3. Then: `inner.control` reach into Laplace (audit gap 2), `scale=` (gap 3).

OPEN GATES (need human):
- **G2** — any change to the SHIPPED Laplace engine (`src/gllvmTMB.cpp`) is likelihood-adjacent:
  maintainer's word + Gauss/Noether review. Nothing has touched it; all work so far is the
  fenced VA-R3 prototype and read-only scouting.
- **G3** standing — do NOT push `claude/va-lane2`.
- **G4** — statistically-free only. `inner.control`'s `tol10` loosens inner-Newton convergence
  and MAY move estimates; it is not a free lever until measured as one.

TRUTH LIVES IN:
- worktree `/private/tmp/gllvmtmb-va-lane2`, branch `claude/va-lane2`, **unpushed**
- `dev/va-speed/50/52/53-*.md` (scouts + audit), `51-*.R` + `51-crossover-*.rds` (profiling),
  `54-*.R` (AD framework A/B)
- `dev/va-speed/20-CLAIMS-LEDGER.md` — **check status before citing anything**; row 46 is RETRACTED
- filed cross-repo: https://github.com/itchyshin/drmTMB/issues/914 (+ a follow-up comment)

RESUME: Read `GOAL.md`, then this file, then `arcs.md`, then `AGENTS.md`. Reattach to
`/private/tmp/gllvmtmb-va-lane2` (do NOT recreate). Re-read GOAL each arc; verify by LOG not exit
code; pause at every OPEN GATE; overwrite this file each arc.
