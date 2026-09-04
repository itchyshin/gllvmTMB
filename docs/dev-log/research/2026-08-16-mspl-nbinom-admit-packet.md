# nbinom1 / nbinom2 LA-MSPL admit packet — pinned rates, loading atoms, φ DROP

**Date:** 2026-08-16
**Branch:** `cursor/mspl-nbinom-admit-packet`
**Status:** science landed; registry stays **`planned`** / `phase4_prep`.
Not admitted. Not NEWS `covered`. Not public `se = TRUE`.
**Ground:** `origin/main` after #1042 (packet-first scout).

**Reader:** Shinichi at the 5am G0, and the next MSPL conductor.

---

## What this packet is

Two family packets, mirroring #1008. Shared prose is allowed; shared
atoms are not. Poisson ordinary `admitted` / `admit_packet` does
**not** transfer a rate, a loading atom, a dispersion decision, or a
registry flip.

| Object | nbinom2 | nbinom1 |
|---|---|---|
| Rate | \(c_{\mathrm{NB2}}=2\sqrt{p_{\mathrm{free}}/\max(I_{\mathrm{NB2}},1)}\) | \(c_{\mathrm{NB1}}=2\sqrt{p_{\mathrm{free}}/\max(I_{\mathrm{NB1}},1)}\) |
| Information-size proxy | data-plugin \(\sum_t n_t\,\bar w_t\), \(\bar w_t=\bar y_t\hat\varphi_t/(\hat\varphi_t+\bar y_t)\) | data-plugin \(\sum_t n_t\,I_\eta(\bar y_t,\hat\varphi_t)\) (PMF-summed exact) |
| Loading atom | \(\sum_t(\sqrt{1+\|\lambda_t\|^2\bar w_t}-1)\) | \(\sum_t(\sqrt{1+\|\lambda_t\|^2\bar I_t}-1)\) |
| Jeffreys-on-\(\varphi\) | **DROP** (evidence below) | not taped; mean atom is not a \(\varphi\to 0\) repair |
| Registry | `planned` / `phase4_prep` | `planned` / `phase4_prep` |

Helpers: `R/mspl-nbinom2-atoms.R`, `R/mspl-nbinom1-atoms.R`.
Oracles: `tests/testthat/test-mspl-nbinom2-admit-packet.R` (A1–A8 +
D-phi) and `test-mspl-nbinom1-admit-packet.R` (A1–A8). A7 is a live
`estimator="mspl"` / `se=FALSE` twin.

AGENT-INFERRED vanishing-scale analogy to Bernoulli / Poisson, using
**this** family's information-size proxy. Not a transferred theorem.

---

## Why the live door was not a packet

On `main` before this PR the public nbinom door already accepted a
finite call (`#1007`). The tape still reported \(c=1\) and Bernoulli
\(V_{\mathrm{loading}}\). Prep oracles N11 / E7 already kill that
loading transplant. Copying Poisson \(c_P\) would have been the same
class of transplant as copying Bernoulli \(c_n\).

---

## Pinned rates

Both rates freeze a **data-plugin** information size from observed
\(y\) and a per-trait method-of-moments \(\hat\varphi\). They do not
move with a known offset at fixed \(y\) (A3). They are not live
\(\mu(\beta)\) functions, so they stay a soft scale like \(c_P\) and
\(c_n\).

**NB2 MoM.** \(\hat\varphi_t=\bar y_t^2/\max(s_t^2-\bar y_t,\varepsilon)\).
Underdispersion versus Poisson (\(s^2\le\bar y\)) floors
\(\hat\varphi=10^8\) (Poisson *limit* of this proxy, not inheritance).
All-zero traits contribute \(\bar w=0\); all-zero data floors
\(I_{\mathrm{NB2}}=1\).

**NB1 MoM.** \(\hat\varphi_t=\max(s_t^2/\bar y_t-1,\varepsilon)\) with
Poisson-limit floor \(10^{-8}\) (NB1 recovers Poisson as
\(\varphi\to 0\)). \(\bar I_t=I_\eta(\bar y_t,\hat\varphi_t)\) uses the
taped PMF-sum truncation (`mu+12*sd`, ymax in \([8,80]\)), not the
quasi weight \(\bar y/(1+\hat\varphi)\).

Rejected transplants, pinned in A1:

- \(c=1\)
- Bernoulli \(c_n=2\sqrt{p_{\mathrm{free}}/N_{\mathrm{rows}}}\)
- Gaussian \(c_N=\sqrt{2/N_{\mathrm{units}}}\)
- Poisson \(c_P=2\sqrt{p_{\mathrm{free}}/\max(\sum y,1)}\)
- NB1 quasi \(\sum\mu/(1+\varphi)\)

At huge \(\hat\varphi\) (NB2) or tiny \(\hat\varphi\) (NB1) the proxy
can numerically approach \(c_P\). That is a limit, not a definition.

---

## Pinned loading atoms

Weight the radial term by the **family** information weight
(trait-mean of NB2 \(W\) or of NB1 exact \(I_\eta\)), evaluated at the
same data plugin as the rate.

- All-zero traits contribute 0. Jeffreys-on-\(\beta\) owns \(\mu\to 0\).
- Coercive as \(\|\lambda_t\|\to\infty\) at \(\bar w_t>0\) / \(\bar I_t>0\).
- Rotation-invariant in the factor space (row Euclidean norms).
- Recovers Bernoulli \(V_{\mathrm{loading}}\) only at unit weights;
  that coincidence is not a transfer.
- Poisson \(V_\lambda^P\) (raw \(\bar y_t\)) is a kill at finite
  overdispersion.

Laplace-marginal loading coercivity remains OPEN. This packet states
experimental-point status as honestly as Poisson #1008 did.

---

## NB2 Jeffreys-on-\(\varphi\): DROP

The mean atom \(P^*_{J,\mu}=\tfrac12\log\det(X_*^\top W X_*)\) with
\(W=\mu\varphi/(\varphi+\mu)\) already moves with \(\varphi\): it
collapses as \(\varphi\to 0\) and approaches the Poisson Jeffreys as
\(\varphi\to\infty\) (hostility: a silent push toward the Poisson
limit). A separate atom \(P^*_{J,\varphi}=\tfrac12\log I_{\varphi\varphi}\)
was the keep-or-drop question.

Evidence (D-phi oracle + E1/E3):

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
5. Exact \(I_{\varphi\varphi}\) is a PMF sum (expensive, tape-local,
   same class as the NB1 truncation caveat).

**Decision: DROP.** Do not tape \(\tfrac12\log I_{\varphi\varphi}\)
or \(\tfrac12\log I_{\log\varphi}\) in this packet. The mean atom's
\(\varphi\to\infty\) hostility stays a documented experimental-point
caveat, exactly as Poisson G0 left #990 admit-evidence FAIL in the
notes. A later sitting may tape the Jacobian-correct atom; this one
does not invent it.

NB1: the mean atom *increases* toward Poisson as \(\varphi\to 0\)
(N6) and cannot be used as a \(\varphi\to 0\) repair. No dedicated
\(\varphi\) atom is taped.

---

## Live TMB / R twins (A7)

A tiny ordinary `q=1` cell with `estimator="mspl"`, `se=FALSE`
checks `report$mspl_c_n`, `report$mspl_V_loading`, and
`report$mspl_logdet_information` against the R twins. The same test
fails if the tape still reports \(c=1\) or Bernoulli
\(V_{\mathrm{loading}}\). Registry status on the fit is `planned`.

---

## Still planned

Healthy / sparse multi-seed no-harm, labelled boundary DGPs
(\(\mu\to 0\), \(\varphi\to 0\), \(\varphi\to\infty\)), prediction,
penalty sensitivity, and the Shinichi admission gate remain OPEN.
Finite and matching oracles are necessary and not sufficient
(constitution Phase 4). Truncated / hurdle / mixed-family nbinom
stay out. No Totoro / DRAC from this packet (D-50 / D-139).

Optional local smoke: `dev/mspl-nbinom-multiseed-point-smoke.R`
(`se=FALSE`). Operational PASS is every arm finite and converged.
Admit-evidence PASS is not claimed from finiteness.

---

## 🔴 G0 ask (Shinichi, 5am)

This PR is **packet science only**. Please do **not** treat a green
CI as an admit.

1. **Do not flip tonight from this packet alone** unless you want the
   same experimental-point bar Poisson used after #1008 (atoms pinned,
   A7 green, #990-class smoke still allowed to be admit-evidence FAIL).
2. If you do want that bar: say which family (`nbinom2`, `nbinom1`,
   both) may move `planned` / `phase4_prep` → `admitted` /
   `admit_packet`. They are separate G0s.
3. Confirm **DROP** of NB2 Jeffreys-on-\(\varphi\), or send it back
   for a Jacobian-correct tape in a later sitting.
4. Public `se=TRUE` stays withheld. No NEWS `covered`.

Recommended next after G0: a later admit PR that only flips the
named rows and sweeps tests, or a keep-planned note if the atoms
need another derivation pass.
