\
# VA-R3 conditioning audit vs. gllvm 2.0.13's three parameterisation choices

**READ-ONLY AUDIT. Nothing in the repository was changed to produce this
document.** Worktree `/private/tmp/gllvmtmb-va-lane2` (branch `claude/va-lane2`),
inspected with `grep`/`git log`/`git show`/`Read` only — no edit, no compile, no
`R` invocation.

## Purpose

`dev/va-speed/21-WHY-GLLVM-IS-FAST.md` (an existing repo research note, dated
2026-08-03, `git show 69c4f3f9`) established that gllvm 2.0.13's speed is a
**conditioning** effect, not an algorithmic one: a single flat BFGS converges
because three parameterisation choices remove flat/ill-conditioned directions
from the objective. That note ends by naming two open questions about our own
`va_r3` engine (whitening, log-Cholesky) and one already-answered one (the
loadings diagonal is unconstrained, PR #919). This document closes those open
questions with file:line evidence, and separately verifies that PR #924
(merged same day, `e8d18cc8`) does not collide with the VA engine's
parameterisation.

Everything about gllvm itself is carried over from that pre-existing note (in
turn sourced from a `download.file()`'d copy of gllvm's GPL-2 `src/gllvm.cpp`,
"quoted for comparison only, nothing copied" per its own provenance section);
this audit did not re-fetch or re-read gllvm's source. Everything about *our*
code below was independently located and read in this session.

## Choice 1 — identifiability hard-coded (diagonal pinned to 1 + separate scale)

**gllvm's choice** (per `dev/va-speed/21-WHY-GLLVM-IS-FAST.md:43`, citing
`gllvm.cpp:295-306`): upper triangle of Λ set to 0, diagonal pinned to 1, scale
carried by a separate `sigmaLV` parameter.

**What we do.** `inst/tmb/gllvmTMB_va_r3.cpp:628-660` reconstructs each dense
tier's loading matrix from `theta_rr` (`PARAMETER_VECTOR(theta_rr)`,
`gllvmTMB_va_r3.cpp:407`) as raw diagonal, then strict lower triangle:

```
645: for (int j = 0; j < d; ++j) {
646:   for (int t = j; t < T; ++t) {
647:     if (t == j) {
648:       Lk(t, j) = lam_diag(j);
```

`lam_diag(j)` (cpp:643, `theta_k.head(d)`) is assigned **verbatim** — no
`exp()`, no `fabs()`, no bound. The strict upper triangle is zero by
construction (`Lk.setZero()`, cpp:640, never written above the diagonal), which
does fix the continuous rotational indeterminacy, exactly as gllvm's does — but
nothing fixes the diagonal's sign or magnitude. `Sigma_B = Lambda *
Lambda.transpose()` (cpp:660) has no separate multiplicative scale anywhere in
it. There is no `sigmaLV`-analogous `PARAMETER_VECTOR` for the dense/ordinary
tier: `log_sd_tier` (cpp:409, `PARAMETER_VECTOR(log_sd_tier)`) exists, but it
scales a **different** kind of tier (`tier_kind == 1`, trait-diagonal
Psi/unique/indep tiers), not tier 0's dense Λ.

R-side confirmation: the only `map` (fixed-parameter) entries constructed in
`.va_r3_make_objective()` (`R/va-r3-proto.R:1922-1967`) gate `log_phi`/`log_sigma`
per-trait by family (lines 1925-1939), or — under an opt-in, all-or-nothing
`fixed_global` argument — fix **all** of `beta` and `theta_rr` at once
(lines 1940-1966). Nothing fixes only the diagonal subset of `theta_rr`.

**Git-history confirmation.** Commit `e45a11fb` ("docs: the loadings diagonal
is unconstrained -- correct the claim everywhere (#919)") measured the
consequence directly: the paired flip `(Lambda_.k, z_.k) -> (-Lambda_.k,
-z_.k)` leaves the joint density invariant to `0.000e+00`. That commit is
docs-only (`git show --stat e45a11fb`: 7 files, all `.md`/one test file, zero
`.cpp`/`.R` source changes) — it corrected claims about pre-existing behaviour,
it did not change the engine.

**This is package-wide, not VA-specific.** The identical raw-diagonal pattern
recurs at 8 sites in the Laplace/AGHQ engine, `src/gllvmTMB.cpp` (`Lambda_B`
line 964, `Lambda_B_slope` 1044, `Lambda_W` 1120, `Lambda_phy` 1216,
`Lambda_kernel` 1320, `Lambda_phy_slope` 1587, `Lambda_spde` 1666,
`Lambda_spde_slope` 1900), documented at `src/gllvmTMB.cpp:17-21` as "a direct
port from glmmTMB src/glmmTMB.cpp ... filled column-by-column with strict
upper triangle zeroed for identifiability" — no diagonal constraint is
mentioned there either.

**Verdict: DIFFERS from gllvm.** Absent in both our engines, not just VA.

### If it differed: what would have to change

A gllvm-style pin would need, at minimum:

1. A new `PARAMETER_VECTOR` (e.g. `log_delta`, length `q`) in
   `gllvmTMB_va_r3.cpp`.
2. The Lambda-construction loop (cpp:645-654) changed to hard-set `Lk(t,j) =
   Type(1.0)` for `t == j`, dropping the diagonal from `theta_rr`'s packed
   length — which changes `.va_r3_theta_length()`'s formula
   (`R/va-r3-proto.R:9-13`, currently `T*q - q*(q-1)/2`) and every call site
   that packs/unpacks against it: `.va_r3_unpack_theta_rr()` (line 27),
   `.va_r3_pack_theta_rr()` (line 50), and their 5 in-file call sites (lines
   1026, 1028, 1054, 1961, 2141).
3. The `mu`/`v` accumulation loop (cpp:845-861) multiplied by the new scale
   per latent coordinate.
4. Default/warm-start initialisation (`.va_r3_default_parameters()`,
   `.va_r3_warm_theta_rr()`, `R/va-r3-proto.R:1004-1057`) reworked to supply
   `log_delta` and a reduced-shape `theta_rr` start.
5. An unquantified but nonzero set of `dev/` scripts and 2+ test files
   (`tests/testthat/test-va-r3-prototype.R`,
   `tests/testthat/test-phylo-latent-slope-gaussian.R`) that reference
   `theta_rr`'s current shape or `lam_diag` — a broad grep matched ~23 `dev/`
   files on this pattern; **not individually verified**, reported as a lower
   bound on the blast radius, not a count.
6. Doing this **only** in the VA engine would break the documented
   "exact live-engine reconstruction" parity with `src/gllvmTMB.cpp` that
   `gllvmTMB_va_r3.cpp:628` asserts by comment; doing it **everywhere** is a
   package-wide, likelihood-affecting change that Design 72 s7 reserves for
   the maintainer and Codex, not an R-side conditioning tweak
   (`R/va-routing.R:5-6`). Either way this is a materially larger change than
   the other two choices.

### Is it identifiability-neutral?

Worked algebraically, not asserted. For any point where Λ's current diagonal
entries are all nonzero, `Λ = Λ₁ · diag(δ)` with `Λ₁[,c] = Λ[,c] / Λ[c,c]` and
`δ_c = Λ[c,c]` is an **exact bijection** onto (unit-diagonal matrix, signed
scale) pairs — a relabelling that reproduces the same `Sigma_B = ΛΛᵀ` for every
parameter value. That makes a **free-signed** `δ` a pure reparameterisation:
**identifiability-neutral**, no change to the fitted model, and the KL block
(cpp:749-781, which only ever reads `m`/`log_L_diag`/`L_off`, never `Λ`) is
untouched by construction.

If instead `δ` is constrained positive (`exp(log_delta)`, the conventional way
to parameterise a "scale" in this kind of code, but **not confirmed** for
gllvm's actual `sigmaLV` — nothing in this repository's notes records its sign
convention) — then the bijection above breaks at the boundary: a pinned +1
diagonal times a strictly-positive δ can never reach the negative-diagonal
half of parameter space our current free diagonal admits. That would
*additionally* resolve the discrete `2^q` sign-flip degeneracy PR #919
measured, rather than merely relabel it. Per that same commit, every quantity
the package actually reports from Λ — `Sigma_unit`, correlations,
communalities, ICC — is already documented sign-invariant, so resolving that
degeneracy would not change any **reported** estimand. It would still not be
the *same parameterisation*, only *the same estimand under a narrower one*.

**Verdict: identifiability-neutral for every quantity the package reports,
either way. UNCERTAIN whether it is also a parameter-for-parameter bijection
throughout, because that depends on a sign convention for gllvm's `sigmaLV`
this repository does not record and this audit was told not to invent.**

## Choice 2 — whitened / non-centred latents

**gllvm's choice**: prior exactly `N(0, I)`, so the KL needs no inverse and no
prior log-determinant; scale is applied *after* the KL by rescaling `u` and
`A(i)` directly (`dev/va-speed/21-WHY-GLLVM-IS-FAST.md:44`).

**What we do — MATCH, for the default (non-structured) tier.** The dense,
unstructured KL (`tier_structured(k) == 0`, the ordinary `latent()`/`rr()`
case) is:

```
762-771: trace_S = Σ Li(row,col)²           (read off the Cholesky factor)
         mean_sq = Σ m(...)²                 (m'm)
         logdet_S += 2·log_L_diag(...)       (Σ 2·log-diag, cpp:768)
780:  kl = 0.5 · (trace_S + mean_sq - logdet_S - d)
```

This is exactly `KL(N(m, LLᵀ) ‖ N(0, I))`: no inverse anywhere, and no prior
log-determinant term — not "computed as zero", **structurally absent**,
because `log|I| = 0` is never written down at all. The trait-diagonal
(`tier_kind == 1`) case is the same formula specialised to 1-D
(cpp:732-738: `kl += s*s + m² - 2·log_s - 1`).

`mu` is accumulated directly from the raw variational mean, with no
post-hoc rescale: `mu += Lam(t, c) * m(mo + c * nk + g);` (cpp:847) — `m` plays
exactly the role of gllvm's whitened `u`. The reason we need no separate
"apply `Δ` after the KL" step is that Choice 1 is already different for us:
scale lives in Λ's own (unconstrained) diagonal from the start, so there is
nothing left for a post-KL rescale to do. The two choices are coupled this
way; see "What is uncertain" below.

**Independent design-doc corroboration** (not derived from the code, a
separate artifact): `docs/design/85-highdim-nongaussian-va-formal-contract.md`
—

- line 192: `` `sum_i KL{N(m_i,S_i) || N(0,I_q)}` ``
- line 285: `u_i` ... "iid `N_q(0,I_q)`"
- line 290: `KL_i` | "prior is exactly `N(0,I_q)`" | `` `0.5*(sum(L_i^2)+m_i^Tm_i-2sum(rho_i)-q)` ``

— matching the C++ formula term-for-term (`rho_i` = `log_L_diag`).

**Independent cross-engine corroboration**: the Laplace/AGHQ engine uses the
identical spherical prior on its own latent scores, `src/gllvmTMB.cpp:976`:
`nll -= dnorm(col_s, Type(0), Type(1), true).sum();` — whitening is a
package-wide convention here too, not something special-cased for VA-R3.

**Caveat — structured extra tiers.** A `tier_structured(k) == 1` tier (phylo /
pedigree / dense-kernel, `gllvmTMB_va_r3.cpp:401,693,701-710,773-778`) has
prior `N(0, A)` for a **fixed, externally supplied** (`DATA_SPARSE_MATRIX
Ainv_struct`, `DATA_SCALAR log_det_A_struct`, cpp:402-404) structure `A`, not
literally the identity. Its KL does carry a `log_det_A_struct` term
(cpp:706-709, added once per tier as `kl_const_by_tier`) and an `Ainv`-weighted
quadratic form (cpp:700-705,724,777). The design comment at cpp:362-372 frames
this as a deliberate "STANDARDIZED-FIELD convention" that keeps scale in the
*loading*, not the prior — the same philosophy as the default case, just
extended to a non-identity but still-fixed structure. Two things keep this
from complicating the "MATCH" verdict above in practice: (a) `Ainv` is
supplied as DATA, so no matrix inverse is ever computed **on the AD tape** —
only a sparse matrix-vector product and scalar lookups; (b) this path is
currently **fenced off** the public route — `R/approximation-engine.R:94-98`
records that `R/integration-fence.R` "still refuses `unique = TRUE` and every
phylo/spatial term under `integration = "va"`" — so no user-facing VA fit
today actually exercises the non-identity-prior branch; the plain whitened
case is what every reachable fit uses.

**Verdict: MATCHES gllvm's choice 2** for the tier every current VA fit
actually uses; the structured extension is a documented, currently-inactive,
fixed-non-identity variant of the same design philosophy, not a departure from
it.

## Choice 3 — A_i as a log-Cholesky factor

**gllvm's choice**: `exp()` on the diagonal, free off-diagonals;
positive-definiteness is free, `log|A|` is a sum of logs rather than a
decomposition on the tape (`dev/va-speed/21-WHY-GLLVM-IS-FAST.md:45`).

**What we do — MATCH, exactly.**

```
gllvmTMB_va_r3.cpp:418  PARAMETER_VECTOR(log_L_diag);  // log Cholesky diagonals
gllvmTMB_va_r3.cpp:419  PARAMETER_VECTOR(L_off);        // strict-lower Cholesky entries
...
753:  Li(c, c) = exp(log_L_diag(mo + c * nk + g));
757:  Li(row, col) = L_off(oo + off_pos * nk + g);
768:  logdet_S += Type(2.0) * log_L_diag(mo + row * nk + g);
```

`exp()` on the diagonal guarantees positive-definiteness with no constraint on
`L_off`; `logdet_S` is a running sum of `log_L_diag` entries — a sum of logs,
not a determinant computed from an assembled matrix. The trait-diagonal
(`tier_kind == 1`) case is the same idea specialised to 1×1 (cpp:727-728:
`log_s = log_L_diag(...); s = exp(log_s);`).

Design-doc corroboration: `docs/design/85-...md:286` — "`S_i=L_iL_i^T` ...
unit-specific full variational covariance; **log Cholesky diagonal**"; line
290's KL formula uses `rho_i` (`= log_L_diag`) directly, the same object.

**Verdict: MATCHES gllvm's choice 3 exactly.** No change needed, none
proposed.

## Two-stage restart

**Searched for** (none found): `grep -rn` across `*.R`/`*.cpp`/`*.md` for
`diag.*to.*unstruct|unstruct.*from.*diag|starting\.val|two-stage restart|
restart.*diag|diag.*restart` in `R/`, `inst/tmb/`, `src/`; `grep -n "restart|
warm.*start"` in `R/eva-proto.R`, `R/approximation-engine.R`,
`R/va-routing.R` (zero hits in all three). No mechanism anywhere in our R code
fits the model once at `tier_kind == 1` (diagonal) and then re-fits it at
`tier_kind == 0` (dense/unstructured) as a warm-started second stage; a fit's
tier layout is a fixed `DATA_IVECTOR` set once from R and never escalated
mid-fit.

**What we do have, on a different axis.** `.va_r3_fit_warm()`
(`R/va-r3-proto.R:1337-1379`) is a genuine two-stage restart, but across
**evaluation method**, not covariance structure: stage 1 fits the
Albert-Chib (AC) closed-form probit bound (`ac_args$eval_method <- "ac"`,
line 1347), stage 2 polishes on Gauss-Hermite (GH) quadrature starting from
the AC optimum (`stats::nlminb(start = ac$best$par, ...)`, line 1369). Both
stages fit the **same** covariance structure throughout — only the likelihood
bound changes between stages. Measured (comment, lines 1328-1334): 3.8x fewer
outer iterations at the same optimum.

Separately, `.va_r3_warm_theta_rr()` (`R/va-r3-proto.R:1004-1033`) is a
**single-stage** (one optimisation, not two) analytic warm *start* for the
loadings: an eigendecomposition of link-scale residual correlations, explicit
comment "mirrors gllvm's `starting.val = "res"`" (line 979). This supplies a
better initial value; it does not run a first, coarser optimisation.

**On record about gllvm's own restart.** `dev/va-speed/21-WHY-GLLVM-IS-FAST.md`
quotes gllvm's own measured optimiser trace (lines 29-32) showing exactly this
staging in gllvm itself: `optim npar=459 ... (stage 1, A diagonal)` then
`optim npar=559 ... (stage 2, A unstructured, warm-started)`. That file also
records an explicit decision (line 99): **"Do not port their two-stage
restart. It is scaffolding for a problem the collapse deletes."** — made in
the context of the (separate, out-of-scope for this audit) `A_i` closed-form
opportunity the same note describes, not a general verdict against restart
machinery as such. A broader literature check (`dev/va-speed/LITERATURE.md:
179-182`) independently reports this specific technique — "fitting a diagonal
`S` first, then relaxing to block-diagonal/unstructured" — as a **stated gap**
in the corpus it searched, distinct from the (well-attested) initial-value-only
`starting.val = "res"` technique we do use.

**Verdict: ABSENT in the gllvm sense (diag-covariance-first restart); PRESENT
on a different axis (AC→GH bound restart); a decision is already on record not
to port gllvm's version, scoped to the A_i-closed-form context.**

## KL/entropy term as computed

Per level `g` of a dense (`tier_kind == 0`), non-structured tier:

```
kl = 0.5 · ( tr(S_g) + mᵀm − log|S_g| − d )
```

read directly off the log-Cholesky parameters — `tr(S_g)` from squared
Cholesky entries (cpp:762-771), `log|S_g|` as `2·Σ log_L_diag` (cpp:768) — no
matrix is ever assembled to take its determinant. Summed over levels and
tiers into `total_kl = kl_by_level.sum() + kl_const_total` (cpp:953), which
enters the objective as `elbo = expected_loglik − total_kl` (cpp:954),
`negative_elbo = −elbo` (cpp:955), the value TMB actually minimises
(`return negative_elbo;`, cpp:1001).

**Does it need a matrix inverse or a prior log-determinant that whitening
would remove?** For the default (non-structured) tier: **no inverse, ever**
(never computed, on-tape or off), and **no prior log-determinant term at
all** — not a zero placeholder, the term is structurally absent because the
prior is fixed at `N(0,I)` and `log|I| = 0` is simply never written. This is
precisely the thing whitening is supposed to remove, and it is already
removed. For a `tier_structured == 1` tier only, a prior log-determinant
(`log_det_A_struct`) and an `Ainv`-weighted quadratic form do appear
(cpp:700-709,724,777) — but `Ainv` is supplied as fixed DATA, so even there
no inversion happens on the AD tape; and (per Choice 2's caveat) this branch
is not reachable from the public `integration = "va"` route today.

## PR #924 scope check

**Confirmed via `gh pr view 924`**: merged as `e8d18cc8`, 2026-08-03T18:27:39Z,
title "Fix standardized-loading inference". Files touched: `NEWS.md`,
`R/loading-ci-bootstrap.R`, `R/loading-ci.R`, `R/loading-uncertainty-helpers.R`,
`R/plot-loadings-confidence-eye.R`, `R/suggest-lambda-constraint.R`,
`R/z-confint-gllvmTMB.R`, three `docs/design/*.md`, two `docs/dev-log/*`,
2 new `docs/dev-log/{after-task,plans}/*` files, 6 `man/*.Rd`, 3
`tests/testthat/*.R`. No `.cpp` file, no `R/va-r3-proto.R`, no
`R/approximation-engine.R`, no `R/va-routing.R`.

**Topical check.** `grep -n "va_r3|va-r3|VA_R3|variational"` across all 6
changed `R/*.R` files returned **zero matches**.

**What the touched code actually is.** `R/loading-ci.R:1-8` states its own
scope: "The maths is the delta method on a numerical Jacobian ... The
covariance is the complete `fit$sd_report$cov.fixed` matrix" — post-hoc
inference on an **already-fitted** model's TMB `sdreport()` Hessian-based
covariance and a numerical Jacobian of a reported quantity (`rho[t,k] =
Lambda[t,k] / sqrt(Sigma_total[t,t])`). It reads a fitted Λ; it does not touch
how Λ/`theta_rr` is parameterised or optimised.

**Structural guard, not just topical distance.** `loading_ci()` requires
`inherits(fit, "gllvmTMB_multi")` and aborts otherwise
(`R/loading-ci.R:119-120`). `suggest_lambda_constraint()` repeats the same
guard at 4 call sites (`R/suggest-lambda-constraint.R:140,264,301,364`). A
VA-routed fit is classed `c("gllvmTMB_va", "gllvmTMB")` — **not**
`gllvmTMB_multi` (`R/va-routing.R:432`) — so both functions are unreachable
from a VA fit by construction, not merely "not yet exercised together."
Independently, `R/va-routing.R:427-430` documents `fit$calibrated <- FALSE`
for every VA fit because "the inverse VA Hessian is NOT calibrated frequentist
uncertainty (Design 85 s10) ... 0.6 ships this route with no standard errors
and no intervals" — so even without the class guard, the SE/CI machinery
#924 improved has nothing to attach to on a VA fit today.

**Verdict: CONFIRMED, no collision** — by file overlap (zero), by design intent
(post-hoc inference on a point estimate, not a parameterisation), and by a
structural class-dispatch guard that makes the two code paths mutually
unreachable. The task's stated hypothesis is correct.

## Summary table

| Choice | Ours | gllvm | Differs? | Identifiability-neutral if changed? | Est. change size |
|---|---|---|---|---|---|
| 1. Diagonal pinned to 1 + separate scale | Λ diagonal unconstrained (raw, no `exp`/`fabs`/bound); no separate scale param for the dense tier; scale lives in Λ itself | Diagonal pinned to 1; scale in separate `sigmaLV` | **Differs** | Free-signed replacement scale: **yes**, exact bijection. Positive-constrained replacement scale: neutral for every *reported* quantity (PR #919 sign-invariance), **UNCERTAIN** whether parameter-for-parameter neutral (gllvm's own sign convention for `sigmaLV` not established here) | Largest of the three: new PARAMETER_VECTOR, changed `theta_rr` packing (≥3 helper fns, ≥5 in-file call sites, unquantified test/dev surface), and a parity question against the Laplace engine's identical convention (8 sites in `src/gllvmTMB.cpp`) |
| 2. Whitened / non-centred latents | KL against `N(0,I)`, no inverse, no prior log-det, for every currently-reachable tier | Same | **Matches** (structured-tier extension is a documented, currently-fenced-off variant, not a departure) | N/A — already our behaviour | None |
| 3. `A_i` as log-Cholesky | `exp()` diagonal, free lower, log-det = sum of logs | Same | **Matches** | N/A — already our behaviour | None |

## What is UNCERTAIN, and how to settle it

1. **gllvm's `sigmaLV` sign convention** (free-signed vs. positive-constrained)
   is not recorded in this repository's own prior research note and was not
   re-derived here (out of scope: nothing from gllvm's source may be
   re-read/copied for this audit beyond what the existing note already
   quotes). This is the one fact that would convert Choice 1's
   "identifiability-neutral for every reported quantity, uncertain beyond
   that" into a clean single verdict. **To settle:** re-open the existing
   `download.file()`'d `gllvm.cpp` copy (or the deparsed R) that produced
   `dev/va-speed/21-WHY-GLLVM-IS-FAST.md` and check whether `sigmaLV` (or its
   log/other transform) is declared with an unconstrained or transformed
   (e.g. `exp()`) parameter type; quote for comparison only, as that note
   already does.
2. **Blast radius of a Choice-1 migration on `dev/`/test files** is reported
   here as a grep hit-count (~23 `dev/` files, 2 test files) on broad patterns
   (`theta_rr`, `lam_diag`), **not individually verified** — several of those
   hits may be unrelated (e.g. Laplace-engine test fixtures that happen to
   share vocabulary). **To settle:** read each matched file's actual
   dependency on `theta_rr`'s shape before scoping any implementation.
3. **Whether the structured-tier KL path (Choice 2's caveat) will ever reach
   the public API** depends on `R/integration-fence.R`'s current refusal of
   `unique = TRUE` and phylo/spatial terms under `integration = "va"`. That
   fence is a live, separately-owned gate (Design 108 evidence-gated per the
   comment at `R/approximation-engine.R:94-98`); this audit did not check its
   current state beyond the one comment cited. **To settle:** read
   `R/integration-fence.R` directly if the structured-tier caveat becomes
   load-bearing for a future decision.
4. **This worktree had uncommitted, very-recently-modified files not produced
   by this audit** — `dev/va-speed/20-CLAIMS-LEDGER.md`,
   `dev/va-speed/21-WHY-GLLVM-IS-FAST.md`, `dev/va-speed/23-warm-route-confirm.R`
   (all modified), plus an untracked `docs/design/ai-collapse-design.md` — all
   with modification times within ~8 minutes of each other and of this audit's
   own start, apparently connected to the separate `A_i` closed-form work the
   same research note describes. A `diff` against `git show HEAD:...` confirmed
   the one file this audit cites (`21-WHY-GLLVM-IS-FAST.md`) was stable across
   the citation (no drift during this audit), so the citations above are
   accurate as of this reading — but the presence of an uncommitted,
   actively-edited file in a worktree this task described as available for a
   read-only audit is itself worth flagging to whoever is coordinating lanes,
   independent of this audit's substantive findings.
