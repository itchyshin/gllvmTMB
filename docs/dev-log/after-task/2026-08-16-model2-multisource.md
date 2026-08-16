# After-task: Model 2 — the multi-source integrated model

**Date:** 2026-08-16 · **Lane:** `claude/isdm-model2-multisource-20260816` (Claude Code) ·
**Base:** `codex/isdm-range-amplitude-orthogonal` @ `bdaf24d4` · **Design:** 120 ·
**Umbrella:** #941

## 1. Scope

Make `n_sources > 2` fittable through public `gllvmTMB()` with honestly named sources,
each declaring its own observation law; validate at n = 3–4; the two-source contract
becomes the n = 2 case of one predicate.

## 2. The finding that resized the arc

The maintainer's steer called Model 2 *"an ENGINE extension"*. Two planning probes showed
it is not:

- **Three all-Poisson sources fit today, unchanged** (#941's Milestone 1 shape): 3.6 s,
  `pd_hessian = PASS`, per-source effects recovered.
- **Three mixed-law sources fit the moment the data are relabelled** into the two-source
  vocabulary — the refusal was the predicate's hard-coded `gbif`/`survey_pa` names, not
  any engine limit. `"gbif"` appears nowhere in `src/gllvmTMB.cpp`.

So the arc became: generalise the admission to a **declared** contract, and validate.
`src/` untouched, as planned.

## 3. What shipped

- **`isdm_sources()`** (new export, `R/isdm-sources.R`): declare ≥2 named sources, each
  `poisson()` or `binomial("cloglog")`; other laws refused at declaration with the
  scale-coherence reason.
- **`.gllvmTMB_integrated_sources_contract()`**: one generalised predicate;
  the legacy two-source shape is recognised and translated into the same core
  (`.gllvmTMB_isdm_declared_core()`), and the old function name survives as an alias
  because tests and dev-log evidence reference it.
- **Design 120**, whose §2 settles Gauss's planning question: coherence is arm-by-arm
  (the joint likelihood has no cross-arm term), so the admitted law set at n arms equals
  the set at 2. Every Model 1 refusal generalises; none relaxes. An all-count declaration
  is deliberately NOT admitted — it needs no relaxation and keeps ordinary behaviour,
  including `weights`, which the admitted contract must refuse.
- **Tests** (`test-isdm-multisource.R`, 19 assertions): declaration validation, a live
  3-source mixed fit, refusals (undeclared value, incomplete trait, weights), the
  all-count-keeps-weights property, predicate equivalence across old/new names, and
  **byte-compatibility** — the legacy route and the declared route give identical
  objective and parameters on the same data.
- **NEWS + register row `ISDM-02` (`partial`)** with the boundary stated.

## 4. Evidence

- **Pre-run (Mac, 12 fits):** 12/12 converged, 12/12 `pd_hessian` PASS, gamma RMSE ≈ 0.10
  flat across n_sources 2–4, median 3.6 s/fit.
- **Campaign (Totoro, 1,200 fits):** grid = n_sources {2,3,4} × mix {all-PO, (n−1)PO+PA}
  × effort-ratio {1×, 10×} × 100 seeds. D-139: priced from the pre-run at ~80 core-minutes
  — under the 30-minute line, so run without a separate approval gate. RESULTS: recorded
  below in §7 when the run lands (the run was in flight when this report was first written;
  the register row cites the harness and the pre-run, and asserts nothing about campaign
  results).
- **Model 1 regression net:** the full isdm/offset/family suite passes unchanged.

## 5. Defects found and fixed during the arc

- **The attribute-borne declaration silently vanished.** `isdm_sources()` first carried
  its source→law map as an attribute; `.align_mixed_family_list()` reorders the family
  list by subsetting, and subsetting drops attributes, so the predicate never saw the map
  and refused everything. Found by the smoke test. Fixed by rebuilding the map from the
  list's names and laws inside the predicate — the declaration is the names+laws, not an
  attribute.
- **Design-number race, dodged by protocol.** The planning scout reported 111 as the
  highest design number; the preflight's cross-ref census said the next free slot was 120.
  The census was right — 112–119 are taken on branches the checkout cannot see. Claimed
  120 by committing a stub first.

## 6. Definition of Done

1. Implementation on the lane; **merge needs the maintainer** (new export, API-class).
2. Recovery: pre-run receipt + campaign (§4); register row stays `partial` — this is
   first-pass nonspatial evidence, not certification.
3. Documentation: roxygen with lifecycle badge + regenerated man/; Design 120.
4. Runnable example: in the `isdm_sources()` roxygen. A dedicated article is a follow-on
   decision, not silently skipped: the two existing articles teach the two-source case,
   and extending them to n sources belongs with the article maintainer's voice.
5. check-log: appended.
6. Review: Gauss+Rose adversarial pass on the diff (fresh context); findings and their
   disposition recorded below.

## 7. Campaign results and review findings

*(Filled in at close — see the check-log entry of the same date.)*
