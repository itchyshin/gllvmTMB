# The A_i collapse — design

**Status:** DESIGN, approved to build (maintainer, 2026-08-03). Nothing implemented yet.
**Lane:** `claude/va-lane2`, worktree `/private/tmp/gllvmtmb-va-lane2`.
**Claim discipline:** the closed form is **published prior art** — see
`21-WHY-GLLVM-IS-FAST.md` §"Prior art on the closed form" and claims-ledger rows 19–21.
Claim **first to implement**, never first to derive.

## 1. What is being changed

Under the Albert–Chib tier the stationarity condition `∂E/∂v ≡ −n/2` makes the variational
covariance data-independent, so the per-unit factor collapses to a single shared matrix:

> `A_i A_iᵀ = (I_q + Σ_j N_ij λ_j λ_jᵀ)⁻¹` — one q×q matrix, identical for every unit.

Confirmed in our engine: per-unit `log_L_diag` identical to 1e-16, matching the predicted
closed form to 2.6e-14, converging back together from jittered starts.

**⚠ Do not borrow gllvm's benefit statement.** An earlier draft of this section said the
collapse "removes ~57% of the outer problem and deletes the entire two-stage diag→unstructured
restart machinery." Both figures are **gllvm's**, from `21-WHY-GLLVM-IS-FAST.md`, and only the
first is even about parameter counts:

- **The 57% is gllvm's parameter share, not ours.** Our outer vector is shaped differently —
  `sum(nm == "m") == N*q + N*T` when the ψ tier is present (`test-va-r3-prototype.R:1236-1238`),
  so at N=100, T=10, q=1 the variational block is ~2,200 of ~2,230 parameters. Our own share
  must be **measured**, not inherited. It is plausibly *larger* than 57%, but only the single
  unstructured tier is covered by the derivation (§2), so the collapsible fraction is smaller
  than the total variational fraction. Until measured, quote no percentage for our engine.
- **We do not have the two-stage restart.** The conditioning audit
  (`va-conditioning-audit-vs-gllvm.md`) found gllvm's diag→unstructured restart is **absent**
  from our R code; porting it was explicitly declined on record
  (`21-WHY-GLLVM-IS-FAST.md:99`). So there is no such machinery here for the collapse to delete.
  Our `.va_r3_fit_warm()` is a restart on a *different* axis (AC→GH bound), and it is untouched
  by this change.

The prize here is therefore the parameter-count reduction on the single unstructured tier, plus
replacing an iterative solve with a closed form — stated in our own terms, once measured.

## 2. 🔴 The constraint that governs the whole design

**The identity is derived and verified for the AC tier only — but the parameters are shared by
every tier.**

`inst/tmb/gllvmTMB_va_r3.cpp:417-419` declares `m`, `log_L_diag`, `L_off` **unconditionally**.
`eval_method` is `DATA_INTEGER` (`:320`) used only for validation (`:559`, `:607-610`) and
inside the family branch (`:891`). It does **not** gate the parameter block.

And the derivation's own scope caveat (`dev/va-speed/ALBERT-CHIB-DERIVATION.md`, §4.1 caveat)
is narrower still:

> constancy across units requires complete data, `n_ij` constant, a pure-probit trait set, and
> the *unstructured single-tier* KL. Missing cells make `A_i` constant only within a missingness
> pattern; varying `n_ij` breaks it; the Stage-7 structured tiers change the KL and the fixed
> point is **UNVERIFIED** there.

**Therefore an unconditional collapse is a correctness bug, not an optimisation.** It would
silently alter the publicly-reachable `integration = "va"` route, which uses only `"jj"`/`"gh"`
— tiers for which this identity has never been derived. The failure would be quiet: a fit that
returns, converges, and is wrong.

**Design rule: the collapse is GATED, never global.** It activates only when *all* hold:

| # | condition | how it is checked |
|---|---|---|
| 1 | `eval_method == 2` (Albert–Chib) | `DATA_INTEGER(eval_method)`, already validated `:559` |
| 2 | every row binomial-probit (family code 4) | already enforced for AC at `:609-610` — reuse, do not duplicate |
| 3 | complete data (no masked cells) | the existing row-mask; must be *added* to the gate |
| 4 | `n_ij` constant across cells | must be *added* to the gate |
| 5 | single unstructured tier (K = 1) | tier layout; Stage-7 structured tiers are UNVERIFIED |

Fail any one → fall back to the existing per-unit block. The fallback must be the default, so
that a condition nobody thought of lands on the safe side.

## 3. What `profile_variational=TRUE` already does — and why it is not this

It is easy to mistake the existing switch for a partial version of this feature. It is not.

`R/va-r3-proto.R:1977-1985` hands the *whole* per-unit block
(`.va_r3_variational_names = c("m","log_L_diag","L_off")`, `:1835`) to TMB's **generic
`profile=`** machinery — an ordinary Newton inner-solve over the stacked vector, with the
Laplace log-det correction disabled (`:1968-1976`).

`tests/testthat/test-va-r3-profile.R:79-96` proves what that costs: the inner Hessian is
block-diagonal and **linear in N** — `nnz` doubles exactly when N doubles.

So `profile_variational` moves the block **outer → inner**. It does not reduce how many
variational-covariance numbers exist. The collapse does: N blocks → 1. They compose (one could
profile the single shared block), but one is not a step toward the other.

## 4. Blast radius

Contained. Repo-wide, `log_L_diag`/`L_off` appear in **no R file except `R/va-r3-proto.R`**.

**Two source files change:**
- `inst/tmb/gllvmTMB_va_r3.cpp` — size checks (`:540-544`), the KL loop (`:749-781`), and the
  `v = λ_tᵀ A_i λ_t` projection (`:844-861`).
- `R/va-r3-proto.R` — seven internal functions: `.va_r3_unpack_variational_chol` (`:72-95`,
  hard-`stop()`s on length), `.va_r3_default_parameters` (`:1035-1128`, sizes at `:1085-1092`),
  `.va_r3_make_objective`'s length validation (`:1881-1890`), `.va_r3_variational_index_map`
  (`:1525-1548`), `.va_r3_hessian_blocks` / `.va_r3_fixed_information_blocked` (`:1564-1676`),
  `.va_r3_infer_dims` / `.va_r3_fixed_information` (`:1702-1801`), `.va_r3_latent_posterior`
  (`:1397-1434`).

**Nothing on the shipped surface changes.** No `sdreport`, `extract_Sigma()`, `predict()`, or
`ranef()` path reads these names; the `gllvmTMB_va` class is deliberately disjoint
(`R/va-routing.R:413-416`) and registers no `predict`/`ranef`/`extract_Sigma` method.

**Two structural hazards inside that radius:**
- `.va_r3_hessian_blocks` rests on *"units are conditionally independent given the fixed
  parameters, so H_vv is EXACTLY block diagonal — N blocks"* (`:1554-1558`). A shared block
  breaks that assumption **structurally**, not merely in size. This is the hardest part of the change.
  **And it is not only a speed structure.** The honest-SE scoping slice
  (`honest-variance-component-ses.md`) found that `.va_r3_fixed_information_blocked()` — built on
  exactly this block-diagonal Schur complement — is *mathematically equivalent to Linear Response
  VB*, already implemented and unit-tested behind `calibrated = FALSE`. It is the most advanced
  piece of the "VA with honest variance-component SEs" story, which is the other half of what
  would make this the best VA implementation available. **So the collapse and the SE work meet
  here, and the collapse is the one that can damage the other.** Sequence accordingly: do not
  break the blocked-information route before its LRVB-equivalence has been validated, or the
  speed win is paid for with the differentiator.
- `.va_r3_infer_dims` recovers N and q *from* `sum(par_names == "m")` / `"L_off"` assuming both
  scale with N (`:1695-1711`). A collapsed `L_off` would **silently mis-infer** N and q rather
  than erroring. Must be made to fail loudly.

## 5. Tests

Eleven test files reference `va_r3`. Two carry literal per-unit shape assertions that will
break and must be updated deliberately, not deleted:
- `test-va-r3-prototype.R:1236-1238`, `:1300-1304` (`sum(nm=="log_L_diag") == N*q + N*T`),
  `:1352-1355` (tier-offset arithmetic), `:1315-1317` (`kl_by_unit == kl_by_level` at K=1).
- `test-va-r3-profile.R:79-96` (nnz linear in N).

A third, `test-va-r3-structured-phylo.R`, carries per-unit block-diagonal *narrative* around the
SE machinery and should be reviewed even though no literal assertion was found.

**New tests required:**
1. **The gate holds** — each of the five conditions in §2, individually violated, falls back to
   the per-unit block. This is the test that protects the publicly-reachable routes.
2. **Equivalence** — under the gate, collapsed and per-unit fits reach the same optimum to
   4–5 s.f. on the same data.
3. **`n_ij` non-constant** is the one condition most likely to be met accidentally in real data;
   give it its own test.

## 6. Definition of done

- Same optimum to 4–5 s.f. against the per-unit route, same data.
- ψ still recovered at `n_trials = 6` (the regime where AC alone collapses it — claim 13).
- `rel_frob ≤ 0.298` — the accuracy gate, which is a constraint, not a trade.
- 245 existing VA tests green.
- Speed result quoted **only** from a quiet machine, with per-arm load recorded.
- The result lands in `20-CLAIMS-LEDGER.md` **with its regime stated**, or it is not a claim.

## 7. Deliberately out of scope

- The publicly-reachable `"gh"`/`"jj"` tiers. The identity is not derived there.
- Stage-7 structured tiers — the KL differs and the fixed point is UNVERIFIED.
- Promotion of any kind. `default_tier` stays `"gh"`; the integration fence stays shut; AC must
  never become a default (claim 13, STANDS).

## 8. A consequence worth carrying to the SE work

The derivation states it directly: *"Any interval, coverage, or `latent_uncertainty` claim built
on VA-AC posterior SDs is on far weaker ground than the same claim under GH. This must be stated
wherever the AC tier's output is surfaced."* If the variational covariance is structurally
data-independent, per-unit variational SDs carry **no per-unit information** — the collapse does
not cause this, it makes it undeniable. Feeds `honest-variance-component-ses.md`.
