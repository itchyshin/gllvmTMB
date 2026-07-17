# D-43 verification panel — gaussian n150 Sigma_unit-diagonal coverage certificate (pooled N≈15k)

**Date:** 2026-07-17 · **Method:** 3 independent adversarial lenses (default NOT-DONE) + synthesis
chair, run as a Workflow (`sigma-coverage-d43-panel`, run `wf_dcbe24f8-af6`). Two lenses independently
recomputed the pooled numbers to 4 dp on Totoro from the raw covered/converged/ci_available flags (not
from a precomputed summary). **This replaces the initial single-agent Rose run, which terminated
without producing its file under the ssh/classifier flakiness.**

## Disposition: BOTH cells CERTIFY (3-0 EARN), under strict wording

"CERTIFY" = the evidence supports a certificate **if Shinichi flips**; it does NOT itself flip any
public surface. The certificate defaults NOT-DONE (D-43); a cell certifies only if <2 lenses withhold.

| cell | statistical | pooling/repro | claims/scope | disposition | headroom |
|---|---|---|---|---|---|
| d1-n150 | EARN | EARN | EARN (wording) | **CERTIFY** | comfortable (+0.0040, ~2.2 MCSE, z=4.16 vs gate) |
| d2-n150 | EARN (thin) | EARN (marginal) | EARN (wording) | **CERTIFY** | thin (+0.0024, ~1.3 MCSE; survives one-sided-95%, z=3.30, p≈5e-4) |

Independent recompute (statistical + pooling lenses, both on Totoro/R): reproduce coverage d1 0.9477 /
d2 0.9461, MCSE 0.00185, bands 0.9440 / 0.9424 **exactly**. Rep-index overlap re-verified 0. Per-batch
homogeneity re-verified (d1 p=0.85, d2 p=0.65). orig-only figures match the committed WITHHELD
after-task exactly; rorqual N=5k d2=0.9462 consistent with pooled 0.9461.

**Why this is not the prior WITHHELD error:** the earning mechanism is legitimate MCSE shrinkage —
doubling the independent reps via a disjoint fresh seed halved the MCSE (0.0032 → 0.00185) and lifted
the lower band above 0.94 **without inflating the point estimate** (d2 settled slightly *down* to
~0.9461). No looser MCSE, no same-seed refit. The strongest statistical attack (MCSE underestimated)
*fails*: the rep-level `sqrt(p(1−p)/N_reps)` treats each rep as a single Bernoulli — the max-variance
case — so the band is an upper-bounded worst case that cannot shrink under intra-rep correlation.

## Two load-bearing qualifications (ride with any flip)

1. **Conditional-on-convergence is mandatory.** Worst-case unconditional coverage (all excluded reps
   counted as misses) is **0.9200 (d1) / 0.9397 (d2) — both BELOW the 0.94 gate.** The exclusion is on
   *base-optimizer convergence* (a pre-CI, outcome-independent status where the profile route correctly
   declines a CI), so it is not informative missingness — but any surface that drops the "for converged
   fits, non-convergence rate disclosed (~2.9% d1 / ~0.7% d2)" qualifier flips **both cells to
   WITHHOLD.**
2. **Gate 0.94, NOT nominal 0.95.** Point coverage ~0.946–0.948 is significantly below 0.95 (d2
   z=−2.11). Genuine ~0.4pp undercoverage of nominal remains. The certified property is *clearing the
   0.94 acceptance gate*, never "nominal 0.95 coverage."

## The drafted flip-wording FAILS three ways (claims/scope lens)

The draft (`2026-07-16-sigma-coverage-flip-wording-DRAFT.md`) must NOT ship unchanged. Mandatory fixes:

1. **Strike "achieves nominal two-sided coverage … against a 0.95 target."** → "clears the 0.94
   coverage gate" / "approximately nominal (~0.946–0.948 against a 0.95 target)". The committed
   after-task explicitly forbids nominal-0.95 framing.
2. **Add the convergence qualifier on EVERY surface** (widget ×2, NEWS, confint roxygen, printed
   output). It is currently absent from all four blocks.
3. **Scope to d≤2.** Only d=1 and d=2 were evaluated; "at least 150 grouping units" with no dimension
   qualifier silently generalizes to all latent dimensions. State "low latent dimension (d≤2, the
   dimensions evaluated)."
4. **Public number:** the range **0.946–0.948**, or the conservative binding **0.946** (d2). Do NOT
   lead with 0.948 (d1 only) or a rounded-up combined ~0.947 — both flatter the weaker cell.
5. **Soften "certificate/certified"** on reader-facing surfaces to "simulation-validated to clear the
   0.94 coverage gate" (avoids reading as a 0.95 guarantee; aligns with the no-internal-codes rule).

Fences confirmed intact and required to stay uncertified: binomial, nbinom2, ordinal, Sigma_unit
off-diagonal/covariance, Gaussian n<150.

## Panel recommendation to Shinichi (synthesis chair)

> Flip **d1 confidently**; treat **d2 as earn-under-strict-wording OR defer to 1.0** — both defensible.
> d1 is an unambiguous pass with no honest reason to hold once the three wording fixes are applied. d2
> legitimately clears the counting rule and the stricter one-sided test, but is **thin by construction**:
> it reaches the band only at pooled N≈15k, the fresh-only batch alone clears by just +0.0009, and the
> lift did not raise the point estimate — so the certificate has essentially no downward headroom (a
> future independent 10k batch near the observed low end 0.9455 would leave the band ~0.9418, still
> passing but barely). If you value a margin of safety, deferring d2 to 1.0 costs little and removes the
> only cell that could embarrass a later re-audit. **Chair's lean: flip d1; if in any doubt on d2,
> defer it.** Either way the flip still needs Shinichi's sign-off; nothing is flipped by this panel.
