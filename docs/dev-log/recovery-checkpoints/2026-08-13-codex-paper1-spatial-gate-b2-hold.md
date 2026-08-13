# Recovery checkpoint — Paper 1 spatial Gate-B2 numerical-admission HOLD

- **Branch / commits:** `codex/isdm-paper1-spatial-gate-b2`; safeguards
  `60646dc2`, receipt-integrity correction `d5c1481c`.
- **Worktree:** `/private/tmp/gllvmtmb-isdm-paper1-spatial-gate-b2`.
- **Immutable private evidence root:**
  `dev/isdm-package-recovery/results/paper1-spatial-gate-b2-d5c1481c`
  (ignored; manifest, fixture truth, fit, all-attempt ledger, telemetry and
  time estimate retained).
- **Exact outcome:** one fit returned in 12.324 s, code 0, finite objective,
  max gradient 0.003392914, PD Hessian TRUE, no flags/warnings. Its package
  admission record is Case D / FALSE (`unsupported_raw_gradient_state`), so
  this is `PRIVATE_NUMERICAL_ADMISSION_HOLD`, not PASS. RSS is `NA` on macOS.
  A second invocation was rejected before fit.
- **Changed tracked files:** runner, fixture, B2 alignment note, B2 receipt
  test, after-task report, this checkpoint, and check log.
- **Commands completed:** targeted B2/private-spatial no-fit tests; preflight;
  one smoke; consumed-root rejection check; ledger/manifest inspection.
- **Do not redo:** do not rerun this root, fit Paper 2, profile, repair, launch
  a campaign, use Totoro/DRAC, or infer recovery from the smoke.
- **Next safest action:** retain the HOLD or obtain explicit approval for a
  separately specified numerical-admission redesign. Do not launch a recovery
  campaign from this smoke. Start from this checkpoint and the after-task report.
