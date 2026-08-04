# Engine Knob Audit — the four `MakeADFun` paths, side by side

Read-only inventory. No claims about speedup, no recommendations. Every cell
is cited `file:line`. Worktree: `/private/tmp/gllvmtmb-va-lane2`.

**The four/five call sites**, found by `grep -rn "MakeADFun" R/` (exhaustive —
this is every `TMB::MakeADFun(` call in the package):

| # | Engine | Function | File:line |
|---|---|---|---|
| 1 | **Laplace** (shipped) | `gllvmTMB_multi_fit()` | `R/fit-multi.R:5113` |
| 2 | **AGHQ** | inner adaptation loop | `R/fit-multi.R:5668` |
| 3 | **VA-R3** (fenced prototype), profiled variant | `.va_r3_make_objective()` | `R/va-r3-proto.R:2089` (`do.call`) |
| 4 | **VA-R3**, default (non-profiled) variant | `.va_r3_make_objective()` | `R/va-r3-proto.R:2091` |
| 5 | **other** — EVA prototype, frozen fixture | `.eva_make_objective()` | `R/eva-proto.R:181` |
| 6 | **other** — EVA prototype, caller data | `.eva_make_objective_data()` | `R/eva-proto.R:371` |

Laplace and AGHQ **share** their optimiser dispatch code (`run_one()`,
`R/fit-multi.R:5166-5215`) and their `sdreport` call (`R/fit-multi.R:6087`) —
AGHQ, when it succeeds, overwrites `obj`/`opt` with its own result
(`R/fit-multi.R:5969-5970`) and falls through to the same post-fit block. So
sections B and C below are genuinely identical code for these two engines,
not independently-tuned duplicates.

Legend: **SET** = value explicitly passed by gllvmTMB code (value shown).
**— (TMB default)** = argument never touched anywhere on this path; TMB's
own default applies. **N/A** = the call itself does not happen on this
engine.

---

## THE MATRIX

### A. `MakeADFun` arguments

| knob | Laplace | AGHQ | VA-R3 (default) | other (EVA) | notes |
|---|---|---|---|---|---|
| `data` | SET `tmb_data` (`fit-multi.R:5114`) | SET `data_aghq` (`fit-multi.R:5668`) | SET `tmb_data` (`va-r3-proto.R:2092`) | SET (`eva-proto.R:182`, `:372`) | AGHQ's `data_aghq` = `tmb_data` + `aghq_*` fields, `fit-multi.R:5659-5666` |
| `parameters` | SET `tmb_params` (`:5115`) | SET `tmb_params` (`:5668`) | SET `parameters` (`:2093`) | SET (`:182`/`184`, `:372`) | |
| `map` | SET `tmb_map` (`:5116`) | SET `map_aghq` (`:5669`) | SET `map` — may resolve to `NULL` (`:2094`, guarded `:2071`) | **ABSENT** — never passed at either EVA call site | EVA is the only path with no `map=` argument at all |
| `random` | SET, dynamic vector, built from `character(0)` (`:5047`) up (e.g. `"z_B"` at `:5053`) | SET explicitly `NULL` (`:5669`) | SET explicitly `NULL` (`:2095`) | SET explicitly `NULL` (`:186`, `:374`) | Laplace is the *only* path that ever puts anything in `random`; AGHQ/VA-R3(default)/EVA all run **outer-only** optimisation with zero TMB inner Newton solve |
| `profile` | **ABSENT** | **ABSENT** | SET `.va_r3_variational_names` — **profiled variant only, opt-in**, default `profile_variational = FALSE` (`va-r3-proto.R:1912`, `:2179`) | **ABSENT** | Only 1 of 6 call sites ever uses `profile=` |
| `intern` | **ABSENT** | **ABSENT** | **ABSENT** | **ABSENT** | Never appears anywhere in `R/` (grep-confirmed) |
| `inner.control` | **ABSENT** | **ABSENT** | conditionally SET, **profiled variant only**, and only if caller supplies `inner_control` — default `NULL` everywhere it is used (`:1914`, `:2180`, injected at `:2088`) | **ABSENT** | The one engine that always runs TMB's inner solve (Laplace, via non-empty `random`) never touches `inner.control`; the only path that *can* touch it is off by default |
| `silent` | SET, caller-controlled (`gllvmTMB_multi_fit(..., silent)` arg, `:342`) | SET, same variable (`:5670`) | SET, default `TRUE` (`:1910`, `:2097`) | SET, default `TRUE` (`:186`, `:374`) | |
| `DLL` | SET `"gllvmTMB"` (`:5118`) | SET `"gllvmTMB"` (`:5670`) | SET `dll$DLL`, from a runtime-compiled tempdir DLL (`:2096`) | SET `dll$DLL`, likewise runtime-compiled (`:185`, `:374`) | Laplace/AGHQ share **one** compiled DLL; VA-R3/EVA each compile their **own**, on demand — see section E |
| `checkParameterOrder` | **ABSENT** | **ABSENT** | **ABSENT** | **ABSENT** | Never appears anywhere in `R/` |
| `atomic` | **ABSENT** | **ABSENT** | **ABSENT** | **ABSENT** | Never appears anywhere in `R/` |
| `type` | **ABSENT** | **ABSENT** | **ABSENT** | **ABSENT** | Never appears anywhere in `R/` |

### B. Outer optimiser

| knob | Laplace | AGHQ | VA-R3 | other (EVA) | notes |
|---|---|---|---|---|---|
| default optimiser | `nlminb` (`run_one()`, `fit-multi.R:5211-5213`) | **same `run_one()`** (`:5859-5860`) | `nlminb`, or `lbfgsb` per family×tier auto-table (`.va_r3_resolve_optimizer()`, `va-r3-proto.R:1507-1521`) | `nlminb` only (`eva-proto.R:400`) | |
| alt. optimiser opt-in | `optim` (any `method`, default `"BFGS"`) via `control$optimizer="optim"` (`:5180-5193`) | same (shared code) | n/a — resolved automatically, not user-selectable | n/a | |
| `eval.max` / `iter.max` (uncapped) | `2000` / `1500` (`:5206`) | same code; AGHQ's *own* per-pass cap overrides this — see notes | `2000` / `2000` (`.va_r3_fit` default arg, `:2170`) | `2000` / `2000` (`.eva_fit` default arg, `:389`) | **Laplace's `iter.max` (1500) ≠ VA-R3/EVA's (2000)** — no stated reason for the difference |
| AGHQ per-pass cap | n/a | `eval.max = 4×iter_cap`, `iter.max = iter_cap`, schedule `1,2,5,25,NULL` (`:5204-5213`, `:5570-5574`) | n/a | n/a | Rebuilds the effective iteration budget every adaptation pass; unique to AGHQ |
| `trace` | **— (TMB/nlminb default)** | same | **— (default)** | **— (default)** | Never set by package code on any path |
| `rel.tol`, `x.tol`, `step.min`, `abs.tol`, `sing.tol` | **— (default)**, but user-reachable via `control$optArgs$control` (kept at `:5196`) | same | **— (default)**, **no user pass-through** (see `scale` row) | **— (default)**, **no user pass-through** | |
| `scale` (nlminb) | **— (default = 1)**; user-reachable — `"scale"` is in the `keep` whitelist (`:5196`) but `optArgs` defaults to `list()` (`gllvmTMB.R:1457`), so **never actually populated** | same code path (shared) | **NO PASS-THROUGH AT ALL** — `.va_r3_run_primary()` calls `nlminb(start, obj$fn, obj$gr, control = control)` with no `scale=` argument and no caller-facing knob for it (`:1523-1526`) | **NO PASS-THROUGH AT ALL** — identical call shape (`:400`, `:434`) | **`scale=` is never passed to `nlminb` on any of the four engines.** Laplace/AGHQ at least expose a route; VA-R3/EVA have none |
| `lower` / `upper` (nlminb box constraints) | **— (default)**; same `keep` whitelist as `scale` (`:5196`) | same | **ABSENT**, no mechanism | **ABSENT**, no mechanism | |
| `parscale` (optim) | **— (default)**; reachable via `control$optArgs$control$parscale` since `opt_args$control` is `modifyList`-merged with caller input (`:5184-5187`) | same | **ABSENT** — the L-BFGS-B polish call's `control=` is a hard-coded literal (`:2352-2353`), not built from any caller argument | **ABSENT** — the BFGS polish call's `control=` is likewise a hard-coded literal (`:447`) | `grep -rn "parscale" R/*.R` → zero hits package-wide |
| polish / fallback pass | none (single `run_one()` call per restart) | none beyond its own continuation schedule | up to 2 extra `nlminb` passes at the *same* `control` if `max|grad| >= 1e-4` (`:2327-2340`), then **L-BFGS-B** fallback, hard-coded `control=list(maxit=500L, factr=1e-12/.Machine$double.eps)` (`:2350-2353`) | up to 2 extra `nlminb` passes, identical structure (`:430-441`), then **BFGS** fallback, hard-coded `control=list(maxit=500L, reltol=1e-12)` (`:445-448`) | VA-R3's fallback is L-BFGS-B; EVA's is plain BFGS — different method for the same role, sized for their respective problem dimensions (VA-R3 carries `O(N·q)` variational coordinates, EVA fixtures do not) |
| multi-start width | `control$n_init`, default `1L` (`gllvmTMB.R:1455`), jittered restarts (`:5249-5304`) | **independent second multi-start layer**: `control$aghq_multistart`, default `TRUE` → 2 starts (`gllvmTMB.R:1510`, `fit-multi.R:5447-5478`) | `n_starts`, default `4L` (`:2173`, gate logic `:2255-2276`) | none — always 1 start from `.eva_default_parameters()` (`:394`) | Four different multi-start policies, four different defaults (1, 1+2-layered, 4, 1) |
| per-(family,tier) optimiser table | computed (`.aghq_resolve()` / `.aghq_optimizer_table()`, `aghq-control.R:221-235`) but **provably discarded** before reaching any optimiser call — `.gllvmTMB_aghq_k()` keeps only `k`, drops `optimizer`/`optArgs` (`fit-multi.R:6652-6670`) | ← (same finding; this *is* the AGHQ row) | **actually wired**: `.va_r3_resolve_optimizer()` reads an almost identical per-(family,tier) `lbfgsb` table and it drives the real optimiser choice (`:1494-1521`) | n/a | Same category of evidence (lbfgsb faster for some cells), acted on in VA-R3, shelved in AGHQ (with an explicit justifying comment) |
| `gllvmTMBcontrol()` reachability | full — `n_init`, `optimizer`, `optArgs` all apply | full (same control object) | **documented no-op**: "`n_init, optimizer, optArgs, start_from, init_*, se` … do not reach it and have no effect on this route" (`R/va-routing.R:356-364`) | not routed through `gllvmTMBcontrol()` at all (unexported research entry point) | VA-R3's non-reachability is a *known, written-down* limitation, not an oversight |

### C. `sdreport`

| knob | Laplace | AGHQ | VA-R3 | other (EVA) | notes |
|---|---|---|---|---|---|
| called at all? | YES, unless `control$se = FALSE` (`fit-multi.R:6082-6084`) | **same call** (shared `obj`/`opt` after AGHQ swap, `:5969-5970`) | **NEVER** — zero occurrences of `sdreport` anywhere in `R/va-r3-proto.R` (grep-confirmed) | **NEVER** — zero occurrences anywhere in `R/eva-proto.R` | Confirmed independently by package's own comments: `R/methods-gllvmTMB.R:447-448` calls it "the one production `sdreport()` call"; `R/re-uncertainty.R:4-9` says explicitly "No refit and no extra `sdreport()` call" |
| call site | `TMB::sdreport(obj, par.fixed = opt$par, getJointPrecision = FALSE)` — `fit-multi.R:6087-6088` | ← same line | N/A | N/A | Only ONE `TMB::sdreport(` call exists in the entire `R/` tree |
| `getJointPrecision` | SET `FALSE` (`:6088`) | SET `FALSE` | N/A | N/A | Documented consequence: `R/re-uncertainty.R:62-63` and `R/methods-gllvmTMB.R:451-452` both note the joint fixed+random precision "this fit's `sdreport()` does not compute" |
| `bias.correct` | **ABSENT** | **ABSENT** | N/A | N/A | |
| `skip.delta.method` | **ABSENT** | **ABSENT** | N/A | N/A | Every one of the 15 `ADREPORT()`'d quantities (below) pays full delta-method cost inside `sdreport()` on every fit |
| `ignore.parm.uncertainty` | **ABSENT** | **ABSENT** | N/A | N/A | |
| `getReportCovariance` | **ABSENT** | **ABSENT** | N/A | N/A | |
| what the engine uses *instead* | n/a (this IS the sdreport engine) | n/a | own Hessian machinery, `.va_r3_fixed_information()` (`:1756`), auto-routing to either: (a) `.va_r3_fixed_information_blocked()` → `.va_r3_hessian_blocks()`, **manual central finite differences** of `obj$gr()`, step `1e-5` (`:1584-1619`, `:1624-1709`), or (b) `objective$he(par)` — TMB's own AD-exact dense Hessian, no `sdreport` (`:1798`) | **nothing** — `.eva_fit()` returns point estimate, gradient, and `report()` only; grep for `hessian`/`fixed_information`/`\$he(` in `eva-proto.R` finds only an unrelated scalar helper (`.eva_aghq_marginal_q1()`, `:556-557`) | EVA has **zero** uncertainty-quantification machinery of any kind |
| `ADREPORT()` count in the engine's own `.cpp` | 15, `src/gllvmTMB.cpp` (`grep -c`) — same file as AGHQ | ← same file (`DLL="gllvmTMB"` shared) | 0, `inst/tmb/gllvmTMB_va_r3.cpp` | 0, `inst/tmb/gllvmTMB_eva.cpp` | Consistent with C1: nothing to `ADREPORT` when nothing calls `sdreport` |
| `REPORT()` count (non-AD, no delta-method cost) | 86, `src/gllvmTMB.cpp` | ← same | not separately counted (out of scope) | not separately counted | for scale contrast only |

### D. Process/global TMB settings

| knob | Laplace | AGHQ | VA-R3 | other (EVA) | notes |
|---|---|---|---|---|---|
| `TMB::config(...)` | **— (never called)** | same | same | same | Zero hits: `grep -rn "TMB::config" R/ src/ inst/` |
| `TMB::openmp(...)` | **— (never called)** | same | same | same | Zero hits |
| `TMB::runSymbolicAnalysis(...)` | **— (never called)** | same | same | same | Zero hits |
| `Sys.setenv(OMP_NUM_THREADS=…)` | **— (never set)** | same | same | same | Zero hits package-wide |
| `Sys.setenv(OPENBLAS_NUM_THREADS=…)` | **— (never set)** | same | same | same | Zero hits package-wide |
| package load hook (`.onLoad`) | n/a | n/a | n/a | n/a | `R/zzz.R` defines only `.onAttach` (start-up message, `:7-15`) and `.onUnload` (`library.dynam.unload`, `:17-19`) — **no `.onLoad` at all**, so no `options()` or thread setup happens at package-attach time either |

**Section D is a single blanket finding, not per-engine**: none of `TMB::config`, `TMB::openmp`, `TMB::runSymbolicAnalysis`, or either thread env var is used anywhere in `R/`, `src/`, or `inst/`. This is identical — completely absent — across all four engines, because it is process-global, not per-`MakeADFun`-call.

### E. Compilation flags

| knob | Laplace / AGHQ (shared DLL) | VA-R3 | other (EVA) | notes |
|---|---|---|---|---|
| how compiled | standard package build (`R CMD INSTALL` → `src/Makevars`) — **not** a runtime `TMB::compile()` call | **runtime**, on first use, via `TMB::compile()`, `R/va-r3-proto.R:916` | **runtime**, on first use, via `TMB::compile()`, `R/eva-proto.R:153` | Laplace/AGHQ's DLL is built once at install time; VA-R3/EVA each compile their own `.cpp` into a `tempdir()` the first time they are invoked in a session (cached by source MD5, `va-r3-proto.R:895-905`, `eva-proto.R:142-146`) |
| source file | `src/gllvmTMB.cpp` (147,873 bytes) | `inst/tmb/gllvmTMB_va_r3.cpp` | `inst/tmb/gllvmTMB_eva.cpp` | |
| `flags=` | n/a (no `TMB::compile()` call; governed by `src/Makevars` instead) | SET `"-O2"` — `.va_r3_load_dll()`'s default argument `compile_flags = "-O2"` (`:890`), used unmodified at `:916` | SET `"-O2"` — `.eva_load_dll()`'s default argument `compile_flags = "-O2"` (`:139`), used unmodified at `:153` | Both prototype engines pin the same explicit `-O2`; identical to each other |
| `framework=` | n/a | **ABSENT** from the `TMB::compile()` call (`:916`) — TMB package's own default applies | **ABSENT** from the `TMB::compile()` call (`:153`) | gllvmTMB code does not choose a framework for either prototype |
| `-DTMBAD_FRAMEWORK` | **SET**, `src/Makevars:1`: `PKG_CPPFLAGS = -DTMBAD_FRAMEWORK` | **NOT SET** — not in `compile_flags`, not `#define`d in `inst/tmb/gllvmTMB_va_r3.cpp` (checked its header, `:1-9`), not passed via `framework=` | **NOT SET** — not in `compile_flags`, not `#define`d in `inst/tmb/gllvmTMB_eva.cpp` (`:1-8`), not passed via `framework=` | **The only compile-time autodiff-framework choice the package makes anywhere is made for the shipped Laplace/AGHQ DLL only.** VA-R3 and EVA's DLLs get whichever framework TMB itself defaults to, unpinned by gllvmTMB |
| `PKG_CXXFLAGS` / optimisation level | **ABSENT** from `src/Makevars` (only `PKG_CPPFLAGS` is set) — optimisation level comes entirely from R's own `Makeconf` defaults for the install machine, not pinned by the package | `-O2`, explicit (see `flags=` row) | `-O2`, explicit (see `flags=` row) | No `-O3`, `-march=`, `-flto`, `-Ofast`, or `#pragma GCC optimize` anywhere in `R/`, `src/`, or `inst/tmb/` (grep-confirmed) |
| `CXX_STD` | **ABSENT** from `src/Makevars` — C++17 is requested only via the free-text `SystemRequirements: GNU make, C++17` field in `DESCRIPTION:91`, not via an explicit `CXX_STD = CXX17` line | n/a (runtime `TMB::compile()`, standard is whatever the ambient `R CMD SHLIB` toolchain defaults to — not pinned by gllvmTMB either) | n/a (same) | |
| `src/Makevars.win` | **does not exist** | n/a | n/a | Only one, platform-generic `src/Makevars` in the repository |
| `ByteCompile` (R code, not C++) | `TRUE`, `DESCRIPTION:85` | same (package-wide) | same | Out of scope for the C++ templates but the only other build-time performance setting in `DESCRIPTION` |

---

## Biggest gaps, ranked

1. **`scale=`/`parscale=` are never passed to the outer optimiser on any of the four engines, and two of the four have no mechanism to accept one at all.** Laplace/AGHQ at least expose a pass-through (`"scale"`/`"lower"`/`"upper"` are in the `keep` whitelist at `R/fit-multi.R:5196`, and `optim()`'s `control$parscale` reaches through the `modifyList` at `:5184-5187`) — but `gllvmTMBcontrol(optArgs=...)` defaults to `list()` (`R/gllvmTMB.R:1457`), so it is never actually populated. VA-R3 (`.va_r3_run_primary()`, `R/va-r3-proto.R:1523-1526`) and EVA (`R/eva-proto.R:400`, `:434`) call `nlminb()`/`optim()` with no scale-related argument and no caller-facing way to supply one — confirmed by a package-wide `grep -rn "parscale" R/*.R` returning zero hits.

2. **`sdreport()` runs on exactly one of the four engines' code paths (Laplace/AGHQ, which share the call); VA-R3 and EVA never call it.** VA-R3 substitutes a hand-rolled Hessian route that is itself two different costs depending on layout — manual central finite differences of the AD gradient (`R/va-r3-proto.R:1584-1619`, step `1e-5`, `2×(n_fixed+k)` extra gradient evaluations per unit-block) or TMB's dense `obj$he()` (`:1798`) — and EVA has no uncertainty machinery at all (point estimate + gradient + `report()` only). This is the largest single asymmetry in the audit: three completely different cost profiles for "get me the covariance matrix," one of them (EVA) simply absent.

3. **The `-DTMBAD_FRAMEWORK` compile define is set only for the shipped Laplace/AGHQ DLL (`src/Makevars:1`) and is not propagated to either prototype's runtime-compiled DLL.** Neither `R/va-r3-proto.R:916` nor `R/eva-proto.R:153` passes `-DTMBAD_FRAMEWORK` in `compile_flags` (both default to plain `"-O2"`, `:890` and `:139`), and neither passes a `framework=` argument to `TMB::compile()` either — so which autodiff framework VA-R3/EVA actually run on is left to TMB's own package default rather than a choice gllvmTMB makes, unlike the main engine where the choice is explicit.

4. **AGHQ computes a per-(family,tier) optimiser recommendation and then provably throws it away; VA-R3 computes the same category of evidence and wires it in.** `.aghq_resolve()`/`.aghq_optimizer_table()` (`R/aghq-control.R:221-235`, `:247-275`) recommend `lbfgsb` (with a required `factr` correction, `:254`) for specific family×tier cells, but `.gllvmTMB_aghq_k()` explicitly keeps only the node count `k` and discards `optimizer`/`optArgs` before any optimiser call happens (`R/fit-multi.R:6652-6670`, with a comment justifying it as currently a no-op for AGHQ's fixed `tier="B"` call). Meanwhile `.va_r3_resolve_optimizer()` (`R/va-r3-proto.R:1494-1521`) reads a near-identical table and it **does** drive VA-R3's real optimiser choice. Same knowledge, acted on in one engine, shelved in the other.

5. **`inner.control` (TMB's inner-Laplace-optimiser tolerance/iteration knob) is reachable on exactly one of six `MakeADFun` call sites, and it is off there by default.** Laplace is the only engine whose `random=` argument is ever non-empty (`R/fit-multi.R:5117`, built from `character(0)` at `:5047`), i.e. the only engine that ever actually runs TMB's inner Newton solve — and its `MakeADFun` call (`:5113-5120`) never sets `inner.control`. The one call site that *can* set it is VA-R3's opt-in `profile_variational=TRUE` branch (`R/va-r3-proto.R:2088`), which is off by default (`profile_variational = FALSE`, `:1912`/`:2179`) and structurally different anyway (`profile=` disables the Laplace approximation entirely rather than tuning it, per the comment at `:2074-2080`).

Two further, smaller inconsistencies worth recording even though they did not make the top five: **(a)** `nlminb`'s uncapped default control differs between engines with no stated reason — Laplace/AGHQ use `eval.max=2000, iter.max=1500` (`R/fit-multi.R:5206`) while VA-R3 and EVA both default to `eval.max=2000, iter.max=2000` (`R/va-r3-proto.R:2170`, `R/eva-proto.R:389`); **(b)** VA-R3's polish fallback is L-BFGS-B while EVA's is plain BFGS with different hard-coded tolerances (`va-r3-proto.R:2350-2353` vs `eva-proto.R:445-448`), and neither fallback's control list is reachable from any caller-supplied argument, unlike Laplace/AGHQ's `optim()` branch.
