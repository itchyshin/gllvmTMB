# Codex kickoff message — `latent_*`-only migration — 2026-06-21

> Short kickoff message handed to the Codex team to open the session. The
> **full** handover is `docs/dev-log/codex-handover-2026-06-21-latent-migration.md`;
> this is the one-screen version.

**To: the Codex team (gllvmTMB) · From: Claude (Ada) · 2026-06-21**

You're taking over the **`latent_*`-only migration**. The repo is authoritative —
rehydrate from git/gh, not chat memory.

**Read first, in order:**
1. `AGENTS.md` (+ `CLAUDE.md`) — project rules.
2. `docs/dev-log/codex-handover-2026-06-21-latent-migration.md` — **the full
   handover** (project context, canonical Ψ model, hard guards, the per-slice fold
   **recipe** in §5, the Stage A–E plan, role map, verification protocol).
3. `~/.claude/plans/memoized-snuggling-balloon.md` — the staged plan.
4. `docs/design/2026-06-21-source-specific-latent-psi-fold.md` — Stage-A design (read
   as the algorithm; emit `unique=`/`.auto_unique`, not the old `residual=`).

**State:** `origin/main = 53e2cb4`. Merged today: **#518** (`latent(residual=)` →
`latent(unique=)`), **#519** (`phylo_latent()` folds Ψ_phy by default). **#516
closed** (superseded). Ordinary `latent()` and `phylo_latent()` now carry their
diagonal Ψ by default (`unique=TRUE`); `unique=FALSE` = loadings-only.

**Your mandate:** carry Stage A forward — **`spatial_latent` (next) → `animal_latent`
→ `kernel_latent` → augmented `phylo_latent(1+x|sp)`**, then Stage B hardening
(per-family recovery gates + the deferred docs: bare-`*_latent` fire-on-use warning,
AGENTS/CLAUDE grid note, validation-debt register row), then C/D/E. Each source fold
= the same §5 recipe: rewriter (`R/brms-sugar.R`) + dedup (`R/fit-multi.R`) +
equivalence-cascade fix + G1–G4 gates.

**First actions:**
1. `git fetch`; confirm `main`; `gh pr list`. Prune the merged `/private/tmp/gllvmtmb-*`
   worktrees.
2. Start **`spatial_latent`** — but **first confirm the SPDE diagonal engine slot is
   wired** (`grep spde|spatial_unique|use_spde*` in `R/fit-multi.R` +
   `src/gllvmTMB.cpp`); if it isn't, raise it with the maintainer before coding.
3. Work on a fresh worktree off `origin/main`; RED-first tests; run G1–G4 for real
   under `GLLVMTMB_HEAVY_TESTS=1`.

**Hard guards:**
- ★ **Run the FULL `devtools::check()` before every push** — #516 went red because a
  phylo-only test run passed while equivalence tests in *other* files failed. A
  scoped run lies.
- Grammar/engine/family changes need **explicit maintainer "yes merge"** — do not
  self-merge. Docs are self-mergeable when CI is green.
- **Never `git add -A`** (stage by name). Don't revert Claude/human work. Don't touch
  the dirty `codex/r-bridge-grouped-dispersion` checkout.
- Env caveat: local `devtools::check()` shows 1 ERROR (`glmmTMB::equalto` missing —
  glmmTMB built vs TMB 1.9.17, env has 1.9.21; reinstall glmmTMB from source) + 1
  clang header WARNING. **Both are env-only, not branch** — absent on Linux CI.
- Leave an after-task report + check-log entry per
  `docs/design/10-after-task-protocol.md`; assign the §7 review roles
  (Boole/Gauss/Noether/Curie/Grace/Rose).

This is your lane — Codex runs the live R/TMB + Julia toolchain (real fits, full
`R CMD check`, heavy recovery suites). Go.
