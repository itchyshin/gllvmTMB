# Cross-lane brief → the LA + AGHQ + ridge lane

Date: 2026-07-30. From: Claude, lane `claude/vgh-pluralism-20260730` (the VA/VGH lane).
**To: whoever owns LA + AGHQ + `aghq_ridge` + the Heywood gate.**

**This is information, not a request.** I changed nothing in `R/`, `src/`, `NEWS.md`, or
`check_gllvmTMB()` — `git diff --stat -- R/ src/` against `main` is empty. Four findings from the
gaussian arm bear on your lane; one is a fact about your own gate that I think you'd want
regardless of what you do with the rest.

A duplicate of this sits in `docs/dev-log/check-log.md` (2026-07-30 entry), but that file is ~47k
lines and this is easier to find.

---

## 1. `loading_absolute_thresh` never evaluates on a gaussian fit

**This is the load-bearing one.** The absolute-loading criterion that shipped in #838 lives only
inside `.gllvmTMB_binomial_prevalence_loading_row()`, and that row `return(NULL)`s unless
`family_id == 1L` rows exist (`R/diagnose.R:464-471`; binomial is `1L`, gaussian `0L`, per
`R/enum.R:6-7`).

Verified by running it, not by reading: `check_gllvmTMB()` on a gaussian fit returns **13 rows and
no `binomial_prevalence_loading` row at all.**

Two consequences:

- **There is currently no absolute-loading criterion for gaussian**, so any statement of the form
  "gaussian fits stay under the threshold" is comparing against something that never fires. (I made
  exactly that mistake — see §5.)
- **The constant `6` is not scale-free off the logit link.** Its stated justification is explicitly
  link-scale: *"the latent scores are standard normal by identification, so a binomial loading IS
  the trait's latent SD in link units"* (`R/diagnose.R:530-533`). On an identity link the reference
  scale is the response's own units. Demonstrated: **multiplying `Y` by 10 lifts every loading past
  6** with no pathology and no new warning; adversarial fits reached raw `max|Λ̂| = 32.64` on
  scale-heterogeneous and t₂-contaminated data, all healthy.

I am **not** proposing a change. If the gate is meant to stay binomial-only this is all correct as
designed — it just means the gaussian question is open rather than answered.

## 2. Gaussian appears to have no loading-runaway tail, which makes `aghq_ridge` a non-gaussian instrument

`aghq_ridge` exists to repair a degenerate Laplace fit in place (47% → 0% on binomial). On gaussian
there appears to be nothing to repair.

Scale-free evidence, since the raw-magnitude version is invalid per §1: across **59 gaussian Laplace
fits** (36 mine + 23 adversarial, including deliberately harsh regimes — rank over-specified
`d = 1 → 4`, `n = 30 / T = 15`, weak signal, trait-scale heterogeneity, contaminated errors), the
largest loading stayed **below that dataset's own largest trait SD in every single fit** — max ratio
**0.961**. Loadings track the data's scale rather than escaping it.

**Mechanism, derived rather than asserted:** the gaussian marginal log-likelihood is **coercive in
Λ**. Since `log|ΛΛ' + diag(ψ)| → ∞` while the quadratic term stays non-negative, `ll → −∞` as
`‖Λ‖ → ∞`, for any data. Measured under `Λ → cΛ`: **−592.8 (c=1) → −800.6 (c=10) → −1352.3
(c=1000)**. A separated logistic does the opposite: **−6.27 → −9.1e-04 → 0**. So `log|Σ|` pins Λ to
the data's second moments; the binomial runaway rides on link saturation, which identity cannot do.

Evidence: `dev/vgh/gaussian-degeneracy-reachability.{R,csv}`; write-up
`docs/dev-log/2026-07-30-gaussian-has-no-degeneracy-tail.md`.

## 3. 🎯 If you need a gaussian degeneracy claim, ψ is where to look — not loading magnitude

**This is the actionable pointer.** The coercivity argument in §2 bounds **Λ**. It says nothing
about **ψ**, and the likelihood is **not** coercive in ψ — `ψ_j → 0` is the classic Heywood boundary
and remains possible in principle.

**My search was structurally blind to it.** All 36 of my fits used `latent(..., unique = FALSE)`, so
`Σ = ΛΛ' + σ²I` with **no per-trait ψ to collapse**. A 9-fit spot check on the ψ model
(`latent(0 + trait | site, d = k)`, 3 configs × 3 seeds including `n=25 / T=12 / d 1→4`) found
nothing — max `|Λ̂| = 2.21`, all converged — but nine fits is a spot check, not coverage.

So: gaussian looks immune to the *loading* runaway on a derived argument, and **untested against the
ψ boundary**. If a gaussian Heywood claim matters for the gate or the ridge, that is the experiment.

## 4. The research recovery metrics false-positive at small true Λ — but NOT your gate

Relevant only if your lane scores coverage or recovery with `rel_frob` / `atten_F`.

Both normalise by the truth's magnitude — `atten_F = sqrt(tr(Σ̂)/tr(Σ_true))`,
`rel_frob = ‖Σ̂−Σ_true‖_F/‖Σ_true‖_F` (`dev/vgh/phase0-matched-recovery.R:88-100`, plus four
independent re-definitions elsewhere in `dev/`). So a near-null true factor structure inflates the
ratio while the fit itself stays small. In my run `atten_F` flagged 8 of 36 fits — and **the flagged
fits carried loadings roughly half the size of the unflagged ones** (median `max|Λ̂|` 0.83 vs 1.44),
with all 8 falling in the single `lam_sd = 0.15` stratum whose `tr(Σ_true)` is 56.9× smaller.

**Diagnostic rule:** when a ratio flags degeneracy, check the absolute magnitude. If it is not
elevated, the flag is a denominator artifact.

> **Scope guard — this is NOT about `check_gllvmTMB()`.** Its statistics never use `Σ_true`; they
> cannot, since truth is unavailable at diagnosis time. `grep -n "Sigma_true\|truth" R/diagnose.R`
> returns **zero hits**. Your shipped gate is unaffected and no change to it is implied.

## 5. What I got wrong, so you don't inherit it

My first version of §2 claimed *"max |Λ̂| = 2.77 against the shipped absolute threshold of 6, zero
exceedances."* **Withdrawn** — it was invalid for the reason in §1 (the threshold never fires on
gaussian) and because 6 is trivially exceeded by rescaling. The check-log entry carried that wrong
number for about an hour before an adversarial pass caught it; it is corrected in place there.

If you saw the earlier version, §1–§2 above supersede it.

---

## What I'd find useful back, if you have it cheaply

1. Was the binomial gating of `loading_absolute_thresh` **deliberate** (gate is binomial-only by
   design) or **incidental** (it happens to live in the binomial row)? That changes whether §1 is a
   gap or a non-issue.
2. Does `aghq_ridge` have any gaussian test coverage? If gaussian genuinely has no tail, gaussian
   ridge cells may be measuring nothing.

No reply needed if neither is at hand — this is a drop-off, not a blocker. My lane's arc is closed;
full account in `docs/dev-log/after-task/2026-07-30-gaussian-arm-vgh-pluralism.md`, and PR
[#840](https://github.com/itchyshin/gllvmTMB/pull/840).
