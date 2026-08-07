# GOAL — va-s0a-gaussian (IMMUTABLE — re-read at the top of EVERY arc)

Read this first, every cycle. Auto-compact eats messages, not this file.

## Mission

Run a **fresh** known-truth Gaussian VA validation on Totoro for
`gaussian_identity` at q∈{2,5}, and produce a scientific absolute-first ledger
(`SCIENTIFIC_PASS` / `SCIENTIFIC_FAIL` / `SCIENTIFIC_INCONCLUSIVE`) versus planted
truth. Stop after S0a for Shinichi checkpoint before any S0b.

## Headline

Answer “Gaussian must pass?” with **absolute recovery vs planted truth** as the
primary score — without soft-passing frozen Arc-2 `overall_point_route_verdict =
INCONCLUSIVE`, and without touching the public VA fence or `calibrated=FALSE`.

## Invariants

1. **One lane only:** `codex/va-gh-all-families` @ worktree
   `/private/tmp/gllvmtmb-va-gh-all-families`. Do not touch other worktrees/branches.
2. **Fresh seeds primary:** do **not** reuse Arc-2 confirmation rows (seeds 1:500)
   as the scientific verdict. Use a disjoint seed block.
3. **No package mutation** of `R/`, `src/`, public VA fence, thresholds, or
   `calibrated` without a new explicit G0.
4. **Do not** mutate frozen Arc-2 INCONCLUSIVE labels; reprint them beside
   scientific verdicts.
5. **D-50:** Totoro/DRAC only; no GitHub Actions artifacts; raw evidence stays local.
6. **No Arc-2 re-run, no pooling, no multinomial** in this goal.
7. **No push/PR** unless Shinichi explicitly says so.
8. Fixture spirit (Design 110): n=120, p=8, exact VA route, H=7 plan marker,
   `match_laplace_residual_sd` when comparing Laplace on pure Gaussian.
9. Abs caps start at β RMSE < 0.35 and Σ rel Frobenius < 0.50 (default). Caps may
   be proposed alternate if evidence warrants — record **both** default and chosen.
10. Eligibility for SCIENTIFIC_PASS prefers **abs-availability ≥ 0.90** (finite VA
    metrics), **not** paired Laplace. Report LA completion and paired ratios as
    secondary diagnostics only.
11. Always report matched **gllvm** VA (and Laplace if available) vs truth where
    feasible (series invariant — `lanes/va-s0b-exact/protocol/gllvm-comparator.md`).
12. **STOP after S0a** — do not open S0b without Shinichi yes.

## Authoritative WHAT

See `LOOP/ultra-plan.md` (approved plan + G0 overlay of 2026-08-07). Detail wins
there; this file wins on “what must never be lost.”

## Definition of done

1. Totoro fresh Gaussian job completed (or blocked with RESUME) with durable
   evidence paths + checksums.
2. Scientific ledger for q=2 and q=5 under default caps (and any alternate).
3. Explicit confirmation that frozen Arc-2 overall labels remain INCONCLUSIVE /
   unchanged.
4. After-task + check-log + plan Actuals updated.
5. Explicit STOP asking Shinichi whether to open S0b (yes/no).
