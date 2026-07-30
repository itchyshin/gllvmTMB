# VGH Phase 4 — public EDA/diagnostic surface: design and sign-off case

Status: **design only. No package behaviour is claimed or changed by this document.**
No export was added, no `NAMESPACE` line was touched, no `R/` implementation was written.
Scope: whether — and how — the research-only VGH engine (`R/va-vgh.R`) may reach a
reader-facing surface, per `docs/dev-log/2026-07-29-vgh-implementation-plan.md:138-147`.

Provenance markers: **RECORDED** (measured elsewhere in this repo, cited),
**DERIVED** (arithmetic from a recorded number, shown), **AGENT-INFERRED** (my
inference, not measured), **UNVERIFIED** (external, web-sourced).

---

## 1. Recommendation

> **(c) — no public surface. Keep VGH internal, today and until a named gate is passed.**
>
> The gate, and the exact shape of the surface that unlocks if it passes, are specified in
> §5.1 and §7. If the gate passes, the route is **(a) — an opt-in argument on the already
> exported `check_gllvmTMB()`** (`R/diagnose.R:591`), *not* a new export.

**Runner-up: (a).** It lost *today* on missing evidence, not on principle. The single fact
that would promote it is unmeasured: **does a VGH cross-check flag degenerate Laplace fits
that `check_gllvmTMB()`'s existing rows already miss?** Until Phase 3 answers that with a
count, (a) is a request, not a recommendation.

**(b) — one new narrowly-scoped exported function — is eliminated on principle**, not on
evidence. Three independent reasons, any one sufficient:

1. It duplicates an existing exported function's intent. `check_gllvmTMB()` already carries a
   `binomial_prevalence_loading` row (`R/diagnose.R:381-515`) built for exactly the Phase 3
   failure shape — a near-constant binomial trait plus a loading dominant at `>= 8x` typical
   or a fitted probability saturated over `>= 50%` of observations — and it fires
   *independently* of `convergence` and `pdHess`, which is precisely the gap Phase 3 targets.
   A second public entry point for the same question is a worse package, not a better one.
2. It would be the **first** breach of a sealed, uniformly-held convention. Every VA/EVA/VGH
   engine in this repo is fully unexported: `R/va-vgh.R`, `R/va-r3-proto.R`, `R/eva-proto.R`,
   `R/approximation-engine.R` have no roxygen export tags and no `NAMESPACE` entry, and
   `R/va-vgh.R:3-8` states the reason in the file header — the engine is kept separate from
   `fit_multi()` "so that it cannot become an accidental user-facing fitting route."
   A new export makes that header false.
3. A new export is unambiguously the high-risk category under `CLAUDE.md:260-268`, so it
   costs a maintainer decision. Route (a) costs the same decision but buys a strictly smaller
   change (§5.2), so (b) pays more for less.

**Why the honest answer is (c) and not (a) today.** Phase 4's own precondition is not met.
The plan reads *"Phase 4 — EDA surface (2–3 days, OPTIONAL, only if 1–3 land)"*
(`docs/dev-log/2026-07-29-vgh-implementation-plan.md:138`). Phase 3 is running in a separate
lane and has not landed. Worse, the *rationale* Phase 4 was originally scoped against no
longer exists: Phase 2 established that VGH warm-starting does **not** speed Laplace up
(§6), so the only surviving argument for any VGH surface is the Phase 3 diagnostic — and the
diagnostic's incremental value over `check_gllvmTMB()`'s existing rows has never been
measured. Recommending a public API on an unmeasured increment is exactly the failure mode
the fences in `2026-07-29-vgh-implementation-plan.md:143-147` exist to prevent.

**This is not a stall.** §4 specifies the surface completely, so that if the gate passes
nobody redesigns from scratch; and §5.1 states the gate as a number Phase 3 can report.

---

## 2. What may be exposed, item by item

Each item names the fence that *permits* it. Everything here is computable from quantities
already built internally — see the note at the end of this section.

| # | Exposed item | Rotation-invariant? | Permitting fence |
|---|---|---|---|
| 1 | A **status verdict** for the cross-check: `PASS` / `WARN` / `FAIL` on the existing three-level status contract (`R/diagnose.R:581-583`) | n/a (a flag) | Not a `logLik`, `AIC`, `BIC`, `LRT`, profile, or model weight, so untouched by Design 85 §10's prohibition at `docs/design/85-highdim-nongaussian-va-formal-contract.md:325-326`. It is a diagnostic label, the same kind every existing row already returns. |
| 2 | **`g_rel_frob`** — the relative Frobenius discrepancy between the two fits' `G = Lambda Lambda'`, i.e. `\|G_laplace - G_vgh\|_F / \|G_vgh\|_F`, dimensionless and unsquared | **Yes, exactly.** `(Lambda Q)(Lambda Q)' = Lambda Q Q' Lambda' = G` for any orthogonal `Q` | The rotation convention (sister-repo `HSquared.jl docs/dev-log/decisions/2026-06-19-fa-rotation-convention.md`), and this repo's own statement of it at `R/vgh-verify.R:9-26`: raw `Lambda` "is the one thing that must NEVER be used", `G` "absorbs any orthogonal `Q` exactly". |
| 3 | **Eigenvalues of `G`** from each fit, and their max absolute difference (`g_eigen_max_absdiff`), in squared-loading units | **Yes** | Same. Eigenvalues of `G` are invariant to `Lambda -> Lambda Q`. |
| 4 | **Per-trait variances `diag(G)`** (the shared-variance/communality part), and the worst per-trait ratio `max_t diag(G_laplace)_t / diag(G_vgh)_t` | **Yes** | Same. `diag(G)` is the diagonal of a rotation-invariant matrix. This is the item that actually catches the recorded failure — see the arithmetic below. |
| 5 | A **plain-language message and action string**, on the existing row contract's `message` / `action` columns | n/a | Fence *"no internal register codes on any reader-facing surface"* (`2026-07-29-vgh-implementation-plan.md:147`) is satisfied by construction: prose only, no register identifiers, no `objective_type` string, no internal field names. |
| 6 | The **word "Heywood case" / "improper solution"** in that message | n/a | External, established vocabulary (Heywood 1931; generalised to any exponential-family latent-variable model by PMC11675695 — **UNVERIFIED**, web-sourced). Using the field's own term is the opposite of an internal register code, and stops the package inventing terminology for a 90-year-old pathology. |
| 7 | An honest **"cross-check unavailable"** `WARN` when the fit's family or structure lies outside VGH's supported set (VGH structurally excludes delta/hurdle/zero-inflated and multinomial, and spatial/SPDE — `2026-07-29-vgh-implementation-plan.md:162-165`) | n/a | Honest-stamping convention: `R/va-vgh.R:607-608` (`research_only = TRUE`, `model_selection_comparable = FALSE`), `R/eva-proto.R:190`, `R/approximation-engine.R:36,124`, and Design 85's own requirement of honest labelling at `85-...md:345-352`. Silence would misrepresent coverage. |

**Why `diag(G)` is the load-bearing item.** The recorded Phase 3 failure is one species'
loading running to `-119.9` against true loadings of `~0.1-1.5`. **DERIVED:** at `q = 2`,
that trait's `diag(G)` is at least `119.9^2 ~= 1.44e4`, against `~0.01` to `~4.5` for a
healthy trait — a ratio of order `10^3` to `10^6`. So the pathology is fully visible in a
rotation-invariant functional; no raw-loading report is needed to see it, which is what makes
a fence-compliant surface possible at all. Phase 3's own headline metric already lives in
this class: relative Frobenius error on `Sigma_B`, and `Sigma_B = Lambda Lambda' + Psi`
(`R/extractors.R:8`) is a rotation-invariant functional of `G` plus a diagonal.

**No new mathematics is required.** `R/vgh-verify.R:133-160,205-300` already computes
`g_rel_frob`, `g_eigen_cold`, `g_eigen_warm`, and `g_eigen_max_absdiff` from `G`, with a
units note at `R/vgh-verify.R:28-39` recording that trace-scale ratios are the square of
Frobenius-scale ratios (a confusion this project has hit before). Phase 4 adds a *decision
rule* and a *reader-facing row*, nothing else. `diag(G)` (item 4) is the only quantity in
the table not already computed there.

---

## 3. What must NOT be exposed

### 3.1 Quoted verbatim from the plan (`2026-07-29-vgh-implementation-plan.md:143-147`)

> Fences, non-negotiable:
> * **no `logLik` / `AIC` / `BIC`** — the ELBO is a bound, not a likelihood, and
>   Design 85 §10 prohibits selecting rank `q` by ELBO;
> * **no intervals** — nothing in gllvmTMB has certified coverage;
> * no internal register codes on any reader-facing surface.

### 3.2 Quoted verbatim from Design 85 §10 (`docs/design/85-highdim-nongaussian-va-formal-contract.md:319-352`)

> ## 10. Prohibited interpretations and outputs
>
> The following language or behaviour is prohibited:
>
> - calling `L_H` a marginal log-likelihood, exact likelihood, restricted
>   likelihood, REML, AI-REML, Cox--Reid adjustment, or AGHQ;
> - computing or exposing `logLik`, AIC, BIC, LRT, likelihood-ratio profile, or
>   model weights from the ELBO;
> - selecting `q` by maximised ELBO or comparing ELBO values across ranks as if
>   they shared an equal approximation gap;
> - describing a smaller negative ELBO as better marginal fit than a Laplace or
>   AGHQ objective;
> - interpreting the inverse VA Hessian as calibrated frequentist uncertainty;
> - treating variational `m_i` or `S_i` as model parameters, true latent scores,
>   or repeated-sampling uncertainty for `u_i`;
> - claiming variance-component, interval, coverage, rank-selection, or
>   high-dimensional accuracy from optimizer convergence alone;
> - folding a diagonal `Psi`, logistic `pi^2/3`, overdispersion term, or
>   observation-level random effect into `Sigma_B`;
> - widening to Bernoulli, incomplete responses, mixed families, alternative
>   links, structured sources, random slopes, or public syntax by analogy; or
> - using this research prototype to weaken the project's Gaussian-only REML
>   boundary.

and

> It must not inherit class `gllvmTMB_multi` or methods that imply marginal likelihood.
> (`85-...md:351-352`)

### 3.3 The prohibition list, applied

| Forbidden on this surface | Fence |
|---|---|
| `logLik`, `AIC`, `BIC`, `AICc`, `LRT`, likelihood-ratio profile, model weights, or any of these computed *from* the ELBO | `85-...md:325-326`; plan `:144` |
| Any comparison of ELBO values across ranks `q`, or any rank suggestion | `85-...md:327-328`; plan `:144-145` |
| Calling the ELBO a likelihood of any kind (marginal, exact, restricted, REML, AI-REML, Cox–Reid, AGHQ) | `85-...md:323-324` |
| Framing a smaller negative ELBO as better fit than the Laplace objective | `85-...md:329-330` |
| **The raw ELBO number itself, anywhere in the returned object.** Beyond the literal fence: printing it invites exactly the cross-rank comparison `85-...md:327-330` forbids, and it answers no reader question. `elbo`, `elbo_path`, `accelerations`, `sweeps`, `objective_type` (`R/va-vgh.R:599-606`) all stay internal. | `85-...md:327-330` (design choice, stricter than the minimum) |
| Any interval, standard error, or confidence statement — including anything derived from the VA Hessian or `S_i` | `85-...md:331-333`; plan `:146` |
| Any coverage claim, and any accuracy claim resting on optimizer convergence | `85-...md:334-335` |
| **Raw `Lambda`, VGH latent scores (`amean`), or `Svec`** — as an estimate, a plot, a table, or a biological axis | Rotation convention (`R/vgh-verify.R:9-26`); `85-...md:332-333` (`m_i`/`S_i` are not latent scores) |
| A `Sigma_B` that folds `Psi`, a logistic `pi^2/3`, an overdispersion term, or an observation-level random effect into it | `85-...md:336-337` |
| Internal register codes, `research_only`/`objective_type` strings, engine field names, or the `vgh_fit` object itself reaching the reader | plan `:147` |
| Any class inheriting `gllvmTMB_multi`, or an S3 method implying a marginal likelihood | `85-...md:351-352` |
| **Any speed claim** — see §6 | Phase 2 result (`docs/dev-log/2026-07-29-vgh-phase2-warmstart-result.md:249,259,266`) |
| Any widening of family/structure/public syntax "by analogy" from what the cross-check actually covers | `85-...md:338-339` |
| Presenting VGH as an alternative *estimator*, a fitting route, or a competitor to `fit_multi()` | `R/va-vgh.R:3-8`; `85-...md:340-343` |

---

## 4. Specification (route (a), for a future implementer, if and only if §5.1's gate passes)

This is a specification, not code. Nothing here should be implemented before sign-off.

### 4.1 Public signature — an additive, default-inert extension of one existing export

```
check_gllvmTMB(
  object,
  gradient_thresh                 = 1e-2,     # existing, unchanged
  se_thresh                       = 100,      # existing, unchanged
  weak_axis_thresh                = 0.05,     # existing, unchanged
  psi_thresh                      = 1e-4,     # existing, unchanged
  psi_rel_thresh                  = 1e-3,     # existing, unchanged
  sigma_eps_thresh                = 1e-4,     # existing, unchanged
  cross_loading_thresh            = 0.6,      # existing, unchanged
  binary_prevalence_thresh        = 0.9,      # existing, unchanged
  binary_saturation_prob_thresh   = 0.99,     # existing, unchanged
  binary_saturation_share_thresh  = 0.5,      # existing, unchanged
  loading_relative_thresh         = 8,        # existing, unchanged
  # --- new, appended, all defaulting to inert ---
  loading_crosscheck              = FALSE,
  crosscheck_g_rel_warn           = <set by the Phase 3 sweep, §5.1>,
  crosscheck_g_rel_fail           = <set by the Phase 3 sweep, §5.1>,
  crosscheck_trait_var_ratio_warn = <set by the Phase 3 sweep, §5.1>,
  crosscheck_trait_var_ratio_fail = <set by the Phase 3 sweep, §5.1>,
  crosscheck_seed                 = NULL
)
```

Design commitments in that signature, each one deliberate:

* **`loading_crosscheck = FALSE` by default.** With the default, behaviour, cost, row set,
  and failure modes of `check_gllvmTMB()` are bit-identical to today. This is what makes the
  change the weakest possible form of "API change" (§5.2).
* **New arguments appended after all existing ones**, so no positional call breaks.
* **No new exported function, and no new exported `*_control()` helper.** A
  `crosscheck_control()` would itself be a new export and would forfeit route (a)'s only
  advantage over (b). Thresholds are plain arguments.
* **Thresholds are left blank on purpose.** They must be *calibrated from Phase 3's sweep*,
  not guessed here. A guessed threshold on a diagnostic is how a false-positive rate gets
  shipped silently.
* **Documented cost.** The roxygen block must state, in the argument description, that
  `loading_crosscheck = TRUE` **runs a second model fit** and is therefore not free. This is
  a materially different cost profile from every other row, all of which read stored fields
  off `object`.
* **Experimental badge.** `` `r lifecycle::badge("experimental")` `` on the new argument's
  documentation, matching the existing precedent at `R/bootstrap-lv-effects.R:17` and
  `R/profile-derived.R:1331`.

### 4.2 Return contract

Unchanged in class and columns: a data frame with `component`, `status`, `value`,
`threshold`, `message`, `action`, and `status` in `{"PASS","WARN","FAIL"}`
(`R/diagnose.R:581-583`).

* With `loading_crosscheck = FALSE`: **zero** additional rows. Byte-identical to today.
* With `loading_crosscheck = TRUE`: **at most three** additional rows, appended last —

| `component` | `value` | `threshold` | Status rule |
|---|---|---|---|
| `loading_crosscheck` | `NA_real_` | `NA` | `PASS` if both metric rows pass; `WARN` if either warns or the cross-check could not run; `FAIL` if either fails |
| `loading_crosscheck_G_discrepancy` | `g_rel_frob`, dimensionless, unsquared (`R/vgh-verify.R:32-34`) | `crosscheck_g_rel_warn` | `PASS` / `WARN` / `FAIL` against the two thresholds |
| `loading_crosscheck_trait_variance` | `max_t diag(G_laplace)_t / diag(G_vgh)_t` | `crosscheck_trait_var_ratio_warn` | `PASS` / `WARN` / `FAIL` against the two thresholds |

* **The three-level status contract is not extended.** A `"SKIP"` or `"NA"` status would
  change the documented return contract for every existing caller and every existing row —
  a real API change on top of an additive one. Unsupported family, unsupported structure, a
  cross-check fit that fails to converge, and a missing loading tier all resolve to a single
  `WARN` row whose `message` says plainly which of those happened and that the loading scale
  was therefore **not** corroborated. Absence of evidence is reported as absence of evidence,
  never as a `PASS`.
* **`message` / `action` are prose only.** No register codes, no `research_only`, no
  `objective_type`, no `elbo`, no internal field names, no engine name in code form
  (`2026-07-29-vgh-implementation-plan.md:147`).
* **No `Lambda`, no scores, no `S_i`, no ELBO, no interval, no `q` suggestion** appears in
  any column (§3.3).

### 4.3 Internal worker (not exported, no roxygen export tag)

```
.gllvmTMB_loading_crosscheck(object, seed = NULL, ...)
  -> list(available, reason, g_rel_frob, g_eigen_max_absdiff,
          trait_var_ratio_max, trait_var_ratio_which, crosscheck_converged)
```

Naming and non-export match the existing internal convention (`.gllvmTMB_check_row`,
`.gllvmTMB_build_fit_health`, `.gllvmTMB_hessian_rank`, all in `R/diagnose.R`). It should
reuse `.vgh_tier_g_stats()` (`R/vgh-verify.R:133`) for `g_rel_frob` and the `G` eigenvalues
rather than reimplementing them, and it must **not** return the `vgh_fit` object, its
`elbo`, or its `elbo_path` to its caller. **AGENT-INFERRED:** reuse is possible from the
signature at `R/vgh-verify.R:133`; I have not attempted it.

### 4.4 The rejected alternative, specified for comparison only

Route (b) would have been, roughly:

```
screen_loading_degeneracy(fit, seed = NULL, ...)  ->  <new S3 class>
```

with a `print()` method. It loses for the three reasons in §1: intent-duplication with
`check_gllvmTMB()`, first breach of the sealed no-export convention, and identical
sign-off cost for a strictly larger change. **Do not implement this.** It is recorded here
only so the comparison is not re-litigated from memory.

---

## 5. Sign-off case

### 5.0 A correction to the plan's own citation, first

The plan says Phase 4 *"[n]eeds maintainer sign-off: a new public route is a high-risk change
under `ROADMAP.md`'s discussion-checkpoint list"*
(`docs/dev-log/2026-07-29-vgh-implementation-plan.md:140-141`).

**There is no such heading in `ROADMAP.md`.** `grep -i "discussion.checkpoint" ROADMAP.md`
returns nothing. This dangling reference has been flagged at least three times and never
fixed: `docs/dev-log/2026-06-19-claude-overnight-briefing.md:195-196`,
`docs/dev-log/check-log.md:33270-33271`, and
`docs/dev-log/recovery-checkpoints/2026-06-19-184500-claude-overnight-finish-checkpoint.md:85`.
`CLAUDE.md:266-268` inherits the same broken pointer.

The substantive rule is real and lives in four places that agree; this section is grounded in
those, not in a heading that does not exist. **This document does not fix the dangling
reference** — that is an edit to `CLAUDE.md`/`ROADMAP.md`, outside a design-only lane.

| Source | The rule |
|---|---|
| `CLAUDE.md:237-241` | "Stop for maintainer discussion before deletions, API changes, formula grammar changes, likelihood changes, new families, or broad article rewrites." |
| `CLAUDE.md:260-268` | High-risk changes — including API changes and deletions of public exports — "the agent must ask the maintainer before merging." Not a self-merge category. |
| `docs/dev-log/decisions.md:111-126` | The 2026-05-11 decision that originated the checkpoint rule, same list. |
| `ROADMAP.md:184-186` | "If a branch changes formula grammar, likelihoods, exported APIs, generated Rd, `_pkgdown.yml`, or validation-debt status, stop and widen the reviewer set before continuing." |

### 5.1 The gate that must pass before route (a) may be implemented

This is the checklist item the design **cannot** satisfy from here, and the reason the
recommendation is (c). Phase 3 must report, from its own recorded sweep, all four:

1. **Incremental catch count.** Of the degenerate Laplace fits Phase 3 identifies, how many
   does `check_gllvmTMB()` at default thresholds report as all-`PASS` on every
   loading-relevant row — `binomial_prevalence_loading`, `near_zero_psi_<level>`,
   `weak_axis_<level>`, `cross_loading_structure_<level>`, `boundary_flags`
   (`R/diagnose.R:381-515` and the row set surveyed at `R/diagnose.R:591-923`) — while a
   VGH cross-check flags them? **If that count is zero, recommendation (c) becomes
   permanent and this document's §4 should never be implemented.**
2. **False-positive rate.** On healthy fits, how often does the cross-check flag? A screen
   with an unmeasured false-positive rate must not become a public row.
3. **Calibrated thresholds.** Concrete numbers for the four `crosscheck_*` thresholds in
   §4.1, derived from (1) and (2), not guessed.
4. **Coverage statement.** Which families and structures the cross-check actually covers,
   and therefore what the `WARN`-unavailable row in §4.2 will say for the rest
   (`85-...md:338-339` forbids widening by analogy).

**RECORDED context, not a substitute for the above:** the incumbent's two logged failures are
*"8 of 20 Laplace fits (40%) diverged to a degenerate loading — off by 2–5 orders of
magnitude — while reporting a clean convergence code and `pdHess = TRUE`"* and *"59 of 70
degenerate Laplace fits reported `convergence = 0` across the 640-cell sweep"*
(`docs/dev-log/2026-07-29-vgh-implementation-plan.md:126-131`). Those establish that
`convergence`/`pdHess` are uninformative here. They do **not** establish that
`binomial_prevalence_loading` is uninformative here — nobody has run it against those cases.
That is the whole of the missing evidence.

### 5.2 Checklist walk

| Requirement | Source | Status under this design |
|---|---|---|
| Explicit maintainer sign-off before merge, and (per the plan's framing) before implementation | `CLAUDE.md:260-268`; `decisions.md:111-126` | **SATISFIED by construction.** This lane wrote no `R/` code and no `NAMESPACE` line. §7 states the decision as a single question. |
| Stop for discussion before an API change | `CLAUDE.md:237-241` | **SATISFIED.** Design-only; nothing changed. Note honestly: adding an argument to an exported function *is* an API change, so route (a) needs the same discussion as (b) — it is just a much smaller change (additive, appended, default-inert, no new export, return contract and status levels unchanged). |
| Widen the reviewer set if the branch changes exported APIs, generated `Rd`, `_pkgdown.yml`, or validation-debt status | `ROADMAP.md:184-186` | **SATISFIED today** (this branch changes none of them). **Flagged for implementation:** route (a) changes an exported API and regenerates one `Rd`, so it independently trips this rule and needs the wider reviewer set — not a self-merge. |
| No `logLik` / `AIC` / `BIC` / `LRT` / model weights from the ELBO | plan `:144`; `85-...md:325-326` | **SATISFIED.** §3.3. The surface returns a status and two rotation-invariant discrepancy scalars; no objective value of any kind, and the raw ELBO is excluded outright. |
| No selecting or comparing rank `q` by ELBO | plan `:144-145`; `85-...md:327-328` | **SATISFIED.** Both fits are at the *same* fixed `q`, taken from `object`. Nothing in the return varies `q` or ranks anything. |
| Never call the ELBO a likelihood | `85-...md:323-324` | **SATISFIED.** The ELBO does not appear on the surface, so no name for it appears either. |
| No intervals; no calibrated-uncertainty claim from the VA Hessian or `S_i` | plan `:146`; `85-...md:331-333` | **SATISFIED.** §3.3. No SE, no CI, no `S_i`, no `Svec` in any column. |
| No coverage claim; no accuracy claim from convergence alone | `85-...md:334-335` | **SATISFIED.** §6 states the non-claim explicitly, and the cross-check fit's own convergence appears only as a reason a row could not be produced, never as evidence of accuracy. |
| No internal register codes on a reader-facing surface | plan `:147` | **SATISFIED.** §4.2: prose-only `message`/`action`, no `research_only`, no `objective_type`, no engine field names. |
| No speed claim anywhere | Phase 2 result, `docs/dev-log/2026-07-29-vgh-phase2-warmstart-result.md:249,259,266` | **SATISFIED.** §6 states the `1.25x` ceiling and the `IMPOSSIBLE` verdict. No document, roxygen block, example, or message produced by this design may claim a speed benefit. Route (a) is in fact *slower*: it runs a second fit. |
| Honest stamping if a result object is built (`research_only = TRUE`, `objective_type = "ELBO_GH"`, honest `rank_source`) | `85-...md:345-352`; `R/va-vgh.R:607-608`; `R/eva-proto.R:190`; `R/approximation-engine.R:36,124` | **SATISFIED, and stronger.** No new result object is built at all. The internal `vgh_fit` keeps its existing stamps (`R/va-vgh.R:606-608`) and never leaves the internal worker (§4.3). `rank_source` is moot: `q` is inherited from `object`, never selected. |
| Must not inherit class `gllvmTMB_multi`, or any method implying marginal likelihood | `85-...md:351-352` | **SATISFIED.** No new class. The return is the same plain data frame `check_gllvmTMB()` already returns; no S3 method is added anywhere. |
| Report only rotation-invariant functionals of `G`; never raw `Lambda` as an identified axis | rotation convention; `R/vgh-verify.R:9-26` | **SATISFIED.** §2: every exposed numeric is `g_rel_frob`, a `G` eigenvalue quantity, or `diag(G)`. §3.3 forbids raw `Lambda` and scores outright. |
| `lifecycle::badge("experimental")` if exported | `R/bootstrap-lv-effects.R:17`; `R/profile-derived.R:1331` | **SPECIFIED** (§4.1). Nothing is exported, so the badge attaches to the new argument's documentation on an already-exported function. |
| Flag explicitly that every other VA/EVA prototype stays off `NAMESPACE` | `R/va-vgh.R:1-8`; `R/va-r3-proto.R:3`; `NAMESPACE` (no VA/EVA/VGH export) | **FLAGGED, §1 reason 2**, and it is one of the three reasons (b) was rejected. Route (a) adds **no** export, so the sealed convention survives intact — this is (a)'s central advantage and the main argument for signing it off rather than (b). |
| Touching `_pkgdown.yml`, generated `Rd`, or validation-debt status independently trips the stop rule | `ROADMAP.md:184-186` | **FLAGGED for implementation.** Route (a) regenerates the `check_gllvmTMB` `Rd`. `_pkgdown.yml` needs no change (the function is already listed, `_pkgdown.yml:276`). No validation-debt row is claimed — a diagnostic with an unmeasured false-positive rate must not be entered as debt discharged. |
| Record outcome in an after-task report and `check-log.md` | `CLAUDE.md:243-247` | **OUTSTANDING for this lane.** This document is the design deliverable; the after-task report and check-log entry are the lane's closure step and are not written by this file. |
| Phase 4's own precondition: "only if 1–3 land" | `2026-07-29-vgh-implementation-plan.md:138` | **NOT SATISFIED.** Phase 3 has not landed. This is the primary reason the recommendation is (c) rather than (a). |
| The incremental-value gate (§5.1) | this document | **CANNOT BE SATISFIED FROM HERE.** It requires a measurement only Phase 3 can supply. Flagged, not finessed. |

---

## 6. What this does not do

* **No speed benefit. There is none, and none may be claimed.** Phase 2 measured median
  warm-vs-cold ratios of `0.85x` to `~0.99x`
  (`docs/dev-log/2026-07-29-vgh-phase2-warmstart-result.md:113-123,101`), and derived the
  bound `speedup <= cold_iters / warm_iters` (`:244`). The best observed iteration reduction
  was `20%`, giving a ceiling of **`1.25x` even with a completely free warm start**
  (`:249,259`); the `>= 1.5x` end-to-end target is recorded as **`IMPOSSIBLE`** (`:266`).
  The warm start is kept because it is net-neutral (`:269`), not because it is fast. Route
  (a) is *slower* than not using it: it runs a second fit. Any implementer who writes
  "faster" in an `Rd`, a message, or an example has violated this design.
* **VGH stays `research_only`.** It remains unexported, keeps
  `research_only = TRUE` and `model_selection_comparable = FALSE`
  (`R/va-vgh.R:606-608`), and remains not a fitting route (`R/va-vgh.R:3-8`). Route (a)
  exposes a *verdict about a Laplace fit*, never a VGH fit, never a VGH estimate.
* **No rank selection, and no help choosing `q`.** Both fits sit at the `q` already in
  `object`. Nothing here compares ranks, ranks models, or suggests a rank
  (`85-...md:327-328`).
* **No coverage claim, no interval, no calibrated uncertainty.** Nothing in gllvmTMB has
  certified coverage (plan `:146`), and the VA Hessian is not calibrated frequentist
  uncertainty (`85-...md:331`). A `PASS` row means "a differently-regularised fit
  corroborated the loading scale", nothing more; a `FAIL` row is a *flag*, not a test with a
  size.
* **Not a fix.** The classical remedy for a Heywood case is a boundary constraint
  (**UNVERIFIED**, external literature). This design detects; it does not repair, and it does
  not touch `suggest_lambda_constraint()`.
* **Not a novelty claim beyond its grain.** Heywood cases are 90+ years old and the
  vocabulary must be used, not reinvented. What has no identified precedent — in `gllvm`,
  `boral`, `Hmsc`, `ecoCopula`, `sjSDM`, or the general VA/Heywood literature — is using a
  variational fit's implicit KL-to-prior regularisation as an operational Heywood-case screen
  for a specific Laplace fit inside a GLLVM (**UNVERIFIED**, external prior-art sweep). State
  it at that grain or not at all.
* **Does not fix the dangling `ROADMAP.md` "Discussion Checkpoints" reference** (§5.0), and
  does not touch `NAMESPACE`, `R/fit-multi.R`, `R/gllvmTMB.R`, or the Phase 3 lane.

---

## 7. The decision

> **Is one extra opt-in model fit inside `check_gllvmTMB()` worth paying for the only known
> signal that catches a Laplace loading which both `convergence = 0` and `pdHess = TRUE`
> call healthy — or does VGH stay fully sealed, leaving that failure mode to
> `binomial_prevalence_loading`'s heuristic thresholds?**

**Say yes** and you accept: an API change to an exported diagnostic (additive, appended,
default-`FALSE`, no new export, return contract and status levels unchanged); a documented
second-fit cost whenever the argument is switched on; a public row whose thresholds are only
as good as Phase 3's calibration; and a research-only engine acquiring, for the first time, a
path — however indirect — to a reader-facing surface. You gain a check that fires on a
failure mode the standard GLLVM convergence diagnostics are documented not to cover (the
`gllvm` convergence vignette recommends gradient, Hessian-eigenvalue and profiling checks and
does not discuss degenerate loadings at all — **UNVERIFIED**, external), expressed entirely
in rotation-invariant functionals of `G`.

**Say no** and you keep a strictly simpler package and an unbroken seal: no VA/EVA/VGH code
has any path to a user, `R/va-vgh.R:3-8` stays literally true, and no threshold with an
unmeasured false-positive rate ships. You accept that the failure mode is caught only when
`binomial_prevalence_loading`'s defaults — prevalence `>= 0.9`, dominant loading `>= 8x`,
saturation share `>= 0.5` (`R/diagnose.R:591-604`) — happen to fire, and that non-binomial
degenerate loadings have no dedicated screen at all.

**A third answer is available and is what I would advise:** *decide nothing yet.* Send §5.1's
four numbers back to Phase 3 first. If item 1 comes back zero — every degenerate fit VGH
flags is already flagged by an existing row — the question dissolves and (c) is simply
correct. That measurement is cheap relative to a public API decision, and it is the only
thing standing between this design and a defensible sign-off either way.
