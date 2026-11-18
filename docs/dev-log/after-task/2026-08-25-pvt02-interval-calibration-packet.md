# After Task — PVT-02 interval-calibration packet

## 1. Goal

Build and verify a fail-closed packet for one unmeasured Gaussian total-variance
profile cell: ordinary unit-tier `latent(..., unique = TRUE)`, `d = 2`,
`n_units = 400`. The 5,000-replicate calibration campaign remains approval-gated.

## 2. Implemented

Added pure PVT-02 arithmetic and accounting helpers, focused tests, a two-replicate
local smoke wrapper, four replayable Unlazy gates, a seed-disjointness check, a
claim reconciliation, and a measured pre-run receipt. The packet records exactly
one target trait per replicate and scores an invalid profile endpoint as a miss
within the converged denominator while retaining every attempt.

## 3a. Decisions and Rejected Alternatives

The target is `V_t = (Lambda Lambda^T)[t,t] + psi_t^2`, profiled on `log(V_t)`
with a one-df likelihood-ratio inversion; `psi` alone and a bootstrap comparator
were rejected as outside this packet. The current broad `n_units >= 150` public
predicate and its test were not edited: the retained evidence proves two `n=150`
cells, not every larger sample size. The frozen future window is `50001:55000`;
the campaign is not allowed to pool historical rows or begin without approval.

## 4. Files Touched

- `dev/pvt02/.gitignore`
- `dev/pvt02/pvt02-contract.R`
- `dev/pvt02/pvt02-smoke.R`
- `dev/pvt02/verify-contract.R`
- `dev/pvt02/verify-tests.R`
- `dev/pvt02/verify-smoke-receipt.R`
- `dev/pvt02/verify-packet.R`
- `tests/testthat/test-pvt02-contract.R`
- `docs/dev-log/artifacts/pvt02/2026-08-25-pvt02-ultra-plan.md`
- `docs/dev-log/artifacts/pvt02/2026-08-25-pvt02-reconciliation.md`
- `docs/dev-log/artifacts/pvt02/2026-08-25-pvt02-smoke-receipt.csv`
- `docs/dev-log/artifacts/pvt02/2026-08-25-pvt02-pre-run-receipt.md`
- this report, the paired Melissa reconciliation, and handover.

No public R API, likelihood, formula grammar, family, C++, NAMESPACE, generated
Rd, vignette, pkgdown navigation, README, NEWS, roadmap, validation register, or
shared check-log changed.

## 5. Checks Run

- `Rscript --vanilla dev/pvt02/verify-contract.R` → `PVT02_CONTRACT_PASS`.
- `Rscript --vanilla dev/pvt02/verify-tests.R` → 7 test blocks, all passed.
- local smoke command → two retained attempts; 21.3 s total; both converged with
  finite, ordered profile bounds.
- `Rscript --vanilla dev/pvt02/verify-smoke-receipt.R ...csv` → pass.
- `Rscript --vanilla dev/pvt02/verify-packet.R ...ultra-plan.md` → pass.
- `node .../gate-check.mjs --reverify dev/pvt02/.unlazy/GATES.md` → 4/4 met.
- `tools/check-actions-boundary.sh` → pass; no science-compute workflow route.
- `git diff --check` → pass.

**Memory receipt:** loaded the repository `AGENTS.md`, its routed prior-work
receipt, the interval target ledger, and the Shinichi memory index before
planning. The preferred Ask-Brain CLI transport failed while trying to change
its sandboxed home configuration; the raw-memory fallback and repository
artifacts supplied the cited prior decisions. **Golden Set:** no PVT-02 Golden
Set exists; the relevant repeat-mistake class was checked through
the retained seed-window, all-attempt, and endpoint-failure negative controls.

## 6. Tests of the Tests

The tests are contract tests, not a coverage claim. They exercise lower-triangular
packing and the `exp(2*theta)` transform; compare the analytic `log(V_t)` gradient
to central finite differences; reject an unbracketed one-df LR root; reject an
overlapping seed window and a duplicate/mismapped realised seed; retain a failed
fit and a failed endpoint; and refuse promotions with 4,999 attempts, a weak lower
band, `n=150`, `unique=FALSE`, or shared seeds. The temporary ledger-CWD failure
was also reproduced and fixed before final re-verification.

## 7a. Issue Ledger

No issue was created, changed, or closed. `gh pr list` was attempted but could
not reach the GitHub API; no remote issue/PR state is asserted from this lane.

## 8. Consistency Audit

Exact scans run:

```sh
rg -n 'n_units >= 150|n_sites >= 150|certified-0\\.94' R/profile-derived.R tests/testthat/test-profile-ci-total-variance-export.R docs/design/75-inference-route-truth-matrix.md
rg -n 'PVT-02|n_units = 400|n_sim = 5000|Totoro|DRAC|GitHub Actions|ci_failed' docs/dev-log/artifacts/pvt02 dev/pvt02 tests/testthat/test-pvt02-contract.R
```

Verdict: the first scan confirms the existing broad predicate and `n=4000`
test; the second confirms that PVT-02 alone carries the frozen exact cell,
failure policy, and stop boundary. The prose-style pass found concrete local
evidence for every quantitative statement and no reader-facing certification
claim. The validation-debt row remains CI-08 `partial`.

## 9. What Did Not Go Smoothly

`basic-memory` could not write its home-directory configuration under the
sandbox, so the Ask-Brain CLI rung was unavailable; the raw memory and
source-pinned prior-work artifacts supplied the fallback. The lane-preflight
script was absent, GitHub API access failed, and Unlazy initially resolved
relative commands from its ledger directory. The last was a real flaw and is
now guarded by replayed gates.

## 10. Known Residuals

The public predicate still labels all qualifying `n >= 150` fits
`certified-0.94`, and the truth matrix still contains its stale blanket wording;
both are deliberately documented but untouched. The 5,000-attempt cell has not
run, no coverage is estimated, and no status can move. The timed pre-run projects
about 14.4 serial local hours, so Totoro approval is required before proceeding.

## 11. Team Learning

Fisher's target discipline kept the total `Sigma_unit` diagonal distinct from
the failed `psi` proxy. Noether's pure gradient and root tests keep mathematical
contract errors out of an expensive campaign. Grace caught that disjoint indices
are insufficient without checking realised seeds; the repaired validator now
checks both. Rose confirmed that no smoke result or helper leaks into a public
certification claim. Ada records that a ledger's effective working directory is
part of its contract and must be reverified after a repair.

## 12. Cross-Product Coverage

PVT-02 covers ✓ only the packet, pure arithmetic, retention policy, and two
local Gaussian `d=2`, `n=400` plumbing attempts. It does NOT cover ✗ 5,000-run
coverage, CI-08 promotion, other traits/families/tiers/ranks, bootstrap
comparison, random slopes, LV effects, public status wording, API/C++ changes,
GitHub Actions science compute, Totoro, or DRAC.
