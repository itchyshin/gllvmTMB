# Phase 4-style prep — multinomial (baseline-category logit) LA-MSPL (not admitted)

**Status:** design + local oracles + **`planned` registry rows only**.
Registry cells `multinomial:logit:ordinary:q1` and `q2` are
`status = "planned"`, `evidence = "phase4_prep"` (#1039). They are
**not** `admitted`. `.gllvmTMB_mspl_prepare()` still rejects
`multinomial` (`family_id` **16**). **Verdict: PASS for oracles /
planned rows, FAIL for C++ / admission / `estimator = "mspl"` on
multinomial.**

**Reader:** statistical method developer / TMB engineer who must
decide whether a later tape may add an *unordered-category* atom.

**Programme constitution:**
`docs/dev-log/after-task/2026-08-14-laplace-mspl-estimator-programme.md`
§Phase 5 — *multinomial contrast cells* after ordinal. This note is
Phase-4-*style* prep. It does **not** inherit Design 88, the
ordinal-probit \(I_\eta\) in #1005, or any scalar GLM-outer weight.

This is **LA-MSPL**, not EVA/VA, not AGHQ-MSPL. Ranga's corpus had
no third-party multinomial GLLVM MSPL theorem under Laplace.
Formulas that are not the wired grouped softmax are
**AGENT-INFERRED** and pin oracles only.

## Why this is not a binomial cell and not an ordinal cell

Binomial Design 88 is a *scalar* logit with \(y\in\{0,1\}\).
Ordinal-probit (#1005) is an *ordered* threshold model with
cutpoints and a scalar \(\eta\).

Multinomial is **unordered** \(K\ge 3\) with a
\((K-1)\)-dimensional contrast. The engine expands one categorical
observation into \(K-1\) contiguous pseudo-rows and evaluates the
softmax **once**, at the group's anchor row
(`src/gllvmTMB.cpp` fid 16). Baseline category 1 is the implicit
\(\eta=0\) normaliser. Per-row `obs_loglik` is a hard error.

\[
\pi_k
=
\frac{e^{\eta_k}}{\sum_{j=1}^{K}e^{\eta_j}},
\qquad
\eta_1=0,
\quad
\log\pi_{y}
=
\eta_{y}-\log\sum_{j=1}^{K}e^{\eta_j}.
\]

There is **no** dispersion parameter (contrast ordinal fid 14 and
Beta/BB). A later tape cannot reuse
`gll_mspl_log_weight_glm`, which returns a *scalar* \(\log w\).

## 1. Exact information is a matrix

For one categorical observation the Fisher information on the
free logits \(\eta_{2:K}\) is the multinomial Gram

\[
I(\eta_{2:K})
=
\operatorname{diag}(\pi_{2:K})-\pi_{2:K}\pi_{2:K}^{\top}.
\]

It is \((K-1)\times(K-1)\), symmetric, rank at most \(K-1\), and
singular if any free \(\pi_k\in\{0,1\}\). A Jeffreys-shaped atom
on one observation is

\[
P^*_{\mathrm{J,MN}}
=
\tfrac12\log\det I(\eta_{2:K}).
\]

Stacked units with a shared design on each contrast (the GLLVM
fixed-effect picture) build a larger block information; oracles
pin the single-observation kernel first. The soft rate \(c\) is
**not** pinned.

At \(K=2\) there is one free logit, \(\pi=\operatorname{logit}^{-1}(\eta)\),
and \(I=\pi(1-\pi)\). That recovers Bernoulli Fisher. It is a
**limit check**, not a license to reuse Design 88 at \(K\ge 3\).

## 2. Boundary objects (named, not taped)

- **Complete separation.** One category observed for every unit of
  a trait. Some free \(\pi_k\to 0\) or \(1\), \(I\) singular,
  \(P^*_{\mathrm{J,MN}}\to-\infty\).
- **Anchor / double-counting.** Evaluating the softmax on every
  contrast row would multiply the log-likelihood by \(K-1\). The
  wired contract is anchor-only. A later tape that adds a scalar
  weight per pseudo-row repeats that bug.
- **Loadings.** Bernoulli \(V_{\mathrm{loading}}\) is a radial
  function of \(\|\lambda_t\|\). Multinomial loadings sit on
  \(K-1\) contrasts; no transfer proof.
- **Ordinal cuts.** Ordinal #1005 names cut-collision and
  cut-infinity. Multinomial has neither.

## 3. Kill list

1. "Binomial logit already covers multinomial at \(K=2\), so \(K>2\) is the same tape."
2. "Reuse `gll_mspl_log_weight_glm` (scalar \(W\))."
3. "Ordinal-probit \(I_\eta\) transfers because both are categorical."
4. "Add the penalty on every contrast pseudo-row."
5. "Reuse Bernoulli \(c_n\)."
6. Flip `admitted`. Public `se=TRUE` / NEWS covered.

## 4. Oracle contract (pure R)

Helpers live in
`tests/testthat/test-mspl-multinomial-phase4-oracles.R`.
No live MSPL, no prepare widen. Registry is `planned` /
`phase4_prep` only.

| ID | Pin |
|---|---|
| M1 | Softmax \(\sum\pi=1\); baseline \(\eta_1=0\). |
| M2 | \(I=\operatorname{diag}(\pi_{-1})-\pi_{-1}\pi_{-1}^{\top}\); PSD; score outer product matches. |
| M3 | \(K=2\) recovers Bernoulli \(\pi(1-\pi)\). |
| M4 | \(K\ge 3\) \(I\) is not a scalar binomial weight. |
| M5 | Separation path (one \(\eta\to+\infty\)) drives \(\log\det I\to-\infty\). |
| M6 | Anchor-once log-likelihood; summing \(K-1\) row densities is wrong. |
| M7 | \(V_{\mathrm{loading}}\) / Hirose / ordinal cut objects are the wrong atom. |
| M8 | Registry rows `planned` / `phase4_prep`; **not** `admitted`. |
