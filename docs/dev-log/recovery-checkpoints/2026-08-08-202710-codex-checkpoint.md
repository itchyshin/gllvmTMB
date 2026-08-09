# Codex recovery checkpoint — post-repair v4 launch boundary

Date: 2026-08-08 20:27 MDT  
Branch: `cursor/cran-0.7-20260807`  
Package identity: 0.6.0  
Working tree: intentionally dirty; no commit, push, version bump, candidate
freeze, online deployment, or CRAN upload.

## Goal and boundary

The approved Ultra Plan is still active. This checkpoint closes the bounded
warm-optimizer, comparator/Stan, and v4-harness preparation milestone. It does
not close the scientific campaign or the pre-0.7 release programme.

Shinichi explicitly authorized the narrow default warm-`nlminb` repair and
future GPL-3/authorship/logo rights. He also explicitly directed that the
package remain 0.6 for now, that no 0.7 release occur yet, and that no CRAN
submission occur before 19 August. Totoro and DRAC are available; simulation
campaigns must not run on GitHub Actions.

## Lane state

- `gh pr list --state open --limit 20`: PASS, no open PRs.
- `git log --all --oneline --since="6 hours ago"`: foreign activity exists on
  the separate integrated-SDM branch; no release-lane PR or overlapping subject
  was found.
- `git status --short --branch`: the shared release lane remains intentionally
  dirty with the approved claim, rights, reader-page, family-constructor,
  loading-unpack, warm-restart, comparator, simulation-harness, tests, and
  release-receipt work. Preserve all of it; never stage with `git add -A`.
- `git diff --stat`: 55 tracked files, 1,913 insertions and 1,048 deletions,
  plus untracked release, simulation, test, and article assets.
- `git diff --check`: PASS.

## Completed bounded evidence

### Warm default `nlminb`

- Exact route: native unpenalized Laplace, default `nlminb`, code 0, finite
  objective and raw AD gradient, positive-definite Hessian, no boundary, raw
  maximum gradient at or above the unchanged 0.01 gate.
- One warm restart uses the same objective, gradient, bounds, scale, and
  controls; acceptance requires a strictly lower raw gradient and the frozen
  64-epsilon objective tolerance.
- Rejected/error candidates restore optimizer/report/sdreport/health plus TMB
  `last.par`, `last.par.best`, and `value.best`.
- Package output now matches the exact ordered 13-field v4 restart provenance
  schema.
- Focused pure: 64 expectations PASS, six declared heavy skips.
- Focused heavy: 125 expectations PASS.
- Relevant ordinary and heavy regression matrices PASS; the heavy matrix keeps
  four pre-existing honest profile-CI skips.
- Independent Gauss rereview: PASS for this bounded repair.

### Independent comparator and Stan recertification

- Six exact `glmmTMB` rows PASS / zero HOLD: Gaussian `indep`, `dep`, and
  `latent`; Poisson, NB2, and binomial-logit `latent`.
- Maximum observed discrepancies across the six rows were approximately
  `3.32e-08` in absolute log-likelihood, `1.89e-05` in fixed effects,
  `4.17e-05` in total covariance, `6.87e-05` in Psi, and `3.48e-05` relative
  for NB2 phi. All fits had optimizer code 0, positive-definite Hessians,
  gradients below 0.004574, assessed/no boundary flags, and no warm restart.
- Stan token `cran07-20260809T015214Z-codex`: K1 6/6, K2 3/3, combined 9/9;
  maximum relative discrepancy `8.062e-16`. K1/K2 output SHA-256 values are
  recorded in
  `docs/dev-log/release/2026-08-08-cran07-comparator-recertification.md`.
- One earlier token is retained only as a mechanical HOLD and contributes no
  scientific evidence.

### V4 zero-fit harness

- Independent adversarial rereview: PASS for harness integrity.
- Canonical production surface: 31 cells; challenge cells remain pilot-only;
  Gaussian latent n=60 and NB2 n=100 remain characterization-only public
  fences.
- Manifest, estimand, restart, source-binding, structural-Psi, NB2-phi, and
  recomputed truth-metric checks fail closed.
- `Rscript --vanilla inst/sim/cran07-v4/self-test.R`: PASS with `fits_run=0`
  and `launch=HOLD_PENDING_SOURCE_ARCHIVE`.
- Frozen SHA ledger: all 18 entries PASS.

### Stable-source full ordinary suite

Command:

```sh
Rscript --vanilla -e 'devtools::test(reporter = "summary", stop_on_failure = FALSE)'
```

Result: exit 0; no failures or errors; 806 declared skips; two known `gllvm`
warnings for all-zero response rows. The repaired comparator and warm-restart
files passed inside this stable-source run.

## Current hard hold

The canonical binding
`docs/dev-log/simulation-artifacts/2026-08-08-cran07-v4-preregistration/source-archive-binding.csv`
is intentionally:

```text
status=HOLD_PENDING_SOURCE_ARCHIVE
launch_authorized=FALSE
```

No v4 source archive exists or is authorized. Do not invent or reuse an older
digest. The archive must capture the exact current 0.6 validation source needed
on Totoro/DRAC, and its absolute-path contract must be reconciled with remote
deployment before changing the binding to READY.

## Next safest action — start a fresh task

1. Rehydrate from this checkpoint, `git status --short --branch`, `git diff
   --stat`, and the tail of `docs/dev-log/check-log.md`.
2. Inspect the v4 archive/deployment contract and create one exact,
   metadata-controlled 0.6 source snapshot without changing package identity.
3. Verify the canonical binding locally; run the two-attempt local smoke.
4. If smoke passes, deploy the exact bound archive to Totoro, run the frozen
   20-attempt pilot, and adjudicate admission. DRAC is available for overflow.
5. Do not launch production unless the pilot gate passes. Retain every attempt.
6. After v4 scientific adjudication, start a separate fresh task for the full
   open-issue sweep before any 0.7 identity/source freeze.
7. Online 0.6 documentation may be published later; do not call it 0.7. No CRAN
   action before the explicit 19 August owner decision.

## Commands not run in this milestone

- No v4 smoke, pilot, or production fit.
- No Totoro or DRAC campaign.
- No GitHub Actions simulation campaign.
- No source binding or launch authorization.
- No version bump, package/site release, commit, push, PR, candidate freeze, or
  CRAN upload.
