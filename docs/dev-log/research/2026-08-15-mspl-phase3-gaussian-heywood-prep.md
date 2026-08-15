# Phase 3 prep — Gaussian Heywood route (not admitted)

**Status:** design + local oracles only. Registry rows
`gaussian:identity:ordinary:q1` and `q2` remain `planned`.
`.gllvmTMB_mspl_prepare()` still rejects Gaussian. **Verdict: PASS
for oracles, FAIL for C++ / admission.**

**Reader:** statistical method developer / TMB engineer who must
decide whether a later tape may add a Gaussian Heywood atom.

**Primary paper:** Sterzinger, Kosmidis & Moustaki (2026),
*Maximum softly penalized likelihood in factor analysis*,
*Psychometrika*, [doi:10.1017/psy.2026.10092](https://doi.org/10.1017/psy.2026.10092).
Formulas below are taken from that paper's (3.2), (4.1), and the
soft-rate display called Akaike[\(n^{-1/2}\)] / Hirose[\(n^{-1/2}\)].

This is **LA-MSPL** (Laplace + a soft *outer* penalty), not EVA/VA.
Laplace is exact for the ordinary Gaussian factor model, so the
paper's exact-likelihood outer criterion is the object a later
`gllvmTMB` tape would add. That transfer is still
**AGENT-INFERRED**: the paper is classical EFA, not a stacked-trait
GLLVM, and it does not mention TMB.

## Why this is the catch-up cell

LA-ML on a Gaussian factor model is exact (Laplace is the marginal).
LA-MSPL would be a *different outer criterion* on that same exact
integral: the place to test whether a softly penalised Heywood
(\(\Psi \to 0\)) atom can sit beside Laplace-ML without inheriting the
Bernoulli loading penalty.

Programme lock: ordinary Gaussian
\(\Sigma = \Lambda\Lambda^\top + \Psi\), Akaike/Hirose-type penalty,
separately derived. Do not transplant the current Bernoulli
\(\sqrt{1+\|\lambda\|^2}-1\) atom.

## 1. Five-row symbolic alignment

Paper (3.2) writes penalties \(P^*(\theta)\) on the **log-likelihood
scale, to be maximised**. Equivalent (4.1) is the diagonal form used
by the oracles. TMB minimises negative log-likelihood, so a later
tape would add \(-P^*\).

Soft rate (paper): \(\rho = 2\sqrt{2/N^3}\). The coefficient that
actually multiplies the (4.1) atom is

\[
c_N=\frac{\rho N}{2}=\sqrt{\frac{2}{N}},
\]

order \(N^{-1/2}\). The paper calls the resulting estimators
Akaike[\(N^{-1/2}\)] and Hirose[\(N^{-1/2}\)]. Do **not** reuse the
Bernoulli scale \(c_n = 2\sqrt{p_{\mathrm{free}}/N_{\mathrm{eff}}}\).
Opus fold: drop any Gaussian Jeffreys transplant (A5).

| Criterion | Atom | Parameters | TMB-shaped expression on paper | Interpretation |
|---|---|---|---|---|
| Akaike[\(n^{-1/2}\)] \(P^*\) | \(\operatorname{tr}(\Psi^{-1/2}\Lambda\Lambda^\top\Psi^{-1/2})=\sum_j \|\lambda_j\|^2/\psi_j\) | \(\Lambda\) (\(p\times q\)), diagonal \(\Psi\) | \(\mathrm{nll}\mathrel{+}=\frac{\rho n}{2}\sum_j \|\lambda_j\|^2/\psi_j\) | Soft penalty on standardised communalities. Coercive as \(\psi_j\to 0\) when \(\lambda_{\min}(\Sigma)\) stays positive (then \(\|\lambda_j\|^2\) cannot vanish). |
| Hirose[\(n^{-1/2}\)] \(P^*\) | \(\operatorname{tr}(\Psi^{-1/2}S\Psi^{-1/2})=\sum_j S_{jj}/\psi_j\) | diagonal \(\Psi\); \(S\) from the data | \(\mathrm{nll}\mathrel{+}=\frac{\rho n}{2}\sum_j S_{jj}/\psi_j\) | Soft penalty on unique-variance collapse against the sample scale. **E3 is immediate** whenever \(S_{jj}>0\). Preferred default for later admission discussion. |
| Equivalent (4.1) | \(P^*=-\frac{\rho n}{2}\sum_j A_{jj}/\psi_j\) | \(A_{jj}=\lambda_j^\top\lambda_j\) (Akaike) or \(A_{jj}=S_{jj}\) (Hirose) | same nll increment with that \(A_{jj}\) | The two (3.2) traces collapse to a sum of ratios because \(\Psi\) is diagonal. This is the oracle atom. |
| Soft rate | \(\rho=2\sqrt{2/N^3}\), \(c_N=\sqrt{2/N}\) | \(N\) = paper sample size (independent multivariate vectors) | \(\mathrm{nll}\mathrel{+}=c_N\sum_j A_{jj}/\psi_j\) | Vanishing rate. **AGENT-INFERRED:** later admission should identify \(N\) with the number of units, not stacked rows. Not Bernoulli \(c_n\). |
| Contrast: Bernoulli \(V_{\mathrm{loading}}\) | \(\sum_t\bigl(\sqrt{1+\|\lambda_t\|^2}-1\bigr)\) | \(\Lambda\) only | already in `gll_mspl_row_radial_penalty` | Penalises **loading runaway**, not \(\psi\to 0\). \(\partial V/\partial\psi\equiv 0\) (oracle E7). Not FA-scale-equivariant. Wrong object. |

Existence conditions from the paper, used as the oracle contract:

- **E1** continuous on \(\psi_j>0\).
- **E2** bounded above (\(P^*\le 0\) whenever the atom is nonnegative
  and \(\rho n/2>0\)).
- **E3** \(P^*\to-\infty\) as any \(\psi_j\to 0\) while
  \(\lambda_{\min}(\Sigma)\) stays positive.

Hirose satisfies E3 as soon as \(S_{jj}>0\), without a side condition
on \(\Lambda\). That is why the oracles treat Hirose as the preferred
later-admission default and Akaike as a sibling.

**AGENT-INFERRED \(S\) convention.** The oracles take a supplied
diagonal \(S_{jj}\) and do not pin whether a later fit should use the
ML Gram \(S=n^{-1}Y_c^\top Y_c\) or the unbiased covariance. That
choice is an admission-time pin, not an oracle pin.

## 2. Why Bernoulli \(V_{\mathrm{loading}}\) is the wrong object

The live binary atom in `src/gllvmTMB.cpp`
(`gll_mspl_row_radial_penalty`) is

\[
V_{\mathrm{loading}}(\Lambda)
=
\sum_t\bigl(\sqrt{1+\|\lambda_t\|^2}-1\bigr).
\]

It was built for Bernoulli **loading runaway** on the link scale: a
row of \(\Lambda\) becoming large while the unique variance is not a
free Heywood coordinate (ordinary binary MSPL keeps free Bernoulli
\(\Psi\) excluded). Gaussian Heywood is the opposite boundary,
\(\psi_j\to 0\) with \(\Sigma=\Lambda\Lambda^\top+\Psi\) still
positive definite.

The two objects also transform differently. Under the Gaussian
response-scale map \(Y\mapsto LY\) with diagonal \(L>0\),

\[
\Lambda\mapsto L\Lambda,\qquad
\Psi\mapsto L\Psi L^\top.
\]

Standardised loadings \(\Psi^{-1/2}\Lambda\) are invariant, so both
paper atoms are invariant. \(V_{\mathrm{loading}}\) sees
\(\|\lambda_t\|\mapsto L_{tt}\|\lambda_t\|\) and is **not** invariant.
That is the explicit oracle contrast.

Do not use \(\|\Lambda\|/k\) as an acceptance test. That is the
#855 / scale-dependent-constants trap (`dev/scale-equivariance-check.R`
is the spirit: check the *standardised* atom, both blocks).

## 3. Scale equivariance

Paper FA: if \(Y\mapsto LY\) with diagonal \(L>0\), then
\(\Lambda\mapsto L\Lambda\) and \(\Psi\mapsto L\Psi L^\top\). The
penalty atom is a function of the **standardised** loadings
\(\Psi^{-1/2}\Lambda\) (Akaike) or of \(S_{jj}/\psi_j\) (Hirose).

For diagonal \(\Psi\) and diagonal \(L\),

\[
\frac{\|(L\Lambda)_j\|^2}{(L\Psi L^\top)_{jj}}
=
\frac{L_{jj}^2\|\lambda_j\|^2}{L_{jj}^2\psi_j}
=
\frac{\|\lambda_j\|^2}{\psi_j},
\]

and likewise \(S'_{jj}/\psi'_j=S_{jj}/\psi_j\). The (4.1) atom is
exactly invariant. The additive constant allowed by the paper is
therefore zero for these atoms.

**AGENT-INFERRED for `gllvmTMB`:** the same map on a stacked-trait
Gaussian `latent(..., unique = TRUE)` model is the ordinary
per-trait scale change. Intercepts and the unit-score standardisation
\(u\sim N(0,I)\) are unchanged. This note does not claim the live
fit path is scale-equivariant; it claims the *paper atom* is.

## 4. Rotation invariance

Akaike depends on \(\Lambda\Lambda^\top\) (equivalently on the row
Gram diagonals \(\|\lambda_j\|^2\)), not on a particular rotation.
If \(Q\) is orthogonal, \(\Lambda Q\) leaves \(\Lambda\Lambda^\top\)
and every \(\|\lambda_j\|^2\) unchanged. Hirose does not see
\(\Lambda\) at all. Neither atom is a lower-triangular loading
coordinate.

## 5. Coercivity at \(\psi_t\to 0\)

Hirose: if \(S_{jj}>0\), then \(S_{jj}/\psi_j\to+\infty\) as
\(\psi_j\to 0\), so \(P^*\to-\infty\). E3 is immediate.

Akaike: \(A_{jj}=\|\lambda_j\|^2\). If a path lets both
\(\psi_j\to 0\) and \(\lambda_j\to 0\), the ratio can stay finite.
The paper's E3 therefore adds \(\lambda_{\min}(\Sigma)>0\). On that
set, \(\Sigma_{jj}=\|\lambda_j\|^2+\psi_j\ge\lambda_{\min}(\Sigma)\),
so \(\|\lambda_j\|^2\) stays bounded away from zero for small
\(\psi_j\), and Akaike also diverges.

A later TMB tape would add \(-P^*\), i.e.
\(+c_N\sum_j A_{jj}/\psi_j\), which \(\to+\infty\) on those paths
and is the coercivity the optimiser actually feels.

## 5a. Rate tension (Opus B4) — why Hirose \(1/\psi\) is primary

**AGENT-INFERRED arithmetic; oracle E4 decides it.** The Gaussian
factor-analysis likelihood is unbounded at the Heywood boundary
(Anderson–Rubin). Along \(\psi_1\downarrow 0\) with
\(\lambda_1\) bounded away from zero, the profile log-likelihood
diverges to \(+\infty\) at rate \(\approx (N/2)\log(1/\psi_1)\).

A log-type atom \(V\sim\log(1/\psi)\) with any vanishing
\(c_N\to 0\) is **not coercive**: \(c_N\log(1/\psi)\) loses to
\((N/2)\log(1/\psi)\), so \(\ell-c_NV\) still \(\to+\infty\).
Hirose \(V_H\sim S_{jj}/\psi\) dominates the log divergence for
every fixed \(c_N>0\). That is why Hirose is the primary oracle
atom and Akaike is a sibling, not a substitute log-penalty.

The paper scale \(c_N=\sqrt{2/N}\) is already vanishing. Oracle E6
checks that the one-dimensional Hirose stationarity shift is
\(o(N^{-1/2})\). Bernoulli \(c_n=2\sqrt{p_{\mathrm{free}}/N_{\mathrm{eff}}}\)
is a rejected comparator only.

## 5b. Drop the Gaussian Jeffreys transplant (Opus A5)

The live Bernoulli Jeffreys term is
\(\tfrac12\log\det(X_*^\top W_g(\beta)X_*)\) with link-specific
Bernoulli weights. Gaussian expected information for \(\beta\) is
\(X^\top X/\sigma^2\), **free of \(\beta\)**:

\[
\tfrac12\log\det(X_*^\top X_*/\sigma^2)
=
\mathrm{const}-\tfrac{p}{2}\log\sigma^2.
\]

That is a covert dispersion prior with zero separation-repair
content. This derivation **drops** it. Oracle E1 records the
identity. Do not keep the term “for symmetry with Bernoulli.”

## 5c. \(\Psi\) split and the flat ridge (Opus B0) — MAP CLOSED for pick C

In live `gllvmTMB` the Gaussian trait-diagonal is **not** the
paper’s single \(\Psi\). It is split (#856):

- per-trait unique variance `sd_B(t)² = exp(2·theta_diag_B(t))`,
  a random block integrated by Laplace;
- residual `sigma_eps² = exp(2·log_sigma_eps)`, **one scalar
  shared across every Gaussian and lognormal row**.

**AGENT-INFERRED:** when \(\sigma_\varepsilon\) is free, only the sum
\(\psi_t^{\mathrm{total}}=sd_B(t)^2+\sigma_\varepsilon^2\) is
identified. The direction
\(\sigma_\varepsilon^2\leftarrow\sigma_\varepsilon^2+c\),
\(sd_B(t)^2\leftarrow sd_B(t)^2-c\) is flat in the likelihood and
terminates at \(\min_t sd_B(t)^2=0\). A penalty on `sd_B` alone
would be 100% penalty-determined (Hao falsifier row 4).

Local oracles stay on the textbook triple \((\Lambda,\psi,S)\).
Oracle E5 *exhibits* the flat ridge; E5b pins the map. **Resolved
for the first matched cell** in
`docs/dev-log/research/2026-08-15-mspl-gaussian-psi-uniqueness-map.md`:
**pick C** (pinned-\(\sigma_\varepsilon\) exact-FA;
\(\psi_j\equiv sd_B(j)^2\)), matching live Q7 auto-suppress on
ordinary per-row `latent(..., unique = TRUE)`. Option A with free
\(\sigma_\varepsilon\) is rejected. Option B
(\(\psi^{\mathrm{total}}\)) is deferred to a later free-ε cell.
C++ / `planned`→`admitted` remain STOP.

## 5d. \(V_{\mathrm{loading}}\) is inert on \(\psi\) (Opus A1 / E7)

\[
\frac{\partial V_{\mathrm{loading}}}{\partial\psi}\equiv 0.
\]

The atom is a function of \(\Lambda\) alone. Along the Heywood
path \(\psi_t\downarrow 0\) at fixed \(\lambda_t\) it is constant.
Oracle E7 records the numerical derivative: \(\partial V/\partial\psi=0\)
and \(\partial V/\partial\Lambda\neq 0\). This is why “do not
transplant” is a theorem, not a taste.

## 5e. Kill list (Opus D) — fail the later derivation on any of these

1. Scale non-equivariance, including \(\|\Lambda\|/k\) or any bare
   additive constant with response units (`√(1+x²)`, thresholds 1 / 6 / 25).
2. Rotation dependence (atom not a function of \(\Lambda\Lambda^\top\)
   or of \(M_\Lambda\)'s spectrum).
3. Coercivity of loadings only; equivalently \(\partial V/\partial\psi\equiv 0\).
4. Bernoulli \(c_n=2\sqrt{p_{\mathrm{free}}/N_{\mathrm{eff}}}\) reused
   without the B4 rate comparison against \((N/2)\log(1/\psi)\).
5. \(\Psi\) left undefined in implemented coordinates (`sd_B²` vs
   \(\sigma_\varepsilon^2 I\) vs the sum; #856) — **first-cell
   map is pick C**; reopening A-with-free-ε fails this kill.
6. Claiming a per-trait \(\psi_t\to 0\) boundary on
   `latent(unique = FALSE)`, which has no per-trait \(\Psi\).
7. Penalty acting along the likelihood-flat ridge (5c) without
   naming it.
8. Finiteness offered as the scientific result.
9. Laplace exactness used as a licence (“so MSPL is unnecessary”
   or “so the paper theorem transfers”).
10. Treating Sterzinger–Kosmidis–Moustaki 2026 as covering this
    stacked-trait model.
11. Undefined \(S\) in long format with covariates.
12. One-sided boundary only, disagreeing with the shipped two-face
    `check_gllvmTMB()` Heywood gate.
13. \(q=2\) comparisons on loading packs rather than \(\Lambda\Lambda^\top\).
14. Any admission-shaped language (status flip, NEWS, register
    promotion) ahead of the Shinichi gate.

## 5f. Oracle contract E1–E7 (pure R; no Gaussian `estimator="mspl"`)

| ID | What | Tolerance / decision |
|---|---|---|
| E1 | (3.2)/(4.1) traces; \(\log\det\Sigma=\sum_t\log\psi_t+\log\det(I_q+\Lambda^\top\Psi^{-1}\Lambda)\); Jeffreys half-logdet \(=\mathrm{const}-(p/2)\log\sigma^2\) | rel. err \(<10^{-12}\) |
| E2 | Anisotropic \(Y\mapsto DY\); Bernoulli \(V_{\mathrm{loading}}\) **fails** the same map | paper atoms exact; \(V_{\mathrm{loading}}\) not equal |
| E3 | \(\Lambda Q\) for orthogonal \(Q\); pack(\(\Lambda Q\)) \(\neq\) pack(\(\Lambda\)) while \(\Lambda\Lambda^\top\) agrees | \(<10^{-12}\) |
| E4 | \(\psi\to 0\) blow-up **and rate**: Hirose \(\sim 1/\psi\); \(\ell-c_N V_H\to-\infty\); log-type atom with \(c_N\) does **not** | slope / sign as named |
| E5 | Flat-ridge exhibit: two \((sd_B,\sigma_\varepsilon)\) with identical \(\Sigma\); textbook atoms stay on \(\psi\), not `sd_B` | \(\Sigma\) agree; gate stays open |
| E6 | Vanishing-rate: 1-d Hirose shift \(o(N^{-1/2})\) under \(c_N=\sqrt{2/N}\) | shift\(/N^{-1/2}\to 0\) |
| E7 | \(\partial V_{\mathrm{loading}}/\partial\psi\equiv 0\), \(\partial V_{\mathrm{loading}}/\partial\Lambda\neq 0\) | finite-diff \(\psi\)-grad \(=0\) |

E8 (two-face diagnostic consistency) is **not** in this run.

## 6. Verdict

| Surface | Verdict | Why |
|---|---|---|
| Local R oracles / this writeup (E1–E7, kill list recorded) | **PASS** | Paper atoms, rate tension, Jeffreys drop, and \(V_{\mathrm{loading}}\) inertness are testable without a Gaussian `estimator = "mspl"` fit. |
| C++ tape / live Gaussian MSPL / flipping `planned` → `admitted` | **FAIL** | No tape, no fence change, no Shinichi admission gate. Uniqueness map for the first cell is CLOSED (pick C); C++ still STOP. |

Preferred later-admission default: **Hirose**, because E3 is
immediate and the \(1/\psi\) rate wins B4. Akaike is a sibling
oracle. Jeffreys is dropped.

Opus adversarial (`4bc7ff91-460c-49f8-a181-d2254c44c650`) folded
2026-08-15. Sol (`8b6f1b9d-abe8-4e18-a12e-784c13ac7205`) agrees on
Hirose primary, \(c_N=\sqrt{2/N}\), and the unresolved
\(\Psi\)-split. Neither overwrites the (3.2)/(4.1) table.

## 7. Non-claims

This note does **not** claim:

- calibrated inference, SEs, profiles, or model comparison;
- mixed-family MSPL;
- structured tiers (`phylo_*`, `spatial_*`, `animal_*`, `kernel_*`);
- rank misspecification robustness;
- a live Gaussian `estimator = "mspl"` fit;
- that Bernoulli \(c_n\) or \(V_{\mathrm{loading}}\) transfers;
- that a Gaussian Jeffreys / Firth term is part of this cell;
- that the live `sd_B` / \(\sigma_\varepsilon\) split is resolved;
- that EVA/VA is involved (it is not);
- that Phase 1B (`estimator = "ml"` outside Laplace) is in scope.

## 8. What must exist before admission (unchanged)

1. Symbolic information atom and coercivity at \(\psi_t\to 0\)
   (this note + oracles).
2. Response-scale equivariance of the *standardised* atom (oracles;
   not \(\|\Lambda\|/k\)).
3. Rotation-invariant covariance recovery vs LA-ML on healthy and
   near-Heywood DGPs (**not** this run).
4. Healthy-regime no-harm vs LA-ML (local smoke, not a campaign;
   **not** this run).
5. Shinichi gate before `status` flips from `planned` to `admitted`.

## 9. Rose boundary (S4)

Confirm, in prose, the fences this catch-up run must not cross:

- **Not EVA / not VA.** The outer criterion is Laplace-ML plus a
  soft penalty. Variational routes are a different estimator class
  and are not touched.
- **No Phase 1B.** Accepted calls stay as they are.
  `estimator = "ml"` outside Laplace is an OPEN GATE.
- **No B2 promotion.** Admitted Bernoulli rows keep
  `evidence = "partial_b2_incomplete"`. Incomplete hard cells are
  not averaged into a covered claim.
- **No repo-root `LOOP/`.** This lane's kit is
  `docs/dev-log/lanes/cursor-mspl-catchup/LOOP/`. Root `LOOP/` is
  the 0.6 release kit on `main`.
- **`planned` ≠ `admitted`.** Gaussian registry rows stay `planned`.
  `.gllvmTMB_mspl_prepare()` still rejects non-binomial families.
- **No NEWS.** No public claim, no validation-register promotion.
- **No C++.** `git diff -- src/` must stay empty. The Bernoulli
  radial atom is left in place for the live binary surface.

## Out of scope here

Campaigns, Totoro/DRAC, NEWS, register promotion, Phase 1B API,
interval lane, Poisson/NB (Phase 4), merge of #962 or #961.
