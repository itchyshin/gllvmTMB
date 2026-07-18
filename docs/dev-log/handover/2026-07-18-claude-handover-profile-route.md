# Session handover — profile-route interval coverage MEASURED; next arc = cheap gaussian close + binomial diagnostic (NOT multi-dim AGHQ yet)

**Meta:** 2026-07-18 · from Claude (Opus 4.8) · TARGET = Claude or Codex · branch
`claude/profile-coverage-remeasure-20260718` (off `claude/release-0.5.0`). Executable plan (comprehensive,
CORRECTED): `/Users/z3437171/.claude/plans/dynamic-tumbling-newell.md`. After-task:
`docs/dev-log/after-task/2026-07-18-interval-coverage-profile-route.md`.

## Critical context (read or you will re-run finished work / re-import a disproven claim)
1. **The profile-route measurement is DONE** (A1 wire + A2 pilot + A3 confirm + PF-5 discriminator). Results
   LOCAL: `results/profile-pilot-{A2,A3,pf5}/`. **Nothing certified, nothing committed, nothing promoted.**
2. **Two over-claims were made THEN RETRACTED this session** — do not re-import them:
   - Gaussian is NOT "nominal incl. n=50 / earned." A3 (n_sim=4000, honest MCSE ~0.0017): **n≥150 borderline
     ~0.945–0.949** (one cell marginally <0.95); **n=50 sub-nominal ~0.94**. The χ²₁ profile has a mild
     residual under-coverage even at n=150.
   - Binomial under-coverage is NOT the "two-lever ML-Laplace floor / fixed by Phase-B REML+AGHQ." **PF-5
     (3 constructions on identical fits) DISPROVED it:** constructions disagree 23pp on the same fits; point
     est/truth wildly UPWARD (9.6–122×); psi→0 boundary collapse in 68–98% of fits → **construction +
     boundary-collapse, NOT the estimator floor.** The Phase-B two-lever route is UNCONFIRMED and could mis-route.
3. **The wire is UNCOMMITTED.** Commit is the maintainer's act (not done). Turnkey block below.

## What was accomplished
- **Wire (A1a/b/c):** profile → `coverage_certificate` (never `coverage_primary`); rho:unit target (truth on
  Sigma_total); PF-3 endpoint-sanity guard; scale gate reads certificate; `trait_j` in dedup key; nbinom2 fenced
  at selector; live-index certificate mirror. Files: `dev/m3-grid.R`, `dev/m3-pilot-report.R`,
  `dev/m3-pilot-launch.R`, `dev/profile-pilot-run.R` (new runner), `dev/test-profile-coverage-remeasure.R` (new).
- **Verified:** 56/56 + 19/19 tests; W2 adversarial diff-review PASS; W5 conclusion panel (caught the over-claims);
  PF-5 discriminator.
- **Measured (Totoro, source-built, LOCAL):** A2 n_sim=200 (24 cells), A3 n_sim=4000 (8 gaussian), PF-5 (4 binomial
  × 3 constructions). Numbers in the plan's "A2 RESULTS" + "A3 + PF-5 FINAL RESULTS".

## NEXT ARC (recommended — evidence-ordered, cheap-first; NOT "jump to AGHQ")
1. **Bartlett-correct the gaussian profile** — the crit is a bare `qchisq(level,1)/2` (`R/profile-ci.R:26-33`);
   add the one-line `crit·(1+b/n)` with **`b` ESTIMATED on our fits** (mean profile deviance / short LR bootstrap),
   re-score gaussian → is n≥150 cleanly 0.95? Cheapest path to the actual certificate. Construction-level, no engine change.
2. **Gaussian REML for n=50** — `reml_bridge()` supports Gaussian; the n=50 shortfall (coverage ~0.94, ≈1pp
   below 0.95; point bias ~2%, est/truth ~0.98) is CONSISTENT WITH the finite-cluster ML VC bias — REML is the
   cheap TEST of that (available NOW), not an asserted cause.
3. **Binomial boundary-collapse DIAGNOSTIC** — why psi→0 in 68–98% of binomial fits and est/truth blows up
   (9–122×)? Identifiability of ΛΛ' vs link-residual vs Ψ at signal 0.5? DGP realism? extract-scale? **Do this
   BEFORE any Phase-B engine build.** Building multi-dim AGHQ + Cox-Reid (curse of dimensionality, sign-off) on
   the current unconfirmed diagnosis would likely be the wrong fix.
4. **Then** D-43 panel + register CI-08/CI-10/CI-07 (only what's earned) + widget/NEWS — maintainer's call.

## Landing state (git ledger — NOT landed)
| branch | committed | pushed | state |
|---|---|---|---|
| `claude/profile-coverage-remeasure-20260718` (dev/ wire + tests + docs) | **n** | n | uncommitted, maintainer's call |

**Turnkey commit (run only when the maintainer says so):**
```bash
cd "/Users/z3437171/Dropbox/Github Local/gllvmTMB" && \
Rscript dev/test-profile-coverage-remeasure.R && Rscript dev/test-pilot-scale-gate.R && \
git add dev/m3-grid.R dev/m3-pilot-report.R dev/m3-pilot-launch.R dev/profile-pilot-run.R \
        dev/test-profile-coverage-remeasure.R dev/test-pilot-scale-gate.R \
        docs/dev-log/after-task/2026-07-18-interval-coverage-profile-route.md \
        docs/dev-log/handover/2026-07-18-claude-handover-profile-route.md && \
git commit -m "feat(m3): profile-route interval-coverage wire + measurement (Phase A)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```
**Never-commit (do NOT stage):** `docs/dev-log/*tier2a*`, `dev/phylo-multinomial-harness-DRAFT.R`, the tier2
multinomial handovers, `.claude/`, `docs/dev-log/check-log.md` (other lane).

## Resume / compute
Totoro `~/gllvm_work` (Rlib built from this branch; preflight `.profile_ci_total_variance`=TRUE). Runner
`dev/profile-pilot-run.R` (scope flags). Monitoring: background waiters + local `sleep` are sandbox-killed (exit
144) — poll via SHORT no-sleep ssh, or a FOREGROUND ssh whose `sleep` runs REMOTELY. Compute ≤100 cores, results
LOCAL never GitHub (D-50). D-43 default NOT-DONE; Lane C off-limits.
