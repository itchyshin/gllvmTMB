# Pólya-Gamma augmentation for the GLLVM bilinear factor structure — feasibility note

**Status: DESIGN ONLY.** No R/C++ file was written, edited, or executed to produce this
note. Nothing here is a public claim, a package behaviour, or an implementation plan
approved for building.

**Sources are mixed provenance and tagged inline.** The commissioning brief for this note
rests on `dr25` (`shinichi-brain/projects/deep-research/dr25-gllvm-variational-implementation-distilled`),
which is **NotebookLM-derived and UNVERIFIED** per the standing quarantine rule — treat
every `dr25`-sourced statement below as a claim, not a fact, until checked against the
primary sources named in §5.

**Provenance legend**, matching the convention already established in this repository's
own VA notes (`docs/design/109-bound-tightness-vs-recovery.md`,
`docs/dev-log/recovered/110-pg-closed-form-updates.md`):

| tag | meaning |
|---|---|
| **PROVED** | derived in this note; checkable by re-reading the algebra |
| **REPO** | already derived and/or numerically verified elsewhere in this repository; cited, not re-claimed |
| **KNOWN** | literature claim, recalled from training, not re-fetched for this note; verify before any public statement |
| **CLAIMED (dr25)** | asserted by the dr25 NotebookLM note; UNVERIFIED |
| **AGENT-INFERRED** | my inference, not a proof |
| **SPECULATION** | explicitly labelled guess |

---

## Headline — read this before the five sections below

**The derivation this brief asked for already exists in this repository, dated one week
before this note, and numerically verified.** `docs/dev-log/recovered/110-pg-closed-form-updates.md`
(committed on `main` at `3cccc396`; confirmed via `git log` for this note) derives closed-form
block-coordinate updates for exactly the bilinear term this brief names — `mu_it = a_it +
lambda_t' m_i`, i.e. `u_i' lambda_t` in the brief's notation — against gllvmTMB's own
`inst/tmb/gllvmTMB_va_r3.cpp` JJ evaluator, not a GLMM stand-in. It reports the fixed-point
gradient at `1.6e-15` and states explicitly, in its own words: `w(xi) := tanh(xi/2)/(2 xi)
(= E[PG(1, xi)])` — the JJ-bound weight already coded **is** the PG expectation, under a
different name.

That derivation was then evaluated for adoption and **parked by the maintainer on
2026-07-28** (`docs/dev-log/2026-07-28-morning-brief.md`, §5C, verbatim: *"the closed-form
Pólya-Gamma route — VA is frozen. (The PG route is verified sound, gradient `1.55e-15` at
the fixed point, but it is JJ-only and therefore accelerates the arm that recovers
worst.)"*). Since then, two things happened that this note had to check before repeating
that verdict blindly: VA was un-frozen and now ships in 0.6 (`docs/dev-log/2026-07-30-va-ships-in-06-reversal.md`),
and a sibling arc four days ago derived and shipped an analogous fast closed-form tier for
a *different* link (Albert-Chib for probit) and found the same class of result — fast,
exact-ish, and **disqualifying as a default** because it collapses a real variance
component — with the resolution being to use it only as a warm start for the numerically
optimised tier, never as a replacement (`docs/dev-log/handover/2026-08-03-claude-handover-mature-va-item1.md`,
§3, §"SESSION 2").

This note's job is therefore narrower than a from-scratch derivation. It (1) confirms the
existing result and states precisely why it answers the brief's core question, (2) extends
it to the one regime it does not cover — both factors carrying a real posterior, not one
of them fixed at a point estimate — which is a small, checkable, genuinely new half-page of
algebra, (3) locates and updates the maintainer's existing verdict against the current
state of the repo, and (4) surfaces a sharper external novelty falsifier than anything
derived below: `gllvm`'s own GitHub issue #237 (quoted in
`docs/dev-log/2026-07-31-ranga-eva-literature.md`, Q4) suggests the competing package may
**already ship** a Pólya-Gamma-based VA for the logit link on the actual bilinear GLLVM
structure. That is flagged there as unverified beyond the thread's own wording, and it is
the single most important open question this note did not settle (see the closing
paragraph and §5).

---

## 1. The core derivation question

**Setup, reusing Design 110's notation exactly** (T traits, q latent dimensions, `Lambda`
is `T x q` with row `t` written `lambda_t`; `n_it` trials, `y_it` responses; `a_it = x_it'
beta` the fixed offset):

    eta_it = a_it + lambda_t' u_i         (the bilinear term the brief asks about)

Two distinct cases answer the brief's (a)/(b)/(c) menu differently, and the difference
matters:

### 1.1 Case A — `Lambda` point-estimated, `u_i` variational (this is gllvmTMB's actual architecture)

**REPO, confirmed by re-reading the algebra myself against `inst/tmb/gllvmTMB_va_r3.cpp:96-113,
297-380` and `:406-423` (parameter block, verified below in §3).** Design 110 treats `Lambda`
and `beta` as ordinary TMB parameters (point/MLE, no distribution), which is exactly what
gllvmTMB (and `gllvm`) actually fit — only `u_i` gets a variational family `q(u_i) = N(m_i,
S_i)`. Fixing `xi_it = sqrt(mu_it^2 + v_it)` (the JJ bound's own free parameter, profiled
out analytically — see §2), write `w_it := n_it tanh(xi_it/2)/(2 xi_it)`,
`c_it := y_it - n_it/2`. Design 110 derives, and verifies numerically to a gradient of
`1.6e-15` against the live template:

    A_i = Lambda' W_i Lambda + I_q,        S_i = A_i^{-1}
    m_i = S_i Lambda' (c_i - W_i a_i)

and, by the same route, closed-form updates for `beta` (weighted least squares) and for
each row of `Lambda` (one `q x q` solve per trait, with `S_i` entering the system matrix
as an exact, not approximate, contribution). **A full alternating sweep — variational
block, then `beta`, then `Lambda` — drives every gradient block to `<= 1.3e-13` and beats
`nlminb`'s objective at the same start.** This is a complete, checkable "yes" to option
(a) of the brief's menu (closed-form CAVI in alternating blocks) for the case that matches
our engine.

### 1.2 Case B — both `u_i` and `Lambda` carry a real posterior (the brief's literal framing, and dr25's framing)

Design 110 does not cover this case — it has no `q(Lambda)` at all. The brief's own
framing ("where BOTH u_i and λ_j are unknown") and dr25's framing (mean-field
`q(beta)q(alpha_j)...` for a GLMM) both describe the fully-Bayesian mean-field extension,
so it has to be checked separately. **PROVED here, first time in this note.**

Posit independent mean-field factors `q(u_i) = N(m_i, S_i)` and `q(lambda_t) = N(l_t,
Sigma_t)` (`l_t` a `q`-vector, `Sigma_t` a `q x q` covariance), independent of each other
and across `i, t`. The PG/JJ tilting step only ever needs the scalar `eta_it`'s first two
moments under the current `q` — it does not care whether `eta_it` is linear or bilinear in
the unknowns, because the augmentation identity is pointwise in `eta_it` itself:

    mu_it := E_q[eta_it] = a_it + l_t' m_i                (cross term vanishes: E[lambda_t'u_i] = E[lambda_t]'E[u_i])

For the variance, use the standard second moment of a bilinear form in two independent
Gaussians (condition on `lambda_t`, take the trace identity, then integrate over
`lambda_t`):

    v_it := Var_q(eta_it) = Var_q(lambda_t' u_i)
          = tr(S_i Sigma_t) + l_t' S_i l_t + m_i' Sigma_t m_i

This collapses exactly to Design 110's `v_it = lambda_t' S_i lambda_t` when `Sigma_t -> 0`
(point-mass `lambda_t`), which is the internal consistency check that this is the right
generalisation, not a different one.

Re-expand `mu_it^2 + v_it` as a function of `m_i` alone (holding `q(Lambda)` fixed, i.e.
one CAVI block):

    E_q[eta_it^2] = const + 2 a_it l_t' m_i + m_i' M_t m_i + tr(S_i M_t),     M_t := E_q[lambda_t lambda_t'] = l_t l_t' + Sigma_t

**This is Design 110's exact quadratic form with one substitution: `lambda_t lambda_t'`
(the point outer product) becomes `M_t` (the full second moment matrix of `lambda_t` under
its own posterior).** Carrying the same stationarity argument through (the surrogate is
still separately concave in `m_i` and in `S_i`, by the identical argument as Design 110
§2):

    A_i = sum_t w_it M_t + I_q,     S_i = A_i^{-1},     m_i = S_i sum_t l_t (c_it - w_it a_it)

and symmetrically, updating `q(lambda_t)` at fixed `q(u)` (`N_i := E_q[u_i u_i'] = S_i +
m_i m_i'`, and noting gllvmTMB puts **no** prior/KL term on `Lambda` at all — see the
caveat below):

    Sigma_t^{-1} = sum_i w_it N_i (+ prior precision, if any is added),     l_t = Sigma_t sum_i m_i (c_it - w_it a_it)

**Answer to the brief's (a)/(b)/(c):** this is (a), not (b)-as-"too crude" and not (c).
Closed-form CAVI in alternating blocks holds in *both* cases. The mean-field assumption in
Case B is exactly the ordinary, well-understood VB independence cost (below), not a
failure of PG/JJ conjugacy to survive bilinearity.

**What the bilinearity costs, precisely — this is the crux the brief asked for:**

1. **The precision (not the mean) of each block needs the *second moment* of the other
   block, not just its point value or its mean.** `A_i`'s weighted sum uses `M_t = l_t l_t'
   + Sigma_t`; using `l_t l_t'` alone (i.e. treating `Lambda` as known-at-its-mean, the
   naive plug-in) would **understate** `A_i` (since `Sigma_t` is PSD, `M_t ⪰ l_t l_t'`) and
   hence **overstate** `S_i` — silently discarding the extra posterior uncertainty in
   `u_i` that not-yet-resolved loading uncertainty should induce. This is the standard
   empirical-Bayes/plug-in under-statement of uncertainty, appearing here in exact,
   nameable closed form because Gaussian second moments are cheap.
2. **Mean-field breaks the `u`-`Lambda` posterior coupling**, most concretely the
   rotational/reflective near-non-identifiability `Lambda -> Lambda Q`, `u -> Q' u` that
   Design 110 §6.5 already flags as unaffected by its own (Case A) closed form. Neither
   case's alternating updates see this correlation; both need multistart for the same
   reason ordinary BFGS does, and the closed form removes the optimiser, not the
   multimodality.
3. **Case B is a different *model* from what gllvmTMB fits, not just a different
   algorithm for the same model.** Our engine (like `gllvm`'s) never places a prior/KL
   term on `Lambda` — it is a bare MLE parameter (confirmed in §3). Building Case B for
   real would mean choosing and defending a prior on `Lambda`, which is a modelling
   decision with its own consequences (partial pooling of loadings across traits, a new
   hyperparameter), not a drop-in acceleration of the existing fit. Nobody has asked for
   this, and this note is not proposing it — it answers the brief's literal question
   ("does PG survive bilinearity") honestly, not proposing a scope expansion.

**No genuine obstruction (option c) was found in either case.**

---

## 2. How this compares to what we already have (JJ), and whether PG buys anything new

**The JJ bound and PG augmentation are the same object here, not two options.** Design 110
§1 derives this directly from the coded evaluator (`va_r3_jj_softplus_expectation`,
`gllvmTMB_va_r3.cpp:96-113`): the JJ tangent-line bound's optimal free parameter satisfies
`xi*^2 = mu^2 + v` — i.e. the template's own `G = min_xi G_xi` **has already maximised the
PG tilting parameter out analytically**, and at that optimum `w(xi*) = tanh(xi*/2)/(2 xi*)
= E[PG(1, xi*)]` exactly. A hypothetical implementation that instead carried an explicit
variational factor `q(omega_it) ~ PG(n_it, c_it)` and iterated it with `c_it` set from the
current `(mu_it, v_it)` would converge to the identical fixed point, because both routes
are computing the same profile of the same non-conjugate objective (Design 110 §3, via a
Danskin's-theorem tangency argument: `grad_u ELBO_engine(u) = grad_u ELBO_JJ(u, xi*(u))`).
**This equivalence between the JJ tangent-line bound with its parameter profiled out and
the PG augmentation with its auxiliary marginalised is itself a KNOWN result in the
variational-inference literature** (recalled, not re-fetched for this note — see §5); it
is not particular to gllvmTMB. The team's own working shorthand already reflects this: the
2026-07-28 morning brief calls Design 110's finding "the closed-form Pólya-Gamma route" in
the same breath as noting it is "JJ-only" — there is no daylight between the two labels in
this codebase's own usage.

**So: would PG give us anything JJ does not already give us? Little to nothing, and this
should be said plainly.** Three specific non-gains:

1. **Not a new closed form.** The closed-form CAVI sweep Design 110 derived came from
   profiling the JJ bound, not from introducing an explicit PG auxiliary. Re-deriving it
   "via PG" would reproduce the same formulas Design 110 already has and already verified.
2. **Not a new accuracy story.** `docs/design/109-bound-tightness-vs-recovery.md` proves
   (its own PROVED-tagged results, not this note's) that JJ's edge over GH on `Sigma_B`
   recovery in a 20-seed study is a **shrinkage-penalty bias-cancellation** (`∂Delta/∂c >
   0` — JJ's extra looseness acts as an implicit ridge on `Sigma_B`), not evidence that JJ
   is the "more correct" objective — and that paper's own falsification section (item 5,
   the "ridge control") explicitly predicts a plain scalar ridge on GH could reproduce the
   same win, which would mean JJ "has no special status" at all. It also proves
   `S_i(JJ) ⪯ S_i(GH)` in the Loewner order: **JJ under-disperses the variational
   posterior more than GH does, not less.** A faster route to the JJ fixed point is a
   faster route to an answer whose own accuracy story is unresolved and, on the posterior-
   uncertainty axis specifically, worse.
3. **The closest recent in-house precedent for "fast closed form for one link" points the
   same way, for a different family.** Four days before this note, the sibling mature-VA
   arc built an analytically exact closed form for the probit link (Albert-Chib), verified
   it reproduces `gllvm`'s own answer, and then found it **collapses a real ψ variance
   component to ~0 at `n_trials = 6` while the numerically-optimised GH tier correctly
   recovers 0.62** — "disqualifying on its own" in that handover's own words
   (`2026-08-03-claude-handover-mature-va-item1.md`, §3, §"SESSION 2" item 3). The
   resolution adopted there was **not** to ship the closed form as an estimator, but to use
   it only to warm-start the slower, more accurate, numerically-optimised tier (§4 of that
   handover; ~3× fewer iterations, GH's accuracy retained). This is offered as an analogy,
   not a direct test of the JJ/PG case — the mechanism (probit's `∂E/∂v ≡ -n/2` forcing a
   data-independent `A_i`) is specific to Albert-Chib and does not carry over to JJ's
   data-dependent `w_it` — but the *pattern* (fast-and-exact-feeling closed form,
   real risk to a variance component, resolved as a warm start rather than a
   replacement) is exactly the shape Design 109's own JJ-under-dispersion result predicts
   for this case too, and it is the most current relevant experience in this codebase.

If PG-vs-JJ ever mattered, it would be for a link where **no** JJ-type bound exists at
all — and `docs/design/108-va-parity-programme.md` §2 already states this precisely:
"PG augmentation is logit-specific. There is no JJ bound for a probit likelihood." That is
exactly why the sibling arc reached for Albert-Chib (a different closed form entirely) for
probit, not for PG. There is no live gap in this codebase where "PG, as opposed to JJ,"
is the missing piece for the logit/binomial family.

---

## 3. Fit with our architecture

**Confirmed directly, not merely cited from Design 110:**

- `inst/tmb/gllvmTMB_va_r3.cpp:406-423` declares `PARAMETER_VECTOR(beta)`,
  `PARAMETER_VECTOR(theta_rr)` / `PARAMETER_VECTOR(log_sd_tier)` (loadings), and the
  variational block `PARAMETER_VECTOR(m)`, `PARAMETER_VECTOR(log_L_diag)`,
  `PARAMETER_VECTOR(L_off)` **as one flat parameter list** that `TMB::MakeADFun`
  concatenates into a single numeric vector for automatic differentiation. There is no
  block structure visible to the optimiser.
- `R/va-r3-proto.R:1504-1508`: the primary fitting call is
  `stats::nlminb(start, obj$fn, obj$gr, control = control)`, with an
  `stats::optim(start, obj$fn, obj$gr, method = "L-BFGS-B", ...)` alternative a few lines
  later — both quasi-Newton methods operating on the entire flat `start` vector via TMB's
  joint AD gradient. Confirmed again at `:2158-2206`, where the fit routine tries `nlminb`
  first and, if the post-fit gradient gate fails (`max(abs(post_nlminb_gradient)) >=
  1e-4`), polishes with `L-BFGS-B` — still on the same flat vector, never a block sweep.
- `R/va-r3-proto.R:1968-1996`: the `profile_variational` toggle is the closest thing to a
  "different" architecture already present, and it is not a CAVI loop either — when
  `TRUE` it hands the variational block to **TMB's own `random =` mechanism** (its
  internal Laplace-style inner Newton profiling), not to any user-coded closed-form
  update; when `FALSE` (the comment at `:1968-1969` states this is "the shipped route")
  the whole vector, variational block included, goes through the same joint
  `nlminb`/`optim` call as everything else.

**What adopting Design 110's closed-form sweep as the actual fitting method would cost:**

1. **It is not a drop-in.** It replaces the `nlminb`/`optim` call with an alternating
   sweep over `(m_i, S_i)`, `beta`, `Lambda` — a genuine control-flow change, not a
   parameter tweak. Design 110 itself never wired this in: its own header states "No file
   under `R/`, `src/`, `inst/`, or `tests/` was modified," and its cited verification
   scripts (`dev/polya-cavi-verify.R`, `dev/polya-cavi-stress.R`) **do not exist in this
   worktree** — they were run in a now-cleared ephemeral `/private/tmp` worktree and only
   the prose write-up was rescued (`git log`, commit `3cccc396`: *"preserve the 2026-07-27
   VA speed diagnosis from a volatile /private/tmp worktree"*). The `1.6e-15` gradient
   claim is therefore **reported, not currently independently re-runnable** in this repo
   without first reconstructing those scripts.
2. **It would need to reproduce the existing convergence/health-gate machinery from
   scratch.** The current architecture's post-fit gradient gate (`R/va-r3-proto.R:2186-2206`)
   and the four-deterministic-start / bounded-polish scaffolding built for the R3 prototype
   (`docs/dev-log/after-task/2026-07-20-va-r3-prototype-no-go.md`, §2) are built around
   "one flat vector, one optimiser, one gradient norm to check." A sweep-based fixed point
   needs its own convergence criterion (e.g. successive-ELBO-increase below tolerance,
   already measured in Design 110 §5 at "4-5 sweeps" for tiny toy sizes, explicitly
   **not** measured at production scale — Design 110 §3(c): *"AGENT-INFERRED: that this
   sweep count holds at n = 5397, q = 2 is not tested here"*).
3. **It would put TMB's joint AD Hessian at risk for downstream uses that assume it.** The
   2026-07-28 brief's calibrated `se_profile` result (block-diagonal Schur complement
   replacing a dense Hessian, verified to `1.5e-10`) is built on having one joint objective
   TMB can differentiate twice. A sweep-based fit can still call `obj$he()` at the final
   point, but any machinery that assumes the *fitting trajectory* itself is a sequence of
   AD-gradient-based steps (multistart comparison by objective value, `pdHess` diagnostics,
   etc.) would need re-examination.
4. **Rotational non-identifiability (§1) is unaffected**, so multistart requirements do not
   shrink — only the per-start cost changes.

**Conclusion for this section:** yes, treating the closed form as the fitting method
requires abandoning flat-BFGS for at least the variational (and, for the "full sweep",
`beta`/`Lambda`) blocks, and the cost is not merely "write a loop" — it is rebuilding the
convergence/health-gate/diagnostic layer the current architecture gets for free from a
single `nlminb`/`optim` call, for a payoff (§2) that is, on the accuracy axis, neutral to
negative.

---

## 4. Verdict

**PARK.**

**Reason, in two sentences:** the derivation is not an open question — it was already
worked out and numerically verified for gllvmTMB's own bilinear parameterisation a week
before this note, is mathematically identical to the JJ bound the engine already ships
(same fixed point, provable by the tangency argument in §2), and was already parked by the
maintainer on exactly the grounds this note independently reaches (it only accelerates an
evaluator whose own accuracy story, per Design 109, is a fragile bias-cancellation rather
than a genuine improvement); the intervening VA-unfreeze and the sibling mature-VA arc's
closely analogous experience (a fast closed-form tier that had to be relegated to a warm
start, not a replacement, because it silently collapsed a real variance component) update
the supporting evidence but do not overturn that verdict.

**Smallest next step, if this were reopened anyway (not recommended without new evidence):**
do **not** re-derive anything — reconstruct `dev/polya-cavi-verify.R` /
`polya-cavi-stress.R` from the fully-specified formulas already in Design 110 §2 and §5,
re-run them against the *current* `gllvmTMB_va_r3.cpp` (it has moved since 2026-07-27
through the Design 108 / mature-VA work) to re-confirm the `1e-15`-class fixed point still
holds, and if it does, measure exactly one number that has never been measured: wall-clock
of "closed-form sweep as a warm start, then hand off to the existing `nlminb`" against the
current cold-start baseline, on the same cells used in the mature-VA warm-start-from-AC
experiment (`dev/va-speed/`) so the result is directly comparable to the one precedent that
already worked. That is an engineering-value question, not a feasibility question — this
note's job was the latter, and the answer is that feasibility was never in doubt.

---

## 5. What would have to be verified before any of this could be claimed publicly

- **Polson, Scott & Windle (2013, JASA)** — the Pólya-Gamma data-augmentation identity
  itself. Already correctly attributed in this repo's own `docs/design/109-bound-tightness-vs-recovery.md`
  reference list; not re-fetched for this note.
- **Jaakkola & Jordan (2000, Stat. & Comput.)** — the tangent-line bound. Same status:
  already cited in Design 109; not re-fetched here.
- **Hui, Warton, Ormerod, Haapaniemi & Taskinen (2017, JCGS)** — VA for GLLVMs, the paper
  whose model class this whole note is about. Already cited in Design 109.
- **KNOWN, unverified for this note:** the general equivalence between a tangent-line
  variational bound with its parameter profiled out and PG augmentation with its auxiliary
  marginalised (used in §2) is recalled from general training, not fetched from a primary
  source for this note. It should be checked against the mean-field-VI-for-logistic-models
  literature (e.g. Durante & Rigon-type treatments of conditionally-conjugate logistic
  VI) before it is asserted anywhere public.
- **The sharpest and cheapest falsifier of any novelty claim: `gllvm`'s own source.**
  `docs/dev-log/2026-07-31-ranga-eva-literature.md` (Q4) quotes `gllvm` GitHub issue #237
  (opened by a `gllvm` co-author, state OPEN as of 2026-02-20) discussing *"the VA
  polya-gamma set up of this model... at least in the case of logit link"* and concludes
  *"current `gllvm` (2.0.13) evidently now offers *some* VA implementation for logit that
  none of the peer-reviewed papers in this corpus describe or benchmark"* — flagged there
  as **UNVERIFIED beyond the GitHub thread's own wording** and *"a testable question for
  the numerical side, not a literature question."* This was **not checked** for this note
  and is the single most important open item: if `gllvm`'s own shipped C++/R source
  already implements a PG-augmented VA update for the actual bilinear loadings structure,
  then any novelty claim — for gllvmTMB or for the wider literature — is false on its face,
  independent of anything derived in §1. The cheapest falsification step is reading that
  source directly, not deriving further.
- **The dr25 note's "no one has derived this" claim** should not be repeated. It is already
  contradicted by this repository's own committed history (§1, §2) and possibly by
  `gllvm`'s own shipped code (this paragraph). Treat dr25 as a lead that motivated a check,
  not as a description of the state of the art.
- **Design 109's own unresolved item**, inherited by reference, not re-opened here: its
  (G5) conjecture (global monotonicity of the JJ/PG gap in `v`) is stated as unproved and
  gating everything past it in that note. It does not gate anything in *this* note (the
  CAVI closed-form derivation in §1 does not depend on G5), but it remains the actual open
  mathematical question in this cluster of documents, and it belongs to Design 109's scope.
