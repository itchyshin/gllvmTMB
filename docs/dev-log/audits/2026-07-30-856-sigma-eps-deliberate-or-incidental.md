# #856 — is the pooled scalar `sigma_eps` deliberate or incidental?

**Date:** 2026-07-30 · **Author:** Claude (Ada) · **Lane:** `claude/856-sigma-eps-archaeology-20260730`
· **Status:** question ANSWERED; no capability claim moves in this document.

## The question

`src/gllvmTMB.cpp:582` declares `PARAMETER(log_sigma_eps)` — a **single scalar** residual log-SD
shared by every gaussian (fid 0) *and* lognormal (fid 3) row, while every other family's dispersion
is a `PARAMETER_VECTOR ... length n_traits`. #856 asks whether that is deliberate (→ a documentation
gap) or incidental (→ a capability gap), and declines to propose either until answered. It gates
#855, because under per-trait scales one fitted `sigma_eps` back-transforms to `T` raw values.

## Verdict

**Incidental.** Four independent lines of evidence, each re-derived from git or the engine rather
than from a prior summary.

### 1. The scalar originally pooled *three* families, and the pooling was already ruled a defect once

At the original engine commit `12a93bae` the scalar served fids `{0, 3, 4}` — gaussian, lognormal
**and gamma** — while `nbinom2`, `tweedie`, `beta`, `betabinom`, `truncnb2` and `gamma_delta` were
per-trait vectors from day one.

`dff9b363` (2026-07-05, Shinichi) is titled **`fix: decouple gamma dispersion from sigma eps`** —
`fix:`, not `feat:`. Its after-task report (`docs/dev-log/after-task/2026-07-05-gamma-phi-decoupling.md`)
records that a mixed gaussian/gamma canary "would have failed under the old scalar-CV aliasing
because the Gamma CV and Gaussian residual SD are **deliberately different**."

So the maintainer has already ruled that pooling conceptually distinct scales on this one parameter
is a correctness defect. The same reasoning transfers verbatim to gaussian-vs-lognormal: an
identity-scale residual SD and a log-scale residual SD are also different quantities.

### 2. The per-trait promotion was explicitly proposed, then dropped when the issue closed

Issue #622's proposed fix has **two** clauses:

> Give the Gamma family its own dispersion parameter … **and make the Gaussian/lognormal residual SD
> per-trait as well.**

and its failure scenario states the symptom directly: *"The single sigma_eps is also not per-trait,
so multiple Gaussian traits cannot have distinct residual SDs."*

Only clause one shipped. The gamma after-task report scopes itself as "**not a change to
Gaussian/lognormal `sigma_eps`**". The Arc E ground-truth triage (2026-07-09) then recorded "the
Gamma family was re-parameterized to the exact proposed fix" — true of clause one — and #622 was
**closed 2026-07-11 as already-fixed**. Its adversarial verifier did not overturn the verdict.
Clause two was never implemented and never re-filed.

A deliberate design choice does not get proposed as a fix, half-implemented, and closed as done.

### 3. The engine already contains the needed parameter twice, for gaussian's two closest analogues

| family | parameter | shape |
|---|---|---|
| Student-t (fid 9) — identity scale | `log_sigma_student` (`:765`) | **per-trait** |
| delta-lognormal (fid 12) — log scale | `log_sigma_lognormal_delta` (`:776`) | **per-trait** |
| **gaussian (0) + lognormal (3)** | **`log_sigma_eps` (`:582`)** | **one shared scalar** |

Student-t is the heavy-tailed analogue of gaussian and gets per-trait scales; delta-lognormal gets a
per-trait log-scale SD. There is no principled design under which plain gaussian must be pooled but
Student-t must not.

### 4. The identifiability defence does not hold — and the package's own answer is different

Design 66 §4.6 / RE-09 establish that `sigma_eps` needs replicate structure to separate from the
per-trait diagonal `psi`. This is real, but it does not justify the scalar:

- The package's actual answer to that confound is **auto-suppression**, not scalar-ness.
  `R/fit-multi.R:4644-4658` maps `log_sigma_eps` off entirely (`factor(NA)`) when a diagonal term
  sits at per-row resolution.
- The confound the code names is `sd_W[t]^2 + sigma_eps^2` — it bites **even with the scalar**.
  RE-09 itself calls the split "weakly identified" with a "deliberately wide band".

Scalar-ness therefore buys no identifiability; it is one fewer parameter in an already-weak split.

**It does, however, constrain the fix.** With one row per unit×trait and `latent()`'s default
`diag(psi)`, a per-trait `sigma_eps_t` would be *exactly* confounded with `psi_t` — `2T` parameters
for `T` variances. The promotion must be guarded, not unconditional. That guard is the hard core of
the follow-on work, not an afterthought.

## Measured cost

Live fit, replicated design chosen so per-trait SDs *would* be identifiable — this isolates the
restriction from the RE-09 confound. 120 units × 2 gaussian traits × 3 replicates; true residual
SDs 0.2 and 2.0; `value ~ 0 + trait + indep(0 + trait | unit)`.

| quantity | value |
|---|---|
| fitted single `sigma_eps` | **1.4292** (`opt$convergence == 0`) |
| RMS of the true SDs — the best a single scalar can represent | 1.4213 (ratio **1.006**) |
| model-free within-cell (unit×trait) estimate of each SD | **0.197** and **2.012** |

The scalar lands exactly on the RMS compromise, as theory predicts. Trait 1's residual SD is
reported **7.1× too large**, trait 2's **1.4× too small**. The model-free estimator recovers both
truths essentially exactly, so **the per-trait information is fully present in the data** — the
restriction is *expressive, not informational*.

Reproducers: `dev/856-sigma-eps-pooled-cost.R` (this measurement) and
`dev/856-sigma-eps-degenerate-probe.R` (the no-replicate case).

## Correction to #856's own framing

#856 states that grepping `sigma_eps` over `man/`, `NEWS.md` and `vignettes/` "returns only the
`check_gllvmTMB()` threshold argument and a `confint_inspect()` example". Re-derived on 2026-07-30,
that is an **under-count**. User-facing sites include `man/diag_re.Rd:135-152` (an entire
auto-suppression subsection, from `R/unique-keyword.R:125-150`), `man/extract_Sigma.Rd:186`,
`man/profile_targets.Rd:21,29,55`, `man/check_gllvmTMB.Rd:14,59-60`, and three vignettes.
`NEWS.md` has zero mentions. The singleness *is* stated once, at `R/unique-keyword.R:127`, in the
context of auto-suppression — so "undocumented" overstates it, while the docs surface needing
update is larger than the issue implies.

## Found in passing — a stale claim, independent of #856

`R/unique-keyword.R:127` reads *"For Gaussian / lognormal / **Gamma** fits, the engine also estimates
a single observation-scale residual `sigma_eps`."* The Gamma half has been **false since 2026-07-05**
(`dff9b363`); ground truth is `src/gllvmTMB.cpp:312` (`family_id_vec(o) in {0, 3}`) and
`R/fit-multi.R:4630` ("Ordinary Gamma (fid 4) has per-trait `log_phi_gamma` shape").

Worth noting *how* it survived: the gamma decoupling's own consistency audit ran the regex
`Gamma.*sigma_eps`, which matches this line, and classified the remaining hits as "intentional
boundary wording that explicitly contrasts Gaussian/lognormal `sigma_eps` with ordinary Gamma
`phi_gamma`". This line does not contrast — it asserts. The right regex was run and the verdict
misclassified the hit.

Not stale, do **not** "fix": `R/extract-sigma.R:1437`'s `fids %in% c(0L, 3L, 4L) # gaussian /
lognormal / Gamma` is a *continuity* test, not a `sigma_eps`-ownership claim.

## What this changes for #855

#855 must make `sigma_eps` trait-aware on the way out regardless. If it is a genuine per-trait
vector **first**, #855's back-transform collapses to a per-trait multiply (`sigma_eps_t * s_t`)
instead of a one-value→`T`-values semantic change across `report$sigma_eps`, `simulate()`'s noise
draw and `extract_residual_split()`. Sequencing #856 first therefore **removes** risk from #855.

## The twin does NOT support the case — and a durable claim is refuted

A prior internal note (the 2026-07-03 twin-review handover) records that GLLVM.jl "folds residual
into `diag(psi)`", i.e. per-trait by construction. **That is false.** Verified at code level:

- `GLLVM.jl/src/likelihood.jl:73` — `gaussian_marginal_loglik(y, Λ_B, σ_eps::Real; …)`
- `GLLVM.jl/src/likelihood_sparse_phy.jl:110` — same signature, `σ_eps::Real`
- `GLLVM.jl/src/em_squarem.jl:59-60` — `_pack_phylo(Λ_B, σ_eps::Real, σ_phy::AbstractVector) =
  vcat(vec(Λ_B), float(σ_eps), Vector{Float64}(σ_phy))` — `σ_eps` is packed as a **single float**
  next to `σ_phy`, which *is* a vector.

So **both** implementations pool the gaussian residual SD on a scalar. This is an honest complication:

- It **removes twin parity as an argument** for the promotion. It is not cited as support above, and
  must not be cited later.
- It is mild evidence *toward* "a single residual scale is a common simplification in this model
  family" — i.e. the counter-position is not unreasonable.
- It does **not** touch the three load-bearing arguments, which are all internal to gllvmTMB:
  #622's clause two was proposed and dropped; this codebase gives Student-t and delta-lognormal
  per-trait scales while denying gaussian one; and the measured cost is real with the information
  demonstrably present in the data.
- Scope differs: GLLVM.jl's gaussian path is phylo-structured and does not carry gllvmTMB's
  mixed-family stacked-trait grammar, where traits in different physical units are the motivating
  case. A pooled residual is less consequential there.

**Record correction owed:** the 2026-07-03 handover's twin-review line is wrong and should be marked
so. Per the Rose principle, the other unverified entries in that same twin-review list (ordinal link,
phylo variance scale, psi/residual semantics, W-tier reduced-rank) deserve the same code-level check
before any of them is used as a basis for work — this one was taken on trust and did not survive.

## Status of claims in this document

Archaeology and the code-shape comparison are **verified** against git and `src/`. The GLLVM.jl
comparison is **verified** and **refutes** a prior durable claim. The measured cost is **one
configuration, one seed** — sufficient to demonstrate the restriction, not a coverage claim. The
degenerate (no-replicate) case is measured separately before any guard is designed, not assumed.
No public capability claim moves on this document.
