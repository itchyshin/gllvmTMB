# After-task — Design 108 Gate A Stage 6 (multiple unstructured tiers) + R3 (`profile=` route)

**Date:** 2026-08-02 · **Platform:** Claude Code · **Merged:** PR #907, `main` @ `773b1ffa`
**Commits:** `509460b8` (Stage 6) · `15c7a18d` (R3)

*Written after the merge, not before it. That is a Definition-of-Done violation and it is
recorded here rather than quietly fixed: the PR shipped without this report, and the gap was
noticed only when the maintainer asked whether to merge. See §9.*

## 1. Goal

Two arcs that landed together because the second depends on the first.

**Stage 6 — multiple unstructured tiers.** The stage at which **Gate A closes**. Ayumi's model has
two latent tiers (ordinary species + phylogenetic) and both carry `unique = TRUE`; the VA engine
admitted exactly one tier and refused Ψ outright. Design 108 §3 also claims Stage 6 delivers
`diag(psi)` — the package's **own default `latent()` term**, hard-gated off — plus
`unique`/`indep`/`cluster`/`cluster2`/`unit_obs`/`scalar` "in one stroke".

**R3 — the `profile=` route.** Not a Design 108 stage. It answers a question raised by Stage 9's
feasibility analysis and confirmed by direct measurement: **the VA engine could not reach the target
model at any capability level**, because `MakeADFun(..., random = NULL)` puts every variational
coordinate in the dense outer problem.

## 2. Implemented

**No public API change. The fence is untouched and still refuses Ψ; a test now pins that.**

**Stage 6.** Tier structure becomes DATA (`n_tiers`, `tier_kind`, `tier_dim`, `tier_n_levels`,
`level_id`); `m`/`log_L_diag`/`L_off` become flat `PARAMETER_VECTOR`s plus a new `log_sd_tier`;
`mu` and `v` accumulate over tiers (Design 106 Proposition 1); the KL loops tiers × levels;
`kl_by_level`/`kl_by_tier` are reported. The `unique`/`psi` gate is lifted in **both** places that
carried it — `R/va-r3-proto.R:325` and `R/approximation-engine.R:68` — because Stage 4 established
that two gates on one condition will silently disagree.

**R3.** `.va_r3_make_objective()` / `.va_r3_fit()` gain `profile_variational` (default `FALSE`) and
`inner_control`. `best$par` remains the full parameter vector on both routes (reconstructed from
`obj$env$last.par`); `best$outer_par` is added. **`inst/tmb/gllvmTMB_va_r3.cpp` is unchanged by
R3** — Stage 6's flat parameter vectors were already the shape `profile=` needs, which is the one
place these two arcs helped each other rather than merely stacking.

## 3a. Decisions and Rejected Alternatives

| Decision | Rationale | Rejected |
|---|---|---|
| **Flattened parameter vectors sliced by offsets**, not a fixed cap of named tier slots | A cap is silently wrong at K+1 and there is no natural K. Within a tier the flat order is column-major over (coordinate, level), which **is** `as.vector()` of the old `N × q` matrix — so K=1 is **byte-identical**, not merely equal | Fixed slot count: simpler, caps K, reopens the "silently wrong at K+1" trap this codebase avoids fastidiously |
| Offsets computed in R **and independently recomputed in C++** from the same three tier vectors | An R/C++ disagreement trips a length check instead of reading across a tier boundary — a class of bug that produces plausible numbers | Trusting one side to be authoritative |
| **Tier 0 pinned dense** (`tier_kind=0`, `dim=q`, `level_id == unit_id`) | It is what makes the K=1 equivalence *provable* rather than coincidental | A fully general tier 0; costs the provable-equivalence property |
| **Diagonal tiers get their own code path**, not the dense path at `d_k = T` | Proposition 2's saving is opt-in by construction. Via the dense path it would "work" while costing 377 numbers per level instead of 52 — passing every test while forfeiting the reduction | Reusing the dense Cholesky machinery: less code, silently 7.25× worse |
| **R3 opt-in, default `FALSE`** | `profile=` changes what `sdreport()` computes across the profiled block, and the VA SE story is a named open item (arc plan §6.2). Shipping it as default would silently repoint the SE route | Default-on: better numbers, silent behaviour change for every existing fit |
| **Multi-tier SEs fail closed** | `H_vv` is block-diagonal by connected component of the tier–level graph. For a Ψ companion that is still the unit, but nothing in the parameter names distinguishes it from a `cluster` tier — so it refuses rather than return a wrong Schur complement | Returning the unit-block answer and hoping; Stage 14 owns that surface |
| **`fixed_global` refused at K>1** | It names only `beta`/`theta_rr`; honouring it would half-fix a multi-tier model and report success | Partial honouring |

## 4. Files Touched

| File | Change |
|---|---|
| `inst/tmb/gllvmTMB_va_r3.cpp` | tier DATA; flat parameter vectors; `log_sd_tier`; mu/v over tiers; KL over tiers × levels (**Stage 6 only — R3 left it untouched**) |
| `R/va-r3-proto.R` | `.va_r3_tier_registry`/`_entry`/`_build_tiers`/`_layout`; gate lift; `extra_tiers`; flat starts; multi-tier SE fail-closed. R3: `profile_variational`, `inner_control`, `outer_par` |
| `R/approximation-engine.R` | lockstep gate lift; `unique`/`psi`/`extra_tiers` pass-through; `admitted_regime` restated |
| `tests/testthat/test-va-r3-prototype.R` | lifted-gate assertion replaced **in place** with a stronger positive one; 8 tests appended |
| `tests/testthat/test-approximation-engine.R` | lifted gate's assertion replaced by "the two gates agree" |
| `tests/testthat/test-va-probit-adsafety.R` | raw-template harness declares the new tier DATA (same K=1 model, restated) |
| `tests/testthat/test-va-r3-profile.R` | **new** — 41 assertions: opt-in identity, block-diagonality, L0–L3, L7 negative control |

**Cascade: nothing else required.** No roxygen changed, so no `man/*.Rd` regeneration. No
NEWS/README/vignette text — there is no capability to advertise.

**Roadmap tick:** Gate A **closes** at Stage 6. Stage 7 (structured phylo KL) is hard-dependent on
it and is the last Gate-A derivation. No `ROADMAP.md` line moves — Gate A is a research programme,
nothing here is user-facing.

## 5. Checks Run

**Stage 6**
- K=1 **byte-identity**: `obj$par` (names and values), `fn`, `gr`, `mu_by_obs`, `v_by_obs`,
  `kl_by_unit`, `elbo` all `identical()` to the pre-change template.
- **Proposition 2 structural**: at T=26, `variational_per_level = 52` against
  `T + T(T+1)/2 = 377` — exactly **7.25×**, with `off_per_level = 0`. Verified twice: off the
  layout, and off a constructed objective.
- Multi-tier oracle, K=3 (dense + trait-diagonal + dense at a coarser grouping): mu/v/KL to
  **1e-16**, gradient to **5e-9**.
- Exact nesting: Ψ at `sd → 0` differs from the single-tier fit by **exactly 0**.

**R3** — L3, the arc plan's own acceptance test: gradient of the **ORIGINAL** joint objective
(`random = NULL`) at the profiled solution's full parameter vector, 12 cells (4 families × q∈{1,2,3}
× N∈{60,150,400}):

| | max abs gradient |
|---|---|
| **profile route** | **6.28e-5** (all 12 cells < 1e-4; 4.28e-5 with polish) |
| joint route, same test | **fails 4 of 12 cells**, max **5.70e-3** |

The profile answer is a *better-converged stationary point of the joint objective than the joint
route's own answer*. **L7 negative control**: a crippled inner solve (`tol=1, maxit=1`) gives
L3 = 5.04 and the test asserts that failure — without it the gate would measure nothing.

Peak **process RSS** (`ps` at 20 ms, not `gc()`; T=8, q=2, gaussian):

| N | joint | profile |
|---|---|---|
| 1,000 | 188.5 MB | 231.3 MB |
| 4,000 | 1,935.5 MB | 845.0 MB |
| **8,000** | **≥6,460 MB, DNF** (3 iterations in 23 min) | **1,697 MB, 12.5 s** |

Fitted exponent N≥1000: **joint 1.70, profile 0.966**. Outer parameter count
`114N + 206 → 206`, constant in N — at N=10,000, **1,140,206 → 206**.

**Regression:** 775 passes / 0 failures across 9 files (`test-va-r3-prototype.R` 473,
`-mixed-family` 23, `-integration-fence` 39, `-probit-adsafety` 114, `-approximation-engine` 38
with 1 pre-existing skip, `-missing-response` 10, `-separation` 6, `-routing-oracle` 31,
`-profile` 41). `R CMD check`: 0 errors / 0 warnings / 0 notes. PR CI green (26m10s).

## 6. Tests of the Tests

- **The three single-tier oracles were verified UNTOUCHED by diff**, not by assertion: zero diff
  lines for each, and the `structured = TRUE` refusal is byte-unchanged. Checked independently by
  the orchestrator, because "the oracles still pass" is exactly what an edited oracle also reports.
- **Proposition 2 is asserted structurally**, not by convergence: `off_per_level == 0`. A test that
  the diagonal tier *converges* to a diagonal optimum would pass on the dense path too and prove
  nothing about cost.
- **L7 exists so that L3 can fail.** Value agreement between routes was explicitly rejected as
  evidence — the arc plan says the joint-objective gradient is what "no amount of value agreement"
  can substitute for.
- **Default-identity was checked by swapping the file on disk against `git show HEAD:`** and
  comparing serialised outputs across 4 families, not by running the suite twice.

## 7a. Issue Ledger

None opened or closed. Related and open: #897 (ordinal detector gap).

## 8. Consistency Audit

- No grammar, keyword, or `Sigma`/`Lambda`/`psi` notation change.
- `man/*.Rd` not regenerated — no roxygen touched.
- Register: **no new row.** Stage 6 and R3 admit nothing new to the public fence, so VA-02's
  admitted set is still correct as written. VA-12 (Stage 4) unchanged.
- Two existing assertions changed, both the gate under lift, both replaced with **stronger**
  positive assertions (Ψ must arrive as a genuine second tier; the two gates must now agree)
  rather than deleted, with `provider`/`lv`/`missing` refusals added alongside the surviving
  `structured` one.

## 9. What Did Not Go Smoothly

1. **This report is late.** PR #907 merged without it. The Stage 6 agent flagged that an after-task
   report was outside its brief; the orchestrator did not pick that up before opening the PR. The
   Definition of Done requires one per phase and says skipping silently is a hard violation — so
   this is recorded as a violation, not backdated.
2. **The `diag(psi)` claim in Design 108 was under-specified.** "Stage 6 delivers `diag(psi)`" is
   true, but it is **one abstraction and two code paths**. Recon caught this before implementation;
   had it not, the dense path would have passed every test at 7.25× the cost.
3. **R3 was scoped as new work when it already existed.** The `random = NULL` architecture was
   diagnosed on 2026-07-27 (`docs/dev-log/recovered/2026-07-27-va-speed-arc-plan.md`, "R3"), with
   the outer-count collapse, the block-diagonal inner solve, and the memory wall at n≈5000 all
   named. The orchestrator called it "unscoped" before a brain query found the plan. **An
   `ask-brain` before the analysis, not after, would have saved the re-derivation.**
4. **The Stage 9 analysis that motivated R3 was itself wrong first.** Its initial verdict was
   MARGINAL, from an extrapolation that omitted the Ψ tier — the largest parameter block in the
   model. The adversarial pass overturned it to BLOCKING and moved peak memory ~40×. A confident
   "high"-rated analysis was load-bearingly wrong; the adversary is why it did not propagate.
5. **The whole-package sweep was launched before the last three edits** and its result was not
   claimed. The blast-radius re-run against current code is what the pass counts above rest on.

## 10. Known Residuals

- **SEs under `profile=` are untested.** The single reason the flag is opt-in. Arc plan §6.2.
- **Multi-tier SEs fail closed** (`va_multi_tier_fixed_information_unsupported`). Stage 14 owns it.
- **Standalone diagonal-only models** (`indep()` with no `latent()`) are not expressible — tier 0 is
  pinned dense. A one-invariant change, but the `q >= 1` bookkeeping in `.va_r3_infer_dims` and the
  `q <= 6` guard hang off it.
- **Profile is worse below N≈1500.** Its memory is TMB's random-effect tape (~7× the joint tape,
  exponent 1.045), not the optimiser (~35 MB, flat). **That 7× constant is the next thing to attack
  if 10,000 units must fit in less than ~1.7 GB.**
- **At default controls neither route reaches the 1e-4 health tolerance** (profile 2.05e-4, joint
  5.95e-4). That is the arc plan's H5 reproduced, not caused by R3. The 1e-4 claim rests on
  hard-driven convergence and is stated that way.
- **`g_out_p == L3_profile` exactly** — the envelope identity holds, so L3 *is* the profile route's
  own reported gradient. Tightening the inner solve to 1e-14 moved L3 by <25%, so the residual is
  outer-optimiser slop.
- **One nbinom2 N=60 cell returns `false convergence (8)` on BOTH routes** — a flat `log_phi` ridge
  in a weakly-identified fixture. Joint-vs-joint across starts differs by 3.05 there, the same
  magnitude as the profile-vs-joint discrepancy: the model's own ridge, not an R3 artefact.
- **No recovery claim.** A Poisson smoke (N=60, T=6, q=2 + psi) converged the tier machinery but
  collapsed 4 of 6 Ψ SDs toward zero — expected identifiability at that size, and exactly why the
  fence stays shut. Recovery is Stage 8.
- Wall-clock ratios are single-seed and indicative; the **RSS law** (5–6 point ladder) is robust.

## 11. Team Learning

**Emmy** — the packing decision was the whole arc. Choosing flattened-with-offsets over a slot cap,
and then making the within-tier order literally `as.vector()` of the old matrix, converted "K=1
should still work" from a test into an identity. Watch for: a refactor that preserves *behaviour*
where it could have preserved *representation* — the latter is checkable, the former is only
sampleable.

**Gauss** — R3's result inverts the usual expectation: the cheaper route is also the *better
converged* one. The joint route failed its own stationarity test in 4 of 12 cells. Watch for:
treating the incumbent as the reference. Measuring the baseline against the same test is what turned
"is the new route good enough" into "the new route is better", and it cost one extra experiment.

**Noether** — Proposition 2 is a proof about the *optimum*, and an implementation can satisfy the
optimum while missing the saving entirely. The distinction between "converges to diagonal" and
"allocates diagonal" is invisible in results and decisive in cost. Watch for: any proposition whose
benefit is opt-in by construction.

**Fisher** — the Stage 9 analysis was rated "high" confidence and was wrong in its load-bearing
term. It omitted the largest parameter block. The adversarial pass is the only reason it did not
set programme direction. Watch for: an extrapolation that excludes a component on the grounds that
it is "cheap" — check what the design doc says that component costs.

**Rose** — this report is late, and the gap was found by the maintainer asking a question, not by
the process. The Stage 6 agent *did* flag it; the orchestrator dropped it between the agent's report
and the PR. Watch for: a subagent's "not in my scope" note becoming nobody's scope.

**Ada** — the sequencing error worth remembering: R3 was treated as a discovery when a designed plan
for it already existed in the dev-log. `ask-brain` ran *after* the analysis rather than before.
Recall before deriving.

## 12. Cross-Product Coverage

**Cross-cutting flags touched: `engine` (VA R3 template + translation layer), `optimizer`
(outer/inner split), `tier` (a new structural axis).**

**COVERS.** The `engine` and `tier` flags for the VA R3 research prototype: multi-tier accumulation,
the diagonal-tier special case, the tier registry, and both lockstep gates. The `optimizer` flag for
the VA route only, opt-in.

**Does NOT cover** — per surface:

| Surface | Does NOT cover |
|---|---|
| **VA route, user-facing** | Ψ is **not reachable**. The fence still refuses `unique = TRUE`; a test pins it. No export, no `method=`, no public text. |
| **Standard errors** | Does NOT cover SEs under `profile=` (untested) or multi-tier SEs (fail closed). |
| **Recovery / accuracy** | Does NOT cover recovery in any regime. Ψ SDs collapsed on the only smoke fit. Stage 8 owes this. |
| **Phylogenetic tiers** | Does NOT cover them. `structured`/`provider` remain refused — an iid tier is *not* a phylo tier. **Stage 7.** |
| **Shipped Laplace engine** | Untouched. No `random=`/optimizer change on the Laplace path; its behaviour is byte-unchanged. |
| **AGHQ / EVA / VGH engines** | Untouched. `R/va-vgh.R` and `R/eva-proto.R` carry byte-identical `unique`/`psi` refusals that were deliberately **not** lifted. |
| **GLLVM.jl (R↔Julia twin)** | No port owed — nothing became user-facing, so no parity obligation is created. |
| **drmTMB** | No coupling — though note `random = NULL` was **inherited from drmTMB Design 160**, so if that convention is load-bearing there, the same analysis may apply. Not investigated. |
