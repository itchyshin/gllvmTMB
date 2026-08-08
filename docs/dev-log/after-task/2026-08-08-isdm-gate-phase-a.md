# After Task: Integrated SDM — Phase A gate (mixed curvature within one species)

Lane: `claude/experiment-integrated-sdm` (worktree-only, no PR, no merge).
Platform: Claude Code. Foreign lanes treated as ACTIVE: codex (VA/GH), cursor (CRAN 0.7).
Umbrella issue: #941. Related: #942 (closed), #943, #945, #946.

## 1. Goal

Decide whether `gllvmTMB` can carry **one species' rows under two likelihoods of different
curvature** — Poisson-log (presence-only) and Bernoulli-cloglog (presence/absence) — and still
recover a planted `Lambda`. This is the single gate on a larger integrated-SDM programme: a GLLVM
pins the latent scale by convention (`u ~ N(0, I)`, `Lambda` lower-triangular with positive
diagonal), so **`Lambda` carries all the scale**, and nobody had checked whether that survives when
one loading is informed by two arms of very different Fisher information. The requirement was not
just a number but an **attributable** one: non-identifiability and weak estimability had to be
separated by instrument, not by inference.

## 2. Implemented

Nothing in `R/`, `src/`, `tests/`, `man/`, `NAMESPACE`, or `DESCRIPTION`. This slice is
**measurement**, and its product is evidence plus a verdict.

**Mathematical contract measured.** One ecological intensity per unit,
`log mu_i = b0 + x_i b + xi_i`. The presence-only arm is a thinned point pattern,
`log lambda_i = log A_i + b0 + x_i b + xi_i + a0 + w_i alpha`, observed as Poisson counts. The
presence/absence arm is *derived*: under a Poisson process a site of area `a_i` is occupied with
probability `1 - exp(-a_i mu_i)`, hence `cloglog(p_i) = log a_i + b0 + x_i b + xi_i`. So `b0` and
`b` are the same parameters in both arms and `cloglog` is compulsory — it *is* the change of
support. Construction is textbook (Fithian 2015; Fletcher 2019; Dovers, Popović & Warton 2024
*MEE* 15:191–203, pkg `scampr`); **nothing about it is claimed here.**

What is now established that was not before:

- **A mixed-family-within-species fit RUNS.** `family_id_vec` / `link_id_vec` come back length
  `nrow(data)`, cross-tabulating exactly against a **non-trait** `family_var` column (family id 2 /
  link 0 for the Poisson rows, family id 1 / link 2 for the Bernoulli-cloglog rows). Converges with
  a PD Hessian. **This contradicts issue #945's own comment thread**, which recorded the
  configuration as *"cannot be run today — the R interface maps family per trait."* It was
  **untested, not unsupported**: every existing mixed-family test keys `family_var` to the `trait`
  column itself.
- **The joint likelihood is analytically correct.** On a fixed-effects-only fit (so TMB's objective
  is the exact NLL, not a Laplace approximation), the objective matches an independently coded joint
  NLL — `dpois` on the PO rows, `dbinom` with a cloglog inverse-link on the PA rows — to
  **1e-10 … 1e-13 at three separate parameter vectors**. A fourth point disagreed by 1212 and traced
  entirely to the documented `[1e-12, 1-1e-12]` probability clamp at `src/gllvmTMB.cpp:2192-2195`
  plus a genuine optimiser failure (`pdHess = FALSE`), not a dispatch bug.
- **`beta` recovers** across the two arms: planted 0.4, bias **−0.00409**, MCSE **0.00826** over
  20 seeds at 400 cells — bias within one MCSE of zero.
- **The PO-only intercept equals `b0 + a0`, not `b0`** — Fithian et al.'s identifiability result
  reproduced empirically rather than cited.
- **THE GATE: PASS above prevalence 0.3.** 24,000 fits. Details in §4.

## 3. Files Changed

All under the lane worktree; **no package source touched**.

```
dev/isdm-probe.R                    dev/isdm-probe-findings.md
dev/isdm-plumbing.R                 dev/isdm-plumbing-findings.md
dev/isdm-gate-harness.R             dev/isdm-gate-smoke.R
dev/isdm-gate-smoke-findings.md     dev/isdm-gate-campaign.R
dev/isdm-gate-analyse.R             dev/isdm-gate-findings.md     (50K — the primary artifact)
dev/isdm-gate-results.rds/.csv      dev/isdm-gate-instruments.rds
docs/dev-log/after-task/2026-08-08-isdm-gate-phase-a.md   (this file)
docs/dev-log/check-log.md                                  (appended)
```

**Status-inventory cascade: N/A by design.** No README, NEWS, ROADMAP, vignette, roxygen, `man/*.Rd`
or validation-debt-register row was touched, because **no capability is advertised by this slice**.
Nothing leaves the lane.

## 3a. Decisions and Rejected Alternatives

> **Decision**: The presence-only arm is **Poisson**, not negative binomial.
> **Rationale**: For NB2 as a Poisson-gamma mixture, `P(Y=0) = (1 + a mu/k)^(-k)`, so
> `cloglog(p) = log k + log log(1 + a mu/k)` — not affine in `log mu`. The gamma mixing is
> **arm-local**: it is marginalised inside the PO likelihood and never appears in the PA arm, so
> either the mixing is real and the PA arm's cloglog link is misspecified, or it is not and NB2 is
> wrong. **Exactly one arm is always wrong.** A declared shared latent `xi` instead keeps
> `cloglog(p | xi) = log a + b0 + x b + xi` exact *conditionally* in both arms.
> **Rejected alternative**: "the marginal detection probability is not cloglog" — the reason
> originally written down. It is a **bad** criterion because it equally condemns the recommended
> lognormal-Poisson fix, which also has a non-cloglog marginal zero probability. Caught in plan
> review; corrected before execution.
> **Also recorded**: NB2 is incompatible with *cloglog*, **not** with *integration*. A
> self-consistent NB2 iSDM exists with the matched link `p = 1 - (1 + e^eta/k)^(-k)`. Rejecting NB2
> here is pragmatic (no such link in the package), **not a theorem**.
> **Confidence**: high.

> **Decision**: The gate uses **T = 6 species, d = 1**, not the T = 2 the incoming handover specified.
> **Rationale**: For `Sigma = Lambda Lambda' + diag(psi)`, `df = ½[(T−d)² − (T+d)]`; at `d = 1` that
> is `T(T−3)/2`. T=2 gives **−1** (under-identified), T=3 gives **0** (knife-edge, Heywood-prone),
> T=6 gives **9**. Ledermann at d=1 is exactly `T ≥ 3`. A T=2 gate would have been flat *regardless*
> of the mixed-family question and would have scored as a landmine-3 failure for the wrong reason.
> The positive-diagonal convention removes a discrete reflection, not a dimension, so it does not
> change the count. Verified in code that `psi` really is estimated here: `R/fit-multi.R:4963-4978`
> maps it off only when a trait's rows are **all** single-trial Bernoulli, which a mixed trait fails.
> **Rejected alternative**: the handover's T = 2. **Confidence**: high.

> **Decision**: PO cells and PA sites are the **same latent units**.
> **Rationale**: the model has no spatial kernel on `xi` (it is `Lambda u + eps`, i.i.d. across
> units), so under **disjoint** units the two arms would transfer **zero** information through `xi`
> and the gate would be testing a different question. Co-location is what makes `xi` the same
> *realised* value rather than merely the same distribution.
> **Rejected alternative**: disjoint units — deferred to Phase C as a declared arm, not assumed away.
> **Confidence**: high.

> **Decision**: PA site area `a_i = 1` for all sites; PO cell areas `A_i` vary, in the same units.
> **Rationale**: `R/offset.R:148` gates offsets to count families but fires only on **nonzero**
> offsets — a zero offset on a binomial row is explicitly legal and is documented as *"what makes a
> mixed-family fit expressible."* Setting `a_i = 1` therefore sidesteps the restriction with no code
> change. **But it is an identifying assumption, not a convenience**: the PA arm identifies
> `b0 + log a`, so `a` known is what makes `b0` identified, which is in turn what identifies `a0`.
> And because `b0` is shared, `A_i` must be expressed in units where the PA site area equals 1 —
> otherwise the mismatch is silently absorbed by `a0` with no error.
> **Rejected alternative**: implementing #946 first. Deferred: a passing gate does **not** license
> #946, since `a = 1` means the gate never exercises a varying PA offset. **Confidence**: high.

> **Decision**: The gate's **primary metric is `Lambda` recovery**, not the correlation off-diagonals.
> **Rationale**: forced by two structural facts found during the smoke. (i) `R/fit-multi.R:4976` maps
> `theta_diag_B` **off** — not merely floors it — when every row of a trait is single-trial Bernoulli,
> so the all-binary control can only ever estimate `Sigma = Lambda Lambda'` (its U1 and U0 fits are
> numerically identical to ~7 significant digits). (ii) Under a rank-1 `Sigma = Lambda Lambda'` with
> `d = 1`, **every off-diagonal correlation is exactly ±1** by construction. Together these exclude
> the BB control from any off-diagonal metric, so an off-diagonal headline would have silently
> dropped the control that makes the result attributable.
> **Rejected alternative**: R off-diagonals as headline — retained as a **secondary** metric, PP vs
> PB only, with BB's exclusion stated rather than quietly omitted. **Confidence**: high.

> **Decision**: Ran the campaign **locally** (18 cores, 6.43 core-hours, ~28 min) rather than on Totoro.
> **Rationale**: the smoke measured the grid at ~2.9 core-hours. The standing rule sends campaigns to
> Totoro/DRAC because campaigns are expensive; this one is a laptop job, and remote deploy + TMB
> compile would have cost more than the run. **Rejected alternative**: Totoro. Recorded here so the
> deviation from the compute default is visible rather than silent. **Confidence**: high.

## 4. Checks Run

**Pre-edit lane check** (AGENTS.md, before touching `docs/dev-log/`):
`gh pr list --state open` → **empty**. `git log --all --oneline --since="6 hours ago"` → only this
lane's own `50f578b9`. No collision.

**Lane preflight**: `bash ~/shinichi-brain/tools/lane_preflight.sh` → *"no codex lane detected in the
last 12h"*. Per D-87 that is **weak evidence, not proof**; foreign lanes were treated as ACTIVE
throughout.

**The campaign.** Grid: 3 cells (PP = both blocks Poisson · BB = both blocks Bernoulli-cloglog ·
**PB** = the gate cell) × `n ∈ {100,200,400,800,1600}` × mean prevalence `∈ {0.1,0.3,0.6,0.9}` ×
2 arms (`unique = TRUE` / `FALSE`) × **200 seeds** = **24,000 fits**. Intensity `t = −log(1−p)` drives
the Poisson blocks too, so the cells stay matched on information.

**The pass criterion was pre-registered** in `dev/isdm-gate-findings.md` (lines 19–42) **before** the
results section (line 130), with numeric tolerances stated up front: slope within **2 SE of −0.5**;
multistart gap threshold **0.05**; PB-vs-PP RMSE ratio tolerance **2.0**.

| instrument | result |
|---|---|
| **D1** log-log RMSE slope, PB/U1 | p=0.1 **−0.431** (SE 0.0095) — misses · p=0.3 **−0.487** (0.0069) · p=0.6 **−0.511** (0.0140) · p=0.9 **−0.487** (0.0136) — three pass |
| **D2** within-dataset multistart | 14 dispersed starts (incl. reflected, 3×-inflated) → **one** optimum. nll spread 4.3e-08; max `Lambda` gap at matched logL **4.5e-05** vs threshold 0.05. Repeated on 6 datasets; worst gap 4.6e-05. |
| **D3** information eigen-spectrum | smallest eigenvalue never approaches zero. **Pre-registered prediction confirmed**: the soft direction lies on the `lambda² + psi = const` manifold (cosine 0.76–0.99 in 11 of 12 configs). |
| **D4** communality profile | **flat** at p=0.1 (nll rise 1.19 over the whole grid; interval [0.04, 0.96]), **sharp** at p=0.6. The undetermined quantity is the loading/unique-variance **split**, not the loading. |
| **D5** arm-stratified information | trustworthy only at p=0.6 (Bernoulli block carries **15.4%**; validated by PP returning 49.6/50.4). At p=0.1 a third of arm-only Hessians are not PD. |
| **D6** permutation placebo | permuting the Bernoulli block moves `Lambda`-hat by 0.488/0.264/0.184/0.103 at p=0.1/0.3/0.6/0.9 — **23×–58× its own MCSE**, roughly doubling RMSE. **Not inert.** |
| **D7** Laplace control | AGHQ is **structurally ineligible** under `unique = TRUE`. On U0 it removes ~a fifth of the error (0.3388 → 0.2764, ~5 MCSE). |
| **boundary / Heywood** | reported as a primary outcome: PB 0.00–0.965, PP 0.00–0.975, BB 1.000 (structurally excluded). **Zero loading runaways in 24,000 fits.** |

**Headline**: PB's sign-aligned `Lambda` RMSE is **1.03–1.17× PP's across all 20 (n, prevalence)
cells** against a pre-stated tolerance of 2.0, and PB beats BB everywhere. **The mixing itself is
nearly free.**

**Attribution of the p=0.1 miss — this is what the controls bought.** It is **not** mixed curvature:
PP fails the same criterion the same way (−0.454); PP's communality profile is equally flat (1.13 vs
1.19); 96.5% of PB fits at n=100 sit at the `psi` boundary versus **97.5% for PP**.

**Independent verification** (fresh agent, recomputed from the saved `.rds` rather than reading the
prose): 24,000 rows × 33 columns confirmed; every (cell, n, prevalence, arm) cell has exactly 200
seeds; PB/PP RMSE ratio recomputed **1.028–1.169** (claimed 1.03–1.17); D1 slope for PB at p=0.3
recomputed **−0.4871** (claimed −0.487; R² 0.9994). No metric column entirely NA.
`R/`, `src/`, `tests/`, `man/`, `NAMESPACE`, `DESCRIPTION`, `docs/design/` all unmodified; the shared
Dropbox checkout verified still clean.

**Deliberately NOT run:** `devtools::test()`, `devtools::document()`, `R CMD check` — no package
source was touched, so they would test nothing about this slice. No `pkgdown` build. No GitHub
Actions (D-50). No Totoro/DRAC (see §3a). No push, no PR, no merge.

## 5. Tests of the Tests

**No package tests were added** — this slice adds no package behaviour. The analogue is the
**analytic likelihood cross-check** (`dev/isdm-plumbing.R` T1), which satisfies the
*failure-before-fix* rule in spirit: it is built specifically to catch the failure mode that a fit
applying the **wrong family to a block of rows** converges and looks fine. It was run at three
parameter vectors rather than one, because a single point can agree by coincidence and an additive
constant can only be identified from more than one point.

The **D6 permutation placebo** is the guard against a vacuous pass, and the **PP/BB control cells**
are the guard against a misattributed failure. Both were pre-specified.

## 6. Consistency Audit

Not applicable in the usual form — no user-facing prose, no exported symbol, no keyword, and no
`man/*.Rd` was touched, so the standard stale-wording patterns have nothing to scan. The audit that
*was* run is the lane audit in §4: verbatim `git status --short` on both the worktree and the shared
checkout, plus an explicit modified-path check against `R/ src/ tests/ man/ NAMESPACE DESCRIPTION
docs/design/`. Verdict: **clean**.

## 7. Roadmap Tick

`N/A` — this lane is fenced out of the roadmap by design until it produces something that would be
advertised, which it has not.

## 8. What Did Not Go Smoothly

- **The plan's first revision could not have answered its own question.** As originally written, the
  gate scored elementwise `Sigma`/`R` error plus Procrustes over 20 seeds and was asked to report
  whether the problem was identifiability or estimability. Those are **not separable by
  cross-seed spread** — a flat ridge and a sharp-but-shallow one inflate it identically. A three-lens
  plan review caught it before any compute was spent; D1/D2/D3 exist because of that review. Cheap
  in review, expensive if it had run.
- **The gate had no controls in rev 1.** A FAIL would have been unattributable — mixed curvature,
  Bernoulli information poverty, and Laplace shrinkage on binary data would have been
  indistinguishable. The PP/BB cells were added for this reason and immediately earned their keep:
  they are the entire basis for saying the p=0.1 miss is not about mixing.
- **Two scoring traps were only visible from the smoke, not from reading.** The `theta_diag_B`
  map-off and the rank-1 `R = ±1` identity together would have made the headline metric vacuous for
  the control cell. Both were found by running one configuration before committing to the grid — the
  smoke-first rule paying for itself.
- **A stated justification was wrong and would have propagated.** The Poisson-over-NB2 decision was
  right, but the reason first written down ("the marginal detection probability is not cloglog")
  equally condemns the recommended fix. It is now restated as a misspecification argument. The
  *decision* never changed; the *reason* would have gone into the dev-log wrong.
- **Two mid-run code corrections** were needed (D5's evaluation point; D7's `aghq_used` field). Both
  made the answer **less** favourable, and no threshold or cell was changed after seeing results.
- **Optimiser flags were useless, again.** `convergence == 0` in **99.9%** of fits and `pdHess` in
  99.6%, *including* the cells where recovery is demonstrably poor. Consistent with the sister-package
  finding that 83.2% of degenerate fits reported clean flags.

## 9. Team Learning

**Fisher** owned the gate and the plan review. The review's load-bearing contribution was noticing
that the proposed instrument could not distinguish the two hypotheses the slice was chartered to
distinguish — a *design* error, invisible to any amount of care in execution. Fisher also supplied
the per-observation information comparison that turned "prevalence" from an unstated constant into a
ladder: `I_Bernoulli-cloglog(log mu) = t²e^(−t)/(1 − e^(−t))` is **capped at ≈0.648** while
`I_Poisson = t` is unbounded, so the honest answer was always going to be a threshold, not a boolean.

**Gauss** verified every mechanical claim against source with `file:line` before any of it was
believed, and produced the verified call shape. Net effect: zero blocking issues from the
implementation side, and the one scope correction (#946 needs 4 touch points, not 2) is now recorded
before anyone starts it.

**Rose** caught that a sweep-receipt row was a bare conclusion with no command attached — exactly the
vacuous-receipt pattern the gate exists to catch — plus the missing pre-edit lane check and the
missing check-log deliverable. All three are closed in this report.

**Curie** adjudicated #945 by running it rather than arguing about it, and found the
`link_residual = "auto"` defect in passing.

## 10. Known Limitations and Next Actions

**What this does NOT cover.**

- **The Laplace attribution is UNCERTAIN for the package's real estimand.** AGHQ is structurally
  ineligible under `unique = TRUE`, so D7 speaks only to the U0 arm. How much of the p=0.1
  degradation is Laplace shrinkage rather than genuine information poverty is **not settled**.
- **`d = 1` only.** Rotation is nearly trivial at `d = 1` (only a sign is free). Nothing here speaks
  to `d ≥ 2`, where the triangular constraint must be imposed before the eigen-spectrum means
  anything.
- **One planted `Lambda`, one covariate structure, no misspecification.** This is a **recovery**
  check. A simulation generated from the fitted model cannot fail; it measures recovery, never
  benefit. **No claim of benefit is made or licensed.**
- **The gate does not license #946.** `a = 1` means a varying PA offset was never exercised.
- **D5's information split** is trustworthy only at p=0.6.
- **Real data, GBIF, detection probability, disjoint units** — all untouched.

**Filed in passing.** `extract_Sigma(link_residual = "auto")` warns that no single link-residual is
defined for a trait spanning two families and sets `NA` (`R/extract-sigma.R:134-145`), but the
consumer gates on `any(link_resid_per_trait != 0, na.rm = TRUE)` (`R/extract-sigma.R:1548`), which
discards the `NA` — so it **silently returns the `"none"` answer while warning the quantity is
undefined**. Pre-existing, not caused by this lane; a CRAN 0.7 release is in flight elsewhere, so it
needs coordination before anyone touches shared files.

**Next actions, in order.**

1. **Correct issue #945** — its own comment thread records the configuration as impossible; it is not.
2. **Phase B (#946)** — re-key the offset gate on family × link. Gauss's corrected scope: add a
   `link_id_vec` parameter to `gll_prepare_offset()` (`R/offset.R:108`), pass it at the sole call site
   (`R/fit-multi.R:2159`, which currently does not), change the gate (`R/offset.R:148`), and augment
   `fam_name()` (`R/offset.R:150`) so the error distinguishes admitted cloglog from still-refused
   logit/probit. **`docs/design/01-formula-grammar.md:692-694` must be rewritten, not extended** — it
   currently argues *explicitly against* a link gate. **No existing test covers binomial at all**, so
   nothing currently regression-guards the surviving logit/probit refusal; S6 must add one.
3. **Phase C (#943)** — the misspecification campaign: spatially structured recording bias correlated
   with the environmental predictors, which a per-source constant `gamma[d,j]` structurally cannot
   represent. Per `dr30` this is the genuinely new result; per Tobler 2019 the driver is
   **species-specific** bias, so a shared bias surface would understate it.
4. **Before any public claim**: the reference paper's authors are UNSW — Gordana Popović and David
   Warton — and Gordana is already on the advisory-board invite list.
