# Recovery checkpoint — Claude/Ada autonomous run (2026-06-20 ~12:31 MDT)

Supersedes the 11:09 checkpoint. **Repo authoritative.** Goal: work autonomously
till 2pm; widget truthful; bridge R↔Julia; "merge and keep going" + the next-5.

## Heads
- gllvmTMB `origin/main` = **bc7118f** (9+ PRs merged this session; 0 open).
- GLLVM.jl `origin/main` = **da135f1** (#101/#102/#103/#111 merged; #94 closed).
- Dashboard live **r55** at http://127.0.0.1:8770/ (metrics unchanged covered 2 / partial 9).

## Merged this session (engine on approval)
- gllvmTMB: #498, #499, #500 (coevolution salvage, full DoD), #501 (R↔Julia coord),
  #502 (Psi exec plan), #503 (Psi cascade spec).
- GLLVM.jl: #102 (J1 docstrings), #103 (masked Poisson/Binomial analytic),
  #111 (masked NB/Gamma/Beta analytic) → masked analytic complete across all 5
  non-Gaussian families. #94 closed → successor issues #104–#110.

## Next-5 status
1. **unique→Psi grammar** — de-risked + decision-mapped on main (specs #502+#503).
   Execution gated on **D0–D5**: D0 core residual=TRUE change + cascade move
   together; D1 *_latent parity; D2 augmented slope-block Psi (RE-12); D3
   kernel_unique stays compat (C1); D4 phylo_unique canonical; D5 pedagogical
   articles (covariance-correlation/pitfalls/morphometrics/fit-diagnostics) need
   residual=FALSE rewrites. ~445 usages. Needs maintainer + Boole/Noether.
2. **New Julia families** — **GenPoisson #104 IN PROGRESS** via Workflow
   `wf_92e39ee3-d70` (plan→implement→verify on branch claude/genpoisson-104-20260620,
   worktree /private/tmp/gllvmjl-genpoisson; NOT pushed — held for review+sign-off).
   Then Student-t #105, etc.
3. **Bridge-expose + JUL-01 parity** — queued (coordination note #501 + GLLVM.jl #65).
4. **cluster2 4th grouping slot** — queued (standing requirement; engine+parser+validation).
5. **CI-08/CI-10 coverage** — queued (power-pilot release-gate undercoverage).

## When picking up
1. GenPoisson Workflow result: review diff + verification; if clean, push branch +
   open PR (held for sign-off); if partial/blocked, surface honestly.
2. Item-1 execution is blocked on D0–D5 maintainer/engine decisions.
3. Items 2–5 are fresh-context heavy execution; offload via Workflows where fan-out.
4. Dashboard hygiene: version.txt + index.html BUILD paired, rsync to
   /tmp/gllvm-dashboard, curl :8770.

## CI note
GLLVM.jl `CI.yml` cancel-in-progress + slow matrix (~45–80 min/run); held-PR jobs
queue behind main runs. Engine PRs merged on explicit approval + local-green
(full suites) when CI queue-stalled.
