# Design 108 — The VA parity programme: what it would actually take

**Status:** design, internal-research only. Authorises no export, no `method=`
argument, no public capability claim, no code change. `NAMESPACE c97ae039`
untouched. This document is a *programme*, not a promise, and its central
contribution is an honest size.

**The ask.** Shinichi, 2026-07-26: *"coverage of all distributions and all
details — structured dependencies and random slopes — multiple random
intercepts — cluster cluster2 unit and unit_obs."*

**The answer in one line.** The mathematics is largely settled and much of it is
free (Designs 104–107 did that work). The *engineering* is 26–42 working days
excluding spatial, and the critical path to the named north star is 17–26 of
them. It is not a session. It is not a week.

**Inherited, established this session, not re-derived here.** The ELBO uses a
per-unit full-covariance Gaussian `q(u_i) = N(m_i, S_i)`, `S_i = L_i L_i'`, with
variational coordinates as ordinary TMB parameters (drmTMB Design 160); every family
sees the latent variable only through a scalar `eta_ij ~ N(mu_ij, v_ij)`, so one
1-D Gauss-Hermite rule covers the family surface (Design 104); Poisson-log and
Gaussian-identity are EXACT, binomial-logit needs GH, EVA is a 2nd-order Taylor
surrogate, default `H = 15`; the per-unit KL is
`0.5*(tr(S_i) + m_i'm_i - logdet(S_i) - q)` against `u_i ~ N(0, I_q)`;
Design 105 §10 found the architecture BREAKS for multinomial and for
zero-inflated / `*_mix` families with separate component predictors.

---

## 0. The destination, and the size of the hole

**The named north star.** Ayumi's BIRDBASE model: `N = 5397` species, 27
responses, **two tiers** (ordinary species + phylogenetic), **missing data
retained**, families **gaussian + binomial-PROBIT + ordinal-probit +
lognormal**. Her published receipt on the shipped Laplace engine is a
26-response two-tier rank-2 mixed-family fit in **1,206.57 s**
(`docs/dev-log/2026-07-24-performance-audit-plan.md`).

**What the VA engine admits today.** Not inferred — read from the fail-closed
gates in `R/va-r3-proto.R:196-201` and `inst/tmb/gllvmTMB_va_r3.cpp:148-171`:

| Her model needs | VA engine today | Evidence |
|---|---|---|
| gaussian with an **estimated** residual SD | `gaussian_anchor` with `gaussian_sd` as **`DATA_SCALAR`** — one fixed number, shared by every trait | `.cpp:130` |
| binomial **probit** | binomial **logit only**, hard error otherwise | `proto.R:204-206` |
| **ordinal_probit** | absent | `.cpp:148` |
| **lognormal** | absent | `.cpp:148` |
| **mixed families** across 27 responses | `family` is a single `DATA_INTEGER` for the whole fit | `.cpp:129` |
| **missing responses** | `stop("R3 requires exactly one complete observation for every unit-trait cell.")` | `proto.R:190` |
| **two tiers** | one tier | `.cpp` parameter block |
| **phylogenetic prior** | `structured = FALSE` enforced | `proto.R:196` |
| default `latent()` = `Lambda Lambda' + diag(psi)` | `psi = FALSE` enforced | `proto.R:196` |

**Count it plainly: zero of her four families are available in the form she
needs, neither of her two tiers' structure is available, her data cannot be
loaded at all, and the engine cannot even express the package's own default
`latent()` term.** The VA engine is a three-family, one-tier, complete-data
research prototype. Calling the gap "extension" understates it; most of the
work below is *first* implementation, not extension.

### 0.1 The uncomfortable prior: her model is not in VA's measured strength zone

Measured this session and not negotiable:

* GH-VA scales **better than Laplace on Poisson** as species count grows —
  Laplace/GH-VA ratio 1.38 → 1.79 → 2.07 across `p = 8/20/40` at `n=40`, and
  0.73 → 1.52 → 1.96 at `n=100` (`dev/frontier/FRONTIER.md` §1).
* **Ayumi has no Poisson columns.** Her surface is gaussian, probit, ordinal
  probit, lognormal.
* On Bernoulli, GH-VA is **58–159× slower** than gllvm's JJ bound at `H=61`
  (`H=15` recovers ~3.4× of that, so call it **17–47×**), and Laplace is the
  *faster* arm at every binary cell tested (FRONTIER §1–2).
* On recovery, GH-VA is **worse** than JJ: relative Frobenius error on
  `Sigma_B` 2.19 vs 0.87 at `n=60,p=12`, and 0.90 vs 0.55 at `n=100,p=20`
  (`dev/bound-vs-estimates.md`). Bound tightness and estimator quality are
  **dissociated**.

So the honest position is: **on the measured evidence, the north star sits
outside the one regime where VA has demonstrated an advantage.** Nothing in
this programme should be sold on speed.

### 0.2 The one honest argument that does survive — and it is not speed

`dev/bound-vs-estimates.md` §3 measured something more interesting than any
timing: **8 of 20 Laplace fits (40%) diverged to a degenerate loading — off by
2–5 orders of magnitude — while reporting a clean convergence code and
`pdHess = TRUE`.** Both VA arms' KL-to-prior term acts as an implicit
regulariser that the unpenalised Laplace MLE lacks, and GH-VA's own health
gates *labelled* its bad fits (`failed_variance_domain` /
`failed_health_gate`) where Laplace's did not.

That is a real, measured, and currently underrated case for a VA route:
**a silent 40% failure rate is worse than a slow fit.** It is also, so far,
a Bernoulli-**logit** result on small `n`. Whether it reproduces on
probit + ordinal + missing data at `N = 5397` is unknown, and Stage 8 exists
to find out. If it does not reproduce, this programme is optional and should
be reconsidered rather than finished.

---

## 1. The ordering principle

**Sequence by what unblocks the destination, not by what is easy.** Two gates,
in this order:

* **Gate A — ADMISSION.** Her data can be loaded and her model expressed at
  all, without an error and without a silent drop. Nothing about quality.
* **Gate B — FIDELITY.** The fit is trustworthy: the phylo tier is actually
  phylogenetic, recovery is measured on *her* families, and the thing runs at
  her scale.

The rule this imposes: **a stage that improves accuracy on a model she cannot
express is worth nothing to the north star.** That is why the tail-safe `log Φ`
work (Stage 4) outranks the entire remaining family catalogue (Stage 12), even
though the catalogue is bigger and more of it is cheap.

Corollary, stated because it is tempting and wrong: `cumulative_logit` is
almost free (Design 105 §6.2 — an exact softplus pair, no new kernel) while
`ordinal_probit` is the hard case. **Substituting it would be changing her
science to fit our engine.** It is a legitimate *additional* family; it is not
a route to the north star.

---

## 2. Confronting the evidence: which arm should the programme extend?

This section comes **before** the stage table because it changes what the
stages are.

**The trap.** The obvious programme — "extend GH-VA to every family and every
tier" — extends the arm the measurements say is weaker. On binomial-logit,
GH-VA is beaten by JJ on *recovery* and by 17–159× on *time*, and gllvm's
already-shipped EVA beats GH-VA on **both** the objective (+23 to +126 nats)
and wall clock (2.5–20.5×) at every evaluable cell (FRONTIER §4). A programme
that ignores this is a programme to build the loser at scale.

**The counter-trap, and it is the one that actually matters here.** JJ is a
**Pólya-Gamma / Jaakkola–Jordan bound, and PG augmentation is logit-specific.**
There is no JJ bound for a probit likelihood. So:

> **The frontier's binomial verdict does not transfer to Ayumi's binomial.**
> The measured "JJ beats GH-VA" result is about the logit cell. Her binomial
> column is probit, and JJ cannot serve it at all. Which also means the
> recovery evidence we currently hold is **not evidence about the cell that
> gates the north star.**

That single observation resolves the apparent conflict. The recommendation is
therefore **not** "pick an arm" — it is **route by family, and make the routing
a documented policy rather than a default**:

| Family class | Route | Why |
|---|---|---|
| Poisson-log, Gaussian-identity, lognormal, Gamma-log, `delta_*` as engineered | **EXACT** | Closed form (Design 105 §1.1). Accuracy is free; there is no tradeoff to expose. This is also where VA's only measured win lives. |
| binomial-**logit**, `cumulative_logit` | **JJ / PG as the default**, GH retained as an opt-in accuracy diagnostic | Measured: better `Sigma_B` recovery *and* ~2 orders of magnitude cheaper. Keep GH because it is the only certified-tighter bound and is the reference for any sign check. |
| binomial-**probit**, **ordinal_probit** | **GH**, with **EVA as the declared fallback** | No PG bound exists. GH is the only tight route; EVA is Design 105 §6.3's option 3 and matches gllvm's own documented position. |
| nbinom1/2, Beta, betabinomial, censored counts | GH | No closed form, no bound. |

**Three consequences, stated as decisions:**

1. **Finish the JJ arm and make it the binomial-logit default.** It is already
   in flight in this worktree (`eval_method` `DATA_INTEGER`,
   `.cpp:131-133, 170-171`; `proto.R:467`). That converts the frontier's
   negative result into an engineering decision instead of a shrug. Note
   Design 104 §3's standing caveat: do **not** resurrect the `design94/95/96`
   JJ prototypes — they implement the coefficient at half the PG convention.
2. **Reserve GH for where it is either exact or unavoidable.** Poisson/Gaussian
   (exact, cheap, scales) and probit/ordinal (no alternative). Do not spend
   quadrature where a closed form or a bound exists.
3. **Keep EVA as a first-class fallback, not an afterthought.** If Stage 4's
   tail work proves AD-unsafe, EVA-only for the probit families is a
   *defensible* landing point rather than a failure — but it must be labelled
   as a surrogate, never as a bound (Design 104 §2).

**What this does not do.** It does not make the ELBO comparable across routes.
An EXACT value, a GH value, a JJ bound, and an EVA surrogate are four different
numbers, and only two of them are certified lower bounds. Design 85 §10's
prohibition stands: no `logLik`/AIC/BIC/LRT from any of them.

---

## 3. The stages

Sizes are **focused working days for one competent implementer**, including the
tests that ship with the implementation, and excluding the days lost to a
negative result forcing a redesign. `CHEAP` means the density spec or the
structural spec found it reduces to machinery that already exists; `NEW` means
machinery must be written and verified.

### Gate A — her data can enter at all

| # | Stage | What it unblocks | Size | Depends on | Cheap / new |
|---|---|---|---|---|---|
| **1** | **Response missingness** — adopt `DATA_IVECTOR(is_y_observed)` verbatim from the Laplace engine; relax the cell-count gate to "≤ 1, and the counted cells are the observed ones"; gate the density call out entirely (never evaluate on a sentinel). Reuse the named sentinel-invariance test (Design 59 §9). | **Her data can be loaded at all.** Today the adapter hard-errors on incomplete data (`proto.R:190`). This is the first blocker in the pipeline and blocks every downstream measurement on real data. | **1–2 d** | none | **CHEAP** — Design 107 §2 read the template end to end and found *nothing in the arithmetic requires completeness*; the requirement is 100% validation code (lines 151, 173–199). §5 sizes it as "a validation relaxation plus one `if`". |
| **2** | **Mixed-family dispatch + per-trait dispersion** — `family` becomes a per-row/per-trait `DATA_IVECTOR`; `gaussian_sd` becomes a `PARAMETER_VECTOR` indexed by trait; the integrand becomes a switch. | **The single biggest admission blocker.** Her model is mixed-family by construction (4 families over 27 responses). Without this, every family stage below is unusable in combination, and the Gaussian column is fitted with a *fixed, shared* SD — i.e. not fitted. | **2–3 d** | 1 (share the row-gating pattern) | **NEW**, but mechanical: parameter packing and indexing, no new mathematics. The dispersion-as-parameter change is trivial for EXACT families and untouched for GH ones. |
| **3** | **lognormal** — Gaussian kernel on `log y` plus the `-log y` Jacobian, with a per-trait `sigma`. | Her lognormal column. | **0.5 d** | 2 | **CHEAP** — EXACT by Design 105 §1.1 (quadratic in `eta`). It is Stage 2's Gaussian branch with two extra terms. |
| **4** | **Tail-safe `log Φ` primitive + binomial-probit.** A log-scale normal CDF that is AD-safe at the quadrature's reach, plus its derivative via a Mills-ratio asymptotic so `dnorm/Φ` does not become `0/0`. | Her binomial column, **and** the prerequisite for Stage 5. **This is the only unavoidable piece of genuinely new numerical machinery on the critical path, and the one place the north star can fail outright.** | **2–3 d** incl. AD-safety verification | 2 | **NEW.** Design 105 §1.3 is explicit about why: guards written for a *point* evaluation at `eta = mu` are not safe under quadrature, where at `H=15` the extreme node reaches **±6.4 SD** of `eta`. §6.3 calls the log-scale route "correct but genuinely fiddly, and needs its own AD-safety verification." |
| **5** | **ordinal_probit** — `logspace_sub` of two `log Φ`s, shared cutpoints on the log-difference scale, `extract_cutpoints()` convention preserved. | Her ordinal column. | **1–2 d** | 4 | **Mostly reuse of Stage 4.** Design 105 §6.1 corrects Design 104's staging: the cutpoints are fixed offsets inside the integrand and **do not add a quadrature dimension** — it is the same 1-D rule with `K-1` extra scalars. Bookkeeping, not quadrature. |
| **6** | **Multiple unstructured tiers** — loop tiers when accumulating `mu` and `v`; loop tiers and levels when accumulating the KL. Per-tier level indices and loading vectors as DATA. | **Her two-tier model expressible at all** — *and* `diag(psi)`, which is the package's own default `latent()` term and is currently hard-gated off (`proto.R:196`). Also delivers `unique`/`indep`/`cluster`/`cluster2`/`unit_obs`/`scalar` in one stroke: Design 106 §0's table shows every tier gllvmTMB has is an instance of one form. | **2–3 d** | 1 (row gating), 2 (packing pattern) | **CHEAP mathematics, real refactor.** Design 106 §5 step 1: "the existing kernel is *already* the general one… no new integrand, no new quadrature, no new linear algebra." Proposition 2 additionally makes per-trait tiers cost `2T` per level instead of `T + T(T+1)/2` — **exactly**, by Fischer's inequality, not as an approximation. The cost is parameter packing across a ragged tier structure. |

**Gate A closes at Stage 6.** At that point her model shape can be expressed and
fitted — with an *iid* prior standing in for the phylogeny.

### Gate B — her data is fitted well

| # | Stage | What it unblocks | Size | Depends on | Cheap / new |
|---|---|---|---|---|---|
| **7** | **Structured phylogenetic KL** — `Ainv`, `diag(Ainv)`, `log_det_A` as DATA; the KL becomes the general Gaussian–Gaussian form under the engine's standardized-field convention. | **Her phylogenetic tier being the actual model** rather than an iid tier wearing its name. Until this lands, a two-tier VA fit is not the model she wrote. | **3–4 d** | **6 (hard prerequisite)** | **Mixed.** The derivation is done (Design 106 §3.1–3.5), the KL carries no hyperparameters under the standardized convention, the trace needs only `diag(A^{-1})` as a DATA vector, and the quadratic form already exists in the Laplace engine (`src/gllvmTMB.cpp:1285-1294`). What is **NEW** is the augmented-node decision: `n_aug ≈ 2N-1 = 10,793`, so the phylo tier costs **twice** what the species count suggests, invisibly from the formula (§4.2) — and Design 106 §6.4(5) flags tips-only-vs-augmented as a *genuine open question* for VA specifically. Settle it with a measurement, not a preference. |
| **8** | **Probit + missingness recovery study** — `Sigma_B` recovery and the Laplace silent-divergence rate on probit / ordinal-probit / missing data, on Totoro. | **The claim that any of this is worth doing.** §0.2's argument for VA rests on a Bernoulli-*logit* measurement; §2 establishes that logit evidence does not transfer to probit. **Required before any statement about her model.** | **2–3 d** incl. compute | 1, 4, 5 | **NEW measurement, no new machinery.** Totoro (≤100 cores, no queue) per the standing compute default; results stay local (D-50). |
| **9** | **Scale gate at `N = 5397`** — verify the optimiser actually carries the coordinate count. | Whether the programme's output runs on her data at all. Design 106 §4.2: **53,970** variational coordinates factorised tips-only, **80,950** on the augmented route, plus `2.1 × 10^6` integrand evaluations per ELBO at `H=15`. §4.3's dense-quasi-Newton-vs-L-BFGS arithmetic (`~52 GB` vs `~6 MB` at `P = 80,950`) is flagged as an **inference that must be verified against what `nlminb`/`optim` actually allocate** before it drives a decision. | **2–3 d** | 6, 7 | **NEW**, and it is the stage most likely to force an architecture change (Design 106 §4.3's two-loop scheme is a *named option*, not a recommendation, and reopening it reopens drmTMB Design 160). |

**Gate A + Gate B critical path: 17–26 working days.**

### Beyond the north star — the rest of the owner's ask

| # | Stage | What it unblocks | Size | Depends on | Cheap / new |
|---|---|---|---|---|---|
| **10** | **Random slopes** | The `||`/correlated random-slope surface. **Not on the critical path** — Ayumi's model as posed has none. | **1–2 d** | 6 | **CHEAP.** Design 106 §2: `a_o = (1, x_o)'`, and `v`'s cross term `2 x_o S_{g,01}` "falls out of the existing kernel for free… there is **no new algebra**." The only work is that `a_o` now depends on the observation's covariate, so the loading can no longer be cached per trait — an indexing and parser change. Gated by Design 04's one-slope cap: match the Laplace surface, do not exceed it. |
| **11** | **Tier plumbing: `cluster`, `cluster2`, `unit_obs`, `scalar`** | The owner's explicit list. | **1–2 d** | 6 | **CHEAP — and worth naming precisely: Stage 6 *is* this request, mathematically.** Design 106 §0's table shows all four are the same `a_{k,o}' u_{k,g}` form. What remains after Stage 6 is formula-parser and adapter plumbing, not template work. |
| **12** | **The remaining family catalogue**, in Design 105 §9's revised order: `delta_lognormal`/`delta_gamma` → nbinom2 → `cumulative_logit` → betabinomial → Beta → censored_poisson → nbinom1 | "All distributions." | **6–10 d total** | 2 | **Split honestly.** *Free/cheap:* `delta_lognormal` and `delta_gamma` are **EXACT end-to-end today** because the hurdle submodel is fixed-effects-only, so `v1 = 0` (§8.3) — Design 104 staged them "later" and that was wrong; nbinom2 is `softplus(eta - log theta)`, the **existing routine, shifted**; `cumulative_logit` is an exact softplus pair with an `eta`-free `log expm1(gap)` precomputed per category, and forms **no CDF difference at all** (§6.2). *New integrands:* Beta and betabinomial (`lgamma` quartets, sharing the `[1e-6, 1-1e-6]` clamp hazard of §1.3), censored rows of `censored_poisson`, and **nbinom1, which §9 names the hardest on the list**. |
| **13** | **Spatial SPDE structured prior** | The spatial half of "structured dependencies." | **≥ 5 d, no honest upper bound** | 6, 7 | **NEW, and partly unknown.** Design 106 §3.6/§6.4(1): `Q(kappa)` is parameter-dependent so `logdet(Q)` recomputes every evaluation; the `A_proj` barycentric loading is supported on ~3 mesh nodes, which makes the node-factorised `q` a *poor* approximation; and the structurally correct fix needs a **differentiable sparse partial inverse inside a TMB template, which is explicitly recorded as unverified.** Do not commit a date to this. |
| **14** | **Uncertainty surface + engine provenance** — `getLV(se = TRUE)` filled from `S_i`, tagged `laplace`/`va_gh`/`eva`/`jj`. | Honest reporting of what a VA fit does and does not give. | **1–2 d** | 6 | **CHEAP.** Design 104 §5.1 already specifies it: VA plugs into the *existing* latent-score SE slot, same signature, different provenance. **No parameter CIs from a VA fit** — three independent lines (Design 85 §10, the PG variance-collapse literature, and gllvm's own `sd.errors` returning `Hessian … na/nan` with 19 negative variances) say a VA-Hessian interval would be silently too narrow. An absent interval beats a wrong one. |

---

## 4. Out of scope for the one-quadrature architecture, permanently

These are **not** "later stages." The architecture cannot reach them; putting
them on a roadmap would be dishonest.

1. **Multinomial / Dirichlet-multinomial / composition families.** `log p`
   depends on the whole `eta_i.` vector through `n_i * log(sum_t exp(eta_it))`.
   Under `q` that vector is `T`-variate Gaussian with covariance
   `Lambda S_i Lambda'`; the expectation is a **`T`-dimensional integral** and
   one 1-D rule cannot touch it (Design 105 §10.1). Design 106 §6.3 confirms
   multiple tiers do not change this in kind or difficulty — the per-tier
   covariances simply add.
   **⚠ `dev/phylo-multinomial-harness-DRAFT.R` is live in the working tree.
   Whatever that lane is doing, it must NOT be assumed VA-reachable.** Any
   route would need a log-sum-exp bound (Böhning / Blei–Lafferty tangent) or an
   explicitly `T`-dimensional treatment — a different architecture, not a
   family addition.
2. **Zero-INFLATED and `*_mix` families with separate component predictors.**
   `log(A(eta1) + B(eta1)C(eta2))` is not additively separable; if both
   predictors load on `u_i`, the ELBO needs the joint — 2-D quadrature
   (§10.2). The precise boundary: components sharing a *single* predictor stay
   GH-reachable (a `logspace_add` inside the integrand); components carrying
   *separate* predictors do not. **This distinction should be written into the
   family registry now**, so nobody adds a two-predictor mixture by analogy
   with `delta_*` — whose separability (§8.2) is a property of the *hurdle*
   structure, where the zero and positive parts are on disjoint events.
3. **The Poisson-link delta parameterisation** (`delta_poisson_link_gamma`,
   `delta_poisson_link_lognormal`). The positive component's mean depends on
   both predictors non-separably (§10.3). These constructors are already
   `blocked deprecated`; **that block is load-bearing for the VA route, not
   merely a deprecation.**
4. **Dispersion carrying its own latent loadings** (a "distributional GLLVM").
   `lgamma(y + exp(eta_phi))` couples two predictors non-separably (§10.4).
   Not currently gllvmTMB's territory — it is drmTMB's — but it is the likely
   direction of travel, so **the family contract of Design 105 §1 should state
   that dispersion arguments are constants with respect to `eta`**, now, while
   it is free.

---

## 5. Total size, and what cannot be done tonight

| Block | Days |
|---|---|
| Gate A (Stages 1–6) — her data can enter | **9–14** |
| Gate B (Stages 7–9) — her data is fitted well | **7–10** |
| **North-star critical path** | **17–26** |
| Owner's remaining ask (10, 11, 12, 14) | **9–16** |
| **Total excluding spatial** | **26–42 working days** |
| Spatial (13) | **≥ 5, with a real chance of not landing** |

**26–42 focused working days is 6–9 working weeks** at one productive
person-day per calendar day — and that assumes nothing found in Stage 8 or
Stage 9 forces a redesign. Two named ways it could:

* Stage 8 finds VA's recovery on probit is no better than Laplace's, and
  Laplace's silent-divergence failure mode does not reproduce at her scale.
  Then §0.2's justification evaporates and the remaining stages become
  optional. **This is a live possibility, not a formality.**
* Stage 9 finds the optimiser cannot carry 80,950 coordinates without the
  two-loop scheme. That reopens drmTMB Design 160, which is an architecture decision,
  not a stage.

### What cannot be done in one session — stated plainly

* **The whole ask.** "All distributions and all details" is off by roughly
  **40×** from a single session. It is not close.
* **Anything past Stage 1.** Stage 2 (mixed-family dispatch) is a parameter-
  packing refactor of both the template and the adapter, with tests; that is
  multi-session on its own.
* **Anything at Ayumi's scale.** Stage 9 is a Totoro campaign, not a laptop
  run.
* **Tonight specifically, in this lane: the template is contended.** Another
  agent is concurrently editing `inst/tmb/gllvmTMB_va_r3.cpp` and
  `R/va-r3-proto.R` (the in-flight `eval_method` JJ arm). Every Gate-A stage
  touches those two files. Starting one tonight is bleed-through
  (D-88), not speed. **This document's lane writes `docs/design/` only.**

The single realistic single-session slice on this list is **Stage 1**, and only
after the in-flight JJ work has landed.

---

## 6. The next slice I would actually run

**Stage 4 — the tail-safe `log Φ` primitive, as a standalone spike, sequenced
after the in-flight JJ wiring lands.**

**Correction (2026-08-02):** Stage 4 has since landed (PR #896). This section's
"add `family == 3` (binomial-probit)" is stale and, taken literally, collides
with the shipped template: code `3` is `nbinom2` and binomial-probit landed as
code **`4`** (`inst/tmb/gllvmTMB_va_r3.cpp:348`: "family entries must be 0
(Gaussian), 1 (binomial-logit), 2 (Poisson), 3 (nbinom2), or 4
(binomial-probit)"). The prose below is left as the historical plan record
(what was scoped before implementation), with the family-code number fixed so
it does not mislead a future reader about which slot is free; the AD-safety
verdict is AD-SAFE, and probit is deliberately still refused at the public
fence per the Live Phase Snapshot.

Scope (as originally planned): add `family == 4` (binomial-probit) to the
template with a log-scale `log Φ` and a Mills-ratio-guarded derivative; verify
AD-safety at the actual quadrature reach (`H = 15` → ±6.4 SD; `H = 61` →
±14.50 SD, corrected in Design 105 §1.3) by finite-differencing `dE/dmu` and
`dE/dv` against the integrand; fit one Bernoulli-probit toy and compare
against the shipped Laplace engine. Nothing else — no mixed-family, no
missing data, no tiers.

**Why that one, and not the cheaper Stage 1:**

1. **It is the only critical-path stage that can fail.** Every other Gate-A
   stage is labour against a settled derivation — Design 107 proved the
   missing-data change is exact, Design 106 proved the tier accumulation is
   textbook. Stage 4 is the one place Design 105 says "genuinely fiddly, and
   needs its own AD-safety verification" (§6.3), and the one place where
   §1.3's cross-cutting hazard — guards written for a point evaluation, used
   under a rule that reaches ±6.4 SD — actually bites.
2. **It decides the shape of the programme.** If the log-scale route is
   AD-safe, Stages 4 and 5 land and the north star is reachable as costed. If
   it is not, the answer is EVA-only for both probit families (Design 105
   §6.3 option 3) — a defensible landing point, but a *different* programme
   with different claims. **Better to know that on day 1 than on day 15.**
3. **It has the highest leverage per day on the critical path.** One primitive
   serves **two of her four families** — binomial-probit and ordinal-probit —
   i.e. half her family surface and the entire half that no bound and no
   closed form can reach.
4. **Stage 1 is certain, and certainty is not information.** It is cheap, it
   will work, and it can be done any time. Spending the first slice on it
   buys progress but no knowledge.

**Run alongside it, in a lane that collides with nothing:** the §0.2
measurement — Laplace's silent-divergence rate on probit / ordinal-probit /
missing data at realistic size, on Totoro. It touches only the *shipped*
engine, needs no VA code, answers "is any of this worth 26–42 days", and is the
one thing that can start tonight without contending for the template.

---

## 7. What this document does not do

It authorises nothing: no export, no `method=` argument, no capability claim,
no NEWS line, no user-facing route. Laplace remains the package default and 0.6
ships Laplace-only (Design 104 §4.1). **⚠ AMENDED 2026-07-30: the "Laplace-only"
half is reversed** — 0.6 now ships an opt-in, hard-fenced `engine = "va"` covering
a subset far smaller than the parity programme priced here; Laplace remains the
default, and this document still authorises nothing on its own (`LOOP/GOAL.md`
Amendment 4). **The 26–42-day estimate below was put to the maintainer before that
decision and is not disputed by it.** Every size above is an estimate made
before the code exists, and the two flagged redesign risks (Stages 8 and 9) are
real. Nothing here has been measured except the things explicitly cited as
measured.

> Related: [Design 104](104-va-family-coverage.md) (architecture, defaults,
> uncertainty surface) · [Design 105](105-va-family-densities.md) (per-family
> density spec, the breakages) · [Design 106](106-va-structural-extension.md)
> (tiers, slopes, structured priors, Ayumi's cost) ·
> [Design 107](107-va-missing-data.md) (response missingness) ·
> [Design 85](85-highdim-nongaussian-va-formal-contract.md) (READ-ONLY,
> negative evidence) · `dev/frontier/FRONTIER.md` (the accuracy-runtime
> frontier) · `dev/bound-vs-estimates.md` (recovery: tightness ≠ quality)
