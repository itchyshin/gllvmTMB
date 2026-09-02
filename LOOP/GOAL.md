# GOAL — gllvmTMB gap-closure overnight lane (IMMUTABLE — re-read at the top of EVERY arc)
Read this first, every cycle. Auto-compact eats messages, not this file. Unsure after a compaction?
Re-read THIS, then checkpoint.md, then continue.

## Mission
Run the approved gap-closure programme to its next finish line, autonomously, until ~05:00 on
2026-09-03 (Shinichi: "run autonomously till then"; approvals recorded as vault D-207 and D-210). In order:
(0) merge PR #1240 (zero-inflated families — APPROVED on four points) once its local suite/check and CI
are green, then bring `main` into this lane; (1) the bare-abort remainder (#1247) in batches of ~150
aborts per PR, messages + tests only, ratchet test enforced — LOW-RISK, auto-merge on green CI;
(2) zi multi-seed recovery evidence for FAM-21..23 — Totoro pre-run (≤30 min, ≤100 cores, 1 thread per
fit) then a DRAC SLURM job array on `def-snakagaw_cpu` (nibi or trillium), `--time` sized from the
measured pre-run, ≤200 core-hours total; outputs on `/project`, checksums + compact summaries into Git;
compare with GLLVM.jl's ADEMP campaign; register rows may move from `partial` only on that evidence and
only with a Rose-checked wording; (3) port #1241 `ordinal_logit()` (name approved) and #1242 `select_lv()` +
`anova.gllvmTMB` with chi-bar-square boundary p-values — each on its own branch, Design Rule 1 (alignment
table first, recovery tests, register row, NEWS boundary), fresh Opus adversarial review, DRAFT PR only;
(4) if time remains, #1243 `ordination_uncertainty()` and #1244 the `censored_poisson()` engine, same rules.

## Headline
Every user-visible refusal names a route that fits, and the R twin carries the user-facing capabilities
the Julia twin added first — with evidence, not claims (D-204 both-ways parity; usability does not bend, D-139).

## Invariants
- ONE lane: this worktree, branch `claude/lane-gapclose-overnight-20260902`; sub-arc branches
  `claude/overnight-<arc>` from `origin/main`. Never edit PR #1236's files (`R/julia-bridge.R`,
  `tests/testthat/test-julia-bridge.R`, `docs/dev-log/julia-bridge/**`), Cursor MSPL lanes, or the Codex
  iJSDM/random-slope lanes (D-88). Run `~/shinichi-brain/tools/lane_preflight.sh` before each new arc.
- Merge rule (D-210): auto-merge LOW-RISK PRs only (docs, tests, message text) after green CI, by merge
  commit; every API / family / S3-method change opens as a DRAFT PR carrying its review verdict and WAITS.
  Never `gh release`, never tag, never a public claim, never NEWS "covered".
- Verify by LOG and ARTIFACT, never exit code: after any R/ or src/ change run
  `devtools::test(filter=)` on touched files (use devtools, NOT testthat::test_file — the installed
  package lacks new families and silently skips); full suite + `devtools::check(args="--no-manual")` once
  per PR before opening it; read the counts, not "DONE".
- Compute (D-139/D-143/D-50): estimate before any run > 30 min; Totoro ≤100 cores with
  `OMP_NUM_THREADS=1`; DRAC ≤200 core-hours total; never on GitHub Actions; never a fresh DRAC login
  (use the `cm-` ControlMaster sockets; if absent, PAUSE — do not trigger Duo).
- CI cadence: batch fixes, push once per PR round (one-fix-per-push caused a 5-run cancel cascade).
- GitHub API budget is shared across four lanes: on "rate limit exceeded", use the REST endpoints via
  `gh api` (they worked when GraphQL was throttled) or wait for the reset; never loop-poll.
- Every arc closes with: after-task report (11 sections), check-log entry, board line, checkpoint commit.
- Machine hygiene: if load > 60, look for another lane's runaway processes before blaming a test; never
  kill another lane's processes without an owner's word (the DRM.jl hook loop needed Shinichi's say-so).

## Authoritative WHAT
-> LOOP/ultra-plan.md (the approved plan with its execution log; detail wins there). This file wins on
"what must never be lost". Vault decisions: D-204 (both-ways parity), D-207 (zi approvals), D-210 (this run).

## Definition of done
By 05:00: #1240 merged; #1247 reduced to ≤ 300 bare aborts package-wide with the ratchet updated and every
batch PR merged; zi multi-seed evidence on `/project` with a compact summary committed and FAM-21..23 rows
reworded on evidence (or the honest reason why not); draft PRs open for #1241 and #1242 with green local
suite/check, review verdicts and after-task reports; a morning brief at `docs/dev-log/2026-09-03-morning-brief.md`
listing every draft PR with its sign-off points, plus `LOOP/checkpoint.md` current.

## Pre-authorisation (D-210 + the plan's envelope)
Scoped edits in this worktree and its sub-arc branches; devtools document/test/check; article renders;
local commits; `git push` of `claude/overnight-*` branches; opening DRAFT PRs; `gh pr merge --merge` of
LOW-RISK PRs on green CI; the Totoro pre-run and the DRAC array within the caps above; filing issues that
the plan already drafted.

## Must stop for
Merging any API/family/method PR; `gh release`/tags; NEWS "covered" or any public capability claim;
credentials or security changes; destructive work outside this worktree; compute beyond the caps; a DRAC
login without a live socket; evidence that reopens a frozen decision (D-157 MSPL park, D-181 intervals,
Design 62 zero-part scope, the four D-207 points).
