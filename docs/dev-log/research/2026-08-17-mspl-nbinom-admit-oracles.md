# nbinom1 / nbinom2 LA-MSPL — Pure-R admit-packet oracles

**Date:** 2026-08-17
**Branch:** `cursor/mspl-nbinom-admit-oracles`
**Ground:** `origin/main` after #1042 (packet-first scout) and #1067
**Status:** Pure-R science pin only. Registry stays **`planned`** /
`phase4_prep`. Not admitted. Not NEWS `covered`. Not public
`se = TRUE`. No `src/` tape. No live A7 twin.

**Reader:** the next MSPL conductor who must pin \(c\), the loading
atom, and the NB2 \(\varphi\) keep/drop *before* retargeting #1065's
C++ / live-twin slice.

This is **LA-MSPL**. Formulas that are not textbook NB GLM
information are **AGENT-INFERRED**. They pin oracles. They do not
license a tape or a registry flip.

---

## Why this sitting is Pure-R

#1042 said packet first: choose family \(c\), a loading atom, and
the NB2 Jeffreys-on-\(\varphi\) keep/drop, then match them. #1065
tried the full #1008 shape (helpers + C++ + live A7) and CI failed
on two non-science paths: the NB1 live fit tripped the penalty-off
decomposition check, and the \(\varphi\) DROP test read
`src/gllvmTMB.cpp` from an installed tarball.

This sitting lands the missing **science** as Pure-R oracles. The
live door still reports unpinned \(c=1\) and Bernoulli
\(V_{\mathrm{loading}}\). That is honest: the tape is not yet the
packet. #1065 stays open as the later C++ / A7 follow-on; do not
merge it against this pin.

---

## Pinned rates

Both rates freeze a **data-plugin** information size from observed
\(y\) and a per-trait method-of-moments \(\hat\varphi\). They do not
move with a known offset at fixed \(y\) (A3). They are not live
\(\mu(\beta)\) functions, so they stay a soft scale like \(c_P\) and
\(c_n\).

\[
c_{\mathrm{NB2}}=2\sqrt{p_{\mathrm{free}}/\max(I_{\mathrm{NB2}},1)},
\qquad
c_{\mathrm{NB1}}=2\sqrt{p_{\mathrm{free}}/\max(I_{\mathrm{NB1}},1)}.
\]

**NB2.** \(I_{\mathrm{NB2}}=\sum_t n_t\,\bar w_t\) with
\(\bar w_t=\bar y_t\hat\varphi_t/(\hat\varphi_t+\bar y_t)\) and
\(\hat\varphi_t=\bar y_t^2/\max(s_t^2-\bar y_t,\varepsilon)\).
Underdispersion versus Poisson (\(s^2\le\bar y\)) floors
\(\hat\varphi=10^8\) (Poisson *limit* of this proxy, not inheritance).
All-zero traits contribute \(\bar w=0\); all-zero data floors
\(I_{\mathrm{NB2}}=1\).

**NB1.** \(I_{\mathrm{NB1}}=\sum_t n_t\,I_\eta(\bar y_t,\hat\varphi_t)\)
with \(\hat\varphi_t=\max(s_t^2/\bar y_t-1,\varepsilon)\) and
Poisson-limit floor \(10^{-8}\) (NB1 recovers Poisson as
\(\varphi\to 0\)). \(I_\eta\) is the PMF-summed exact score outer
product (qnbinom tail). Not quasi \(\bar y/(1+\hat\varphi)\).

| Kill | Formula | Why it is not this cell |
|---|---|---|
| \(c=1\) | unit placeholder | Live nbinom door today. Not science. |
| \(c_n\) | \(2\sqrt{p_{\mathrm{free}}/N_{\mathrm{rows}}}\) | Row count is not NB information. |
| \(c_N\) | \(\sqrt{2/N_{\mathrm{units}}}\) | Gaussian Phase-3 rate. |
| \(c_P\) | \(2\sqrt{p_{\mathrm{free}}/\max(\sum y,1)}\) | Event count is a Poisson proxy. NB2 information does not double when exposure doubles. |
| NB1 quasi | \(\sum\mu/(1+\varphi)\) | Diagnostic only. Exact \(I_\eta\) is the pin. |

At huge \(\hat\varphi\) (NB2) or tiny \(\hat\varphi\) (NB1) the proxy
can numerically approach \(c_P\). That is a limit, not a definition.
NB1 \(\neq\) NB2 on the same \(y\).

---

## Pinned loading atoms

Weight the radial term by the **family** information weight
(trait-mean of NB2 \(W\) or of NB1 exact \(I_\eta\)), evaluated at
the same data plugin as the rate.

\[
V_\lambda^{\mathrm{NB2}}=\sum_t\bigl(\sqrt{1+\|\lambda_t\|^2\bar w_t}-1\bigr),
\qquad
V_\lambda^{\mathrm{NB1}}=\sum_t\bigl(\sqrt{1+\|\lambda_t\|^2\bar I_t}-1\bigr).
\]

- All-zero traits contribute 0. Jeffreys-on-\(\beta\) owns \(\mu\to 0\).
- Coercive as \(\|\lambda_t\|\to\infty\) at \(\bar w_t>0\) / \(\bar I_t>0\).
- Rotation-invariant in the factor space (row Euclidean norms).
- Recovers Bernoulli \(V_{\mathrm{loading}}\) only at unit weights;
  that coincidence is not a transfer.
- Poisson \(V_\lambda^P\) (raw \(\bar y_t\)) is a kill at finite
  overdispersion.

Laplace-marginal loading coercivity remains OPEN. This pin states
experimental-point status as honestly as Poisson #1008 did.

---

## NB2 Jeffreys-on-\(\varphi\): DROP

The mean atom \(P^*_{J,\mu}=\tfrac12\log\det(X_*^\top W X_*)\) with
\(W=\mu\varphi/(\varphi+\mu)\) already moves with \(\varphi\): it
collapses as \(\varphi\to 0\) and approaches the Poisson Jeffreys as
\(\varphi\to\infty\). A separate atom
\(P^*_{J,\varphi}=\tfrac12\log I_{\varphi\varphi}\) was the
keep-or-drop question.

Evidence (D-phi oracle + Phase-4 E1/E3):

1. \(I_{\log\varphi}=\varphi^2 I_{\varphi\varphi}\). Taping
   \(\tfrac12\log I_{\varphi\varphi}\) on `log_phi_nbinom2` without
   that Jacobian is a kill.
2. The quasi stand-in \(\tfrac12(\mu/(\mu+\varphi))^2\) is not
   \(I_{\varphi\varphi}\).
3. As \(\varphi\to\infty\), \(I_{\varphi\varphi}\to 0\), so
   \(\tfrac12\log I_{\varphi\varphi}\to-\infty\) and would *fight*
   the Poisson limit on the maximisation scale.
4. As \(\varphi\to 0\), \(I_{\varphi\varphi}\) grows, so the same
   atom would *reward* infinite overdispersion.
5. Exact \(I_{\varphi\varphi}\) is a PMF sum.

**Decision: DROP.** Do not tape \(\tfrac12\log I_{\varphi\varphi}\)
or \(\tfrac12\log I_{\log\varphi}\) in a later C++ sitting unless a
new derivation overturns this pin. The mean atom's
\(\varphi\to\infty\) hostility stays a documented experimental-point
caveat.

NB1: the mean atom *increases* toward Poisson as \(\varphi\to 0\)
(N6) and cannot be used as a \(\varphi\to 0\) repair. No dedicated
\(\varphi\) atom is pinned.

---

## What this sitting does not do

- No live `estimator="mspl"` twin (Poisson A7). Phase-4 E/N files
  still refuse that call; that remains correct for those files.
- No `src/` edit. Live `mspl_c_n = 1` and Bernoulli radial stay.
- No `R/mspl.R` prepare-path rate change. Scope strings still say
  `unpinned c=1`.
- No registry flip. A8 holds `planned` / `phase4_prep`.
- No Totoro / DRAC (D-50 / D-139). No public SE. No NEWS `covered`.

A later tape sitting must match these R twins and must not read
`src/` from an installed tarball.

## Helpers

`R/mspl-nbinom2-atoms.R`, `R/mspl-nbinom1-atoms.R` (internal, not
exported). Oracles:
`tests/testthat/test-mspl-nbinom2-admit-packet.R` (A1–A6, D-phi, A8)
and `test-mspl-nbinom1-admit-packet.R` (A1–A6, A8, plus NB1 \(\neq\)
NB2).
