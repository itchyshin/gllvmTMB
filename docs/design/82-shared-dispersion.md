# Design 82 — Shared / grouped negative-binomial dispersion (`disp_group=`)

**Status:** design proposal (2026-07-15). Design half of the flagship nbinom2
fix; **not implemented**. C++/R implementation is a separate, later lane,
blocked on the current in-flight uncommitted diff to `src/gllvmTMB.cpp` and
`R/fit-multi.R` landing first. This document does not modify either file.

**Scope correction up front.** The originating audit
(`docs/dev-log/audits/2026-05-18-cross-package-count-inference-scout.md`,
§3 item 4) and this task's brief both use the name `disp.group=`/`disp_group=`
as if mirroring gllvm. The literature synthesis
(`docs/dev-log/2026-07-13-nbinom2-dispersion-literature.md`, gllvm section)
already flags this: **gllvm's real argument is `disp.formula`** ("a vector of
indices, or alternatively formula, for the grouping of dispersion
parameters... Defaults to `NULL` so that all species have their own
dispersion parameter"); `disp.group` does not appear in gllvm's docs. This
design keeps the name **`disp_group`** as gllvmTMB's own argument (consistent
with gllvmTMB's snake_case convention, e.g. `unit=`, `link_residual=`), and
does **not** claim it mirrors a literal gllvm API name — only the underlying
statistical idea (grouping/pooling dispersion across responses) is shared.

---

## 1. Problem statement

### 1.1 The ridge (literature-grounded)

NB2 and a latent/observation-level log-scale random effect are the same
overdispersion mechanism expressed two ways (NB2 = Poisson–Gamma mixture;
latent RE = Poisson–lognormal mixture). With one observation per unit, the
NB dispersion φ and the random-effect variance ψ are weakly identified —
different (φ, ψ) pairs give near-identical likelihood (Lawless 1987; Bolker's
GLMM FAQ; a Cross Validated thread cited in the literature synthesis calls
NB + OLRE together "a weird construction"). Separately, small-sample NB
dispersion MLEs are documented as **biased toward the Poisson limit**
(Lloyd-Smith 2007, *PLoS ONE*; Gregory & Woolhouse 1993; Saha & Paul 2005,
*Biometrics*) — i.e. φ̂ is inflated, which starves the companion latent
variance of the overdispersion it should be capturing. Full grounding,
citation tiers, and the provenance caveats live in
`docs/dev-log/2026-07-13-nbinom2-dispersion-literature.md`; treat this
section as a summary, not a re-derivation.

### 1.2 The over-parameterisation, concretely

gllvmTMB fits a fully-crossed stacked-trait model: for a `T`-trait fit,
`nbinom2()` estimates **one φ per trait** — `PARAMETER_VECTOR(log_phi_nbinom2)`
is length `n_traits` (`src/gllvmTMB.cpp:615`), indexed per-trait inside the
NB2 log-density block at `src/gllvmTMB.cpp:2047`
(`log_v_minus_mu = 2*log_mu - log_phi_nbinom2(t)`). R-side initialisation
allocates the same length-`n_traits` vector unconditionally
(`R/fit-multi.R:3580`, `.clamp_log_phi(rep(0.0, n_traits))`) and only maps it
off entirely (`factor(rep(NA_integer_, n_traits))`, `R/fit-multi.R:4166`) when
no trait in the fit uses `nbinom2()`. There is currently **no partial
pooling** option between "one φ per trait" (today's default, always on when
any trait is nbinom2) and "fix φ at a known value"
(`dev/m3-grid.R:592-635`, `m3_refit_known_nbinom2_phi()` — see §3.1).

### 1.3 Quantified evidence (the mitigation ladder)

Source: `dev/nbinom2-mitigation-ladder.R`, results in
`dev/nbinom2-mitigation-ladder-results.rds`. Design: `T = 5` traits, `d = 1`
latent dimension, `n ∈ {150, 400, 800}` units, 8 seeds per cell, 3 arms:

- **`default`** — plain fit, 5 independently-estimated φ.
- **`warmstart`** — `init_strategy = "single_trait_warmup"` (gllvm-style
  Poisson-first warm start), still 5 independently-estimated φ.
- **`knownphi`** — post-hoc refit with all 5 `log_phi_nbinom2` entries
  **fixed** at the true (shared) DGP value via `m3_refit_known_nbinom2_phi()`.

The DGP itself draws **one** scalar `phi ~ Gamma(shape, rate)` shared across
all 5 traits (`dev/m3-grid.R:435-437`, `nuisance$phi <- rgamma(1, ...)`) — so
the model is estimating 5 free dispersion parameters against 1 true value, the
over-parameterisation from §1.2 realised directly in the simulation. The
outcome metric is median recovery of `diag(Sigma_hat) / diag(Sigma_true)` at
the unit level (`extract_Sigma(..., level = "unit")`), 1.0 = unbiased:

| n | default | warmstart | knownphi |
|---|---|---|---|
| 150 | 0.519 | 0.522 | 0.776 |
| 400 | 0.459 | 0.423 | 0.811 |
| 800 | 0.495 | 0.495 | 0.839 |

(medians over 8 seeds each; full per-seed table in the `.rds`.)

Reading this: **`default` and `warmstart` are statistically indistinguishable**
— per-seed values match to 3 decimals in almost every row (e.g. n=150 seed 1:
0.4533906 vs 0.4533893), and neither trends toward 1.0 as `n` grows (0.52 →
0.46 → 0.50, flat/noisy, not a bias that shrinks with more data — consistent
with an **identifiability** problem, not a finite-sample one). **`knownphi`
rises with n** (0.78 → 0.81 → 0.84) but **does not reach 1.0 even at n=800** —
fixing φ at the true value removes most, not all, of the bias. This is
consistent with (not proof of) the literature's ridge/small-sample-bias
account: point estimates only, 8 seeds/cell, no CI — **do not oversell this
table**; it motivates the design, it is not a validation of the fix (that is
§4, and is explicitly gated as not-yet-done).

### 1.4 What `knownphi` is not

`knownphi` fixes φ at a value the fitting procedure would never have —
the true DGP parameter. It is a **ceiling probe**, not a candidate fix (a user
cannot supply the truth). The candidate fix this document proposes is
**pooling φ across traits within the model** (shared/grouped, freely
estimated) — the middle ground between "5 independent φ" (today) and "1 φ
fixed at a value nobody has" (`knownphi`). Whether pooling gets close to the
`knownphi` ceiling is an open empirical question (§4), not assumed here.

---

## 2. Proposed grammar / API

### 2.1 Recommendation: a top-level `disp_group=` argument on `gllvmTMB()`, not a `gllvmTMBcontrol()` field

`gllvmTMBcontrol()` (`R/gllvmTMB.R:1009-1050`) holds **engine/optimiser**
knobs — `n_init`, `optimizer`, `optArgs`, `init_jitter`, `init_strategy`,
`start_method`, `se`, `verbose`. Grouping dispersion across traits is a
**model-structure** decision (which nuisance parameters are shared), the same
category as `family=` per trait or the `unit=`/`species=`/`site=` grouping
arguments already on `gllvmTMB()` — not a convergence-tuning switch. gllvm's
own precedent (`disp.formula`) is likewise a top-level model argument, not
inside a control list. Putting it in `gllvmTMBcontrol()` would also be
surprising for anyone porting the gllvm `disp.formula` mental model.

**Rationale in one line:** dispersion grouping changes what the model *is*
(shared vs. per-trait nuisance parameters, hence the effective parameter
count and the likelihood surface), not how the optimiser searches for it —
that puts it with the other model-defining arguments, not `gllvmTMBcontrol()`.

### 2.2 Grammar

```r
gllvmTMB(
  formula, data, family = nbinom2(), unit = "unit",
  disp_group = NULL,   # new
  ...
)
```

- **`disp_group = NULL` (default).** Current behaviour, byte-identical:
  every trait gets its own φ (`group = seq_len(n_traits)`). No behaviour
  change for existing code — this is the backward-compatibility contract.
- **`disp_group = "shared"`** (shorthand). All traits that use a dispersed
  family (nbinom2 first; see §2.3) pool into **one** φ. Mirrors gllvm 2.0's
  documented "set `disp.formula` to a vector of ones... to avoid volatile
  estimation" pattern (literature synthesis, gllvm section).
- **`disp_group = <vector>`.** Length `n_traits`, one group label per trait
  (integer, character, or factor-coercible), in the same trait order as
  `levels(data[[trait]])` for long-format input or the LHS column order for
  `traits(...)`. Traits sharing a label share one estimated φ. This is
  gllvmTMB's version of gllvm's "vector of indices" form of `disp.formula`
  (not the formula form — deferred; see §5).
- **Not supported at this design stage:** `disp_group` as a formula
  (gllvm's `disp.formula` also accepts `~ covariate`-style grouping via
  model-matrix columns). A plain vector covers the flagship use case (pool
  everything, or pool by known trait class) at a fraction of the
  implementation cost; a formula interface is a possible follow-up, not part
  of this proposal.

### 2.3 Family scope

The ladder evidence is **nbinom2-only**. `nbinom1`, `Gamma`, `tweedie`,
`beta`, `betabinomial`, `truncated_nbinom2`, and the delta-family positive
component (`gamma_delta`) all follow the identical
`PARAMETER_VECTOR(log_phi_<family>)`-per-trait pattern
(`src/gllvmTMB.cpp:615-648`) and the identical R-side allocate/map-off
pattern (`R/fit-multi.R:3580` onward, `R/fit-multi.R:4166` onward), so the
**mechanism** generalises trivially. Whether **pooling is statistically
warranted** does not automatically generalise:

- `nbinom1` shares NB2's Poisson-mixture overdispersion logic (same
  Lawless 1987 argument) and is the next most plausible candidate.
- `Gamma`/`tweedie`/`beta`/`betabinomial` dispersion parameters play a
  different role (shape/CV, not a Poisson-mixture overdispersion that
  competes with a latent-variance term), so pooling them may or may not face
  the same ridge — untested.

**Recommendation:** implement the mechanism generically (it costs nothing
extra to make `disp_group` apply to whichever family the fit uses), but
**advertise and validate only nbinom2** until a family-specific ladder exists
for the others. `disp_group` on a non-nbinom2 fit should not error, but
should not be marketed as fixing anything either.

---

## 3. Implementation sketch

Two implementation routes exist at very different cost. Route A is the
recommended default; Route B is documented because the task brief and the
audit anticipated a `DATA_IVECTOR` design and a future lane should know both
options were considered and why one was preferred.

### 3.1 Route A (recommended): TMB `map=` parameter tying — zero `src/gllvmTMB.cpp` diff

TMB's `map=` argument to `MakeADFun()` already supports **tying** parameter
vector entries together by giving them the same factor level, not just fixing
them off with `NA`. This mechanism is **already used** in this exact spot,
just for the all-fixed extreme:

```r
# dev/m3-grid.R:624-632 (existing, "known phi" ceiling probe)
params$log_phi_nbinom2 <- rep(log(phi), length(params$log_phi_nbinom2))
map$log_phi_nbinom2 <- factor(rep(NA_integer_, length(params$log_phi_nbinom2)))
#                              ^^^^^^^^^^^^^^^ every entry NA => every entry FIXED
```

The generalisation to "shared but freely estimated" is: give tied entries
the **same non-`NA` factor level** instead of `NA`. E.g. for `disp_group =
"shared"` with `n_traits = 5`:

```r
tmb_map$log_phi_nbinom2 <- factor(rep(1L, n_traits))   # one estimated level, shared by all 5
```

or, for an arbitrary grouping vector `g` (length `n_traits`, e.g.
`c(1, 1, 2, 2, 2)` to pool traits 1-2 and pool traits 3-5 separately):

```r
tmb_map$log_phi_nbinom2 <- factor(match(g, unique(g)))
```

TMB collapses tied entries to one free parameter internally, optimises it
once, and **fills the full length-`n_traits` `log_phi_nbinom2` vector** with
the shared estimate when reporting. Consequences:

- **`src/gllvmTMB.cpp` needs no change at all** — `PARAMETER_VECTOR
  (log_phi_nbinom2)` (line 615) stays length `n_traits`; the per-trait index
  `log_phi_nbinom2(t)` (line 2047) stays as-is; `REPORT(phi_nbinom2)`
  (line 2529) stays length `n_traits`. Every downstream R consumer
  (`extract_sigma.R`, `extract-correlations.R`, `m3_fitted_nbinom2_phi()` in
  `dev/m3-grid.R:277-286`) already reads a length-`n_traits` `phi_nbinom2`
  and needs **no change** either — tied entries just come back numerically
  identical.
- The only new code is R-side: (a) parse `disp_group` into a group-index
  vector aligned to trait order (new helper, analogous to the existing
  family-id-vector construction around `R/fit-multi.R:265-320`); (b) replace
  the current binary "map off entirely if family absent"
  (`R/fit-multi.R:4166`) with a three-way branch: family absent → all-`NA`
  (unchanged), family present + `disp_group` default → all-distinct levels
  (unchanged, i.e. `factor(seq_len(n_traits))`, numerically identical to
  today's implicit behaviour), family present + `disp_group` supplied →
  `factor(match(group_vec, unique(group_vec)))`.
- This matches the audit's "~50 LOC" estimate (§ cross-reference below)
  far better than a C++ re-indexing change would.
- SE/uncertainty: `sdreport()` on a tied parameter produces one shared SE per
  group, replicated across the tied `REPORT`/`ADREPORT` entries — correct
  (it *is* one estimated quantity), and needs no special-casing in
  `extract_sigma.R` beyond what already exists for reading `phi_nbinom2`.

### 3.2 Route B (heavier, not recommended as the first cut): `DATA_IVECTOR` grouping with a shorter `PARAMETER_VECTOR`

The alternative anticipated in the task brief: add
`DATA_IVECTOR(disp_group_nbinom2)` (length `n_traits`, 0-indexed group id per
trait, alongside the existing per-trait `DATA_IVECTOR`s such as
`family_id_vec` at `src/gllvmTMB.cpp:252`), shrink
`PARAMETER_VECTOR(log_phi_nbinom2)` to length `n_groups` instead of
`n_traits`, and change the per-trait index at line 2047 from
`log_phi_nbinom2(t)` to `log_phi_nbinom2(disp_group_nbinom2(t))`.

This is a legitimate design and has one real advantage over Route A: the
**reported parameter vector is exactly length `n_groups`**, which is a
cleaner `sdreport()`/AIC parameter-count story than a length-`n_traits`
vector with duplicated values. Its costs: touches `src/gllvmTMB.cpp` (new
`DATA_IVECTOR`, changed indexing at the NB2 block, changed `REPORT`
dimensions at line 2529), forces a corresponding change to every downstream
reader that currently assumes `phi_nbinom2` has length `n_traits`
(`extract_sigma.R`, `extract-correlations.R`, `dev/m3-grid.R:277-286`, any
`predictive-diagnostics.R` NB2 path), and needs a `n_traits -> n_groups`
lookup wired through those readers to re-expand grouped φ back to per-trait
values for display. This is a much larger diff for a benefit (exact
parameter count) that TMB's own `sdreport()` parameter-counting on tied `map`
levels already gets right in Route A.

**Recommendation:** implement Route A first. Route B is worth revisiting only
if a future need (e.g. exposing `disp_group` structure to AIC-style model
comparison in a way that must not touch the R-side readers) makes the
cleaner parameter count worth the larger diff.

### 3.3 Backward compatibility

Both routes preserve `disp_group = NULL` as numerically identical to current
behaviour by construction (Route A: `factor(seq_len(n_traits))`, i.e. all
distinct levels, is exactly what unconstrained estimation already does;
Route B: `n_groups = n_traits`, `disp_group_nbinom2 = 0:(n_traits-1)`,
identical indexing to today's `log_phi_nbinom2(t)`). No existing fit changes
under either route unless a user opts in.

---

## 4. Validation plan

Per D-43 (default NOT-DONE until independently verified), and per this
project's standing rule that interval/recovery claims require evidence, not
assertion: **none of the following has been run.** This section specifies
what "shared dispersion works" would have to show, not a result.

1. **Re-run the mitigation ladder with a `shared` arm.** Extend
   `dev/nbinom2-mitigation-ladder.R` (or a copy) with a 4th arm using Route
   A's `factor(rep(1L, n_traits))` map (pooling all 5 traits to one freely
   estimated φ), same `n ∈ {150, 400, 800}`, same 8+ seeds (more seeds if
   the effect is small — 8 seeds gave visibly noisy per-cell medians in the
   existing table, e.g. n=400 warmstart ranged 0.30–1.23 across seeds).
   **Expected pattern if the fix works:** `shared` tracks `knownphi`
   (0.78 → 0.81 → 0.84 in the existing table) rather than `default`/
   `warmstart` (flat ~0.46–0.52). **If `shared` does not move off the
   `default` line, the fix does not work as designed** and the ridge has a
   different cause than over-parameterisation (e.g. the latent-variance term
   itself, not φ, is what's biased) — a real possible outcome, not
   discounted here.
2. **Grouped (not fully pooled) arm**, if (1) succeeds: repeat with a
   partial grouping (e.g. 2 groups of trait sizes 2/3) to check the fix is
   not an artifact of collapsing to a single parameter specifically, and
   to give a realistic multi-trait-class use case (mirrors gllvm 2.0's
   invertebrate/seaweed grouped example, literature synthesis §gllvm).
3. **Small LOCAL coverage smoke, 1-2 nbinom2 cells.** Not a full coverage
   certificate — a cheap, local (no Totoro/DRAC per this task's compute
   ban) sanity check that CI coverage for the unit-level Sigma diagonal
   moves toward nominal (e.g. 95%) under `shared`/grouped `disp_group`
   relative to `default`, at one or two `(n, seed-count)` cells already used
   in the ladder infra. Point-recovery improving does not guarantee interval
   coverage improves correspondingly — check both, do not infer one from
   the other.
4. **Gate, explicitly.** This validation (1)-(3), if it shows recovery
   moving toward `knownphi` and coverage moving toward nominal, is the
   evidence gate to **un-fence nbinom2** for the 0.6 interval-coverage
   certificate effort (per the handover's "interval coverage is the
   headline" framing). "It works" in any report from this validation must
   mean **recovery to truth, demonstrated**, not an assertion that the
   design is sound — per D-43, default to NOT-DONE until an independent
   read of the ladder output confirms the pattern in (1).

### 4.5 RESULT (2026-07-15) — validated, and it FAILS the gate

`disp_group=` was implemented via Route A (TMB `map=` tying, zero
`src/gllvmTMB.cpp` diff, 18/18 tests pass) and validation step (1) was run:
the mitigation ladder with a fully-pooled `shared` arm, 3 arms × n ∈
{150, 400, 800} × 8 seeds, 0 non-convergence.

| n | default (per-trait) | **shared `disp_group`** | knownphi oracle | shared − default |
|---|---|---|---|---|
| 150 | 0.519 | 0.515 | 0.776 | −0.004 |
| 400 | 0.459 | 0.408 | 0.811 | −0.051 |
| 800 | 0.495 | 0.480 | 0.839 | −0.015 |

(median Σ̂/truth; default reproduces the §1.3 baseline exactly.)

**Verdict: shared dispersion does NOT recover Σ.** `shared` tracks the
`default` line — in fact marginally *below* it (pooling discards the
occasional helpful high per-trait φ) — nowhere near the `knownphi` oracle.
This is precisely the outcome step (1) flagged as possible: **the ridge is
in φ *estimation itself*, not over-parameterisation.** A freely-estimated φ
lands biased-low (~0.5 vs true ~1.1) whether pooled or per-trait; only
fixing φ at the (unknowable) true value rescues Σ. Steps (2)-(3) were not
run — the gate in step (1) already fails, so there is nothing to un-fence.

**Consequences:**
- **nbinom2 stays fenced** (recovery-only; the G1/G2/G3 caveats stand). The
  un-fence gate in §4.4 is NOT met.
- `disp_group=` remains a *legitimate modelling option* (pool φ when traits
  genuinely share dispersion) but is **not** the nbinom2-Σ fix it was
  motivated by. It is **held for maintainer sign-off** — the decision is
  whether to land a correctly-built facility that does not deliver its
  motivating benefit. Not committed to the branch; the diff lives in worktree
  branch `worktree-agent-a6930931ce81e02da`.
- The real nbinom2 Σ problem is φ-estimation bias — a separate, harder
  problem (bias-corrected / penalised φ, or a genuinely informative prior),
  out of scope here and not solved by pooling.

### 4.6 Validation-completeness caveat (2026-07-15)

The §4.5 run has a subtlety worth stating plainly: **the mitigation ladder's
DGP draws a single shared phi across all traits**, so the fully-pooled `shared`
model is the case *most favourable* to pooling — the pooled model structurally
*matches* the DGP. "Pooling recovers Sigma" on this DGP would therefore be
partly circular.

This does not weaken the §4.5 verdict — it **strengthens it a fortiori**:
pooling failed to recover Sigma *even on the DGP that most favours it*. If it
does not help when the shared-dispersion assumption is exactly true, it will not
help when it is false. The phi-estimation-bias diagnosis stands.

But for a **complete** evaluation of `disp_group=` as an opt-in *modelling tool*
(a separate question from the now-settled "does it fix nbinom2 Sigma" — it does
not), two further checks are owed before the facility is advertised:

1. **Per-trait default unharmed.** `disp_group = NULL` must be byte-identical to
   current behaviour. Covered by construction (NULL sets no `map`) and by the
   wire test; assert it explicitly in the recovery ladder too.
2. **Mis-specification / bias cost.** Run a DGP with genuinely *different*
   per-trait phi and measure the bias `disp_group=` *introduces* when the
   shared-dispersion assumption is **wrong** (pooling then forces distinct true
   phi's onto one estimate). This quantifies the cost of the tool being misused,
   and is the honest counterpart to advertising it.

**Standing framing:** per-trait phi estimation remains the **default**;
`disp_group=` is an **opt-in** tool for the case where traits genuinely share
dispersion — never a universal fix, and (per §4.5) not the nbinom2-Sigma remedy.
Fold checks (1)-(2) into the recovery run before any sign-off to advertise.

---

## 5. Risks / open questions

- **Misspecified groups are a real footgun.** Pooling φ across traits that
  do *not* share a true dispersion (the DGP here has one shared φ by
  construction; a real dataset may not) will bias φ toward some pooled
  average and could bias `Sigma_hat` in a new, harder-to-diagnose way, since
  it is now a *modelling* choice (silently wrong) rather than an
  *engineering* limitation (visibly wrong). The design doc does not propose
  an automatic grouping-detection method — `disp_group` is opt-in and the
  user's declared groups are trusted at face value, same trust model as
  `family=` per trait today. Worth a documentation warning, not a code gate.
- **Interaction with Design 66 estimands.** `docs/design/66-capstone-power-study.md`
  and the broader estimand framework were not re-read in depth for this
  document (out of scope for this pass); a future lane should check whether
  pooled dispersion changes any estimand's degrees-of-freedom accounting or
  its effective-parameter count for power/coverage claims before wiring
  `disp_group` into that framework.
- **API surface: argument vs. formula grammar.** §2.2 recommends a plain
  grouping vector, explicitly deferring gllvm's `~ covariate` formula form.
  If real use cases need covariate-driven dispersion grouping (not just a
  static vector), that is materially more work (a dispersion model matrix,
  not just a `map=` factor) and should be scoped as its own design, not
  assumed to fall out of this one.
- **This is an API and engine change and needs maintainer sign-off before
  merge**, per `CLAUDE.md`'s high-risk set (new top-level argument on
  `gllvmTMB()`, and — for Route A — new branching in the `tmb_map`
  construction that changes what gets estimated for existing `nbinom2` fits
  that opt in). Route A's zero-`.cpp`-diff property lowers the engineering
  risk considerably but does **not** exempt the argument-surface decision
  (§2.1: control vs. top-level arg; §2.2: vector vs. formula grammar) from
  that sign-off.
- **Generalisation beyond nbinom2 (§2.3) is untested.** Do not advertise
  `disp_group` for `nbinom1`/`Gamma`/`tweedie`/`beta`/`betabinomial` beyond
  "the argument will not error" until each has its own ladder-style evidence.

---

## Related

`docs/dev-log/2026-07-13-nbinom2-dispersion-literature.md` (literature
grounding) · `dev/nbinom2-mitigation-ladder.R` /
`dev/nbinom2-mitigation-ladder-results.rds` (the evidence in §1.3) ·
`docs/dev-log/audits/2026-05-18-cross-package-count-inference-scout.md` §3
item 4 (the cross-package basis, name-corrected in the header above) ·
`docs/design/80-nongaussian-re-evidence-bars.md` (the sibling honesty-fencing
pattern this design's §4 gate follows) · `docs/design/66-capstone-power-study.md`
(estimand interaction, flagged open in §5).
