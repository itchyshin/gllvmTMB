# Session Handoff — VA registry, calibrated SEs, four retractions

**Meta:** 2026-07-27 · target = Claude · author = Claude · lane
`claude/va-wiring-20260726` · worktree `/private/tmp/gllvmtmb-va-wiring-20260726`
· **PR #798 OPEN** · `main` merged in · pushed · suite green.

## Resume block (paste and go)

```sh
cd /private/tmp/gllvmtmb-va-wiring-20260726 && claude "Read
docs/dev-log/after-task/2026-07-27-va-registry-calibrated-se-and-four-retractions.md
then this handover. PR #798 is open and green. Do NOT re-derive the calibration
(done: se_profile covers 0.935-0.950 vs nominal 0.95, 25 seeds, MCSE 0.015) and do
NOT re-run the timing claims (four retractions are recorded; re-deriving them is how
they came back twice). First task: finish the two items in 'Immediate next steps'."
```

## Critical context — read before planning

**Four claims this lane carried are now retracted. Do not resurrect them.**

1. **L-BFGS-B is NOT 16× at n=800.** Interleaved it measures **0.9×** — slower. It is
   kept for gradient quality (4 vs 10/19/6 evaluations), not speed. The
   "dense inverse-Hessian is the n≥2500 wall" hypothesis has **no support**; do not
   frame any scale work as testing it.
2. **gllvm EVA did NOT have "all reporting converged".** A `grepl` substring bug
   (`"converged"` matches `"not_converged"`) at `dev/totoro-grid/analyse-grid.R:100`.
   True 160/203. The arms were also scored on different fields. **Needs re-scoring
   before any use.** Surviving headline: `gtmb_laplace` 59/70, jointly on
   `convergence==0` AND `pdHess==TRUE`.
3. **JJ does NOT beat GH generally.** True at n=150, **reverses at n=400**.
4. **VA is NOT inherently slow.** Inside gllvm, **VA is 2.1–4.7× faster than LA** in
   every cell. Our VA being slow is an *implementation gap*. Ordering measured:
   **gllvmTMB Laplace ≫ gllvm VA > gllvm LA ≫ our VA.**

## What shipped

`51d1fa81` Arc 0 + ENGINE column · `4dc65e44` family registry · `74f4c810` LV posterior
SDs + fixed-parameter information · `b20061e7` Design 109 + audits + harness ·
`2becfd49` calibration evidence · `35ac6c88` per-family row corrections.

**VA has calibrated intervals** (β only, binomial-logit, q=2, p=8, n∈{150,400}):
`se_profile` 0.935–0.950 against nominal 0.95 in every cell; `se_conditional`
under-covers in every cell (0.885–0.910). The Schur complement is load-bearing.

## Immediate next steps

1. **IN FLIGHT when this was written — check first.** Two agents were running:
   - **nbinom2 port** (proves the registry claim). Had modified
     `inst/tmb/gllvmTMB_va_r3.cpp` and `R/va-r3-proto.R`. Its report should be at
     `docs/dev-log/2026-07-27-nbinom2-registry-proof.md`. **If it did not finish,
     the working tree may hold partial edits — check `git status` before anything.**
     A negative result ("cost more than a declaration + a likelihood") is a valid and
     important outcome; do not force it through.
   - **gllvm VA-vs-LA benchmark** — results already in `dev/gllvm-va-vs-la-results.csv`
     (72 rows, table above). `dev/gllvm-va-vs-la.md` may still be pending.
2. **Rename `score$negative_elbo_gh`** — Shinichi approved. It hardcodes `_gh` in a
   field that can now hold a JJ value. Call sites in `dev/totoro-grid/run-grid.R:97`
   and siblings. Deferred only because an agent held `R/`.

## Decisions Shinichi made this session

- **Keep the JJ binomial default.** Its original justification (better Σ_B recovery)
  reverses at n=400, but JJ is 4–5× faster, so it is now an explicit speed/accuracy
  trade rather than a dominance claim.
- **Rename `negative_elbo_gh`:** yes.
- **Fix the per-family rows:** done (`35ac6c88`).
- **The Ayumi note is a DRAFT and UNSENT** —
  `docs/dev-log/2026-07-27-for-ayumi-va-status-and-a-convergence-caution.md`.
- **Time-to-inference replaces point-only timing** as the only headline metric.
- **Measure the SE bias before choosing a fix** — done; the answer was the Schur
  complement, and it works.

## Shinichi's strategic steer — AGHQ (do not lose this)

He proposed **improving our Laplace and implementing AGHQ** instead of pushing VA
further. **I agree and recommend it above more VA work.** Reasons:

- AGHQ is the only route with a **convergence knob** — Laplace *is* AGHQ with one
  node, and adding nodes provably improves toward exact. VA has no such knob and we
  just measured it converging to the *wrong* answer (attenuation 0.59–0.69).
- We already use AGHQ as an **oracle**: `.eva_aghq_marginal_q1()` in `R/eva-proto.R`
  and the fixed-coordinate admission test in `test-va-r3-prototype.R`. Promoting it
  from reference to estimator is a smaller step than it sounds.
- Cost wall is `H^q` evaluations per unit — practical at q ≤ 2, painful beyond.
- **"Improve LA" concretely means "speed up the SE step":** `sdreport` is **27–32%**
  of Laplace's time-to-inference and rising with n.

## Gotchas — do not repeat

- **Never time from a single sequential pass.** Five retractions, one cause.
- **Never infer relative speed from architecture.** Three framings were corrected by
  measurement in one session; every one came from reasoning instead of measuring.
- **A default flip must sweep call sites AND tests.** `eval_method="auto"` meaning GH
  was assumed in four `dev/` scripts and three tests.
- **`grepl` on a status string is a substring match.**
- **Score every arm on the same fields** or the comparison is an artifact.
- **`extract_Sigma_B()` returns a list** (`$Sigma_B`, `$R_B`), not a matrix.
- **`gllvmTMB_wide()` cannot suppress Psi** — the only matched Laplace comparator is
  the formula path with `latent(..., unique = FALSE)`.
- **Touching `va_r3.cpp` forces a recompile** and changes `source_checksum`; re-run
  timing after, never across.
- **Never `git add -A`** — ~20 untracked `dev/` scratch files.

## Open, maintainer-only

- Re-score the gllvm comparison with real gradient/Hessian extraction (bounded re-run,
  not a full 640-cell repeat).
- Latent-score SDs are **entirely uncalibrated** — only β was tested.
- Design 109's global monotonicity of `g` in `v` is **not proved**; downstream claims
  are conditional on a 5-line deterministic quadrature check.
- The article Shinichi wants on VA/EVA is **gated on capability** — his call, and
  right. Natural trigger: tier-1 family parity plus the calibration number.

## Landing state

| Artifact | Committed | Pushed | PR |
|---|---|---|---|
| `claude/va-wiring-20260726` | yes | yes | **#798 open** |

`devtools::test()`: FAIL 0 | WARN 2 | SKIP 782 | PASS 7563. NAMESPACE diff 0.
