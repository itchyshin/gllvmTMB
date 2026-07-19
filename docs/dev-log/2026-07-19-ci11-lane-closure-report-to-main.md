# CI-11 cross-family interval lane — CLOSURE + report to the main lane (2026-07-19)

**Lane:** multinomial cross-family `extract_cross_correlations()` interval certification (CI-11).
**Branch:** `claude/cross-family-ci11-20260718` (off `main`, PR #766 merged). **Status: CLOSED for this arc.**

## Report to the main lane (one paragraph)
The cross-family interval-coverage certification RAN END TO END (Totoro pilot → DRAC super-sim job 49532634,
n_sim=13000/n_boot=499, 6389 shards → aggregate → D-43 panel). **Outcome: "all routes validated" WITHHELD
(D-43 3/3 NOT_DONE).** Honest route disposition (MEASURED, not certified): **profile = partial** (most robust;
contrast_r only), **wald = partial** (heuristic, r-dependent), **bootstrap = not_covered / fenced**. **No route
covers at the r=0.8 boundary** — pooling over r had masked it. Mechanism RESOLVED + empirically confirmed:
**finite-sample attenuation bias of the plug-in correlation functional** (binomial GLLVM loadings shrink at high
r), inherited by bootstrap+wald, escaped by likelihood-based profile; `multiple_r` has no profile route so both
its routes collapse (binomial×r=0.8×N=500 → **0.303**). **The CI-11 register / NEWS / roxygen are UNTOUCHED**
and must stay so until the fix + Ayumi's external pass + maintainer sign-off.

## Landed (committed on the branch)
`4bce0d65` full route×estimand arms + bootstrap→contrast_r · `0af25fd1` Feeder-2 hardening pass 1 (MASS guard +
contrast_r clamp) + hardening map · `bcdd0338` pilot aggregate + reconcile · `d085ba22` MEASURED certificate ·
`de30785f` D-43 WITHHELD + per-cell decomposition · `53df7da2` failure mechanism · `9d4a5568` after-task closure.

## UNCOMMITTED (applied on disk; blocked only by a transient Opus-classifier outage that gated Bash/git)
1. **Feeder-2 hardening pass 2 (H1–H6)** — R/bootstrap-sigma.R (H2 non-finite→NA before quantile; H3 surface
   bootstrap point-estimate failure via `.point`), R/extract-correlations.R (H1 bootstrap family-allowlist
   warn+stamp; H5 Scc rcond warn), R/profile-derived.R (H4 non-monotone-bracket one-shot warn), dev/
   cross-family-coverage.R + dev/xfc-aggregate.R (H6 honest per-shard n_nonconverged + AUTO-scale truth
   assertion). All are defensive guards designed as NO-OPS on the certification grid. **VERIFICATION PASSED:
   parse OK (all 5 files) + load OK + 40+25 cross-family testthat ALL PASS (run `b2r32j1bz`, exit 0)** — confirms
   no certification-grid regression. Still pending ONLY because the Opus-classifier outage gated Bash/git: (a) the
   `dev/xfc-stress-test.R` confirmation re-run, (b) the adversarial-review workflow, (c) the commit itself.
   NEXT SESSION (or when the outage clears): run the stress-test, then commit (turnkey below). The testthat gate
   is already green.
2. **`docs/dev-log/2026-07-19-ci11-register-update-PROPOSAL.md`** + **`…-ci11-lane-closure-report-to-main.md`**
   (this file).

### Turnkey commit (run when the classifier is back + the tests pass)
```bash
cd /Users/z3437171/gllvm_work/gtmb-xfam-ci11
# 1. verify FIRST (must be clean):
NOT_CRAN=true Rscript -e 'suppressMessages(pkgload::load_all(".",quiet=TRUE,compile=FALSE));
  testthat::test_file("tests/testthat/test-cross-family-intervals.R", reporter="summary");
  testthat::test_file("tests/testthat/test-cross-family-multinomial.R", reporter="summary")'
XFC_STRESS_MAIN=1 Rscript dev/xfc-stress-test.R   # should stay all-ok
# 2. then commit:
git add R/bootstrap-sigma.R R/extract-correlations.R R/profile-derived.R \
        dev/cross-family-coverage.R dev/xfc-aggregate.R \
        docs/dev-log/2026-07-19-ci11-register-update-PROPOSAL.md \
        docs/dev-log/2026-07-19-ci11-lane-closure-report-to-main.md
git commit -m "harden(cross-family): Feeder-2 pass 2 (family-allowlist, Inf-strip, point-fail, profile bracket, rcond, honest nnc + AUTO truth) + CI-11 lane closure

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

## Carried over (multi-session / human-gated — NOT this lane)
- **profile-`multiple_r` fix arc** (maintainer-design-gated — the deliberately-fenced un-profileable functional;
  the principled repair per the mechanism doc). Task chip `task_25cbceb0`. → re-measure → fresh D-43.
- **Ayumi's external real-data pass** (external human).
- **Maintainer decision on the route-specific register update** (the PROPOSAL doc; Design 39 gate).
- Remaining hardening-map minors (task chip `task_7368e457`).

## Maintainer decisions still open
1. **Push** `claude/cross-family-ci11-20260718` to the remote (8 landed commits + the uncommitted pass-2 above)?
2. **`/goal clear`** — the session `/goal` targets the CI-11 register flip, which is correctly human-gated; it
   will keep re-firing until cleared.
