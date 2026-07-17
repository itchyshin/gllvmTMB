# 🔴 Decision memo for Shinichi — Sigma_unit n≥150 coverage certificate: earn or defer?

**Date:** 2026-07-17 · **Author:** Claude (Lane A, coverage) · **Status:** awaiting your decision
**Gate:** no public surface flips without your sign-off. Rose's independent re-audit is attached
below (the D-43 default-NOT-DONE gate).

---

## TL;DR

The fresh-seed lift you approved **worked** — but read *how* it worked, because it is not what the
"0.9398" headline suggested. The value is **MCSE shrinkage, not a point-estimate rescue.** Pooling the
original 5,000 reps with 10,000 fresh disjoint-seed reps (N≈15,000) roughly **halves the MCSE**
(0.0032 → 0.00185), which lifts d2-n150's 2·MCSE lower band above 0.94 (**0.9424**) even though the
coverage point estimate itself settled *slightly down* to a stable ~0.946. Both n150 cells now clear
the 0.94 gate on their lower band — d1 comfortably, **d2 thinly**.

**Correction to the earlier framing:** "d2-n150 failed at 0.9398" was the *rorqual cross-hardware
lower band* (0.9462 − 2·0.0032), not a coverage point estimate. The original **Totoro** d2-n150
coverage was already **0.9473** (a thin pass on Totoro; band 0.9409); the WITHHELD call was driven by
rorqual's band dipping to 0.9398 **and** the thinness at N=5k. See §2.

**My recommendation:** flip **d1** confidently; **d2** is a genuine judgment call (earn-under-strict-
wording *or* defer to 1.0 — both honest). The independent D-43 panel certified both cells 3-0, but d2 is
thin with no downward headroom. Given 0.6 is the release and the certificate is a maturity nicety, my
lean is the conservative one: **ship the properly-worded certificate for both cells if you want the
headline capability now, or defer the whole certificate to 1.0 and keep 0.6 recovery-only.** A d1-only
public claim I'd avoid — splitting the certificate by latent dimension reads as odd. Details in §4–§6.

---

## 1. The pooled numbers (N≈15,000, committed rep-level MCSE = √(p(1−p)/N))

| cell | pooled coverage | N (reps) | MCSE | 2·MCSE lower band | vs 0.94 gate |
|---|---|---|---|---|---|
| **d1-n150** | 0.9477 | 14,562 | 0.00185 | **0.9440** | clears, +0.0040 |
| **d2-n150** | 0.9461 | 14,898 | 0.00185 | **0.9424** | clears, **+0.0024 (thin)** |

- Original run: `~/gllvm_work/profile_rescore/` (reps 1–5000).
- Fresh run: `~/gllvm_work/profile_rescore_freshseed_A/` (reps 5001–15000, n_boot=100, DONE exit=0,
  192 shards). Disjoint seeds; verified rep-index overlap = 0.
- Estimand: **diagonal of `Sigma_unit`** (per-trait total variance V_t = loadings + diagonal ψ),
  `ci_method = "profile_total"`, Gaussian only. Everything else stays fenced.
- MCSE convention: the **committed** rep-level `pilot_binomial_mcse` (`dev/m3-pilot-report.R:768`),
  NOT the clustered trait-level ~0.0015 that a prior in-session analysis wrongly used to declare
  "earned." Under the correct convention d2 is a genuine — but thin — pass.

## 2. Caveat 1 — where the point estimate actually sits (batch consistency)

The authoritative N=5k numbers (committed after-task `2026-07-17-sigma-coverage-nsim5000-confirm.md`):

| source (N=5k) | d1-n150 | d2-n150 | d2 band (cov − 2·0.0032) |
|---|---|---|---|
| original Totoro | 0.9482 | **0.9473** | 0.9409 (thin pass) |
| original rorqual (cross-hw) | 0.9481 | **0.9462** | 0.9398 (fail) |

Pooled Totoro (orig + fresh, N≈15k): d1 **0.9477**, d2 **0.9461**. Exact per-batch split of the
pooled set, with a two-proportion z-test on the rep-level denominators:

| cell | orig-only (reps 1–5000) | fresh-only (reps 5001–15000) | diff | z | p |
|---|---|---|---|---|---|
| d1-n150 | 0.9482 (N=4872) | 0.9474 (N=9690) | +0.0007 | 0.18 | **0.85** |
| d2-n150 | 0.9473 (N=4959) | 0.9455 (N=9939) | +0.0018 | 0.46 | **0.65** |

**The fresh batch is statistically indistinguishable from the original** (p=0.85, p=0.65) — no
outlier, no batch effect: this is textbook-legitimate homogeneous pooling. The orig-only numbers
(d1 0.9482, d2 0.9473) match the committed WITHHELD after-task's Totoro figures **exactly**,
confirming the pool is sound. d2 settles at a stable ~0.946, which also **coincides with the
independent rorqual estimate (0.9462)** — cross-sample *and* cross-hardware agreement. My earlier
"~2.3 SE gap" back-solve was an artifact of confusing the rorqual band (0.9398) with a coverage point;
the real batches agree within noise. **This caveat is effectively cleared.**

## 3. Caveat 2 — thin margin + conditional-on-convergence

- d2's 2·MCSE lower band clears 0.94 by only **0.0024**. d1 is comfortable; d2 is "just clears it."
- Coverage is measured on **converged, CI-available** reps (conditional-on-convergence). ~1–3% of
  nominal reps produced no record and are excluded (d1: 14,562/15,000; d2: 14,898/15,000). Any public
  wording should say "for converged fits" and must not imply an unconditional guarantee.

## 4. Independent D-43 verification panel — result

> **Disposition: BOTH cells CERTIFY (3-0 EARN each) — under strict wording. d2 is thin.**
> Full audit: `docs/dev-log/2026-07-17-sigma-coverage-d43-panel.md`.

Three independent adversarial lenses (each default-WITHHOLD); two independently recomputed the numbers
to 4 dp on Totoro. All three returned EARN for both cells, so neither reached the ≥2-WITHHOLD threshold.
But the panel is emphatic that this certifies the *cells*, not the *drafted wording* — and it attaches
two non-negotiable qualifications:

- **Conditional-on-convergence is mandatory.** Worst-case unconditional coverage (all excluded reps =
  misses) is **0.9200 (d1) / 0.9397 (d2) — both below 0.94.** Drop the "for converged fits, rate
  disclosed" qualifier on any surface and both cells flip to WITHHOLD. (The exclusion is on base-fit
  convergence, outcome-independent, so it is honest to condition — but the qualifier must travel.)
- **Gate 0.94, NOT nominal 0.95.** Point coverage ~0.946–0.948 is significantly below 0.95 (d2
  z=−2.11). The certified property is *clearing the 0.94 gate*, never "nominal 0.95."

**Robustness:** d1 clears the gate at z=4.16 (comfortable); d2 clears at z=3.30 (p≈5e-4 above 0.94) and
survives a stricter one-sided-95% criterion — thin (+0.0024, ~1.3 MCSE) but real, with **no downward
headroom** (the fresh-only batch alone clears by just +0.0009). The earning mechanism is legitimate
MCSE shrinkage, not the prior looser-MCSE error.

## 5. If you decide to FLIP (earn) — the wording is now settled by the panel

The panel resolved both open wording questions and found the drafted
`2026-07-16-sigma-coverage-flip-wording-DRAFT.md` **must not ship unchanged** — three mandatory fixes:

1. **Strike "achieves nominal two-sided coverage … against a 0.95 target."** Use "clears the 0.94
   coverage gate" / "approximately nominal (~0.946–0.948 against a 0.95 target)." (Your committed
   after-task already forbids nominal-0.95 framing; the draft violated it.)
2. **Add the convergence qualifier on EVERY surface** — "for converged fits, non-convergence rate
   ~2.9% (d1) / ~0.7% (d2) disclosed." Currently absent from all four drafted blocks.
3. **Scope to d≤2** (the only latent dimensions tested). "at least 150 grouping units" alone
   over-generalizes.
4. **Public number:** the **range 0.946–0.948**, or the conservative binding **0.946**. Not 0.948, not
   a rounded 0.947.
5. **Soften "certificate/certified"** → "simulation-validated to clear the 0.94 coverage gate."

**Implementation is NOT a mechanical paste.** The now-closed coverage lane committed `c0754666` (481-line
rework of `R/profile-derived.R` + `R/z-confint-gllvmTMB.R`), so the draft's line numbers and the old
"S6 safe recipe" are **stale**. On approval I re-derive the wiring/roxygen insertion point against the
current code, apply all five wording fixes, `document()`, run the two touched test files, commit as one
coherent commit, and run a second fresh reviewer on claim-vs-evidence before finalizing.

## 6. If you decide to DEFER

Close the arc: recovery-only for 0.6, certificate re-opened at 1.0. I record DEFER-to-1.0 in the
after-task and a directed check-log note. No code change. This is fully defensible given the thin d2
margin — 0.6 is the release, and the certificate is a maturity nicety, not a blocker.

---

## 🔴 What I need from you — pick one

- **(A) Flip both cells** — ship the certificate for gaussian n150 d≤2, worded per §5 (gate-framed,
  convergence-conditional, number 0.946–0.948). Delivers the headline interval-coverage capability for
  0.6. Honest and panel-backed; d2 has no headroom.
- **(B) Flip d1 only, defer d2 to 1.0** — I'd *not* recommend this: a certificate scoped to one latent
  dimension is a confusing public claim.
- **(C) Defer the whole certificate to 1.0** — recovery-only for 0.6; re-earn with a fuller campaign
  (more n, more d, tighter margin) at maturity. Most conservative; costs the 0.6 headline.

My lean: **(A) if you want the capability in 0.6, else (C).** Either is defensible; (A) is more work
(the five wording fixes + re-derive the wiring against the current code) but delivers more.

Also:
- Note: the concurrent coverage lane **closed this session and handed me this exact follow-up** (it
   left my uncommitted work untouched). It landed 4 local, **unpushed** commits on
   `claude/release-0.5.0` — including `c0754666`, which is the *correlation / off-diagonal* recovery-only
   restore (its CI-08/CI-10 certification is deferred until this **diagonal** certificate is settled, so
   my task is its prerequisite). I have not pushed. Flag if you want me to push, and note the S6 diagonal
   wiring must still be re-derived against this current code.
