# G2d S0 reconciliation receipt

## Exact branch and HEAD

- Worktree: `/private/tmp/gllvmtmb-isdm-g2d-six-species`
- Branch: `codex/isdm-g2d-six-species`
- HEAD: `7c277d4181f06ebcb060c2a857e52c5ac41d7566`
- State at reconciliation: clean.

The lane preflight found no foreign or second active Codex lane in its time
window. The GitHub PR query could not connect, so this receipt relies on the
local lane board and git history; it makes no remote-state assertion.

## Protected G2c disposition

G2c remains `G2C_SMOKE_ADMISSION_HOLD`. Its retained retry root failed the
frozen two-sided profile rule. It is not recovery evidence, cannot be reused,
and is not changed by this receipt.

## G2d root inventory

| Evidence class | Final status | Meaning |
| --- | --- | --- |
| deterministic/no-fit contract | PASS | Row contract, pairing, rank-one packing, and six-coordinate Psi checks passed; no fit was made. |
| write-path smoke | HOLD | Retained failure; no usable fitted output. |
| profile-harness smoke | HOLD | Retained harness failure; no recovery inference. |
| complete smoke | HOLD | Retained but ineligible under the frozen smoke rule; no Totoro admission. |
| diagnostic map/extractor fit | assembly PASS only | One retained fit establishes the six-coordinate parameter-map and `extract_Sigma` identities. |
| diagnostic re-audits | no-fit PASS | Verify retained diagnostic artifacts; do not replace its original receipt. |

The initial `G2D_DIAGNOSTIC_MAP_HOLD` records a checker-label failure. The
later no-fit audit passed all 12 assembly checks. These records are
chronological, not contradictory: neither is a smoke or recovery PASS.

## Map/extractor claim boundary

The retained diagnostic establishes only `theta_rr_B -> Lambda_B`,
`exp(theta_diag_B) -> sd_B`, and the shared, unique, and total covariance
reconstruction identities. It does not establish profile eligibility, estimator
recovery, interval behaviour, Totoro eligibility, or a public capability.

## Final factual status

**G2c smoke HOLD; G2d smoke HOLD; G2d diagnostic assembly PASS only;
recovery/Totoro/campaign not admitted.** All ignored result roots remain
protected and untouched.

## Authority required for any next fit

Any future S3 diagnostic or replacement smoke needs fresh explicit authority,
a frozen commit and protocol receipt, a new immutable output root, retained
starts/profiles/failures, and a pre-run output inspection. It must first close
the S1 numerical-tail blocker recorded in the S1 certificate.
