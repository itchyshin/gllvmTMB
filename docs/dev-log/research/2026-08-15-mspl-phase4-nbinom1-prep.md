# Phase 4 prep — nbinom1 LA-MSPL route (not admitted)

**Status:** design + local oracles only. **No registry row** is added
for `nbinom1`. `.gllvmTMB_mspl_prepare()` still rejects every
non-binomial / non-gaussian family at the `family_id` fence
(`fam_ids %in% c(0L, 1L)`); nbinom1 is runtime `family_id` **15**.
**Verdict: PASS for oracles / this writeup, FAIL for C++ / admission /
registry / `estimator = "mspl"` on nbinom1.**

**Reader:** statistical method developer / TMB engineer who must
decide whether a later tape may add an NB1 count atom. This note
does **not** inherit the Poisson Phase-4 atom, rate, or oracles.

**Programme constitution:**
`docs/dev-log/after-task/2026-08-14-laplace-mspl-estimator-programme.md`
§Phase 4 — *Negative binomial next: separate mean-boundary penalties
from dispersion \(0\) or \(\infty\) boundaries. NB1 and NB2 do not
inherit each other's scale or theorem.*

This is **LA-MSPL** (Laplace + a soft *outer* penalty), not EVA/VA,
not AGHQ-MSPL. There is **no** verified third-party theorem that
transfers Bernoulli Jeffreys/`V_loading`, Gaussian Hirose \(\Psi\),
or the Poisson \(W=\operatorname{diag}(\mu)\) atom to an NB1 GLLVM
under Laplace (programme §7; Ranga corpus). Every formula below that
is not textbook NB1 GLM information is **AGENT-INFERRED** and exists
to pin oracles, not to license a tape.

## Why this is its own family cell

Poisson Phase 4 is a one-parameter count mean. NB1 adds a free
linear overdispersion \(\varphi>0\) with a **different variance
function** from both Poisson and NB2. Programme lock: ordinary NB1

\[
\log\mu_{it}=x_{it}^\top\beta+\lambda_t^\top u_i
\quad\text{(optional known offset)},
\qquad
\operatorname{Var}(y_{it})=\mu_{it}(1+\varphi_t)=\mu_{it}+\varphi_t\mu_{it},
\]

soft outer penalty derived for *this* likelihood, separately. Do not
transplant Poisson \(W=\operatorname{diag}(\mu)\), NB2
\(V=\mu+\mu^2/\theta\), Bernoulli, or Gaussian atoms by convenience.
The Poisson note's kill #8 ("Poisson worked, so NB does") is the
reason this cell exists.

Locked implementation contract (read-only; this prep does not edit
`src/` or `R/`):

- runtime `family_id = 15`, log link only;
- per-trait \(\varphi=\exp(\texttt{log\_phi\_nbinom1})\);
- TMB uses `dnbinom_robust` with
  \(\log(V-\mu)=\log\mu+\log\varphi\) (`src/gllvmTMB.cpp` fid 15);
- size in the `stats::dnbinom` parameterisation is \(\mu/\varphi\),
  **not** a \(\mu\)-free \(\theta\).

Public `sigma` on nbinom1 is the same orientation (larger \(\sigma\)
\(\Rightarrow\) more linear-mean overdispersion;
`docs/design/03-likelihoods.md`). Oracles use the internal \(\varphi\).

## 1. Exact fixed-effect information alignment

The familiar variance-function expression

\[
W_{\mathrm{quasi}}=
\operatorname{diag}\!\left(\frac{(\mathrm{d}\mu/\mathrm{d}\eta)^2}{V(\mu)}\right)
=\operatorname{diag}\!\left(\frac{\mu}{1+\varphi}\right)
\]

is a **quasi-likelihood / IRLS working weight**, not the exact Fisher
information for gllvmTMB's NB1 likelihood. NB1 uses
`size = mu / phi`, so the negative-binomial shape
\(r=\mu/\varphi\) changes with the linear predictor.

In R/TMB's convention,

\[
f(y\mid\mu,\varphi)=
\frac{\Gamma(y+r)}{\Gamma(r)\Gamma(y+1)}
p^r(1-p)^y,\qquad
r=\frac{\mu}{\varphi},\qquad
p=\frac{1}{1+\varphi}.
\]

Here \(p\) is the success probability; \(1-p=\varphi/(1+\varphi)\).
At fixed \(\varphi\), \(\mathrm dr/\mathrm d\eta=r\), giving score

\[
s_\eta(y)=r\{\psi(y+r)-\psi(r)+\log p\}.
\]

The exact scalar Fisher contribution is

\[
\mathcal I_\eta(\mu,\varphi)
=\sum_{y=0}^{\infty}f(y\mid\mu,\varphi)s_\eta(y)^2
=-\operatorname E\!\left[\frac{\partial s_\eta}{\partial\eta}\right],
\]

with

\[
-\frac{\partial s_\eta}{\partial\eta}
=-r\{\psi(y+r)-\psi(r)+\log p\}
-r^2\{\psi_1(y+r)-\psi_1(r)\}.
\]

The pure-R oracles sum the same `stats::dnbinom` pmf implied by the
implementation, truncating only after the remaining tail probability
is below \(10^{-13}\), and check the outer-product and
expected-Hessian forms against each other. Therefore

\[
I_{\mathrm{exact}}(\beta_*)=
X_*^\top\operatorname{diag}\{\mathcal I_\eta(\mu_i,\varphi)\}X_*,
\qquad
P^*_{\mathrm{J,NB1}}=
\tfrac12\log\det I_{\mathrm{exact}}(\beta_*).
\]

For orientation:

| Family / object | Variance \(V(\mu)\) | Log-link quantity |
|---|---|---|
| Poisson exact Fisher | \(\mu\) | \(\mu\) |
| **NB1 exact Fisher** | \(\mu(1+\varphi)\) | \(\mathcal I_\eta(\mu,\varphi)\), pmf expectation above |
| **NB1 quasi / IRLS** | \(\mu(1+\varphi)\) | \(\mu/(1+\varphi)\) |
| NB2 GLM weight | \(\mu+\mu^2/\theta\) | \(\mu\theta/(\theta+\mu)\) |

TMB minimises negative log-likelihood, so a later tape would add
\(-c\,P^*_{\mathrm{J,NB1}}\) together with any loading or
**dispersion** atoms that earn their own coercivity proofs. The soft
rate \(c\) is **not** pinned here. Bernoulli
\(c_n=2\sqrt{p_{\mathrm{free}}/N_{\mathrm{eff}}}\), Gaussian
\(c_N=\sqrt{2/N}\), and any Poisson rate left OPEN in the Poisson
note are all rejected transplants (kill list §5).

Even when \(\varphi\) is shared, the identity

\[
I_{\mathrm{quasi}}(\beta_*)=\frac{I_{\mathrm{Poisson}}(\beta_*)}{1+\varphi},
\qquad
P^*_{\mathrm{quasi}}=P^*_{\mathrm{J,Pois}}-\frac{p_*}{2}\log(1+\varphi)
\]

holds only for the quasi weight. It is false for exact NB1 Fisher
information. N3 pins that failure so a later tape cannot mistake the
working weight for a Jeffreys atom.

| Criterion | Atom | Parameters | TMB-shaped expression on paper | Interpretation |
|---|---|---|---|---|
| NB1 exact Jeffreys-shaped \(P^*_{\mathrm{J,NB1}}\) | \(\tfrac12\log\det(X_*^\top\operatorname{diag}\{\mathcal I_\eta(\mu,\varphi)\}X_*)\) | free \(\beta_*\); \(\mu=\exp(\eta)\) (× exposure if offset); \(\varphi>0\) | candidate only; no tape | Uses the actual `size = mu / phi` pmf. |
| NB1 quasi / IRLS object | \(\mu/(1+\varphi)\) | \(\mu,\varphi\) | diagnostic contrast only | **Not** the Jeffreys atom. |
| Information size | \(\sum_i\mathcal I_\eta(\mu_i,\varphi)\) or \(\lambda_{\min}(I_{\mathrm{exact}})\) | \(\mu,\varphi\) | diagnostic only | **Not** \(\sum\mu/(1+\varphi)\), \(\sum\mu\), or row count. |
| Dispersion \(\varphi\to 0\) | exact pmf information approaches Poisson | \(\varphi\) at fixed \(\mu>0\) | OPEN; no tape | \(P^*_{\mathrm{J,NB1}}\to P^*_{\mathrm{J,Pois}}\). |
| Dispersion \(\varphi\to\infty\) | exact pmf information collapses | \(\varphi\) at fixed \(\mu>0\) | dedicated \(\varphi\) atom OPEN | Distinct from \(\mu\to 0\). |
| Contrast: Poisson \(W=\operatorname{diag}(\mu)\) | \(\tfrac12\log\det(X_*^\top\operatorname{diag}(\mu)X_*)\) | \(\mu\) only | Poisson Phase-4 candidate | Equals NB1 only at \(\varphi=0\). Oracle kill as a transplant. |
| Contrast: NB2 \(W=\operatorname{diag}(\mu\theta/(\theta+\mu))\) | \(\tfrac12\log\det(X_*^\top\operatorname{diag}(\mu\theta/(\theta+\mu))X_*)\) | \(\mu,\theta\) | not this cell | Quadratic-mean information. Setting \(\theta=1/\varphi\) does **not** recover NB1 unless \(\mu=1\). |
| Contrast: Bernoulli \(V_{\mathrm{loading}}\) | \(\sum_t(\sqrt{1+\|\lambda_t\|^2}-1)\) | \(\Lambda\) only | live `gll_mspl_row_radial_penalty` | Binary link-scale runaway atom. No NB1 coercivity proof. |
| Contrast: Gaussian Hirose | \(\sum_j S_{jj}/\psi_j\) | diagonal \(\Psi\) | Phase 3 planned tape object | Heywood unique-variance atom. NB1 \(\varphi\) is not \(\psi\). |

Existence / coercivity sketch used as the oracle contract (fixed-design
slice first; latent loadings and a dedicated \(\varphi\) atom deferred):

- **N-P1** \(P^*_{\mathrm{J,NB1}}\) is continuous for \(\mu>0\),
  \(\varphi>0\), and full-rank \(X_*\).
- **N-P2 (mean boundary).** Along an all-zero or near-zero path with
  \(\mu_t\to 0\) at **fixed** \(\varphi>0\), the pmf-summed exact
  \(\mathcal I_\eta\to 0\) and
  \(P^*_{\mathrm{J,NB1}}\to-\infty\) whenever \(X_*\) has a column
  that is active on those rows.
- **N-P3 (dispersion \(\to 0\)).** At fixed \(\mu>0\),
  \(\varphi\to 0^+\) sends the exact information toward
  \(\operatorname{diag}(\mu)\) and
  \(P^*_{\mathrm{J,NB1}}\uparrow P^*_{\mathrm{J,Pois}}\). This is a
  nested-family limit, not a mean-boundary, and **not** a reason to
  inherit a Poisson MSPL tape.
- **N-P4 (dispersion \(\to\infty\)).** At fixed \(\mu>0\),
  the exact pmf-summed information decreases toward zero as
  \(\varphi\to\infty\), and
  \(P^*_{\mathrm{J,NB1}}\to-\infty\). Same qualitative divergence as
  N-P2, **different coordinate**. A dedicated \(\varphi\) atom (Jeffreys
  in \(\varphi\), barrier, or otherwise) is **OPEN**. Using the mean
  atom as a \(\varphi\to 0\) repair is a type error: that path
  *increases* \(P^*_{\mathrm{J}}\).
- **N-P5** The conditional NB1 log-pmf is bounded above for fixed
  \(y\) (size \(\mu/\varphi\), success probability
  \(1/(1+\varphi)\) is \(\mu\)-free). Combined with N-P2, a soft
  \(+c P^*_{\mathrm{J,NB1}}\) term (maximisation scale) pulls away
  from the infinite-\(|\beta|\) all-zero MLE path in the same
  *qualitative* way Poisson Jeffreys does — **AGENT-INFERRED**
  analogy, not a transferred theorem.
- **N-P6** Exposure enters only through \(\mu=E\circ e^{\eta}\).
  Doubling every \(E\) at fixed \(\eta_{\mathrm{free}}\) and fixed
  \(\varphi\) doubles \(\mu\), but does **not** double exact Fisher
  information because \(r=\mu/\varphi\) also changes. N9 observes
  increasing but sublinear information on the frozen fixture. The
  exact information size is \(\sum_i\mathcal I_\eta(\mu_i,\varphi)\),
  not the quasi sum \(\sum\mu/(1+\varphi)\), \(\sum\mu\), or
  \(N_{\mathrm{rows}}\).

Latent loading coercivity under Laplace is **OPEN**. The Bernoulli
radial atom is listed only as a forbidden transplant, not as a
candidate. A \(\varphi\)-only atom is **OPEN**.

## 2. Three named boundaries (do not collapse them)

### Mean boundary — all-zero / near-zero at fixed \(\varphi\)

For a trait with \(y_{\cdot t}\equiv 0\) and \(\varphi_t\) held away
from \(0\),

\[
\ell_t=\sum_i\log f_{\mathrm{NB1}}(0\mid\mu_{it},\varphi_t)
\]

still drives \(\mu_{\cdot t}\to 0\) (equivalently
\(\beta_t\to-\infty\) on an intercept-only trait design). Exact
pmf-summed Fisher contributions on those rows vanish. Any soft
penalty whose fixed-effect atom is
\(\tfrac12\log\det I_{\mathrm{exact}}(\beta_*)\) therefore
diverges to \(-\infty\) on that path when the trait’s design columns
remain in \(X_*\) (oracle N4). Finiteness of a penalised fit on
all-zero data is necessary and **not** sufficient for admission
(programme §16).

Sparse but non-zero counts keep \(\mu\) small on most units. N5 pins
the exact atom's deterioration numerically without asserting the
quasi weight as its asymptotic rate.

### Dispersion \(\varphi\to 0\) — Poisson limit, not a mean repair

As \(\varphi\to 0\), \(\operatorname{Var}\to\mu\),
\(\texttt{size}=\mu/\varphi\to\infty\), and the TMB
\(\log(V-\mu)=\log\mu+\log\varphi\to-\infty\) recovers the Poisson
kernel. The mean Jeffreys atom **grows** toward the Poisson value.
A later derivation that treats “\(\varphi\) small, therefore use
the Poisson Phase-4 atom / rate / loading candidate” has failed
the programme’s no-inheritance rule. Chung-type cautions also
apply: forcing \(\varphi\) off \(0\) when the truth is Poisson
changes the estimand.

### Dispersion \(\varphi\to\infty\) — overdispersion information collapse

At fixed \(\mu>0\), exact pmf-summed mean information decreases
toward zero. Every count becomes infinitely noisy; the mean did not
hit its boundary. N7 checks this path separately from N4. This
qualitative behavior does **not** close a \(\varphi\)-atom derivation.

### Loading runaway (named, not solved)

On \(\log\mu=\eta_{\mathrm{fix}}+\lambda^\top u\), large
\(\|\lambda\|\) can send some units’ means to \(+\infty\) and others
toward \(0\). That is a *different* boundary from \(\varphi\to 0\),
\(\varphi\to\infty\), Gaussian \(\psi\to 0\), and Bernoulli
separation. **No NB1 loading atom is admitted in this note.**

## 3. Why Poisson and NB2 do not transfer

### Poisson \(W=\operatorname{diag}(\mu)\)

Exact NB1 information approaches Poisson information only in the
\(\varphi\to0\) limit. At interior \(\varphi>0\), it is neither
Poisson information nor its constant \(1/(1+\varphi)\) rescaling.
That rescaling belongs to the quasi weight only (N2–N3). The
Poisson note itself forbids NB1/NB2 inheritance.

### NB2 \(V=\mu+\mu^2/\theta\)

NB2 (fid 5) uses \(\log(V-\mu)=2\log\mu-\log\theta\) with
\(\theta=\exp(\texttt{log\_phi\_nbinom2})\). The log-link weight
\(\mu\theta/(\theta+\mu)\) is a **\(\mu\)-dependent** downscale of
Poisson, not a constant \(1/(1+\varphi)\). Setting
\(\theta=1/\varphi\) still leaves

\[
V_{\mathrm{NB1}}=\mu(1+\varphi),\qquad
V_{\mathrm{NB2}}=\mu+\mu^2\varphi=\mu(1+\mu\varphi),
\]

which agree for all \(\mu\) only if \(\varphi=0\) or \(\mu=1\)
(oracle N8). The size constructions also differ: NB1 size
\(\mu/\varphi\) depends on \(\mu\); NB2 size \(\theta\) does not
(oracle N12). Programme: *NB1 and NB2 do not inherit each other's
scale or theorem.*

Do not treat \(\texttt{log\_phi\_nbinom1}\) and
\(\texttt{log\_phi\_nbinom2}\) as the same coordinate with two
names.

## 4. Why Bernoulli Jeffreys / \(V_{\mathrm{loading}}\) and Gaussian Hirose do not transfer

Design 88 maximises a Bernoulli Jeffreys term with link-specific
\(W_g\) plus \(V_{\mathrm{loading}}=\sum_t(\sqrt{1+\|\lambda_t\|^2}-1)\).
Three transfer failures remain, now with an extra NB1 reason:

1. **Information.** Exact NB1 \(\mathcal I_\eta(\mu,\varphi)\) is not
   its quasi weight \(\mu/(1+\varphi)\), Poisson \(\mu\), Bernoulli
   \(\mu(1-\mu)\), or a probit/cloglog weight.
2. **Boundary object.** Bernoulli repairs *separation*. NB1 must
   separate \(\mu\to 0\) from \(\varphi\to 0\) and \(\varphi\to\infty\).
3. **\(V_{\mathrm{loading}}\) is \(\mu\)-inert and \(\varphi\)-inert.**
   \(\partial V_{\mathrm{loading}}/\partial\mu\equiv 0\) and
   \(\partial V_{\mathrm{loading}}/\partial\varphi\equiv 0\)
   (oracle N11). It cannot supply either the all-zero or the
   \(\varphi\to\infty\) information divergence.

Phase 3 Hirose \(V_H=\sum_j S_{jj}/\psi_j\) targets Gaussian
Heywood \(\psi_j\to 0\). Ordinary NB1 has no free \(\Psi\).
Fabricating \(\psi=\varphi\) or \(\psi=1/\mu\) silently renames
the dispersion or the mean problem without a proof (oracle N11).

## 5. Exposure / offset versus information size

Write \(\log\mu_{it}=o_{it}+\eta_{it}^{\mathrm{free}}\) with
\(o_{it}=\log E_{it}\) and known \(E_{it}>0\). Then
\(\mu=E\circ\exp(\eta^{\mathrm{free}})\), while exact information is
\(\mathcal I_\eta(\mu,\varphi)\).

| Quantity | What it is | What it is not |
|---|---|---|
| Exposure \(E\) | Known mean multiplier / offset | Sample size; penalty rate \(c\); \(N_{\mathrm{eff}}\) |
| Row count \(N_{\mathrm{rows}}\) | Number of stacked \((i,t)\) observations | NB1 information |
| Poisson information size \(\sum\mu\) | Poisson weights | NB1 information unless \(\varphi=0\) |
| NB1 information size | \(X_*^\top\operatorname{diag}\{\mathcal I_\eta(\mu,\varphi)\}X_*\) and \(\sum_i\mathcal I_\eta(\mu_i,\varphi)\) | quasi \(\sum\mu/(1+\varphi)\), \(\sum E\), \(\sum\mu\), or Bernoulli \(N_{\mathrm{eff}}\) |

Oracle N9: at fixed free \(\eta\) and fixed \(\varphi\), replacing
\(E\) by \(2E\) doubles \(\mu\), but exact information increases
sublinearly on the fixture; only the quasi weight doubles exactly.
\(N_{\mathrm{rows}}\) is unchanged. Oracle
N10: absorbing \(\log E\) into the offset leaves \(\mu\) and \(I\)
unchanged. Live Design 88 still fences *nonzero* offsets on the
Bernoulli MSPL surface. This prep does not ask the prepare fence
to accept offsets.

## 5a. Kill list — fail the later derivation on any of these

1. Transplant of Poisson \(W=\operatorname{diag}(\mu)\) as if NB1
   were “Poisson plus \(\varphi\)”.
2. Transplant of NB2 \(W=\operatorname{diag}(\mu\theta/(\theta+\mu))\)
   or variance \(\mu+\mu^2/\theta\).
3. Treating \(\varphi_{\mathrm{NB1}}\) as \(\theta_{\mathrm{NB2}}\)
   or as \(1/\theta\); treating `log_phi_nbinom1` as
   `log_phi_nbinom2`.
4. Inheriting the Poisson Phase-4 oracles, rate, or loading
   candidate (“Poisson worked, so NB1 does”).
5. Treating \(\varphi\to 0\) as permission to run a Poisson MSPL
   tape, or using the mean Jeffreys atom as a \(\varphi\to 0\)
   repair (that path *increases* \(P^*_{\mathrm{J}}\)).
6. Collapsing \(\mu\to 0\), \(\varphi\to 0\), and \(\varphi\to\infty\)
   into one “count boundary”.
7. Transplant of Bernoulli \(V_{\mathrm{loading}}\) or Bernoulli
   \(W_g\) (logit / probit / cloglog).
8. Transplant of Gaussian Hirose / Akaike \(\Psi\) atoms, or any
   \(1/\psi\) term, including \(\psi:=\varphi\) or \(\psi:=1/\mu\).
9. Reuse of Bernoulli \(c_n=2\sqrt{p_{\mathrm{free}}/N_{\mathrm{eff}}}\),
   Gaussian \(c_N=\sqrt{2/N}\), or an unpinned Poisson rate without
   an NB1 rate argument against the Laplace objective.
10. Treating exposure \(\sum E\), row count, or Poisson
    \(\sum\mu\) as interchangeable with
    exact \(\sum_i\mathcal I_\eta(\mu_i,\varphi)\); or treating the
    quasi sum \(\sum\mu/(1+\varphi)\) as exact information.
11. Claiming Design 88 or Sterzinger–Kosmidis–Moustaki 2026 covers
    NB1 GLLVM MSPL under Laplace.
12. Finiteness of a count fit offered as the scientific result.
13. Mixed-family inheritance, or truncated / delta-truncated
    nbinom1 inheritance.
14. Any admission-shaped language (status flip to `admitted` or
    `planned`, NEWS covered, validation-register promotion, C++
    tape) ahead of the Shinichi gate.
15. Live `gllvmTMB(..., estimator = "mspl")` on nbinom1 in tests.
16. Quietly widening `.gllvmTMB_mspl_prepare()` beyond
    `family_id %in% {0,1}`.
17. Adding an nbinom1 registry row in this prep cell.

## 5b. Oracle contract N1–N13 (pure R; no nbinom1 `estimator="mspl"`)

| ID | What | Tolerance / decision |
|---|---|---|
| N1 | \(V_{\mathrm{NB1}}=\mu(1+\varphi)\); \(V_{\mathrm{Pois}}=\mu\); \(V_{\mathrm{NB2}}=\mu+\mu^2/\theta\) **differ** | rel. err \(<10^{-12}\) on NB1; contrasts fire |
| N2 | Exact \(\mathcal I_\eta\) from the NB1 pmf: analytic score = finite difference of `dnbinom`, total mass 1, expected score 0, outer product = expected Hessian; differs from quasi \(\mu/(1+\varphi)\) | score \(<10^{-8}\); moment identities \(<10^{-10}\); contrasts fire |
| N3 | \(P^*_{\mathrm{J,NB1}}\) uses exact \(\mathcal I_\eta\); shared-\(\varphi\) Poisson-rescaling identity holds only for the quasi object and fails for exact Fisher | quasi identity \(<10^{-12}\); exact contrast fires |
| N4 | Mean-boundary: \(\beta\to-\infty\Rightarrow\mu\to 0\Rightarrow P^*_{\mathrm{J,NB1}}\to-\infty\) at fixed \(\varphi>0\) | monotone decrease; large negative |
| N5 | Near-zero: scale \(\mu\leftarrow\varepsilon\mu_0\) at fixed \(\varphi\) deteriorates \(P^*_{\mathrm{J,NB1}}\) | monotone in \(\varepsilon\downarrow 0\) |
| N6 | \(\varphi\to 0\) at fixed \(\mu\): exact \(P^*_{\mathrm{J}}\) **increases** toward Poisson; does **not** go to \(-\infty\) | monotone increase; contrast with N4 |
| N7 | \(\varphi\to\infty\) at fixed \(\mu>0\): \(P^*_{\mathrm{J,NB1}}\to-\infty\) | monotone decrease; large negative |
| N8 | \(\theta=1/\varphi\) does **not** equate \(V\) or \(W\) unless \(\mu=1\) | contrast fires on the fixture |
| N9 | Exposure doubling at fixed \(\eta,\varphi\) doubles the quasi weight but increases exact information sublinearly on the fixture; \(N_{\mathrm{rows}}\) fixed | exact-vs-quasi contrast fires |
| N10 | Offset spelling: \(o=\log E\) vs folding \(\log E\) into \(\eta\) leaves \(\mu\) and \(I\) identical | \(<10^{-12}\) |
| N11 | Hirose \(\sum S/\psi\) refused (\(\varphi\) is not \(\psi\)); \(V_{\mathrm{loading}}\) is \(\mu\)- and \(\varphi\)-inert | structural reject + finite-diff |
| N12 | NB1 size \(\mu/\varphi\) depends on \(\mu\); success probability is \(1/(1+\varphi)\); \(\log(V-\mu)\) matches TMB | \(<10^{-12}\) |
| N13 | No live nbinom1 MSPL call; nbinom1 is not `admitted` and has no `planned` registry row | structural |

## 6. Verdict

| Surface | Verdict | Why |
|---|---|---|
| Local R oracles / this writeup (N1–N13, kill list) | **PASS** | Exact PMF-summed score information, its distinction from the quasi weight, three named boundaries, and exposure behavior are testable without an NB1 MSPL fit. |
| C++ tape / live nbinom1 MSPL / registry `planned` or `admitted` | **FAIL** | No tape, no prepare widening, no registry row, no Shinichi admission gate. |
| NEWS / covered / SE / intervals | **FAIL** | Out of scope; SE remains PROTECTED on Codex Lane B. |

Preferred later-admission *candidate* for the fixed-effect slice:
NB1 Jeffreys-shaped
\(\tfrac12\log\det(X_*^\top\operatorname{diag}\{\mathcal I_\eta(\mu,\varphi)\}X_*)\),
with rate, loading atom, and dedicated \(\varphi\) atom still OPEN.
Not a theorem transfer. Not the Poisson candidate.

## 7. Non-claims

This note does **not** claim:

- calibrated inference, SEs, profiles, or model comparison;
- a live nbinom1 `estimator = "mspl"` fit;
- that Poisson, NB2, Bernoulli \(c_n\), \(V_{\mathrm{loading}}\), or
  Gaussian Hirose transfer;
- that Laplace is exact for NB1 (it is not);
- that \(\varphi\to 0\) may reuse a Poisson MSPL route;
- truncated nbinom1 / delta-truncated nbinom1 / mixed-family MSPL;
- structured tiers (`phylo_*`, `spatial_*`, `animal_*`, `kernel_*`);
- that nonzero offsets are admitted;
- that EVA/VA is involved (it is not);
- a registry cell (none is added).

## 8. What must exist before admission (unchanged programme gate)

1. Symbolic information atom and coercivity at the **mean**
   boundary (this note + oracles) **and** separately argued
   \(\varphi\to 0\) / \(\varphi\to\infty\) atoms **and** a proved
   loading atom under Laplace.
2. Exposure vs information size pinned in the implemented rate
   (oracles N9–N10; rate choice still OPEN). Information size must
   use exact \(\sum_i\mathcal I_\eta(\mu_i,\varphi)\), not quasi
   \(\sum\mu/(1+\varphi)\) or Poisson \(\sum\mu\).
3. Healthy-regime no-harm vs LA-ML, plus boundary DGPs that
   **label** which of the three boundaries is active (not this run).
4. Family-specific TMB oracles after any tape (not this run).
5. Shinichi gate before any registry row, and again before
   `status` could flip to `admitted`.

## 9. Rose boundary

- **Not EVA / not VA.** Outer criterion is Laplace-ML plus a soft
  penalty yet to be taped.
- **Not Poisson Phase 4.** This cell has its own atom and kill list.
- **No registry row.** nbinom1 is not `planned` and not `admitted`.
- **Prepare fence unchanged.** `family_id` still only `{0,1}`;
  nbinom1 is 15.
- **No C++.** `git diff -- src/` must stay empty on this arc.
- **No NEWS covered.** No validation-register promotion.
- **No repo-root `LOOP/`.** Lane kit:
  `docs/dev-log/lanes/cursor-mspl-point-continue/LOOP/`.

## Out of scope here

Campaigns, Totoro/DRAC, NEWS, register promotion, Phase 1B API,
interval lane, Poisson/NB2 admission, C++ tape,
`estimator = "mspl"` on nbinom1, truncated / hurdle nbinom1.
