# Phase 4-style prep — truncated Poisson and truncated NB2 (not admitted)

**Status:** design + local oracles only. **No registry row** is added
for `truncated_poisson` (fid **10**) or `truncated_nbinom2` (fid
**11**). Prepare still admits only gaussian / binomial / Poisson.
**Verdict: PASS for oracles / this writeup, FAIL for C++ / admission
/ registry / `estimator = "mspl"` on either truncated family.**

**Reader:** statistical method developer / TMB engineer who must
decide whether a later tape may add a *positive-count* atom.

**Programme constitution:**
`docs/dev-log/after-task/2026-08-14-laplace-mspl-estimator-programme.md`
§Phase 5 — *truncated and delta/hurdle components*. This note is
Phase-4-*style* prep. It does **not** inherit the Poisson Phase-4
atom (`W=\operatorname{diag}(\mu)`), the NB2 GLM weight, or the
delta/hurdle shared-\(\eta\) atom in #1004.

This is **LA-MSPL**, not EVA/VA, not AGHQ-MSPL. There is **no**
verified third-party theorem transferring those atoms to a
zero-truncated GLLVM under Laplace. Formulas that are not the wired
densities are **AGENT-INFERRED** and pin oracles only.

## Why truncation is its own cell

Ordinary Poisson can take \(y=0\). The Phase-4 Poisson boundary
story is all-zero / \(\mu\to 0\). Zero-truncated Poisson **forbids**
zeros: the wired density (`src/gllvmTMB.cpp` fid 10) is

\[
\log f(y\mid\lambda)
=
\log\operatorname{Poisson}(y;\lambda)
-\log\bigl(1-e^{-\lambda}\bigr),
\qquad
\lambda=e^{\eta},\quad y\ge 1.
\]

The boundary that remains is **all-ones** (every count at the
truncation point), not all-zeros. Transplanting Poisson
\(W=\lambda\) is the kill that justifies this note.

Zero-truncated NB2 (fid 11) adds a free size \(\varphi=\exp(\texttt{log\_phi\_truncnb2})\)
with the wired NB2 kernel and

\[
\log p_0=\varphi\bigl(\log\varphi-\log(\mu+\varphi)\bigr),
\qquad
\log f_{\mathrm{trunc}}
=
\log f_{\mathrm{NB2}}-\log(1-p_0).
\]

NB1 is **not** in this cell. The engine has no `truncated_nbinom1`.

## 1. Truncated Poisson information

Untruncated Poisson: \(s_\eta=y-\lambda\), \(\mathcal I_\eta=\lambda\).

For ZTP, \(\mathrm{E}[Y\mid Y\ge 1]=\lambda/(1-e^{-\lambda})\) and

\[
s_\eta=y-\frac{\lambda}{1-e^{-\lambda}},
\qquad
\mathcal I_\eta^{\mathrm{ZTP}}
=
\operatorname{Var}(Y\mid Y\ge 1)
=
\frac{\lambda}{1-p_0}
-\frac{\lambda^2 p_0}{(1-p_0)^2},
\quad p_0=e^{-\lambda}.
\]

As \(\lambda\to\infty\), \(p_0\to 0\) and \(\mathcal I_\eta^{\mathrm{ZTP}}\to\lambda\).
As \(\lambda\to 0\), all mass sits at \(y=1\), variance \(\to 0\),
and \(\mathcal I_\eta^{\mathrm{ZTP}}\to 0\). A Jeffreys-shaped atom

\[
P^*_{\mathrm{J,ZTP}}
=
\tfrac12\log\det\bigl(X_*^\top\operatorname{diag}\{\mathcal I_\eta^{\mathrm{ZTP}}\}X_*\bigr)
\]

is therefore coercive on the all-ones path and **not** equal to the
Poisson atom at finite \(\lambda\).

## 2. Truncated NB2 information

Untruncated NB2 log-link score is
\(s_\eta^{\mathrm{NB2}}=(y-\mu)\,\varphi/(\varphi+\mu)\).
The truncation correction is

\[
s_\eta^{\mathrm{TNB2}}
=
\frac{\varphi}{\varphi+\mu}
\Bigl(y-\frac{\mu}{1-p_0}\Bigr),
\qquad
p_0=\Bigl(\frac{\varphi}{\varphi+\mu}\Bigr)^{\varphi}.
\]

Hence

\[
\mathcal I_\eta^{\mathrm{TNB2}}
=
\Bigl(\frac{\varphi}{\varphi+\mu}\Bigr)^2
\operatorname{Var}(Y\mid Y\ge 1).
\]

The untruncated NB2 GLM weight \(\mu\varphi/(\varphi+\mu)\) is a
**contrast**. It equals the truncated information only in the
\(p_0\to 0\) (large-mean) limit. The \(\varphi\to\infty\) limit is
truncated Poisson, not ordinary Poisson.

## 3. Kill list

1. "Poisson \(W=\mu\) already covers truncated Poisson."
2. "NB2 tape (fid 5) already covers truncated NB2."
3. "All-zero Poisson oracles apply; zeros cannot occur."
4. "Reuse Poisson \(c_P\) or Bernoulli \(c_n\)."
5. "Delta/hurdle shared-\(\eta\) atom (#1004) is the same as truncation."
   Hurdle has a structural zero process; truncation conditions it out.
6. Flip `admitted`. Public `se=TRUE` / NEWS covered.

## 4. Oracle contract (pure R)

Helpers live in
`tests/testthat/test-mspl-truncated-phase4-oracles.R`.
No live MSPL, no prepare, no registry.

| ID | Pin |
|---|---|
| T1 | ZTP mean \(\lambda/(1-e^{-\lambda})\); variance formula above. |
| T2 | ZTP score centred; \(I_\eta=\mathrm{Var}(Y\mid Y\ge 1)\). |
| T3 | ZTP \(I_\eta\neq\lambda\) at interior \(\lambda\); \(\lambda\to\infty\) recovers Poisson. |
| T4 | ZTP \(P^*_{\mathrm{J}}\) collapses as \(\lambda\to 0\) (all-ones). |
| T5 | TNB2 \(p_0=(\varphi/(\varphi+\mu))^\varphi\); score centred. |
| T6 | TNB2 \(I_\eta\neq\) untruncated NB2 weight at interior \((\mu,\varphi)\). |
| T7 | TNB2 \(\varphi\to\infty\) tracks ZTP, not Poisson. |
| T8 | \(V_{\mathrm{loading}}\) / Hirose are mean-inert. |
| T9 | No live MSPL fit / registry / prepare. |
