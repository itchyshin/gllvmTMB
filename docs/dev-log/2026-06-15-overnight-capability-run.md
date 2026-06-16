# Overnight capability run — 2026-06-15/16 (Claude, autonomous)

Maintainer goal: finish the plan and close capability gaps, **gllvmTMB-first**,
using the team + ultracode, through ~5am. Articles deferred (done together later).

## TL;DR (morning read)

- **14 capability commits on `gllvmTMB@engine-julia` + 1 on `GLLVM.jl-integration`
  + 1 docs honesty fix on `GLLVM.jl` — nothing pushed.** All verified: canonical
  native `test_local` **3136 pass / 0 fail / 0 error** (240 files; +44 vs 3092
  baseline, no regression); **live heavy+julia bridge 826 pass / 0 fail / 0 skip**
  (fresh end-to-end run against GLLVM.jl-integration `1dc9e98`); engine
  `Pkg.test()` 3943 pass / 0 fail. (The post-compaction continuation — cutpoints,
  Sigma_B, guard tests, roadmap, plus two gap-audit fixes [`trait_families`
  bridge method, `tidy(cutpoint)`] — is detailed in that section below.)
- **Native ↔ `engine="julia"` point-parity is now characterized** (matrix below): it
  HOLDS for Gaussian / Poisson / Binomial (both no-X and fixed-effect-X); it does NOT
  hold for the dispersion families (NB2/NB1/Beta/Gamma) or ordinal.
- **Headline finding — the one thing for you to decide:** the non-parity is a
  *systematic structural divergence*, not a bug. `GLLVM.jl` shares a single trait-level
  nuisance parameter (dispersion; ordinal cutpoints) where `gllvmTMB` estimates one
  **per trait**. Not transform-fixable — needs an engine-alignment decision
  (see `2026-06-15-dispersion-structure-divergence.md`).
- **New capabilities:** ordinal `predict(type="prob"/"class")` (cross-repo); Pearson
  residuals; `getResidualCov()/getResidualCor()` bridge fix (was a real, user-visible
  bug); `trait_families()` accessor + per-trait family in `print()`.
- **Deliberately NOT done** (out of scope / your call): the dispersion/cutpoint engine
  alignment; non-Gaussian-X / REML / masked CIs (amendment-held); low-value test-coverage
  items; articles (to do together). **Nothing pushed; no CRAN/tag.**

## Continuation (post-compaction, ~22:15–22:40 MDT)

Picked up the uncommitted `extract_cutpoints` slice and finished the safe,
in-scope vein, then ran an independent completeness-critic gap-audit which
surfaced two more genuine fixes. **6 more local commits — nothing pushed.**

| commit | repo | slice | gating |
|---|---|---|---|
| `78d887b` | gllvmTMB | `extract_cutpoints()` for engine="julia" ordinal fits — returns the fitted **shared** cutpoints from the bridge payload in the native 5-column shape, `trait="(shared)"`, with an honest shared-vs-per-trait advisory; errors clearly on non-ordinal fits | bridge +20 |
| `899b90a` | gllvmTMB | `extract_Sigma_B()` for engine="julia" — point Σ_B=ΛΛᵀ and R_B (historical `{Sigma_B,R_B}` shape) via the validated `.gllvm_julia_residual_sigma()` helper; same quantity as `getResidualCov(level="unit")`; removes the misleading native-only abort | bridge +7 |
| `e1dacae` | gllvmTMB | regression tests locking two capability-guard branches: **phylo/structured-term refusal** and **multi-rr refusal** | bridge +4 |
| `1b42e35` | GLLVM.jl | softened the v1.0 roadmap row (`Full digital twin`→`Digital-twin milestone`; `complete R bridge coverage`→`expanded …`) — the one LOW finding from the claim audit | docs |
| `7d46924` | gllvmTMB | **`trait_families.gllvmTMB_julia`** S3 method (gap-audit #1) — was generic + `gllvmTMB_multi` only, so it errored "no applicable method" on bridge fits. **Corrects a false "done" belief**: `14df97d` shipped `trait_families()` multi-only; now wired for the bridge (canonical per-trait accessor for mixed-family fits) | bridge +6 |
| `a00d4d2` | gllvmTMB | **`tidy(effects="cutpoint")`** for engine="julia" ordinal fits (gap-audit #2) — routes to the now-wired `extract_cutpoints()`, mirroring native term+estimate shape; `ran_pars`/`conf.int=TRUE` stay refused | bridge +9 |

- **`extract_Sigma_W()` / `extract_correlations()` deliberately stay unwired**
  (documented): `Sigma_W` on the bridge is only the trivial Gaussian σ_eps²I
  diagonal already reachable via `getResidualCov(level="unit_obs")`; the point
  cross-trait correlation is `getResidualCor()`, and wiring `extract_correlations`
  would only add out-of-scope CI columns. The accessor vein is now **exhausted** —
  every remaining accessor (ICC, repeatability, Ω/phylo, proportions, Gamma) is
  degenerate on the bridge.

- **Claim-surface honesty audit (read-only, both repos):** 1 finding,
  **0 HIGH / 0 MED / 1 LOW** (the roadmap row, now fixed). REML correctly
  Gaussian-only; non-Gaussian-X & masked CIs correctly CI-status-strings-only;
  mixed-family correctly capped at no-X/no-mask/no-CI `partial`; the
  dispersion/ordinal divergence correctly disclosed as cannot-point-parity.
  **The public claim surface is honest.**

- **#92 (phylo-signal CI bridge exposure) is BLOCKED at the fit level** — a
  maintainer-relevant boundary, now confirmed + locked in a test (`e1dacae`):
  the bridge maps ONLY the single reduced-rank latent block and rejects
  phylo/spatial/structured terms at dispatch (`R/julia-bridge.R:2485`). The
  engine's phylo-signal CI machinery runs on **native GLLVM.jl** phylo fits,
  which `gllvmTMB(engine="julia")` cannot produce. So #92's R-bridge exposure is
  gated behind the structured-dependence bridge track (out-of-scope engine work),
  **not** a quick exposure.

- **Independent completeness-critic gap-audit (read-only, both surfaces):**
  verdict **MINOR-GAPS** → both now fixed (`7d46924`, `a00d4d2`) → surface now
  **EXHAUSTED**. The audit independently **verified** every "degenerate / unwired"
  conclusion (`extract_Sigma_W`, `extract_correlations`, ICC, repeatability,
  `extract_Omega`, `extract_proportions`, `extract_Gamma`, `vcov`, `diagnose`,
  `extract_Sigma_table`) with a code reason each, and found **no bridge_capabilities
  advertise-vs-wired contract mismatches**. One borderline item (exposing the
  link-residual-adjusted Σ_B carried as `$Sigma`) was **correctly skipped**: its
  "silent parity-trap" rationale is actually wrong — native `getResidualCov` also
  calls `extract_Sigma_B` with `link_residual="none"`, so native and bridge both
  return ΛΛᵀ; the `"auto"` variant is only reachable via the CI-bearing
  `extract_Sigma`, which is gated.

- **Process note (verification fix):** earlier per-slice summaries summed only
  the testthat `failed` column, which HID a test-only error (a
  `conditionMessage()` on a non-condition list) in the first `extract_Sigma_B`
  test draft. The canonical `devtools::test()` caught it; fixed + amended into
  `899b90a`; verification now counts `failed + error`. The accessor **functions**
  were always correct — only the test draft had the bug.

- **Verification (continuation):** canonical native `test_local`
  **PASS 3151 / FAIL 0 / ERROR 0** (240 files; +59 vs the 3092 baseline — the
  6 continuation slices, no regression); bridge file fixture
  **PASS 371 / FAIL 0 / ERROR 0**; **live heavy+julia bridge
  PASS 826 / FAIL 0 / ERROR 0 / SKIP 0** (run after the cutpoints+Sigma_B
  slices) — every live test ran against the real GLLVM.jl-integration `1dc9e98`
  engine, no live regression. Both trees clean; nothing pushed.

## Standing constraints
- R-first; the 7 amendments are binding (do **not** fill amendment-held cells:
  NB1-X, non-Gaussian-X CI endpoints, mixed-family widening, masked CIs/sims,
  non-Gaussian/REML-CI). Status vocabulary only; no "full/complete" wording.
- **Local commits only — no push.** One concern per commit, staged by name.
- Each slice: implement → test → verify (record tally) → Rose self-audit → commit.
- m3-pilot power sim pins ~11 cores → heavy suites slow; prefer filtered tests.

## Baseline at start
- gllvmTMB `engine-julia` @ `a083cdc` — Gaussian REML bridge banked + verified
  (pure-R bridge 254 pass/19 skip; live bridge 612/612 vs GLLVM.jl-integration `5fabcb1`).
- WIP backup at `/tmp/gllvm-takeover-snapshot/`.

## Key findings (surface to maintainer)
- **Native-vs-engine="julia" point-PARITY HOLDS for no-dispersion families**
  (Gaussian / Poisson / Binomial) to ~1e-9 logLik, ~1e-5 estimates/Σ_B. Strong
  R-first evidence to promote those rows toward `covered`. [6c646cc, c06c96c]
- **Systematic dispersion-STRUCTURE divergence** (→ `2026-06-15-dispersion-structure-divergence.md`):
  `GLLVM.jl` uses a single **shared scalar** dispersion per family; `gllvmTMB`
  native uses a **per-trait** vector (df differ by `n_traits−1`). So dispersion
  families (NB2/NB1/Beta/Gamma/…) **cannot** point-parity until the engines align
  the dispersion structure. NB2 documented + guarded [fa7b997]. **This is a real
  twin-fidelity gap and a concrete engine-alignment task for the maintainer.**

## Slices completed (verified, committed local)
| # | slice | pkg | commit | gating evidence |
|---|-------|-----|--------|-----------------|
| 0 | Gaussian REML bridge (inherited, verified+banked) | gllvmTMB | a083cdc | bridge 254/612 |
| 1 | Native-TMB vs engine="julia" **Gaussian parity** (logLik 1e-6; means/loadings/σ_eps 1e-4) | gllvmTMB | 6c646cc | 44 tests/622 pass; new test 10/10 (heavy-gated) |
| 2 | **Pearson residuals** for engine="julia" (per-family variance map; mixed-row-aware; masked NA; ordinal errors) | gllvmTMB | 268e409 | no-Julia bridge 264 pass (+10) |
| 3 | **getResidualCov/Cor** bridge fix (real bug: misleading abort → Σ_B=ΛΛᵀ; σ_eps²I Gaussian W; clear error non-Gaussian W) | gllvmTMB | 9bf10c9 | no-Julia bridge 278 pass (+14) |
| 4 | **trait_families()** accessor + per-trait family in print (multi); family-id map verified vs family_to_id() | gllvmTMB | 14df97d | trait-families heavy 15; mock 38 pass |
| 5 | **Poisson + Binomial parity** (native-vs-julia; shared Σ_B helper; Gaussian refactored onto it) | gllvmTMB | c06c96c | heavy+julia 664 pass (indep. re-run) |
| 6 | **NB2 honest non-parity** — documents shared-scalar vs per-trait dispersion mismatch + guard (NOT promoted) | gllvmTMB | fa7b997 | heavy+julia 675 pass (indep. re-run) |
| 7 | **Ordinal predict(prob/class)** — engine emits cutpoints+n_categories; R computes P(y=c)=F(τ−η); machine-precision match | gllvmTMB `804c2a5` + integration `1dc9e98` | heavy+julia 714; engine Pkg.test 3943/0 |
| 8 | **Fixed-effect-X parity** (Gaussian/Poisson/Binomial native-vs-julia; full β incl. x-coef; two-payload-shape aligner) | gllvmTMB | a58bc71 | heavy+julia 745 pass (+31, indep.) |
| 9 | **Mixed-family parity** (no-dispersion components; shared-Λ cross-family fit) | gllvmTMB | 769cef3 | heavy+julia 756 pass (+11, indep.) |
| 10 | **Masked-response parity** (Poisson/Binomial no-X; cell-wise mask = native NA handling, identical observed cells) | gllvmTMB | 8d114dc | heavy+julia 782 pass (+26, indep.) |
| 11 | **extract_communality()** bridge fix (removes misleading abort; Gaussian degenerate c²=1, clear non-Gaussian errors) — modest: communality is degenerate on the bridge (no unique tier) | gllvmTMB | 1ec78e8 | no-Julia 325 pass |

## Verification (close-out checkpoint, ~20:15)
- Native fast full suite (`devtools::test()`): **FAIL 0 | WARN 3 (pre-existing) | SKIP 730 | PASS 3092**
  (+69 vs inherited 3023; **no regression** from the 8 slices).
- Heavy+julia bridge suite: **745 pass / 0 fail** (independent re-run; includes the X-parity tests).
- Engine (GLLVM.jl-integration `1dc9e98`) ordinal payload change: engine `Pkg.test()` initially
  flagged 3 STALE `bridge_capabilities` assertions (ordinal predict is now `true`) — fixed +
  re-verified (20/20); engine suite **3943 pass / 0 fail / 1 pre-existing broken**. (The engine
  Pkg.test caught a regression the R bridge suite missed — worth running.)

## Parity matrix (native engine="tmb" vs engine="julia" point estimates)
| Family | no-X | fixed-effect-X | note |
|---|---|---|---|
| Gaussian | ✓ HOLDS (~1e-9 / 1e-4) | ✓ HOLDS | closed-form marginal |
| Poisson | ✓ HOLDS (~1e-9 / 1e-3) | ✓ HOLDS | shared Laplace marginal |
| Binomial | ✓ HOLDS (~1e-9 / 1e-3) | ✓ HOLDS | shared Laplace marginal |
| Mixed (G+P+B, no-disp) | ✓ HOLDS | (n/a) | shared-Λ cross-family fit |
| NB2 / NB1 / Beta / Gamma | ✗ structural | (n/a) | shared-scalar vs per-trait **dispersion** |
| Ordinal | ✗ structural | (n/a) | shared vs per-trait **cutpoints** |

_Also verified to parity:_ **mixed-family** (G+P+B, shared-Λ) and **masked-response**
(Poisson/Binomial no-X — the bridge's cell-wise mask matches native NA handling
*exactly*, identical observed cells). So every achievable no-dispersion case parities.
- `NEWS.md` reconciled with honest entries; dispersion/ordinal divergence documented + guarded.
- Ordinal native-vs-julia parity NOT run: the finding (per-trait vs shared cutpoints) shows it cannot
  point-parity — same structural reason as the dispersion families.

## Remaining / next (if continuing)
- #92 derived phylo-signal CI bridge exposure (engine done; R bridge exposure pending).
- Low-value coverage: r5 Poisson masked, r7 un-gate no-fit blocks, r10/11/12.
- Engine-alignment for dispersion/cutpoint structure — **out of scope** (engine algorithm work).

## Recon worklist (`w7ajgc9u0`) — tonight, gllvmTMB-first, non-amendment-held
- [done] r1/r2 Gaussian native-vs-julia parity → `6c646cc`.
- [done] r3 Pearson residuals → `268e409`.
- [active] r4 `getResidualCov()/getResidualCor()` BUG — aborts "Provide a fit returned by gllvmTMB" on a
  valid `gllvmTMB_julia` object (`extract-sigma.R:580`); add a julia branch building
  Σ_B=ΛΛᵀ (+σ_eps²I for homogeneous Gaussian) from cached `$loadings`/`$sigma_eps`.
- r5 Poisson masked public coverage (masked test loop covers 6/7 families; Poisson missing).
- r6 Native per-trait `families()` accessor on `gllvmTMB_multi` (`family_selector` stored, unexposed).
- r7 Un-gate 3 no-fit mixed-family fixture-contract test blocks.
- r8/r9/r13 Poisson / Binomial / NB2 native-vs-julia parity tests (+ dispersion).
- r10 Live non-Gaussian no-X Wald CI breadth through `confint.gllvmTMB_julia`.
- r11 REML CI-status method symmetry + at-rest field parity.
- r12 Structural-refusal guard regression test for `engine="julia"`.

## Deferred (research / amendment-held / articles)
- NB1/Beta/Gamma/Ordinal native-vs-julia parity — medium, serialized after the cheap families.
- Dunn-Smyth/randomized-quantile residuals — needs an RNG/seed contract.
- #92 derived phylo-signal CI Julia-**bridge** exposure — native R path already done.
- Gaussian masks / X+mask / predictor `mi()` — research / cross-repo / amendment-adjacent.
- Phylo O(p) sparse-grad, spatial/SPDE, animal/relmat — engine research in GLLVM.jl-integration.
- Random-slopes ledger correction + **articles/visuals** — explicitly with the maintainer.
- Amendment-held cells (NB1-X, non-Gaussian-X CI endpoints, mixed-family widening,
  masked CIs/sims, REML/non-Gaussian CIs) — intentionally NOT filled.

## Notes / decisions
- (running log)
