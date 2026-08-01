# Claude → Claude handover — 2026-07-31, the VA-in-0.6 lane

**You are Claude, picking up the variational-engine lane.** Branch
`claude/va-in-06-20260730`, pushed. **A campaign is running right now** — read §"Critical context"
before you touch the worktree.

**Multi-lane repo.** This is one lane. The board is
`docs/dev-log/handover/2026-07-25-active-lane-split.md`; other lanes' handovers are listed there and
are **not** superseded by this file. Deferred items from other lanes stay theirs.

---

## Critical context — three things that will bite you first

1. **🔴 DO NOT delete, `git clean`, or recreate the worktree `/private/tmp/gllvmtmb-va-in-06`.**
   The Gate 3 campaign is writing per-cell output there and its resume path depends on those files.
   Progress: `ls dev/va-gate3/results/cells/ | wc -l` against **2,160**.
2. **🔴 The campaign LOOKS dead and is not.** `run-gate3.R` processes sit at **0.0% CPU, state
   `SN`** by design — they sleep while their persistent `callr` sessions compute. I misread this and
   **killed a healthy run**. Correct check (counts *all* R processes):
   `ps -eo %cpu,command | grep "[R]esources/bin/exec/R" | awk '{s+=$1;n++} END {print n, s}'` —
   healthy is ~30 processes at 1300–1500% total. Full note:
   `dev/va-gate3/results/LIVENESS-NOTE.md`.
3. **The goal block in the session that wrote this is STALE.** Three clauses were superseded by
   maintainer decisions on 2026-07-31. The operative spec is
   `docs/dev-log/2026-07-31-gate0-scope-extension-and-s11-departure.md`.

## Goals / mission

`gllvmTMB` 0.6 is the package's first CRAN release. Maintainer position, settled 2026-07-31:
**Laplace is the default, AGHQ for accuracy, VA and EVA are OPT-IN.** An opt-in route need not beat
Laplace — it must work correctly and be honestly fenced. That is why Gate 3's rule is *"no more than
0.05 worse than ML"* rather than *"better than ML"*.

## What was accomplished

- **The 0.6 reversal recorded and swept.** VA ships in 0.6 (reversing the 2026-07-21 cut), with
  every *live* surface updated — `LOOP/GOAL.md` (Amendment 4 + top banner), `checkpoint.md`,
  `arcs.md`, `ultra-plan.md`, `decision-queue.md`, Design 104 §4.1, Design 108 §7, and a banner on
  the 2026-07-21 record. Historical dev-log entries left as dated records.
- **Gates 0, 1, 2 established by measurement** — 352 + 1,469 tests, `NOT_CRAN=true`.
- **Gate 3 pre-registered, frozen, and RUNNING** — 2,160 cells / 6,480 fits, both VA arms, so it
  settles admission *and* the GH-vs-JJ estimator question in one pass.
- **The separation guard landed** — `main` had accepted Bernoulli VA fits with no separation check
  since PR #797; the guard written to protect that relaxation had never been merged.
- **`gllvmTMBcontrol(integration=)` built**, fenced, documented, tested — and honest: it aborts
  explicitly rather than silently returning a Laplace fit.
- **EVA settled.** Ours is provably the same algebra as gllvm's; its degeneracy is genuine, not our
  bug.
- **The "~90 unmerged commits" alarm dissolved** — one real item, the rest squash-merge artefacts.

## Current working state

| | |
|---|---|
| **branch** | `claude/va-in-06-20260730`, pushed, working tree clean |
| **campaign** | **RUNNING**, ~92/2,160 cells, 14 workers, resumable, LOCAL (D-50) |
| **Gates 0/1/2** | PASS |
| **Gate 3** | in progress — needs ~12 h to 2 days |
| **`integration=`** | control + fence + docs + tests built; **NOT routed** |
| **estimator** | OPEN — Gate 3 decides |

## Key decisions & rationale

- **`q ≤ 2` → `q ≤ 4`, earned not asserted.** Gate 3 is defined at `q = 1/2`; the q=4 advance is what
  the 2026-07-20 audit refused. It ships **only if the q=4 cells pass on their own terms**.
- **Bernoulli admitted** by a fresh Gate 0 scope freeze — defensible only because the separation
  guard landed first. A3 names binary JSDM as VA's purpose.
- **A recorded §11 departure**: the `RMSE_ml` rule is chosen after both variants are seen. Bounded by
  pre-declaring **exactly two** admissible rules, R1 (raw) and R2 (paired exclusion), no third.
- **`default_tier` NOT changed.** Rose returned REJECT on GH-over-JJ; the two-sided detector then
  found JJ's hidden contraction failures. Neither arm is clean.

## Files created / modified

Full diff: `git diff --name-only origin/main...claude/va-in-06-20260730` (≈84 paths).
The load-bearing ones:

- `R/integration-fence.R` (new) · `R/gllvmTMB.R` · `R/va-r3-proto.R` (separation guard)
- `tests/testthat/test-integration-fence.R` (new) · `test-va-r3-separation.R` (new)
- `dev/va-gate3/{run-gate3.R, analyse-gate3.R, truths.rds, two-sided-detector.R}`
- `docs/dev-log/2026-07-31-gate0-scope-extension-and-s11-departure.md` ← **operative spec**
- `docs/dev-log/2026-07-30-gate3-preregistration.md` ← the frozen design
- `docs/dev-log/2026-07-31-integration-routing-brief.md` ← **your first job**
- `docs/dev-log/handover/2026-07-31-claude-handover-va-lane-close.md` ← long-form detail
- `.gitignore`, `LOOP/*`, `docs/design/104|108`, `docs/dev-log/decisions.md`

## Next immediate steps

1. **Route `integration=`.** `docs/dev-log/2026-07-31-integration-routing-brief.md` pins the
   insertion point to `fit-multi.R` **line 2256** — every engine input already exists there in the
   right form. The real work is the *return object*; use a distinct
   `c("gllvmTMB_va","gllvmTMB")` class so unsupported methods fail loudly.
2. **Call the fence a second time after parsing.** Today only `engine` is checkable at the abort
   point, so `q`/`p`/`n`/family/link are implemented and tested but **not yet reachable**.
3. **When the campaign finishes**: `Rscript dev/va-gate3/analyse-gate3.R`, which emits **both** pass
   rules. Then commit the durable artefacts only (combined `gate3.rds`/`.csv`, both verdict CSVs) —
   the per-cell files are `.gitignore`d deliberately.

## Blockers / open questions — for the maintainer

1. **Estimator**: GH or JJ. Gate 3 decides; do not pre-empt it.
2. **`RMSE_ml` rule**: R1 or R2, once both are visible. R2 removed all 12 vacuous-pass cells on
   partial data.
3. Whether **`"eva"`** stays a fenced value making no claim.
4. Long-open, unrelated: `test-start-method-residual.R:156` fails the nightly under
   `GLLVMTMB_HEAVY_TESTS=1` — maintainer's call, 2026-07-27, never resolved.

## Gotchas / failed approaches — do not repeat

- **`NOT_CRAN=true` or Gate 1 silently skips.** The file reports "183 passed, 8 skipped" and looks
  clean; those 8 skips *are* Gate 1.
- **Never filter on `status`/`admitted`.** The `max_projected_variance <= 4` guard rejects GH 14.5%
  and JJ **0.0%**; a filter manufactures the result the campaign exists to test. At `n_starts = 1`,
  `admitted` can never be `TRUE`.
- **gllvm's top-level `link=` is a silent no-op** for binomial — use `family = binomial(link=)`.
- **EVA: more restarts make it WORSE.** Its own objective scores the runaway **291 nats above the
  truth**; gllvm picks the best-objective restart, so `n.init=5` found 3.8e8 where the default was
  1.16. Use `is.list(fit$sd)` as the degeneracy guard (6/6 correct); `convergence` is useless.
- **Do not add a `q` to the truths loop** — nested `truth × q × p` order means inserting one shifts
  the RNG stream and rewrites frozen truths. Append under a separate seed; the code asserts this.
- **Recompute before citing, and check the gradient any pooled summary pools over.** Ten claims were
  withdrawn this arc; the estimator inversion hid under a median pooled over `p`.

## How to resume

```bash
cd "/Users/z3437171/Dropbox/Github Local/gllvmTMB" && git fetch && \
  git worktree list | grep -q va-in-06 || \
  git worktree add /private/tmp/gllvmtmb-va-next claude/va-in-06-20260730
```

Then, in your own terminal:

```
claude "Rehydrate from docs/dev-log/handover/2026-07-31-claude-handover.md and the CLAUDE.md lane split, then continue with the Next Immediate Steps: route integration= per the routing brief. Do NOT delete /private/tmp/gllvmtmb-va-in-06 — a campaign is running there."
```

Read, in order: this file → `2026-07-31-gate0-scope-extension-and-s11-departure.md` →
`2026-07-30-gate3-preregistration.md` → `2026-07-31-integration-routing-brief.md`. Spawn **Rose**
before any public claim.
