# Gaussian MSPL — which Ψ the theorem targets in gllvmTMB coords

**Status:** decision note closing the Opus/Sol OPEN GATE from
`docs/dev-log/research/2026-08-15-mspl-phase3-gaussian-heywood-prep.md`
§5c. **Not an admission.** No C++. No `planned` → `admitted`. No NEWS.

**Reader:** method developer / TMB engineer who must name the
Heywood coordinate before any Gaussian `estimator = "mspl"` tape.

**Paper:** Sterzinger, Kosmidis & Moustaki (2026), *Psychometrika*,
[doi:10.1017/psy.2026.10092](https://doi.org/10.1017/psy.2026.10092).
Classical EFA: \(\operatorname{Cov}(Y)=\Lambda\Lambda^\top+\Psi\) with
diagonal \(\Psi=\operatorname{diag}(\psi_j)\). Soft atoms (3.2)/(4.1)
are functions of that \(\Psi\) (Hirose preferred; Akaike sibling).

This is **LA-MSPL**, not EVA, not AGHQ-MSPL.

## 1. Three candidate maps (the gate)

Live Gaussian / lognormal observation noise is one shared scalar
(`log_sigma_eps` → \(\sigma_\varepsilon^2\)). The unit-tier unique
companion under `latent(..., unique = TRUE)` is per-trait
`sd_B(t)^2=\exp(2\cdot\theta_{\mathrm{diag},B}(t))`. Paper \(\Psi\)
is a single diagonal. The three named options:

| ID | Map | Claim |
|---|---|---|
| A | \(\psi_j \leftarrow sd_B(j)^2\) while \(\sigma_\varepsilon\) free | Treat the random-block diagonal alone as paper \(\Psi\). |
| B | \(\psi_j \leftarrow \psi_j^{\mathrm{total}}=sd_B(j)^2+\sigma_\varepsilon^2\) | Treat the *identified* unique share of \(\Sigma\) as paper \(\Psi\). |
| C | **Pinned FA** — map \(\sigma_\varepsilon\) off (or fix tiny) so \(\psi_j \leftarrow sd_B(j)^2\) | Exact classical FA cell in package coords. |

## 2. Sol-level arithmetic

### 2.1 Marginal object the theorem sees

For a complete stacked Gaussian GLLVM with one observation per
\((\mathrm{unit},\,\mathrm{trait})\), the unit-tier trait covariance
that enters the Laplace/FA story is

\[
\Sigma
=
\Lambda\Lambda^\top
+
\operatorname{diag}\bigl(sd_B(1)^2,\ldots,sd_B(p)^2\bigr)
+
\sigma_\varepsilon^2 I_p.
\]

(Oracle E5 already encodes this as
`tcrossprod(Lambda) + diag(sd_B2 + sigma_eps2)`.)

Classical FA writes the same matrix as
\(\Lambda\Lambda^\top+\Psi\). Therefore the **identified** paper
diagonal is always the sum:

\[
\Psi_{\mathrm{paper}}
=
\operatorname{diag}(\psi^{\mathrm{total}}),
\qquad
\psi_j^{\mathrm{total}}
=
sd_B(j)^2+\sigma_\varepsilon^2.
\]

Bare \(sd_B^2\) equals paper \(\Psi\) **if and only if**
\(\sigma_\varepsilon^2=0\) (or is pinned so small that it is a
numerical floor, not a free share).

### 2.2 Flat ridge (why A fails while \(\sigma_\varepsilon\) is free)

For any \(c\) with \(0\le c\le\min_j sd_B(j)^2\),

\[
sd_B(j)^2 \leftarrow sd_B(j)^2-c,
\qquad
\sigma_\varepsilon^2 \leftarrow \sigma_\varepsilon^2+c
\]

leaves \(\Sigma\) bit-identical. Likelihood is flat on that ray.
Hirose / Akaike atoms on \(\psi^{\mathrm{total}}\) are invariant along
the ray (E5). Atoms on bare \(sd_B^2\) **move** along the ray (E5
`expect_false`).

Consequence for option A with free \(\sigma_\varepsilon\): a penalty
written on \(sd_B\) alone is **100% penalty-determined** on a
likelihood-flat direction (Hao falsifier / kill-list item 5–7). That
is not a soft-rate estimator; it is a prior on an unidentified split.

### 2.3 Why B is identified for Heywood but not for the split

Penalising \(\sum_j S_{jj}/\psi_j^{\mathrm{total}}\) (Hirose) or
\(\sum_j \|\lambda_j\|^2/\psi_j^{\mathrm{total}}\) (Akaike) is
invariant to the A-ridge and blows up as any
\(\psi_j^{\mathrm{total}}\to 0\). So B is the right *scientific*
Heywood object whenever \(\sigma_\varepsilon\) is free.

It does **not** identify \((sd_B,\sigma_\varepsilon)\). A later tape
that keeps both free must either reparameterise
\((\psi^{\mathrm{total}},\mathrm{share})\) or accept a flat nuisance
direction orthogonal to Heywood. That is a separate engineering
slice, not required to transfer the paper theorem.

### 2.4 Live package already prefers C on the ordinary cell

`R/fit-multi.R` Q7 (≈4884–4906): when a diagonal term is at
per-row resolution (`per_row_diag_B` / `per_row_diag_W`),
`log_sigma_eps` is **mapped off** and fixed at
\(\approx 10^{-3}\mathrm{sd}(y)\). For complete long data with one
row per \((\mathrm{unit},\,\mathrm{trait})\) and
`latent(..., unique = TRUE)`, `length(unique(trait_id, site_id)) == n_obs`,
so Q7 fires.

Under that live pin,

\[
\Psi_{\mathrm{paper}}
\;\approx\;
\operatorname{diag}(sd_B^2),
\]

with \(\sigma_\varepsilon\) a tiny numerical floor, not a free
Heywood competitor. This is option **C** in the coords the first
matched Gaussian cell would actually fit.

(If someone later admits repeated measures or forces a free
\(\sigma_\varepsilon\), the theorem target switches to B’s
\(\psi^{\mathrm{total}}\) — see §4.)

## 3. Recommended pick (binding for later derivation)

**Primary (Phase 3 first Gaussian cell):** option **C —
pinned-σ_ε exact-FA route.**

- Grammar: ordinary `latent(..., unique = TRUE)` on complete
  Gaussian identity data where Q7 maps `log_sigma_eps` off (or an
  explicit map that sets \(\sigma_\varepsilon=0\) / tiny floor).
- Paper coordinates: \(\psi_j \equiv sd_B(j)^2\).
- Soft atom: Hirose[\(N^{-1/2}\)] primary; Akaike sibling; Jeffreys
  dropped (prep note §5b).
- Rate: \(c_N=\sqrt{2/N}\) with \(N=\) number of units
  (AGENT-INFERRED, unchanged).
- Oracles continue on the textbook triple \((\Lambda,\psi,S)\); under
  C, \(\psi\) is literally `sd_B^2`.

**Rejected as first-cell target:** option **A with free
\(\sigma_\varepsilon\)** — fails §2.2.

**Deferred (not rejected):** option **B** for a later free-ε /
repeated-measure Gaussian MSPL cell. Requires an explicit
reparameterisation or a named flat nuisance, plus a separate
Shinichi gate. Do not pretend B is what Q7 already fits.

## 4. What this does / does not authorise

**Does:**

- Name which Ψ the Sterzinger–Kosmidis–Moustaki coercivity argument
  is allowed to talk about in this package.
- Keep textbook oracles on \((\Lambda,\psi,S)\) honest under C.
- Unblock *design* work toward a later C++ atom that adds
  \(c_N\sum_j A_{jj}/\psi_j\) with \(\psi=sd_B^2\) under the pin.

**Does not:**

- Flip registry `gaussian:*` from `planned` to `admitted`.
- Touch `src/`.
- Call `gllvmTMB(..., estimator = "mspl")` on Gaussian.
- Resolve #856 as a package-wide redesign of shared
  `log_sigma_eps` for lognormal / mixed rows — out of scope; the
  pin is cell-local.
- Authorise NEWS, campaigns, or interval/SE work (Codex Lane B
  remains PROTECTED).

## 5. STOP before C++?

**Ambiguity for the first matched cell: CLOSED** under pick C.
A later C++ / admission gate still needs Shinichi yes, but it no
longer needs to reopen “which Ψ?” for the ordinary pinned FA cell.

Still STOP before C++ until an explicit new yes covering: tape
change, registry flip, and healthy / near-Heywood recovery evidence
plan. This note only clears the uniqueness map.

## 6. Cross-refs

- Prep + kill list:
  `docs/dev-log/research/2026-08-15-mspl-phase3-gaussian-heywood-prep.md`
- Oracles: `tests/testthat/test-mspl-gaussian-heywood-oracles.R` (E5)
- Q7 pin: `R/fit-multi.R` (~4884–4906)
- Programme:
  `docs/dev-log/after-task/2026-08-14-laplace-mspl-estimator-programme.md`
- Protected SE lane: `codex/lane-b-mspl-interval-feasibility`
