# Phase 4-style prep — Tweedie LA-MSPL route (not admitted)

**Status:** design + local oracles only. **No registry row.**
`.gllvmTMB_mspl_prepare()` still rejects every non-binomial /
non-gaussian family at the `family_id` fence
(`fam_ids %in% c(0L, 1L)`). Tweedie is `family_id = 6`. **Verdict:
PASS for oracles / this writeup, FAIL for C++ / admission /
registry / `estimator = "mspl"` on Tweedie.**

**Reader:** statistical method developer / TMB engineer who must
decide whether a later tape may add a Tweedie compound-Poisson-gamma
atom — and who must not treat that atom as a Poisson transfer.

**Programme constitution:**
`docs/dev-log/after-task/2026-08-14-laplace-mspl-estimator-programme.md`

- **Phase 4** is Poisson, then NB2 and NB1: *derive its information
  atom and coercivity for all-zero and near-zero count designs;
  distinguish exposure/offset structure from information size.*
- **Phase 5** is where Tweedie actually sits: *ordinal, multinomial,
  beta/beta-binomial, **Tweedie**, truncated and delta/hurdle.
  Each gets a separate boundary definition and evidence row.*

This note applies the **Phase 4 fences** (family-specific atom,
named boundaries, no theorem transfer, oracles before any tape) to
the Phase 5 Tweedie cell so a later slice does not start from
“Poisson worked.” It does **not** jump the Phase 4 Poisson/NB
admission queue and it does **not** add a `planned` registry row.

This is **LA-MSPL** (Laplace + a soft *outer* penalty), not EVA/VA,
not AGHQ-MSPL. There is **no** verified third-party theorem that
transfers Bernoulli Jeffreys/`V_loading`, Gaussian Hirose \(\Psi\),
or the Poisson Phase-4 \(W=\operatorname{diag}(\mu)\) atom to a
Tweedie GLLVM under Laplace (programme §7; Ranga corpus). Every
formula below that is not textbook Tweedie GLM / compound-Poisson-gamma
is **AGENT-INFERRED** and exists to pin oracles, not to license a tape.

## Why this family is not a Poisson cell

Poisson Phase 4 earned a Jeffreys-shaped \(W=\operatorname{diag}(\mu)\)
sketch because an all-zero *count sample* has one mean-boundary path
(\(\mu\to 0\)) and no free dispersion. Tweedie on the package surface
is a compound Poisson-gamma (CPG) law with three free coordinates
on the log-link ordinary cell:

\[
\mu=e^{\eta},\qquad
\phi=e^{\texttt{log\_phi\_tweedie}},\qquad
p=1+\operatorname{logit}^{-1}(\texttt{logit\_p\_tweedie})\in(1,2).
\]

Variance and zero-mass are textbook CPG (Dunn & Smyth; TMB
`dtweedie`):

\[
\operatorname{Var}(Y)=\phi\mu^{p},
\qquad
\Pr(Y=0)=\exp(-\lambda),
\qquad
\lambda=\frac{\mu^{2-p}}{\phi(2-p)}.
\]

High \(\Pr(Y=0)\) is therefore a **surface** in \((\mu,\phi,p)\), not
a synonym for “the trait is all zeros, so \(\mu\to 0\).” That is the
whole point of this prep. Programme lock: ordinary Tweedie
\(\log\mu_{it}=x_{it}^\top\beta+\lambda_t^\top u_i\) (log link only
at fit time), soft outer penalty derived for *this* likelihood,
separately. Do not transplant Poisson, Bernoulli, or Gaussian atoms
by convenience. Do not treat delta/hurdle zeros as this atom.

## 1. Five-row symbolic alignment

Tweedie GLM expected information for free fixed coordinates
\(\beta_*\) on the **log** link is textbook GLM algebra. With
\(d\mu/d\eta=\mu\) and \(V=\phi\mu^{p}\),

\[
I(\beta_*)=X_*^\top W(\mu,\phi,p)\,X_*,
\qquad
W(\mu,\phi,p)=\operatorname{diag}\!\bigl(\mu^{2-p}/\phi\bigr).
\]

A Jeffreys-shaped fixed-effect atom on the *maximised* log-likelihood
scale is therefore

\[
P^*_{\mathrm{J}}=\tfrac12\log\det\bigl(X_*^\top W(\mu,\phi,p)X_*\bigr).
\]

TMB minimises negative log-likelihood, so a later tape would add
\(-c\,P^*_{\mathrm{J}}\) together with any \(\phi\), \(p\), or
loading atoms that earn their own coercivity proofs. The soft rate
\(c\) is **not** pinned here: Bernoulli
\(c_n=2\sqrt{p_{\mathrm{free}}/N_{\mathrm{eff}}}\), Gaussian
\(c_N=\sqrt{2/N}\), and the still-open Poisson rate are all rejected
transplants (kill list §6).

When \(\phi\) is a scalar shared across the stacked rows of a
homogeneous trait block,

\[
P^*_{\mathrm{J}}
=\tfrac12\log\det\bigl(X_*^\top\operatorname{diag}(\mu^{2-p})X_*\bigr)
-\tfrac{p_{\mathrm{free}}}{2}\log\phi.
\]

So the \(\beta\)-Jeffreys atom **decreases** as \(\phi\to\infty\) and
**increases** as \(\phi\to 0\). It is not a \(\phi\to 0\) repair.

| Criterion | Atom | Parameters | TMB-shaped expression on paper | Interpretation |
|---|---|---|---|---|
| Tweedie Jeffreys-shaped \(P^*_{\mathrm{J}}\) | \(\tfrac12\log\det(X_*^\top\operatorname{diag}(\mu^{2-p}/\phi)X_*)\) | free \(\beta_*\); \(\mu=e^{\eta}\); \(\phi>0\); \(p\in(1,2)\) | \(\mathrm{nll}\mathrel{+}=-c\,P^*_{\mathrm{J}}\) | Softens paths where \(W\to 0\): \(\mu\to 0\) at fixed \(p<2\), or \(\phi\to\infty\). \(\beta\)-, \(\phi\)-, and \(p\)-dependent. |
| Information size | \(\operatorname{tr}(W)=\sum\mu^{2-p}/\phi\) or \(\lambda_{\min}(I)\) | \(\mu,\phi,p\) | diagnostic only | Size of the Tweedie GLM information. **Not** \(\sum\mu\), **not** row count, **not** \(\Pr(Y=0)\). |
| Zero-mass \(\lambda\) | \(\lambda=\mu^{2-p}/(\phi(2-p))\), \(\Pr(Y=0)=e^{-\lambda}\) | \(\mu,\phi,p\) | diagnostic only | CPG point mass. At fixed \(p\), \(W=(2-p)\lambda\): same \(\lambda\) same \(W\), but \((\mu,\phi)\) stays unidentified. |
| Contrast: Poisson \(W=\operatorname{diag}(\mu)\) | \(\tfrac12\log\det(X_*^\top\operatorname{diag}(\mu)X_*)\) | \(\mu\) only | Phase 4 planned Poisson atom | Recovers Tweedie \(W\) only at the unattainable point \(p=1,\phi=1\). Oracle kill. |
| Contrast: Bernoulli \(V_{\mathrm{loading}}\) / Gaussian Hirose | \(\sum_t(\sqrt{1+\|\lambda_t\|^2}-1)\) / \(\sum_j S_{jj}/\psi_j\) | \(\Lambda\) or \(\Psi\) | live binary tape / Phase 3 Gaussian | Wrong object. Ordinary Tweedie has no free \(\Psi\) Heywood coordinate. Oracle kill. |

Existence / coercivity sketch used as the oracle contract
(fixed-design slice first; \(\phi\), \(p\), and latent loadings
deferred):

- **T1** \(P^*_{\mathrm{J}}\) is continuous for \(\mu>0\),
  \(\phi>0\), \(p\in(1,2)\), and full-rank \(X_*\).
- **T2** Along a mean-boundary path \(\mu\to 0\) at fixed
  \(\phi\) and fixed \(p\in(1,2)\), \(W\to 0\) and
  \(P^*_{\mathrm{J}}\to-\infty\) whenever \(X_*\) has a column
  active on those rows.
- **T3** Along a dispersion-explosion path \(\phi\to\infty\) at
  fixed \(\mu>0\) and fixed \(p\in(1,2)\), \(W\to 0\) and
  \(P^*_{\mathrm{J}}\to-\infty\), while \(\Pr(Y=0)\to 1\). This is
  **not** the Poisson all-zero path.
- **T4** Along \(\phi\to 0\) at fixed \(\mu,p\), \(W\to\infty\) and
  \(P^*_{\mathrm{J}}\to+\infty\). A soft \(+c P^*_{\mathrm{J}}\)
  term therefore *rewards* dispersion collapse. The \(\beta\)-atom
  is not a \(\phi\to 0\) coercivity device.
- **T5** As \(p\to 2^-\) at fixed \(\mu>0\), \(W\to\operatorname{diag}(1/\phi)\)
  (mean-inert) and \(\Pr(Y=0)\to 0\) (gamma limit; the point mass
  dies). The Poisson-style “all-zero \(\Rightarrow\mu\to 0\)”
  signal in \(P^*_{\mathrm{J}}\) vanishes. Iterated limits
  \((\mu\to 0,\,p\to 2)\) do **not** commute.
- **T6** As \(p\to 1^+\) at fixed \(\mu,\phi\),
  \(W\to\operatorname{diag}(\mu/\phi)\) and
  \(\Pr(Y=0)\to\exp(-\mu/\phi)\). This is Poisson-like only when
  \(\phi=1\). The package map \(p=1+\operatorname{logit}^{-1}(\cdot)\)
  never attains \(p=1\) or \(p=2\); those identities are limits,
  not live cells.

Latent loading coercivity under Laplace is **OPEN**. Fisher
information for \((\phi,p)\) in the CPG series density is **OPEN**
(not faked from \(1/\phi\) or from Hirose). The Bernoulli radial
atom and the Gaussian Hirose atom are listed only as forbidden
transplants. The mean-model atom in this note is **fixed-only /
conditional** GLM information, evaluated at
\(\eta=X_{\mathrm{fix}}b_{\mathrm{fix}}+\mathrm{offset}\) before any
latent-score contribution — the same convention the live tape
records at `src/gllvmTMB.cpp` ("before any latent-score
contribution"). Laplace-marginal information for \(\beta\) is a
different object and remains **OPEN**. These oracles do not compute
it.

## 2. Power and dispersion boundaries (named, separately)

The package already fences \(1<p<2\) and \(\phi>0\) by construction
(`logit_p_tweedie`, `log_phi_tweedie`; `tweedie(p=...)` pins \(p\)
in \((1,2)\)). A parameterisation fence is **not** an MSPL atom.
Approaching a boundary on the unconstrained scale is still a live
path.

### Power \(p\to 1^+\) (Poisson-like limit)

Weights become \(W=\operatorname{diag}(\mu/\phi)\). Zero-mass
becomes \(\exp(-\mu/\phi)\). \(\phi\) remains free. Transplanting
the Poisson Phase-4 atom \(W=\operatorname{diag}(\mu)\) is a
wrong information matrix unless someone also pins \(\phi=1\) and
pretends \(p=1\) is attained. It is not. Empirical note already in
the package: fixing \(p\) does **not** unlock Tweedie random slopes
(`tests/testthat/test-tweedie-fixed-p.R`); that fact is not MSPL
evidence.

### Power \(p\to 2^-\) (gamma-like limit)

Weights become \(W=\operatorname{diag}(1/\phi)\), independent of
\(\mu\). The CPG point mass dies. A later “Tweedie all-zero”
story that only talks about \(\mu\to 0\) is empty near this
boundary. This is also **not** a Gamma MSPL cell and **not** a
Hirose \(\psi\to 0\) cell.

### Dispersion explosion \(\phi\to\infty\)

Variance \(\phi\mu^{p}\to\infty\) and \(\Pr(Y=0)\to 1\) at
**interior** \(\mu\). Information \(W\propto 1/\phi\to 0\). This
is the Tweedie-specific cousin of “lots of zeros” that Poisson
cannot express.

### Dispersion collapse \(\phi\to 0\)

Variance collapses toward a deterministic mean. \(P^*_{\mathrm{J}}\)
on \(\beta\) grows like \(-\log\phi\). That is the opposite of a
soft barrier at \(\phi\to 0\). Do not rename \(\phi\) to \(\psi\)
and import Hirose \(\sum S_{jj}/\psi_j\).

### Mean boundary \(\mu\to 0\)

At fixed \(p\in(1,2)\) and fixed \(\phi\), \(W\propto\mu^{2-p}\to 0\)
and \(\Pr(Y=0)\to 1\). Qualitatively closer to Poisson all-zero,
but the rate in \(\mu\) is \(2-p\), not \(1\), and \(\phi\) still
rescales the information. Near \(p=2\) the rate is arbitrarily
slow (T5).

### Loading runaway (named, not solved)

On \(\log\mu=\eta_{\mathrm{fix}}+\lambda^\top u\), large
\(\|\lambda\|\) can send some units’ means to \(+\infty\) and
others toward \(0\). That is a *different* boundary from
\(\phi\to 0\), from \(\phi\to\infty\), and from Bernoulli
separation. **No Tweedie loading atom is admitted in this note.**

## 3. Mass-at-zero is not Poisson all-zero

| | Poisson all-zero | Tweedie CPG mass-at-zero |
|---|---|---|
| Support | discrete \(\{0,1,2,\ldots\}\) | atom at \(0\) **plus** continuous density on \((0,\infty)\) |
| \(\Pr(Y=0)\) | \(e^{-\mu}\) | \(e^{-\mu^{2-p}/(\phi(2-p))}\) |
| Free dispersion | none | \(\phi>0\) |
| All-zero *sample* path | \(\mu\to 0\) (unique, intercept-only) | \(\mu\to 0\) **or** \(\phi\to\infty\) **or** both; \(p\) moves the surface |
| Information weight | \(W=\mu\) | \(W=\mu^{2-p}/\phi=(2-p)\lambda\) |
| Same zero-mass identifies? | \(\mu\) and \(W\) together | \(W\) (at fixed \(p\)); **not** the pair \((\mu,\phi)\) (oracle E4) |

Textbook identity, \(1<p<2\): \(W=(2-p)\lambda\). Matching
\(\Pr(Y=0)\) at fixed \(p\) therefore matches the GLM weight, so
a \(\beta\)-only Jeffreys atom **cannot tell a \(\mu\to 0\) path
from a \(\phi\to\infty\) path**. Poisson all-zero has no such
ambiguity: \(e^{-\mu}\) identifies \(\mu\) and \(W\) together.
An all-zero Tweedie *sample* is necessary and **not** sufficient
for a mean-boundary diagnosis. High observed zero fraction at
interior fitted \(\mu\) is a dispersion/power story until proven
otherwise. Finiteness of a penalised fit on all-zero or
high-zero data is necessary and **not** sufficient for admission
(programme §16).

Delta / hurdle zeros are a third object: a separate Bernoulli
zero-process plus a positive continuous law. They live on
`family_id` 12/13, not 6. Do not reuse this CPG \(\lambda\) as a
hurdle atom.

## 4. Why Poisson Phase-4 atoms do not transfer

Poisson prep
(`docs/dev-log/research/2026-08-15-mspl-phase4-poisson-prep.md`)
sketches

\[
P^*_{\mathrm{J,pois}}=\tfrac12\log\det\bigl(X_*^\top\operatorname{diag}(\mu)X_*\bigr)
\]

and distinguishes exposure from \(\sum\mu\). Four transfer
failures:

1. **Weights.** Tweedie \(W=\mu^{2-p}/\phi\) equals Poisson
   \(W=\mu\) only at the unattainable \((p,\phi)=(1,1)\).
   Doubling \(\mu\) doubles Poisson \(I\) and scales Tweedie \(I\)
   by \(2^{2-p}\) (oracle E7).
2. **Boundary object.** Poisson all-zero is a \(\mu\to 0\) count
   path. Tweedie zero-mass is a \((\mu,\phi,p)\) surface. At fixed
   \(p\), matching \(\Pr(Y=0)\) matches \(W\) but leaves
   \((\mu,\phi)\) free; a \(\beta\)-only atom cannot name the
   path. The \(\phi\to\infty\) path has no Poisson analogue.
3. **Rate in \(\mu\).** Even on a pure mean path, the Tweedie
   weight vanishes as \(\mu^{2-p}\), which is arbitrarily weak
   as \(p\to 2\).
4. **Exposure story.** Poisson prep had to separate known
   exposure \(E\) from information size. Tweedie’s extra
   confusion is \(\Pr(Y=0)\) versus information size. Using
   zero-fraction as \(N_{\mathrm{eff}}\) would mis-scale designs
   that differ only by \(\phi\).

Do not keep the Poisson atom “for symmetry with Phase 4.”

## 5. Why Bernoulli Jeffreys / \(V_{\mathrm{loading}}\) and Gaussian Hirose do not transfer

Design 88 maximises a Bernoulli Jeffreys atom with weights
\(W_g\) (logit \(\mu(1-\mu)\), probit, cloglog) plus
\(V_{\mathrm{loading}}=\sum_t(\sqrt{1+\|\lambda_t\|^2}-1)\).
Phase 3 targets Heywood \(\psi_j\to 0\) with Hirose
\(V_H=\sum_j S_{jj}/\psi_j\).

1. **Weights.** Tweedie \(W=\mu^{2-p}/\phi\) is not
   \(\mu(1-\mu)\) and not \(\mu\).
2. **\(V_{\mathrm{loading}}\) is \((\mu,\phi,p)\)-inert.**
   \(\partial V_{\mathrm{loading}}/\partial\mu\equiv 0\) and
   likewise for \(\phi,p\) (oracle E9). It cannot supply
   mean-boundary or dispersion-boundary divergence.
3. **No \(\Psi\).** Ordinary Tweedie rows in this prep cell are
   CPG means on the log link. A \(1/\psi\) atom has no object.
   Fabricating \(\psi=\phi\) or \(\psi=1/\mu\) silently renames
   the information problem without a proof (oracle E8).

## 6. Kill list — fail the later derivation on any of these

1. Transplant of the Poisson Phase-4 atom \(W=\operatorname{diag}(\mu)\)
   as if Tweedie were “overdispersed Poisson.”
2. Treating Tweedie mass-at-zero as Poisson all-zero (same
   zero-fraction \(\Rightarrow\) same \(\mu\) path).
3. Transplant of Bernoulli \(V_{\mathrm{loading}}\) or Bernoulli
   \(W_g\) without a Tweedie Laplace coercivity proof.
4. Transplant of Gaussian Hirose / Akaike \(\Psi\) atoms, or any
   \(1/\psi\) term, including \(\psi:=\phi\) or \(\psi:=1/\mu\).
5. Using the \(\beta\)-Jeffreys atom as a \(\phi\to 0\) repair
   (it rewards collapse; T4).
6. Reuse of Bernoulli \(c_n\), Gaussian \(c_N\), or an unpinned
   Poisson rate without a Tweedie rate argument against the
   Laplace objective.
7. Treating \(\Pr(Y=0)\), \(\sum\mu\), or row count as
   interchangeable with information size \(\sum\mu^{2-p}/\phi\).
8. Claiming \(p\to 1\) *is* the Poisson cell, or \(p\to 2\) *is*
   a Gamma / Hirose cell. Those are limits, not attained
   `family_id` values.
9. Claiming Design 88, Sterzinger–Kosmidis–Moustaki 2026, or
   Poisson Phase 4 covers Tweedie GLLVM MSPL under Laplace.
10. Finiteness of a high-zero or all-zero Tweedie fit offered as
    the scientific result.
11. Mixed-family, NB1/NB2, truncated, or delta/hurdle inheritance
    (“Tweedie zeros, so hurdle does”).
12. Any admission-shaped language (status flip, `planned` registry
    row, NEWS covered, validation-register promotion, C++ tape)
    ahead of the Shinichi gate **and** ahead of Phase 4 Poisson/NB
    order in the constitution.
13. Live `gllvmTMB(..., estimator = "mspl")` on Tweedie in tests.
14. Quietly widening `.gllvmTMB_mspl_prepare()` beyond
    `family_id %in% {0,1}`.

## 7. Oracle contract E1–E10 (pure R; no Tweedie `estimator="mspl"`)

| ID | What | Tolerance / decision |
|---|---|---|
| E1 | Tweedie \(I=X^\top\operatorname{diag}(\mu^{2-p}/\phi)X\); Poisson \(W=\mu\) and Bernoulli \(W_g=\mu(1-\mu)\) **differ** | rel. err \(<10^{-12}\) on Tweedie; both contrasts fire |
| E2 | Mean path: \(\mu\to 0\) at fixed \(\phi,p\in(1,2)\) sends \(P^*_{\mathrm{J}}\to-\infty\) | monotone decrease; large negative |
| E3 | Dispersion-explosion: \(\phi\to\infty\) at fixed \(\mu,p\) sends \(P^*_{\mathrm{J}}\to-\infty\) and \(\Pr(Y=0)\to 1\) | monotone in \(\phi\uparrow\); \(P^*_{\mathrm{J}}\) **increases** as \(\phi\downarrow\) (T4) |
| E4 | Matched \(\Pr(Y=0)\) via a \(\mu\)-path vs a \(\phi\)-path: **same** \(W=(2-p)\lambda\), **different** \((\mu,\phi)\); Poisson \(\mu=-\log\Pr(Y=0)\) matches neither | \(W\) equal \(<10^{-12}\); \(\mu,\phi\) contrasts; Poisson contrast |
| E5 | \(p\to 2^-\) at fixed \(\mu>0\): \(W\to 1/\phi\) (mean-inert); \(\Pr(Y=0)\to 0\) | rel. err on \(W\); \(\partial P^*_{\mathrm{J}}/\partial\mu\to 0\) |
| E6 | \(p\to 1^+\): \(W\to\mu/\phi\); \(\Pr(Y=0)\to e^{-\mu/\phi}\); equals Poisson \(W=\mu\) **only** at \(\phi=1\) | rel. err; \(\phi\neq 1\) contrast |
| E7 | Information size is \(\sum\mu^{2-p}/\phi\); doubling \(\mu\) scales \(I\) by \(2^{2-p}\), not \(2\); \(N_{\mathrm{rows}}\) and \(\Pr(Y=0)\) are not \(I\) | exact scale; contrasts fire |
| E8 | Hirose \(\sum S/\psi\) is undefined / refused for the Tweedie mean model | structural reject |
| E9 | \(\partial V_{\mathrm{loading}}/\partial(\mu,\phi,p)\equiv 0\); Tweedie \(P^*_{\mathrm{J}}\) **does** move | finite-diff |
| E10 | No Tweedie registry row; this file never calls live MSPL | lookup `NULL`; source scan |

## 8. Verdict

| Surface | Verdict | Why |
|---|---|---|
| Local R oracles / this writeup (E1–E10, kill list) | **PASS** | Power/dispersion boundaries, mass-at-zero ≠ Poisson all-zero, and the \(W=\mu^{2-p}/\phi\) atom are testable without a Tweedie MSPL fit. |
| Registry `planned` / `admitted` Tweedie row | **FAIL** | Deliberately absent. Phase 5 cell; do not smuggle a Poisson-style `phase4_prep` row. |
| C++ tape / live Tweedie MSPL | **FAIL** | No tape, no prepare widening, no Shinichi admission gate. |
| NEWS / covered / SE / intervals | **FAIL** | Out of scope; SE remains PROTECTED on Codex Lane B. |

Preferred later-admission *candidate* for the fixed-effect slice:
Tweedie Jeffreys-shaped
\(\tfrac12\log\det(X_*^\top\operatorname{diag}(\mu^{2-p}/\phi)X_*)\),
with rate, \(\phi\)-atom, \(p\)-atom, loading atom, and
Laplace-marginal \(I(\beta)\) still OPEN.
Not a theorem transfer. Not a Poisson transfer.

## 9. Non-claims

This note does **not** claim:

- calibrated inference, SEs, profiles, or model comparison;
- a live Tweedie `estimator = "mspl"` fit;
- that Bernoulli \(c_n\), \(V_{\mathrm{loading}}\), Gaussian Hirose,
  or Poisson \(W=\operatorname{diag}(\mu)\) transfer;
- that Laplace is exact for Tweedie (it is not);
- that \(p\to 1\) is Poisson MSPL or \(p\to 2\) is Gamma MSPL;
- NB1 / NB2 / truncated / delta / hurdle / mixed-family MSPL;
- structured tiers (`phylo_*`, `spatial_*`, `animal_*`, `kernel_*`);
- that a `planned` registry row exists or should exist;
- that EVA/VA is involved (it is not);
- that this prep authorises jumping Phase 4 Poisson/NB;
- that this atom is the Laplace-marginal information for \(\beta\).

## 10. What must exist before admission (unchanged programme gate)

1. Symbolic information atom and coercivity at each *named*
   Tweedie boundary (this note + oracles) **and** proved
   \(\phi\), \(p\), and loading atoms under Laplace where those
   boundaries are in scope.
2. Mass-at-zero vs mean-boundary vs dispersion-explosion pinned
   in the implemented diagnostics (oracles E3–E4; rate still OPEN).
3. Healthy-regime no-harm vs LA-ML and boundary DGPs (not this run).
4. Family-specific TMB oracles after any tape (not this run).
5. Shinichi gate before any `status` appears, and not before the
   constitution’s Phase 4 Poisson/NB order is respected.

## 11. Rose boundary

- **Not EVA / not VA.** Outer criterion is Laplace-ML plus a soft
  penalty yet to be taped.
- **No registry row.** `planned` ≠ `admitted`, and Tweedie is
  neither.
- **Prepare fence unchanged.** `family_id` still only `{0,1}`.
- **No C++.** `git diff -- src/` must stay empty on this arc.
- **No NEWS covered.** No validation-register promotion.
- **No repo-root `LOOP/`.** Lane kit:
  `docs/dev-log/lanes/cursor-mspl-phase4-tweedie/LOOP/`.
- **No family transfer.** Poisson Phase 4 is a sibling prep, not
  a licence.

## Out of scope here

Campaigns, Totoro/DRAC, NEWS, register rows, Phase 1B API,
interval lane, Poisson/NB admission, C++ tape,
`estimator = "mspl"` on Tweedie, delta/hurdle, identity-link
Tweedie (constructor-listed; fit currently log-only).
