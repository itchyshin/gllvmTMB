# Gamma / lognormal LA-MSPL — oracle-pinned \(c\) and loading atoms

**Date:** 2026-08-16
**Track:** overnight close of OPEN items from
`docs/dev-log/research/2026-08-16-mspl-gamma-lognormal-door-gap.md`
(#1051)
**Workspace:** `/private/tmp/gllvmtmb-mspl-gamma-lnorm-atoms`
**Status:** pure-R Phase-4 pin only. No prepare widen. No `src/`
tape. No admit. No NEWS `covered`. No public `se=TRUE`.

**Reader:** the next MSPL conductor who must not open a
`#1007`-shaped door until these formulas exist as oracles.

This is **LA-MSPL**. Formulas that are not textbook GLM information
are **AGENT-INFERRED**. They pin oracles. They do not license a
tape.

---

## What #1051 left OPEN

The door-gap note already had READY weights:

- Gamma \(W=\phi_\gamma\) (mean-inert)
- lognormal \(W=1/\sigma_\varepsilon^2\) on \(\log y\) (mean-inert)

and left **G-c / L-c** (soft rate) and **G-λ / L-λ** (loading
atom) OPEN. A `#1007` mirror would have inherited unpinned
\(c=1\) and Bernoulli \(V_{\mathrm{loading}}\). Both prep notes
kill those transplants.

This sitting pins the two OPEN objects in pure R. It does **not**
close G-φ / L-σ, L-mix, I-LA, the door, the curvature pin, or
admission.

---

## Pinned soft rates

Information size is the named diagnostic from the prep notes, not
row count and not a count event total.

\[
c_\Gamma=2\sqrt{\frac{p_{\mathrm{free}}}{\max(n\phi_\gamma,1)}},
\qquad
c_L=2\sqrt{\frac{p_{\mathrm{free}}}{\max(n/\sigma_\varepsilon^2,1)}}.
\]

The leading \(2\) matches the live Bernoulli / Poisson tape
convention, not the 2023 paper’s \(\sqrt{2p/n}\). Do not silently
switch constants.

| Kill | Formula | Why it is not this cell |
|---|---|---|
| \(c=1\) | unit placeholder | Live non-Bernoulli / non-Poisson default. Not science. |
| \(c_n\) | \(2\sqrt{p_{\mathrm{free}}/N_{\mathrm{rows}}}\) | Row count \(\neq n\phi\) and \(\neq n/\sigma^2\). |
| \(c_N\) | \(\sqrt{2/N}\) | Gaussian Phase-3 rate. Wrong constant and wrong \(N\). |
| \(c_P\) | \(2\sqrt{p_{\mathrm{free}}/\max(\sum y,1)}\) | Event count is a Poisson proxy. Gamma has \(\Pr(Y=0)=0\). |

Floors: \(n\phi_\gamma<1\) or \(n/\sigma_\varepsilon^2<1\) maps
the denominator to 1, so the rate stays finite when information
vanishes (\(\phi\to 0\) or \(\sigma\to\infty\)). The rate
vanishes as information grows. Doubling \(\mu\) (Gamma) or
\(\eta\) (lognormal) does not move \(c\).

Toy-fixture collisions (do not use them as science):
\(2\sqrt{2/(4\cdot 2)}=1\), and
\(2\sqrt{2/(4/0.5^2)}=\sqrt{2/4}=c_N(n=4)\). Contrast oracles
use a second \((p,n)\) block.

---

## Pinned loading atoms

Weight the radial term by the **family** information weight. Do
not copy Bernoulli \(V_{\mathrm{loading}}\) (inert in
\((\mu,\phi)\) and \((\eta,\sigma)\)) and do not import Hirose
\(\Psi\).

\[
V_\lambda^\Gamma=\sum_t\bigl(\sqrt{1+\|\lambda_t\|^2\phi_t}-1\bigr),
\qquad
V_\lambda^L=\sum_t\bigl(\sqrt{1+\|\lambda_t\|^2/\sigma_\varepsilon^2}-1\bigr).
\]

| Property | Gamma \(V_\lambda^\Gamma\) | lognormal \(V_\lambda^L\) |
|---|---|---|
| Weight | per-trait \(\phi_t\) | shared \(\sigma_\varepsilon\) |
| \(\phi=1\) / \(\sigma=1\) | recovers Bernoulli radial | recovers Bernoulli radial |
| Information \(\to 0\) | \(\phi\to 0\Rightarrow V\to 0\) | \(\sigma\to\infty\Rightarrow V\to 0\) |
| \(\|\lambda\|\to\infty\) at \(W>0\) | coercive | coercive |
| Mean / \(\eta\) | inert | inert |
| Hirose \(\sum S/\psi\) | type error | type error |
| Poisson \(\bar y_t\) weight | type error | type error |

Jeffreys-on-\(\beta\) owns the information-collapse path
(\(\phi\to 0\), \(\sigma\to\infty\)). The loading atom is silent
there, the same way Poisson \(V_\lambda^P\) is silent on
all-zero traits.

Numerically \(V_\lambda^L(\sigma)=V_\lambda^\Gamma(\phi=1/\sigma^2)\)
when \(\phi\) is that constant. That is an alias, not inheritance:
lognormal’s residual is shared; Gamma’s shape is per-trait; the
means \(\mathrm{e}^{\eta}\) and \(\mathrm{e}^{\eta+\sigma^2/2}\)
are different scientific objects.

---

## Oracle contract (this sitting)

| ID | Family | What |
|---|---|---|
| E11 | both | Rate uses the named information size; \(c_n\), \(c_N\), \(c_P\), \(c=1\) differ |
| E12 | both | Floor at info \(<1\); vanishes as info grows; mean / \(\eta\) inert |
| E13 | both | Weight \(=1\) recovers Bernoulli; information \(\to 0\) silences \(V\) |
| E14 | both | Coercive as \(\|\lambda\|\) grows at \(W>0\); silent at \(W=0\) |
| E15 | both | Family \(V\) is dispersion-aware; Bernoulli \(V\) is not |
| E16 | both | Not Hirose; not Poisson \(\bar y\); not \(c_N\) |

Helpers stay in the Phase-4 oracle files. No `R/mspl-*-atoms.R`.
No live `estimator = "mspl"`.

---

## Still OPEN

| ID | Object | Why it stays OPEN |
|---|---|---|
| G-φ | \(\tfrac12\log I_{\phi\phi}\) | Rewards \(\phi_\gamma\to 0\). Not a shape-collapse repair. |
| L-σ | residual atom beyond \(c_L\) / \(V_\lambda^L\) | \(\beta\)-atom rewards \(\sigma\to 0\). No dedicated repair. |
| L-mix | shared `log_sigma_eps` with Gaussian | Phase-6 composition. Single-family pin does not solve it. |
| I-LA | Laplace-marginal \(I(\beta)\) | Atom is still fixed-only / conditional GLM-outer. |
| Door | prepare `family_id` 3 / 4 | Shinichi gate. Oracle E10 still forbids the widen. |
| Tape | `src/` GLM-outer weight | Do not tape until a later G0 on the door. |
| Admit | `planned` → `admitted` | Not this sitting. |

---

## HARD STOP

planned → admitted · NEWS covered · public `se=TRUE` · prepare
widen to 3 or 4 · `src/` GLM-outer tape · `#1000` un-skip ·
Codex Lane B absorb · inherit \(c=1\) or Bernoulli
\(V_{\mathrm{loading}}\)
