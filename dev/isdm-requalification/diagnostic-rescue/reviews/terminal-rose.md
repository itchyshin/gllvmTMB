# Rose terminal scope review — PASS

Date: 2026-08-29  
Role: scope, provenance, denominators, claim boundary, and next action  
Verdict: **PASS**

Review mode: read-only inspection of the approved plan, frozen contract,
checksum-bound raw evidence, and independently reproduced summary. I started no
fit and changed no file outside this review.

## Findings

### Denominator and provenance — PASS

- The approved experiment has exactly 52 immutable task identities: 16
  nonspatial and 36 spatial. The compute-input plan and retained experiment plan
  have the same SHA-256,
  `8a7ec70f6b26befca9f554f68363c161d34a93b86ea8fec0c0ad364bae3c28e5`.
- The raw bundle manifest verifies its exact file set and every checksum. It
  contains 52 distinct started receipts and 52 distinct worker terminal
  records. The independent summary reports `planned = 52`, `started = 52`,
  `terminal = 52`, `worker = 52`, `coordinator = 0`, with 52
  `fit_returned` and zero error, interrupted, or unavailable dispositions.
  Smoke remains a separate four-fit bundle and is not counted in this
  denominator.
- `verify-remote-receipt.R experiment` returned
  `DIAGNOSTIC_52_ATTEMPTS_VERIFIED`. The pure-reader replay returned
  `DIAGNOSTIC_SUMMARY_VERIFIED` and was identical to the retained independent
  summary. There is no missing, duplicate, replacement, filtered, or
  coordinator-substituted experiment attempt.
- Source identity remains the approved package commit
  `09eca7b1eb9018958bad367be824871161a60af1`, tree
  `fb979daa5d9a93d0804a053ff1bb00eced47ad09`. All 17 frozen harness members
  pass `HARNESS_SHA256.txt`. The branch diff is confined to `LOOP/`, the
  diagnostic-rescue harness/evidence, and dedicated tests; it contains no
  package `R/`, `src/`, API, interval, structured-source, NEWS, vignette, or
  public-promotion change.

### Thresholds and adjudication — PASS

The independent adjudicator implements the preregistered rules without changing
their conjunctions or cutoffs. The retained raw evidence reproduces all five
signals as `FALSE`:

- `REPLICATION_SIGNAL = FALSE`. Replication reduced full-surface nRMSE in 8/8
  pairs (median reduction 0.1283) and improved or preserved correlation in 8/8,
  but species-1 `Psi` relative error improved in only 4/8 and its median change
  was -0.0355. The frozen rule requires at least 6/8 and a median of at least
  0.10, so the promising surface pattern cannot be promoted to the combined
  replication signal.
- `ESTIMAND_SIGNAL = FALSE`. Zero of eight baseline pairs met the joint
  shared-versus-full criterion; the rule requires at least 7/8.
- `BASIN_SIGNAL = FALSE`. All eight eligible nlminb5 comparisons were
  comparable, but 0/8 passed the frozen joint transition, objective, gradient,
  and held-out-performance rule; the requirement is at least 6/8.
- `TERMINATION_SIGNAL = FALSE`. All eight eligible BFGS-continuation
  comparisons were comparable, but 0/8 passed the same frozen joint rule; the
  requirement is at least 6/8.
- `CURVATURE_SIGNAL = FALSE`. Native and relative rankings agreed for all 12
  defaults, and the dominant `theta_rr_spde_lv` block had median normalized mass
  0.991, but it dominated only 8/12 defaults; the preregistered count is at
  least 9/12.

No denominator or threshold was altered to rescue a signal. With zero fired
signals, `next_action = "MIXED"` is exactly the preregistered fallback. Here
`MIXED` means **no single preregistered mechanism was selected**; it does not
mean that multiple mechanisms were demonstrated.

### Honest claim boundary — PASS

This is complete hypothesis-generating sentinel evidence. It supports the
negative decision that the present experiment does not select replication,
estimand choice, optimizer basin, optimizer termination, or one dominant
curvature block as the next confirmatory mechanism. The surface improvements
under replication and the 8/12 curvature pattern may be retained as descriptive
leads only.

It does not establish mechanism prevalence or cause, does not requalify failed
production gates, does not justify rescoring or replacing production attempts,
and earns no threshold change, engine repair, interval claim,
structured-source claim, package/API change, or public promotion.

## Exactly one next action

**Prepare a new approval packet for one narrower nonspatial paired
replication-discrimination experiment.** Hold the same eight design cells,
public fitting route, fixed/shared/full estimands, and baseline-versus-replicated
contrast fixed; add preregistered independent response-seed replication so the
full-surface response and species-1 `Psi` response can be distinguished rather
than forced into the present combined signal. This is planning only: it starts
no fit, changes no current denominator or threshold, and authorizes no API,
interval, structured-source, or public work.

No P0, P1, P2, or P3 scope inconsistency was found under this bounded claim and
next-action contract.
