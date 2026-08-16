# Phase 4-style prep — delta/hurdle LA-MSPL route (not admitted)

**Status:** design + local oracles + **planned** registry rows.
`.gllvmTMB_mspl_prepare()` still rejects every family outside
`family_id %in% {0L, 1L, 2L}`. Delta-lognormal is `family_id` 12;
delta-Gamma is `family_id` 13. `gll_mspl_log_weight_glm()` has
**no** fid 12/13 branch. **Verdict: PASS for oracles / this
writeup / planned rows, FAIL for C++ / admission / public
`estimator = "mspl"` on either hurdle family.**

**Reader:** statistical method developer / TMB engineer who must
decide whether a later tape may add a two-part shared-η atom —
and who must not treat Bernoulli Design 88, Poisson Phase 4, or
Tweedie CPG zeros as a licence.

**Programme constitution:**
`docs/dev-log/after-task/2026-08-14-laplace-mspl-estimator-programme.md`
§Phase 5 — *truncated and delta/hurdle components. Each gets a
separate boundary definition and evidence row.* This note is
Phase-4-*style* prep so a later Phase 5 derivation does not start
from “Bernoulli already covers occurrence” or “Tweedie already
covers zeros.” It does **not** jump the Phase 4 Poisson/NB
admission queue.

This is **LA-MSPL** (Laplace + a soft *outer* penalty), not EVA/VA,
not AGHQ-MSPL. There is **no** verified third-party theorem that
transfers Bernoulli Jeffreys / `V_loading`, Gaussian Hirose
\(\Psi\), Poisson \(W=\operatorname{diag}(\mu)\), or Tweedie
\(W=\mu^{2-p}/\phi\) to a hurdle GLLVM under Laplace (programme
§7; Ranga corpus). Every formula below that is not textbook
Bernoulli-logit / lognormal / Gamma GLM information, or the
package’s own shared-η tape, is **AGENT-INFERRED** and exists to
pin oracles, not to license a tape.

## Why this is not a Bernoulli cell, a Poisson cell, or a Tweedie cell

The live tape (`src/gllvmTMB.cpp` fid 12 / 13) is a **shared-η
two-part** law, not two independent models and not a
compound-Poisson point mass.

**Occurrence** (both families):

\[
x=\mathbf{1}\{y>0\}\sim\mathrm{Bernoulli}(\pi),\qquad
\pi=\operatorname{logit}^{-1}(\eta),\qquad
\ell_{\mathrm{occ}}=x\eta-\log(1+e^{\eta})
\]

(`dbinom_robust` on `eta_o`).

**Positive part, given \(y>0\):**

| Family | fid | Positive law | Dispersion | \(E[Y\mid Y>0]\) |
|---|---|---|---|---|
| `delta_lognormal` | 12 | \(\log Y\mid Y>0\sim N(\eta,\sigma^2)\) | \(\sigma=\exp(\texttt{log\_sigma\_lognormal\_delta})\) | \(\exp(\eta+\sigma^2/2)\) |
| `delta_gamma` | 13 | \(Y\mid Y>0\sim\mathrm{Gamma}(\mathrm{shape}=1/\varphi^2,\,\mathrm{scale}=\mu\varphi^2)\) | \(\varphi=\exp(\texttt{log\_phi\_gamma\_delta})\) (CV) | \(\mu=\exp(\eta)\) |

One linear predictor drives **both** pieces. Design 02’s
“occurrence is fixed-effects only” is a *correlation-reporting*
constraint (latent scale = positive-part residual). It is **not**
a second η in the Laplace tape. Design 110 records the same
shared-predictor fact. Do not invent a two-η MSPL cell from the
correlation note.

Three objects that look like “zeros” and are not this atom:

1. **Bernoulli Design 88** is a *single* discrete law. Its
   Jeffreys weight is \(\pi(1-\pi)\). Here that weight is only
   the occurrence half. The same η also scores the positive part.
2. **Poisson all-zero** is \(\mu\to 0\) in a one-parameter count
   law, \(W=\mu\). Hurdle \(\Pr(Y=0)=1-\pi\) identifies η on the
   logit scale, not \(\log\mu\).
3. **Tweedie CPG mass** is \(\Pr(Y=0)=\exp(-\mu^{2-p}/(\phi(2-p)))\)
   from one process. Hurdle zeros are a separate Bernoulli. Do
   not reuse Tweedie \(\lambda\).

`delta_lognormal` and `delta_gamma` share the occurrence piece
and **do not** share the positive-part information. They are two
cells. `delta_beta`, mixtures, and Poisson-link constructors are
out of scope.

## 1. Five-row symbolic alignment

Expected GLM-outer information for free fixed coordinates
\(\beta_*\) at **fixed** dispersion, evaluated at
\(\eta=X_{\mathrm{fix}}b_{\mathrm{fix}}+\mathrm{offset}\) before
any latent-score contribution (same convention as the live tape
comment “before any latent-score contribution”):

\[
I(\beta_*)=X_*^\top W(\eta,\kappa)\,X_*,
\qquad
\pi=\operatorname{logit}^{-1}(\eta).
\]

Occurrence contribution (textbook Bernoulli logit; observed =
expected):

\[
w_{\mathrm{occ}}=\pi(1-\pi).
\]

Positive contribution, *expected* over the hurdle (the positive
density is evaluated only when \(y>0\), which has probability
\(\pi\)):

\[
w_{\mathrm{dln,pos}}=\frac{\pi}{\sigma^2},
\qquad
w_{\mathrm{dg,pos}}=\frac{\pi}{\varphi^2}.
\]

The Gamma row is the expected Fisher for the package
parameterisation: score
\((y/\mu-1)/\varphi^2\), observed \(I_{\eta\eta}=y/(\mu\varphi^2)\),
expected \(I_{\eta\eta}=1/\varphi^2\) on a positive draw, times
\(\pi\). The lognormal row is Gaussian-on-\(\log y\): observed
\(I_{\eta\eta}=1/\sigma^2\) on a positive draw, times \(\pi\).

Jeffreys-shaped *shared-η* atom on the maximised log-likelihood
scale:

\[
P^*_{\mathrm{J,dln}}=\tfrac12\log\det\bigl(X_*^\top\operatorname{diag}\bigl(\pi(1-\pi)+\pi/\sigma^2\bigr)X_*\bigr),
\]

\[
P^*_{\mathrm{J,dg}}=\tfrac12\log\det\bigl(X_*^\top\operatorname{diag}\bigl(\pi(1-\pi)+\pi/\varphi^2\bigr)X_*\bigr).
\]

TMB minimises negative log-likelihood, so a later tape would add
\(-c\,P^*_{\mathrm{J}}\). The soft rate \(c\) is **not** pinned:
Bernoulli \(c_n\), Gaussian \(c_N\), and the unpinned Poisson
\(c=1\) are rejected transplants (kill list §6).
`gll_mspl_log_weight_glm()` currently `error`s on fid 12/13 —
there is no fenced tape to inherit.

| Criterion | Atom | Parameters | TMB-shaped expression on paper | Interpretation |
|---|---|---|---|---|
| Shared-η Jeffreys \(P^*_{\mathrm{J,dln}}\) | \(\tfrac12\log\det(X_*^\top W X_*)\), \(W=\pi(1-\pi)+\pi/\sigma^2\) | free \(\beta_*\); \(\sigma>0\) | \(\mathrm{nll}\mathrel{+}=-c\,P^*_{\mathrm{J,dln}}\) | Occurrence **plus** lognormal mean. Not Bernoulli \(W_g\) alone. |
| Shared-η Jeffreys \(P^*_{\mathrm{J,dg}}\) | same template, \(W=\pi(1-\pi)+\pi/\varphi^2\) | free \(\beta_*\); \(\varphi>0\) (CV) | \(\mathrm{nll}\mathrel{+}=-c\,P^*_{\mathrm{J,dg}}\) | Occurrence **plus** Gamma log-mean. Not the lognormal cell. |
| Information size | \(\operatorname{tr}(W)\) or \(\lambda_{\min}(I)\) | \(\eta,\kappa\) | diagnostic only | Not row count, not zero-fraction, not Poisson \(\sum\mu\). |
| Contrast: Bernoulli \(W_g\) / \(V_{\mathrm{loading}}\) | \(\pi(1-\pi)\); \(\sum_t(\sqrt{1+\|\lambda_t\|^2}-1)\) | \(\pi\) or \(\Lambda\) | live Design 88 | Half the hurdle likelihood; \(V_{\mathrm{loading}}\) is \((\pi,\sigma,\varphi)\)-inert. |
| Contrast: Poisson \(W=\mu\) / Tweedie \(W=\mu^{2-p}/\phi\) | count / CPG weights | \(\mu\) or \((\mu,\phi,p)\) | Phase 4 / Phase-5 Tweedie notes | Wrong zero mechanism. Oracle kill. |

Existence / coercivity sketch used as the oracle contract
(fixed-design slice first; latent loadings deferred):

- **H1** \(P^*_{\mathrm{J}}\) is continuous for \(\pi\in(0,1)\),
  \(\sigma>0\) (or \(\varphi>0\)), and full-rank \(X_*\).
- **H2** Along an all-zero path \(\eta\to-\infty\) (\(\pi\to 0\))
  both summands vanish and \(P^*_{\mathrm{J}}\to-\infty\) whenever
  \(X_*\) has a column active on those rows. Dispersion is
  unidentified (no positive \(y\)).
- **H3** Along an all-positive path \(\eta\to+\infty\)
  (\(\pi\to 1\)), \(w_{\mathrm{occ}}\to 0\) but
  \(w_{\mathrm{pos}}\to 1/\sigma^2\) or \(1/\varphi^2\).
  \(P^*_{\mathrm{J}}\) stays **finite**. Pure Bernoulli Jeffreys
  diverges here. Transplanting Design 88’s “Jeffreys repairs
  complete separation” *role* is false for the shared-η atom
  (oracle E3).
- **H4** Shared η couples the two stories: sending occurrence to
  \(\pi\to 1\) *is* sending the positive mean to
  \(\exp(\eta)\to\infty\) (Gamma) or
  \(\exp(\eta+\sigma^2/2)\to\infty\) (lognormal). There is no
  independent “occurrence separates, positive mean stays put”
  path on this tape.
- **H5** As \(\sigma\to\infty\) or \(\varphi\to\infty\) at fixed
  \(\pi\in(0,1)\), \(W\to\pi(1-\pi)\): the atom collapses to
  Bernoulli-only. As \(\sigma\to 0\) or \(\varphi\to 0\),
  \(W\to\infty\) and \(P^*_{\mathrm{J}}\to+\infty\). A soft
  \(+c P^*_{\mathrm{J}}\) term **rewards** positive-part
  collapse. The \(\beta\)-atom is not a dispersion repair
  (oracles E6–E7).
- **H6** \(\Pr(Y=0)=1-\pi\) identifies η for the hurdle. The same
  zero-fraction identifies a *different* η under Poisson
  (\(\mu=-\log\Pr(Y=0)\)) and a \((\mu,\phi,p)\) surface under
  Tweedie. Matched zeros do not match information (oracle E5).
- **H7** Latent loading coercivity under Laplace is **OPEN**.
  Bernoulli \(V_{\mathrm{loading}}\) is listed only as a
  forbidden transplant. Laplace-marginal \(I(\beta)\) is a
  different object and remains **OPEN**. These oracles do not
  compute it.

## 2. Named boundaries (four objects, not one “zero problem”)

### All-zero sample

Only the Bernoulli likelihood remains. \(\eta\to-\infty\),
\(W\to 0\), \(P^*_{\mathrm{J}}\to-\infty\). \(\sigma\) / \(\varphi\)
have no positive observations. Finiteness of a penalised fit on
all-zero data is necessary and **not** sufficient for admission
(programme §16).

### All-positive sample

Bernoulli still contributes, but \(w_{\mathrm{occ}}\to 0\). The
positive part is fully observed and keeps \(W\) at \(1/\sigma^2\)
or \(1/\varphi^2\). Shared η means “everyone is present” is also
“everyone’s positive mean exploded.” That is **not** Design 88
complete separation, and it is **not** Poisson all-zero.

### Dispersion explosion / collapse

\(\sigma\to\infty\) (lognormal) or \(\varphi\to\infty\) (Gamma CV)
erases the positive-part information and leaves Bernoulli-only
weights. \(\sigma\to 0\) / \(\varphi\to 0\) makes \(P^*_{\mathrm{J}}\)
diverge to \(+\infty\) — a reward, not a barrier. Do not rename
\(\sigma\) or \(\varphi\) to \(\psi\) and import Hirose.

### Loading runaway (named, not solved)

On shared \(\eta=\eta_{\mathrm{fix}}+\lambda^\top u\), large
\(\|\lambda\|\) moves **both** occurrence and the positive mean.
Design 88’s \(V_{\mathrm{loading}}\) was built for binary
link-scale runaway and is inert in \((\pi,\sigma,\varphi)\).
**No hurdle loading atom is admitted in this note.**

## 3. Why Bernoulli Jeffreys / \(V_{\mathrm{loading}}\) do not transfer

Design 88 maximises a Bernoulli Jeffreys atom with weights
\(W_g\) plus \(V_{\mathrm{loading}}=\sum_t(\sqrt{1+\|\lambda_t\|^2}-1)\).

1. **Support.** Design 88 is \(y\in\{0,1\}\). Hurdle \(y\) is
   \(\{0\}\cup(0,\infty)\). The positive density is missing from
   \(W_g\).
2. **Weights.** \(W=\pi(1-\pi)+\pi/\kappa^2\) is not
   \(\pi(1-\pi)\) (oracle E1). Reusing `W_g` understates
   information wherever \(\pi>0\).
3. **All-positive role.** Bernoulli Jeffreys diverges as
   \(\pi\to 1\). The shared-η atom stays finite (H3, oracle E3).
4. **\(V_{\mathrm{loading}}\) is \((\pi,\sigma,\varphi)\)-inert**
   (oracle E9). It cannot supply all-zero or dispersion
   divergence.

Do not keep Bernoulli atoms “because occurrence is logit.”

## 4. Why Poisson \(W=\operatorname{diag}(\mu)\) does not transfer

Poisson Phase-4 prep pins \(I=X_*^\top\operatorname{diag}(\mu)X_*\)
for a log-mean count. Hurdle \(\Pr(Y=0)=1-\pi\) is not
\(e^{-\mu}\). Matched zero-fraction produces different η and
different \(W\) (oracle E5). Exposure / offset algebra from the
Poisson note has no object on the occurrence logit.

## 5. Why Tweedie CPG zeros do not transfer

Tweedie prep pins \(W=\mu^{2-p}/\phi\) and
\(\Pr(Y=0)=\exp(-\mu^{2-p}/(\phi(2-p)))\). That is one process
with a free power. Hurdle zeros are a Bernoulli. Matching
\(\Pr(Y=0)\) matches neither \(W\) nor the \((\mu,\phi)\) pair
(oracle E5). Kill list in the Tweedie note already forbids
“Tweedie zeros, so hurdle does.”

## 6. Why Gaussian Hirose \(\Psi\) does not transfer

Phase 3 targets Heywood \(\psi_j\to 0\) in
\(\Sigma=\Lambda\Lambda^\top+\Psi\). Ordinary hurdle rows in this
prep cell are a shared-η mean plus a positive-part scale
(\(\sigma\) or CV \(\varphi\)). They do not carry a free Gaussian
unique-variance coordinate. Fabricating \(\psi=\sigma^2\) or
\(\psi=\varphi^2\) silently renames the dispersion problem
without a proof (oracle E8). \(\sigma\to 0\) is lognormal
collapse, not Hirose.

## 6a. Why the two hurdle families do not inherit each other

Same occurrence. Different positive Fisher, different
\(E[Y\mid Y>0]\). Lognormal η is \(E[\log Y\mid Y>0]\); Gamma η
is \(\log E[Y\mid Y>0]\). A later tape that copies
\(W=\pi(1-\pi)+\pi/\sigma^2\) onto fid 13 (or the reverse) is a
type error (oracle E4).

## 7. Kill list — fail the later derivation on any of these

1. Transplant of Bernoulli \(W_g=\pi(1-\pi)\) as the whole hurdle
   atom, or of Design 88’s “Jeffreys repairs \(\pi\to 0/1\)” role
   (false at \(\pi\to 1\)).
2. Transplant of Bernoulli \(V_{\mathrm{loading}}\) without a
   hurdle Laplace coercivity proof.
3. Transplant of Poisson \(W=\operatorname{diag}(\mu)\), or
   treating matched \(\Pr(Y=0)\) as a shared η.
4. Transplant of Tweedie \(W=\mu^{2-p}/\phi\) or CPG \(\lambda\).
5. Transplant of Gaussian Hirose / Akaike \(\Psi\) atoms, or any
   \(1/\psi\) term, including \(\psi:=\sigma^2\) or
   \(\psi:=\varphi^2\).
6. Reuse of Bernoulli \(c_n\), Gaussian \(c_N\), or Poisson
   \(c=1\) without a hurdle rate argument against the Laplace
   objective.
7. Using the \(\beta\)-Jeffreys atom as a \(\sigma\to 0\) or
   \(\varphi\to 0\) repair (it rewards collapse; H5).
8. Treating \(\Pr(Y=0)\), row count, or Poisson \(\sum\mu\) as
   interchangeable with \(\operatorname{tr}(W)\).
9. Inventing a two-η cell from Design 02’s “occurrence FE-only”
   correlation note, or claiming the live tape already splits η.
10. Claiming `delta_lognormal` inherits `delta_gamma` (or the
    reverse), or that either inherits `delta_beta` / mixtures /
    Poisson-link constructors.
11. Claiming Design 88, Sterzinger–Kosmidis–Moustaki 2026,
    Poisson Phase 4, or Tweedie Phase-5 prep covers hurdle GLLVM
    MSPL under Laplace.
12. Finiteness of an all-zero or all-positive hurdle fit offered
    as the scientific result.
13. Any admission-shaped language (status flip to `admitted`,
    NEWS covered, validation-register promotion, C++ tape,
    prepare widen to fid 12/13) ahead of the Shinichi gate.
14. Live `gllvmTMB(..., estimator = "mspl")` *fit* on either
    hurdle family in tests.
15. Quietly widening `.gllvmTMB_mspl_prepare()` beyond
    `family_id %in% {0,1,2}`.

## 8. Oracle contract E1–E10 (pure R; no hurdle `estimator="mspl"` fit)

| ID | What | Tolerance / decision |
|---|---|---|
| E1 | Combined \(W=\pi(1-\pi)+\pi/\kappa^2\); Bernoulli-only and positive-only **differ**; Poisson \(W=\mu\) **differs** | rel. err \(<10^{-12}\) on hurdle; contrasts fire |
| E2 | All-zero path \(\eta\to-\infty\): \(P^*_{\mathrm{J}}\to-\infty\) for both families | monotone; large negative |
| E3 | All-positive path \(\eta\to+\infty\): hurdle \(P^*_{\mathrm{J}}\) **finite**; Bernoulli-only \(P^*_{\mathrm{J}}\to-\infty\) | hurdle bounded; Bernoulli diverges |
| E4 | Lognormal vs Gamma: same \(\eta\) gives different \(E[Y\mid Y>0]\) and different \(W\) unless \(\sigma=\varphi\) | contrasts fire; equal \(W\) only at \(\sigma=\varphi\) |
| E5 | Matched \(\Pr(Y=0)\): hurdle η, Poisson η, and Tweedie \((\mu,\phi)\) **differ**; \(W\) differ | contrasts fire |
| E6 | \(\sigma\to\infty\) or \(\varphi\to\infty\): \(W\to\pi(1-\pi)\) | rel. err at large κ |
| E7 | \(\sigma\to 0\) or \(\varphi\to 0\): \(P^*_{\mathrm{J}}\to+\infty\) (reward) | monotone increase |
| E8 | Hirose refused; fabricating \(\psi=\sigma^2\) or \(\psi=\varphi^2\) is not \(P^*_{\mathrm{J}}\) | structural reject + contrast |
| E9 | \(\partial V_{\mathrm{loading}}/\partial(\pi,\sigma,\varphi)\equiv 0\); hurdle \(P^*_{\mathrm{J}}\) **does** move | finite-diff |
| E10 | Four `planned` / `phase4_prep` rows; none `admitted`; prepare source still `{0,1,2}` | lookup + source scan |

## 9. Verdict

| Surface | Verdict | Why |
|---|---|---|
| Local R oracles / this writeup (E1–E10, kill list) | **PASS** | Shared-η weights, all-zero vs all-positive, and zero-mechanism contrasts are testable without a hurdle MSPL fit. |
| Registry `planned` ordinary q1/q2 rows | **PASS as planned** | Board was na; this prep adds `planned` / `phase4_prep` only. |
| Registry `admitted` / public door / C++ tape | **FAIL** | Prepare still `{0,1,2}`; no fid 12/13 weight; no Shinichi admission gate. |
| NEWS / covered / SE / intervals | **FAIL** | Out of scope; SE remains PROTECTED on Codex Lane B. |

Preferred later-admission *candidates* for the fixed-effect slice,
still OPEN and not a theorem transfer:

- `delta_lognormal`: \(W=\pi(1-\pi)+\pi/\sigma^2\);
- `delta_gamma`: \(W=\pi(1-\pi)+\pi/\varphi^2\).

Rate, loading, dispersion atoms, and Laplace-marginal \(I(\beta)\)
remain OPEN.

## 10. Non-claims

This note does **not** claim:

- calibrated inference, SEs, profiles, or model comparison;
- a live hurdle `estimator = "mspl"` fit;
- that Bernoulli \(c_n\) / \(V_{\mathrm{loading}}\), Poisson
  \(W=\operatorname{diag}(\mu)\), Tweedie CPG, or Gaussian Hirose
  transfer;
- that Jeffreys-shaped \(P^*_{\mathrm{J}}\) repairs \(\pi\to 1\)
  or \(\sigma\to 0\);
- that Laplace is exact for either hurdle family (it is not);
- that Design 02 already split η;
- `delta_beta` / mixtures / Poisson-link / mixed-family MSPL;
- structured tiers (`phylo_*`, `spatial_*`, `animal_*`, `kernel_*`);
- that EVA/VA is involved (it is not);
- that this atom is the Laplace-marginal information for \(\beta\);
- that a public door exists (it does not).

## 11. What must exist before admission (unchanged programme gate)

1. Symbolic information atom **and** a named boundary the atom is
   actually coercive for (this note: all-zero yes; all-positive
   **no**; dispersion collapse **wrong sign**) **and** a proved
   loading atom under Laplace.
2. The two families kept as separate cells, with shared-η coupling
   pinned in the implemented diagnostics (oracles E3–E5).
3. Healthy-regime no-harm vs LA-ML and boundary DGPs (not this run).
4. Family-specific TMB oracles after any tape (not this run).
5. Phase 4 Poisson/NB order respected, then Shinichi gate, before
   any `status` flip from `planned` to `admitted`, and before any
   prepare widen to fid 12/13.

## 12. Rose boundary

- **Not EVA / not VA.** Outer criterion is Laplace-ML plus a soft
  penalty yet to be taped.
- **`planned` ≠ `admitted`.** Board was na; rows are planned only.
- **Prepare fence unchanged.** `family_id` still only `{0,1,2}`.
- **No C++.** `git diff -- src/` must stay empty on this arc.
- **No NEWS covered.** No validation-register promotion.
- **No repo-root `LOOP/`.** Lane kit:
  `docs/dev-log/lanes/cursor-mspl-phase4-hurdle/LOOP/`.
- **No family transfer.** Poisson / Tweedie / Bernoulli / Gamma
  MSPL (there is no Gamma MSPL cell) are siblings, not licences.

## Out of scope here

Campaigns, Totoro/DRAC, NEWS, register promotion, Phase 1B API,
interval lane, C++ tape, `estimator = "mspl"` on delta_*,
prepare widen, `delta_beta`, mixtures, Poisson-link, identity /
inverse positive-part links (constructors list them; the live
tape uses shared η as written above).
