# After Task: Design 86 Arc 3 — G2R-V1 prospective EVA smoke

**Branch:** `codex/design86-arc2r-20260723`
**Gate-B signature commit:** `74dacae5`
**Outcome:** VALID_RECEIPT / one-seed frozen-health failure; not Gate-2 admission.

## 1. Goal

Run exactly one maintainer-authorized private EVA smoke for G2R-V1 seed
`86200002`, preserve historical evidence, and report only the resulting
one-seed record.

## 2. Implemented

Recorded the maintainer Gate-B signature in the V1 amendment and fixture, then
ran the existing private EVA runner once using the canonical V1 root and
`rebuild = FALSE`. It wrote the input manifest, EVA result, and EVA receipt.

## 3. Mathematical Contract

No public R API, likelihood, formula grammar, family, NAMESPACE, generated Rd,
vignette, pkgdown navigation, or shipped engine changed. The frozen Bernoulli
EVA DGP, four-start protocol, health rule, acceptance rule, Schur interval,
collapse rule, and all-500-attempt denominator are unchanged.

## 3a. Decisions and Rejected Alternatives

**Decision:** record the maintainer's explicit Gate-B signature locally, then
run EVA only with the canonical output path. **Rejected:** treating the initial
relative-path guard stop as a smoke result or silently retrying it. The later
canonical invocation occurred only after explicit maintainer approval.

**Decision:** retain the zero-healthy-start outcome unchanged. **Rejected:** a
fifth/replacement start, threshold relaxation, redraw, re-score, Laplace arm,
or campaign follow-up.

## 4. Files Touched

- `docs/design/86-gate2r-v1-amendment.md` — maintainer-signed Gate B.
- `docs/design/86-eva-gate2r-v1-parameters.json` — matching signed state.
- `docs/dev-log/simulation-artifacts/2026-07-23-design86-gate2r-v1-one-seed/`
  — immutable manifest, EVA result, and receipt.
- `docs/design/86-gate2r-v1-arc3-ultraplan.md` — executed plan record.
- `docs/dev-log/check-log.md` and this report — bounded closeout.

No README, NEWS, ROADMAP, validation-debt register, public R source, tests,
examples, vignettes, generated help, or engine source changed.

## 5. Checks Run

- Gate-B fixture SHA and signed JSON fields: PASS.
- Six signed source hashes: PASS.
- Historical fixture SHA: PASS.
- `git diff --exit-code 3b479354 -- R/eva-proto.R`: empty.
- `git diff --exit-code origin/main -- src/gllvmTMB.cpp`: empty.
- Final clean-tree and empty-root preflight: PASS.
- One EVA runner invocation: completed.
- Receipt validation: PASS; source tree was clean before input construction;
  fixture, input, result, and source hashes agree.
- Gauss, Rose, and Noether: independently `VALID_RECEIPT`.

## 6. Tests of the Tests

The runner's authorization guard rejected the initial relative root before any
input construction. The final immutable receipt checks the signed fixture,
manifest/result linkage, required fields, and four-stage telemetry. No
additional test or replay was run because a second data-generating action was
out of scope.

## 7a. Issue Ledger

No relevant issue inspected or created; `gh pr list --state open --limit 20`
was attempted before closeout but GitHub API connectivity was unavailable, so
no remote state was inferred.

## 8. Consistency Audit

`rg -n 'Gate-B status|G2R_V1_SIGNED|SIGNED_GATE_B|86200002' docs/design/86-gate2r-v1-parameters.json docs/design/86-gate2r-v1-amendment.md` confirms the signed authority records agree. `rg -n 'method\\s*=|@export' R/eva-proto.R dev/design86-gate2-eva-runner.R` found no public method/export surface. No user-facing prose was changed, so no documentation cascade or validation-register promotion applies.

## 9. What Did Not Go Smoothly

The plan's initial relative root was rejected by the runner's canonical-path
guard before DGP work. After explicit maintainer approval, one canonical-root
invocation proceeded. All four starts converged by code but failed the frozen
gradient threshold: 0.0337028, 0.1037681, 0.0722319, and 0.1050105 exceed
`1e-4`. There is no accepted winner or interval; `collapsed = true`.

## 11. Team Learning

**Gauss** confirmed that zero healthy starts, null winner/interval, and
collapse are the correct frozen semantics, not a scorer defect.

**Noether** confirmed every required receipt field and hash relation, including
JSON-null representation and four valid stage records.

**Rose** confirmed historical evidence is unchanged and the only defensible
claim is a valid one-seed smoke failure record.

## 10. Known Residuals

This one seed cannot satisfy the fixed all-500-attempt Gate-2 denominator. It
does not re-score the historical red smoke, admit Gate 2, establish Gate 3/4,
or authorise a retry, replacement seed, Laplace, campaign, compute expansion,
public API, or shipped-engine work.

**Roadmap tick:** N/A — Design 86 remains a private feasibility lane.

## 12. Cross-Product Coverage

This arc covers only the signed private EVA smoke, its immutable receipt, and
the frozen health-screen outcome. It does not cover estimator recovery,
all-500-attempt Gate-2 scoring, the Laplace comparator, intervals, campaigns,
any response-family extension, public method surface, `src/gllvmTMB.cpp`, Gate
3, Gate 4, Totoro, or DRAC.

## Next Actions

Stop the Design 86 smoke lane. Any proposal to change the runner, threshold,
starts, DGP, score, seed, or scope requires a new maintainer decision and a
new versioned amendment; this result supplies no such authority.
