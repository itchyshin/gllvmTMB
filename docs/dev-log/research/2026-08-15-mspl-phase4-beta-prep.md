# Phase 4 prep — Beta (logit) LA-MSPL route (not admitted)

**Status:** design + local oracles only. **No** `beta:*` MSPL registry
row is created. `.gllvmTMB_mspl_prepare()` still rejects every
non-binomial / non-gaussian family at the `family_id` fence
(`fam_ids %in% c(0L, 1L)`). Beta is `family_id` 7. **Verdict: PASS
for oracles / this writeup, FAIL for C++ / admission / registry
rows / `estimator = "mspl"` on Beta.**

**Reader:** statistical method developer / TMB engineer who must
decide whether a later tape may add a Beta proportion atom.

**Programme constitution:**
`docs/dev-log/after-task/2026-08-14-laplace-mspl-estimator-programme.md`
§Phase 5 names *beta / beta-binomial* among the bounded-mean and
shape-parameter cells (Phase 4 in that document is Poisson then
NB). This note is Phase-4-*style* prep — information atom,
boundary objects, and pure-R oracles — so a later Phase 5
derivation does not start from a blank page. It does **not** jump
the admission queue and it does **not** reopen Poisson or
Gaussian.

This is **LA-MSPL** (Laplace + a soft *outer* penalty), not EVA/VA,
not AGHQ-MSPL. There is **no** verified third-party theorem that
transfers Bernoulli Jeffreys / `V_loading`, Gaussian Hirose
\(\Psi\), or Poisson \(W=\operatorname{diag}(\mu)\) to a Beta GLLVM
under Laplace (programme §7; Ranga corpus). Every formula below
that is not textbook Beta-regression information (Ferrari &
Cribari-Neto 2004; Smithson & Verkuilen 2006) is **AGENT-INFERRED**
and exists to pin oracles, not to license a tape.

## Why this family is not a Bernoulli logit cell

Both families use a logit mean. That is the whole resemblance.

Bernoulli \(y\in\{0,1\}\) can separate: an all-zero or all-one
trait sends \(\|\beta\|\to\infty\) and Fisher weights
\(W_g=\mu(1-\mu)\to 0\). Design 88’s Jeffreys atom is built for
that discrete boundary.

Beta \(y\in(0,1)\) is **continuous**. Exact 0/1 never occur (the
tape clamps \(y\) at \(10^{-12}\) only as a numerical guard;
`delta_beta()` is a different family). The mean-precision model is

\[
y\sim\mathrm{Beta}(a,b),\qquad
a=\mu\phi,\quad b=(1-\mu)\phi,\qquad
\operatorname{logit}\mu=\eta=x^\top\beta+\lambda^\top u,
\]

with per-trait \(\phi=\exp(\texttt{log\_phi\_beta})\) (public
`sigma` stores \(\phi=1/\sigma^2\);
`docs/design/03-likelihoods.md`). Variance
\(\mu(1-\mu)/(1+\phi)\) is not a Bernoulli trial variance and not
a Poisson mean.

A logit link is not a theorem transfer. Do not keep Bernoulli
atoms “because Beta is also logit.”

## 1. Five-row symbolic alignment

Textbook expected information for free fixed coordinates
\(\beta_*\) at fixed \(\phi\) (Ferrari & Cribari-Neto 2004; logit
link) is

\[
I(\beta_*)=X_*^\top W(\mu,\phi)\,X_*,
\qquad
w(\mu,\phi)=\phi^2\bigl[\mu(1-\mu)\bigr]^2
\bigl\{\psi'(\mu\phi)+\psi'\bigl((1-\mu)\phi\bigr)\bigr\}.
\]

A Jeffreys-shaped fixed-effect atom on the *maximised*
log-likelihood scale is therefore

\[
P^*_{\mathrm{J}}=\tfrac12\log\det\bigl(X_*^\top W(\mu,\phi)X_*\bigr).
\]

TMB minimises negative log-likelihood, so a later tape would add
\(-c\,P^*_{\mathrm{J}}\) together with any precision / loading
atoms that earn their own coercivity proofs. The soft rate \(c\)
is **not** pinned here: Bernoulli
\(c_n=2\sqrt{p_{\mathrm{free}}/N_{\mathrm{eff}}}\) and Gaussian
\(c_N=\sqrt{2/N}\) are both rejected transplants (kill list §5).

The precision block (one observation; sum over rows) is

\[
I_{\phi\phi}=-\psi'(\phi)+\mu^2\psi'(\mu\phi)+(1-\mu)^2\psi'\bigl((1-\mu)\phi\bigr).
\]

The cross-term is **not** zero except at \(\mu=1/2\):

\[
I_{\eta\phi}=\phi\,\mu(1-\mu)
\bigl\{\mu\psi'(\mu\phi)-(1-\mu)\psi'\bigl((1-\mu)\phi\bigr)\bigr\}.
\]

| Criterion | Atom | Parameters | TMB-shaped expression on paper | Interpretation |
|---|---|---|---|---|
| Beta Jeffreys-shaped \(P^*_{\mathrm{J}}\) | \(\tfrac12\log\det(X_*^\top W(\mu,\phi)X_*)\) with \(w\) above | free \(\beta_*\); \(\mu=\operatorname{logit}^{-1}(\eta)\); \(\phi>0\) | \(\mathrm{nll}\mathrel{+}=-c\,P^*_{\mathrm{J}}\) | Mean-model information. \(\beta\)- and \(\phi\)-dependent. **Not** Bernoulli \(W_g=\mu(1-\mu)\). |
| Precision information | \(I_{\phi\phi}\) (and \(I_{\eta\phi}\)) | \(\phi_t=\exp(\texttt{log\_phi\_beta}_t)\) | diagnostic / later atom; not taped | \(\phi\to\infty\) weakly identifies precision; \(\phi\to 0\) is U-shaped shape collapse. Not orthogonal to \(\beta\). |
| Shape coordinates | \(a=\mu\phi\), \(b=(1-\mu)\phi\) | \((\mu,\phi)\) jointly | `src/gllvmTMB.cpp` fid 7 | \(a\to 0\) can be \(\mu\to 0\) *or* \(\phi\to 0\). Three objects, not one. |
| Contrast: Bernoulli \(W_g\) / \(V_{\mathrm{loading}}\) | \(\mu(1-\mu)\); \(\sum_t(\sqrt{1+\|\lambda_t\|^2}-1)\) | \(\mu\) or \(\Lambda\) | live Design 88 | Discrete separation atom + \(\mu\)-inert loading atom. Oracle kill. |
| Contrast: Poisson \(W=\operatorname{diag}(\mu)\) and Gaussian Hirose | \(\operatorname{diag}(\mu)\); \(\sum_j S_{jj}/\psi_j\) | count mean or diagonal \(\Psi\) | Phase 3 / Poisson Phase-4 notes | No Poisson mean and no free Gaussian \(\Psi\) in this Beta cell. Oracle kill. |

Existence / coercivity sketch used as the oracle contract
(fixed-design slice first; latent loadings deferred):

- **B1** \(P^*_{\mathrm{J}}\) is continuous for \(\mu\in(0,1)\),
  \(\phi>0\), and full-rank \(X_*\).
- **B2** Along \(\mu\to 0\) or \(\mu\to 1\) at **fixed** \(\phi\),
  \(\psi'(\mu\phi)\sim 1/(\mu\phi)^2\) cancels
  \([\mu(1-\mu)]^2\), so \(w(\mu,\phi)\to 1\) and
  \(P^*_{\mathrm{J}}\to\tfrac12\log\det(X_*^\top X_*)\), which is
  **finite**. A Bernoulli-style “Jeffreys diverges at the mean
  boundary” claim is **false** for Beta (oracle E2).
- **B3** For any \(y\in(0,1)\) the Beta log-density
  \(\ell=\log\Gamma(\phi)-\log\Gamma(a)-\log\Gamma(b)+(a-1)\log y+(b-1)\log(1-y)\)
  satisfies \(\ell\to-\infty\) as \(\lvert\eta\rvert\to\infty\)
  (as \(a\to 0\) or \(b\to 0\), \(-\log\Gamma(a)\) or
  \(-\log\Gamma(b)\) diverges). The unpenalised mean-model MLE is
  typically **self-coercive**. This is the continuity fact:
  Bernoulli all-zero \(\ell=\log(1-\mu)\) stays finite as
  \(\eta\to-\infty\) (oracle E3).
- **B4** Near-boundary \(y=\varepsilon\) still has a finite MLE,
  but \(\lvert\hat\eta\rvert\) grows as \(\varepsilon\to 0\)
  (oracle E4). Softness, not a hard barrier, is the live mean
  question — and \(P^*_{\mathrm{J}}\) does not supply it (B2).
- **B5** As \(\phi\to\infty\) at fixed \(\mu\in(0,1)\),
  \(w\sim\phi\,\mu(1-\mu)\) and \(I_{\phi\phi}\sim 1/(2\phi^2)\to 0\).
  Precision is weakly identified under concentration. As
  \(\phi\to 0\), \(I_{\phi\phi}\sim 1/\phi^2\to\infty\) and
  \(a,b\to 0\) (U-shaped). These are the precision / shape
  boundaries (oracles E5–E6).
- **B6** \(\beta\) and \(\phi\) are not orthogonal except at
  \(\mu=1/2\) (oracle E9). A later tape cannot treat \(\phi\) as
  a Gaussian-like residual orthogonal to the mean.
- **B7** Latent loading coercivity under Laplace is **OPEN**.
  Bernoulli \(V_{\mathrm{loading}}\) is listed only as a
  forbidden transplant (oracle E8).
- **B8** The mean-model atom in this note is **fixed-only /
  conditional** GLM information, evaluated at
  \(\eta=X_{\mathrm{fix}}b_{\mathrm{fix}}+\mathrm{offset}\) before
  any latent-score contribution — the same convention the live
  tape records at `src/gllvmTMB.cpp` ("before any latent-score
  contribution"). Laplace-marginal information for \(\beta\) is a
  different object and remains **OPEN**. These oracles do not
  compute it.

## 2. Boundary mechanisms (three objects, not one)

### Mean boundary \(\mu\to 0\) or \(1\)

On \(\operatorname{logit}\mu=\eta\), large \(\lvert\eta\rvert\)
sends \(\mu\) to a boundary. For interior \(y\) the likelihood
itself pulls back (B3). Fisher weights do **not** vanish (B2).
That is the opposite of Bernoulli separation and of Poisson
all-zero (\(W=\mu\to 0\)).

Finiteness of an unpenalised Beta fit on interior \(y\) is
necessary and **not** sufficient for admission (programme §16).
It is the default behaviour, not an MSPL result.

### Near-boundary proportions

\(y\) can sit at \(10^{-4}\) or \(1-10^{-4}\) without being a
point mass. The intercept MLE stays finite; \(\lvert\hat\eta\rvert\)
grows only slowly as \(y\to 0\) because \(\phi\) still penalises
\(a\to 0\) (oracle E4). Package
`gll_clamp(y, 10^{-12}, 1-10^{-12})` is a numerical guard, not a
scientific repair, and not a hurdle model.

### Precision \(\phi\to\infty\) and \(\phi\to 0\)

\(\phi\to\infty\) concentrates \(y\) at \(\mu\)
(\(\operatorname{Var}(y)\to 0\)) and sends \(I_{\phi\phi}\to 0\).
That is a *precision* boundary, not Gaussian Heywood
\(\psi_j\to 0\) in \(\Sigma=\Lambda\Lambda^\top+\Psi\). Ordinary
Beta rows have no free unique-variance \(\Psi\) coordinate in
this prep cell.

\(\phi\to 0\) sends \(a,b\to 0\) at fixed \(\mu\in(0,1)\): the
density becomes U-shaped and mass escapes toward 0 and 1. Shape
collapse via \(\phi\) is a different path from shape collapse via
\(\mu\to 0\) at fixed \(\phi\).

### Loading runaway (named, not solved)

Large \(\lvert\lambda\rvert\) on the logit scale still drives
some units toward \(\mu\approx 0\) and others toward \(\mu\approx 1\).
Design 88’s \(V_{\mathrm{loading}}\) was built for binary
link-scale runaway. **No Beta loading atom is admitted in this
note.** Oracle E8 only shows that \(V_{\mathrm{loading}}\) is
inert in both \(\mu\) and \(\phi\).

## 3. Why Bernoulli Jeffreys / \(V_{\mathrm{loading}}\) do not transfer

Design 88 maximises

\[
Q_{LA}=\ell_{LA}
+c_n\tfrac12\log\det(X_*^\top W_g(\beta)X_*)
-c_n V_{\mathrm{loading}}
-c_n V_{\mathrm{covariance}},
\]

with Bernoulli weights \(W_g\) (logit \(\mu(1-\mu)\), probit,
cloglog) and

\[
V_{\mathrm{loading}}=\sum_t\bigl(\sqrt{1+\|\lambda_t\|^2}-1\bigr).
\]

Four transfer failures:

1. **Support.** Bernoulli is discrete \(\{0,1\}\); Beta is
   continuous \((0,1)\). Complete separation of the Design 88
   kind does not exist.
2. **Weights.** \(w(\mu,\phi)\) is \(\phi^2[\mu(1-\mu)]^2\) times
   a trigamma sum, not \(\mu(1-\mu)\). Reusing `W_g` is a wrong
   information matrix (oracle E1).
3. **Boundary behaviour.** Bernoulli Jeffreys diverges because
   \(W_g\to 0\). Beta \(w\to 1\), so \(P^*_{\mathrm{J}}\) stays
   finite (oracle E2). Transplanting the *role* of Jeffreys
   (“it will pull away from \(\mu\to 0/1\)”) is false even if
   someone typed the Beta weight correctly.
4. **\(V_{\mathrm{loading}}\) is \((\mu,\phi)\)-inert.**
   \(\partial V_{\mathrm{loading}}/\partial\mu\equiv 0\) and
   \(\partial V_{\mathrm{loading}}/\partial\phi\equiv 0\)
   (oracle E8). It cannot be the mean-boundary or
   precision-boundary repair.

Do not keep Bernoulli atoms “for symmetry with Design 88.”

## 4. Why Poisson \(W=\operatorname{diag}(\mu)\) does not transfer

Poisson Phase-4 prep pins \(I(\beta_*)=X_*^\top\operatorname{diag}(\mu)X_*\)
for a log-mean count model. Beta \(\mu\in(0,1)\) is a proportion,
not a count mean. Using \(W=\operatorname{diag}(\mu)\) on a logit
scale — or using \(\operatorname{diag}(\mu(1-\mu))\) as if the
extra \(\phi^2[\mu(1-\mu)]\psi'(\cdot)\) factors were optional —
is a type error (oracle E1, E8). Exposure / offset algebra from
the Poisson note has no object here.

## 5. Why Gaussian Hirose \(\Psi\) does not transfer

Phase 3 targets Heywood \(\psi_j\to 0\) in
\(\Sigma=\Lambda\Lambda^\top+\Psi\) with Hirose
\(V_H=\sum_j S_{jj}/\psi_j\). Ordinary Beta GLLVM rows in this
prep cell are continuous proportions plus a precision \(\phi\).
They do not carry a free Gaussian unique-variance coordinate.

Fabricating \(\psi=1/\phi\) or \(\psi=\operatorname{Var}(y)\)
silently renames the precision problem without a proof. Oracle
E7 refuses Hirose-on-Beta as a type error.
\(\phi\to\infty\) (concentration, \(I_{\phi\phi}\to 0\)) is the
named precision boundary; it is not Hirose.

## 5a. Kill list — fail the later derivation on any of these

1. Transplant of Bernoulli \(V_{\mathrm{loading}}\) without a
   Beta Laplace coercivity proof.
2. Transplant of Bernoulli Jeffreys weights \(W_g\) (logit /
   probit / cloglog) in place of \(w(\mu,\phi)\).
3. Claiming Jeffreys-shaped \(P^*_{\mathrm{J}}\) is coercive at
   \(\mu\to 0/1\) for Beta (\(w\to 1\); oracle E2).
4. Transplant of Poisson \(W=\operatorname{diag}(\mu)\), or any
   claim that a count information atom transfers because both
   families have a mean weight.
5. Transplant of Gaussian Hirose / Akaike \(\Psi\) atoms, or any
   \(1/\psi\) term, including \(\psi:=1/\phi\) or
   \(\psi:=\operatorname{Var}(y)\).
6. Reuse of Bernoulli \(c_n=2\sqrt{p_{\mathrm{free}}/N_{\mathrm{eff}}}\)
   or Gaussian \(c_N=\sqrt{2/N}\) without a Beta rate argument
   against the Laplace objective.
7. Treating \(\phi\) as Gaussian \(\psi\), as Poisson exposure,
   or as orthogonal to \(\beta\) (it is not, except at
   \(\mu=1/2\)).
8. Collapsing \(\mu\to 0/1\), \(\phi\to 0\), and \(\phi\to\infty\)
   into one “Beta boundary.”
9. Claiming Design 88 or Sterzinger–Kosmidis–Moustaki 2026 covers
   Beta GLLVM MSPL under Laplace.
10. Claiming Beta inherits Bernoulli because both use logit, or
    inherits Poisson because both are “non-Gaussian means.”
11. Mixed-family, `betabinomial`, or `delta_beta` inheritance
    (fid 8 is discrete trials; `delta_beta` has a point mass).
12. Treating the \(y\) clamp at \(10^{-12}\) as a scientific
    boundary repair.
13. Finiteness of a Beta fit on interior \(y\) offered as the
    scientific result.
14. Any admission-shaped language (status flip to `admitted`,
    registry row, NEWS covered, validation-register promotion,
    C++ tape) ahead of the Shinichi gate.
15. Live `gllvmTMB(..., estimator = "mspl")` on Beta in tests.
16. Quietly widening `.gllvmTMB_mspl_prepare()` beyond
    `family_id %in% {0,1}`, or adding a `beta:*` registry row
    as a side effect of this prep.

## 5b. Oracle contract E1–E9 (pure R; no Beta `estimator="mspl"`)

| ID | What | Tolerance / decision |
|---|---|---|
| E1 | Beta \(I=X^\top W(\mu,\phi)X\); Bernoulli \(W_g=\mu(1-\mu)\) **differs**; Poisson \(W=\mu\) **differs** | rel. err \(<10^{-12}\) on Beta; both contrasts fire |
| E2 | \(\mu\to 0/1\) at fixed \(\phi\): \(w\to 1\), \(P^*_{\mathrm{J}}\) **finite** (Bernoulli \(P^*_{\mathrm{J}}\to-\infty\)) | \(\lvert w-1\rvert\) small at \(\lvert\eta\rvert=20\); Beta \(P^*_{\mathrm{J}}\) bounded |
| E3 | Unpenalised \(\ell_\beta\to-\infty\) as \(\lvert\eta\rvert\to\infty\) for \(y\in(0,1)\); Bernoulli all-zero stays finite as \(\eta\to-\infty\) | monotone; large negative vs finite |
| E4 | Near-boundary \(y=\varepsilon\): intercept MLE finite, \(\lvert\hat\eta\rvert\) grows slowly as \(\varepsilon\downarrow 0\) | monotone in \(\varepsilon\); all finite; not a grid-edge runaway |
| E5 | \(\phi\to\infty\): \(w\sim\phi\mu(1-\mu)\); \(I_{\phi\phi}\sim 1/(2\phi^2)\to 0\) | relative agreement at large \(\phi\) |
| E6 | \(\phi\to 0\): \(I_{\phi\phi}\sim 1/\phi^2\to\infty\); \(w\to\mu^2+(1-\mu)^2\); \(a,b\to 0\) | relative agreement; shapes vanish |
| E7 | Hirose \(\sum S/\psi\) is undefined / refused for the Beta mean-precision model | structural reject |
| E8 | \(\partial V_{\mathrm{loading}}/\partial\mu\equiv 0\), \(\partial V_{\mathrm{loading}}/\partial\phi\equiv 0\); Poisson \(W=\mu\) is not \(w(\mu,\phi)\) | finite-diff; contrast |
| E9 | \(I_{\eta\phi}=0\) at \(\mu=1/2\) and **not** zero at \(\mu\neq 1/2\) | \(<10^{-12}\) vs contrast fires |

No registry lookup. This file must not grow a `beta:*` planned
row as a test dependency.

## 6. Verdict

| Surface | Verdict | Why |
|---|---|---|
| Local R oracles / this writeup (E1–E9, kill list) | **PASS** | Information atom, \(\mu\)-boundary non-coercivity of \(P^*_{\mathrm{J}}\), self-coercive likelihood, and \(\phi\) boundaries are testable without a Beta MSPL fit. |
| C++ tape / live Beta MSPL / registry row / `planned` or `admitted` | **FAIL** | No tape, no prepare widening, no registry row, no Shinichi admission gate. |
| NEWS / covered / SE / intervals | **FAIL** | Out of scope; SE remains PROTECTED on Codex Lane B. |

Preferred later-admission *candidate* is **not** a transplanted
Bernoulli Jeffreys role. The mean-model \(P^*_{\mathrm{J}}\) is
the correct *information* atom and is **not** a mean-boundary
repair. Precision / shape atoms, a loading atom under Laplace, and
Laplace-marginal \(I(\beta)\) remain OPEN. Not a theorem transfer.

## 7. Non-claims

This note does **not** claim:

- calibrated inference, SEs, profiles, or model comparison;
- a live Beta `estimator = "mspl"` fit;
- that Bernoulli \(c_n\), \(V_{\mathrm{loading}}\), Poisson
  \(W=\operatorname{diag}(\mu)\), or Gaussian Hirose transfer;
- that Jeffreys-shaped \(P^*_{\mathrm{J}}\) repairs \(\mu\to 0/1\);
- that Laplace is exact for Beta (it is not);
- `betabinomial` / `delta_beta` / mixed-family MSPL;
- structured tiers (`phylo_*`, `spatial_*`, `animal_*`, `kernel_*`);
- that EVA/VA is involved (it is not);
- that a `beta:*` registry row exists or should exist;
- that this atom is the Laplace-marginal information for \(\beta\).

## 8. What must exist before admission (unchanged programme gate)

1. Symbolic information atom **and** a named boundary that the
   atom is actually coercive for (this note shows mean-model
   Jeffreys is **not** that atom for \(\mu\to 0/1\)) **and** a
   proved loading atom under Laplace.
2. Precision \(\phi\to 0\) / \(\phi\to\infty\) separated from the
   mean boundary in the implemented rate (oracles E5–E6, E9;
   rate choice still OPEN).
3. Healthy-regime no-harm vs LA-ML and near-boundary DGPs (not
   this run).
4. Family-specific TMB oracles after any tape (not this run).
5. Shinichi gate before any registry row, and again before
   `status` would flip from `planned` to `admitted`.

## 9. Rose boundary

- **Not EVA / not VA.** Outer criterion is Laplace-ML plus a
  soft penalty yet to be taped.
- **No registry row.** Poisson’s `planned` / `phase4_prep`
  pattern is **not** repeated. Beta stays off the MSPL registry.
- **Prepare fence unchanged.** `family_id` still only `{0,1}`.
- **No C++.** `git diff -- src/` must stay empty on this arc.
- **No NEWS covered.** No validation-register promotion.
- **No repo-root `LOOP/`.** Lane kit:
  `docs/dev-log/lanes/cursor-mspl-phase4-beta/LOOP/`.

## Out of scope here

Campaigns, Totoro/DRAC, NEWS, register promotion, registry rows,
Phase 1B API, interval lane, `betabinomial`, `delta_beta`, C++
tape, `estimator = "mspl"` on Beta.
