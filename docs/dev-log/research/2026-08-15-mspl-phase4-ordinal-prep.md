# Phase 4-style prep — ordinal_probit LA-MSPL route (not admitted)

**Status:** design + local oracles only. **No registry row** is added
for `ordinal_probit`. `.gllvmTMB_mspl_prepare()` still admits only
gaussian / bernoulli / Poisson at the public door
(`family_id %in% {0,1,2}` after #978). Ordinal probit is runtime
`family_id` **14**. **Verdict: PASS for oracles / this writeup, FAIL
for C++ / admission / registry / `estimator = "mspl"` on
`ordinal_probit()`.**

**Board move:** this cell was **na**. It is now **planned prep
only**. That is a documentation + oracle status, not a registry
`planned` row and not admission.

**Reader:** statistical method developer / TMB engineer who must
decide whether a later tape may add an ordinal location or
cutpoint atom. This note does **not** inherit Bernoulli Design 88,
Gaussian Hirose, Student-t location weights, or the five GLM-outer
count/beta/Tweedie tapes. Programme §7 recorded no verified
theorem for ordinal GLLVM MSPL under Laplace.

**Programme constitution:**
`docs/dev-log/after-task/2026-08-14-laplace-mspl-estimator-programme.md`
names *ordinal cutpoint collision/infinity* as its own boundary
class. Do not collapse that class into binary separation.

This is **LA-MSPL** (Laplace + a soft *outer* penalty), not EVA/VA,
not AGHQ-MSPL. Every formula below that is not the Wright /
Falconer / Hadfield threshold likelihood already taped in
`src/gllvmTMB.cpp` fid 14 is **AGENT-INFERRED** and exists to pin
oracles, not to license a penalty tape.

## Why this is not a Bernoulli probit cell

The observation model is

\[
y^\star=\eta+e,\qquad e\sim\mathcal N(0,1),\qquad
y=k\iff \tau_{k-1}<y^\star\le\tau_k,
\]

with \(\tau_0=-\infty\), \(\tau_1=0\), \(\tau_K=+\infty\), and
\(K\ge 3\). Residual variance is **pinned at 1** by probit
identification. Free cutpoints \(\tau_2,\ldots,\tau_{K-1}\) are
reconstructed from log-increments

\[
\tau= \bigl(0,\; e^{\delta_1},\; e^{\delta_1}+e^{\delta_2},\;\ldots\bigr)
\]

(`ordinal_log_increments`; Christensen 2019 / `brms` cumulative).
Category probabilities are

\[
\Pr(y=k\mid\eta)=\Phi(\tau_k-\eta)-\Phi(\tau_{k-1}-\eta),
\]

evaluated on the log scale (`gll_log_pnorm` /
`gll_log_pnorm_diff`).

\(K=2\) with \(\tau_1=0\) *would* be binomial probit
(\(\Pr(y=2)=\Phi(\eta)\)). The package does not admit \(K=2\)
ordinal. Oracle O7 pins that the \(K=2\) information weight
recovers the Bernoulli *probit* weight
\(\phi(\eta)^2/(\Phi(\eta)(1-\Phi(\eta)))\), and that the \(K\ge 3\)
weight equals neither that binary weight nor the logit
\(\mu(1-\mu)\).

Do not treat ordinal as stacked Bernoulli, as \(K-1\) independent
binary MSPL cells, or as multinomial softmax (oracle O10).

## 1. Exact location information

For a single row the \(\eta\)-score on category \(k\) is

\[
s_k(\eta)=\frac{\phi(\tau_{k-1}-\eta)-\phi(\tau_k-\eta)}{p_k(\eta)}.
\]

The exact scalar Fisher contribution is the finite sum

\[
\mathcal I_\eta(\eta,\tau)=\sum_{k=1}^{K}p_k(\eta)\,s_k(\eta)^2
=-\operatorname E\bigl[\partial s/\partial\eta\bigr].
\]

No truncation: \(K\) is finite. Then

\[
I(\beta_*)=X_*^\top\operatorname{diag}\{\mathcal I_\eta(\eta_i,\tau)\}X_*,
\qquad
P^*_{\mathrm{J,ord}}=\tfrac12\log\det I(\beta_*).
\]

This is GLM-outer information at the **fixed-only** linear
predictor, before any latent score — the same convention the live
Bernoulli / Poisson tapes record. Laplace-marginal \(I(\beta)\)
remains **OPEN**. The \(\beta\)-block at fixed cuts is not the
joint \((\beta,\delta)\) Jeffreys determinant.

TMB minimises negative log-likelihood, so a later tape would add
\(-c\,P^*_{\mathrm{J,ord}}\) together with any cut or loading atoms
that earn their own coercivity proofs. Soft rate \(c\) is **OPEN**.
Bernoulli \(c_n\) and Gaussian \(c_N\) are rejected transplants.

## 2. Three named boundaries (do not collapse them)

### Location separation — \(|\eta|\to\infty\) at fixed cuts

All mass goes to category \(1\) or \(K\). Exact
\(\mathcal I_\eta\to 0\) and \(P^*_{\mathrm{J,ord}}\to-\infty\)
when \(X_*\) has a column active on those rows (oracle O3). This
is the ordinal analogue of binary separation. Finiteness of a
penalised fit on an all-top or all-bottom trait is necessary and
**not** sufficient for admission.

The cut layout \(\tau\in\{0,1,2\}\) makes
\(\mathcal I_\eta(\eta)=\mathcal I_\eta(\eta+2)\) near the
fixture; a positive-intercept grid must start *past* that
reflection or the first step is flat. That is a design symmetry,
not coercivity.

### Cut collision — some \(\delta_j\to-\infty\)

An adjacent pair \(\tau_{j+1}-\tau_j=e^{\delta_j}\to 0\). The
middle category probability vanishes (oracle O4). This is the
programme’s *cutpoint collision* class. It is **not** the
\(|\eta|\to\infty\) path: the location atom may stay finite while
a category disappears. A dedicated \(\delta\)-atom is **OPEN**.

### Cut infinity — some \(\delta_j\to+\infty\)

Upper (or lower, after a shift) categories become unused
(oracle O5). Programme *cutpoint infinity*. Again a different
coordinate from location separation.

### Residual scale (named so it cannot be invented)

\(\sigma_d=1\) is pinned. Fabricating a free residual \(\sigma\),
or treating cuts as Gaussian \(\psi\), is a type error
(oracles O6, O8).

### Loading runaway (named, not solved)

Large \(\|\lambda\|\) on \(\eta_{\mathrm{fix}}+\lambda^\top u\)
can send units into opposite extreme categories. **No ordinal
loading atom is admitted here.** \(V_{\mathrm{loading}}\) is
\((\eta,\tau)\)-inert (oracle O9).

## 3. Why Bernoulli, Gaussian, and Student-t atoms do not transfer

1. **Bernoulli logit \(W_g=\mu(1-\mu)\)** is the wrong link and
   the wrong \(K\).
2. **Bernoulli probit weight** is the \(K=2\) special case only.
3. **\(V_{\mathrm{loading}}\)** does not see \(\eta\) or \(\tau\).
4. **Gaussian Hirose** needs free \(\Psi\). Ordinal has none;
   residual variance is 1.
5. **Student-t location weight** \((\nu+1)/((\nu+3)\sigma^2)\) is
   \(\mu\)-inert. Ordinal \(\mathcal I_\eta\) is not.
6. **Poisson / NB / Tweedie / beta** mean weights do not apply to
   a pinned-threshold categorical likelihood.

## 4. Kill list — fail the later derivation on any of these

1. Treating ordinal as Bernoulli probit, stacked Bernoulli, or
   multinomial softmax.
2. Transplant of logit \(W_g=\mu(1-\mu)\) or Design 88
   \(V_{\mathrm{loading}}\).
3. Transplant of Gaussian Hirose, including \(\psi:=\tau\) or
   \(\psi:=1\).
4. Transplant of Student-t \((\nu+1)/((\nu+3)\sigma^2)\).
5. Inventing a free residual \(\sigma_d\).
6. Collapsing location separation, cut collision, and cut
   infinity into one “ordinal boundary.”
7. Inheriting Bernoulli \(c_n\) or Gaussian \(c_N\).
8. Claiming Design 88 or Hadfield (2015) covers ordinal *GLLVM
   MSPL* under Laplace.
9. Finiteness of a fit offered as the scientific result.
10. Any admission-shaped language (`admitted` or registry
    `planned`, NEWS covered, C++ tape) ahead of the Shinichi gate.
11. Live `gllvmTMB(..., estimator = "mspl")` on
    `ordinal_probit()`.
12. Quietly widening `.gllvmTMB_mspl_prepare()` beyond `{0,1,2}`.
13. Adding an `ordinal_probit` registry row in this prep cell.
14. Student-t inheritance in either direction.

## 5. Oracle contract O1–O11 (pure R; no ordinal `estimator="mspl"`)

| ID | What | Tolerance / decision |
|---|---|---|
| O1 | \(\tau_1=0\); \(\tau\) = cumulative \(\exp(\delta)\); \(\sum p=1\) | \(<10^{-12}\) |
| O2 | exact \(\mathcal I_\eta\): mass 1, expected score 0, outer = Hessian; score = FD | moments \(<10^{-10}\); score \(<10^{-8}\) |
| O3 | \(\lvert\eta\rvert\to\infty\Rightarrow P^*_{\mathrm{J,ord}}\to-\infty\) at fixed \(\tau\) | monotone in each far tail |
| O4 | cut collision \(\delta\to-\infty\) collapses a middle category; not the \(\lvert\eta\rvert\) path | monotone \(p_{\mathrm{mid}}\downarrow 0\) |
| O5 | cut infinity unused upper categories | nonincreasing; tail \(<10^{-8}\) |
| O6 | residual sd pinned at 1 | structural reject |
| O7 | \(K=2\) recovers Bernoulli probit weight; \(K\ge 3\) matches neither that nor logit \(\mu(1-\mu)\) | \(K=2\) \(<10^{-10}\); contrasts fire |
| O8 | Hirose refused; cuts are not \(\psi\) | structural reject |
| O9 | \(V_{\mathrm{loading}}\) is \((\eta,\tau)\)-inert | finite-diff |
| O10 | not stacked Bernoulli; not multinomial softmax | contrasts fire |
| O11 | no live ordinal MSPL; no `admitted` / `planned` row | structural |

## 6. Verdict

| Surface | Verdict | Why |
|---|---|---|
| Local R oracles / this writeup (O1–O11, kill list) | **PASS** | Exact finite-category information, three named boundaries, and refused transplants are testable without an ordinal MSPL fit. |
| C++ tape / live ordinal MSPL / registry `planned` or `admitted` | **FAIL** | No tape, no prepare widening, no registry row, no Shinichi admission gate. |
| NEWS / covered / SE / intervals | **FAIL** | Out of scope; SE remains PROTECTED on Codex Lane B. |

Preferred later-admission *candidate* for the fixed-effect slice:
ordinal Jeffreys-shaped
\(\tfrac12\log\det(X_*^\top\operatorname{diag}\{\mathcal I_\eta(\eta,\tau)\}X_*)\),
with rate, cut-increment atom, loading atom, and Laplace-marginal
\(I(\beta)\) still OPEN. Not a theorem transfer. Not Design 88.

## 7. Non-claims

This note does **not** claim calibrated inference, SEs, a live
`estimator = "mspl"` fit, that Bernoulli / Hirose / Student-t
transfer, that Laplace is exact for ordinal, \(K=2\) admission,
structured tiers, EVA/VA, or a registry cell.

## 8. Rose boundary

- **Not EVA / not VA.**
- **Not Bernoulli Design 88.** \(K\ge 3\); residual pinned at 1.
- **Not Student-t.** Location information here depends on \(\eta\).
- **No registry row.**
- **Prepare fence unchanged.** Public door still `{0,1,2}`.
- **No C++.** `git diff -- src/` must stay empty on this arc.
- **No NEWS covered.**
- **No repo-root `LOOP/`.** Lane kit:
  `docs/dev-log/lanes/cursor-mspl-phase4-student-ordinal/LOOP/`.
- **No public `se=TRUE`.**

## Out of scope here

Campaigns, Totoro/DRAC, NEWS, register promotion, C++ tape,
`estimator = "mspl"` on `ordinal_probit()`, Student-t inheritance,
multinomial, interval lane.
