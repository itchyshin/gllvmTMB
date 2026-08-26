# Handover: release-complete interval calibration

Date: 2026-08-25
Platform: Codex
Repository: `gllvmTMB`
Branch: `codex/interval-calibration-release`
Release base: `f5ba7bdb2e454f3d3cda34936f0bb9b746459e68`
Latest implementation/truth SHA before closure documents:
`c86968ab9d69cd88f06e8892b4c00f451edd3691`

## 1. Goal and terminal result

The approved programme replaced interval-route availability with an evidence
status for every public CI-08--CI-15 route. The terminal census contains 19
exact route identities, each `certified`, `limited`, `blocked`, or `refused`.
Only three routes are certified:

- `CI13-loading-n150-d2`
- `CI13-loading-n400-d1`
- `CI13-loading-n400-d2`

Those certificates cover only structurally free strict-lower standardized
loading targets from the symmetric joint-delta Wald method in native pinned,
unrotated, ordinary-Gaussian three-trait cells, for one frozen DGP, conditional on eligible fits.
The DGP fixes trait intercepts `(-0.20, 0.10, 0.25)`, unique SDs
`(0.70, 0.80, 0.90)`, and loading vector `(0.80, 0.45, -0.35)` for `d=1`, with
second column `(0, 0.70, 0.40)` for `d=2`. Availability was 98.82%, 93.38%,
and 96.18% in the three certified regimes. They do not widen to another
truth-parameter regime, pinned
diagnostics, Fisher-z Wald, arbitrary constraints, raw/profile/bootstrap
targets, rotations, or neighbouring cells.

## 2. Critical scientific boundary

`profile_ci_total_variance()` is callable but not calibrated. Every computed
row is `route-only`; unavailable rows are `none`. Historical callable CI-08
rows are terminally `limited`. The exact PVT-02 campaign is terminally
`blocked`: its numerical gates pass, but retained endpoints cannot establish
constrained-refit convergence and exact target attainment for the requested
likelihood-ratio profile. This distinction is intentional and locked by the
exact 19-route/state oracle.

CI-09 is campaign-blocked because the frozen one-pair-per-unit DGP does not
identify the separately scored unit-tier correlation. CI-10 is blocked for the
nonlinear profile and limited for the named Wald/bootstrap/contrast routes.
CI-11/12 remain typed refusals. CI-14 is blocked at the frozen-source guard;
CI-15 remains blocked because its predecessor did not produce an aggregate.

## 3. Evidence and attempts

The canonical all-attempt ledger is
`docs/dev-log/artifacts/interval-calibration/2026-08-25-all-attempt-ledger.csv.gz`:
150,019 rows, SHA-256
`f8c1f33308b0ccb9bed684a99a746f415d79f090875756a6eba752e577dfbe4a`.
The target recomputation has 18 rows, SHA-256
`3d204c754d9cada7858c656341a7d8234c018af9a7c874772b666632018f9047`.

The invalid first Totoro deployment is retained as 85,000
infrastructure-excluded attempts. Corrected r2 PVT-02, CI-09, and CI-13 output,
CI-14 source-guard failures, and every Fir CI-10 cost-preflight result remain in
the denominator trail. No scientific failure was retried away. No science
compute or campaign output used GitHub Actions.

## 4. Verification state

- `Rscript --vanilla dev/interval-calibration/verify-claims.R`:
  `INTERVAL_CLAIMS_OK`.
- Focused claims/loading/total-variance tests: 98 passes, 35 intentional heavy
  skips, zero failures or warnings.
- Complete ordinary suite: 523 configured files passed across five deterministic
  shards (112 + 79 + 223 + 108 + 1). The earlier monolithic run overran its
  estimate and was stopped; it is not counted as a pass.
- `devtools::document(quiet = TRUE)` succeeded with only the pre-existing
  AIC/BIC/anova S3 export warnings.
- Both affected articles rendered locally, and `pkgdown::check_pkgdown()` found
  no problems before and after independent-review repairs.
- Clean replay reproduced the target CSV byte-for-byte and the RDS numerically.
- Fresh Terra statistical, Terra release, and Sol-high D-43 reviews: PASS at full SHA
  `c86968ab9d69cd88f06e8892b4c00f451edd3691`, with no P0--P3 findings. They
  independently verified the repaired DGP/eligibility and `unrotated` fences,
  census mutations, arithmetic, stale-comment removal, and absence of API/C++
  scope widening. Rose's final exact-SHA closure review also returned PASS;
  Grace's final reproducibility review returned PASS after independently
  checking the archive and tracked hashes, canonical identities, seed windows,
  retained raw store, compute routing, and exact claim boundaries.
- `seed-registry.csv` is the frozen pre-run reservation registry. Its
  `reserved; not executed` rows are reservations, not a claim that every packet
  was launched.
- Final Rose, Grace, after-task validation, and Unlazy evidence are recorded in
  the closure report/ledger before the final local closure commit.

## 5. Commits and files to read first

Read in this order:

1. `docs/dev-log/artifacts/interval-calibration/2026-08-25-terminal-campaign-evidence.md`
2. `docs/dev-log/artifacts/interval-calibration/public-route-census.csv`
3. `docs/dev-log/artifacts/interval-calibration/interval-target-ledger.md`
4. `docs/dev-log/after-task/2026-08-25-interval-calibration-release.md`
5. `docs/dev-log/plan-actual/2026-08-25-interval-calibration-release.md`

Load-bearing commits include:

- `a1d18411` retain terminal campaign evidence
- `3c0c2ff7` make target evidence replayable
- `a8732db6` adjudicate interval calibration claims
- `52cdf3b8` fail closed interval calibration claims
- `f68e6bba` lock exact interval release dispositions
- `884f0184` synchronize interval calibration truth surfaces
- `eacbdc88` bind interval reviews to current claim surfaces
- `7cff7e16` narrow CI-13 certificates to tested regimes
- `c86968ab` bind final interval claim fences

## 6. Landing state

`CARRIED-OVER` — the branch is deliberately local and unpushed. The maintainer
approved local commits but did not authorize push, PR, merge, release, issue
comments, or other public messages. The pre-handover landing gate therefore
reported the branch's unpushed commits and the prospective closure documents;
that non-zero result is declared here rather than hidden.

Resume from the exact worktree:

```sh
cd /Users/z3437171/.codex/worktrees/d899/gllvmTMB
git status --short --branch
git log --oneline --decorate -12
```

Do not infer that another worktree or `origin/main` contains this lane. Do not
push or merge without new maintainer authority.

No fresh `R CMD check` or 3-OS CI was run after the final claim-only repair.
The local 523-file ordinary test receipt and documentation checks do not make
this a merged or cross-platform package release.

## 7. Residual work and safe next actions

No further CI-08--CI-15 campaign is authorized or required for this closure.
Future work must start as a new bounded lane:

- CI-08: implement an exact constrained-refit profile with endpoint convergence
  and target-fidelity retention, then recalibrate.
- CI-09: redesign the DGP so the scored unit-tier correlation is identified.
- CI-10: obtain a successful small nested-bootstrap cost preflight before any
  `18 x 5000 x 499` proposal.
- CI-14: repair frozen-source provenance before a new approved campaign.
- CI-15: remain blocked until its predecessor completes.

CI-11/12 nonlinear profiles remain refused. New MSPL, prediction/missing-data
intervals, LV expansion, rotated/unconstrained loading calibration, new APIs,
C++, and random-slope point-recovery are outside this lane.

## 8. Gotchas and findings of record

- The lease helper once printed `GRANTED` after its registry write failed in the
  sandbox. The lane reissued and verified the lease outside the sandbox; never
  treat the first printout as ownership evidence.
- Pkgdown article names require the `articles/` prefix.
- The planned-seed scanner must exclude only the exact current-programme PVT
  cross-root ledger or it treats the programme's own seed receipt as history.
- Callable status and campaign terminal status are different axes for CI-08;
  do not flatten `route-only` and `blocked` into one label.

FINDING-OF-RECORD: CI-08 penalty profiles cannot support exact-LR certificates;
the frozen CI-09 DGP does not identify its scored unit-tier correlation; and
only three frozen-DGP, eligible-fit-conditional CI-13 standardized-loading
regimes earned certificates. The
canonical branch sources are the tracked terminal evidence and route census.
vault-note: OWED/BLOCKED -- this Codex lane was not explicitly authorized to
write or update Shinichi's memory vault; distil these findings only after that
authority is granted.
