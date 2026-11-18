# Phase 4 prep — nbinom2 (log) LA-MSPL route (not admitted)

**Status:** design + local oracles only. The registry still carries
`nbinom2:log:ordinary:q1:nbinom2` as **`excluded`** (`evidence =
"fence"`, note *“NB2 waits for Phase 4 after Poisson admission
gate”*). There is **no** `planned` nbinom2 row. Bare lookup of
`nbinom2:log:ordinary:q1` returns `NULL`.
`.gllvmTMB_mspl_prepare()` still rejects every family outside
`family_id %in% {0L, 1L}` (nbinom2 is `family_id = 5L`). **Verdict:
PASS for oracles / excluded fence, FAIL for C++ / planned-row
promotion / admission / `estimator = "mspl"` on nbinom2.**

**Reader:** statistical method developer / TMB engineer who must
decide whether a later tape may add an NB2 count-and-dispersion
atom — and who must not treat Poisson Phase-4 prep as a licence.

**Programme constitution:**
`docs/dev-log/after-task/2026-08-14-laplace-mspl-estimator-programme.md`
§Phase 4 — *Negative binomial next: separate mean-boundary penalties
from dispersion \(0\) or \(\infty\) boundaries. NB1 and NB2 do not
inherit each other's scale or theorem.*

This is **LA-MSPL** (Laplace + a soft *outer* penalty), not EVA/VA,
not AGHQ-MSPL. There is **no** verified third-party theorem that
transfers Bernoulli Jeffreys/`V_loading`, Gaussian Hirose \(\Psi\),
or the Poisson \(W=\operatorname{diag}(\mu)\) atom to an NB2 GLLVM
under Laplace (programme §7; Ranga corpus). Every formula below that
is not textbook NB2 GLM / TMB information is **AGENT-INFERRED** and
exists to pin oracles, not to license a tape.

## Why this is a new family cell

Poisson Phase-4 prep derived a one-parameter mean-boundary atom
\(W=\operatorname{diag}(\mu)\). NB2 is not “Poisson plus a
dispersion knob on the same atom.” The observation variance is

\[
\operatorname{Var}(y)=\mu+\mu^2/\phi,
\]

so the GLM weight on the log link is \(\mu\phi/(\phi+\mu)\), not
\(\mu\). A free size \(\phi\) adds two further boundaries
(\(\phi\to 0\) and \(\phi\to\infty\)) that Poisson does not have.
The Poisson note’s kill list already forbids “Poisson worked, so NB
does.” This note derives the NB2 objects from the TMB likelihood.

Programme lock: ordinary nbinom2,
\(\log\mu_{it}=x_{it}^\top\beta+\lambda_t^\top u_i\) (optional known
offset), per-trait `log_phi_nbinom2`, soft outer penalty derived for
*this* likelihood, separately. Do not transplant Poisson Jeffreys,
Bernoulli, or Gaussian atoms by convenience.

## Parameterisation (TMB is authoritative)

Aligned with `src/gllvmTMB.cpp` (`family_id == 5`,
`log_phi_nbinom2`) and `docs/design/03-likelihoods.md`:

| Symbol | Meaning | Package coordinate |
|---|---|---|
| \(\mu\) | mean | \(\mu=E\circ\exp(\eta)\) on the log link |
| \(\phi\) | NB2 size | \(\phi=\exp(\texttt{log\_phi\_nbinom2})\) |
| \(\sigma\) | public overdispersion | \(\phi=\theta=1/\sigma^2\); larger \(\sigma\) ⇒ more quadratic OD |
| \(V(\mu)\) | variance function | \(\mu+\mu^2/\phi\) |
| Poisson limit | \(\phi\to\infty\) | \(V\to\mu\); TMB comment at the `log_phi_nbinom2` block |
| Infinite OD | \(\phi\to 0^+\) | \(V/\mu\to\infty\); **not** the NB1 Poisson limit |

NB1 uses \(V=\mu(1+\phi)\) and recovers Poisson as \(\phi\to 0\),
the opposite end of its own scale. That cell is out of scope.

Oracles and algebra below are written in \((\mu,\phi)\) to match the
tape coordinate. A later penalty written in \(\log\phi\) or public
\(\sigma\) must carry the Jacobian; taping \(\tfrac12\log I_{\phi\phi}\)
on `log_phi_nbinom2` without \(I_{\log\phi}=\phi^2 I_{\phi\phi}\) is a
kill.

## 1. Five-row symbolic alignment

Textbook GLM expected information for free fixed coordinates
\(\beta_*\) at *known* \(\phi\), log link, variance \(V(\mu)\):

\[
I(\beta_*)=X_*^\top W(\mu,\phi)\,X_*,\qquad
W_{ii}=\frac{(\mathrm{d}\mu_i/\mathrm{d}\eta_i)^2}{V(\mu_i)}
=\frac{\mu_i\phi}{\phi+\mu_i}.
\]

Poisson is the special case \(\phi\to\infty\), \(W\to\operatorname{diag}(\mu)\).
At finite \(\phi\),

\[
\frac{W_{\mathrm{NB2}}}{W_{\mathrm{Pois}}}
=\frac{\phi}{\phi+\mu}<1.
\]

A Jeffreys-shaped *mean* atom on the maximised log-likelihood scale
is therefore

\[
P^*_{\mathrm{J},\mu}
=\tfrac12\log\det\bigl(X_*^\top W(\mu,\phi)\,X_*\bigr),
\]

which is **not** the Poisson atom
\(\tfrac12\log\det(X_*^\top\operatorname{diag}(\mu)X_*)\). Same
Jeffreys *template*, different information matrix.

NB2 expected information is block-diagonal in \((\beta,\phi)\):
\(I_{\beta\phi}=0\) (the mean score is \((y-\mu)\,\phi/(\phi+\mu)\);
its \(\phi\)-derivative has factor \(y-\mu\) and expectation zero).
Observed cross-information is not zero. Jeffreys
\(\lvert I\rvert^{1/2}\) factors as
\(\lvert I_{\beta\beta}\rvert^{1/2}\,I_{\phi\phi}^{1/2}\) **in
expectation only**.

Per-row expected information for the size (Lawless-type; pinned by
score variance in the oracles) is

\[
I_{\phi\phi}(\mu,\phi)
=\psi'(\phi)-\mathbb{E}\bigl[\psi'(\phi+Y)\bigr]
+\frac{1}{\phi+\mu}-\frac{1}{\phi}
=\operatorname{Var}\bigl(\psi(Y+\phi)-Y/(\phi+\mu)\bigr),
\]

with \(Y\sim\mathrm{NB2}(\mu,\phi)\) (`stats::dnbinom(mu=, size=φ)`).
A Jeffreys-shaped *dispersion* atom would be
\(P^*_{\mathrm{J},\phi}=\tfrac12\log I_{\phi\phi}^{\mathrm{tot}}\)
(\(I_{\phi\phi}^{\mathrm{tot}}=\sum_i I_{\phi\phi}(\mu_i,\phi)\) on a
shared per-trait size). That atom is a **separate scientific
object** from \(P^*_{\mathrm{J},\mu}\). In particular, \(I_{\phi\phi}\to 0\)
as \(\phi\to\infty\), so \(P^*_{\mathrm{J},\phi}\to-\infty\) *fights
the Poisson limit* if it is switched on. Whether a later tape wants
that is OPEN and must not be smuggled in as “the NB2 Jeffreys
atom.”

The quasi / moment stand-in
\(I_{\phi\phi}^{\mathrm{quasi}}=\tfrac12\bigl(\mu/(\mu+\phi)\bigr)^2\)
is **not** the likelihood information (different \(\phi\to\infty\)
rate). Using it as \(P^*_{\mathrm{J},\phi}\) is a kill.

TMB minimises negative log-likelihood, so a later tape would add
\(-c\,P^*\) on whichever atoms earn coercivity proofs. The soft rate
\(c\) is **not** pinned: Bernoulli
\(c_n=2\sqrt{p_{\mathrm{free}}/N_{\mathrm{eff}}}\), Gaussian
\(c_N=\sqrt{2/N}\), and any Poisson rate copied from the sibling
prep are rejected transplants (kill list).

| Criterion | Atom | Parameters | TMB-shaped expression on paper | Interpretation |
|---|---|---|---|---|
| NB2 mean Jeffreys-shaped \(P^*_{\mathrm{J},\mu}\) | \(\tfrac12\log\det(X_*^\top W X_*)\), \(W=\operatorname{diag}(\mu\phi/(\phi+\mu))\) | free \(\beta_*\); \(\phi>0\); \(\mu=E\circ\exp(\eta)\) | \(\mathrm{nll}\mathrel{+}=-c\,P^*_{\mathrm{J},\mu}\) | Softens paths where mean information vanishes: \(\mu\to 0\) *or* \(\phi\to 0\). \(\beta\)- and \(\phi\)-dependent. |
| NB2 size information \(I_{\phi\phi}\) | \(\psi'(\phi)-\mathbb{E}\psi'(\phi+Y)+1/(\phi+\mu)-1/\phi\) | per-trait \(\phi\) | diagnostic; optional \(\tfrac12\log I_{\phi\phi}\) is a *different* atom | Identifies \(\phi\) only when \(\mu\) is not tiny and \(\phi\) is not huge. Jeffreys-on-\(\phi\) fights \(\phi\to\infty\). |
| Information size | \(\operatorname{tr}(W)\), \(\lambda_{\min}(X_*^\top W X_*)\), \(I_{\phi\phi}\) | \(\mu,\phi\) | diagnostic only | Not row count, not \(\sum E\), and not Poisson \(\sum\mu\). |
| Exposure / offset | \(o=\log E\), \(\mu=E\circ\exp(\eta_{\mathrm{free}})\) | known \(E>0\) | offset vector; live Design 88 still requires all-zero offset on the binary surface | Exposure rescales the *mean*; \(W(\mu,\phi)\) is nonlinear in \(E\). Not a Poisson doubling knob and not \(N_{\mathrm{eff}}\). |
| Forbidden transplants | Poisson \(W=\operatorname{diag}(\mu)\); Bernoulli \(V_{\mathrm{loading}}\); Hirose \(\sum S_{jj}/\psi_j\) | — | oracle kills E1 / E6 / E7 | Wrong variance, wrong boundary object, or no \(\Psi\) in this cell. |

Existence / coercivity sketch used as the oracle contract
(fixed-design slice first; latent loadings deferred):

- **N1** \(P^*_{\mathrm{J},\mu}\) is continuous for \(\mu>0\),
  \(\phi>0\), and full-rank \(X_*\).
- **N2** Along an all-zero or near-zero path with \(\mu_t\to 0\)
  uniformly on a trait (or intercept \(\beta\to-\infty\)),
  \(W\to 0\) and \(P^*_{\mathrm{J},\mu}\to-\infty\) whenever \(X_*\)
  has a column active on those rows. Leading weight is
  \(W=\mu\cdot\phi/(\phi+\mu)=\mu+O(\mu^2/\phi)\); the \(O(\mu)\)
  term matching Poisson is **not** a theorem transfer (oracle E1
  still fires at every finite \(\mu\)).
- **N3** Along \(\phi\to 0^+\) at fixed \(\mu>0\), \(W\to 0\) and
  \(P^*_{\mathrm{J},\mu}\to-\infty\): infinite overdispersion
  erases mean information. This is a *dispersion* boundary, not
  all-zero and not Heywood.
- **N4** Along \(\phi\to\infty\), \(W\to\operatorname{diag}(\mu)\)
  and \(I_{\phi\phi}\to 0\). The mean atom *approaches* the Poisson
  atom as a limit of the weight. The size atom, if used, diverges
  to \(-\infty\) and pulls *away* from Poisson. These must not be
  collapsed into one “NB2 Jeffreys” slogan.
- **N5** The conditional NB2 log-pmf is bounded above for fixed
  \(y\). Combined with N2–N3, a soft \(+c P^*_{\mathrm{J},\mu}\)
  term (maximisation scale) pulls away from infinite-\(|\beta|\)
  and infinite-OD mean-info collapse in the same *qualitative* way
  Bernoulli Jeffreys pulls away from separation —
  **AGENT-INFERRED** analogy, not a transferred theorem.
- **N6** Exposure enters only through \(\mu=E\circ e^{\eta}\).
  Doubling every \(E\) at fixed \(\eta_{\mathrm{free}}\) and
  \(\phi\) does **not** double \(I(\beta_*)\) (oracle E4). Using
  Poisson “\(\times 2\)” or Bernoulli \(N_{\mathrm{eff}}=\#\{\text{rows}\}\)
  as the rate denominator mis-scales NB2 designs.

Latent loading coercivity under Laplace is **OPEN**. The Bernoulli
radial atom and the Poisson mean atom are listed only as forbidden
transplants, not as candidates. The mean-model atom in this note is
**fixed-only / conditional** GLM information, evaluated at
\(\eta=X_{\mathrm{fix}}b_{\mathrm{fix}}+\mathrm{offset}\) before any
latent-score contribution — the same convention the live tape
records at `src/gllvmTMB.cpp` ("before any latent-score
contribution"). Laplace-marginal information for \(\beta\) is a
different object and remains **OPEN**. These oracles do not compute
it.

## 2. Low-mean and dispersion boundary mechanisms

### All-zero / low-mean trait

For a trait with \(y_{\cdot t}\equiv 0\), the NB2 log-pmf still
drives \(\mu_{\cdot t}\to 0\) (\(\beta_t\to-\infty\) on an
intercept-only trait). Fisher weights vanish:

\[
W=\frac{\mu\phi}{\phi+\mu}\to 0.
\]

Any soft mean atom \(\tfrac12\log\det(X_*^\top W X_*)\) therefore
diverges to \(-\infty\) on that path when the trait’s design
columns remain in \(X_*\) (oracle E2). At the same time
\(I_{\phi\phi}\to 0\): all-zero data do not identify size. A
dispersion atom cannot repair an all-zero mean path, and a
Poisson \(W=\operatorname{diag}(\mu)\) atom is the wrong number at
every finite \(\phi\) even though both atoms go to \(-\infty\).

Finiteness of a penalised fit on all-zero data is necessary and
**not** sufficient for admission (programme §16).

Sparse but non-zero counts keep \(\mu\) small on most units.
Information remains \(O(\operatorname{tr}(W))\), so the mean atom
is soft rather than hard (oracle E3a).

### Dispersion \(\phi\to 0^+\) (infinite overdispersion)

At fixed \(\mu>0\), \(V=\mu+\mu^2/\phi\) explodes and
\(W=\mu\phi/(\phi+\mu)\to 0\). The mean score factor
\(\phi/(\phi+\mu)\) vanishes: the data stop informing \(\beta\).
This is **not** Poisson all-zero (means may be order-1), **not**
Bernoulli separation, and **not** Gaussian \(\psi\to 0\). Oracle
E3b checks that \(P^*_{\mathrm{J},\mu}\) deteriorates as
\(\phi\downarrow 0\).

### Dispersion \(\phi\to\infty\) (Poisson limit)

\(W\to\operatorname{diag}(\mu)\) and \(I_{\phi\phi}\to 0\). Size is
unidentified because the extra variance \(\mu^2/\phi\) has gone.
Two failure modes for a later derivation:

1. Treating the weight limit as permission to *tape the Poisson
   atom* at finite \(\phi\) (oracle E1).
2. Switching on \(P^*_{\mathrm{J},\phi}\) without noticing it
   penalises the Poisson limit itself (N4).

Neither is decided here. Both are named so they cannot happen
quietly.

### Loading runaway (named, not solved)

On \(\log\mu=\eta_{\mathrm{fix}}+\lambda^\top u\), large
\(\|\lambda\|\) can send some units’ means to \(+\infty\) and
others toward \(0\). That is a different boundary from
\(\phi\to 0\), from Gaussian \(\psi\to 0\), and from Bernoulli
separation. Design 88’s \(V_{\mathrm{loading}}\) was built for the
binary link-scale runaway. **No NB2 loading atom is admitted in
this note.** Oracle E7 only shows that transplanting
\(V_{\mathrm{loading}}\) is inert in both \(\mu\) and \(\phi\).

## 3. Exposure / offset versus information size

Write

\[
\log\mu_{it}=o_{it}+\eta_{it}^{\mathrm{free}},\qquad o_{it}=\log E_{it},
\]

with known \(E_{it}>0\). Then \(\mu=E\circ\exp(\eta^{\mathrm{free}})\)
and \(W_i=\mu_i\phi/(\phi+\mu_i)\).

| Quantity | What it is | What it is not |
|---|---|---|
| Exposure \(E\) | Known mean multiplier / offset | Sample size; penalty rate \(c\); \(N_{\mathrm{eff}}\); a factor-2 information knob |
| Row count \(N_{\mathrm{rows}}\) | Number of stacked \((i,t)\) observations | NB2 information |
| Poisson information size \(\sum\mu\) | The \(\phi\to\infty\) limit of \(\operatorname{tr}(W)\) | The NB2 information at finite \(\phi\) |
| NB2 information size | \(X_*^\top W(\mu,\phi)X_*\) and \(I_{\phi\phi}\) | \(\sum E\), \(\sum\mu\), or Bernoulli \(N_{\mathrm{eff}}\) |

Oracle E4: at fixed free \(\eta\) and \(\phi\), replacing \(E\) by
\(2E\) doubles \(\mu\) but multiplies each weight by

\[
\frac{W(2\mu,\phi)}{W(\mu,\phi)}
=\frac{2(\phi+\mu)}{\phi+2\mu}\in(1,2).
\]

Information increases, strictly less than the Poisson doubling.
\(N_{\mathrm{rows}}\) is unchanged. Oracle E5: absorbing
\(\log E\) into the offset leaves \(\mu\) (hence \(W\) and \(I\))
unchanged when \(\eta^{\mathrm{free}}\) is reduced by \(\log E\).

Live Design 88 still fences *nonzero* offsets on the Bernoulli
MSPL surface. This prep cell records the exposure algebra for a
*future* NB2 route; it does not ask the prepare fence to accept
offsets, and it does not inherit Poisson’s factor-2 identity.

## 4. Why the Poisson Jeffreys atom does not transfer

The sibling note
`docs/dev-log/research/2026-08-15-mspl-phase4-poisson-prep.md`
proposes, as a *Poisson* candidate,

\[
P^*_{\mathrm{J,Pois}}
=\tfrac12\log\det\bigl(X_*^\top\operatorname{diag}(\mu)X_*\bigr).
\]

Three transfer failures on NB2:

1. **Weights.** \(W_{\mathrm{NB2}}=\operatorname{diag}(\mu\phi/(\phi+\mu))\)
   is not \(\operatorname{diag}(\mu)\). Reusing the Poisson Gram
   matrix overstates information by \((\phi+\mu)/\phi=1+\mu/\phi\)
   (oracle E1).
2. **Missing parameter.** Poisson has no \(\phi\). NB2’s
   \(\phi\to 0\) and \(\phi\to\infty\) boundaries are invisible to
   \(P^*_{\mathrm{J,Pois}}\).
3. **Limit is not inheritance.** \(W_{\mathrm{NB2}}\to W_{\mathrm{Pois}}\)
   as \(\phi\to\infty\) is a continuous limit of *this* family’s
   weight, not a licence to tape the Poisson atom, reuse a Poisson
   rate, or skip a Poisson admission gate. The registry note
   already says NB2 waits for that gate.

Do not keep the Poisson atom “for continuity with Phase 4.”

## 5. Why Bernoulli Jeffreys / \(V_{\mathrm{loading}}\) do not transfer

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

Three transfer failures:

1. **Weights.** NB2 \(W=\mu\phi/(\phi+\mu)\) is not \(\mu(1-\mu)\)
   and not a probit/cloglog weight (oracle E1).
2. **Boundary object.** Bernoulli Jeffreys repairs *separation*.
   NB2 repairs (if anything) low-mean information collapse and
   named \(\phi\) boundaries. The loading geometry on the log-mean
   scale is unproved.
3. **\(V_{\mathrm{loading}}\) is \((\mu,\phi)\)-inert.**
   \(\partial V_{\mathrm{loading}}/\partial\mu\equiv 0\) and
   \(\partial V_{\mathrm{loading}}/\partial\phi\equiv 0\) (oracle
   E7). It cannot supply the all-zero or infinite-OD information
   divergence.

Do not keep Bernoulli atoms “for symmetry with Design 88.”

## 6. Why Gaussian Hirose \(\Psi\) does not transfer

Phase 3 targets Heywood \(\psi_j\to 0\) in
\(\Sigma=\Lambda\Lambda^\top+\Psi\) with Hirose
\(V_H=\sum_j S_{jj}/\psi_j\). Ordinary nbinom2 rows in this prep
cell are count means plus a size \(\phi\). They do not carry a free
Gaussian unique-variance coordinate. A \(1/\psi\) atom has no
object. Oracle E6 refuses Hirose-on-NB2 as a type error:
fabricating \(\psi=1/\phi\) or \(\psi=1/\mu\) silently renames
either the size or the mean-information problem without a proof.
\(\phi\to 0\) is infinite overdispersion, not a Heywood collapse of
\(\Psi\).

## 6a. Why NB1 does not transfer

NB1 variance is \(\mu(1+\phi)\) with Poisson recovered at
\(\phi\to 0\). NB2 recovers Poisson at \(\phi\to\infty\). The GLM
weight, the size information, and both dispersion boundaries
differ. Programme lock: NB1 and NB2 do not inherit each other’s
scale or theorem. This note does not derive an NB1 atom.

## 7. Kill list — fail the later derivation on any of these

1. Transplant of the Poisson Jeffreys atom
   \(W=\operatorname{diag}(\mu)\) at finite \(\phi\), or treating
   \(\phi\to\infty\) as permission to tape that atom.
2. Transplant of Bernoulli \(V_{\mathrm{loading}}\) without an NB2
   Laplace coercivity proof.
3. Transplant of Bernoulli Jeffreys weights \(W_g\) (logit / probit
   / cloglog) in place of \(W=\operatorname{diag}(\mu\phi/(\phi+\mu))\).
4. Transplant of Gaussian Hirose / Akaike \(\Psi\) atoms, or any
   \(1/\psi\) term, including \(\psi:=1/\phi\) or \(\psi:=1/\mu\).
5. Reuse of Bernoulli \(c_n\), Gaussian \(c_N\), or a Poisson rate
   without an NB2 rate argument against the Laplace objective.
6. Treating exposure \(\sum E\), row count, or Poisson
   \(\sum\mu\) as interchangeable with
   \(\operatorname{tr}(W(\mu,\phi))\).
7. Assuming exposure doubling doubles \(I(\beta_*)\) (true for
   Poisson, false for NB2).
8. Using \(I_{\phi\phi}^{\mathrm{quasi}}=\tfrac12(\mu/(\mu+\phi))^2\)
   as the likelihood size information.
9. Taping \(\tfrac12\log I_{\phi\phi}\) on `log_phi_nbinom2`
   without the Jacobian \(I_{\log\phi}=\phi^2 I_{\phi\phi}\).
10. Collapsing \(P^*_{\mathrm{J},\mu}\) and \(P^*_{\mathrm{J},\phi}\)
    into one “NB2 Jeffreys” atom, or switching on the size atom
    without stating that it fights \(\phi\to\infty\).
11. Claiming Design 88, Sterzinger–Kosmidis–Moustaki 2026, or the
    Poisson Phase-4 note covers NB2 GLLVM MSPL under Laplace.
12. Finiteness of a count fit offered as the scientific result.
13. NB1 inheritance, mixed-family inheritance, or “Poisson planned,
    so NB2 planned.”
14. Nonzero-offset admission smuggled in under “exposure.”
15. Any admission-shaped language (status flip to `planned` or
    `admitted`, NEWS covered, validation-register promotion, C++
    tape) ahead of the Shinichi gate. This prep does **not** add
    planned registry rows.
16. Live `gllvmTMB(..., estimator = "mspl")` on nbinom2 in tests.
17. Quietly widening `.gllvmTMB_mspl_prepare()` beyond
    `family_id %in% {0,1}`.

## 8. Oracle contract E1–E7 (pure R; no nbinom2 `estimator="mspl"`)

| ID | What | Tolerance / decision |
|---|---|---|
| E1 | NB2 \(I_{\beta\beta}=X^\top\operatorname{diag}(\mu\phi/(\phi+\mu))X\); Poisson \(W=\mu\) and Bernoulli \(W_g=\mu(1-\mu)\) **differ**; \(\phi\to\infty\) weight limit is a limit, not inheritance; \(I_{\log\phi}=\phi^2 I_{\phi\phi}\); \(I_{\phi\phi}\) matches score variance and is not the quasi stand-in | rel. err \(<10^{-12}\) on the Gram identity; contrasts fire; \(I_{\phi\phi}\) vs Var(score) \(<10^{-8}\) |
| E2 | All-zero path: \(\beta\to-\infty\Rightarrow\mu\to 0\Rightarrow P^*_{\mathrm{J},\mu}\to-\infty\); \(I_{\phi\phi}\) shrinks | monotone decrease; large negative; \(I_{\phi\phi}\) at tiny \(\mu\) \(\ll\) fixture |
| E3 | Near-zero \(\mu\leftarrow\varepsilon\mu_0\) deteriorates \(P^*_{\mathrm{J},\mu}\); \(\phi\downarrow 0\) also deteriorates \(P^*_{\mathrm{J},\mu}\); \(\phi\uparrow\infty\) sends \(I_{\phi\phi}\downarrow 0\) and \(W\to\mu\) | monotone in each grid |
| E4 | Exposure doubling at fixed \(\eta,\phi\) multiplies weights by \(2(\phi+\mu)/(\phi+2\mu)\in(1,2)\), **not** 2; \(N_{\mathrm{rows}}\) fixed | exact algebraic factor; reject Poisson doubling |
| E5 | Offset spelling: \(o=\log E\) vs folding \(\log E\) into \(\eta\) leaves \(\mu\), \(W\), and \(I\) identical | \(<10^{-12}\) |
| E6 | Hirose \(\sum S/\psi\) is undefined / refused; Poisson \(P^*_{\mathrm{J,Pois}}\) **differs** at finite \(\phi\) | structural reject + numerical contrast |
| E7 | \(\partial V_{\mathrm{loading}}/\partial\mu\equiv 0\) and \(\partial V_{\mathrm{loading}}/\partial\phi\equiv 0\); NB2 \(P^*_{\mathrm{J},\mu}\) **does** move with \(\mu\) and with \(\phi\) | finite-diff |

## 9. Verdict

| Surface | Verdict | Why |
|---|---|---|
| Local R oracles / this writeup (E1–E7, kill list) | **PASS** | Mean weight, size information, low-mean / \(\phi\) boundaries, and exposure≠Poisson-doubling are testable without an NB2 MSPL fit. |
| Planned registry rows / C++ tape / live NB2 MSPL / flipping `excluded` → `planned` or `admitted` | **FAIL** | Registry stays excluded until the Poisson admission gate; no tape; no prepare widening; no Shinichi admission gate. |
| NEWS / covered / SE / intervals | **FAIL** | Out of scope; SE remains PROTECTED on Codex Lane B. |

Preferred later-admission *candidates* for the fixed-effect slice,
still OPEN and not a theorem transfer:

- mean atom \(P^*_{\mathrm{J},\mu}\) with
  \(W=\operatorname{diag}(\mu\phi/(\phi+\mu))\);
- a *separately argued* size atom, or none, because Jeffreys-on-\(\phi\)
  fights the Poisson limit.

Rate, loading, and Laplace-marginal \(I(\beta)\) remain OPEN.

## 10. Non-claims

This note does **not** claim:

- calibrated inference, SEs, profiles, or model comparison;
- a live nbinom2 `estimator = "mspl"` fit;
- that Poisson Jeffreys, Bernoulli \(c_n\) / \(V_{\mathrm{loading}}\),
  or Gaussian Hirose transfer;
- that Laplace is exact for NB2 (it is not);
- that \(\phi\to\infty\) inherits the Poisson Phase-4 atom;
- NB1 / truncated NB2 / mixed-family MSPL;
- structured tiers (`phylo_*`, `spatial_*`, `animal_*`, `kernel_*`);
- that nonzero offsets are admitted;
- that planned registry rows exist for nbinom2 (they do not);
- that EVA/VA is involved (it is not);
- that this atom is the Laplace-marginal information for \(\beta\).

## 11. What must exist before admission (unchanged programme gate)

1. Symbolic information atoms and coercivity at low-mean **and**
   at \(\phi\to 0\) / \(\phi\to\infty\) (this note + oracles),
   **and** a proved loading atom under Laplace, **and** an explicit
   keep-or-drop decision on \(P^*_{\mathrm{J},\phi}\).
2. Exposure vs information size pinned in the implemented rate
   (oracles E4–E5; the factor is not 2; rate choice still OPEN).
3. Healthy-regime no-harm vs LA-ML and boundary DGPs (not this run).
4. Family-specific TMB oracles after any tape (not this run).
5. Poisson Phase-4 admission gate, then Shinichi gate, before any
   nbinom2 `status` flip from `excluded` to `planned` or
   `admitted`.

## 12. Rose boundary

- **Not EVA / not VA.** Outer criterion is Laplace-ML plus a soft
  penalty yet to be taped.
- **`excluded` ≠ `planned` ≠ `admitted`.** nbinom2 stays
  `excluded`. This prep does not add planned rows.
- **Prepare fence unchanged.** `family_id` still only `{0,1}`;
  nbinom2 (`5`) must not widen prepare.
- **No C++.** `git diff -- src/` must stay empty on this arc.
- **No registry edit.** `R/mspl-registry.R` is out of ownership
  for this sitting.
- **No NEWS covered.** No validation-register promotion.
- **No repo-root `LOOP/`.** Lane kit:
  `docs/dev-log/lanes/cursor-mspl-point-continue/LOOP/`.

## Out of scope here

Campaigns, Totoro/DRAC, NEWS, register promotion, Phase 1B API,
interval lane, NB1, truncated NB2, C++ tape, `estimator = "mspl"`
on nbinom2, planned-row insertion, Poisson admission.
