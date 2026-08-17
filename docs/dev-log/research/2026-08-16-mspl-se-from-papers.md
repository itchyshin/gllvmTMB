# MSPL standard errors from the two source papers

**Date:** 2026-08-16
**Lane:** `docs/mspl-se-from-papers` (docs-only; no `R/` / `src/` / admit)
**Reader:** the next SE coder on the D-149 internal \(Q_P\)/\(Q_0\) pins
**Status:** paper extract. **No family is admitted. No public interval is
authorised.** Forming a finite SE is not “MSPL has standard errors.”

This note records only what the two source PDFs say about information,
curvature, and standard errors, then maps that onto our existing pin
names. \(Q_P\) and \(Q_0\) are **gllvmTMB names**. They do not appear
in either paper.

**Extraction.** `pdftotext -layout` on both Desktop PDFs (2026-08-16).
No claim below is taken from chat memory, Claude handovers, or our
binary campaign. Where this note uses a gllvmTMB word (`Q_P`,
`sdreport`, Laplace GLLVM), the sentence says so.

---

## Sources

1. **SK2023** — Sterzinger, P. and Kosmidis, I. (2023). Maximum
   softly-penalized likelihood for mixed effects logistic regression.
   *Statistics and Computing* **33**:53.
   PDF: `/Users/z3437171/Desktop/s11222-023-10217-3-1.pdf`.
   Page cites use the article’s “Page *k* of 14” running header.
2. **SKM2026** — Sterzinger, P., Kosmidis, I. and Moustaki, I. (2026).
   Maximum softly penalized likelihood in factor analysis.
   *Psychometrika* **91**:494–507.
   PDF: `/Users/z3437171/Desktop/maximum-softly-penalized-likelihood-in-factor-analysis.pdf`.
   Page cites use the journal pagination (494–507).

**Our binding split (not a paper claim).** Brain **D-149** (2026-08-16):
internal \(Q_P\)/\(Q_0\) availability+PD pins are authorised for the
non-binomial cascade; public calibrated intervals stay binary-only
(MSPL-interval D-148; MSPL-04 blocked; no public `vcov` / `confint` /
`sdreport`). This extract does not change that split.

---

## 1. What information matrix the papers use for SEs

### 1.1 SK2023 (mixed-effects logistic)

The reported standard errors are **Wald numbers from the observed
Hessian of the unpenalized approximate log-likelihood**, evaluated at
the fitted estimates (including the MSPL estimates).

| Location | What they invert / report |
|---|---|
| Table 2 caption (p. 4 of 14) | “Estimated standard errors (in parentheses) are based on the **negative Hessian of the approximate log-likelihood**.” The table’s MSPL column carries those SEs. |
| Figure 1 / §3 (p. 4–5 of 14) | Coverage of 95% Wald intervals uses “the estimates and estimated standard errors from the **negative Hessian of the approximate log-likelihood at the estimates**.” |
| Table 3 caption (p. 9 of 14) | “Estimated standard errors (in parentheses) are based on the **inverse of the negative Hessian of the approximate likelihood**.” Laplace approximation of the log-likelihood (§8, p. 8 of 14). |
| Table 3 footnote (p. 9 of 14) | “The estimated standard errors are **not reported when the corresponding diagonal elements of the inverse are negative**.” |

In the theory they write \(J(\theta)=-\nabla_\theta\nabla_\theta^\top\ell(\theta)\)
for the **observed information** of \(\ell\), and \(I(\theta)\) for an
\(O(1)\) matrix such that \(R_n^{-1/2}J(\theta)R_n^{-1/2}\to_p I(\theta)\)
(§7, p. 7 of 14; Appendix B.3 assumption A6, p. 12 of 14). Theorem B.2
then gives

\[
R_n^{1/2}(\tilde\theta-\theta_0)\;\xrightarrow{d}\;N\bigl(0,\,I(\theta_0)^{-1}\bigr)
\]

when the penalty gradient is soft enough that
\(\sup_\theta R_n^{-1/2}A(\theta)=o_p(1)\) (Appendix B.3, p. 12 of 14).
That is the Cramér–Rao / ML asymptotic variance. It is **not** the
Hessian of \(\ell+P\).

**Sandwich / Godambe.** The paper never names a sandwich, Godambe,
or robust variance. Scores appear only as \(S(\theta)=\nabla\ell(\theta)\)
and \(A(\theta)=\nabla P(\theta)\) in the M-estimator proofs
(Appendix B.2–B.3). There is no additive per-cluster sandwich recipe.

**Expected information.** \(I(\theta)\) is the probability limit of the
*scaled observed* information. The numerical SEs in the examples are
the observed-Hessian route above, not an expected-information formula.

### 1.2 SKM2026 (Gaussian linear factor analysis)

This paper **does not give a computational SE formula**. It never
inverts a Hessian in a table, never writes a Wald interval, and never
mentions a sandwich.

What it *does* say about information:

- Local identification (full-column-rank Jacobian of \(\mathrm{vec}(\Sigma(\theta))\)
  at \(\theta_0\)) “ensures that the **information matrix is invertible**,
  which is required for \(\sqrt{n}\)-asymptotics” (§5.2, p. 499).
- Under the soft-penalty condition N4 (\(c_n=o_p(\sqrt{n})\)),
  \(\sqrt{n}\|\tilde\theta-\hat\theta\|=o_p(1)\). Slutsky then gives
  \(\tilde\theta\) the **same asymptotic distribution as the ML
  estimator** if \(\sqrt{n}(\hat\theta-\theta_0)\) is asymptotically
  normal (§5.2, p. 500).
- The only explicit information matrix in the main text is the
  **independence** model (\(\Lambda=0\)): the information for the
  unique variances is diagonal with \(j\)th entry \(n/(2\sigma_j^4)\).
  They use that rate, \(\sqrt{n/2}\), only to pick the soft scale
  \(c_n=\sqrt{2/n}\) (§6, p. 500). That matrix is **not** offered as
  an SE for the factor model.
- AIC and BIC are computed from the **unpenalized** log-likelihood
  evaluated at the ML and MSPL estimates (§7, p. 503).
- The **penalized** Hessian \(\nabla\nabla^\top\ell^*(\theta)\) appears
  only as a **Heywood / convergence heuristic**: they flag a case when
  the normalised gradient
  \(\{\nabla\nabla^\top\ell^*(\theta)\}^{-1}\nabla\ell^*(\theta)\) has
  an element larger than \(10^{-4}\) in absolute value, or a
  \(\psi_j\) estimate is below \(10^{-4}\) (§7, p. 501). That is a
  diagnostic on the penalized objective, not a published SE.

The conclusion says the framework “enables hypothesis testing by
ensuring the existence of interior estimates in finite samples … while
preserving standard ML asymptotic behavior” (§9, p. 506). It does not
name which matrix to invert in software.

---

## 2. Soft penalty’s effect on curvature / Fisher / SEs

Both papers make the same asymptotic move: **scale the penalty so its
score is negligible relative to information accumulation**. Then MSPL
and ML differ by \(o_p\) of the \(\sqrt{n}\) (or \(R_n^{1/2}\)) rate,
and first-order inference inherits the **ML** information
\(I(\theta_0)^{-1}\).

### SK2023

- Softness is a condition on \(\nabla P\), not on adding \(-\nabla\nabla^\top P\)
  into the SE matrix. They bound
  \(\|\nabla_\beta P^{(f)}(\beta)\|\le p^{3/2}\max|x_{st}|/2\)
  (Jeffreys; Theorem C.1, p. 13 of 14) and
  \(\|\nabla_\psi P^{(v)}(\psi)\|\le\sqrt{q(q+1)/2}\) (Huber; §7,
  p. 7 of 14), then set \(c_1=c_2=c=\sqrt{2p/n}\) so that
  \(\sup_\theta\|R_n^{-1}\nabla P(\theta)\|=o_p(1)\) when
  \(\max|x_{st}|=O_p(n^{1/2})\) (§7, p. 7 of 14).
- The Jeffreys piece is
  \(P^{(f)}(\beta)=\tfrac12\log\det\bigl(\sum_i X_i^\top W_i X_i\bigr)\)
  for the **corresponding GLM with no random effects**, with
  \(W_i=\mathrm{diag}\bigl(\mu_{ij}^{(f)}(1-\mu_{ij}^{(f)})\bigr)\)
  and \(\eta_{ij}^{(f)}=x_{ij}^\top\beta\) (§4, eq. (4), p. 6 of 14).
  That \(X^\top WX\) is the **penalty atom**. It is not the mixed-model
  Fisher matrix and not the SE matrix they invert in Tables 2–3.
- Softness is what they claim preserves consistency, asymptotic
  normality, and Cramér–Rao efficiency (abstract; §7; §9, p. 10 of 14).
- A **non-soft** competitor (bglmer normal / \(t\) priors) produces
  “excessive finite-sample bias” and Wald intervals that
  “systematically undercover” (§3, p. 5 of 14). That is a warning
  about **too-strong** penalization, not about using \(\ell\)’s Hessian.

### SKM2026

- Vanilla Akaike (1987) / Hirose et al. (2011) penalties
  \(P^*(\theta)=-\frac{\rho n}{2}\mathrm{tr}(\cdots)\) with a
  non-decaying \(\rho\) “can result in questionable finite-sample
  properties in **estimation, inference, and model selection**”
  (abstract, p. 494). Simulations with \(\rho=1\) (order \(n\)) show
  large bias, systematic underestimation of \(\Lambda\Lambda^\top\),
  and AIC/BIC that never select the correct number of factors
  (§7, Figures 2–3, p. 502–503; Table 2, p. 504).
- Soft adaptation is \(\rho=2\sqrt{2/n^3}\), equivalent to
  \(c_n=\sqrt{2/n}\) in front of an \(O(1)\) functional piece
  (§6, p. 500). Then N4 of Theorem 5.2 holds and MSPL is
  \(\sqrt{n}\)-equivalent to ML.
- When a cell is **not** a Heywood case, “the ML and MSPL estimates
  … are similar” because the penalty is soft (§8, p. 504).
- Constraining \(\psi_j\ge 0\) (or clipping negatives to zero)
  “violates regularity conditions of ML estimation, leading to
  estimators and **testing procedures with properties that are hard
  to evaluate**” (§1, p. 495). Soft interior penalization is their
  alternative to that constrained-Wald path.

**What this is not.** Neither paper says “add the penalty Hessian to
the observed information and call that the SE.” The softness argument
is that the penalty **drops out** of the first-order asymptotic
variance.

---

## 3. Warnings that are actually in the papers

### Unpenalized Hessian

SK2023 **uses** the unpenalized approximate-likelihood Hessian for
SEs. It does **not** warn against that construction. The warnings
that *are* there:

1. Boundary ML estimates, if undetected, “may substantially impact
   first-order inferential procedures, like Wald tests, resulting in
   spuriously strong or weak conclusions” (§1, p. 2 of 14).
2. Large SEs on the Culcita ML fits “are indicative of an almost flat
   approximate log-likelihood around the estimates”; those ML fixed
   effects are “in reality infinite” (§3, p. 4 of 14).
3. **Do not report** an SE when the corresponding diagonal of the
   inverse Hessian is negative (Table 3 footnote, p. 9 of 14). They
   leave the cell blank. They do not describe a pseudoinverse,
   eigenvalue clip, or nearest-PD repair.
4. Simulation summaries **discard parameter estimates on the
   boundary** before computing bias / variance / Wald coverage
   (Figure 1 caption, p. 5 of 14; Figure 2 caption, p. 10 of 14).
   That is their reporting rule for *summaries*, not a claim that
   non-PD rows may be dropped from an availability denominator.

SKM2026: Heywood cases “can produce parameter estimates, **standard
errors**, factor scores, and goodness-of-fit test statistics that
cannot be trusted,” citing Cooperman and Waller (2022) that Heywood
cases increase loading SEs (§1, p. 495). That is a warning about
**boundary ML**, not about evaluating \(\ell\) at an interior MSPL
point.

### Jeffreys

- SK2023’s Jeffreys penalty is for the **GLM with no random
  effects**, not for the mixed-model observed information
  (abstract; §4, eq. (4)).
- The gradient bound in Theorem C.1 is proved for the logistic
  GLM. The authors say the bound “extends to the cauchit link up
  to a constant” and that “bounds for other link functions, like
  the probit and the complementary log-log, are the subject of
  **current work**” (§9, p. 10 of 14).
- SKM2026 does not use Jeffreys.

### Working weights

- In SK2023, \(W_i=\mathrm{diag}(\mu(1-\mu))\) appears **only
  inside the Jeffreys penalty** (eq. (4)). Appendix C uses
  nonnegativity of those diagonal entries to bound
  \(\partial_{\beta_s}\log\det(X^\top WX)\). The paper never
  inverts \(X^\top WX\), or a mixed-model working-weight matrix,
  as a standard-error matrix.
- SKM2026 is a closed-form Gaussian factor likelihood. It has no
  GLM working weights.

### Approximate likelihood (Laplace / AGHQ)

SK2023 Appendix B.4 (p. 12–13 of 14): the consistency / asymptotic
normality theorems are stated for the **exact** log-likelihood.
If \(\bar\ell\) is an approximation, extra conditions on the
score error \(\bar S-S\) are required (they cite Ogden 2017, 2021;
Stringer and Bilodeau 2022; Jin and Andersson 2020). Laplace and
adaptive Gauss–Hermite are the approximations they actually
compute with (`glmer`; §2, p. 3 of 14; §8, p. 8 of 14), but the
paper does **not** claim those extra conditions have been verified
for a GLLVM.

SKM2026’s likelihood (eqs. (2.2)–(2.3), p. 496) is the **exact**
Gaussian factor-analysis profile likelihood. No Laplace remainder.

---

## 4. What transfers to Laplace-approximated GLLVM vs GLM / FA only

### Transfers as a *blueprint* (papers say this much)

- SK2023 §1 (p. 2 of 14): the logistic mixed-model development is
  “a blueprint for the construction of penalties and estimators of
  the fixed effects and/or the variance components” more generally.
- SK2023 §9 (p. 10 of 14): the **negative Huber** variance-component
  penalty “can be readily applied to other GLMMs”; they “expect”
  usefulness for GLMMs with categorical or ordinal responses. That
  sentence is about **existence / interior estimates**, not about
  a derived SE for those families.
- SKM2026 §9 (p. 506): the estimator “can also be applied in a
  confirmatory factor analysis setting by enforcing additional
  constraints.” Logistic factor analysis / IRT Heywood cases are
  named as a **further research** direction, not a theorem
  (p. 506).

### Transfers that our SE coder may use *as paper-justified*

| Object | Paper warrant | Our name |
|---|---|---|
| Invert \(\,-\nabla\nabla^\top\ell\,\) at the MSPL point; do not optimise \(\ell\) | SK2023 Tables 2–3, Figure 1 | \(Q_0\) |
| Do not publish an SE from a negative inverse-Hessian diagonal | SK2023 Table 3 footnote | retain `non_pd` |
| Soft \(c_n\) is what licences ML-variance Wald, not the penalty Hessian | SK2023 §7 / Thm B.2; SKM2026 §5.2 / N4 | do not treat \(Q_P\) as the paper SE |
| Penalized Hessian as a convergence / Heywood *diagnostic* | SKM2026 §7 heuristic | \(Q_P\) pin, not `vcov()` |
| Unpenalized \(\ell\) for information criteria | SKM2026 §7 AIC/BIC | not an SE, but same “evaluate \(\ell\) at \(\tilde\theta\)” move |
| Gaussian unique-variance soft scale \(c_n=\sqrt{2/n}\) | SKM2026 §6, from the independence information \(n/(2\sigma_j^4)\) | Hirose Gaussian rate only |
| Bernoulli-logit Jeffreys atom \(X^\top WX\) with \(W=\mathrm{diag}(\mu(1-\mu))\) at the **fixed-effect-only** predictor | SK2023 eq. (4) | GLM-outer atom; **not** \(I_{\mathrm{LA}}(\beta)\) |
| Identification restriction before claiming an invertible information matrix (rotation of \(\Lambda\)) | SKM2026 §5.2, p. 499 | ordinary `latent()` needs a stated restriction |

### Does **not** transfer (not in the papers)

- Poisson, nbinom1, nbinom2, beta, Tweedie: **no SE construction,
  no information matrix, no Wald table.** SK2023’s opening sentence
  lists “counts, proportions, positive responses” as GLMM *response
  types* (§1, p. 1 of 14); the estimator and all SE numbers are
  mixed-effects **logistic**.
- A GLLVM loadings block under Laplace. SKM2026 is exploratory
  **linear** factor analysis with an exact Gaussian likelihood.
  SK2023’s random effects are GLMM \(u_i\sim N(0,\Sigma)\), not
  a trait-loading \(\Lambda\).
- Probit / cloglog Jeffreys theory (explicitly open in SK2023 §9).
- Sandwich / Godambe / per-site scores.
- `TMB::sdreport()`, Laplace-marginal \(I_{\mathrm{LA}}(\beta)\),
  or a claim that the GLM-outer atom is an information matrix.
- Calibrated finite-sample coverage for any GLLVM family. SK2023’s
  Wald coverage is for their logistic GLMM simulations after
  discarding boundary rows. SKM2026 does not report interval
  coverage at all.
- A licence to open public `vcov()` / `confint()`.

---

## 5. Family map for the D-149 cascade

Paper text only. “Not in papers” means neither PDF specifies an SE
for that family.

| Family | What the papers give | What they do not give |
|---|---|---|
| **Bernoulli logit** | SK2023’s whole paper: Jeffreys GLM-outer atom; Huber on \(\psi=\mathrm{vech}(L)\); \(c=\sqrt{2p/n}\); SEs = inverse negative Hessian of **approximate** \(\ell\) at the estimates; blank the cell if that inverse diagonal is negative; Laplace used for bivariate RE (§8). | GLLVM \(\Lambda\); a sandwich; a proof that `glmer` Laplace satisfies Appendix B.4’s extra score conditions in our tape. |
| **Bernoulli probit / cloglog** | Same *penalty shape* is asserted for those links via Kosmidis and Firth (2021) on GLM finiteness (§5, p. 6 of 14). Soft-rate **gradient bound** for probit/cloglog is “current work” (§9). | A proved soft \(c_n\) for those links; any GLLVM SE. |
| **Gaussian FA / unique \(\psi\)** | SKM2026: Hirose / Akaike penalties; soft \(\rho=2\sqrt{2/n^3}\); ML-equivalent asymptotics; AIC/BIC on unpenalized \(\ell(\tilde\theta)\); penalized Hessian only as a Heywood diagnostic. | A Wald SE table; Laplace GLLVM; mixed families. |
| **Poisson** | Not treated. Huber “can be readily applied to other GLMMs” is existence language (§9), not an SE. | Atom, rate, Hessian recipe, coverage. |
| **nbinom1 / nbinom2** | Not treated. | Same. |
| **Beta** | Not treated. “Proportions” in the GLMM sentence (§1) is not a beta MSPL SE. | Same. |
| **Tweedie** | Not treated. “Positive responses” in the GLMM sentence is not a Tweedie MSPL SE. | Same. |

---

## 6. Checklist for the next SE coding slice

### Do

1. **Keep \(Q_0\) as the paper-style Wald object.** Evaluate
   \(-\nabla\nabla^\top\ell\) (our penalty-off tape) at
   \(\hat\theta_{\mathrm{MSPL}}\). Do not optimise that tape.
   Warrant: SK2023 Tables 2–3 and Figure 1.
2. **Keep \(Q_P\) as a separate typed diagnostic.** The papers do
   not invert \(\nabla\nabla^\top(\ell+P)\) for published SEs.
   SKM2026 uses the penalized Hessian only as a Heywood /
   gradient heuristic (§7). Report the two tapes side by side;
   do not substitute one for the other.
3. **Leave a non-PD inverse blank / typed `non_pd`.** SK2023
   Table 3 footnote: no SE when the inverse diagonal is negative.
   No pseudoinverse, no eigenvalue clip, no nearest-PD.
4. **Treat softness as a condition on \(\nabla P\) and \(c_n\),
   not as “use the penalized curvature.”** If \(c\) does not vanish
   with information, SK2023 §7 / SKM2026 N4 do not licence
   \(I(\theta_0)^{-1}\) as the SE. A unit placeholder \(c=1\) is
   outside both papers’ soft-rate arguments.
5. **Keep Jeffreys / Hirose working-weight atoms inside the
   penalty.** Do not invert \(X_*^\top W X_*\) and call it a
   standard error. SK2023 eq. (4); SKM2026 §6 uses
   \(n/(2\sigma_j^4)\) only to pick \(c_n\).
6. **Keep public `sdreport` / `vcov` / `confint` closed.** Nothing
   in either paper is a GLLVM calibration certificate. D-149
   already withholds the public door.
7. **For Gaussian unique-\(\psi\) pins, use the SKM2026 rate
   story only if the penalty is the Hirose/Akaike form they
   analysed.** Their \(c_n=\sqrt{2/n}\) is derived from the
   independence Gaussian variance model (§6), not from a
   Laplace GLLVM.
8. **For Bernoulli-logit pins, the closest paper object is
   SK2023’s \(Q_0\)-style Wald on the approximate likelihood.**
   Their approximation is `glmer` AGHQ (\(q=1\)) or Laplace
   (\(q=2\)), not our TMB GLLVM tape. Appendix B.4’s extra
   score-error conditions remain an open transfer, not a free
   inheritance.
9. **Name the identification restriction** before claiming an
   invertible information matrix on loadings (SKM2026 §5.2).
10. **Record every attempt in the availability denominator.**
    The papers discard boundary ML from *simulation summaries*;
    that is not a warrant to drop non-PD rows from a D-149 pin.

### Do not

1. **Do not invert \(Q_P\) and label it the Sterzinger–Kosmidis SE.**
   Their published SEs are from \(\ell\), not \(\ell+P\).
2. **Do not implement a sandwich / Godambe because “the papers
   must have one.”** They do not.
3. **Do not use GLM working weights, Jeffreys \(X^\top WX\), or
   the independence information \(n/(2\sigma_j^4)\) as the SE
   matrix.**
4. **Do not transplant SK2023’s \(c=\sqrt{2p/n}\) or SKM2026’s
   \(c_n=\sqrt{2/n}\) onto Poisson / NB / beta / Tweedie and call
   the result paper-justified.** Those rates are derived for
   logistic GLM-outer Jeffreys and independent Gaussian
   variances, respectively.
5. **Do not treat probit/cloglog Jeffreys softness as proved.**
   SK2023 §9 leaves those gradient bounds as current work.
6. **Do not constrain \(\psi\) to \([0,\infty)\) and then run
   regular ML Wald.** SKM2026 §1 says that path makes testing
   procedures hard to evaluate.
7. **Do not use vanilla Hirose/Akaike \(\rho=1\) (order \(n\))
   and then quote SKM2026’s “asymptotically optimal inference.”**
   The abstract and §7 say the vanilla versions have questionable
   finite-sample inference.
8. **Do not open public intervals, write NEWS `covered`, or flip
   `planned` → `admitted` from this extract.**
9. **Do not cite SK2023 Figure 1 coverage as GLLVM calibration.**
   That figure is a logistic GLMM, after discarding boundary
   estimates, using `glmer`’s approximate likelihood.
10. **Do not claim Laplace-GLLVM SEs are covered by Appendix B.4.**
    The appendix states extra conditions; it does not verify them
    for our model.
11. **Do not repair a negative Hessian diagonal** to match a
    table that the papers themselves left blank.
12. **Do not invent a Poisson / NB / beta / Tweedie observed
    information from these PDFs.** If a pin is coded for those
    families, the construction is ours (D-149 availability), not
    theirs.

---

## 7. Mapping onto the objects we already named

| Our object | Paper object | Paper role |
|---|---|---|
| \(Q_0=\nabla^2\ell(\hat\theta_{\mathrm{MSPL}})\) | SK2023 “negative Hessian of the approximate log-likelihood at the estimates” | **Published SE / Wald** |
| \(Q_P=\nabla^2(\ell+P)(\hat\theta_{\mathrm{MSPL}})\) | SKM2026 \(\nabla\nabla^\top\ell^*\) in the Heywood heuristic; not used for SEs in SK2023 | **Diagnostic only** |
| GLM-outer \(\tfrac12\log\det(X_*^\top W X_*)\) | SK2023 eq. (4) Jeffreys for the no-RE GLM | **Penalty**, not \(I(\theta)\) |
| Soft \(c_n\to 0\) | SK2023 \(c=\sqrt{2p/n}\); SKM2026 \(c_n=\sqrt{2/n}\) | Licences ML asymptotic variance |
| Placeholder \(c=1\) | — | **Outside both papers’ softness theorems** |
| Sandwich / Godambe | — | **Absent** |
| Public `sdreport()` | — | **Absent** |

---

## 8. Claims this note does not make

This extract does not claim: that an MSPL standard error is
calibrated or publishable in gllvmTMB; that \(Q_P\) is a valid SE;
that \(Q_0\) is calibrated on our Bernoulli pin (that cell was
non-PD in the #979 fixture — a **local** fact, not a paper fact);
that Poisson / NB / beta / Tweedie inherit SK2023 Wald; that
Gaussian GLLVM Laplace equals SKM2026 exact FA; that Jeffreys
\(X^\top WX\) is \(I_{\mathrm{LA}}(\beta)\); that Appendix B.4
clears our Laplace tape; or that D-149’s public-interval fence
has moved.

---

## 9. Checks

```sh
pdftotext -layout "/Users/z3437171/Desktop/s11222-023-10217-3-1.pdf" \
  /tmp/mspl-pdf-extract/kosmidis-2023.txt
pdftotext -layout \
  "/Users/z3437171/Desktop/maximum-softly-penalized-likelihood-in-factor-analysis.pdf" \
  /tmp/mspl-pdf-extract/hirose-mspl-fa.txt
# 992 and 772 lines respectively; both extracts readable
```

Stale-wording / overclaim scan on this file (must stay clean):

```text
rg -n "calibrated|NEWS covered|sandwich|Godambe|I_LA|sdreport" \
  docs/dev-log/research/2026-08-16-mspl-se-from-papers.md
```

Those words appear only as **negations** or as names of objects the
papers do not supply.
