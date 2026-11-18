# Phase 4-style prep — lognormal(log) LA-MSPL route (not admitted)

**Status:** design + local oracles + **`planned` registry rows only**.
Registry cells `lognormal:log:ordinary:q1` and `q2` are
`status = "planned"`, `evidence = "phase4_prep"`. They are **not**
`admitted`. `.gllvmTMB_mspl_prepare()` still rejects lognormal at
the `family_id` fence (`fam_ids %in% c(0L, 1L, 2L)`; lognormal is
`family_id = 3`). **Verdict: PASS for oracles / planned rows, FAIL
for C++ / admission / `estimator = "mspl"` on lognormal.**

**Reader:** statistical method developer / TMB engineer who must
decide whether a later tape may add a lognormal-on-log-\(y\) atom
— and who must not treat that atom as Gaussian identity MSPL,
Gamma(log), or `delta_lognormal`.

**Programme constitution:**
`docs/dev-log/after-task/2026-08-14-laplace-mspl-estimator-programme.md`

- **Phase 3** is ordinary Gaussian (Hirose \(\Psi\), pinned
  \(\sigma_{\varepsilon}\)).
- **Phase 4** is Poisson, then NB.
- Lognormal is **not** in either queue as a proved cell. This
  note applies the Phase-4 *fences* so a later slice does not
  start from “Gaussian worked, and lognormal is Gaussian on
  \(\log y\).”

This is **LA-MSPL** (Laplace + a soft *outer* penalty), not EVA/VA,
not AGHQ-MSPL. There is **no** verified third-party theorem that
transfers Bernoulli Jeffreys/`V_loading`, Gaussian Hirose \(\Psi\),
Poisson \(W=\operatorname{diag}(\mu)\), or Gamma \(W=\phi_{\gamma}\)
to a lognormal GLLVM under Laplace (programme §7; Ranga corpus).
Every formula below that is not textbook lognormal / Gaussian-on-
\(\log y\) information is **AGENT-INFERRED** and exists to pin
oracles, not to license a tape.

## Why this family is not Gaussian identity and not Gamma(log)

The live Laplace tape (`src/gllvmTMB.cpp`, `fid == 3`) is

\[
\log y\sim\mathcal{N}(\eta,\sigma_{\varepsilon}^2),
\qquad
\ell=\log\varphi(\log y;\eta,\sigma_{\varepsilon})-\log y.
\]

The R constructor requires `lognormal(link = "log")`. The linear
predictor is **identity on \(\log y\)**: \(\eta=\mathrm{E}[\log Y]\).
The Jacobian \(-\log y\) does **not** depend on \((\eta,\sigma_{\varepsilon})\).

Two scientific facts that kill naive transfers:

1. **\(\mathrm{E}[Y]=\exp(\eta+\sigma_{\varepsilon}^2/2)\)**, not
   \(\exp(\eta)\). Gamma(log) reads \(\mathrm{E}[Y]=\exp(\eta)\).
   The same \(\eta\) is a different mean (oracle E2).
2. **\(\sigma_{\varepsilon}\) is shared with Gaussian**
   (`family_id` \(\in\{0,3\}\); `log_sigma_eps` is mapped off
   only when neither family is present). Shared plumbing is **not**
   a theorem that Gaussian Phase-3 Hirose, or Gaussian identity
   MSPL on \(y\), covers lognormal. Phase 3 pins
   \(\sigma_{\varepsilon}\) and penalises free \(\Psi\). Ordinary
   lognormal in this prep cell has a shared residual SD on
   \(\log y\), not a per-trait Heywood \(\psi_j\).

Support is \((0,\infty)\). There is **no** point mass at zero.
`delta_lognormal()` is `family_id` 12 (hurdle) and is a different
atom.

Programme lock: ordinary lognormal
\(\log y_{it}=x_{it}^\top\beta+\lambda_t^\top u_i+\varepsilon_{it}\),
soft outer penalty derived for *this* likelihood, separately.

## 1. Five-row symbolic alignment

Expected information for free fixed coordinates \(\beta_*\) at
fixed \(\sigma_{\varepsilon}\) is the Gaussian identity formula
**on the working response \(\log y\)**:

\[
I(\beta_*)=\sigma_{\varepsilon}^{-2}\,X_*^\top X_*,
\qquad
W=1/\sigma_{\varepsilon}^2,
\qquad
P^*_{\mathrm{J}}=\tfrac12\log\det(I(\beta_*)).
\]

TMB minimises negative log-likelihood, so a later tape would add
\(-c\,P^*_{\mathrm{J}}\). The soft rate \(c\) is **not** pinned:
Bernoulli \(c_n\), Gaussian \(c_N=\sqrt{2/N}\), and the open
Poisson rate are rejected transplants. Reusing Gaussian \(c_N\)
because the working model is Gaussian-on-\(\log y\) is still a
transfer until someone writes the rate against the *Laplace*
objective for this family (kill list §6).

Exact log-det scaling:

\[
P^*_{\mathrm{J}}(c\,\sigma_{\varepsilon})
=P^*_{\mathrm{J}}(\sigma_{\varepsilon})-p_*\log c.
\]

Per observation, \(I_{\sigma,\sigma}=2/\sigma_{\varepsilon}^2\)
(oracle E4). Mean and scale are orthogonal. The Jacobian
\(-\log y\) does not enter either information block.

| Criterion | Atom | Parameters | TMB-shaped expression on paper | Interpretation |
|---|---|---|---|---|
| Lognormal Jeffreys-shaped \(P^*_{\mathrm{J}}\) | \(\tfrac12\log\det(\sigma_{\varepsilon}^{-2} X_*^\top X_*)\) | free \(\beta_*\); \(\sigma_{\varepsilon}>0\) | \(\mathrm{nll}\mathrel{+}=-c\,P^*_{\mathrm{J}}\) | Softens \(\sigma_{\varepsilon}\to\infty\). **Mean-inert** in \(\eta\). |
| Information size | \(\operatorname{tr}(W)=n/\sigma_{\varepsilon}^2\) | \(\sigma_{\varepsilon}\) | diagnostic only | **Not** \(\sum\mu\), **not** \(\sum e^{\eta}\), **not** row count alone. |
| Contrast: Gamma \(W=\phi_{\gamma}\) | \(\tfrac12\log\det(\phi_{\gamma} X_*^\top X_*)\) | shape | sibling Gamma prep | Same matrix shape, different scientific \(\mu\) and different dispersion. |
| Contrast: Gaussian Hirose / identity-on-\(y\) | \(\sum_j S_{jj}/\psi_j\) / \(I=X^\top X/\sigma^2\) on \(y\) | \(\Psi\) or \(y\)-scale \(\sigma\) | Phase 3 admitted Gaussian | Wrong response, wrong unique-variance object. Oracle kill. |
| Contrast: Poisson \(W=\mu\) / Bernoulli \(V_{\mathrm{loading}}\) | count / radial | \(\mu\) or \(\Lambda\) | Phase 4 / Design 88 | Wrong support and wrong weights. |

Existence / coercivity sketch (fixed-design slice first):

- **L1** \(P^*_{\mathrm{J}}\) is continuous for
  \(\sigma_{\varepsilon}>0\) and full-rank \(X_*\). It does **not**
  depend on \(\eta\).
- **L2** Along a mean path \(\eta\to-\infty\) at fixed
  \(\sigma_{\varepsilon}\), \(W\) and \(P^*_{\mathrm{J}}\) are
  exactly constant. \(\mathrm{E}[Y]\to 0\) is invisible to the
  \(\beta\)-atom.
- **L3** Along \(\sigma_{\varepsilon}\to\infty\),
  \(P^*_{\mathrm{J}}\to-\infty\).
- **L4** Along \(\sigma_{\varepsilon}\to 0\),
  \(P^*_{\mathrm{J}}\to+\infty\). The \(\beta\)-atom *rewards*
  residual collapse. It is not a \(\sigma\to 0\) repair.
- **L5** \(\Pr(Y=0)=0\). Zero-mass stories belong to Poisson,
  Tweedie CPG, or `delta_lognormal`, not here.

Latent loading coercivity under Laplace is **OPEN**. The atom is
**fixed-only / conditional** GLM information before any
latent-score contribution. Laplace-marginal \(I(\beta)\) remains
**OPEN**. Mixed gaussian+lognormal composition (shared
\(\sigma_{\varepsilon}\)) is a Phase-6 question and is **OPEN**.

## 2. Named boundaries

### Linear predictor \(\eta\to\pm\infty\) (inert for \(I(\beta)\))

\(W=1/\sigma_{\varepsilon}^2\) does not move. Small medians
\(\mathrm{e}^{\eta}\) are not a Poisson all-zero path.

### Residual explosion \(\sigma_{\varepsilon}\to\infty\)

Information on \(\beta\) vanishes. This is the one boundary the
\(\beta\)-atom can see.

### Residual collapse \(\sigma_{\varepsilon}\to 0\)

\(P^*_{\mathrm{J}}\) grows like \(-\log\sigma_{\varepsilon}\). Do
not rename \(\sigma_{\varepsilon}^2\) to \(\psi\) and import
Hirose.

### Shared \(\sigma_{\varepsilon}\) with Gaussian (named, not solved)

A mixed-family fit with `family_id` 0 and 3 shares one residual
SD. That is a composition constraint, not evidence that Phase 3
covers this cell.

### Loading runaway (named, not solved)

Large \(\|\lambda\|\) on \(\log y=\eta_{\mathrm{fix}}+\lambda^\top u\)
is a different boundary. **No lognormal loading atom is admitted
in this note.**

## 3. Why Gaussian, Gamma, Poisson, and Hirose do not transfer

1. **Response.** Gaussian Phase 3 is identity on \(y\). Lognormal
   is identity on \(\log y\) plus a parameter-free Jacobian
   (oracle E4, E7).
2. **Mean.** Gamma(log) uses \(\mathrm{E}[Y]=\mathrm{e}^{\eta}\).
   Lognormal uses \(\mathrm{E}[Y]=\mathrm{e}^{\eta+\sigma^2/2}\)
   (oracle E2).
3. **Unique variance.** Hirose targets per-trait \(\psi_j\to 0\).
   The live lognormal residual is a *shared* \(\sigma_{\varepsilon}\).
   Fabricating \(\psi=\sigma_{\varepsilon}^2\) or \(\psi=1/\mu\) is
   a type error (oracle E8).
4. **Zeros.** \(\Pr(Y=0)=0\) (oracle E6). `delta_lognormal` is
   `family_id` 12.
5. **\(V_{\mathrm{loading}}\)** is \((\eta,\sigma)\)-inert
   (oracle E9).

## 4. Kill list — fail the later derivation on any of these

1. Claiming lognormal MSPL *is* Gaussian Phase-3 MSPL because
   \(\log y\) is Gaussian.
2. Transplant of Gamma \(W=\phi_{\gamma}\) or
   \(\mathrm{E}[Y]=\mathrm{e}^{\eta}\).
3. Transplant of Poisson \(W=\operatorname{diag}(\mu)\).
4. Transplant of Bernoulli \(V_{\mathrm{loading}}\) or \(W_g\).
5. Transplant of Gaussian Hirose, including
   \(\psi:=\sigma_{\varepsilon}^2\).
6. Reuse of Gaussian \(c_N\) without a lognormal-Laplace rate
   argument.
7. Treating \(\sum\mu\), \(\sum\mathrm{e}^{\eta}\), or row count
   as interchangeable with \(n/\sigma_{\varepsilon}^2\).
8. Claiming Design 88, Poisson Phase 4, Gamma prep, or the
   shared `sigma_eps` map covers lognormal GLLVM MSPL under
   Laplace.
9. Finiteness of a small-median lognormal fit offered as the
   scientific result.
10. `delta_lognormal` / mixed-family inheritance.
11. Any admission-shaped language (status flip to `admitted`,
    NEWS covered, C++ tape) ahead of the Shinichi gate **and**
    ahead of the constitution’s Phase 4 Poisson/NB order.
12. Live `gllvmTMB(..., estimator = "mspl")` on lognormal in tests.
13. Quietly widening `.gllvmTMB_mspl_prepare()` to `family_id` 3.
14. Public `se=TRUE` on this cell.

## 5. Oracle contract (pure R; no lognormal `estimator="mspl"`)

| ID | What | Tolerance / decision |
|---|---|---|
| E1 | \(I=X^\top X/\sigma^2\); Gamma and Poisson weights **differ** | rel. err \(<10^{-12}\); contrasts |
| E2 | \(\mathrm{E}[Y]=\mathrm{e}^{\eta+\sigma^2/2}\neq\mathrm{e}^{\eta}\); mean path inert | exact; constancy |
| E3 | \(\sigma\to\infty\) sends \(P^*_{\mathrm{J}}\to-\infty\); \(\sigma\to 0\) raises it; log-det scaling | monotone; exact \(-p_*\log c\) |
| E4 | Jacobian \(-\log y\) parameter-free; \(I_{\sigma}=2/\sigma^2\) | exact |
| E5 | Information size is \(n/\sigma^2\), not \(\sum\mu\) | exact; contrasts |
| E6 | \(\Pr(Y=0)=0\); not `delta_lognormal` | `dlnorm(0)=0`; `3L != 12L` |
| E7 | Shared \(\sigma_{\varepsilon}\) algebra \(\neq\) Gaussian-on-\(y\) claim | contrast on the mean |
| E8 | Hirose refused | structural reject |
| E9 | \(V_{\mathrm{loading}}\) inert; \(P^*_{\mathrm{J}}\) moves with \(\sigma\) | finite-diff |
| E10 | Registry rows `planned` / `phase4_prep`; **not** `admitted`; no live MSPL; prepare not widened to 3 | lookup + source scan |
| E11 | \(c_L=2\sqrt{p_{\mathrm{free}}/\max(n/\sigma^2,1)}\); \(c_n\), \(c_N\), \(c_P\), \(c=1\) differ | exact; contrasts |
| E12 | Floor at \(n/\sigma^2<1\); vanishes as info grows; \(\eta\)-inert | exact |
| E13 | \(\sigma\to\infty\Rightarrow V_\lambda^L\to 0\); \(\sigma=1\) recovers Bernoulli | exact |
| E14 | Coercive as \(\|\lambda\|\) grows at finite \(\sigma\); silent as \(\sigma\to\infty\) | monotone |
| E15 | \(V_\lambda^L\) is \(\sigma\)-aware; Bernoulli \(V\) is not | finite-diff |
| E16 | Not Hirose; not \(c_N\); shared \(\sigma\neq\) per-trait \(\phi\) | contrasts |

## 6. Verdict

| Surface | Verdict | Why |
|---|---|---|
| Local R oracles / this writeup | **PASS** | Mean-inert \(W=1/\sigma^2\), the \(\mathrm{E}[Y]\) split, and the Gaussian/Gamma kills are testable without a lognormal MSPL fit. |
| Registry `planned` rows | **PASS as planned only** | `lognormal:log:ordinary:q1/q2`. Not a public claim. |
| Registry `admitted` / C++ tape / live lognormal MSPL | **FAIL** | No tape, no prepare widen, no Shinichi admission gate. |
| NEWS / covered / SE / intervals | **FAIL** | Out of scope; SE remains PROTECTED on Codex Lane B. |

Preferred later-admission *candidate* for the fixed-effect slice:
lognormal Jeffreys-shaped
\(\tfrac12\log\det(\sigma_{\varepsilon}^{-2} X_*^\top X_*)\),
with oracle-pinned
\(c_L=2\sqrt{p_{\mathrm{free}}/\max(n/\sigma_\varepsilon^2,1)}\)
and
\(V_\lambda^L=\sum_t(\sqrt{1+\|\lambda_t\|^2/\sigma_\varepsilon^2}-1)\)
(`docs/dev-log/research/2026-08-16-mspl-gamma-lognormal-atom-pin.md`,
E11–E16). Residual atom, shared-\(\sigma_{\varepsilon}\)
composition, and Laplace-marginal \(I(\beta)\) still OPEN.
Not a theorem transfer. Not a Gaussian transfer. Not a tape.

## 7. Non-claims

This note does **not** claim calibrated inference, a live
lognormal `estimator = "mspl"` fit, that Gaussian Hirose or
Gamma \(W=\phi\) transfer, that Laplace is exact, that shared
`sigma_eps` is a licence, delta / hurdle / mixed-family MSPL,
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
- **No family transfer.** Gaussian Phase 3 and Gamma prep are
  siblings, not licences.

## Out of scope here

Campaigns, Totoro/DRAC, NEWS, admission, C++ tape,
`estimator = "mspl"` on lognormal, `delta_lognormal`, public
`se=TRUE`, mixed gaussian+lognormal composition.
