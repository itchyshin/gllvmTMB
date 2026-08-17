# After Task: Fenced MSPL profile-CI scaffold

**Branch**: `cursor/mspl-profile-ci-scaffold`
**Date**: `2026-08-17`
**Roles (engaged)**: Ada / Curie / Rose / Fisher

## 1. Goal

Land **fenced** internal scaffolding for a profile-interval construction on a toy LA-MSPL point fit, keep public `confint` refused, and document Wald \(Q_0\) as the quick baseline versus profile as the signature. Triad Confirm is SIGNED; this PR stays draft. New construction only (D-157). Do not reopen Design 118. Do not run Totoro.

## 2. Implemented

- Internal, unexported helpers in `R/mspl-profile-ci-stub.R`.
- Toy Gaussian `se=FALSE` fit still errors on public `confint` / `vcov`.
- Scaffold returns `public_confint = "refused"` and `profile$status = "not_constructed"`.
- Wald \(Q_0\) is labelled `quickest_baseline`; optional pin is the existing D-149 helper, not a public Wald interval.
- Research note coordinates with sibling triad note `2026-08-17-mspl-ci-wald-plus-profile.md`.

## 3. Files Changed

- `R/mspl-profile-ci-stub.R` (new)
- `tests/testthat/test-zz-mspl-profile-ci-stub.R` (new)
- `docs/dev-log/research/2026-08-17-mspl-profile-ci-scaffold.md` (new)
- `docs/dev-log/after-task/2026-08-17-mspl-profile-ci-scaffold.md` (this file)
- `docs/dev-log/check-log.md` (prepend)

No `NAMESPACE`, `NEWS.md`, `src/`, registry, or `R/z-confint-gllvmTMB.R` edits.

## 3a. Decisions and Rejected Alternatives

- **Decision:** stub the construction door; do not invert a profile while G0 is open. **Rationale:** `#1073` and the triad note both forbid implementing MSPL `confint(method="profile")` from a sketch. **Rejected:** calling `TMB::tmbprofile()` on the toy fit. **Confidence:** high.
- **Decision:** fence the stub to Gaussian identity / Poisson log `se=FALSE`. **Rationale:** point-admitted ordinary cells; avoid binary SE (Lane B protected). **Rejected:** binomial toy (Lane B). **Confidence:** high.
- **Decision:** default `run_wald_q0=FALSE`. **Rationale:** CI time; Hessian is already tested in the pin suite. **Rejected:** always running `optimHess`. **Confidence:** high.

## 4. Checks Run

Recorded in `docs/dev-log/check-log.md` for this sitting.

## 5. Tests of the Tests

- Source scan would fail if the stub called `TMB::sdreport()`, `confint(`, or `@export`.
- `z-confint-gllvmTMB.R` scan would fail if the stub were wired into the public method.
- Toy Gaussian test would fail if `confint(method="profile")` stopped refusing.
- Family-fence test would fail if a binomial fake fit were accepted.

## 6. Consistency Audit

```sh
rg -n 'export|TMB::sdreport|confint\\(' R/mspl-profile-ci-stub.R
# expect no export / sdreport / confint call
rg -n 'mspl_profile_ci_scaffold|mspl_ci_triad' R/z-confint-gllvmTMB.R
# expect 0
rg -n 'signature|quickest_baseline|asymmetry|D-157|parked' \
  R/mspl-profile-ci-stub.R \
  docs/dev-log/research/2026-08-17-mspl-profile-ci-scaffold.md
```

## 7. Roadmap Tick

N/A — no `ROADMAP.md` row. `MSPL-04` stays `blocked`.

## 7a. GitHub Issue Ledger

No relevant open issue for this scaffold; no new issue created. Interval work remains a new construction under D-157, not a Design 118 ticket.

## 8. What Did Not Go Smoothly

The MSPL estimator-programme worktree was dirty on `cursor/mspl-poisson-admit-packet`. Scaffolding landed in a fresh worktree `/private/tmp/gllvmtmb-mspl-profile-ci-scaffold` from `origin/main` @ `#1073`. Sibling triad note may land as a parallel docs PR; this slice cites the path and does not copy the doctrine file.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

**Ada.** G0 stays open; this is a door, not a pick. Do not treat a green test as permission to profile.

**Curie.** Tests prove refuse + unexported + role labels. They do not prove a profile interval exists.

**Rose.** Sketch ≠ Design ≠ covered claim. Sibling triad note owns the paste; this file owns the helper contract. Do not merge a NEWS covered line.

**Fisher.** Wald \(Q_0\) remains availability / triage. Profile remains the signature construction and is still unbuilt.

## 10. Known Limitations And Next Actions

- This scaffold still leaves `profile$status = "not_constructed"` (no calibrated / public profile CI). Binomial profile *computability* on `main` (`#1090`) is a separate probe — wording reconciled so we no longer say “bounds are not computed while Design G0 is open.” Objective fork A/B/C for a claim path stays unpicked.
- Optional `run_wald_q0=TRUE` is untested in CI (Hessian cost).
- Next: wait for Shinichi G0 on the triad paste; then a **new Design number**, not Design 118. No Totoro until that pre-registration exists.
