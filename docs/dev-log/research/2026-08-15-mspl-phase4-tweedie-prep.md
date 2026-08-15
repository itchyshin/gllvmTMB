# Phase 4-style prep — Tweedie LA-MSPL route (not admitted)

**Status:** design + local oracles only. This lane does **not**
write registry rows and does **not** widen
`.gllvmTMB_mspl_prepare()`. Tweedie remains `family_id` 6, rejected
by the live fence (`fam_ids %in% c(0L, 1L)`). **Verdict: PASS for
oracles / planned-on-paper, FAIL for C++ / admission /
`estimator = "mspl"` on Tweedie.**

**Reader:** statistical method developer / TMB engineer who must
decide whether a later tape may add a Tweedie compound-Poisson
atom — and who must not treat Tweedie zeros as Poisson all-zero.

**Programme constitution:**
`docs/dev-log/after-task/2026-08-14-laplace-mspl-estimator-programme.md`.
Phase 4 is Poisson, then NB2/NB1. **Tweedie is listed under Phase
5** (point masses and shape parameters), after ordinal /
multinomial / beta. This note is a Phase-4-*style* prep: it pins
the information atom and the zero mechanism so a later Phase-5
derivation cannot inherit Poisson by convenience.

This is **LA-MSPL** (Laplace + a soft *outer* penalty), not EVA/VA,
not AGHQ-MSPL. There is **no** verified third-party theorem that
transfers Bernoulli Jeffreys/`V_loading`, Gaussian Hirose \(\Psi\),
or Poisson \(W=\operatorname{diag}(\mu)\) to a Tweedie GLLVM under
Laplace (programme §7; Ranga corpus). Every formula below that is
not textbook Tweedie EDF information is **AGENT-INFERRED** and
exists to pin oracles, not to license a tape.

## Why this family is not Poisson-next

Poisson Phase-4 prep
(`docs/dev-log/research/2026-08-15-mspl-phase4-poisson-prep.md`)
earned a Jeffreys-shaped atom on \(W=\operatorname{diag}(\mu)\)
and a coercivity sketch for the *all-zero trait* path
\(y_{\cdot t}\equiv 0\Rightarrow\mu\to 0\). Tweedie looks like a
count family with zeros, so the tempting transplant is “reuse the
Poisson atom; zeros are zeros.”

That transplant fails twice:

1. **Power and dispersion.** Tweedie is an exponential dispersion
   family with variance \(\operatorname{Var}(Y)=\varphi\mu^{p}\),
   \(1<p<2\). The GLM weight is \(\mu^{2-p}/\varphi\), not
   \(\mu\). Both \(\varphi\) and \(p\) are free parameters in the
   live engine (`log_phi_tweedie`, `logit_p_tweedie` with
   \(p=1+\operatorname{invlogit}\); `R/enum.R` `tweedie = 6L`).
2. **Mass-at-zero is a distribution property.** For the compound
   Poisson–gamma regime, \(\Pr(Y=0)>0\) at any finite \(\mu\).
   That is not the Poisson all-zero *sample path*.

Do not promote Tweedie because Poisson planned rows exist. Do not
call this Phase-4 admission.

## 1. Five-row symbolic alignment

Textbook Tweedie / EDF expected information for free fixed
coordinates \(\beta_*\) on the log link (McCullagh & Nelder;
Jørgensen 1997):

\[
I(\beta_*)=\frac{1}{\varphi}\,X_*^\top W(\mu,p)\,X_*,\qquad
W(\mu,p)=\operatorname{diag}(\mu^{2-p}).
\]

Equivalently the working weights are
\(w_i=\mu_i^{2-p}/\varphi\). A Jeffreys-shaped fixed-effect atom
on the *maximised* log-likelihood scale is therefore

\[
P^*_{\mathrm{J}}=\tfrac12\log\det\bigl(X_*^\top\operatorname{diag}(\mu^{2-p}/\varphi)\,X_*\bigr).
\]

TMB minimises negative log-likelihood, so a later tape would add
\(-c\,P^*_{\mathrm{J}}\) together with any loading / \((\varphi,p)\)
atoms that earn their own coercivity proofs. The soft rate \(c\)
is **not** pinned here: Bernoulli
\(c_n=2\sqrt{p_{\mathrm{free}}/N_{\mathrm{eff}}}\), Gaussian
\(c_N=\sqrt{2/N}\), and the unpinned Poisson rate are all
rejected transplants (kill list §5).

At the Poisson corner \(p=1\), \(\varphi=1\),
\(W=\operatorname{diag}(\mu)\) and \(I(\beta_*)\) recovers the
Poisson Phase-4 atom. That identity is a *diagnostic* (oracle E2).
The live constructor constrains \(1<p<2\); the corner is not an
admitted cell.

| Criterion | Atom | Parameters | TMB-shaped expression on paper | Interpretation |
|---|---|---|---|---|
| Tweedie Jeffreys-shaped \(P^*_{\mathrm{J}}\) | \(\tfrac12\log\det(X_*^\top\operatorname{diag}(\mu^{2-p}/\varphi)X_*)\) | free \(\beta_*\); \(\mu=e^{\eta}\); \(\varphi>0\); \(1<p<2\) | \(\mathrm{nll}\mathrel{+}=-c\,P^*_{\mathrm{J}}\) | Softens \(\mu\to 0\) paths where \(W\to 0\). \(\beta\)-, \(\varphi\)-, and \(p\)-dependent. |
| Dispersion \(\varphi\) | scales \(I(\beta_*)\) by \(1/\varphi\); enters \(\Pr(Y=0)\) | `log_phi_tweedie` | diagnostic / OPEN tape | \(\varphi\to 0\) over-weights \(I\); \(\varphi\to\infty\) flattens \(I\) and raises the zero mass. Not a Poisson \(\varphi\equiv 1\) object. |
| Power \(p\) | enters \(W=\mu^{2-p}\) and \(\Pr(Y=0)\) | `logit_p_tweedie`, \(p=1+\operatorname{invlogit}\) | diagnostic / OPEN tape | \(p\to 1^+\) Poisson-like; \(p\to 2^-\) gamma-like (zero mass \(\to 0\)). Both are *power* boundaries. |
| Contrast: Poisson all-zero | \(y_{\cdot t}\equiv 0\Rightarrow\mu\to 0\Rightarrow P^*_{\mathrm{J}}\to-\infty\) on \(W=\operatorname{diag}(\mu)\) | Poisson \(\mu\) only | Poisson Phase-4 E2 | A *sample path*, not \(\Pr(Y=0)\). |
| Contrast: Tweedie mass-at-zero | \(\Pr(Y=0)=\exp\bigl(-\mu^{2-p}/(\varphi(2-p))\bigr)\) | \(\mu,\varphi,p\) | oracle E3–E4 | Distributional point mass at any finite \(\mu\). Observing zeros is expected. |

Existence / coercivity sketch used as the oracle contract
(fixed-design slice first; latent loadings and full
\(I_{\varphi,p}\) deferred):

- **T1** \(P^*_{\mathrm{J}}\) is continuous for \(\mu>0\),
  \(\varphi>0\), \(1<p<2\), and full-rank \(X_*\).
- **T2** Along a mean path \(\mu\to 0\) at fixed \((\varphi,p)\),
  \(W=\mu^{2-p}\to 0\) (because \(2-p>0\)) and
  \(P^*_{\mathrm{J}}\to-\infty\) when \(X_*\) has a column active
  on those rows. This is a *mean* boundary, not the mass-at-zero
  object (oracle E7).
- **T3** Doubling \(\varphi\) at fixed \((\mu,p)\) halves
  \(I(\beta_*)\) and *raises* \(\Pr(Y=0)\) (oracle E5). Dispersion
  is not a second spelling of the Poisson all-zero path.
- **T4** \(p\to 1^+\) sends \(\Pr(Y=0)\to\exp(-\mu/\varphi)\);
  \(p\to 2^-\) sends \(\Pr(Y=0)\to 0\) (oracle E6). Those limits
  are power-parameter boundaries. They are not
  \(y_{\cdot t}\equiv 0\).
- **T5** Full expected information for \((\varphi,p)\) involves
  the Tweedie series (Dunn & Smyth 2005, 2008) and is **OPEN**.
  This note pins only how \((\varphi,p)\) enter \(I(\beta_*)\) and
  \(\Pr(Y=0)\).

Latent loading coercivity under Laplace is **OPEN**. The Bernoulli
radial atom is listed only as a forbidden transplant.

## 2. Mass-at-zero \(\neq\) Poisson all-zero

### Poisson all-zero (the object already pinned)

For a Poisson trait with \(y_{\cdot t}\equiv 0\),

\[
\ell_t=-\sum_i\mu_{it},
\]

and the conditional MLE drives \(\mu_{\cdot t}\to 0\)
(\(\beta_t\to-\infty\) on an intercept-only trait). Fisher weights
vanish with \(\mu\). That is a *data path*: every observation on
the trait is the integer 0.

### Tweedie mass-at-zero (a different object)

In the compound Poisson–gamma regime \(1<p<2\) (Jørgensen 1997;
Dunn & Smyth 2005),

\[
\Pr(Y=0)=\exp\Bigl(-\frac{\mu^{2-p}}{\varphi(2-p)}\Bigr).
\]

At a perfectly ordinary interior point, for example
\(\mu=1\), \(\varphi=1\), \(p=1.5\),

\[
\Pr(Y=0)=\exp(-2)\approx 0.135.
\]

Zeros are *expected*. They do not imply \(\mu\to 0\), they do not
send \(P^*_{\mathrm{J}}\to-\infty\), and they are not evidence of
the Poisson all-zero MLE pathology. The existing recovery test
(`tests/testthat/test-tweedie-recovery.R`) already treats
“zeros and positive continuous values” as the healthy compound
regime, citing Shono (2008) and Lecomte et al. (2013).

The two objects *touch* as \(\mu\to 0\): \(\Pr(Y=0)\to 1\) and
the mean-information atom deteriorates (oracle E7). Contact is
not identity. Repairing a Tweedie all-zero *sample* is still a
mean-boundary problem on \(W=\mu^{2-p}/\varphi\), not a licence
to paste the Poisson \(W=\mu\) atom or to treat every observed
zero as that sample.

### What a later tape must not do

- Count Tweedie zeros and call them Poisson all-zero.
- Drop \(\varphi\) or \(p\) from the weight.
- Use Bernoulli \(W_g=\mu(1-\mu)\) or Hirose \(1/\psi\).
- Treat \(p\to 1\) or \(p\to 2\) as interior.

## 3. Power and dispersion as their own boundaries

Live parameterisation (`src/gllvmTMB.cpp`):

\[
\varphi_t=\exp(\texttt{log\_phi\_tweedie}_t),\qquad
p_t=1+\operatorname{invlogit}(\texttt{logit\_p\_tweedie}_t).
\]

The constructor also accepts a *fixed* \(p\in(1,2)\)
(`tweedie(p = …)`). Both the free-\(p\) and fixed-\(p\) surfaces
still carry free \(\varphi\). Neither is Poisson
(\(\varphi\equiv 1\), \(p\equiv 1\)).

| Boundary | What moves | What it is not |
|---|---|---|
| \(\mu\to 0\) | \(W=\mu^{2-p}\to 0\); \(\Pr(Y=0)\to 1\) | Poisson all-zero *sample*; Bernoulli separation |
| \(\varphi\to 0\) | \(I(\beta_*)\to\infty\); \(\Pr(Y=0)\to 0\) | Heywood \(\psi\to 0\) |
| \(\varphi\to\infty\) | \(I(\beta_*)\to 0\); \(\Pr(Y=0)\to 1\) | Poisson exposure / \(N_{\mathrm{eff}}\) |
| \(p\to 1^+\) | \(W\to\mu\); \(\Pr(Y=0)\to e^{-\mu/\varphi}\) | An admitted Poisson MSPL cell |
| \(p\to 2^-\) | \(W\to 1\); \(\Pr(Y=0)\to 0\) (gamma limit) | A Tweedie zero-mass problem |

Oracle E5–E6 pin the \(\varphi\) and \(p\) directions. They do
not propose atoms for \(\varphi\) or \(p\). Those remain OPEN
with the Tweedie series information.

## 4. Why Poisson, Bernoulli, and Hirose do not transfer

1. **Weights.** Poisson \(W=\operatorname{diag}(\mu)\) equals
   Tweedie \(W=\operatorname{diag}(\mu^{2-p}/\varphi)\) only at
   the corner \(p=1\), \(\varphi=1\) (oracle E1–E2). Reusing the
   Poisson atom at the live default \(p\approx 1.5\) is a wrong
   information matrix.
2. **Zero object.** Poisson Jeffreys repairs the all-zero *MLE
   path*. Tweedie \(\Pr(Y=0)\) is positive at moderate \(\mu\)
   (oracle E3–E4).
3. **Bernoulli \(V_{\mathrm{loading}}\)** is \(\mu\)-inert and
   \(\varphi\)-inert (oracle E8). It cannot supply a Tweedie
   mean or zero-mass repair.
4. **Gaussian Hirose** \(\sum S_{jj}/\psi_j\) needs a free
   unique-variance coordinate. Ordinary Tweedie rows have
   \((\mu,\varphi,p)\), not \(\Psi\). Fabricating
   \(\psi=1/\mu\) or \(\psi=\varphi\) is a type error (oracle E8).

Do not keep Poisson atoms “for symmetry with Phase 4.”

## 5. Kill list — fail the later derivation on any of these

1. Transplant of Poisson \(W=\operatorname{diag}(\mu)\) without
   restoring \(\mu^{2-p}/\varphi\).
2. Treating Tweedie \(\Pr(Y=0)\) as the Poisson all-zero sample
   path, or counting zeros as that pathology.
3. Transplant of Bernoulli \(V_{\mathrm{loading}}\) or Jeffreys
   \(W_g\) (logit / probit / cloglog).
4. Transplant of Gaussian Hirose / Akaike \(\Psi\) atoms, or any
   \(1/\psi\) term, into a Tweedie ordinary cell.
5. Reuse of Bernoulli \(c_n\), Gaussian \(c_N\), or an unpinned
   Poisson rate without a Tweedie rate argument against the
   Laplace objective.
6. Claiming Design 88, Sterzinger–Kosmidis–Moustaki 2026, or
   Poisson Phase-4 prep covers Tweedie GLLVM MSPL under Laplace.
7. Finiteness of a Tweedie fit offered as the scientific result.
8. Mixed-family, NB1/NB2, or Poisson-admission inheritance
   (“Poisson worked, so Tweedie does”).
9. Quietly widening `.gllvmTMB_mspl_prepare()` beyond
   `family_id %in% {0,1}`.
10. Any admission-shaped language (status flip to `admitted`,
    NEWS covered, validation-register promotion, C++ tape)
    ahead of the Shinichi gate.
11. Live `gllvmTMB(..., estimator = "mspl")` on Tweedie in tests.
12. Treating \(p=1\) or \(p=2\) as interior, or writing a
    planned Tweedie row into the registry from this lane
    (OWN fence; Poisson `nrow(planned)==2` pin stays intact).

## 5b. Oracle contract E1–E8 (pure R; no Tweedie `estimator="mspl"`)

| ID | What | Tolerance / decision |
|---|---|---|
| E1 | Tweedie \(I=X^\top\operatorname{diag}(\mu^{2-p}/\varphi)X\); Poisson \(W=\mu\) **differs** at \(p=1.5\) | rel. err \(<10^{-12}\) on Tweedie; contrast fires |
| E2 | Corner \(p=1\), \(\varphi=1\) recovers Poisson \(I\); \(p=1.5\) does not | exact at corner; contrast fires |
| E3 | \(\Pr(Y=0)=\exp(-\mu^{2-p}/(\varphi(2-p)))\) at moderate \(\mu\) is in \((0,1)\) | closed form; \(\mu=1,\varphi=1,p=1.5\) gives \(e^{-2}\) |
| E4 | That mass is **not** the Poisson all-zero path: \(P^*_{\mathrm{J}}\) stays finite at the same \(\mu\) | finite \(P^*_{\mathrm{J}}\); \(\Pr(Y=0)\neq 1\) |
| E5 | \(\varphi\leftarrow 2\varphi\) halves \(I(\beta_*)\) and raises \(\Pr(Y=0)\); row count fixed | exact factor \(1/2\) on \(I\) |
| E6 | \(p\to 2^-\) sends \(\Pr(Y=0)\to 0\); \(p\to 1^+\) approaches \(e^{-\mu/\varphi}\) | monotone; rel. err \(<5\times 10^{-3}\) at \(p=1.001\); \(p=1.05\) farther |
| E7 | Mean path \(\mu\leftarrow\varepsilon\mu_0\) deteriorates Tweedie \(P^*_{\mathrm{J}}\) and sends \(\Pr(Y=0)\to 1\) | monotone; Tweedie \(W=\mu^{0.5}\) decays slower than Poisson \(W=\mu\) |
| E8 | Hirose \(\sum S/\psi\) refused; \(V_{\mathrm{loading}}\) is \(\mu\)- and \(\varphi\)-inert | structural reject; finite-diff 0 |

Fence tests (not numbered as E): Tweedie is not `admitted`;
prepare body still contains `fam_ids %in% c(0L, 1L)`; this file
never calls `estimator = "mspl"`.

## 6. Verdict

| Surface | Verdict | Why |
|---|---|---|
| Local R oracles / this writeup (E1–E8, kill list) | **PASS** | Power/dispersion weights and mass-at-zero \(\neq\) Poisson all-zero are testable without a Tweedie MSPL fit. |
| C++ tape / live Tweedie MSPL / registry `planned` or `admitted` | **FAIL** | No tape, no prepare widening, no registry mutation, no Shinichi admission gate. |
| NEWS / covered / SE / intervals | **FAIL** | Out of scope; SE remains PROTECTED on Codex Lane B. |

Preferred later-admission *candidate* for the fixed-effect slice:
Tweedie Jeffreys-shaped
\(\tfrac12\log\det(X_*^\top\operatorname{diag}(\mu^{2-p}/\varphi)X_*)\),
with rate, loading, and \((\varphi,p)\) atoms still OPEN. Not a
theorem transfer. Not a Poisson inheritance.

## 7. Non-claims

This note does **not** claim:

- calibrated inference, SEs, profiles, or model comparison;
- a live Tweedie `estimator = "mspl"` fit;
- that Poisson \(W=\mu\), Bernoulli \(c_n\), \(V_{\mathrm{loading}}\),
  or Gaussian Hirose transfer;
- that Laplace is exact for Tweedie (it is not);
- that Tweedie is a Phase-4 family (constitution: Phase 5);
- NB1 / NB2 / truncated / delta / mixed-family MSPL;
- structured tiers (`phylo_*`, `spatial_*`, `animal_*`, `kernel_*`);
- a full \(I_{\varphi,p}\) tape object;
- that EVA/VA is involved (it is not).

## 8. What must exist before admission (unchanged programme gate)

1. Symbolic information atom and coercivity at the *mean*
   boundary **and** a separate treatment of \(\Pr(Y=0)\) that
   does not collapse it onto Poisson all-zero (this note +
   oracles) **and** proved \((\varphi,p)\) and loading atoms
   under Laplace.
2. Healthy-regime no-harm vs LA-ML, including the ordinary
   compound-Poisson zero mass (not this run).
3. Family-specific TMB oracles after any tape (not this run).
4. Shinichi gate before any `status` flip, and before any
   prepare widening to `family_id` 6.

## 9. Rose boundary

- **Not EVA / not VA.** Outer criterion is Laplace-ML plus a soft
  penalty yet to be taped.
- **Planned-on-paper \(\neq\) `admitted`.** This lane writes no
  registry row. Poisson `planned` rows stay the only Phase-4
  planned cells.
- **Prepare fence unchanged.** `family_id` still only `{0,1}`.
- **No C++.** `git diff -- src/` must stay empty on this arc.
- **No NEWS covered.** No validation-register promotion.
- **No repo-root `LOOP/`.** Lane kit:
  `docs/dev-log/lanes/cursor-mspl-phase4-tweedie/LOOP/`.

## Out of scope here

Campaigns, Totoro/DRAC, NEWS, register promotion, registry
mutation, Phase 1B API, interval lane, NB1/NB2, C++ tape,
`estimator = "mspl"` on Tweedie, prepare widening.

## References (local + textbook)

- Jørgensen, B. (1997). *The Theory of Dispersion Models*.
- Dunn, P. K. & Smyth, G. K. (2005). Series evaluation of
  Tweedie exponential dispersion model densities. *Statistics
  and Computing* 15:267–280.
- Dunn, P. K. & Smyth, G. K. (2008). Evaluation of Tweedie
  exponential dispersion model densities by Fourier inversion.
  *Statistics and Computing* 18:73–86.
- Shono, H. (2008). *Fisheries Research* 93:154–162; Lecomte
  et al. (2013). *Ecological Modelling* 265:74–84 — applied
  citations already used by `test-tweedie-recovery.R`.
- Poisson contrast:
  `docs/dev-log/research/2026-08-15-mspl-phase4-poisson-prep.md`.
