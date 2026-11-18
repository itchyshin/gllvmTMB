# Five GLM-outer atoms — Poisson, NB2, NB1, beta, Tweedie (planned tapes)

**Status:** symbolic alignment only. **No family is admitted.** Public
`estimator = "mspl"` after this lane is **gaussian, bernoulli, and
Poisson**; NB1, NB2, beta, and Tweedie still error at
`.gllvmTMB_mspl_prepare()`. NB2 stays `excluded` in the registry; NB1,
beta, and Tweedie have **no** registry row at all. No NEWS `covered`,
no validation-register promotion, no SE.

**Reader:** Noether/Gauss reviewers and the single `src/gllvmTMB.cpp`
owner who must check that the five taped weights say what the symbols
say.

**Lane:** `cursor/mspl-phase4-tapes-planned`, kit
`docs/dev-log/lanes/cursor-mspl-phase4-tapes-planned/LOOP/`.
**Programme constitution:**
`docs/dev-log/after-task/2026-08-14-laplace-mspl-estimator-programme.md`.
**Poisson prep:** `docs/dev-log/research/2026-08-15-mspl-phase4-poisson-prep.md`.

This is **LA-MSPL** — Laplace integration with a soft *outer* penalty —
not EVA, not VA, not AGHQ-MSPL.

## 1. What these five atoms are, exactly

Each atom is the **GLM-outer** candidate

\[
P^*(\theta)=\tfrac12\log\det\bigl(X_*^\top W X_*\bigr),
\qquad
W=\operatorname{diag}\bigl(w(\eta_o)\bigr),
\qquad
\eta_o=(X_{\mathrm{fix}}b_{\mathrm{fix}})_o+\mathrm{offset}_o,
\]

evaluated at the **fixed-effect linear predictor only, BEFORE any latent
score** \(\lambda_t^\top u_i\) enters. \(X_*\) is the resolved free
mapped fixed design (`X_mspl`), and the row weights are supplied on the
log scale by the shared family-dispatch hook
`gll_mspl_log_weight_glm()`; the half-log-determinant is formed by
`gll_mspl_atomic_half_logdet(log w, X_mspl)`.

**This is not \(I_{\mathrm{LA}}(\beta)\).** It is not the
Laplace-marginal information of the outer parameters, not the marginal
observed information, and not the conditional random-effect Hessian
\(H_u\). Naming it a Laplace-marginal \(I(\beta)\) is a kill: the
marginal information for \(\beta\) in a GLLVM mixes \(\Lambda\), \(u\),
and the dispersion block, and none of that appears in \(X_*^\top W X_*\).
The GLM-outer object is a *candidate soft atom whose coercivity must be
proved family by family*, exactly as the Poisson prep note states for
its own row.

On the maximisation scale the criterion is
\(\ell_{\mathrm{LA}}(\theta)+c\,P^*(\theta)+\dots\); TMB minimises the
sign-reversed form, so the tape adds \(-c\,P^*\) to `nll`.

**The rate \(c\) stays symbolic.** For all five families here \(c=1\)
(unit scale) in the planned tapes. Bernoulli
\(c_n=2\sqrt{p_{\mathrm{free}}/N_{\mathrm{eff}}}\) and Gaussian
\(c_N=\sqrt{2/N}\) are **rejected transplants** until a family-specific
rate argument is written against the actual Laplace objective. A unit
\(c\) is a placeholder, not a derived rate; it does not vanish with
\(N\), so nothing here is yet a "soft, ML-equivalent" penalty.

## 2. Five-row symbolic alignment table

| family | family_id | public mspl? | registry | atom \(W\) or \(I\) | log-weight \(\log w(\eta)\) | hostility note |
|---|---|---|---|---|---|---|
| Poisson (log) | 2 | **yes** — planned fenced tape, experimental, not admitted | `poisson:log:ordinary:q1,q2` = `planned`, `evidence = "phase4_prep"` | \(W=\operatorname{diag}(\mu)\), \(\mu=e^{\eta}\) (exposure inside \(\eta\)) | \(\log w=\eta\) | Cleanest row: no dispersion parameter, so the atom is a pure function of \(\beta\). Coercive **one-sidedly only** — \(P^*\to-\infty\) as \(\mu\to0\) (all-zero / \(\beta\to-\infty\)), nothing controls \(\mu\to\infty\), and the latent loading runaway on the log-mean scale is **untouched and unproved**. Exposure \(\sum E\) is not \(N_{\mathrm{eff}}\); \(c=1\) is unpinned. |
| NB2 (log) | 5 | **no** — prepare rejects at the `family_id` fence | `nbinom2:log:ordinary:q1` = `excluded` (`"NB2 waits for Phase 4 after Poisson admission gate"`) | \(W=\dfrac{\mu\varphi}{\varphi+\mu}\), harmonic in \((\mu,\varphi)\) | \(\log w=\eta+\log\varphi-\operatorname{logspace\_add}(\eta,\log\varphi)\) | Couples the **mean** atom to a **dispersion** boundary it was never derived for: \(w\to0\) as \(\varphi\to0\), so \(P^*\to-\infty\) and the atom acts as an implicit push toward \(\varphi\to\infty\), i.e. toward the Poisson limit — it silently penalises genuine overdispersion. It also saturates: \(w\le\min(\mu,\varphi)\), so at large \(\mu\) the weight is \(\approx\varphi\), flat in \(\beta\), and the mean-boundary signal is weaker than Poisson's. Two boundaries, one atom, no theorem. |
| NB1 (log) | 15 | **no** — prepare rejects at the `family_id` fence | **no row** (do not add a `planned` row in this lane) | Exact \(I_\eta=\sum_y f(y;r,p)\,s(y)^2\) at fixed \(\varphi\), with \(r=\mu/\varphi\), \(\log p=-\log(1+\varphi)\), \(s(y)=r\{\psi(y+r)-\psi(r)+\log p\}\). **Not** the quasi weight \(\mu/(1+\varphi)\). | \(\log w=\log\bigl(I_\eta+10^{-12}\bigr)\), \(\psi\) via the AD-safe recurrence helper | The NB1 \(\eta\)-score is **not** linear in \(y\) (the shape \(r=\mu/\varphi\) moves with \(\mu\)), so the variance-shaped quasi weight \(\mu/(1+\varphi)\) is the **wrong** information — using it is a kill. The exact atom costs a PMF sum per row, and its truncation cap (`ymax`, \(\mu+12\,\mathrm{sd}\)) is read through `asDouble`, so the **number of summed terms is a non-differentiable step in the parameters**: the taped atom is only faithful near the taping point, and a fit that drifts far in \(\mu\) or \(\varphi\) is silently evaluating a different truncation. Expensive and tape-local. |
| beta (logit) | 7 | **no** — prepare rejects at the `family_id` fence | **no row** | Ferrari–Cribari-Neto mean-model weight: \(w=\varphi\{\psi'(a)+\psi'(b)\}\,\{\mu(1-\mu)\}^2\), \(a=\mu\varphi\), \(b=(1-\mu)\varphi\), \(\mu=\operatorname{logit}^{-1}(\eta)\) | \(\log w=\log\bigl(\varphi\{\psi'(a)+\psi'(b)\}\mu^2(1-\mu)^2+10^{-12}\bigr)\) | **Not coercive at the mean boundary.** As \(\mu\to0\), \(\psi'(a)\sim(\mu\varphi)^{-2}\) exactly cancels \(\{\mu(1-\mu)\}^2\) and \(w\to1/\varphi\) — a finite positive constant (unity at \(\varphi=1\)), symmetrically at \(\mu\to1\). \(P^*\) therefore stays bounded and supplies **no** Jeffreys-type repair for beta means. The boundaries beta actually has — support at \(y\in\{0,1\}\) (handled by a \(10^{-12}\) clamp, a support hack, not a penalty) and \(\varphi\to\infty\) — are untouched by this atom. A tape that exists but cannot do the job it is shaped like. |
| Tweedie (log, \(1<p<2\)) | 6 | **no** — prepare rejects at the `family_id` fence | **no row** | \(W=\mu^{2-p}/\varphi\), \(p=1+\operatorname{logit}^{-1}(\text{logit}\_p)\) | \(\log w=(2-p)\eta-\log\varphi\) | **Anti-coercive in \(\varphi\): the atom rewards \(\varphi\to0\).** Because \(1/\varphi\) is a row-constant factor, \(P^*=-\tfrac{p_\beta}{2}\log\varphi+\tfrac12\log\det(X_*^\top\operatorname{diag}(\mu^{2-p})X_*)\), so \(+c\,P^*\to+\infty\) on the degenerate zero-dispersion path — the penalty actively pushes toward the boundary instead of away from it. Worse, \(p\) is estimated, so the exponent of the penalty moves with the fit (\(\partial P^*/\partial p\) is a design-weighted \(-\eta\) average), and as \(p\to2\) the weight loses its \(\mu\) dependence entirely and the atom stops informing \(\beta\). The most hostile of the five. |

Reading of the table: **Poisson is the only row whose atom points the
way its boundary story needs**; NB2 aims the mean atom at a dispersion
boundary, NB1 is exact but tape-local and expensive, beta is bounded
where it would need to diverge, and Tweedie diverges the wrong way.
That asymmetry is precisely why only Poisson gets the public door and
the other four stay taped-and-fenced.

## 3. Where each object lives

| Layer | Content | This lane's state |
|---|---|---|
| Symbolic criterion | \(\ell_{\mathrm{LA}}+c\,P^*\); \(P^*=\tfrac12\log\det(X_*^\top WX_*)\) at \(\eta=X_{\mathrm{fix}}b_{\mathrm{fix}}+\mathrm{offset}\) | this note |
| R assembly | `.gllvmTMB_mspl_prepare()` family fence `{0,1,2}`; `rate = 1` for Poisson | Poisson public; four families rejected |
| TMB implementation | `gll_mspl_log_weight_glm()` family dispatch + `gll_mspl_atomic_half_logdet()`; `nll += -c * P^*` | five tapes exist; one cpp owner; **not edited by this note** |
| Registry | `.gllvmTMB_mspl_registry()` | Poisson `planned`; NB2 `excluded`; NB1/beta/Tweedie absent |
| User interpretation | experimental point estimator, `se = FALSE` only | no covered claim |

The dispersion arguments reach the hook per trait: `log_phi_nbinom2`,
`log_phi_nbinom1`, `log_phi_beta`, and `log_phi_tweedie` +
`logit_p_tweedie`. Poisson and Bernoulli pass inert stubs.

## 4. Kill list for the later derivations

1. Calling any of these five atoms `I_LA(beta)`, "Laplace-marginal
   information", or "observed information for \(\beta\)".
2. Transplanting Bernoulli \(c_n=2\sqrt{p_{\mathrm{free}}/N_{\mathrm{eff}}}\)
   or Gaussian \(c_N=\sqrt{2/N}\) as the Poisson / NB / beta / Tweedie
   rate.
3. NB1 quasi weight \(\mu/(1+\varphi)\) in place of the PMF-summed exact
   \(I_\eta\).
4. Claiming the beta atom repairs \(\mu\to0/1\) (it converges to
   \(1/\varphi\)).
5. Claiming the Tweedie atom is a penalty at the dispersion boundary
   (it is a reward).
6. Letting the NB2 atom's implicit \(\varphi\to\infty\) pull be reported
   as a mean-boundary result.
7. Treating the NB1 truncation cap as differentiable, or comparing NB1
   atom values across fits taped at different \(\mu,\varphi\).
8. Family inheritance of any kind ("Poisson works, so NB does"; "NB2
   works, so NB1 does").
9. Transplanting Bernoulli \(V_{\mathrm{loading}}\) or Gaussian Hirose
   \(\sum_j S_{jj}/\psi_j\) into any of these five cells.
10. Flipping any row to `admitted`, adding a `planned` row for NB1 /
    beta / Tweedie, moving NB2 off `excluded`, writing NEWS `covered`,
    or implementing SE.
11. Widening `.gllvmTMB_mspl_prepare()` beyond `family_id ∈ {0,1,2}`.
12. Reporting finiteness of a fit as the scientific result.

## 5. Non-claims

This note does **not** claim: a proved coercivity theorem for any of the
five atoms; that the Poisson public door is an admission; calibrated
inference, SEs, profiles, or model comparison; that Design 88 or
Sterzinger–Kosmidis–Moustaki 2026 covers count, beta, or Tweedie GLLVM
MSPL under Laplace; that Laplace is exact for any of these families
(it is not); that nonzero offsets are admitted; that structured tiers
(`phylo_*`, `spatial_*`, `animal_*`, `kernel_*`) are in scope; or that
EVA/VA/AGHQ is involved.

## 6. Rose boundary

- `planned` ≠ `admitted`; absent ≠ `planned`. NB2 stays `excluded`.
- Public door after this lane = gaussian + bernoulli + **Poisson** only.
- `c` symbolic (unit 1); no Bernoulli or Gaussian transplant.
- Atom named **GLM-outer**, never \(I_{\mathrm{LA}}(\beta)\).
- No NEWS `covered`, no register promotion, no SE, no campaign.
- Lane kit only under
  `docs/dev-log/lanes/cursor-mspl-phase4-tapes-planned/LOOP/`; never
  repo-root `LOOP/`, never Dropbox.
- This note edits no `src/`, no `R/`, no NEWS, no design file.

## Out of scope here

Admission gates, campaigns, Totoro/DRAC, SE/intervals (PROTECTED on
`codex/lane-b-mspl-interval-feasibility`), Phase 1B API policy, mixed
families, and merging #972–#976.
