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

## 1. Five-row symbolic alignment

GLM expected information for free fixed coordinates \(\beta_*\) on
the log link is textbook:

\[
I(\beta_*)=X_*^\top W\,X_*,\qquad
W=\operatorname{diag}\!\left(\frac{(\mathrm{d}\mu/\mathrm{d}\eta)^2}{V(\mu)}\right)
=\operatorname{diag}\!\left(\frac{\mu^2}{V(\mu)}\right).
\]

The three count variance functions then give **three different
weights**:

| Family | Variance \(V(\mu)\) | Log-link weight \(W\) |
|---|---|---|
| Poisson | \(\mu\) | \(\mu\) |
| **NB1** | \(\mu+\varphi\mu=\mu(1+\varphi)\) | \(\mu/(1+\varphi)\) |
| NB2 | \(\mu+\mu^2/\theta\) | \(\mu\theta/(\theta+\mu)\) |

A Jeffreys-shaped fixed-effect atom on the *maximised* log-likelihood
scale for **this** family is therefore

\[
P^*_{\mathrm{J,NB1}}=\tfrac12\log\det\bigl(X_*^\top W_{\mathrm{NB1}}(\mu,\varphi)\,X_*\bigr),
\qquad
W_{\mathrm{NB1}}=\operatorname{diag}\bigl(\mu/(1+\varphi)\bigr).
\]

TMB minimises negative log-likelihood, so a later tape would add
\(-c\,P^*_{\mathrm{J,NB1}}\) together with any loading or
**dispersion** atoms that earn their own coercivity proofs. The soft
rate \(c\) is **not** pinned here. Bernoulli
\(c_n=2\sqrt{p_{\mathrm{free}}/N_{\mathrm{eff}}}\), Gaussian
\(c_N=\sqrt{2/N}\), and any Poisson rate left OPEN in the Poisson
note are all rejected transplants (kill list §5).

When \(\varphi\) is **shared** across the stacked rows of \(X_*\),

\[
I_{\mathrm{NB1}}(\beta_*)=\frac{I_{\mathrm{Poisson}}(\beta_*)}{1+\varphi},
\qquad
P^*_{\mathrm{J,NB1}}=P^*_{\mathrm{J,Pois}}-\frac{p_*}{2}\log(1+\varphi).
\]

That identity is an oracle pin (N3). It is **not** a license to
drop the \(\varphi\) term and reuse the Poisson atom.

| Criterion | Atom | Parameters | TMB-shaped expression on paper | Interpretation |
|---|---|---|---|---|
| NB1 Jeffreys-shaped \(P^*_{\mathrm{J,NB1}}\) | \(\tfrac12\log\det(X_*^\top\operatorname{diag}(\mu/(1+\varphi))X_*)\) | free \(\beta_*\); \(\mu=\exp(\eta)\) (× exposure if offset); \(\varphi>0\) | \(\mathrm{nll}\mathrel{+}=-c\,P^*_{\mathrm{J,NB1}}\) | Softens \(\beta\to-\infty\) / \(\mu\to 0\) **and** feels \(\varphi\to\infty\) through \(W\). \(\beta\)- and \(\varphi\)-dependent. |
| Information size | \(\operatorname{tr}(W)=\sum\mu/(1+\varphi)\) or \(\lambda_{\min}(I_{\mathrm{NB1}})\) | \(\mu,\varphi\) | diagnostic only | **Not** \(\sum\mu\) (Poisson), **not** \(\sum\mu\theta/(\theta+\mu)\) (NB2), **not** the row count. |
| Dispersion \(\varphi\to 0\) | nested Poisson limit of \(W\), **not** a mean-boundary atom | \(\varphi\) at fixed \(\mu>0\) | OPEN; no tape | \(W\to\mu\), \(P^*_{\mathrm{J,NB1}}\to P^*_{\mathrm{J,Pois}}\) from below. Does **not** send \(P^*_{\mathrm{J}}\) to \(-\infty\). |
| Dispersion \(\varphi\to\infty\) | same \(W=\mu/(1+\varphi)\) collapses | \(\varphi\) at fixed \(\mu>0\) | consequence of the mean atom; dedicated \(\varphi\) atom OPEN | Information collapse from overdispersion, distinct from \(\mu\to 0\). |
| Contrast: Poisson \(W=\operatorname{diag}(\mu)\) | \(\tfrac12\log\det(X_*^\top\operatorname{diag}(\mu)X_*)\) | \(\mu\) only | Poisson Phase-4 candidate | Equals NB1 only at \(\varphi=0\). Oracle kill as a transplant. |
| Contrast: NB2 \(W=\operatorname{diag}(\mu\theta/(\theta+\mu))\) | \(\tfrac12\log\det(X_*^\top\operatorname{diag}(\mu\theta/(\theta+\mu))X_*)\) | \(\mu,\theta\) | not this cell | Quadratic-mean information. Setting \(\theta=1/\varphi\) does **not** recover NB1 unless \(\mu=1\). |
| Contrast: Bernoulli \(V_{\mathrm{loading}}\) | \(\sum_t(\sqrt{1+\|\lambda_t\|^2}-1)\) | \(\Lambda\) only | live `gll_mspl_row_radial_penalty` | Binary link-scale runaway atom. No NB1 coercivity proof. |
| Contrast: Gaussian Hirose | \(\sum_j S_{jj}/\psi_j\) | diagonal \(\Psi\) | Phase 3 planned tape object | Heywood unique-variance atom. NB1 \(\varphi\) is not \(\psi\). |

Existence / coercivity sketch used as the oracle contract (fixed-design
slice first; latent loadings and a dedicated \(\varphi\) atom deferred):

- **N-P1** \(P^*_{\mathrm{J,NB1}}\) is continuous for \(\mu>0\),
  \(\varphi>0\), and full-rank \(X_*\).
- **N-P2 (mean boundary).** Along an all-zero or near-zero path with
  \(\mu_t\to 0\) at **fixed** \(\varphi>0\), \(W\to 0\) and
  \(P^*_{\mathrm{J,NB1}}\to-\infty\) whenever \(X_*\) has a column
  that is active on those rows.
- **N-P3 (dispersion \(\to 0\)).** At fixed \(\mu>0\),
  \(\varphi\to 0^+\) sends \(W\to\operatorname{diag}(\mu)\) and
  \(P^*_{\mathrm{J,NB1}}\uparrow P^*_{\mathrm{J,Pois}}\). This is a
  nested-family limit, not a mean-boundary, and **not** a reason to
  inherit a Poisson MSPL tape.
- **N-P4 (dispersion \(\to\infty\)).** At fixed \(\mu>0\),
  \(\varphi\to\infty\) sends \(W\to 0\) and
  \(P^*_{\mathrm{J,NB1}}\to-\infty\). Same qualitative divergence as
  N-P2, **different coordinate**. A dedicated \(\varphi\) atom (Jeffreys
  in \(\varphi\), barrier, or otherwise) is **OPEN**. Using the mean
  atom as a \(\varphi\to 0\) repair is a type error: that path
  *increases* \(P^*_{\mathrm{J}}\).
- **N-P5** The conditional NB1 log-pmf is bounded above for fixed
  \(y\) (size \(\mu/\varphi\), success probability
  \(\varphi/(1+\varphi)\) is \(\mu\)-free). Combined with N-P2, a soft
  \(+c P^*_{\mathrm{J,NB1}}\) term (maximisation scale) pulls away
  from the infinite-\(|\beta|\) all-zero MLE path in the same
  *qualitative* way Poisson Jeffreys does — **AGENT-INFERRED**
  analogy, not a transferred theorem.
- **N-P6** Exposure enters only through \(\mu=E\circ e^{\eta}\).
  Doubling every \(E\) at fixed \(\eta_{\mathrm{free}}\) and fixed
  \(\varphi\) doubles \(\mu\) and doubles \(I(\beta_*)\). Information
  size is \(\sum\mu/(1+\varphi)\), not \(\sum\mu\) and not
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
\(\beta_t\to-\infty\) on an intercept-only trait design). Fisher
weights on those rows vanish as \(\mu/(1+\varphi)\). Any soft
penalty whose fixed-effect atom is
\(\tfrac12\log\det(X_*^\top W_{\mathrm{NB1}} X_*)\) therefore
diverges to \(-\infty\) on that path when the trait’s design columns
remain in \(X_*\) (oracle N4). Finiteness of a penalised fit on
all-zero data is necessary and **not** sufficient for admission
(programme §16).

Sparse but non-zero counts keep \(\mu\) small on most units.
Information remains \(O(\sum\mu/(1+\varphi))\), so the same atom is
soft rather than hard (oracle N5).

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

At fixed \(\mu>0\), \(W=\mu/(1+\varphi)\to 0\). Mean information
vanishes because every count is infinitely noisy, not because the
mean hit the boundary. Oracle N7 checks this path separately from
N4. The mean atom is consequentially coercive here; that does
**not** close a \(\varphi\)-atom derivation.

### Loading runaway (named, not solved)

On \(\log\mu=\eta_{\mathrm{fix}}+\lambda^\top u\), large
\(\|\lambda\|\) can send some units’ means to \(+\infty\) and others
toward \(0\). That is a *different* boundary from \(\varphi\to 0\),
\(\varphi\to\infty\), Gaussian \(\psi\to 0\), and Bernoulli
separation. **No NB1 loading atom is admitted in this note.**

## 3. Why Poisson and NB2 do not transfer

### Poisson \(W=\operatorname{diag}(\mu)\)

Equals \(W_{\mathrm{NB1}}\) if and only if \(\varphi=0\). At any
interior \(\varphi>0\) the information matrices differ by the
exact factor \(1/(1+\varphi)\) when \(\varphi\) is shared (oracle
N3). Reusing the Poisson atom silently drops that factor and
mis-scales every later rate comparison. The Poisson note itself
forbids NB1/NB2 inheritance.

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

1. **Weights.** NB1 \(W=\mu/(1+\varphi)\) is not \(\mu\), not
   \(\mu(1-\mu)\), and not a probit/cloglog weight.
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
\(\mu=E\circ\exp(\eta^{\mathrm{free}})\) and
\(W=\mu/(1+\varphi)\).

| Quantity | What it is | What it is not |
|---|---|---|
| Exposure \(E\) | Known mean multiplier / offset | Sample size; penalty rate \(c\); \(N_{\mathrm{eff}}\) |
| Row count \(N_{\mathrm{rows}}\) | Number of stacked \((i,t)\) observations | NB1 information |
| Poisson information size \(\sum\mu\) | Poisson weights | NB1 information unless \(\varphi=0\) |
| NB1 information size | \(X_*^\top\operatorname{diag}(\mu/(1+\varphi))X_*\) and \(\sum\mu/(1+\varphi)\) | \(\sum E\), \(\sum\mu\), or Bernoulli \(N_{\mathrm{eff}}\) |

Oracle N9: at fixed free \(\eta\) and fixed \(\varphi\), replacing
\(E\) by \(2E\) doubles \(\mu\), doubles \(W\), and doubles
\(I(\beta_*)\), while \(N_{\mathrm{rows}}\) is unchanged. Oracle
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
    \(\sum\mu/(1+\varphi)\).
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
| N2 | \(W_{\mathrm{NB1}}=\mu/(1+\varphi)\); not Poisson \(\mu\); not NB2 \(\mu\theta/(\theta+\mu)\) | same |
| N3 | \(P^*_{\mathrm{J,NB1}}\) uses \(W_{\mathrm{NB1}}\); shared-\(\varphi\) identity \(P^*_{\mathrm{J,Pois}}-(p_*/2)\log(1+\varphi)\) | \(<10^{-12}\); Poisson/NB2 substitutions differ |
| N4 | Mean-boundary: \(\beta\to-\infty\Rightarrow\mu\to 0\Rightarrow P^*_{\mathrm{J,NB1}}\to-\infty\) at fixed \(\varphi>0\) | monotone decrease; large negative |
| N5 | Near-zero: scale \(\mu\leftarrow\varepsilon\mu_0\) at fixed \(\varphi\) deteriorates \(P^*_{\mathrm{J,NB1}}\) | monotone in \(\varepsilon\downarrow 0\) |
| N6 | \(\varphi\to 0\) at fixed \(\mu\): \(W\to W_{\mathrm{Pois}}\); \(P^*_{\mathrm{J}}\) **increases** toward Poisson; does **not** go to \(-\infty\) | monotone increase; contrast with N4 |
| N7 | \(\varphi\to\infty\) at fixed \(\mu>0\): \(P^*_{\mathrm{J,NB1}}\to-\infty\) | monotone decrease; large negative |
| N8 | \(\theta=1/\varphi\) does **not** equate \(V\) or \(W\) unless \(\mu=1\) | contrast fires on the fixture |
| N9 | Exposure doubling at fixed \(\eta,\varphi\) doubles \(I\) and \(\sum\mu/(1+\varphi)\); \(N_{\mathrm{rows}}\) fixed; \(\sum\mu/(1+\varphi)\neq\sum\mu\) | exact factor 2 |
| N10 | Offset spelling: \(o=\log E\) vs folding \(\log E\) into \(\eta\) leaves \(\mu\) and \(I\) identical | \(<10^{-12}\) |
| N11 | Hirose \(\sum S/\psi\) refused (\(\varphi\) is not \(\psi\)); \(V_{\mathrm{loading}}\) is \(\mu\)- and \(\varphi\)-inert | structural reject + finite-diff |
| N12 | NB1 size \(\mu/\varphi\) depends on \(\mu\); NB2 size \(\theta\) does not; \(\log(V-\mu)\) matches the TMB comments | \(<10^{-12}\) |
| N13 | No live nbinom1 MSPL call; nbinom1 is not `admitted` and has no `planned` registry row | structural |

## 6. Verdict

| Surface | Verdict | Why |
|---|---|---|
| Local R oracles / this writeup (N1–N13, kill list) | **PASS** | Variance/weight triple, three named boundaries, and exposure≠information are testable without an NB1 MSPL fit. |
| C++ tape / live nbinom1 MSPL / registry `planned` or `admitted` | **FAIL** | No tape, no prepare widening, no registry row, no Shinichi admission gate. |
| NEWS / covered / SE / intervals | **FAIL** | Out of scope; SE remains PROTECTED on Codex Lane B. |

Preferred later-admission *candidate* for the fixed-effect slice:
NB1 Jeffreys-shaped
\(\tfrac12\log\det(X_*^\top\operatorname{diag}(\mu/(1+\varphi))X_*)\),
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
   be \(\sum\mu/(1+\varphi)\), not Poisson \(\sum\mu\).
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
