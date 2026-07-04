# Handover checkpoint — post-#101 landing (2026-06-20)

Agent: Claude Code (Ada). Reason: context near-full; clean handover after the
approved GLLVM.jl #101 landing. **The repository is authoritative — rehydrate
from git/gh state, not chat memory.**

## Active goal + standing authorization

> Finish the Big 4 well, with R / Julia / Julia-via-R. Then: "merge everything",
> "ultracode all Julia stuff left and the bridge". Maintainer present + responsive.

Hard guard still in force: PR green != bridge complete != release ready !=
scientific coverage passed. Add evidence, never self-promote a register row.
Never `git add -A`. The maintainer authorized merges this session; high-risk
cross-repo / grammar / engine merges still warrant one explicit confirmation
(e.g. #101 was confirmed before landing).

## What is DONE (merged, verified)

### gllvmTMB `origin/main` = `b09f510` — 7 PRs landed this session
- #492 bridge admission (JUL-01/01A, partial).
- #493 full integration: cbind(succ,fail) binomial routing (LIVE-verified, exact
  parity), extract_correlations() point-only for julia, gate hardening,
  gllvm_julia_fit + latent/traits/animal/control/meta @examples, 15 pure-R
  input-validation guards. (full 3155 / live 1228 / pkgdown clean.)
- #494 coevolution multi-kernel TMB engine + COE-03/04 gates
  (predict_cross_covariance, profile_cross_rho, effect-scale extract_Gamma).
  (full 3191 / heavy 424.)
- #495 closure batch 1: EXT-10 cutpoints, FG-14/MET-01 single-V meta_V vs
  glmmTMB::equalto() comparator (~1e-9), FAM-15 wired-truncated, MIS-09 snapshots.
- #496 closure batch 2: COE-04 A2-A4 (moderate-overlap 0.45-0.55 + boundary,
  Poisson construction smoke, null-seed overfit-tail). (heavy 392.)
- #497 closure batch 3: EXT-04 mixed-family SHAPE (not calibration), DIA-11
  predictive-check display smokes, ANI-09 animal+PE composition recovery (both
  variance components recovered), RE-12 Poisson low-rank augmented latent. (343.)
- All closure batches are ADD-EVIDENCE-ONLY (Rose-audited). NO register row
  promoted — promotion is the row-owner's call (evidence now exists).

### GLLVM.jl `origin/main` = `186af2d` — #101 LANDED
- #101 (wide bridge layer: X / masks / mixed / grouped-dispersion / simulate /
  Wald-profile-bootstrap CI) merged via true merge commit. CLEAN, was 6/6 CI.
- The non-Gaussian ENGINE was already on GLLVM.jl main (#95/#99/#100); #101 added
  the bridge layer on top (why it merged clean).
- bridge_capabilities()/bridge_fit() now on GLLVM.jl main.

## DOWNSTREAM — autonomous, do NEXT (post-#101)

1. **Repoint + re-verify the live bridge against GLLVM.jl main** (the #101-landing
   confirmation). The R bridge already targets the wide surface — NO R code change
   needed, pure config:
   - Make a GLLVM.jl `main` checkout/worktree (current local GLLVM.jl is on the
     DIVERGENT `codex/non-gaussian-fitter-gradients` branch — do NOT use it).
     e.g. `git -C "/Users/z3437171/Dropbox/Github Local/GLLVM.jl" worktree add
     /private/tmp/gllvmjl-main origin/main`.
   - From a gllvmTMB checkout of `origin/main` (b09f510), run the live bridge
     suite pointing at that main checkout:
     `PATH="$HOME/.juliaup/bin:$PATH" GLLVM_JL_PATH=/private/tmp/gllvmjl-main
      Rscript --vanilla -e 'devtools::test(filter="julia-bridge")'`
     Expect FAIL 0 / SKIP 0 / PASS ~1212 (parity with the f7be594 run). Julia
     1.10 at `~/.juliaup/bin/julia` (juliaup; NOT on PATH by default).
   - Write an after-task report recording the result. This is EVIDENCE, not a
     register promotion.
2. **J1 (genuinely-new Julia engine slice):** wire #65 exact analytic Laplace
   gradients into the production `fit_*` (poisson/nb/gamma/beta/binomial), behind
   a logLik-delta <= 1e-6 vs FD gate. Files: `src/laplace_grad.jl` (L19-22,
   103/163/214/285/351) + per-family fit_*. The analytic grad is standalone +
   FD-verified but NOT yet wired (persists even post-#101). Do this on a branch
   off GLLVM.jl `main` (which now has #101). Verify: `julia --project=.
   test/runtests.jl` (test_laplace_grad.jl). NOT on the divergent branch.

## HELD for maintainer decision (do NOT force)

- **JUL-01 / JUL-01A promotion** (partial -> covered): evidence exists; the row
  edit needs Rose audit + maintainer sign-off.
- **#94** (GLLVM.jl, DRAFT, conflicting, 176 files): ADDITIVE — carries
  genpoisson/studentt/truncnb/truncpoisson/anova/diagnostics ABSENT from #101.
  Must NOT be auto-closed; fold-or-defer is a maintainer call.
- **`codex/non-gaussian-fitter-gradients`** (GLLVM.jl): divergent parallel
  engine, conflicts in 19 files. Superseded by #101; reconcile-or-abandon is the
  maintainer's call. Do NOT merge it. (50 local unpushed commits = docs churn.)
- **J2 branch** `claude/jl-bridge-capabilities-20260619`: sits on the divergent
  base; #101 ships its own test_bridge_capabilities.jl. Likely redundant — assess
  vs #101's surface, then keep or discard.
- **unique->Psi convention cascade** (`codex/unique-latent-psi-split-20260619`):
  edits AGENTS.md/CLAUDE.md/NEWS + dozens of files, conflicts on check-log. A
  grammar/rule-file cascade — held for maintainer review.
- **120-commit dirty branch** `codex/r-bridge-grouped-dispersion` (the working
  checkout): dashboard/articles + the FULLER coevolution surface
  (extract_coevolution_modules, diagnose_kernel_separability, 2226-line test) that
  did NOT land via #494's split. Needs maintainer reconciliation.
- **CI-08 / CI-10 calibration** (13/15 cells below 94%; mixed-family
  0.82/0.685/0.55): Design-50 surface admission + Fisher/Curie sign-off. NOT
  closeable by point cells.
- **In-engine rho estimation / rho intervals / Type-I calibration / module
  uncertainty** (COE-04): engine + scientific work, decision-gated.
- **Honestly blocked this session (flagged, not faked):** B4 LAM-02 Gaussian
  recovery (between-site factor unidentifiable at feasible sizes); A1/A5/A3-mixed
  COE cells (functions exist only in the dirty tree, not on main).

## Reference docs (read these)
- `docs/dev-log/2026-06-19-claude-overnight-briefing.md` (the running briefing,
  decisions 1-7 + merge-wave + Julia/bridge sections).
- `docs/dev-log/2026-06-19-bridge-finish-map.md` (the authoritative bridge scope).
- after-task: `2026-06-19-overnight-bridge-pr492-dashboard.md`,
  `2026-06-19-overnight-doc-test-hardening.md`,
  `2026-06-19-julia-bridge-finish-slices.md`.
- Dashboard: source `docs/dev-log/dashboard/`, served `/tmp/gllvm-dashboard/`,
  live 8770/8765; after edits `rsync -a docs/dev-log/dashboard/ /tmp/gllvm-dashboard/`.

## Worktrees created this session (cleanup candidates)
`git -C <repo> worktree list`. gllvmTMB: /private/tmp/gllvmtmb-{integrate,
closure1,closure2,closure3,coe-*,bridge-finish,bridge-followups,doc-examples,
input-tests}; GLLVM.jl: the J2 branch worktree. Prune stale ones; the closure
branches are all merged.

## Next-action one-liner for the fresh session
"Repoint GLLVM_JL_PATH to a GLLVM.jl origin/main (186af2d) checkout and re-run the
gllvmTMB live julia-bridge suite to confirm #101 landed clean (expect ~1212 pass);
write the after-task; then optionally J1 analytic-gradient wiring. Everything in
'HELD for maintainer' stays held."
