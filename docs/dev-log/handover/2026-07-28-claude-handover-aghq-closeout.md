# Claude → Claude handover, 2026-07-28 — the AGHQ close-out arc

Lane: `claude/aghq-engine-20260728`, worktree `/private/tmp/gllvmtmb-arc0-identifiability`,
base `main` @ `72c2e53d`. **PR #801 OPEN — DO NOT MERGE.** 46 commits added this arc, pushed.

## Mission control

| | |
|---|---|
| **what this arc did** | cleared lens 1 and lens 2's objections; produced the first coverage evidence AGHQ has ever had |
| **verdict** | **WITHHELD TWICE.** Two fresh D-43 panels, both **NOT-DONE / DONE / NOT-DONE** |
| **default** | UNCHANGED. `aghq = FALSE`, nothing exported, NAMESPACE untouched |
| **suites** | AGHQ suite **FAIL 0 / SKIP 0 / PASS 1504** (was FAIL 2 / SKIP 1 / PASS 10) |
| **rung** | NOT READY. No capability claim. Two panels have now withheld it |

## ⚠ Read this before quoting any number from this arc

`docs/dev-log/decisions.md`, the final 2026-07-28 entry, lists **four statements of mine the
panel proved wrong**. The most important:

**`aghq_used == TRUE` DOES NOT MEAN THE QUADRATURE MOVED THE ANSWER.** Read
`fit$aghq$par_shift` instead — it was added for exactly this. **Any future claim must verify
the quadrature moved the objective, not read the flag.**

**⚠ THE "poisson par_shift identically 0" FIGURE IS STALE — DO NOT CITE IT.** It was measured
at `09b2dbcd`; my own false-convergence fix `12648f44` landed after it and CHANGED the
behaviour. Poisson `par_shift` is now nonzero (~0.004–0.05, deterministic). The second panel
caught this. The general lesson stands and is the important part: **after changing an engine,
re-run every measurement that engine produced — not only the invariant**, which was
insensitive to precisely what changed.

**⚠ EVERY COVERAGE NUMBER IN THIS ARC IS SUSPECT.** `25-coverage-fixedtruth.R:26-31` carries
a pre-registered gate in my own words — *"no coverage number may be quoted unless SE/SD is
near 1"* — which I **never computed**. The second panel computed it: it **fails in 45 of 48
diagonal cells** (0.159–2.608). Entry-level SE missingness is also asymmetric (aghq 4.83% vs
laplace 0.06%), so complete-case figures flatter the AGHQ arms.

## What is SOLID and cleared

* **Lens 1's original objection is CLEARED.** No headline number traces to
  `dev/aghq-r-reference.R` any more. 7550 point-recovery fits + 3199 coverage fits all call
  real `gllvmTMB()`.
* **Lens 2's original objection is CLEARED.** The golden accuracy tests genuinely run —
  23 blocks, 0 skipped, 1502 expectations, real quadrature convergence against an
  independent oracle (`k=25` error **1.6e-14**, `par_shift = 0`).
* **The MAP/ML gradient defect is genuinely fixed**, and verified not to be a loosened
  tolerance: `grad_tol` unchanged, only the tested gradient corrected to include the penalty.
  Trace descends 0.324 → 3.55e-05.
* **The ridge is unbundled** (`4dc351ed`), so `Laplace+ridge` — the fair control — is
  runnable for the first time. Opt-in only; the default path is byte-identical.
* **RETRACTED — do not carry this forward.** I reported "the shipped Laplace default covers
  0.023 at n=1600". The second panel substituted the within-truth empirical SD for my delta
  SE (possible only because the truth is fixed) and got **0.970 / 0.969 / 0.959 / 0.649**.
  The "defect" is ~90% my own unexported SE route, whose bootstrap validation had already
  failed and which I used anyway.
* **What survives instrument-independently** (a CANDIDATE, not a claim): at lam_sd = 1,
  n = 1600 the shipped Laplace default's Σ-diagonal **bias exceeds one sampling SD**
  (bias/SD = −1.115, oracle-SE coverage 0.699). Uses the empirical SD, not the delta SE.

## Commits this arc

```
4dc351ed feat(ridge): unbundle the loading ridge so Laplace+ridge is runnable
4d551817 evidence(aghq): 7550 SHIPPED-ENGINE fits — bias is O(1/T) and BINARY-SPECIFIC
d7dc6c43 fix(aghq): no ML quantity at a MAP point in silence
fa66156f test(aghq): golden tests now RUN, at a fixed point, + poisson null control
b5b67189 evidence(aghq): delta-method Sigma SE — V1 PASSES, V2 NOT CLEAN
e35dfb79 evidence(aghq): first coverage evidence — shipped default covers 0.66 at n=1600
9995a458 docs(decisions): fresh D-43 returns 2 NOT-DONE — four of my statements wrong
```

## 🔴 START HERE — THE NEXT ARC IS PLANNED

**`docs/dev-log/2026-07-28-next-arc-sigma-intervals-ULTRAPLAN.md`** — a 10 h (7–12) ultra-plan
with a copy-paste GOAL block, a Phase 0.25 sweep receipt, and 8 slices. Read it before
anything else.

**Its headline is NOT AGHQ.** Two panels converged on the same root cause: **gllvmTMB has no
trustworthy standard error for Σ = ΛΛ'.** `src/gllvmTMB.cpp:910-912` REPORTs Σ_B rather than
ADREPORTing it, `confint()` returns NA for a reduced-rank fit, and the delta route built this
arc failed its own pre-registered SE/SD gate in 45 of 48 cells. Every coverage number in this
arc — favourable and unfavourable alike — was instrument-limited, and two headline findings
were retracted for exactly that reason. Interval coverage is also the 0.6 release's own
headline gap, so fixing the instrument unblocks the AGHQ question, the Laplace question and a
release gate at once.

Slice order: **Ranga prior-art sweep first** (do `gllvm` / `Hmsc` / `boral` / `sdmTMB` already
solve this? near-zero token cost, citation-backed, and the slice most likely to change the
plan) ‖ interval-route inventory ‖ **poisson stall ROOT CAUSE** — then the validated Σ route
‖ multinomial, then re-measure, adversarial verify, D-43 panel.

**Risk branch worth knowing up front:** if the stall turns out to be a genuinely flat
objective rather than an optimiser-handoff bug, AGHQ cannot help those cells at all and
multinomial should be DEFERRED — adding a family to an engine that cannot make progress just
widens an unusable surface. The plan is allowed to end there.

## MULTINOMIAL AGHQ — the analysis, so you don't re-derive it (Shinichi asked for this arc)

Shinichi's explicit instruction: **close this arc, then implement AGHQ for multinomial in
the next one.** The analysis is already done and is on the capability surface — recording
it here so the next lane starts from it rather than re-deriving:

* **It is possible.** The quadrature is family-free: nodes, weights, mode, Cholesky and
  logdet never see the family. It integrates the LATENT (dimension `q`), which multinomial
  does not change. It needs only the site's conditional log-likelihood at each node, which
  multinomial can supply.
* **The obstruction is structural, in ONE place.** Multinomial is the sole family evaluated
  as a **grouped softmax at an anchor row** (`src/gllvmTMB.cpp:2530`) rather than per-row
  through the scalar-`eta` `obs_loglik` contract — `obs_loglik` explicitly errors for
  fid 16 (`:2310`). Its K−1 contrast pseudo-rows share one normaliser and shift together
  with the latent, so they cannot be accumulated independently.
* **The work:** move that grouped reduction INSIDE the node loop (compute all K−1 etas at
  node *u*, then one log-sum-exp), plus an assertion that a contrast group never straddles
  sites — true by construction, currently unchecked. Bounded template work + a recompile.
* **NOT the same barrier as VA's.** VA needs a K−1-dimensional integral over the category
  contrasts; that one *is* dimensional. AGHQ's is not. Do not conflate them.
* **DO THE STALL FIRST.** If AGHQ can silently return its warm start on a family it
  nominally supports, adding a fifteenth family before that is diagnosed just widens the
  surface where `aghq_used = TRUE` means nothing.

## Next session's job, in order

1. **Fix the silent decline.** AGHQ does not activate on the package's **current default
   grammar** — a default poisson `latent()` with `gllvmTMBcontrol(aghq = 9)` returns
   `aghq$used = FALSE` **with no warning**. All 10,749 evidence fits used the soft-deprecated
   `unique = FALSE` syntax. Silently ignoring an opt-in argument is a defect in its own
   right, and it means the evidence describes a non-default grammar.
2. **Fix the stall.** The adaptation loop returning the warm start while reporting
   `aghq_used = TRUE` is the deepest problem found. Either make the flag honest (report
   whether the objective moved) or fix the stall. Until then no AGHQ activity claim is safe.
3. **Re-run coverage with a FIXED truth.** The DGP redraws Λ every seed, so the reported
   coverage is marginalised over a Gaussian prior — and the ridge *is* that prior. Lens 3
   showed the "nominal" average decomposes into 0.87 in the lowest truth quintile and 0.99
   in the middle, matching the analytic over-coverage condition `s² < 2τ² + σ²` at `s = 1`.
   Draw ~3 truths once, replicate data within each, report per-truth.
4. **Vary `lam_sd` in the coverage cell** (it is fixed at 1, i.e. τ/2 — the most favourable
   configuration a shrinkage prior can be given).
5. Only then re-panel.

## Do not repeat

* Do **not** read `aghq_used` as evidence the quadrature did anything (see above).
* Do **not** quote complete-case coverage without the entry-level missingness beside it.
* Do **not** cite the divergence metric `‖Λ̂‖/‖Λ‖ > 2` as an independent result — it is
  circular with a penalty equal to `0.5·tr(Σ̂)/τ²`; McNemar on 47%→73% gives **p = 0.134**.
* Do **not** treat `O(1/T)` as established: `bias × T` is constant only in the single
  `(lam_sd = 1, n = 1600)` cell of the 7550.
* Do **not** merge PR #801. Two panels have withheld the claim.
* `pgrep -f Rscript` reports 0 for healthy R jobs — R runs as `exec/R`.

## Compute

Totoro is set up and **~10× faster per fit than the laptop**. Branch installed at
`~/h4_work/aghq-lib`, source at `~/h4_work/aghq-src`, campaigns in `~/h4_work/`. Rebuild
after any `src/` change:
`R CMD INSTALL --no-docs --library=$HOME/h4_work/aghq-lib aghq-src` — and **delete
`src/*.so` and `src/*.o` on the remote first**, `rsync --delete` protects excluded files and
a macOS `.so` gives `invalid ELF header`.

## ⚠ Concurrent lane

`claude/aghq-family-axis-20260728` is checked out at `/private/tmp/gllvmtmb-family-axis`,
1 commit ahead (`42153da3`, the family axis). It **conflicts with this branch on
`docs/dev-log/decisions.md`** — both append. Its finding (AGHQ's σ lever ~0 or negative at
n=200 across families) is *compatible* with this arc's. Ownership and merge order are
Shinichi's call, not an agent's.
