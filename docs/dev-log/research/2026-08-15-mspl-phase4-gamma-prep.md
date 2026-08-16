# Phase 4-style prep — Gamma(log) LA-MSPL route (not admitted)

**Status:** design + local oracles + **`planned` registry rows only**.
Registry cells `gamma:log:ordinary:q1` and `q2` are
`status = "planned"`, `evidence = "phase4_prep"`. They are **not**
`admitted`. `.gllvmTMB_mspl_prepare()` still rejects Gamma at the
`family_id` fence (`fam_ids %in% c(0L, 1L, 2L)`; Gamma is
`family_id = 4`). **Verdict: PASS for oracles / planned rows, FAIL
for C++ / admission / `estimator = "mspl"` on Gamma.**

**Reader:** statistical method developer / TMB engineer who must
decide whether a later tape may add a Gamma mean-shape atom — and
who must not treat that atom as Poisson all-zero, Gaussian Hirose,
or the Tweedie \(p\to 2\) limit.

**Programme constitution:**
`docs/dev-log/after-task/2026-08-14-laplace-mspl-estimator-programme.md`

- **Phase 4** in that document is Poisson, then NB2 and NB1.
- Gamma is **not** in that Phase-4 queue. This note applies the
  Phase-4 *fences* (family-specific atom, named boundaries, no
  theorem transfer, oracles before any tape) so a later slice does
  not start from “Poisson worked” or “Tweedie \(p\to 2\) is Gamma.”

This is **LA-MSPL** (Laplace + a soft *outer* penalty), not EVA/VA,
not AGHQ-MSPL. There is **no** verified third-party theorem that
transfers Bernoulli Jeffreys/`V_loading`, Gaussian Hirose \(\Psi\),
Poisson \(W=\operatorname{diag}(\mu)\), or Tweedie
\(W=\operatorname{diag}(\mu^{2-p}/\phi)\) to a Gamma GLLVM under
Laplace (programme §7; Ranga corpus). Every formula below that is
not textbook Gamma GLM / mean-shape information is
**AGENT-INFERRED** and exists to pin oracles, not to license a tape.

## Why this family is not a Poisson cell and not Tweedie \(p\to 2\)

The live Laplace tape (`src/gllvmTMB.cpp`, `fid == 4`) is
mean-shape Gamma on the log link:

\[
\mu=e^{\eta},\qquad
\phi_{\gamma}=\exp(\texttt{log\_phi\_gamma}),\qquad
\text{scale}=\mu/\phi_{\gamma},\qquad
\operatorname{CV}(Y)=1/\sqrt{\phi_{\gamma}}.
\]

Support is \((0,\infty)\). There is **no** point mass at zero.
Public `sigma` is the CV \(1/\sqrt{\phi_{\gamma}}\), not a Gaussian
\(\sigma_{\varepsilon}\) and not Tweedie \(\phi\).

Textbook GLM algebra on the log link uses \(d\mu/d\eta=\mu\) and
\(V=\mu^2/\phi_{\gamma}\), so

\[
W(\phi_{\gamma})=\phi_{\gamma}.
\]

The weight **does not depend on \(\mu\)**. A \(\beta\)-only
Jeffreys atom therefore **cannot** see a \(\mu\to 0\) path. That
is the whole point of this prep. Poisson all-zero is a
\(\mu\to 0\) count path with \(W=\mu\). Tweedie at \(p\to 2^-\)
has \(W=1/\phi_{\mathrm{tw}}\), which equals \(\phi_{\gamma}\)
only after the identification \(\phi_{\mathrm{tw}}=1/\phi_{\gamma}\).
Those are limits and aliases, not this `family_id`.

Programme lock: ordinary Gamma
\(\log\mu_{it}=x_{it}^\top\beta+\lambda_t^\top u_i\), soft outer
penalty derived for *this* likelihood, separately. Do not
transplant Poisson, Bernoulli, Gaussian, or Tweedie atoms by
convenience. Do not treat `delta_gamma()` (`family_id` 13) as this
atom.

## 1. Five-row symbolic alignment

Gamma GLM expected information for free fixed coordinates
\(\beta_*\) at fixed shape \(\phi_{\gamma}\) is textbook:

\[
I(\beta_*)=\phi_{\gamma}\,X_*^\top X_*,
\qquad
P^*_{\mathrm{J}}=\tfrac12\log\det(I(\beta_*)).
\]

TMB minimises negative log-likelihood, so a later tape would add
\(-c\,P^*_{\mathrm{J}}\) together with any shape or loading atoms
that earn their own coercivity proofs. The soft rate \(c\) is
**not** pinned here: Bernoulli
\(c_n=2\sqrt{p_{\mathrm{free}}/N_{\mathrm{eff}}}\), Gaussian
\(c_N=\sqrt{2/N}\), and the still-open Poisson rate are all
rejected transplants (kill list §6).

Exact log-det scaling, used as an oracle identity:

\[
P^*_{\mathrm{J}}(c\,\phi_{\gamma})
=P^*_{\mathrm{J}}(\phi_{\gamma})+\tfrac{p_*}{2}\log c,
\qquad p_*=\mathrm{ncol}(X_*).
\]

Mean and shape are orthogonal in this exponential-dispersion
family. Per observation,

\[
I_{\phi_{\gamma},\phi_{\gamma}}=\psi'(\phi_{\gamma})-1/\phi_{\gamma},
\]

with \(\psi'\) the trigamma function (oracle E4). As
\(\phi_{\gamma}\to 0^+\), \(I_{\phi\phi}\to+\infty\); as
\(\phi_{\gamma}\to\infty\), \(I_{\phi\phi}\to 0\). A
\(\tfrac12\log I_{\phi\phi}\) atom therefore *rewards* shape
collapse to 0 on the maximisation scale. The \(\beta\)-atom is
the object that diverges to \(-\infty\) as \(\phi_{\gamma}\to 0\).

| Criterion | Atom | Parameters | TMB-shaped expression on paper | Interpretation |
|---|---|---|---|---|
| Gamma Jeffreys-shaped \(P^*_{\mathrm{J}}\) | \(\tfrac12\log\det(\phi_{\gamma} X_*^\top X_*)\) | free \(\beta_*\); \(\phi_{\gamma}>0\) | \(\mathrm{nll}\mathrel{+}=-c\,P^*_{\mathrm{J}}\) | Softens \(\phi_{\gamma}\to 0\) (CV explosion). **Mean-inert.** |
| Information size | \(\operatorname{tr}(W)=n\phi_{\gamma}\) | \(\phi_{\gamma}\) | diagnostic only | Size of the Gamma GLM information. **Not** \(\sum\mu\), **not** row count alone. |
| Shape information | \(I_{\phi\phi}=\psi'(\phi)-1/\phi\) | \(\phi_{\gamma}\) | diagnostic only | Orthogonal to \(\beta\). Not a \(\phi\to 0\) repair. |
| Contrast: Poisson \(W=\operatorname{diag}(\mu)\) | \(\tfrac12\log\det(X_*^\top\operatorname{diag}(\mu)X_*)\) | \(\mu\) only | Phase 4 planned Poisson atom | Sees \(\mu\to 0\); Gamma \(W\) does not. Oracle kill. |
| Contrast: Tweedie \(p\to 2\) / Bernoulli \(V_{\mathrm{loading}}\) / Gaussian Hirose | \(W=1/\phi_{\mathrm{tw}}\) / \(\sum_t(\sqrt{1+\|\lambda_t\|^2}-1)\) / \(\sum_j S_{jj}/\psi_j\) | \(\phi_{\mathrm{tw}}\), \(\Lambda\), or \(\Psi\) | sibling prep / live binary tape / Phase 3 | Wrong object or unattained limit. Oracle kill. |

Existence / coercivity sketch used as the oracle contract
(fixed-design slice first; latent loadings deferred):

- **G1** \(P^*_{\mathrm{J}}\) is continuous for \(\phi_{\gamma}>0\)
  and full-rank \(X_*\). It does **not** depend on \(\mu\).
- **G2** Along a mean path \(\mu\to 0\) at fixed \(\phi_{\gamma}\),
  \(W\) and \(P^*_{\mathrm{J}}\) are exactly constant. There is no
  Poisson-style all-zero signal in the \(\beta\)-atom.
- **G3** Along \(\phi_{\gamma}\to 0\) at fixed \(X_*\),
  \(P^*_{\mathrm{J}}\to-\infty\). This is the named overdispersion
  / CV-explosion boundary.
- **G4** Along \(\phi_{\gamma}\to\infty\),
  \(P^*_{\mathrm{J}}\to+\infty\). The \(\beta\)-atom *rewards*
  deterministic collapse. It is not a \(\phi\to\infty\) repair.
- **G5** \(\Pr(Y=0)=0\) for \(\phi_{\gamma}>0\). Mass-at-zero
  stories belong to Poisson, Tweedie CPG, or `delta_gamma`, not
  here.

Latent loading coercivity under Laplace is **OPEN**. The mean-model
atom is **fixed-only / conditional** GLM information, evaluated at
\(\eta=X_{\mathrm{fix}}b_{\mathrm{fix}}+\mathrm{offset}\) before any
latent-score contribution — the same convention the live tape
records at `src/gllvmTMB.cpp`. Laplace-marginal information for
\(\beta\) remains **OPEN**.

## 2. Named boundaries

### Mean \(\mu\to 0\) (inert)

\(W=\phi_{\gamma}\) does not move. A later “Gamma all-zero” story
that only talks about \(\mu\to 0\) is empty. Gamma cannot produce
exact zeros.

### Shape collapse \(\phi_{\gamma}\to 0\) (CV \(\to\infty\))

Variance \(\mu^2/\phi_{\gamma}\to\infty\). \(P^*_{\mathrm{J}}\) on
\(\beta\) goes to \(-\infty\). This is the one boundary the
\(\beta\)-atom can see.

### Shape explosion \(\phi_{\gamma}\to\infty\) (CV \(\to 0\))

The law concentrates at \(\mu\). \(P^*_{\mathrm{J}}\) grows like
\(\log\phi_{\gamma}\). Do not rename \(\phi_{\gamma}\) to \(\psi\)
and import Hirose \(\sum S_{jj}/\psi_j\).

### Loading runaway (named, not solved)

On \(\log\mu=\eta_{\mathrm{fix}}+\lambda^\top u\), large
\(\|\lambda\|\) can send some units’ means to \(+\infty\) and
others toward \(0\). That is a *different* boundary from
\(\phi_{\gamma}\to 0\). **No Gamma loading atom is admitted in
this note.**

## 3. Why Poisson, Tweedie \(p\to 2\), Bernoulli, and Hirose do not transfer

1. **Weights.** Gamma \(W=\phi_{\gamma}\) equals Poisson \(W=\mu\)
   never, except by numerical accident on one design. Doubling
   \(\mu\) doubles Poisson \(I\) and leaves Gamma \(I\) unchanged
   (oracle E2, E5).
2. **Zeros.** Poisson all-zero identifies \(\mu\). Gamma has
   \(\Pr(Y=0)=0\) (oracle E6).
3. **Tweedie \(p\to 2\).** \(W\to 1/\phi_{\mathrm{tw}}\). Matching
   Gamma requires \(\phi_{\mathrm{tw}}=1/\phi_{\gamma}\) *and*
   pretending \(p=2\) is attained. The package map never attains
   \(p=2\). The Tweedie sibling note already forbids this claim.
4. **\(V_{\mathrm{loading}}\)** is \((\mu,\phi_{\gamma})\)-inert
   (oracle E8).
5. **Hirose \(\Psi\).** Ordinary Gamma rows have a shape, not a
   free unique-variance Heywood coordinate. Fabricating
   \(\psi=1/\phi_{\gamma}\) or \(\psi=1/\mu\) is a type error
   (oracle E7).

## 4. Kill list — fail the later derivation on any of these

1. Transplant of Poisson \(W=\operatorname{diag}(\mu)\).
2. Treating Gamma as “Tweedie at \(p=2\).”
3. Transplant of Bernoulli \(V_{\mathrm{loading}}\) or \(W_g\).
4. Transplant of Gaussian Hirose / Akaike \(\Psi\), including
   \(\psi:=\phi_{\gamma}\) or \(\psi:=1/\mu\).
5. Using the \(\beta\)-atom as a \(\phi_{\gamma}\to\infty\) repair
   (it rewards collapse; G4).
6. Reuse of Bernoulli \(c_n\), Gaussian \(c_N\), or an unpinned
   Poisson rate.
7. Treating \(\sum\mu\) or row count as interchangeable with
   \(n\phi_{\gamma}\).
8. Claiming Design 88, Sterzinger–Kosmidis–Moustaki 2026, Poisson
   Phase 4, or Tweedie prep covers Gamma GLLVM MSPL under Laplace.
9. Finiteness of a small-mean Gamma fit offered as the scientific
   result.
10. `delta_gamma` / mixed-family inheritance.
11. Any admission-shaped language (status flip to `admitted`, NEWS
    covered, validation-register promotion, C++ tape) ahead of the
    Shinichi gate **and** ahead of the constitution’s Phase 4
    Poisson/NB order.
12. Live `gllvmTMB(..., estimator = "mspl")` on Gamma in tests.
13. Quietly widening `.gllvmTMB_mspl_prepare()` to `family_id` 4.

## 5. Oracle contract (pure R; no Gamma `estimator="mspl"`)

| ID | What | Tolerance / decision |
|---|---|---|
| E1 | \(I=\phi X^\top X\); Poisson, Bernoulli, and raw Tweedie-\(p=2\) \(W=1/\phi\) **differ** | rel. err \(<10^{-12}\) on Gamma; contrasts fire |
| E2 | Mean path is inert; Poisson \(I\) on the same path collapses | exact constancy; Poisson contrast |
| E3 | \(\phi\to 0\) sends \(P^*_{\mathrm{J}}\to-\infty\); \(\phi\to\infty\) raises it; log-det scaling | monotone; exact \(+\frac{p_*}{2}\log c\) |
| E4 | \(I_{\phi\phi}=\psi'(\phi)-1/\phi\); orthogonal increment in \(\phi\); boundaries flip | rel. err; sign of the two limits |
| E5 | Information size is \(n\phi\), not \(\sum\mu\) | exact; contrasts |
| E6 | \(\Pr(Y=0)=0\); Poisson all-zero does not transfer | `dgamma(0)=0` |
| E7 | Hirose \(\sum S/\psi\) refused | structural reject |
| E8 | \(\partial V_{\mathrm{loading}}/\partial(\mu,\phi)\equiv 0\); \(P^*_{\mathrm{J}}\) moves with \(\phi\) | finite-diff |
| E9 | Registry rows `planned` / `phase4_prep`; **not** `admitted` | lookup |
| E10 | This file never calls live MSPL; prepare not widened to 4 | source scan |

## 6. Verdict

| Surface | Verdict | Why |
|---|---|---|
| Local R oracles / this writeup | **PASS** | Mean-inert \(W=\phi\), shape boundaries, and the Tweedie/Poisson kills are testable without a Gamma MSPL fit. |
| Registry `planned` rows | **PASS as planned only** | `gamma:log:ordinary:q1/q2`. Not a public claim. |
| Registry `admitted` / C++ tape / live Gamma MSPL | **FAIL** | No tape, no prepare widen, no Shinichi admission gate. |
| NEWS / covered / SE / intervals | **FAIL** | Out of scope; SE remains PROTECTED on Codex Lane B. |

Preferred later-admission *candidate* for the fixed-effect slice:
Gamma Jeffreys-shaped \(\tfrac12\log\det(\phi_{\gamma} X_*^\top X_*)\),
with rate, shape atom, loading atom, and Laplace-marginal
\(I(\beta)\) still OPEN. Not a theorem transfer.

## 7. Non-claims

This note does **not** claim calibrated inference, a live Gamma
`estimator = "mspl"` fit, that Bernoulli / Gaussian / Poisson /
Tweedie atoms transfer, that Laplace is exact for Gamma, that
\(p\to 2\) is this cell, NB / delta / hurdle / mixed-family MSPL,
structured tiers, or that this atom is the Laplace-marginal
information for \(\beta\).

## 8. Rose boundary

- **Not EVA / not VA.**
- **`planned` ≠ `admitted`.**
- **Prepare fence unchanged.** `family_id` still only `{0,1,2}`.
- **No C++.** `git diff -- src/` must stay empty on this arc.
- **No NEWS covered.**
- **No repo-root `LOOP/`.** Lane kit:
  `docs/dev-log/lanes/cursor-mspl-phase4-gamma-lognormal/LOOP/`.
- **No family transfer.** Poisson Phase 4 and Tweedie prep are
  siblings, not licences.

## Out of scope here

Campaigns, Totoro/DRAC, NEWS, admission, C++ tape,
`estimator = "mspl"` on Gamma, `delta_gamma`, identity-link Gamma
(constructor-rejected), public `se=TRUE`.
