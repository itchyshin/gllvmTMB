# Phase 4-style prep — betabinomial (logit) LA-MSPL route (not admitted)

**Status:** design + local oracles only. **No registry row** is added
for `betabinomial`. `.gllvmTMB_mspl_prepare()` still admits only
gaussian / binomial / Poisson (`family_id %in% c(0L, 1L, 2L)`).
Betabinomial is runtime `family_id` **8**. **Verdict: PASS for
oracles / this writeup, FAIL for C++ / admission / registry /
`estimator = "mspl"` on betabinomial.**

**Reader:** statistical method developer / TMB engineer who must
decide whether a later tape may add a trials-and-precision atom.

**Programme constitution:**
`docs/dev-log/after-task/2026-08-14-laplace-mspl-estimator-programme.md`
§Phase 5 — *beta / beta-binomial* among the bounded-mean and
shape-parameter cells. This note is Phase-4-*style* prep so a later
Phase 5 derivation does not start from a blank page. It does **not**
inherit the Beta (#975) atom, the Bernoulli Design 88 atom, or the
Poisson count atom.

This is **LA-MSPL** (Laplace + a soft *outer* penalty), not EVA/VA,
not AGHQ-MSPL. There is **no** verified third-party theorem that
transfers those atoms to a beta-binomial GLLVM under Laplace
(programme §7; Ranga corpus). Every formula below that is not the
wired Hilbe/Bolker density is **AGENT-INFERRED** and exists to pin
oracles, not to license a tape.

## Why this is not a Beta cell and not a binomial cell

Beta (#975) is continuous \(y\in(0,1)\). Exact 0/1 never occur.
Binomial Design 88 is single-trial Bernoulli: \(N=1\), no free
precision, Fisher weight \(\mu(1-\mu)\).

Betabinomial is **integer counts in \(0,\ldots,N\)** with a free
precision \(\varphi>0\):

\[
\mu=\operatorname{logit}^{-1}(\eta),\qquad
a=\mu\varphi,\quad b=(1-\mu)\varphi,\qquad
\varphi=\exp(\texttt{log\_phi\_betabinom}).
\]

Public `sigma` stores \(\varphi=1/\sigma^2\)
(`docs/design/03-likelihoods.md`). Oracles use the internal
\(\varphi\). The wired log-pmf (`src/gllvmTMB.cpp` fid 8) is

\[
\begin{aligned}
\log f(y\mid N,\mu,\varphi)
&=
\log\Gamma(N+1)+\log\Gamma(y+a)+\log\Gamma(N-y+b)+\log\Gamma(a+b)\\
&\quad-\log\Gamma(y+1)-\log\Gamma(N-y+1)-\log\Gamma(a)-\log\Gamma(b)-\log\Gamma(N+a+b).
\end{aligned}
\]

Mean and variance (textbook BB):

\[
\mathrm{E}[Y]=N\mu,\qquad
\operatorname{Var}(Y)=N\mu(1-\mu)\,\frac{\varphi+N}{\varphi+1}.
\]

At \(N=1\) the precision drops out and the pmf is Bernoulli(\(\mu\)).
At \(\varphi\to\infty\) the extra-binomial factor \((\varphi+N)/(\varphi+1)\to 1\)
and the quasi weight recovers binomial Fisher. Neither limit is a
theorem transfer for a later tape at interior \((N,\varphi)\).

## 1. Exact fixed-effect information

Score on the logit scale, using \(\mathrm{d}a/\mathrm{d}\eta=\varphi\mu(1-\mu)\)
and \(\mathrm{d}b/\mathrm{d}\eta=-\varphi\mu(1-\mu)\):

\[
s_\eta
=
\varphi\mu(1-\mu)
\bigl\{\psi(y+a)-\psi(a)-\psi(N-y+b)+\psi(b)\bigr\}.
\]

The exact scalar Fisher contribution is the finite sum

\[
\mathcal I_\eta(N,\mu,\varphi)
=
\sum_{y=0}^{N}f(y)\,s_\eta(y)^2
=
-\mathrm{E}\Bigl[\frac{\partial s_\eta}{\partial\eta}\Bigr].
\]

Support is \(\{0,\ldots,N\}\), so oracles sum the **full** pmf (no
tail truncation). Therefore

\[
I_{\mathrm{exact}}(\beta_*)
=
X_*^\top\operatorname{diag}\{\mathcal I_\eta(N_i,\mu_i,\varphi)\}X_*,
\qquad
P^*_{\mathrm{J,BB}}
=
\tfrac12\log\det I_{\mathrm{exact}}(\beta_*).
\]

The quasi / IRLS working weight from the variance function is a
**contrast**, not the Jeffreys atom:

\[
w_{\mathrm{quasi}}
=
\frac{\bigl(\mathrm{d}\,\mathrm{E}[Y]/\mathrm{d}\eta\bigr)^2}{\operatorname{Var}(Y)}
=
N\mu(1-\mu)\,\frac{\varphi+1}{\varphi+N}.
\]

| Family / object | Quantity on logit \(\eta\) |
|---|---|
| Bernoulli / binomial \(N=1\) | \(\mu(1-\mu)\) |
| Binomial \(N\) trials, no extra-binomial | \(N\mu(1-\mu)\) |
| **BB exact Fisher** | \(\mathcal I_\eta(N,\mu,\varphi)\) from the pmf |
| **BB quasi / IRLS** | \(N\mu(1-\mu)\,(\varphi+1)/(\varphi+N)\) |
| Beta continuous (Ferrari) | \(\phi^2[\mu(1-\mu)]^2\{\psi'(\mu\phi)+\psi'((1-\mu)\phi)\}\) |

TMB minimises negative log-likelihood, so a later tape would add
\(-c\,P^*_{\mathrm{J,BB}}\) together with any loading or precision
atoms that earn their own proofs. The soft rate \(c\) is **not**
pinned. Bernoulli \(c_n\), Gaussian \(c_N\), and Poisson \(c_P\)
are rejected transplants.

## 2. Boundary objects (named, not taped)

- **Mean boundary \(\mu\to 0\) or \(1\).** All-\(0\) or all-\(N\)
  traits. Exact \(\mathcal I_\eta\to 0\). Distinct from Beta's
  continuous clamp at \(10^{-12}\).
- **Precision \(\varphi\to 0\).** Extra-binomial factor
  \((\varphi+N)/(\varphi+1)\to N\); variance inflates toward
  \(N^2\mu(1-\mu)\). Dedicated \(\varphi\) atom OPEN.
- **Precision \(\varphi\to\infty\).** Recovers binomial Fisher.
  Not a license to reuse Design 88 at finite \(\varphi\).
- **Trials \(N=1\).** \(\varphi\)-inert Bernoulli. A later tape
  that keeps a \(\varphi\) atom on single-trial rows is wrong.
- **Loadings.** Bernoulli \(V_{\mathrm{loading}}\) and Gaussian
  Hirose \(\sum S_{jj}/\psi_j\) have no BB coercivity proof.

## 3. Kill list

1. "Beta is also logit, reuse the Ferrari weight."
2. "Binomial Design 88 already covers trials."
3. "Quasi \(w=N\mu(1-\mu)(\varphi+1)/(\varphi+N)\) *is* Jeffreys."
4. "Poisson \(W=\mu\) or NB weights transfer because counts."
5. "Reuse Bernoulli \(c_n\) or Poisson \(c_P\)."
6. Flip `admitted` without an admit packet.
7. Public `se=TRUE` / NEWS covered.

## 4. Oracle contract (pure R)

Helpers live in
`tests/testthat/test-mspl-betabinomial-phase4-oracles.R`.
They must not call `gllvmTMB(..., estimator = "mspl")`,
`.gllvmTMB_mspl_prepare()`, or the registry.

| ID | Pin |
|---|---|
| B1 | \(\mathrm{E}[Y]=N\mu\); \(\operatorname{Var}=N\mu(1-\mu)(\varphi+N)/(\varphi+1)\). |
| B2 | Exact Fisher from the full pmf: mass 1, centred score, outer product = expected Hessian. |
| B3 | Quasi weight \(\neq\) exact \(\mathcal I_\eta\) at interior \((N,\varphi)\). |
| B4 | \(N=1\) recovers Bernoulli \(\mu(1-\mu)\) and is \(\varphi\)-inert. |
| B5 | \(\varphi\to\infty\) quasi \(\to N\mu(1-\mu)\); exact tracks it. |
| B6 | Ferrari Beta weight \(\neq\) BB exact or quasi. |
| B7 | All-zero / all-\(N\) paths drive \(P^*_{\mathrm{J,BB}}\to-\infty\). |
| B8 | \(V_{\mathrm{loading}}\) and Hirose are \((\mu,\varphi,N)\)-inert. |
| B9 | No live MSPL fit / registry / prepare. |
