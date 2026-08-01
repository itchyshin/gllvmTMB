# Claude → next session — #851 start-value lane CLOSED, rejoining `main`

**2026-07-31 · Claude (Fable 5) · everything merged · no branch carried over**

## Copy-paste opener

```
🎯 The #851 start-value lane is CLOSED. Three PRs merged (#873, #878, #879);
   nothing is carried over and no worktree needs resuming.
READ FIRST: the CORRECTION below — "main is not green (18 fail / 3 err)" was
   MY HARNESS, not the repo. main's true baseline is 3 fail / 0 err.
STATE: main is green on all three OSes. The repo's only Windows failure is fixed.
NEXT: nothing is owed by this lane. Pick work from the main lane.
```

## What landed

| PR | what | evidence |
|---|---|---|
| **#873** | #851 scale-aware start, scoped to where it was measured | suite matched `main` file-for-file; equivariance oracle + cross-package comparator unchanged |
| **#878** | the `res` start returned two scales in one Λ | ratios `10000, 1, 10000, 10000` → all `10000`; guard verified to fail on unfixed code |
| **#879** | `.gitattributes` pins the frozen fixture's bytes | **3-OS green — Windows, macOS, ubuntu all success** |

`main` is at `9cd7aa1f` and is **green on all three platforms**. The Windows failure that
had been red on every branch is gone.

## 🔴 CORRECTION — read before trusting anything I wrote earlier today

**`main` was green the whole time. The "18 failures / 3 errors" I reported repeatedly was
my Totoro harness.** True baseline, same 348 files: **3 fail / 0 err**, PASS 14534.

Two causes, both mine:

1. `test-m3-pilot-manifest.R` (16 fail + 2 err) shells out with `Rscript --vanilla`, which
   implies `--no-environ`. Totoro sets `R_LIBS_USER=~/R/lib` in `~/.Renviron`, so the child
   process could not see the installed package. Every CLI test failed with *"there is no
   package called 'gllvmTMB'"* — invisible in a runner that records only counts.
2. `test-tweedie-fixed-p.R` (1 err) — `tweedie` was not installed on Totoro.

Both fixed: `~/gllvm_work/fullsuite.R` and `fullsuite-main.R` now prepend `~/R/lib` and
export `R_LIBS`, **and must be launched WITHOUT `--vanilla`** (my first repair set `R_LIBS`
from inside a `--vanilla` runner, captured the already-wrong path set, changed nothing, and
looked like the diagnosis was wrong). `tweedie` is installed.

The wrong figure is in the #851 after-task report, two merged PR bodies and a spawned task
brief. `check-log.md` carries the full account under *"CORRECTION: `main` was green all
along"*.

## Do NOT redo

- **Do not re-litigate the #851 tier scoping.** The scale is passed only at `theta_rr_B`,
  deliberately. The five other tiers keeping `0.5` is a decision (Shinichi's, on evidence),
  not an oversight; NEWS states the limitation.
- **Do not remove the SVD score seeding.** Load-bearing at scale — removing it degrades
  k = 5000 badly (Λ 0.0171 → 0.0749, Σ 0.0204 → 0.117), flipping three laws to VIOLATED.
  The `lv` gate is the narrow, measured version.
- **Do not "fix" `test-eva-gate1.R`.** The fixture's committed bytes were always correct;
  only their on-disk representation on Windows was at issue, and `.gitattributes` fixes it
  at the right layer. Hashing parsed content would have left `R/eva-proto.R`'s provenance
  stamp silently platform-dependent.
- **Do not pin only `inst/extdata`.** `.eva_gate1_file()` resolves the `docs/design/` copy
  first. I made exactly this mistake and burned a 3-OS run on it.

## Open, and owned by nobody

1. **`test-profile-derived-curves.R` (2 failures)** on `main`. Real, undiagnosed. Present
   on Totoro; not investigated.
2. **`test-funcphylo-spatial-recovery.R` (1 failure)** — appeared on Totoro *and* once on
   ubuntu CI, while `main`'s own ubuntu run was green. **Flakiness candidate**, not
   confirmed either way. Worth a few repeat runs before anyone treats it as a defect.
3. **A cross-lane note to the AGHQ lane** sits in `check-log.md`: #851 moved the
   start-dependent objective their `test-aghq-multistart-convergence.R:103` pins. Measured
   both trees — the #851 start reaches a *less* severe runaway (‖Λ̂‖/‖Λ‖ 22.57 vs 29.70) at a
   0.83-higher objective, in a region their own file records as non-MLE. Their test, their
   call; three options are laid out for them. **It is not currently failing on `main`**,
   because #873 merged after their test landed and the suite is green — but the note stands
   if they revisit that pin.
4. **Full `--as-cran`** was never re-established on any of these branches (only a restricted
   `--no-tests --no-vignettes` run). 3-OS CI green covers the same ground more credibly, but
   it is not the same check.

## Method notes worth keeping

- **Two green platforms against one red one is a statement about the third environment.**
  I had `main`'s ubuntu CI green and the Mac green, and still spent most of a session
  attributing a Totoro-only failure to the repo.
- **An adversarial panel earned its cost twice today.** It defeated my own refutation of
  Rose's F1 finding (3/3), locating a live path that both her report *and* my rebuttal had
  missed — the hardcoded `0.5` surviving a partial SVD overwrite. And Rose's audit itself
  caught a NEWS overclaim of ~3 orders of magnitude before it shipped.
- **Verify which file the code actually reads, not which file you assume it reads.** Both
  the `.gitattributes` miss and the F1 mis-diagnosis were the same error in different
  clothes: a correct mechanism attached to the wrong object.
- **Totoro:** `~/gllvm_work` holds `gllvmTMB-main` and `gllvmTMB-851` trees plus the fixed
  runners. `src/` is excluded from rsync and the compiled `.so` is reused, so a suite run is
  ~15 min with no rebuild — but re-verify the deployed tree is the state you think it is
  (a stale tree with reverted code cost me a wrong baseline early on).
