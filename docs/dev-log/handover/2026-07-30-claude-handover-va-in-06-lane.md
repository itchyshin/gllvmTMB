# Claude → Claude handover — the VA-in-0.6 lane, overnight state

Date: 2026-07-30 (late). Author: Claude. Target: **Claude** (same platform), or Shinichi at ~05:00.
Lane: `claude/va-in-06-20260730`, worktree `/private/tmp/gllvmtmb-va-in-06`, off `origin/main`
`c473364e`. **Pushed.** For the exact commit list, run `git log --oneline origin/main..HEAD` — a
literal count written here goes stale the moment anything else lands, including a fix to the count
itself, which is how it went stale twice already.

## Mission control

| item | state |
|---|---|
| **owner decision** | **VA SHIPS IN 0.6**, reversing the 2026-07-21 cut. Recorded, swept, `LOOP/GOAL.md` Amendment 4 |
| **Gates 0, 1, 2** | **ALL PASS**, measured not assumed (352 + 1,469 tests, `NOT_CRAN=true`) |
| **Gate 3** | harness **BUILT and smoke-tested**, campaign **NOT RUN — blocked on a maintainer decision** |
| **estimator (GH vs JJ)** | **OPEN.** Rose rejected GH-over-JJ; the two-sided detector then found JJ's hidden failures. Neither arm is clean |
| **separation guard** | **LANDED** — the session's one real code fix |
| **EVA** | our EVA proven the **same algebra** as gllvm's. Not buggy |
| **fence** | `q <= 2` (corrected down from the stated `q <= 4`; see below) |

## 🔴 Four things waiting on Shinichi — nothing proceeds past these

1. **The `n_trials` contract contradiction.** Design 85 §2 says *"no single-trial Bernoulli rows"*
   and Gate 0's NO-GO names *"trial count below two"*; `main`'s validator admits `n_trials >= 1`;
   and decisions.md **A3** names VA's purpose as *"high-$d$ **binary** JSDM"* — which *is* Bernoulli.
   A valid Gate 3 cannot cover the motivating regime; a campaign covering it cannot be admitted.
   Options: (a) fence to multi-trial and say binary JSDM is not covered; (b) extend the contract to
   Bernoulli with a fresh Gate 0 scope freeze — **now cheaper, since the separation guard landed**;
   (c) something else.
2. **How `RMSE_ml` treats its own degenerate replicates**, decided *before* any verdict is read
   (§11 forbids adjusting after). During the smoke, `ml_laplace` `kappa` ran **3.1 to 1,430** with
   `convergence = 0, pdHess = TRUE` on every seed. If the comparator is outlier-dominated, *"no more
   than 0.05 worse than ML"* is trivially passable and the gate means nothing.
3. **The estimator clause** — GH or JJ. See "the estimator is genuinely undecided" below.
4. **Whether the fence returns to `q <= 4`.** Held at `q <= 2` because Gate 3 is titled *"recovery at
   `q = 1/2`"* and the `q=4/q=6` advance is what the 2026-07-20 audit refused. Raising it needs a new
   gate or an explicit decision to ship beyond the evidence.

## What landed (11 commits)

- **The reversal, swept properly.** `docs/dev-log/2026-07-30-va-ships-in-06-reversal.md`, Amendment 4,
  `decisions.md`, a banner on the 2026-07-21 record, plus **every live surface** — `GOAL.md` (top
  banner + inline marker on the superseded line), `checkpoint.md` (THREE→FOUR), `arcs.md`,
  `ultra-plan.md`, `decision-queue.md`, Design 104 §4.1, Design 108 §7. Historical dev-log /
  after-task / handover entries left as dated records. *The previous reversal in this project was
  applied to one instance and left the false claim visible to anyone arriving by search.*
- **Gates 0/1/2 established.** ⚠ **Without `NOT_CRAN=true`, `test-va-r3-prototype.R` reports "183
  passed, 8 skipped" and looks clean — and those 8 skips ARE Gate 1.** Never cite a green run of that
  file without the env var.
- **Gate 3 pre-registered and frozen** before any run. Fixed truths (not redrawn), rank fixed, every
  attempted fit in the denominator, `Sigma_B` stratified, signed κ, MCSE between replicates. `p` and
  `n` added as declared factors — widens no tolerance, and closes Rose's objection that Gate 3 cannot
  discriminate the two VA arms.
- **The separation guard** (`.va_r3_check_separation`), ported and wired. `main` had been accepting
  Bernoulli VA fits with **no separation check at all** since PR #797 — the relaxation landed, the
  guard written to protect it did not. 6 new tests; existing suite unchanged at 352.
- **A two-sided degeneracy detector** (`dev/va-gate3/two-sided-detector.R`).
- **The branch audit** — the "~90 unmerged commits" is **1 real item**; the rest are squash-merge
  artefacts, supersessions, or docs. Codex lanes clean.
- **EVA parity** — ours ≡ gllvm's.

## The estimator is genuinely undecided — do not "resolve" it by picking

Three reviews, each correcting the last, all correct in what they measured:

- **Polya:** JJ's objective is coercive in `‖Λ‖`, so it *cannot* run away; its 0/320 degeneracy record
  is a **theorem**, not evidence. `rel_frob > 10` needs `‖Σ̂‖ > 9‖Σ‖` and is blind to contraction.
- **Fisher:** confirmed it in signed scale — but his table was a **median pooled over `p`**.
- **Rose:** disaggregating by `p` **inverts it**. At n=400, JJ's κ runs 0.501 → 0.700 → 0.814 →
  0.934 across p = 8/20/40/80 while GH stays flat at ~1.07–1.21. At **n=400, p=80 — the corner
  Design 85 exists for — JJ is the LESS-biased arm** (|κ−1| 0.066 vs 0.105), and wins the paired sign
  test 18/20. **Verdict: REJECT** the GH default. `default_tier` was NOT changed.
- **Then the two-sided detector cut back the other way:** it revealed **8 contraction failures
  invisible to the old rule, and all 8 are in the JJ/Pólya-Gamma arms** (`gtmb_jj` 3, `gllvm_va` 5).
  GH contributes zero.

So: **GH inflates and gets caught; JJ contracts and wasn't being caught at all.** Neither dominates,
and it is `p`-dependent. The pre-registered Gate 3 is designed to settle it — that is why `p` is a
factor.

## Traps that will bite the next session

1. **`NOT_CRAN=true` or Gate 1 silently skips** (above).
2. **Never filter on `status == "healthy"` / `admitted`.** The `max_projected_variance <= 4` guard
   rejects GH **14.5%** and JJ **0.0%**; on 84/320 matched cells GH is flagged where JJ is healthy on
   identical data. A status filter deletes GH's high-variance tail and manufactures the result the
   campaign exists to test. And at `n_starts = 1`, `admitted` can **never** be `TRUE`.
3. **gllvm's top-level `link=` is a SILENT NO-OP** for binomial VA/EVA/LA — use
   `family = binomial(link = "logit")`. Any past comparison passing `link=` at top level ran the
   default link, not the named one.
4. **Convergence is never health, on either side.** 56/79 gllvm fits reporting `convergence=TRUE` are
   beta-exploded (70.9%); our own Laplace hits κ=1,430 with `pdHess=TRUE`.
5. **Recompute before citing.** Seven claims were withdrawn this session, every one from citing a
   written figure or a partial search instead of deriving it. **And no pooled summary without
   checking the gradient it pools over** — that is what hid the estimator inversion.

## On the speed story — the theory is not supported by our own data

The brain note claiming VA/EVA are substantially faster than Laplace is `status: UNVERIFIED` and
quarantined (*"a LEAD, never load-bearing"*). Measured, bernoulli q=4, median seconds:
at **n=400, p=20** — `gtmb_laplace` **6.52**, `gllvm_va` 72.83, `gllvm_eva` **315.34**. Laplace is
the fastest arm at almost every cell; EVA the slowest, **compiled against compiled**.

The theory's argument (Laplace's O(m³) determinant, inner-mode iteration) concerns a corner we have
never measured — Ayumi's BIRDBASE is n=5397. **The advantage may be real there. We have no evidence
for it, and what we have points the other way.** Do not put a speed claim on any surface.

## Resume

```bash
cd "/Users/z3437171/Dropbox/Github Local/gllvmTMB" && git fetch && \
  git worktree list | grep va-in-06 || \
  git worktree add /private/tmp/gllvmtmb-va-in-06 claude/va-in-06-20260730
```

Then read, in order: this file → `docs/dev-log/2026-07-30-va-ships-in-06-reversal.md` →
`docs/dev-log/2026-07-30-gate3-preregistration.md` (the frozen spec, and the blocking correction) →
`docs/dev-log/2026-07-30-gate01-status-and-estimator-open.md`.

**Do not run the Gate 3 campaign** until item 1 and item 2 above are answered.
