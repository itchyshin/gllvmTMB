# Audit — `profile_ci_correlation()` operates on $\Sigma_\text{shared}$, not $\Sigma_\text{total}$

**Date**: 2026-05-17
**Auditor**: Fisher (inference); Boole (extractor surface); Ada (close gate)
**Triggered by**: M1.4 finding (PR #153) — on a rank-1 latent fit, `profile_ci_correlation()` returns point estimates of $\pm 1$ while `fisher-z` / `wald` return correlations adjusted for the per-trait link residual.

This audit documents what the divergence means + the design choice
behind it, so future M1+ work knows whether to fix the
`profile_ci_correlation` surface or leave it.

## §1 — The two surfaces

`extract_correlations(method = ...)` exposes four CIs, but they
operate on **two different objects**:

| Method | Surface | Computes |
|---|---|---|
| `fisher-z` (= `wald`) | $\Sigma_{\text{total}}$ with link_residual | Fisher-z CI on $r = \mathrm{cov2cor}(\Sigma_{\text{total}})[i,j]$ |
| `profile` | $\Sigma_{\text{shared}}$ (no link_residual, no Ψ) | Profile-likelihood CI on $r = \mathrm{cov2cor}(\Lambda\Lambda^\top)[i,j]$ |
| `bootstrap` | $\Sigma_{\text{total}}$ via per-refit $\mathrm{cov2cor}$ | Empirical quantiles of $r$ across refits |

`fisher-z` and `bootstrap` target the **same** quantity (the
correlation on the observable latent scale, with link residual
added). `profile` targets a **different** quantity — the
correlation implied by the rank-$d$ factor structure $\Lambda\Lambda^\top$
alone, *without* the link-residual or trait-specific $\Psi$
contribution.

## §2 — Why `profile_ci_correlation` operates on $\Sigma_\text{shared}$

The profile-likelihood machinery for correlations
(`R/profile-derived.R`'s `profile_ci_correlation()`) constructs
the profile around a **rotation-invariant target** — the
sub-block of $\Lambda\Lambda^\top$. The Lagrange-style
fix-and-refit on a single correlation entry can be parametrised
in terms of $\Lambda$ entries directly. Including the link
residual or $\Psi$ in the target would require profiling on
a different (and less natural) Lagrange constraint involving
both $\Lambda$ and the dispersion parameters.

Pros (the design's intent):
- **Rotation-invariant**: the profile target is the
  $\Lambda\Lambda^\top$ inner product, which is invariant to
  varimax / quartimax / orthogonal rotations of $\Lambda$.
- **Numerically stable**: the Lagrange constraint is a
  smooth function of $\Lambda$ entries; no link-function
  derivative chain through dispersion parameters.

Cons (the design's cost):
- **Disagrees with fisher-z / wald / bootstrap on rank-1
  latent fits** (and any fit where $\Lambda\Lambda^\top$ is
  close to rank-deficient): the shared correlation is $\pm 1$
  deterministically on rank-1, while $\mathrm{cov2cor}(\Sigma_\text{total})$
  is bounded away from $\pm 1$ by the link residual.
- **Hidden surface choice**: users who type
  `method = "profile"` thinking they will get the same
  point estimate as the default but with a tighter CI are
  surprised when the point estimate itself shifts.

## §3 — What the M1.4 finding actually surfaced

The M1.4 test on the 3-family fixture (T=3, d=1):

```
fisher-z point: 0.195, -0.299, -0.058
profile point: 1.000, -1.000, -1.000    ← rank-1 Σ_shared correlations
```

The profile point estimates are **mathematically correct for what
they target**: on a rank-1 $\Lambda$, every off-diagonal of
$\mathrm{cov2cor}(\Lambda\Lambda^\top)$ is $\mathrm{sign}(\Lambda_i \Lambda_j) \cdot 1$.

But that's not what users expect when they ask for "the
correlation between trait $i$ and trait $j$". They expect the
correlation on the *observable latent scale*, which is what
fisher-z / wald / bootstrap return.

## §4 — Three options

**(a) Keep the surface mismatch + document it.** Add a docstring
note to `profile_ci_correlation()` (and `extract_correlations(method = "profile")`) explaining the surface choice. Recommend
`fisher-z` for "the correlation on the observable latent scale"
and `profile` for "rotation-invariant profile-likelihood CI on
the rank-$d$ factor structure" (a less common use case). Low cost;
preserves the existing profile machinery.

**(b) Re-implement profile on $\Sigma_\text{total}$.** Build a new
Lagrange constraint that fixes a single $(i,j)$ entry of
$\Sigma_\text{total} = \Lambda\Lambda^\top + \mathrm{diag}(\Psi)
+ \mathrm{diag}(\sigma^2_d)$ at a candidate value, then profile
the likelihood. More work; needs careful derivative chains
through dispersion parameters; the link-residual is family-
specific so the constraint shape varies. Higher cost; better
alignment with user expectations.

**(c) Hybrid**: default `method = "profile"` redirects to
`fisher-z` (the most-aligned closed-form), and the
$\Sigma_\text{shared}$-profile becomes an opt-in
`method = "profile-shared"`. Backward-compat warning emitted
for the old `method = "profile"` shape.

## §5 — Recommendation

**(a) for now, (b) at M3.** The surface mismatch is a real
design tension but reimplementing profile on $\Sigma_\text{total}$
is M3 inference-completeness work (parallel with the coverage-
study + per-family CI accuracy validation). For M1.8 close: keep
the existing `profile_ci_correlation` surface, add the docstring
note, surface the choice to users.

**Future M3 slice scope** (when scheduled): re-implement
profile_ci_correlation on $\Sigma_\text{total}$ with full
Lagrange-on-link-residual chain. Add a coverage study comparing
profile-on-shared vs profile-on-total vs fisher-z vs bootstrap
on the family × $d$ × $n_\text{sites}$ grid. Document which
surface is canonical for the package.

## §6 — Immediate action (this PR)

- **No code change** to `profile_ci_correlation`.
- **Update M1.4 test docstring** in
  `tests/testthat/test-m1-4-extract-correlations-mixed-family.R`
  to note the surface divergence is by design, not a bug.
- **Add register entry**: CI-04 (extract_correlations 4 methods)
  note now reads: "`profile` operates on $\Sigma_\text{shared}$ —
  rotation-invariant rank-$d$ target. fisher-z / wald / bootstrap
  operate on $\Sigma_\text{total}$. See
  `docs/dev-log/audits/2026-05-17-profile-correlation-surface.md`."
- **Future docstring update** for `profile_ci_correlation` and
  `extract_correlations()`: explain the surface choice + cross-
  link this audit. Filed as a small follow-up PR (or folded into
  the M3 reimplementation when that happens).

## §7 — Cross-references

- `R/extract-correlations.R:151` — `extract_correlations()` entry.
- `R/profile-derived.R` — `profile_ci_correlation()` source.
- `tests/testthat/test-m1-4-extract-correlations-mixed-family.R` — M1.4 surfaced this divergence.
- `docs/dev-log/audits/2026-05-17-link-residual-design-decision.md` — parallel design audit on the link residual conventions.
