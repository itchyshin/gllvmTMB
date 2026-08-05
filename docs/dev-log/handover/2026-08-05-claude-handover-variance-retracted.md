# Handover — gllvmTMB VA lane, 2026-08-05: variance finding retracted, large-N not established

**Author:** Claude Code, Rose role (closer) → **Target:** fresh Claude / Codex / Cursor session,
no chat inherited
**Branch:** `claude/va-lane2` @ `728f4aa8` (`728f4aa82b387b2b93e27009a484f40e28a3d582`) —
**UNCOMMITTED work on top, not pushed**
**Worktree:** `/private/tmp/gllvmtmb-va-lane2`

> The committed repo plus the uncommitted files listed below are the authoritative state. This
> file supersedes chat. Read `dev/va-speed/78-VARIANCE-RETRACTION-AND-LARGE-N.md` for the full
> technical detail — this handover summarises and gives the next steps.

## FIRST: rehydrate and classify

```sh
bash ~/shinichi-brain/tools/lane_preflight.sh /private/tmp/gllvmtmb-va-lane2
cd /private/tmp/gllvmtmb-va-lane2 && ./tools/check-push-traps.sh && git log --oneline -10 && git status --porcelain=v1
```

Classify every item below as OWED / DONE / RETRACTED / PROTECTED against actual repo state before
acting. Do not trust this document over the repository.

## Landing State — UNCOMMITTED, every new/modified file listed

Nothing in this arc was committed. `git status --porcelain=v1` at handover time:

| status | file | origin |
|---|---|---|
| **M** | `dev/va-speed/20-CLAIMS-LEDGER.md` | this closure task — claim 30 amended, rows 47/48 added |
| **M** | `docs/dev-log/check-log.md` | this closure task — dated entry appended |
| ?? | `docs/dev-log/after-task/2026-08-05-va-variance-retraction.md` | this closure task — new |
| ?? | `docs/dev-log/handover/2026-08-05-claude-handover-variance-retracted.md` | this closure task — new (this file) |
| ?? | `dev/va-speed/73-SPLIT-RESULT.md`, `73-split-instrumented.R`, `73-split-instrumented.rds`, `73-run.log` | producer agent (Curie role), pre-existing at task start |
| ?? | `dev/va-speed/74-spec-discriminator.R`, `74-spec-discriminator.rds`, `74-run.log` | producer agent (Curie role), pre-existing at task start |
| ?? | `dev/va-speed/75-CLEAN-LADDER-RESULT.md`, `75-ladder-results.rds` | producer agent (Fisher role), pre-existing at task start |
| ?? | `dev/va-speed/76-gllvm-eval-counts.md` | producer agent, pre-existing at task start |
| ?? | `dev/va-speed/77-ADVERSARIAL-REVIEW.md` | adversarial reviewer, pre-existing at task start |
| ?? | `dev/va-speed/78-VARIANCE-RETRACTION-AND-LARGE-N.md` | orchestrator (Ada role) consolidation, pre-existing at task start |
| ?? | `dev/va-speed/trace-gllvm-va.R`, `dev/va-speed/inventory-analysis.txt` | producer agents, pre-existing at task start |
| ?? | `docs/dev-log/plan-actual/2026-08-05-va-variance.md` | plan-vs-actual reconciliation, pre-existing at task start |

**`R/`, `src/`, `tests/` — zero changes.** The engine was measured, not modified. The package's
existing 371-file / 9,286-test baseline (last confirmed 2026-08-04) is untouched and does not need
re-running because nothing in its surface moved.

**PROTECTED, do not touch:** `/Users/z3437171/Dropbox/Github Local/gllvmTMB` — different branch,
stale by design; this worktree is the only place to work. `origin/main` — untouched throughout;
merging is the maintainer's act.

**Committing this state is a maintainer/next-session decision, not made here** — per this task's
own instructions, no `git add`/`commit`/`push` was run.

## What this session established

Two claims went in; both came out worse than they went in, and for the same reason each time:
**work timed on one side of a comparison and not the other.**

1. **The "1-in-8 catastrophic seed" / "the gap is VARIANCE" finding is RETRACTED.** It was a TMB
   recompile inside the timed block — `.va_r3_load_dll()` builds into `tempdir()`
   (`R/va-r3-proto.R:909`), which is per-R-session, so a fresh `Rscript` recompiles on its first
   `.va_r3_fit()` call. Measured: cold compile **24.77 s**, warm **0.23 s**; the original
   "catastrophic seed"'s excess over its own median was **24.76–24.84 s** (two independent
   readings) — matching the compile cost to within 0.01–0.24 s. An 8-seed re-run with an untimed
   warm-up and randomised run order lands every seed in a 1.10–1.12× band; load-independent trace
   counts are flat across every seed. **There is no outlier to explain.** Separately, the original
   8-seed table has no surviving artefact — the committed script is `SEEDS <- 1:3` and the artefact
   it wrote has 3 rows disagreeing with every seed-1 figure in the write-up.
2. **The large-N "we beat gllvm" result is NOT ESTABLISHED.** A 72-cell, 24-seed, model-matched
   ladder (N ∈ {250,1000,2500}, T=20, q=2, binomial-probit, no ψ) reported 1.03×/2.55×/3.68×
   medians in our favour. Adversarial re-measurement found gllvm was timed with its **default
   `sd.errors=TRUE`** (an `optimHess()` SE pass our arm never computes — `R/va-r3-proto.R` has
   zero `sdreport`/`optimHess` calls) — **60–63% of gllvm's N=1000 wall time.** SE-matched, N=1000
   collapses to **1.08×/0.98× — a tie (2 seeds)**, gllvm faster on one. Our arm also ran at
   `n_starts=1` against our own shipped default of `4L`
   (`R/va-r3-proto.R:2189`) — at the default we are **3.6–4.1× slower** than SE-free gllvm, with
   identical accuracy at 1 and 4 starts.
3. **Claim 30 ("we have a better VA than gllvm") stays NOT ESTABLISHED — third attempt, first to
   fail for a reason other than being underpowered.** This run had 24 seeds (properly powered) and
   was model-matched and interleaved, but (a) the ψ requirement is still unmet — the DGP planted no
   ψ, which excludes the one documented AC failure mode (ledger claim 13: AC collapses ψ 0.0001
   against a planted 0.6), and (b) the speed half doesn't survive Defects A/B above.
4. **Do not build the loadings-diagonal reparameterisation.** Its only motivating measurement
   (finding 1) is retracted. The ~23-file scope estimate in
   `docs/design/va-conditioning-audit-vs-gllvm.md` has no evidence behind it now — the audit's
   description of the parameterisation difference itself is still valid, only the urgency is gone.
5. **The SE-matching defect is a shared hazard, not a one-script bug.** `75-clean-ladder.R`
   inherited its arms verbatim from `57-gllvm-scaling.R`, and `29-head-to-head-gllvm.R` scores the
   same estimand the same way. **No figure from `57`, `29`, or `75` is a like-for-like engine-speed
   comparison** until re-measured `sd.errors=FALSE` at both `n_starts` settings (ledger claim 48).

Full detail and every number's regime: `dev/va-speed/78-VARIANCE-RETRACTION-AND-LARGE-N.md`,
`dev/va-speed/77-ADVERSARIAL-REVIEW.md`. Ledger: `dev/va-speed/20-CLAIMS-LEDGER.md` claims 30
(amended), 47, 48.

## Next Immediate Steps (OWED, in order)

1. **Re-run the ladder SE-matched, at both `n_starts` ∈ {1, 4}, before any gllvm speed comparison
   is stated anywhere.** Concretely: `75-clean-ladder.R`'s `run_gllvm()` needs `sd.errors = FALSE`
   added, and our arm needs both `n_starts=1` and `n_starts=4` reported side by side. This is the
   single repair that changes the conclusion (per `77-ADVERSARIAL-REVIEW.md`'s own closing
   section) — everything else about that harness (rotation, guards, warm-up, accuracy scoring, 24
   seeds, interleaving) is sound and does not need rebuilding. N=2500 SE-matched is the one
   completely unmeasured cell (heavy, ~10 min/cell single-core) — budget for it explicitly rather
   than inferring from N=1000.
2. **Fix the timing hazard at its source, or at minimum guard every future harness against it.**
   `.va_r3_load_dll()` builds into `tempdir()` (`R/va-r3-proto.R:909`), so **every fresh `Rscript`
   recompiles the TMB template** and bills ~25 s to whichever fit runs first. Two options, not
   mutually exclusive: (a) require an untimed warm-up fit in every timing script in this lane
   (`71-split25.R` lacked one; `57-gllvm-scaling.R:74-78` and `75-clean-ladder.R` already have one
   — the lane is currently inconsistent); (b) build a persistent DLL cache so the hazard cannot
   recur regardless of harness discipline. Option (b) is a real code change to `R/va-r3-proto.R`
   and should go through the normal review path, not be done inline in a timing script.
3. **Arc B (sandwich-scoring timed pilot) is still deferred, untouched.** Tracked in GitHub issue
   #934 ("VA intervals: score the SANDWICH route ... + speed backlog"). This session did not
   advance it, comment on it, or close it.
4. **Explicitly do not build the loadings-diagonal reparameterisation on conditioning grounds.**
   Its motivating measurement is retracted (point 4 above). If a future session wants to revisit
   the ~23-file scope in `docs/design/va-conditioning-audit-vs-gllvm.md`, it needs new evidence,
   not a re-read of the retracted finding.

## Carried forward, unchanged by this session

**Whether this lane is the priority at all is a maintainer decision, not answered by this
session.** D-112/D-113 mean this VA-speed lane is **not** one of the six 0.7 capability tracks, and
missing-data **#332 remains the named primary post-0.6 slice**. Shinichi, 2026-08-04, when asked
whether this lane precedes #332: *"not necessarily."* Continuing to invest in this lane at all —
including step 1 above — is worth confirming before spending more compute on it, even though step 1
is cheap (two SE-matched cells plus a mechanical flag change).

## Live environment

```sh
cd /private/tmp/gllvmtmb-va-lane2
export NOT_CRAN=true
Rscript -e 'devtools::load_all("."); testthat::test_local(filter="standard-errors")'   # safe verify, unrelated to this arc but confirms the tree loads
ssh -o BatchMode=yes totoro    # 384 cores; lane ~/gllvm_work/va-lane2-git; budget <=150 cores
#  OPENBLAS_NUM_THREADS=1 / OMP_NUM_THREADS=1 per worker (both R script and shell wrapper)
#  ⚠ Rscript --vanilla implies --no-environ -> pass R_LIBS_USER=$HOME/R/lib or library(gllvm) fails
#  gllvm 2.0.13 on both local Mac and Totoro -- confirm before trusting any comparison
```

⚠ **Never stage:** the Dropbox checkout's `.claude/`/`.uinit/`, campaign `.rds`/`.csv` (D-50 —
compute results stay local), `dev/va-speed/inventory-analysis.txt`.
⚠ **Before any push:** `git rev-parse --abbrev-ref claude/va-lane2@{upstream}`; push with an
explicit refspec. `tools/check-push-traps.sh` guards this lane specifically.
⚠ **Do not cite `57`, `29`, or `75`'s absolute speed ratios without the SE-match + n_starts
correction** (ledger claim 48) — they are not independent measurements, they share one harness
defect.

```text
Read AGENTS.md and docs/dev-log/handover/2026-08-05-claude-handover-variance-retracted.md. Run the
handover rehydration steps, reconcile them with the current git state, then continue only the OWED
Next Immediate Steps in order — starting with confirming with the maintainer whether this lane is
still the priority before spending Totoro compute on step 1.
```
