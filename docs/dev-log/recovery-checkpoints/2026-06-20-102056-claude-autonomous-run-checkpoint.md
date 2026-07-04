# Recovery checkpoint — Claude/Ada autonomous run (2026-06-20 ~10:21 MDT)

**The repository is authoritative.** This run took over from
`2026-06-20-handover-post-101-landing.md` and executed the autonomous DO-NEXT
items + a HELD-item audit. Maintainer present; goal = "turn the many parts of the
plan into action; keep the widget truthful; work autonomously until context fills."

## Repo state at checkpoint
- gllvmTMB `origin/main` = **f4da6c1** (8 PRs merged this session; **0 open
  gllvmTMB PRs**).
- GLLVM.jl `origin/main` = **186af2d** (#101 merged). **Open GLLVM.jl PRs, both
  HELD for sign-off:** #102 (J1 docstring truth-fix, doc-only), #103 (masked
  analytic gradient, engine default-path change). #94 still DRAFT/held.
- Working checkout still on the dirty `codex/r-bridge-grouped-dispersion`
  (untouched except the dashboard refresh + this checkpoint, both untracked).

## What landed / shipped this run
1. **Bridge re-verify** vs GLLVM.jl main #101: live `julia-bridge` **PASS 1228 /
   FAIL 0 / WARN 0 / SKIP 0**. → after-task + check-log → **PR #498 MERGED**.
2. **J1 (analytic Laplace gradients):** confirmed ALREADY done+default+gated on
   GLLVM.jl main (`test_laplace_grad.jl` 26/26). Only stale "not yet wired"
   docstrings remained → fixed → **GLLVM.jl PR #102 (HELD)** + J1 after-task.
3. **HELD-item audit** (4-agent read-only Workflow `wf_d37991cd-a1e`): risk-tiered
   recommendations → memo → **PR #499 MERGED**
   (`docs/dev-log/2026-06-20-held-item-reconciliation-audit.md`).
4. **Masked-analytic J1 follow-on (BUILT + verified):** masked Poisson/Binomial
   fits now use the analytic gradient by default. `test_laplace_grad.jl` 32/32
   (new masked gate 6/6), `test_missing_response.jl` 23/23 (masked analytic-vs-FD
   ~1e-8), `test_poisson_fit.jl` 12/12. → **GLLVM.jl PR #103 (HELD)** + after-task.
5. **Mission-control dashboard** kept truthful → live at **r46** on
   http://127.0.0.1:8770/ (source on the dirty branch; served `/tmp/gllvm-dashboard`
   via rsync). Metrics UNCHANGED (covered 2 / partial 9) — no register promotion.
6. Worktree admin pruned (3 stale entries).

## HELD for maintainer (audit recommendations; nothing forced)
1. **Merge GLLVM.jl PR #102 (doc-only) + #103 (engine masked-analytic).**
2. **Item-1 salvage** (dirty branch): the only net-new gllvmTMB code is two
   UNCOMMITTED exports — `extract_coevolution_modules` (R/extract-sigma.R:1574) +
   `diagnose_kernel_separability` (R/kernel-helpers.R:311). REFINED FINDING: they
   are a **helper cluster**, not a clean 2-function port — `extract_coevolution_modules`
   also needs `.coevolution_axis_table` + `.matrix_inv_sqrt` (both dirty-tree-only;
   missing from main); `diagnose_kernel_separability` needs the 5
   `.kernel_separability_*` helpers (+ check `.kernel_pair_similarity`). Two new
   public exports → **needs API sign-off** before a salvage PR.
3. **GLLVM.jl #94:** conflicting/superseded; file the 8 already-drafted successor
   issues (`docs/dev-log/2026-06-15-pr94-successor-issue-drafts.md`; GenPoisson +
   Student-t first), then close #94 as superseded. (Outward-facing → needs go.)
4. **GLLVM.jl divergent branch + J2:** J2 → abandon (superseded by #101).
   Divergent (`codex/non-gaussian-fitter-gradients`, PR #60 closed) → keep/drop
   the structured-Schur/Poisson **speed substrate** (the only unique value).
5. **unique→Psi cascade:** real **high-risk grammar** change (soft-deprecation
   compliant, no removal over-claim) → grammar sign-off or defer.

## Next autonomous build available (not started)
- NB/Gamma/Beta masked analytic gradient (mirror PR #103): requires adding a
  `mask` arg to `nb_/gamma_/beta_laplace_grad` + their site functions (observed-
  weight subtleties), then a masked gate. Heavier; flagged, not built.

## Worktrees (scratch this run; safe to prune when done)
`/private/tmp/gllvmjl-main` (186af2d detached), `/private/tmp/gllvmjl-j1`
(PR #102), `/private/tmp/gllvmjl-masked` (PR #103), `/private/tmp/gllvmtmb-main`
(memo branch). Plus the many pre-existing HELD-branch worktrees (keep until the
audit decisions land).

## Verified toolchain
Julia 1.10 at `~/.juliaup/bin/julia`; `GLLVM_JL_PATH` → a GLLVM.jl main worktree
for live R bridge tests. Hard guard held all run: no register/coverage/release
promotion; no high-risk/engine merge without sign-off (#102/#103 HELD).
