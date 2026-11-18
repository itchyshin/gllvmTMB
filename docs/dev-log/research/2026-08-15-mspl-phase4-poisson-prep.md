# Phase 4 prep — Poisson LA-MSPL route (not admitted)

**Status:** design + local oracles only (2026-08-15 strengthen pass
on lane `cursor/mspl-phase4-poisson`). Registry rows
`poisson:log:ordinary:q1` and `q2` are **`planned`** with
`evidence = "phase4_prep"`. After #978 the public door is
`fam_ids %in% c(0L, 1L, 2L)` (gaussian / bernoulli / Poisson);
NB1, NB2, beta, and Tweedie stay out. Poisson remains `family_id = 2`
and is **not admitted**. **Verdict:
PASS for oracles / planned rows, FAIL for admission / NEWS covered.**

**Reader:** statistical method developer / TMB engineer who must
decide whether a later tape may add a Poisson count atom.

**Programme constitution:**
`docs/dev-log/after-task/2026-08-14-laplace-mspl-estimator-programme.md`
§Phase 4 — *derive its information atom and coercivity for all-zero
and near-zero count designs; distinguish exposure/offset structure
from information size.*

This is **LA-MSPL** (Laplace + a soft *outer* penalty), not EVA/VA,
not AGHQ-MSPL. There is **no** verified third-party theorem that
transfers Bernoulli Jeffreys/`V_loading` or Gaussian Hirose \(\Psi\)
atoms to a Poisson GLLVM under Laplace (programme §7; Ranga corpus).
Every formula below that is not textbook Poisson GLM information is
**AGENT-INFERRED** and exists to pin oracles, not to license a tape.

## Why this is the next family cell

Gaussian Heywood earned its own atom from a matched primary paper.
Poisson is next because it is the simplest one-sided *count* boundary
stress test: all-zero and near-zero traits push the mean toward the
boundary \(\mu\to 0\), while loadings on the log-mean scale can still
run away. It does **not** inherit the Gaussian proof, and it does
**not** inherit Design 88.

Programme lock: ordinary Poisson
\(\log\mu_{it}=x_{it}^\top\beta+\lambda_t^\top u_i\) (optional known
offset), soft outer penalty derived for *this* likelihood, separately.
Do not transplant Bernoulli or Gaussian atoms by convenience.

## 1. Five-row symbolic alignment

Poisson GLM expected information for free fixed coordinates \(\beta_*\)
on the log link is textbook:

\[
I(\beta_*)=X_*^\top W(\mu)\,X_*,\qquad W(\mu)=\operatorname{diag}(\mu).
\]

A Jeffreys-shaped fixed-effect atom on the *maximised* log-likelihood
scale is therefore

\[
P^*_{\mathrm{J}}=\tfrac12\log\det\bigl(X_*^\top W(\mu)X_*\bigr).
\]

TMB minimises negative log-likelihood, so a later tape would add
\(-c\,P^*_{\mathrm{J}}\) together with any loading/covariance atoms that
earn their own coercivity proofs. The soft rate \(c\) is **not** pinned
here: Bernoulli \(c_n=2\sqrt{p_{\mathrm{free}}/N_{\mathrm{eff}}}\) and
Gaussian \(c_N=\sqrt{2/N}\) are both rejected transplants until a
Poisson rate comparison is written against the actual Laplace
objective (kill list §5).

| Criterion | Atom | Parameters | TMB-shaped expression on paper | Interpretation |
|---|---|---|---|---|
| Poisson Jeffreys-shaped \(P^*_{\mathrm{J}}\) | \(\tfrac12\log\det(X_*^\top\operatorname{diag}(\mu)X_*)\) | free \(\beta_*\); \(\mu=\exp(\eta)\) (× exposure if offset) | \(\mathrm{nll}\mathrel{+}=-c\,P^*_{\mathrm{J}}\) | Softens \(\beta\to-\infty\) / \(\mu\to 0\) paths where \(W\to 0\). \(\beta\)-dependent (unlike Gaussian). |
| Information size | \(\operatorname{tr}(W)=\sum\mu\) or \(\lambda_{\min}(X_*^\top W X_*)\) | \(\mu\) | diagnostic only | Size of the Poisson information, **not** the row count and **not** the exposure total alone. |
| Exposure / offset | \(o=\log E\), \(\mu=E\circ\exp(\eta_{\mathrm{free}})\) | known \(E>0\) | offset vector; Design 88 still requires all-zero offset on the live binary surface | Exposure rescales the *mean*; it is not a second sample-size knob for \(c\). |
| Contrast: Bernoulli \(V_{\mathrm{loading}}\) | \(\sum_t(\sqrt{1+\|\lambda_t\|^2}-1)\) | \(\Lambda\) only | live `gll_mspl_row_radial_penalty` | Binary link-scale runaway atom. No Poisson coercivity proof. Oracle kill. |
| Contrast: Gaussian Hirose | \(\sum_j S_{jj}/\psi_j\) | diagonal \(\Psi\) | Phase 3 planned tape object | Heywood / unique-variance atom. Ordinary Poisson GLLVM has no free \(\Psi\) Heywood coordinate in this prep cell. Oracle kill. |

Existence / coercivity sketch used as the oracle contract (fixed-design
slice first; latent loadings deferred to a separate proof):

- **P1** \(P^*_{\mathrm{J}}\) is continuous for \(\mu>0\) and full-rank \(X_*\).
- **P2** Along an all-zero or near-zero path with \(\mu_t\to 0\) uniformly
  on a trait (or intercept \(\beta\to-\infty\)), \(W\to 0\) and
  \(P^*_{\mathrm{J}}\to-\infty\) whenever \(X_*\) has a column that is
  active on those rows.
- **P3** The conditional Poisson log-pmf \(\sum(y\log\mu-\mu)\) is
  bounded above for fixed \(y\). Combined with P2, a soft
  \(+c P^*_{\mathrm{J}}\) term (maximisation scale) pulls away from the
  infinite-\(|\beta|\) all-zero MLE path in the same *qualitative* way
  Bernoulli Jeffreys pulls away from separation — **AGENT-INFERRED**
  analogy, not a transferred theorem.
- **P4** Exposure enters only through \(\mu=E\circ e^{\eta}\). Doubling
  every \(E\) at fixed \(\eta_{\mathrm{free}}\) doubles \(\mu\) and
  doubles \(I(\beta_*)\); it does **not** change the number of stacked
  rows. Using Bernoulli \(N_{\mathrm{eff}}=\#\{\text{rows}\}\) as the
  sole rate denominator would mis-scale designs that differ only by
  exposure.
- **P5** (log-det scaling, exact). For \(\varepsilon>0\),
  \(I(\varepsilon\mu)=\varepsilon I(\mu)\) and therefore
  \(P^*_{\mathrm{J}}(\varepsilon\mu)=P^*_{\mathrm{J}}(\mu)+\tfrac{p_*}{2}\log\varepsilon\)
  with \(p_*=\mathrm{ncol}(X_*)\). Near-zero deterioration is this
  identity, not a numerical coincidence (oracle E3).
- **P6** (all-zero log-pmf bound). For \(y\equiv 0\),
  \(\sum(y\log\mu-\mu)=-\sum\mu\le 0\), so the conditional Poisson
  kernel is bounded above by 0 and tends to 0 as \(\mu\to 0\). The
  Jeffreys atom, not the pmf, is what diverges to \(-\infty\) on that
  path (oracle E2).

Latent loading coercivity under Laplace is **OPEN**. The Bernoulli
radial atom is listed only as a forbidden transplant, not as a
candidate. The mean-model atom in this note is **fixed-only /
conditional** GLM information, evaluated at
\(\eta=X_{\mathrm{fix}}b_{\mathrm{fix}}+\mathrm{offset}\) before any
latent-score contribution — the same convention the live tape
records at `src/gllvmTMB.cpp` ("before any latent-score
contribution"). Laplace-marginal information for \(\beta\) is a
different object and remains **OPEN**. These oracles do not compute
it.

## 2. All-zero and near-zero count boundary mechanisms

### All-zero trait

For a trait with \(y_{\cdot t}\equiv 0\),

\[
\ell_t=-\sum_i\mu_{it}.
\]

The conditional MLE drives \(\mu_{\cdot t}\to 0\) (equivalently
\(\beta_t\to-\infty\) on an intercept-only trait design). Fisher
weights on those rows vanish with \(\mu\). Any soft penalty whose
fixed-effect atom is \(\tfrac12\log\det(X_*^\top W X_*)\) therefore
diverges to \(-\infty\) on that path when the trait’s design columns
remain in \(X_*\) (oracle E2). The same divergence holds
*trait-wise*: sending only trait A’s intercept to \(-\infty\) while
trait B stays healthy still drives \(P^*_{\mathrm{J}}\to-\infty\)
because trait A’s column remains in \(X_*\). Finiteness of a
penalised fit on all-zero data is necessary and **not** sufficient
for admission (programme §16).

### Near-zero counts

Sparse but non-zero counts (\(y\in\{0,1\}\) with rare ones) keep
\(\mu\) small on most units. Information remains \(O(\sum\mu)\), so
the same atom is soft rather than hard: it shrinks extreme negative
intercepts without erasing rare positive events. Oracles check the
monotone deterioration of \(P^*_{\mathrm{J}}\) as a positive mean is
scaled toward zero (E3), not a live recovery claim.

### Loading runaway (named, not solved)

On \(\log\mu=\eta_{\mathrm{fix}}+\lambda^\top u\), large \(\|\lambda\|\)
can send some units’ means to \(+\infty\) and others toward \(0\)
depending on the sign of \(u\). That is a *different* boundary from
Gaussian \(\psi\to 0\) and from Bernoulli separation. Design 88’s
\(V_{\mathrm{loading}}\) was built for the binary link-scale runaway.
**No Poisson loading atom is admitted in this note.** Oracle E7 only
shows that transplanting \(V_{\mathrm{loading}}\) is inert with respect
to \(\mu\) and therefore cannot be the all-zero information repair.

## 3. Exposure / offset versus information size

Write the linear predictor as

\[
\log\mu_{it}=o_{it}+\eta_{it}^{\mathrm{free}},\qquad o_{it}=\log E_{it},
\]

with known exposure \(E_{it}>0\). Then \(\mu=E\circ\exp(\eta^{\mathrm{free}})\).

| Quantity | What it is | What it is not |
|---|---|---|
| Exposure \(E\) | Known mean multiplier / offset | Sample size; penalty rate \(c\); \(N_{\mathrm{eff}}\) |
| Row count \(N_{\mathrm{rows}}\) | Number of stacked \((i,t)\) observations | Poisson information (unless \(\mu\) is order-1) |
| Information size | \(X_*^\top\operatorname{diag}(\mu)X_*\) (and \(\sum\mu\)) | \(\sum E\) alone, or Bernoulli \(N_{\mathrm{eff}}\) |

Oracle E4: at fixed free \(\eta\), replacing \(E\) by \(2E\) doubles
\(\mu\) and doubles every entry of \(I(\beta_*)\), while \(N_{\mathrm{rows}}\)
is unchanged. The transplanted rates
\(c_n=2\sqrt{p_{\mathrm{free}}/N_{\mathrm{rows}}}\) and
\(c_N=\sqrt{2/N_{\mathrm{rows}}}\) are **invariant** under that
exposure change, so they cannot be the Poisson information-size
knob. Oracle E5: absorbing \(\log E\) into the offset leaves
\(\mu\) unchanged when \(\eta^{\mathrm{free}}\) is reduced by
\(\log E\); the information atom tracks \(\mu\), not the spelling of
the offset. Dropping the offset without folding \(\eta\) changes
both \(\mu\) and \(I\).

Live Design 88 still fences *nonzero* offsets on the Bernoulli MSPL
surface. This prep cell records the exposure algebra for a *future*
Poisson route; it does not ask the prepare fence to accept offsets.

## 4. Why Bernoulli Jeffreys / \(V_{\mathrm{loading}}\) do not transfer

Design 88 (`docs/design/88-binary-mspl-estimator.md`) maximises

\[
Q_{LA}=\ell_{LA}
+c_n\tfrac12\log\det(X_*^\top W_g(\beta)X_*)
-c_n V_{\mathrm{loading}}
-c_n V_{\mathrm{covariance}},
\]

with Bernoulli weights \(W_g\) (logit \(\mu(1-\mu)\), probit, cloglog)
and

\[
V_{\mathrm{loading}}=\sum_t\bigl(\sqrt{1+\|\lambda_t\|^2}-1\bigr).
\]

Three transfer failures:

1. **Weights.** Poisson \(W=\operatorname{diag}(\mu)\) is not
   \(\mu(1-\mu)\) and not a probit/cloglog weight. Reusing the binary
   `W_g` path would be a wrong information matrix (oracle E1 contrast).
2. **Boundary object.** Bernoulli Jeffreys repairs *separation*
   (\(\mu\to 0\) or \(1\) with \(\|\beta\|\to\infty\)). Poisson all-zero
   repair is about \(\mu\to 0\) with unbounded-above means available
   elsewhere; the loading geometry on the log-mean scale is unproved.
3. **\(V_{\mathrm{loading}}\) is \(\mu\)-inert.**
   \(\partial V_{\mathrm{loading}}/\partial\mu\equiv 0\) (oracle E7). It
   cannot supply the all-zero information divergence.

Do not keep Bernoulli atoms “for symmetry with Design 88.”

## 5. Why Gaussian Hirose \(\Psi\) does not transfer

Phase 3 targets Heywood \(\psi_j\to 0\) in
\(\Sigma=\Lambda\Lambda^\top+\Psi\) with Hirose
\(V_H=\sum_j S_{jj}/\psi_j\). Ordinary Poisson GLLVM rows in this prep
cell are count means on the log link; they do not carry a free
Gaussian unique-variance coordinate. A \(1/\psi\) atom has no object.
Oracle E6 refuses Hirose-on-Poisson as a type error: there is no
\(\psi\) in the Poisson mean model, and fabricating one from
\(1/\mu\) silently renames the information problem without a proof.

## 5a. Kill list — fail the later derivation on any of these

1. Transplant of Bernoulli \(V_{\mathrm{loading}}\) without a Poisson
   Laplace coercivity proof.
2. Transplant of Bernoulli Jeffreys weights \(W_g\) (logit / probit /
   cloglog) in place of \(W=\operatorname{diag}(\mu)\).
3. Transplant of Gaussian Hirose / Akaike \(\Psi\) atoms, or any
   \(1/\psi\) term, into a Poisson ordinary cell that has no \(\Psi\).
4. Reuse of Bernoulli \(c_n=2\sqrt{p_{\mathrm{free}}/N_{\mathrm{eff}}}\) or
   Gaussian \(c_N=\sqrt{2/N}\) without a Poisson rate argument against
   the Laplace objective.
5. Treating exposure \(\sum E\) or row count as interchangeable with
   information size \(\sum\mu\).
6. Claiming Design 88 or Sterzinger–Kosmidis–Moustaki 2026 covers
   Poisson GLLVM MSPL under Laplace.
7. Finiteness of a count fit offered as the scientific result.
8. Mixed-family or NB1/NB2 inheritance (“Poisson worked, so NB does”).
9. Nonzero-offset admission smuggled in under “exposure.”
10. Any admission-shaped language (status flip to `admitted`, NEWS
    covered, validation-register promotion, C++ tape) ahead of the
    Shinichi gate.
11. Live `gllvmTMB(..., estimator = "mspl")` on Poisson in tests.
12. Quietly widening `.gllvmTMB_mspl_prepare()` beyond
    `family_id %in% {0,1,2}` (the #978 planned public door).

## 5b. Oracle contract E1–E7 (pure R; no Poisson `estimator="mspl"`)

| ID | What | Tolerance / decision |
|---|---|---|
| E1 | Poisson \(I=X^\top\operatorname{diag}(\mu)X\) (also \(X^\top W X\) with \(W=\mathrm{diag}(\mu)\)); PD; P1 continuity; Bernoulli \(W_g=\mu(1-\mu)\) **differs**, and is not even non-negative at typical Poisson \(\mu>1\) | rel. err \(<10^{-12}\) on Poisson; contrast fires |
| E2 | All-zero path: \(\beta\to-\infty\Rightarrow\mu\to 0\Rightarrow\operatorname{tr}(W)\to 0\Rightarrow P^*_{\mathrm{J}}\to-\infty\); P6 kernel \(-\sum\mu\le 0\); trait-wise vanishing of one intercept still diverges | monotone decrease; large negative; trait-B means stay \(O(1)\) |
| E3 | Near-zero: scale \(\mu\leftarrow \varepsilon\mu_0\) deteriorates \(P^*_{\mathrm{J}}\); **P5** \(I(\varepsilon\mu)=\varepsilon I(\mu)\), \(P^*_{\mathrm{J}}(\varepsilon\mu)=P^*_{\mathrm{J}}(\mu)+\tfrac{p_*}{2}\log\varepsilon\) | identity \(<10^{-12}\); monotone in \(\varepsilon\downarrow 0\) |
| E4 | Exposure doubling at fixed \(\eta\) doubles \(I\) and \(\sum\mu\); \(N_{\mathrm{rows}}\) fixed; \(\sum\mu\neq\sum E\) in general; Bernoulli \(c_n\) and Gaussian \(c_N\) **unchanged** | exact factor 2; rate contrast |
| E5 | Offset spelling: \(o=\log E\) vs folding \(\log E\) into \(\eta\) leaves \(\mu\) and \(I\) identical; dropping the offset without folding does **not** | \(<10^{-12}\); converse fires |
| E6 | Hirose \(\sum S/\psi\) is undefined / refused for Poisson mean model; \(1/\mu\) fabrication \(\neq P^*_{\mathrm{J}}\); Hirose \(\to+\infty\) as \(\psi\to 0\) while \(P^*_{\mathrm{J}}\to-\infty\) as \(\mu\to 0\) | structural reject; opposite-signed |
| E7 | \(\partial V_{\mathrm{loading}}/\partial\mu\equiv 0\); Poisson \(P^*_{\mathrm{J}}\) **does** move with \(\mu\); on the all-zero path \(V_{\mathrm{loading}}\) stays put while \(P^*_{\mathrm{J}}\) falls | finite-diff; path contrast |

## 6. Verdict

| Surface | Verdict | Why |
|---|---|---|
| Local R oracles / this writeup (E1–E7, kill list) | **PASS** | Information atom, all-zero / near-zero paths, and exposure≠information are testable without a Poisson MSPL fit. |
| C++ tape / live Poisson MSPL / flipping `planned` → `admitted` | **FAIL** | No tape, no prepare widening, no Shinichi admission gate. |
| NEWS / covered / SE / intervals | **FAIL** | Out of scope; SE remains PROTECTED on Codex Lane B. |

Preferred later-admission *candidate* for the fixed-effect slice:
Poisson Jeffreys-shaped \(\tfrac12\log\det(X_*^\top\operatorname{diag}(\mu)X_*)\),
with rate, loading atom, and Laplace-marginal \(I(\beta)\) still
OPEN. Not a theorem transfer.

## 7. Non-claims

This note does **not** claim:

- calibrated inference, SEs, profiles, or model comparison;
- a live Poisson `estimator = "mspl"` fit;
- that Bernoulli \(c_n\), \(V_{\mathrm{loading}}\), or Gaussian Hirose transfer;
- that Laplace is exact for Poisson (it is not);
- NB1 / NB2 / truncated Poisson / mixed-family MSPL;
- structured tiers (`phylo_*`, `spatial_*`, `animal_*`, `kernel_*`);
- that nonzero offsets are admitted;
- that EVA/VA is involved (it is not);
- that this atom is the Laplace-marginal information for \(\beta\).

## 8. What must exist before admission (unchanged programme gate)

1. Symbolic information atom and coercivity at all-zero / near-zero
   (this note + oracles) **and** a proved loading atom under Laplace.
2. Exposure vs information size pinned in the implemented rate
   (oracles E4–E5; rate choice still OPEN).
3. Healthy-regime no-harm vs LA-ML and boundary DGPs (not this run).
4. Family-specific TMB oracles after any tape (not this run).
5. Shinichi gate before `status` flips from `planned` to `admitted`.

## 9. Rose boundary

- **Not EVA / not VA.** Outer criterion is Laplace-ML plus a soft
  penalty yet to be taped.
- **`planned` ≠ `admitted`.** Poisson registry rows stay `planned`
  with `evidence = "phase4_prep"`.
- **Prepare fence is the #978 planned door.** `family_id` is
  `{0,1,2}`; this PR does not edit `R/mspl.R` and does not admit
  Poisson.
- **No C++.** `git diff -- src/` must stay empty on this arc.
- **No NEWS covered.** No validation-register promotion.
- **No repo-root `LOOP/`.** Lane kit:
  `docs/dev-log/lanes/cursor-mspl-phase4-poisson/LOOP/`.
  The earlier point-continue kit that first landed this note is
  historical; do not reopen it.

## Out of scope here

Campaigns, Totoro/DRAC, NEWS, register promotion, Phase 1B API,
interval lane, NB1/NB2, C++ tape, `estimator = "mspl"` on Poisson.

## 10. Strengthen pass (this lane)

Lane `cursor/mspl-phase4-poisson` did **not** admit Poisson and did
**not** add a new oracle ID. It pinned identities that the first
prep pass only sketched:

- E1 now checks the explicit \(X^\top\operatorname{diag}(\mu)X\)
  form, positive-definiteness, P1 continuity, and that Bernoulli
  \(W_g\) can be negative at Poisson means \(\mu>1\).
- E2 now tracks \(\mu\) and \(\operatorname{tr}(W)\), pins P6, and
  adds a two-trait all-zero path.
- E3 now asserts the exact P5 log-det scaling identity.
- E4 now refuses Bernoulli \(c_n\) / Gaussian \(c_N\) as
  exposure-blind rate transplants.
- E5 adds the converse (offset dropped, \(\eta\) not folded).
- E6 contrasts opposite-signed Hirose vs Jeffreys boundaries.
- E7 holds \(V_{\mathrm{loading}}\) fixed on the all-zero path.
- A read-only source pin records the #978 planned public door
  `family_id %in% {0,1,2}` (Poisson is `2`, not admitted).

Loading-atom coercivity under Laplace, the Poisson rate \(c\), and
Laplace-marginal information for \(\beta\), remain **OPEN**.
