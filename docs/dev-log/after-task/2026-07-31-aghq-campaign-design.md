# After-task — the AGHQ estimator campaign: designed, coded, and blocked on #874

**2026-07-31 · Claude (Fable 5) · branch `claude/843-truthstart-20260731` · slice 2 of the lane**

## 1. Goal

The lane's stated deliverable: *"evidence that answers 'does AGHQ produce BETTER POINT
ESTIMATES than Laplace, and where' — an ADEMP-designed simulation campaign with a
pre-registered estimand, a defined truth, a named regime, and a seed count justified by
MCSE."* The brief's own headline: **the design is the work; running it is the easy part.**

## 2. Implemented

- `docs/design/2026-07-31-aghq-estimator-campaign-ADEMP.md` — the design. ADEMP (Morris,
  White & Crowther 2019) with the Williams et al. (2024) 11-item self-audit filled in
  honestly (three items short or absent, marked as such).
- `dev/aghq-evidence/24-estimator-campaign.R` + `24-summarise.R` — turnkey runner and the
  acceptance rule.
- `dev/aghq-evidence/25-convergence-nladder.R` + `25-analyse.R` — the blocker probe.
- `docs/dev-log/audits/2026-07-31-aghq-convergence-nladder.md` — the blocker evidence.
- Issue **#874** filed; design and handover re-pointed.

**Outcome: the campaign is designed, pre-registered, coded, smoke-tested — and correctly
NOT RUN.** The smoke test found that the AGHQ loop reports convergence in **0% of fits at
n = 400 and n = 1600**, because `aghq_grad_tol` is a fixed 1e-4 while the gradient at the
stop grows ~√n. The design's converged-only analysis population is therefore empty at every
n, and running 16,000 fits would return a table tagged `OPTIMISER-LIMITED` throughout.

## 3a. Decisions and Rejected Alternatives

- **Paired within replicate.** All five arms fitted to the *same* data. The pilot (#843's
  40 seeds) gives SD 0.0624 on the paired ρ-MAE difference against 0.1386/0.1362 unpaired —
  **2.2× tighter for free.** This is what makes n_sim = 400 a computed number rather than a
  habitual one.
- **Rotation-invariant primary estimand.** Λ is identified only up to rotation, so an
  elementwise loading bias would need Procrustes and would import its own choices. The trait
  correlation avoids the problem instead of managing it, and is what JSDM users publish.
- **Banned `aghq_ridge` vs plain `laplace`** by pre-registration. It is the confound #842
  named, and banning it in advance is cheaper than resisting it later.
- **Stored `Λ̂` for every fit.** Makes the primary estimand a post-hoc choice, so maintainer
  decision 1 (correlation vs Σ_unit) cannot force a re-run. ~2 MB.
- **`aghq_ms` is derived, not fitted** — `min(aghq, aghq_alt)` on the final objective. Costs
  5 fits per replicate rather than 6, and it is also the honest definition of "run both,
  keep the better".
- **Held `p` fixed.** The O(1/T) mechanism was retracted in #842; varying `p` would spend
  compute on a refuted hypothesis. Varied ‖Λ‖ instead, which is the measured driver.
- **Rejected running the grid anyway.** With the converged-only population empty, the
  campaign cannot answer its own question; the output would be the exact class of number
  this lane exists to stop producing.
- **Rejected lowering the convergence gate to fit the data.** That is the post-hoc tuning
  pre-registration exists to prevent. Removed the gate and replaced it with *reporting*
  plus an `OPTIMISER-LIMITED` tag — amendment recorded in the open (§P.3b).

## 4. Files Touched

| file | change |
|---|---|
| `docs/design/2026-07-31-aghq-estimator-campaign-ADEMP.md` | new — the design + §P.3b amendment + blocker header |
| `dev/aghq-evidence/24-estimator-campaign.R`, `24-summarise.R` | new — runner, summariser |
| `dev/aghq-evidence/25-convergence-nladder.R`, `25-analyse.R`, `25-convergence-nladder.csv` | new — blocker probe + data |
| `docs/dev-log/audits/2026-07-31-aghq-convergence-nladder.md` | new |
| `docs/dev-log/decisions.md`, `handover/2026-07-31-aghq-campaign-designed-blocked-on-874.md` | appended / new |

**No package code changed in this slice.** The only source change on the branch is #843's
inert diagnostic hook.

## 5. Checks Run

- Smoke test 1 cell × 10 seeds (50 fits) — **found two measurement-validity defects**.
- Re-smoke 1 cell × 40 seeds (200 fits) — sized the convergence rate at n = 100.
- Totoro n-ladder, 150 fits, 60 cores, ~14 min — established 0% at n = 400 and 1600.
- **Cross-build check:** Totoro (2026-07-29 build) vs local (current source) at n = 100
  agree within MCSE — which is what licenses using the older Totoro build for the n-ladder.
- Full-run arithmetic from **measured** per-fit times, not guesses.
- PR #870 CI: **ubuntu-latest (release) PASS, 22m12s**.

## 6. Tests of the Tests

The smoke test *is* the test of the campaign, and it worked: it invalidated two things in
my own pre-registered design before any expensive compute.

The load-bearing self-check is the **cross-build agreement at n = 100**. Without it, the
Totoro n-ladder would be a claim about a 2-day-old binary; with it, the older build is
demonstrably adequate for this probe. That check exists because the same class of error
(stale install) had already bitten this lane once.

The counterfactual analysis carries its own honesty check: the `stalled at cap 1` branch
does not report its gradient, so 33/22/11 fits per cell are **unclassifiable from outside
the engine** — stated explicitly, and the recovery figures are labelled a **lower bound**
rather than a result.

## 7a. Issue Ledger

- **#874 NEW** — `aghq_grad_tol` fixed when it should scale; AGHQ convergence 0% at n ≥ 400.
  Includes a concrete second ask: have the stalled branch report `max |grad|`.
- **#847 / #857** — #874 belongs on that scale-constant inventory; noted in both.
- **#843, #871** — from slice 1, unchanged.

## 8. Consistency Audit

Walking the neighbourhood of the convergence finding:

- **The wrong-field error generalises.** Any AGHQ convergence number taken from
  `opt$convergence` anywhere in the repo is measuring the per-pass cap. Recorded in
  `decisions.md` as binding on future work rather than left as a local note.
- **The defect class is one the repo already tracks.** `aghq_grad_tol` sits with #847's
  `tau = 2`, `loading_absolute_thresh = 6`, and the #857 inventory. Routed there rather
  than filed as an isolated curiosity.
- **Checked I was not claiming another lane's work.** Totoro carries Codex's
  `design90`/`design91`; I created `~/gllvmtmb-aghq-20260731` and touched neither.
- **Checked the Totoro build date rather than the branch** — it is 2026-07-29 and predates
  the hook arm 4 needs. Surfaced in the handover as a prerequisite.

## 9. What Did Not Go Smoothly

- **My first pre-registered convergence gate was built on the wrong field**, and would have
  marked every AGHQ cell INCONCLUSIVE for a reason that was an artefact. Caught by a 50-fit
  smoke test; it would have been very expensive to catch after 16,000.
- **The `nohup` launch on Totoro appeared to fail** (the ssh call hit a 2-minute timeout).
  It had in fact launched; the session was just holding open. Verified by `pgrep` rather
  than assumed either way.
- Two R one-liners failed on shell escaping before I moved the analysis into a file. Minor,
  but the lesson is to put anything with regex metacharacters in a script.
- **I shipped a fidelity bug in the runner and the Stage 2 exercise caught it.** My
  `alt_start()` reimplements the engine's truth-free alternative start, and I dropped its
  family guard: the engine applies the empirical-**logit** intercepts only when
  `identical(family_id_vec[1L], 1L)` (binomial), leaving them at their Laplace values
  otherwise. Mine applied `qlogis()` unconditionally, which off the logit scale is a
  catastrophic start — **poisson n=1600 `aghq_alt` took 941 s against `aghq`'s 19 s, a 50×
  slowdown**, which is how it announced itself. Fixed, and Stage 2 re-run clean.
  **Binomial is unaffected**, so Stage 1 and every slice-1 number stand. The general lesson
  is the sharper one: *reimplementing engine logic in a harness reintroduces exactly the
  divergence risk that invalidated `dev/aghq-r-reference.R`* — the thing this whole lane
  exists to correct. Where a harness must mirror engine code, it should mirror it line by
  line and say so.
- **My rapid pushes auto-cancelled four CI runs.** The concurrency group cancels in-flight
  runs on a new push; batching the commits would have cost one run instead of five. The
  last green run (`85e87099`) covers the only package-source change on the branch, and
  nothing in `R/`, `src/` or `tests/` has changed since — verified, not assumed.

## 10. Known Residuals

- **The campaign has not run.** That is the correct state, not an incomplete one — but it
  means the lane's headline question is still unanswered.
- **A third of the fits are unclassifiable** (`stalled at cap 1`, no gradient reported), so
  the true convergence picture is bounded, not known.
- **The √n reading describes three points.** It is consistent with the score's scale; it is
  not a derived rate and is not claimed as one.
- ~~Stage 2 unexercised~~ — **closed.** The family switch has now been run end-to-end for
  gaussian and poisson at n = 100 and 1600, 0 fit failures, which is what surfaced the
  `alt_start` fidelity bug above and re-costed the budget (252 → **134** measured
  core-hours; poisson n=1600 dominates Stage 2 entirely).
- **#874 is family-general**, on small cells: gaussian and poisson AGHQ arms converge **0%**
  at both n. Gaussian returns the Laplace optimum bit-for-bit (`par_shift = 0`) at n = 1600
  as well as n = 100 — and still reports non-convergence.
- **My prediction P3 looks wrong for poisson.** I predicted a near-zero quadrature-moved
  rate from the audit's *"poisson (74.0%) returns the Laplace answer bit-for-bit"*; poisson
  moved in 4/4 fits (median |shift| ≈ 1.4–1.9e-2). Four fits cannot overturn the audit, and
  the two may measure different things (bit-for-bit vs a 1e-6 threshold) — recorded now as a
  prediction that currently looks wrong rather than dropped later.
- **n = 400 per-fit time is interpolated**, not measured; flagged in the design's budget.
- **The design's items 4, 6 and 9** (methods citations, package versions, worked case study)
  are short or absent and marked as such in the self-audit.

## 11. Team Learning

- **The smoke test is where you discover the expensive thing is premature.** 270 fits found
  what 16,000 would have buried under a confident-looking table.
- **Pre-registration is only as good as the field you measure.** Both amendments this slice
  were about *measurement validity*, not about the answer — and both were recorded in the
  open, with the grid unrun, rather than quietly patched.
- **"Fixed constant standing in for a data-determined scale" is now a named, recurring class
  in this repo** (#847, #857, #874, `loading_absolute_thresh`). Worth a lint, not another
  issue each time.
- **Check the installed build date, never the branch.** Bitten once locally (13 days stale),
  avoided once on Totoro (2 days stale, and it would have broken arm 4).

## 12. Cross-Product Coverage

The convergence-field trap (`opt$convergence` meaning the iteration cap under a capped
continuation schedule) applies to any TMB package that caps inner iterations — **drmTMB
included**, if it adopts a similar adaptation loop. The scale-constant class already has a
cross-repo home in the #857 inventory.

**Memory receipt.** Loaded and used: the lane brief's *"the DESIGN is the work"* and its
method note (*"if your own findings contradict the framing of the task, stop and re-ask"* —
which is exactly what happened, and drove the decision not to run); D-50 (results local,
Totoro not Actions); the Codex lane fence (design90/91 untouched); the Rose principle
(drove §8, which routed #874 to the existing class rather than leaving it isolated); and the
Totoro standing authority for the ControlMaster socket. I invoked the **`simulation-design`
skill** and followed its ADEMP + Williams structure, including the 11-item self-audit table
verbatim. I did **not** query the brain MCP: the question was repo-local and the design's
inputs were the repo's own audits, issues and pilot data.
