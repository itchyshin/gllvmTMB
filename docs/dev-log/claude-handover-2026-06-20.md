# Claude handover — 2026-06-20 ~12:35 MDT (gllvmTMB + GLLVM.jl)

For the next Claude session. **The repository is authoritative** — rehydrate from
git/gh + the files below, not from chat. Prior session (Ada) ran a long
autonomous push under `/goal "work till 2pm; keep the widget truthful; bridge
R↔Julia; merge and keep going"`.

## Read first (in order)
1. This file.
2. `docs/dev-log/recovery-checkpoints/2026-06-20-123123-claude-autonomous-run-checkpoint.md` (newest).
3. `docs/dev-log/2026-06-20-psi-grammar-execution-plan.md` + `docs/dev-log/2026-06-20-psi-cascade-spec.md` (item 1).
4. `docs/dev-log/2026-06-20-r-julia-bridge-coordination.md` (bridge state).
5. `docs/dev-log/2026-06-20-held-item-reconciliation-audit.md` (the HELD-item disposition).
6. `AGENTS.md`, `CLAUDE.md`, `~/.claude/memory/memory_summary.md` (gllvmTMB section).
Then: `git -C <gllvmTMB> log --oneline -10`, `gh pr list --state all -L 12`,
`gh pr list -R itchyshin/GLLVM.jl --state all -L 12`.

## Current heads / state (verify with git)
- gllvmTMB `origin/main` = **bc7118f** — **0 open PRs**.
- GLLVM.jl `origin/main` = **da135f1** — **0 open PRs**.
- Mission control live **r55** at http://127.0.0.1:8770/ (source `docs/dev-log/dashboard/`,
  served `/tmp/gllvm-dashboard/`). Metrics unchanged all session: covered 2 / partial 9.

## Standing authorization + hard guards (still in force)
- Maintainer authorized "merge everything" + "keep going" + "I trust your decisions".
  **But engine/export/grammar merges to shared main still need an explicit
  per-item go** (auto-mode classifier enforces this — it blocked a generic-trust
  engine merge; #103/#111/#500 each merged only after an explicit "yes merge").
- Never self-promote a validation-debt register row (partial→covered = row-owner +
  maintainer). Never `git add -A` (stage by name). Honest status: if a gate can't
  pass honestly, STOP and report blocked — don't loosen tolerances / cherry-pick seeds.
- Dashboard hygiene: bump `version.txt` AND `index.html const BUILD` together, then
  `rsync -a docs/dev-log/dashboard/ /tmp/gllvm-dashboard/`, then `curl -s :8770/version.txt`.
  (Source lives on the dirty branch `codex/r-bridge-grouped-dispersion` = the working
  checkout; the live board updates via rsync, not git.)

## Merged this session
- gllvmTMB: #498 (bridge re-verify, live 1228/0/0/0), #499 (HELD-item audit),
  #500 (coevolution salvage — `extract_coevolution_modules` + `diagnose_kernel_separability`,
  full DoD: recovery test + extractor contract), #501 (R↔Julia coordination),
  #502 (Psi execution plan), #503 (Psi cascade spec).
- GLLVM.jl: #102 (J1 docstring truth-fix), #103 (masked Poisson/Binomial analytic),
  #111 (masked NB/Gamma/Beta analytic). → **analytic Laplace gradient is the
  production default + gated across all 5 non-Gaussian families, masked AND
  unmasked.** #94 closed superseded → successor issues **#104–#110**.

## IN FLIGHT — check first thing
**GenPoisson family (#104)** was being built by a background Workflow
(`wf_92e39ee3-d70`, plan→implement→verify) in the prior session — it may not have
finished and **does not carry into a new session**. The implementer agent works in
worktree **`/private/tmp/gllvmjl-genpoisson`** (branch `claude/genpoisson-104-20260620`),
commits locally, does NOT push. New session: inspect that worktree
(`git -C /private/tmp/gllvmjl-genpoisson log --oneline -3`, `git diff --stat`,
run its tests with `PATH="$HOME/.juliaup/bin:$PATH" julia --project=. test/<file>`).
If it's clean + verified (FD-gradient ≤1e-6, Poisson-limit, recovery) → push +
open a **held** PR. If partial/missing → re-run the GenPoisson Workflow (script at
`.../workflows/scripts/genpoisson-family-wf_92e39ee3-d70.js`) or re-do. Held for
maintainer sign-off regardless.

## The next-5 plan (proposed + accepted; balanced R↔Julia)
1. **unique→Psi grammar migration** (R) — *de-risked + decision-mapped on main*
   (#502 + #503). ~445 usages. **Execution is BLOCKED on 6 decisions (🔴 maintainer
   + Boole/Noether)** — see #503 / the dashboard "Next decision" card:
   - **D0**: the core `residual=TRUE` parser change and the cascade must land
     together (else double-count Psi / redundancy-abort).
   - **D1**: do `phylo_latent`/`spatial_latent`/`kernel_latent` also auto-carry Psi,
     or only ordinary `latent()`?
   - **D2**: does `residual=TRUE` auto-supply the augmented slope-block Psi
     (`latent(1+x|unit)`)? RE-12 tests depend on it.
   - **D3**: `kernel_unique()` stays compat (C1 phylo-equivalence gate, Paper-2).
   - **D4**: `phylo_unique()` stays canonical (don't convert examples to phylo_indep).
   - **D5**: pedagogical articles (covariance-correlation, pitfalls, morphometrics,
     fit-diagnostics) need `residual=FALSE` rewrites + reframing, not swaps.
   Once D0–D5 are settled: core change → safe-mechanical cascade → article rewrites
   → regenerate man/ → verify (Gaussian recovery, wide/long byte-identity, RE-12,
   pkgdown) → Boole/Noether/Rose/Pat sign-off.
2. **New Julia families #104–#110** — GenPoisson (in flight) → Student-t (#105) →
   truncated/lognormal/anova/diagnostics/structured-speed. Each: 14-slot family
   contract + FD-gradient + Poisson/Gaussian-limit + ADEMP recovery; held for sign-off.
3. **Bridge-expose new families + JUL-01/JUL-01A parity campaign** (R↔Julia) — wire
   new families into the R bridge family map + per-family ADEMP gates; systematic
   native-vs-Julia parity deltas → JUL promotion evidence (held). See the
   coordination note + GLLVM.jl #65.
4. **`cluster2` — 4th random-effect grouping slot** (R engine) — standing maintainer
   requirement: implement AND validate across ALL distributions (mirror the
   `cluster`-tier pattern: parser + TMB + `test-tiers-*`/`test-cluster-rename`).
5. **CI-08/CI-10 coverage diagnostics** (R) — power-pilot release-gate undercoverage
   + mixed-family calibration (M3.3 production gate). Investigate before any promotion.
Honorable mentions: model-based missing-data FIML layer (standing design,
`~/.claude/memory/design-missing-data-drmtmb-gllvmtmb.md`); structured-term bridge
routing (biggest bridge gap, phase-scale); document #494's coevolution extractors
(extract_Gamma/predict_cross_covariance/profile_cross_rho/make_cross_kernel) in
`docs/design/06-extractors-contract.md` §8 (the salvaged 2 are already there).

## Working style that fit this work
- Offload heavy builds to ultracode **Workflows** (keeps orchestrator context light);
  review the returned summary + verification, then push/PR (held).
- GLLVM.jl CI is slow (`cancel-in-progress`, ~45–80 min/run, queue-stalls held-PR
  jobs); rely on local full-suite green (`julia --project=. test/runtests.jl`) +
  explicit approval to merge engine PRs.
- Surface PR links + after-task paths + 🔴 Needs-you items at every stopping point.

## Worktrees (scratch; prune when settled)
`/private/tmp/gllvmjl-main` (GLLVM.jl main), `/private/tmp/gllvmjl-genpoisson`
(#104 in flight), `/private/tmp/gllvmtmb-main` (gllvmTMB multi-branch scratch).
Merged-branch worktrees already pruned. Many pre-existing HELD-branch worktrees
remain (see `git worktree list`) — leave until their dispositions land.

## One-line next action
"Check the GenPoisson worktree `/private/tmp/gllvmjl-genpoisson` + Workflow result;
push+held-PR if verified. Then either drive item-1 Psi once the maintainer settles
D0–D5, or continue the Julia family backlog (Student-t #105). Keep the widget truthful."
