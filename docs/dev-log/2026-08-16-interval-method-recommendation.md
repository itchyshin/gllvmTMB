# Interval-method recommendation for Design 66 §3.4 (2026-08-16)

**Author**: Claude (Fable 5), statistical-reviewer pass. Read-only. For the capstone-scoping
conversation alongside `docs/dev-log/2026-08-16-design66-scoping-onepager.md`.

**Scope**: Design 66 §3.4 (`docs/design/66-capstone-power-study.md:305-374`) re-opened the
primary/diagnostic interval-method assignment with three named candidates (a)/(b)/(c). This memo
recommends among them from measured evidence. It does not resolve §3.4 — that is the maintainer's
call — it gives the call a evidence-anchored default.

## 1. The three candidates, as named, with their evidence

**(a) Profile primary / bootstrap secondary** — gate on P-V (`profile_ci_total_variance()`),
report bootstrap alongside.
- *Evidence*: the only pre-registered, D-43-panelled certificate in the repo. 20,000-replicate
  campaign, gaussian, `d ∈ {1,2}`, `n_units = 150`: coverage 0.9467 / 0.9467 against a **0.94
  floor** (`docs/dev-log/2026-07-29-certificate-disposition.md`; `docs/design/66-capstone-power-study.md:249-272`).
  CERTIFY 3-0.
- *Cost*: `cells × n_sim × (1 + n_estimands × refits_per_profile)`. `refits_per_profile` is
  **code-derived, not measured** — 14–26 per two-sided scalar for a well-behaved bound, worst
  case 72 (`docs/design/66-capstone-power-study.md:848-877`). At `n_estimands = 5` (diagonals
  only) this is ~1.5–2.8× cheaper than bootstrap at the floor; at `n_estimands = 15` (diagonals +
  all pairwise correlations) it is ~1.05–1.95× *more* expensive (`:879-887`).
- *Known failure modes*: (i) **zero evidence on the structured between-unit tier**
  (`phylo_*`/`spatial_*`/`animal_*`/`kernel_*`) that defines the Tier-0 core grid
  (`:273-304`) — extending P-V there is a deliverable, not an assumption; (ii) two-sided only,
  one-sided/point-null use is invalid; (iii) marginal average fails in the smallest-`V_t` ventile
  (0.9259/0.9369); (iv) conditional on convergence; (v) 0.94 floor, never nominal 0.95 — both
  cells sit ~3.3 clustered SEs below 0.95 (`:255-272`).

**(b) Bootstrap primary at `n_boot ≥ 200`** — keeps PR #364's existing assignment.
- *Evidence*: no pre-registered certificate. Measured post-hoc: holding draws fixed and varying
  only `B`, coverage moves 0.8073 (B=10) → 0.9418 (B=200), against 0.9491 for the profile route on
  the same data — the apparent 17-point "failure" was a `n_boot = 10` harness bug, not a defect of
  `bootstrap_Sigma()` itself (`docs/dev-log/audits/2026-08-02-ci08-coverage-explained.md:107-135`,
  full B-sweep table at lines 118-123). Analytic scaled-χ² check attributes ~16 of the 17 points to
  the B=10 artifact and ~0.5–1 point to the percentile method's known second-order inaccuracy on a
  right-skewed variance component (`:126-132`).
- *Cost*: `cells × n_sim × (1 + n_boot)`, amortises across **every** estimand (all diagonals +
  all pairwise correlations) from one refit set (`:815-834`). At the `n_boot ≥ 200` floor the core
  spoke design (50 cells × 2000 reps) is ~465 single-core-days at 2 s/fit (`docs/design/66-capstone-power-study.md:820-824`).
  `n_boot` is a hard floor, not a tunable lever: coverage ceiling is `(B−1)/(B+1)`, so `B = 25`
  (the old M3 default) caps at 0.9231 — below the study's own 0.94 gate regardless of estimator
  quality (`:928-953`).
- *Known failure modes*: 0.9418 at the floor is a measurement with no pre-registration and no
  D-43 panel — it is evidence, not a certificate; and `bootstrap_Sigma()` silently accepts
  `n_boot = 10` with no floor guard on the matrix branch, so a mis-set harness reproduces the
  original 0.78 artifact undetected (`docs/dev-log/audits/2026-08-02-ci08-coverage-explained.md:135-141`).

**(c) Both arms on every core cell, reporting the pair.**
- *Evidence*: none run jointly at capstone scale; the two existing measurements (P-V 0.9467,
  bootstrap-at-B=200 0.9418) already agree within ~1 MCSE on the one cell both have touched
  (gaussian, diagonal `Sigma_unit`, no structured tier), which is itself a weak instance of what
  this option is meant to buy systematically.
- *Cost*: **additive, not averaged** (`docs/design/66-capstone-power-study.md:340-343`) — the full
  bill of (a) plus the full bill of (b), i.e. hundreds of single-core-days at minimum for the
  spoke design.
- *Known failure modes*: none beyond the union of (a) and (b)'s; the risk is entirely budget, not
  validity.

## 2. Recommendation

**Primary: (a) profile (P-V), gated on `Sigma_unit_diag` only (`n_estimands = 5`). Diagnostic:
(b) bootstrap at `n_boot ≥ 200`, reported but not gated.** This is (a) as named, not (c), and it
deliberately restricts the gated estimand set to diagonals.

Reasoning, anchored in the measurements above:
- P-V is the only candidate with a pre-registered certificate that has passed a D-43 panel. It is
  the safer default for a paper's headline gate on the axis it actually covers (gaussian,
  diagonal `Sigma_unit`, `d ≤ 2`, `n_units = 150`).
- The cost case for P-V being cheaper than bootstrap holds *only* if the off-diagonal correlation
  estimand stays diagnostic rather than gated (§8's own table: 1.5–2.8× cheaper at
  `n_estimands = 5`, but 1.05–1.95× *more expensive* at `n_estimands = 15`). Recommending (a) with
  the correlation estimand ungated is therefore not free-riding on an unresolved input — it is the
  choice that makes the cost case for (a) go through, and it is defensible on its own terms since
  §3.4's own estimand list marks the off-diagonal correlation as a separate, non-diagonal target
  (`docs/design/66-capstone-power-study.md:336-338`).
- Bootstrap-at-B≥200 is not disqualified — its 0.9418 is within ~1 MCSE of P-V's 0.9467 — but it
  carries no pre-registration and is ~2× the wall-clock of the diagonals-only profile arm at the
  floor. Keeping it as a reported diagnostic costs nothing extra once its refits are already
  amortised for the correlation estimand's own point estimates, and it is the built-in cross-check
  against P-V's structured-tier extrapolation (see below).
- Option (c) is not recommended as the *default* because its incremental evidence value over (a)
  is currently unquantified — the one cell where both routes have run shows agreement, not
  disagreement, so there is no measured case yet that the extra ~2× spend buys a materially
  different conclusion. It should be revisited if the pilot (below) shows P-V and bootstrap
  diverging on the structured tiers.

**What the `n_sim ≈ 200` pilot must confirm before the assignment locks:**
1. **`refits_per_profile`**, empirically, per family and per RE structure (Tier-0 core grid
   including at least one `phylo_*`/`spatial_*`/`animal_*` cell) — the 14–26 figure is code-derived
   from bracket-widening bounds, not measured, and a flat structured-tier likelihood surface (OU/BM
   at few tips) is explicitly flagged as likely to widen brackets and raise this number
   (`docs/design/66-capstone-power-study.md:283-291`, `:848-877`).
2. **P-V's behaviour on the structured tier at all** — the certificate has zero coverage evidence
   there (§3.3); the pilot must show P-V's `uniroot` bisection actually converges and produces
   sane widths on `phylo_dep`/`spatial_dep`/`animal_dep`/`phylo_latent` cells before the primary
   assignment can extend past the certified gaussian-diagonal regime.
3. **Agreement/disagreement between P-V and bootstrap on the structured tiers**, since that is
   the input option (c) is currently missing.

## 3. What is still unmeasured, and the cheapest way to measure it

`refits_per_profile` is the load-bearing unmeasured quantity — it sets both the cost comparison's
sign and, downstream, the Totoro-vs-DRAC compute-target decision (Design 66 L-a addendum,
`:1102-1122`; staleness audit, `docs/dev-log/audits/2026-08-02-design66-staleness-audit.md:130-137,303`).
The cheapest measurement is exactly what §8 already specifies: **a bounded, non-claim smoke run**
that fits `profile_ci_total_variance()` bisections across a handful of Tier-0 cells (one per
family × RE-structure combination is enough to see the structured-tier effect) and records median
and upper-decile refit counts per bound — no `n_sim` replication needed, since this is a
per-fit instrumentation question, not a coverage question. This is small enough to run locally or
on Totoro without touching the compute-admission gate that fences the actual pilot/production runs.

## 4. The cov119 traits-per-unit mechanism and missing-data interval claims

The cov119 campaign (`docs/design/119-predict-missing-uncertainty.md` §7–§8; handover
`docs/dev-log/handover/2026-08-16-claude-handover-missing-data-arc-closed.md`) found that
`predict_missing()`'s confidence-interval deficit is governed by **traits per unit (p), not sample
size (n)**: a 32× range in `n` left the confidence deficit flat (0.61→0.51 pt) while a 10× range
in `p` cut it 78% (1.32→0.29 pt), because a masked cell's linear predictor leans on the unit score
`u_i`, itself reconstructed from that unit's *other observed traits* — information scaling as
`O(p)`, not `O(n)`. This constrains any missing-data interval claim in the capstone in the same
direction Design 66 already worries about structured-tier extrapolation: **whichever interval
method §3.4 lands on (P-V, bootstrap, or both), neither has been measured under missing data at
all, and the traits-per-unit mechanism means a missing-data cell's calibration cannot be assumed
to inherit from a complete-data cell at the same `n_units`, even at matched `T`.** Best route
`sim` (R2) still under-covers at 0.941–0.946 against nominal 95% on the one measured grid
(n=50×p=25, q=2), and the parametric bootstrap under-covers further even with an REML-corrected
DGP (§8) — so bootstrap's already-uncertificated 0.9418 in the complete-data regime should not be
assumed to transfer to any missing-data cell in the capstone grid; each such cell needs its own
measurement, and the pilot should include at least one masked cell per family class to surface
this rather than assuming complete-data calibration carries over.

## References

- `docs/design/66-capstone-power-study.md:212-374` (§3, §3.4), `:805-961` (§8)
- `docs/design/35-validation-debt-register.md:430` (CI-08), `:432` (CI-10)
- `docs/dev-log/2026-07-29-certificate-disposition.md`
- `docs/dev-log/audits/2026-08-02-ci08-coverage-explained.md:1-141`
- `docs/dev-log/audits/2026-08-02-design66-staleness-audit.md:130-137,303`
- `vignettes/articles/profile-likelihood-ci.Rmd:36-58`
- `docs/design/119-predict-missing-uncertainty.md` §7-§8 (lines 113-469)
- `docs/dev-log/handover/2026-08-16-claude-handover-missing-data-arc-closed.md`
