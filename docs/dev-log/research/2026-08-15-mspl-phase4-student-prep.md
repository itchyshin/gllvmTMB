# Phase 4-style prep — Student-t (identity) LA-MSPL route (not admitted)

**Status:** design + local oracles + **`planned` registry rows only**.
Registry cells `student:identity:ordinary:q1` and `q2` are
`status = "planned"`, `evidence = "phase4_prep"` (#1039). They are
**not** `admitted`. `.gllvmTMB_mspl_prepare()` still rejects
`student` (`family_id` **9**). **Verdict: PASS for oracles / planned
rows, FAIL for C++ / admission / `estimator = "mspl"` on
`student()`.**

**Board move:** this cell was **na**, then oracle-only prep (#1005).
After #1039 it is **`planned` / `phase4_prep`**. That is not
admission.

**Reader:** statistical method developer / TMB engineer who must
decide whether a later tape may add a Student-t location or scale
atom. This note does **not** inherit the Gaussian Hirose \(\Psi\)
atom, the Bernoulli Jeffreys / \(V_{\mathrm{loading}}\) atoms, or
any of the five GLM-outer count/beta/Tweedie tapes.

**Programme constitution:**
`docs/dev-log/after-task/2026-08-14-laplace-mspl-estimator-programme.md`
§7.2 (Gaussian factor MSPL is a \(\Psi\to 0\) Heywood theorem) and
§7 (no verified third-party theorem for non-Gaussian GLLVM MSPL
under Laplace, including this cell).

This is **LA-MSPL** (Laplace + a soft *outer* penalty), not EVA/VA,
not AGHQ-MSPL. Every formula below that is not textbook
location-scale Student-\(t\) information (Lange, Little & Taylor
1989; Pinheiro, Liu & Wu 2001) is **AGENT-INFERRED** and exists to
pin oracles, not to license a tape.

## Why this is its own family cell

Gaussian ordinary MSPL (Phase 3) targets Heywood unique variance
\(\psi_j\to 0\) with a Hirose atom \(\sum_j S_{jj}/\psi_j\).
Student-t (identity) is a **location-scale observation** model

\[
y=\mu+\sigma\,z,\qquad z\sim t_\nu,\qquad \mu=\eta=x^\top\beta+\lambda^\top u,
\]

with per-trait \(\sigma=\exp(\texttt{log\_sigma\_student})\) and

\[
\nu=1+\exp(\texttt{log\_df\_student})>1
\]

(`src/gllvmTMB.cpp` fid 9). The TMB log-density is exactly
`dt((y-mu)/sigma, df, true) - log(sigma)`.

Design 03 still writes the stale \(\nu=2+\exp(\eta_\nu)\)
(logm2, \(\nu>2\)) spelling. That is **not** the taped coordinate.
Oracles S6 pin `1+exp` and reject `2+exp`. Do not “fix” the design
doc in this prep; do not let a later tape use the stale transform.

Public `student()` also allows `log` and `inverse` links. **This
cell is identity only.**

## 1. Location information is \(\mu\)-inert

Textbook expected information for the location, at fixed
\((\sigma,\nu)\), is the constant weight

\[
w(\sigma,\nu)=\frac{\nu+1}{\nu+3}\,\frac{1}{\sigma^2}.
\]

A Jeffreys-shaped fixed-effect atom on the maximised log-likelihood
scale is therefore

\[
P^*_{\mathrm{J,st}}=\tfrac12\log\det\bigl(X_*^\top w(\sigma,\nu)\,X_*\bigr).
\]

Because \(w\) does not depend on \(\mu\) (hence not on \(\beta\)),
\(P^*_{\mathrm{J,st}}\) is **location-inert**. It cannot repair a
runaway intercept or loading that moves \(\mu\). That is the
opposite of Poisson \(W=\operatorname{diag}(\mu)\) and Bernoulli
\(W_g\).

| Family / object | Location weight | Depends on \(\mu\)? |
|---|---|---|
| Gaussian identity | \(1/\sigma^2\) | no |
| **Student-t identity** | \((\nu+1)/((\nu+3)\sigma^2)\) | **no** |
| Poisson log | \(\mu\) | yes |
| Bernoulli logit | \(\mu(1-\mu)\) | yes |
| Bernoulli probit | \(\phi(\eta)^2/(\Phi(\eta)(1-\Phi(\eta)))\) | yes (through \(\eta\)) |

Limits at fixed \(\sigma\):

- \(\nu\to\infty\): \(w\to 1/\sigma^2\) (Gaussian). Nested-family
  limit, **not** a reason to inherit the Hirose \(\Psi\) tape.
- \(\nu\to 1^+\): \(w\to 1/(2\sigma^2)\) (Cauchy-scale
  information). Still finite; still \(\mu\)-inert.

Variance \(\sigma^2\nu/(\nu-2)\) exists only for \(\nu>2\). TMB
allows \(1<\nu\le 2\) (infinite variance). Location information
stays finite there (oracle S7). Do not treat “variance undefined”
as “Fisher undefined.”

## 2. Three named boundaries (do not collapse them)

### Scale collapse \(\sigma\to 0\) — anti-coercive for this atom

Because \(w\propto 1/\sigma^2\),

\[
P^*_{\mathrm{J,st}}=-\,p_*\log\sigma+\tfrac12\log\det(X_*^\top X_*)+\text{const}(\nu).
\]

As \(\sigma\to 0\), \(P^*_{\mathrm{J,st}}\to+\infty\). On the
maximisation scale a \(+c\,P^*\) term **rewards** residual-scale
collapse. That is the Tweedie-\(\varphi\to 0\) hostility, not a
Heywood repair. Gaussian Hirose is *intended* to diverge as
\(\psi\to 0\); transplanting it onto \(\sigma\) silently renames
the observation scale as unique variance.

### Scale explosion \(\sigma\to\infty\)

The same atom sends \(P^*_{\mathrm{J,st}}\to-\infty\). Qualitatively
a push away from infinite residual scale; **not** a derived
\(\sigma\)-atom, and it still does nothing to \(\mu\).

### Degrees-of-freedom boundaries

- \(\nu\to 1^+\): heaviest tails; `log_df_student\to-\infty`.
- \(\nu\to\infty\): Gaussian limit; `log_df_student\to+\infty`.
  The location atom *increases* toward the Gaussian weight. Using
  it as a “make \(\nu\) large / small” repair is a type error.

### Loading runaway (named, not solved)

On \(\mu=\eta_{\mathrm{fix}}+\lambda^\top u\), large
\(\|\lambda\|\) moves units’ locations. The location Jeffreys atom
does not see \(\mu\). **No Student-t loading atom is admitted
here.** Bernoulli \(V_{\mathrm{loading}}\) is
\((\mu,\sigma,\nu)\)-inert (oracle S10).

## 3. Why Gaussian Hirose and Bernoulli atoms do not transfer

1. **Hirose \(\sum S_{jj}/\psi_j\)** targets free unique variance
   in a Gaussian factor model. Ordinary Student-t has residual
   \(\sigma\) and \(\nu\), not \(\Psi\). Fabricating
   \(\psi:=\sigma\) or \(\psi:=\nu\) is a type error (oracle S9).
2. **Bernoulli \(W_g\) and \(V_{\mathrm{loading}}\)** repair
   *separation* on a probability scale. Student-t \(y\in\mathbb{R}\)
   does not separate. \(V_{\mathrm{loading}}\) does not move when
   \(\sigma\) or \(\nu\) move.
3. **Poisson / NB / Tweedie / beta GLM-outer weights** are mean
   functions. Student-t location weight is not.

Rate transplants
\(c_n=2\sqrt{p_{\mathrm{free}}/N_{\mathrm{eff}}}\) and
\(c_N=\sqrt{2/N}\) are rejected. Soft rate \(c\) is **OPEN**.

## 4. Kill list — fail the later derivation on any of these

1. Transplant of Gaussian Hirose / Akaike \(\Psi\) atoms, including
   \(\psi:=\sigma\) or \(\psi:=\nu\).
2. Treating the location Jeffreys atom as a \(\mu\)-runaway repair
   (it is \(\mu\)-inert).
3. Treating \(\sigma\to 0\) as a Heywood problem, or using
   \(P^*_{\mathrm{J,st}}\) as a scale-collapse repair (that path
   *increases* \(P^*\)).
4. Using Design 03’s \(\nu=2+\exp(\cdot)\) as the tape coordinate.
5. Inheriting Bernoulli \(V_{\mathrm{loading}}\) / \(W_g\), or any
   of the five GLM-outer count/beta/Tweedie tapes.
6. Collapsing \(\sigma\to 0\), \(\sigma\to\infty\), \(\nu\to 1^+\),
   and \(\nu\to\infty\) into one “Student-t boundary.”
7. Treating infinite variance at \(1<\nu\le 2\) as missing Fisher
   information for \(\mu\).
8. Widening this cell to `log` / `inverse` links.
9. Claiming Lange–Little–Taylor or Pinheiro–Liu–Wu covers Student-t
   *GLLVM* MSPL under Laplace.
10. Finiteness of a fit offered as the scientific result.
11. Any admission-shaped language (status flip to `admitted`, NEWS
    covered, validation-register promotion, C++ tape) ahead of the
    Shinichi gate.
12. Live `gllvmTMB(..., estimator = "mspl")` on `student()`.
13. Quietly widening `.gllvmTMB_mspl_prepare()` to `family_id` 9.
14. Flipping student from `planned` / `phase4_prep` to `admitted`
    in this note.

## 5. Oracle contract S1–S12 (pure R; no student `estimator="mspl"`)

| ID | What | Tolerance / decision |
|---|---|---|
| S1 | \(w=(\nu+1)/((\nu+3)\sigma^2)\); Gaussian \(1/\sigma^2\) differs | \(<10^{-12}\); contrast fires |
| S2 | \(P^*_{\mathrm{J,st}}\) is \(\mu\)-inert | exact equality under \(\beta\) shift |
| S3 | \(\nu\to\infty\) recovers Gaussian \(w\); \(\nu\to 1^+\) is \(1/(2\sigma^2)\) | monotone in \(\nu\); limits \(<10^{-6}\) |
| S4 | \(\sigma\to 0\Rightarrow P^*\to+\infty\) (anti-coercive) | monotone increase |
| S5 | \(\sigma\to\infty\Rightarrow P^*\to-\infty\) | monotone decrease |
| S6 | TMB \(\nu=1+\exp(\texttt{log\_df})\); reject \(2+\exp\) | \(<10^{-12}\); contrast fires |
| S7 | \(\operatorname{Var}\) finite only for \(\nu>2\); \(I_\mu\) finite on \(1<\nu\le 2\) | structural |
| S8 | loglik = `dt((y-μ)/σ,ν,log)-log(σ)`; score = FD | score \(<10^{-8}\) |
| S9 | Hirose refused; \(\sigma,\nu\) are not \(\psi\) | structural reject |
| S10 | \(V_{\mathrm{loading}}\) is \((\mu,\sigma,\nu)\)-inert | finite-diff |
| S11 | identity-only cell | structural |
| S12 | Registry rows `planned` / `phase4_prep`; **not** `admitted` | lookup |

## 6. Verdict

| Surface | Verdict | Why |
|---|---|---|
| Local R oracles / this writeup (S1–S12, kill list) | **PASS** | Location inertness, anti-coercive \(\sigma\to 0\), TMB df transform, and refused transplants are testable without a student MSPL fit. |
| Registry `planned` rows | **PASS as planned only** | `student:identity:ordinary:q1/q2`. Not a public claim. |
| Registry `admitted` / C++ tape / live student MSPL | **FAIL** | No tape, no prepare widen, no Shinichi admission gate. |
| NEWS / covered / SE / intervals | **FAIL** | Out of scope; SE remains PROTECTED on Codex Lane B. |

Preferred later-admission *candidate* is **not** the location
Jeffreys atom (it cannot do the job a mean-boundary atom must do).
A dedicated \(\sigma\) atom that is *coercive* as \(\sigma\to 0\),
a \(\nu\) atom, and a loading atom under Laplace are all **OPEN**.
Not a theorem transfer. Not Gaussian Hirose.

## 7. Non-claims

This note does **not** claim calibrated inference, SEs, a live
`estimator = "mspl"` fit, that Hirose / Bernoulli / Poisson
transfer, that Laplace is exact for Student-t, `log`/`inverse`
Student-t MSPL, structured tiers, EVA/VA, or admission.

## 8. Rose boundary

- **Not EVA / not VA.** Outer criterion is Laplace-ML plus a soft
  penalty yet to be taped.
- **Not Gaussian Phase 3.** Residual \(\sigma\) is not \(\Psi\).
- **`planned` ≠ `admitted`.** student is `phase4_prep` only.
- **Prepare fence unchanged.** `student` still rejected.
- **No C++.** `git diff -- src/` must stay empty on this arc.
- **No NEWS covered.** No validation-register promotion.
- **No repo-root `LOOP/`.** Lane kit:
  `docs/dev-log/lanes/cursor-mspl-phase4-student-ordinal/LOOP/`.
- **No public `se=TRUE`.**

## Out of scope here

Campaigns, Totoro/DRAC, NEWS, register promotion, Phase 1B API,
interval lane, C++ tape, `estimator = "mspl"` on `student()`,
non-identity links, ordinal inheritance.
