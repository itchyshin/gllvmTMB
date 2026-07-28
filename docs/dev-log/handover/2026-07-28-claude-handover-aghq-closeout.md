# Claude → Claude handover, 2026-07-28 — the AGHQ close-out arc

Lane: `claude/aghq-engine-20260728`, worktree `/private/tmp/gllvmtmb-arc0-identifiability`,
base `main` @ `72c2e53d`. **PR #801 OPEN — DO NOT MERGE.** 6 commits added this arc, pushed.

## Mission control

| | |
|---|---|
| **what this arc did** | cleared lens 1 and lens 2's objections; produced the first coverage evidence AGHQ has ever had |
| **verdict** | **WITHHELD.** A fresh D-43 panel returned **NOT-DONE / DONE / NOT-DONE** |
| **default** | UNCHANGED. `aghq = FALSE`, nothing exported, NAMESPACE untouched |
| **suites** | AGHQ suite **FAIL 0 / SKIP 0 / PASS 1502** (was FAIL 2 / SKIP 1 / PASS 10) |
| **rung** | NOT READY. No capability claim. Two panels have now withheld it |

## ⚠ Read this before quoting any number from this arc

`docs/dev-log/decisions.md`, the final 2026-07-28 entry, lists **four statements of mine the
panel proved wrong**. The most important:

**`aghq_used == TRUE` DOES NOT MEAN THE QUADRATURE MOVED THE ANSWER.** 15/15 poisson AGHQ
fits at T=12 return the Laplace answer bit-for-bit (73%/60% at T=6/4) because the adaptation
loop stalls back to its warm start while the flag still reports TRUE. This destroys the
"poisson is a live null control" argument I built — it is largely AGHQ not doing anything,
which is the same inactivity objection I had used to dismiss Gaussian exactness. **Any future
claim must verify the quadrature moved the objective, not read the flag.**

Also: entry-level SE missingness is asymmetric (aghq 4.83% / aghq_ridge 1.27% vs laplace
0.06%), so the honest coverage figures are the **conservative** ones — 0.944 / 0.946 / 0.936
/ 0.949, not the complete-case 0.961 / 0.957 / 0.949 / 0.951 I first reported.

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
* **The shipped Laplace default under-covers** and worse as n grows (0.776/0.861/0.825/
  **0.664** on the Σ diagonal). Lens 3 confirmed Laplace's SE is *not* broken within truth
  strata, so this is real — but the mechanism is bias **plus** a ~28% SE deficiency at
  n=1600, not bias alone as I claimed.

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
