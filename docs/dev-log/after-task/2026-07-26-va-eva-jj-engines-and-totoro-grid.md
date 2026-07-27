# After Task: VA / EVA / JJ evaluation tiers and the Totoro wide-condition grid

## Goal

Make VA and EVA work as **internal** fitting engines in gllvmTMB for Poisson,
Bernoulli and multi-trial binomial, verify them against `gllvm`, and run a
wide-condition comparison on Totoro producing an agreement/divergence map and
runtime scaling.

Authority: the recorded 2026-07-25 "stop designing, start coding" decision, plus
Shinichi's instruction this session to skip the AGHQ oracle ("it is proven
methods") and write no simulations or test suites in the research lane.

## Implemented

Three evaluation tiers behind one variational family (full-covariance Gaussian
`q(u_i) = N(m_i, S_i)`), selected by `eval_method`:

| tier | route | families |
|---|---|---|
| EXACT | closed form | Poisson `exp(mu + v/2)`, Gaussian |
| GH | 15-point Gauss-Hermite | binomial-logit |
| JJ | Jaakkola-Jordan closed form | binomial-logit |
| EVA | 2nd-order Taylor surrogate | binomial, Poisson |

Plus the R plumbing (`.va_r3_validate_data`, `.va_r3_fit`,
`.approximation_engine_va_r3_fit`, `.eva_fit`, `.eva_validate_data`) and a
data-accepting entry point for EVA, which had been fixture-name-only.

**Nothing is exported.** No `@export`, no `method=` argument, `NAMESPACE`
untouched, `src/gllvmTMB.cpp` untouched by this lane.

## Mathematical contract

At `eta_ij ~ N(mu_ij, v_ij)` with `mu = x'beta + lambda_j'm_i` and
`v = ||L_i' lambda_j||^2`, each tier evaluates `E_q[log p(y|eta)]`:

- Poisson EXACT: `y*mu - exp(mu + v/2) - lgamma(y+1)` (log-normal mean)
- Binomial GH: `logC + y*mu - n*E[softplus(eta)]` by quadrature
- Binomial JJ: `logC + (y - n/2)*mu - n*log(2*cosh(xi/2))`, `xi = sqrt(mu^2 + v)`
- EVA: `log p(y|mu) + (v/2) * d2/deta2 log p(y|eta)|_mu`

The objective is an ELBO, never a marginal likelihood; no `logLik`/AIC/BIC is
derived from it (Design 85 s10).

## Files changed

`inst/tmb/gllvmTMB_va_r3.cpp`, `inst/tmb/gllvmTMB_eva.cpp`,
`R/va-r3-proto.R`, `R/eva-proto.R`, `R/approximation-engine.R`,
`docs/design/104`-`108`, `dev/totoro-grid/`, `dev/controlled-gh-vs-jj.*`,
`dev/frontier/`, `dev/bound-vs-estimates.md`, `dev/poisson-health-diagnosis.md`.
Two test files were realigned by a separate sitting. Roadmap tick: N/A — no
public claim changed.

## Checks and results

**Cross-package agreement (640 cells, 2880 rows, Totoro, 64 workers, 5419 s):**

| comparison | median rel. diff | agree <1% |
|---|---|---|
| ours JJ vs `gllvm` VA (binomial) | 2.69e-07 | 100% |
| ours GH vs `gllvm` VA (Poisson) | 4.37e-09 | 99% |

**Bound ordering:** GH − JJ = +22.222 nats median (min +2.869, max +160.146),
correct sign in **320/320** cells. No inversion.

**Sign check** (matched models, `latent(..., unique = FALSE)` both sides):
Poisson ELBO −1201.8229 < Laplace −1200.6594; binomial −460.9790 < −456.4784.

**Silent-failure rate** (degenerate = rel. Frobenius > 10):

| arm | usable | degenerate | rate | reported OK anyway |
|---|---:|---:|---:|---:|
| `gtmb_gh` | 640 | 4 | 1% | **0** |
| `gtmb_jj` | 320 | 0 | 0% | 0 |
| `gllvm_va` | 600 | 0 | 0% | 0 |
| `gllvm_eva` | 300 | 203 | **68%** | **203** |
| `gtmb_laplace` | 601 | 70 | 12% | 59 |

**Runtime** (median s, q=2, n=400, p=8→80): `gtmb_gh` 12.3→127.3 (Poisson),
19.3→251.2 (Bernoulli); `gtmb_laplace` 0.66→25.6, 0.78→31.2; `gllvm_va`
4.7→36.7, 4.0→33.2.

## Consistency audit

```sh
git diff --stat origin/main...HEAD -- NAMESPACE   # empty
grep -rn "@export" R/va-r3-proto.R R/eva-proto.R R/approximation-engine.R
```
Verdict: no public surface in the diff; `NAMESPACE` byte-identical.

## Tests of the tests

The bound-ordering check is the load-bearing one: a looser bound *cannot*
legitimately score higher, so a single sign inversion would have falsified the
JJ implementation. It held 320/320. The sign check against a matched Laplace is
the second: an ELBO above its own Laplace value would indicate a likelihood bug,
not a tighter bound.

## What did not go smoothly

**Four claims were made and retracted.** Three were timing artefacts from the
same cause — a ~3x first-fit-in-session penalty (once a full TMB compile at
18.9 s) — asserted from single sequential passes: "H=15 is slower", "Poisson VA
is 10x slower than Laplace", and "quadrature order is not where the cost lives".
The fix is mechanical and now recorded in Design 104: **interleave replicates
and report objective evaluations alongside wall clock.**

The fourth was substantive. GH-VA recovered `Sigma_B` worse than JJ; I attributed
this to our cold start after finding that a three-line SVD of the residual
correlation beats our converged fit on 6/6 seeds. That start defect is real —
our loadings initialise at an arbitrary ±0.1 while `gllvm` uses a factor-analytic
warm start — but it does **not** explain the gap: cross-evaluating the GH
objective at JJ's optimum gives `f_GH(theta_A) < f_GH(theta_B)` on 6/6 seeds, so
GH finds a genuinely better GH optimum and still recovers worse.

A stated prediction also failed: I predicted `gtmb_laplace` would show the
highest degenerate rate. At scale it is 12%, second to `gllvm_eva`'s 68%. The
earlier 50% figure was a small-n artefact.

## Team learning

**Polya** (new roster member) established with citations that Jaakkola-Jordan
*is* Polya-Gamma mean-field VB and that both are strictly looser than
Gauss-Hermite — then verified from `gllvm` 2.0.13's own source
(`src/gllvm.cpp:3271-3273`) that its binomial `method="VA"` *is* that bound.
Naming the arm JJ rather than VA is what stopped "EVA looks better than VA" from
becoming a conclusion.

**Ranganathan's** prior-art sweep found the headline claim was not novel:
quadrature-beats-JJ is published from 2011 (Knowles & Minka; Marlin/Khan/Murphy;
Tiao). What is unfound is that comparison *inside a GLLVM* — both GLLVM papers
explicitly call quadrature impractical. Running that sweep before writing
anything saved a claim a referee would have dismantled.

**Proposition 2** (structural design): a zero off-diagonal block of `S` is
*exactly* optimal — not an approximation — iff every observation's loading is
supported in one group and the prior precision is block-diagonal on the same
partition. On Ayumi's model that is a 7.25x parameter reduction bought with a
proof.

The **smoke test earned its cost**: it caught that `gllvm` EVA does not support
Poisson, that `extract_Sigma_B()` returns a list rather than a matrix (every
Laplace recovery row would have been `NA`), and a degenerate EVA fit reporting
`converged`.

## Known limitations and next action

- The wide grid ran on the **pre-fix** build w.r.t. the binary/OLRE logLik defect
  merged to `main` as `c3d11667`. Verified not to matter here: the
  `unique = FALSE` Laplace path sets `use_diag_B = 0` and never enters the buggy
  branch, returning sane negative logLik on both families.
- `gtmb_laplace`'s `Sigma_B` may carry a link-implicit residual on its diagonal,
  so its recovery column is **indicative, not like-for-like**. Every row carries
  that note.
- **EVA binomial fails its health gate in 20/20 seeds** — a genuine property of
  the Taylor-2 objective (C++ gradient verified against finite differences to
  7.9e-9), not a wiring bug.
- The **cold-start defect is unfixed**: a factor-analytic warm start is the
  single highest-value outstanding item.
- This lane is based on `dc79753a`; `main` has moved to `c3d11667` and a rebase
  is required before it is mergeable.
- **Nothing here is a public or capability claim.** VA/EVA remain internal
  research; 0.6 ships Laplace-only.

## GitHub issue ledger

No issue was filed, commented on, or closed by this lane. The binary/OLRE defect
found here was handed to a separate lane and merged as `c3d11667` (PR #796); its
NEWS entry and public issue remain maintainer calls.
