# DRAFT — public wording for a possible `Sigma_unit_diag` coverage-certificate flip

**Status: DRAFT ONLY. No public file has been edited.** This is Rose's (claims/scope
reviewer) proposed wording for Shinichi to approve, edit, or reject. It must not be
copied onto any public surface until (a) the n_sim ≥ 5000 gaussian-n≥150 confirmation
run lands and the `{{GAUSS_N150_COVERAGE}}` placeholder is filled with the confirmed
number, and (b) Shinichi signs off on the flip itself.

## Sources consulted

- `docs/dev-log/handover/2026-07-16-claude-handover-coverage-landed.md` — the scoped
  claim: Totoro n_sim=1000 grid, gaussian n≥150 profile coverage 0.939/**0.950** (d1),
  0.939/**0.948** (d2); binomial 0.765–0.916; D-43 panel (Rose/Curie/Fisher) — gaussian
  n≥150 DEFENSIBLE (Curie holds out for n_sim≥5000 confirm), binomial WITHHELD 3/3.
- `docs/dev-log/after-task/2026-07-16-sigma-total-variance-profile-wald-build.md` §8–9 —
  same numbers plus the miss-direction detail (gaussian misses now roughly balanced
  across both tails vs the old bootstrap's ~10:1-above; binomial too-narrow at the
  ψ=0 boundary).
- `R/z-confint-gllvmTMB.R` lines 1312–1400 — current `confint()` roxygen (the
  `@details`/`@param` block this draft's sentence would extend).
- `R/profile-derived.R` lines 644–802 — `.total_variance_spec()` / `.profile_ci_total_variance()`
  comments: the estimand is `V_t = (ΛΛ')_tt + ψ_t`, the **diagonal** of `Sigma_unit`
  (per-trait total variance), not off-diagonal covariance entries — those still fall
  back to bootstrap per the existing roxygen at line ~1354.
- `docs/dev-log/capability-surface.html` lines 447 (gap-box bullet) and 472–479
  (Intervals-section lead) — current public wording this draft would replace.
- `NEWS.md` lines 33–68 (`## Changed`) — voice/format model for the NEWS bullet.
- `CLAUDE.md` — "reader-facing content shows only what makes sense to the reader —
  no internal register codes on any surface." No D-43, no "Lane A/B/C", no
  "certificate candidate" internal labels, no estimand codenames in any block below.

## Scope reminder (what this flip covers and does NOT cover)

The estimand is the **diagonal of `Sigma_unit`** — the per-trait total variance
`V_t = (loadings contribution) + (diagonal/residual contribution)` — for **Gaussian
responses at n ≥ 150 grouping units** only. It does **not** cover: `Sigma_unit`
off-diagonal (covariance) entries, `Sigma_unit_obs`, `Sigma_cluster`/`Sigma_cluster2`,
`Lambda`, `icc`, `phylo_signal`, correlations/`rho`, communality, proportions, or any
non-Gaussian family. Every wording block below is written to keep that scope explicit
rather than implying a package-wide interval-coverage claim.

---

## (1) Capability / mission-control widget — paste-ready block

Two locations in `docs/dev-log/capability-surface.html` reference this claim. Both
need the same scoped update.

### 1a. Gap-box bullet (currently line 447, "Interval coverage — the headline gap")

```html
<li><b>Interval coverage.</b> One target now has a coverage certificate: the profile-likelihood
interval on the per-trait total variance (<code>Sigma_unit</code> diagonal) for <b>Gaussian
responses with at least 150 grouping units</b> achieves nominal two-sided coverage
({{GAUSS_N150_COVERAGE}} against a 0.95 target), confirmed by repeated-sampling simulation.
Every other cell remains uncertified: Gaussian fits with fewer than 150 units, binomial,
negative-binomial (<code>nbinom2</code>), and ordinal responses all stay recovery-grade /
approximately-calibrated, not nominal-certified — the binomial route in particular sits well
below nominal near the zero-variance boundary. <code>Sigma_unit</code> off-diagonal
(covariance) entries and every other Sigma tier are unaffected by this certificate and remain
point-only.</li>
```

### 1b. Intervals-section lead paragraph (currently lines 472–479)

```html
<p class="lead">
  The honesty boundary. A route that returns bounds is <b>not</b>, by itself, evidence of
  nominal repeated-sampling coverage. Extraction is point-only by default.
  <b>One cell is certified by repeated-sampling simulation:</b> the profile-likelihood
  interval on the Gaussian <code>Sigma_unit</code> diagonal (per-trait total variance),
  restricted to fits with at least 150 grouping units, reaches nominal two-sided coverage
  ({{GAUSS_N150_COVERAGE}} against 0.95). Binomial, <code>nbinom2</code>, and ordinal
  <code>Sigma_unit_diag</code> intervals, and Gaussian fits below 150 units, remain
  recovery-grade / approximately-calibrated — <b>no other cell is nominal-certified.</b>
</p>
```

---

## (2) NEWS bullet — paste-ready block

Placement note: this belongs under a `## Changed` (or `## Fixed`, if framed as
replacing the earlier NA/bootstrap-fallback route) heading in whichever release
actually ships the flip — the current top-of-file header is `# gllvmTMB 0.5.0`
(0.5 is the non-released dev cycle per `CLAUDE.md`), so this bullet is drafted
generically and needs a version-header decision at insertion time.

```markdown
* `confint(fit, parm = "Sigma_unit")` now returns a genuine profile-likelihood
  interval for the per-trait total variance (the diagonal of `Sigma_unit`,
  combining the loadings and diagonal/residual contributions) when the response
  is Gaussian and the grouping level has at least 150 units. Repeated-sampling
  simulation confirms nominal two-sided coverage ({{GAUSS_N150_COVERAGE}} against
  a 0.95 target), with misses roughly balanced across both tails. Gaussian fits
  with fewer than 150 units, and binomial, `nbinom2`, and ordinal responses, are
  not covered by this certificate: they continue to return the previous
  uncalibrated / bootstrap-fallback route, and `Sigma_unit` off-diagonal
  (covariance) entries are unaffected.
```

---

## (3) `confint()` help / roxygen — paste-ready sentence(s)

Insertion point: end of the `@details` block in `R/z-confint-gllvmTMB.R`, directly
after the existing paragraph ending "...inspect the returned method and the
target-specific article before reporting bounds." (line ~1340), before the
"Main parm-class dispatch paths" itemize block.

```
#' For \code{parm = "Sigma_unit"} with \code{method = "profile"}, the diagonal
#' entries (the per-trait total variance) carry a coverage certificate for
#' Gaussian responses fitted with at least 150 grouping units: repeated-sampling
#' simulation confirms nominal two-sided coverage ({{GAUSS_N150_COVERAGE}} against
#' a 0.95 target). This is currently the only \code{confint()} target with a
#' coverage certificate. Gaussian fits with fewer than 150 units, and binomial,
#' \code{nbinom2}, and ordinal responses, do not carry this certificate and
#' should still be treated as recovery-grade / approximately-calibrated.
#' \code{Sigma_unit} off-diagonal (covariance) entries fall back to bootstrap
#' regardless of family, as described above, and are not covered by this
#' certificate either.
```

---

## STAYS FENCED / NOT ADVERTISED (no change to public claims)

- **Binomial `Sigma_unit_diag`** — best cell 0.916 (n≥150), roughly 5 SE below
  nominal, too-narrow at the ψ = 0 (zero-variance) boundary. Fenced.
- **`nbinom2` `Sigma_unit_diag`** — not certified; shared-dispersion Σ recovery
  unresolved. Fenced.
- **Ordinal `Sigma_unit_diag`** — not certified. Fenced.
- **Gaussian `Sigma_unit_diag`, n = 50** — 0.939, a benign small-sample shortfall,
  not the boundary pathology seen in binomial; still not certified.
- **`Sigma_unit` off-diagonal (covariance) entries** — nonlinear function of
  rotation-equivalent loadings and diagonal Ψ; still falls back to bootstrap,
  unaffected by this certificate.
- **Every other `confint()` target** — `Sigma_unit_obs`, `Sigma_cluster` /
  `Sigma_cluster2`, `Lambda`, `icc`, `phylo_signal`, correlations (`rho`),
  communality, proportions — unchanged: point-only, uncalibrated, or
  target-specific bootstrap. No coverage claim.
- **Delta / hurdle latent-scale correlation** — remains "do not advertise" per
  existing NEWS wording; unaffected by this arc.
- **No internal register codes on any public surface** — no "D-43", no lane
  names ("Lane A/B/C"), no "certificate candidate" / "Route A/B" internal
  labels, no Totoro/n_sim-methodology detail beyond the confirmed coverage
  number itself. Public wording states the scoped claim and the fence; it does
  not narrate the process that produced it.
- **The `{{GAUSS_N150_COVERAGE}}` placeholder is not a number to publish as-is** —
  it must be replaced with the confirmed n_sim ≥ 5000 result before any of the
  three blocks above goes live, and the flip itself still needs Shinichi's
  sign-off per the 2026-07-16 handover.
