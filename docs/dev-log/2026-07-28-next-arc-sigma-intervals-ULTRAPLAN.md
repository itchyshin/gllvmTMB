```
🎯 GOAL — gllvmTMB: a Σ interval instrument that survives its own gate, then multinomial.
SOLO PLATFORM: CLAUDE. Worktree /private/tmp/gllvmtmb-arc0-identifiability, branch
claude/aghq-engine-20260728. PR #801 OPEN — merging is Shinichi's call, never a goal state.

HEADLINE: EXTEND THE CERTIFIED PROFILE ROUTE TO LOW-RANK Σ. gllvmTMB already has ONE
coverage-certified interval — the Gaussian Sigma_unit DIAGONAL profile — but
R/profile-route-matrix.R:631 is explicit that LOW-RANK TOTAL Σ FALLS BACK TO BOOTSTRAP, which
was ruled the wrong route on 2026-07-18. AGHQ forces unique = FALSE, so Σ = ΛΛ' is low-rank in
every AGHQ fit and the entire last arc measured through that fallback. Interval coverage is
also the 0.6 release's own headline gap. Fix the instrument and the AGHQ question, the Laplace
question and a release gate unblock together.

THEN MULTINOMIAL (Shinichi's standing ask), which needs LESS than assumed:
expand_multinomial_response already makes K−1 pseudo-traits, so the factor route needs NO new
C++ — but the multinomial latent scale is NON-IDENTIFIED and must be fixed by convention
before quadrature over that same latent means anything.

IN PARALLEL: the poisson stall ROOT CAUSE (the one genuinely new finding — the brain searched
and found no prior instance).
DEFER: flipping the aghq default; any capability claim before the panel; merging #801.
DISCIPLINE: COMPUTE EVERY GATE YOU PRE-REGISTER (last arc wrote one and never ran it) ·
n_sim ≥ 2000 for adjudication, ~200 is PILOT ONLY (Design 66 §7) · FIXED TRUTH PER CELL is
the house standard, not an innovation · report the fit-health denominator, never complete-case
alone · after ANY engine edit re-run every measurement that engine produced, not only the
invariant · Gaussian exactness ~1e-9 identical across k · Totoro ≤150 cores, incremental
writes · local ≤6 cores · `ps aux | grep exec/R`, never pgrep · D-43 panel (2 build + 1
ceiling, default NOT-DONE) before any claim, and record whatever it returns.
```

# Context

The 2026-07-28 arc built an opt-in AGHQ engine, fixed four real engine bugs, and cleared two
of three original panel objections. **Two D-43 panels still withheld the claim, converging both
times on the measuring instrument rather than the engine.** Four results dissolved under a
mechanism check; the fourth was *unfavourable* to AGHQ and dissolved anyway, which is the
diagnostic — direction of flattery gave no protection. What they shared was an unchecked
instrument.

A brain sweep then found that most of what the arc "discovered" was already on record:

| the arc did | the brain already held |
|---|---|
| ran 200- and 120-seed coverage cells | **Design 66 §7: ~200 = PILOT ONLY** (MCSE 1.54pp); **2000 = the adjudication floor** |
| "discovered" the truth-redraw confound | **fixed truth per cell is the unbroken standing practice** (`m3_sample_truth`) |
| reported complete-case coverage | recorded failure mode **#1, silent denominator laundering** |
| built a delta SE with `qnorm` | **z→t for LOCATION-axis VCs**, per-class map already filed as **gllvmTMB#565** |
| measured Laplace bias by simulation | **`R/check-consistency.R` already wraps `TMB::checkConsistency()`** |
| found a "flat likelihood direction" | **Rabe-Hesketh, Skrondal & Pickles 2002** predicts exactly this for discrete + small clusters + high ICC |

**The stall is the one genuinely new finding** — the sweep searched for a prior
adaptive-quadrature warm-start stall and found none.

`ARC PROGRAM` — size mode, recommended **11 h** (range 8–12), confidence *inferred*.

## DECISIONS LOCKED (Shinichi, this session)

1. **Instrument first, then multinomial.** Multinomial would otherwise inherit the same broken
   measurement, and its recorded blocker is data-hungriness (N≈800), not the integrator.
2. **A1/A3 are SUPERSEDED — record the reversal explicitly**, the way the 2026-05-15 reversal
   was recorded, so a future reader can tell they were overturned rather than overlooked.
   A1 was *no engine implementation*, not *no AGHQ ever*; A3 ranked VA above AGHQ. An engine
   now exists with measured evidence. **This must be written into `decisions.md` in S1, not
   assumed silently.**

---

# Phase 0.25 — sweep receipt (complete; Phase 1 may begin)

| surface | evidence run | finding | call |
|---|---|---|---|
| repo git | `git status -sb`, `log`, `worktree list` | clean, in sync, 51 commits; lane `claude/aghq-family-axis-20260728` conflicts on `decisions.md` | **resume**; surface conflict to Shinichi |
| repo designs | `docs/design/66`, `73`, `75`, `80` | MCSE table, log-SD-Wald convention, route matrix, evidence-bar ladder all exist | **reuse** — invent no new taxonomy |
| interval code | `R/profile-*.R`, `R/bootstrap-sigma.R`, `R/z-confint-gllvmTMB.R:1873` | certified diagonal profile exists; low-rank falls back to bootstrap (`profile-route-matrix.R:631`) | **extend**, do not rebuild |
| brain (4-way MCP sweep) | `search_notes(search_all_projects=true)` ×4 + `read_note` | coverage conventions, z-vs-t (#565), D-12's Self–Liang defect, `check_consistency()`, Design 84 multinomial, A1/A3 | **reuse all six** |
| external prior art | **NOT DONE — S2** | the small-sample-VC literature is already in NotebookLM `3b3d2ec5` | narrow the ask |

**Verdict: resume + reuse.** The genuine gap is a *low-rank* profile, the Self–Liang fix, and
the stall. Everything else already exists.

---

# Slices

| # | slice | member | model · effort | time | dep |
|---|---|---|---|---|---|
| **S1** | **Record the A1/A3 reversal + land the orphan note.** Write the explicit supersession entry (locked above). Also land `docs/dev-log/2026-07-22-quadrature-regime-trap-*.md` — it is UNCOMMITTED and out-of-lane, and it holds the Rabe-Hesketh/Liu–Pierce regime analysis that predicts this arc's flat-likelihood finding | Ada | Sonnet · low | 30 m | — |
| **S2** | **Ranga — the ONE open question.** Do NOT re-gather small-sample-VC literature (already in NotebookLM `3b3d2ec5`). Ask only: does anyone profile a **reduced-rank** covariance, and what happens to a profile under **rotational non-identifiability** (Σ identified, Λ not)? Plus how `gllvm`/`Hmsc`/`boral`/`sdmTMB` report Σ uncertainty | **Ranga** | outside context | 30 m | — |
| **S3** | **Poisson stall ROOT CAUSE.** Why does the capped first iteration make no progress? Optimiser handoff, stale tape, or genuinely flat objective — opposite fixes. Last arc only *labelled* it. Reproducer: poisson, n=200, T=6, q=1, `unique=FALSE`, `aghq=9, aghq_ridge=Inf` | Curie | Sonnet · high | 120 m | — |
| **S4** | **Profile-route deep read.** `profile-ci.R`, `profile-route-matrix.R`, `profile-targets.R`, `profile-derived.R`, `design/73`. What does the certified diagonal profile do, *why* does low-rank fall back, what would a target-explicit full-Σ profile need? | recon | Sonnet · med | 45 m | — |
| **S5** | **Fix the Self–Liang defect.** `R/profile-ci.R:32` uses a bare `qchisq(level, 1)/2`; at a boundary the LR reference is a **chi-bar-square mixture**, so it mis-covers *in profile's own best regime* (D-12). Any low-rank extension inherits this unless fixed first | Gauss | Sonnet · high | 90 m | S4 |
| **S6** | **Extend the profile to low-rank Σ** — the target-explicit full-Σ profile the route matrix names as its own gap. Reuse the certified diagonal machinery + the log-SD convention. Settle z-vs-t per **#565's per-class map** (Λ/Ψ/sd_B = location → t may help; dispersion → do NOT; correlations → Fisher-z) | Gauss | Sonnet · high | 180 m | S2, S4, S5 |
| **S7** | **Coverage, to house standard.** `check_consistency()` FIRST as the cheap Laplace-bias gate. Then **n_sim ≥ 2000**, **fixed truth per cell**, lam_sd ∈ {0.5,1,3}, 4 arms. **Compute the SE/SD gate and the fit-health denominator BEFORE quoting any number** | Gauss | Sonnet · med | 90 m + async | S6 |
| **S8** | **Multinomial** — settle the **latent-scale convention** first (non-identified; must be FIXED, and quadrature interacts with it). Then wire AGHQ through the *existing* pseudo-trait path. **Do NOT re-attempt the `R=(1/K)(I+J)` OLRE regularization** — recorded negative | Curie | Sonnet · high | 150 m | S3 |
| **S9** | **Adversarial verify** — attack S6/S7's *validation*, not their output. That is where both prior arcs failed | Rose | Opus · high | 60 m | S7 |
| **S10** | **D-43 panel**, 2 build + 1 ceiling, default NOT-DONE; **record whatever it returns** | panel | 2×Sonnet + 1×Opus · high | 60 m | S9 |
| — | Melissa reconcile · after-task · handover | Melissa/Rose | Sonnet · low | 45 m | all |

**PARALLEL:** {S1, S2, S3, S4} → {S5} → {S6 ‖ S8} → S7 → S9 → S10.
**FAN-OUT BUDGET:** 6 new children per checkpoint, 1 ceiling. S2 is free (outside context).

---

# Critical files

`R/profile-ci.R` (:32 Self–Liang) · `R/profile-route-matrix.R` (:631 the fallback) ·
`R/profile-targets.R` · `R/profile-derived.R` · `R/check-consistency.R` (reuse, don't rebuild) ·
`R/fit-multi.R` (the AGHQ adaptation loop, for S3) · `src/gllvmTMB.cpp` (:2310 `obs_loglik`
fid-16 error, :2530 the grouped softmax, for S8) · `docs/design/{66,73,75,80}` ·
`dev/aghq-evidence/22-sigma-se-delta.R` (**`qnorm` at :104 — the z-vs-t site**).

# Verification

* **The SE/SD gate and the fit-health denominator are PRECONDITIONS, not reports.** No coverage
  number is computed, let alone quoted, until both are in hand. Last arc wrote that rule into
  its own script and skipped it.
* **n_sim ≥ 2000** for anything adjudicating; label a smaller run PILOT in the same sentence.
* **After any engine edit, re-run every measurement that engine produced** — the invariant was
  insensitive to exactly what `12648f44` changed, and stale numbers were cited for hours.
* Gaussian exactness ~1e-9, identical across k, after every edit.
* AGHQ suite ≥1504 passing, 0 skipped; full `devtools::test()` before close.
* **S9 attacks the validation, not the output.**

# Not in this arc

Flipping the `aghq` default · merging PR #801 · any capability claim before S10 ·
`R/diagnose.R` · the remaining 12 unexercised families · CRAN work · the multinomial
data-hungriness fix (N≈800; recorded as a **1.0-maturity** arc).

# Risk branches

* **S3 finds a genuinely flat objective** (not a handoff bug) → AGHQ cannot help those cells;
  **S8 defers** rather than adding a family to an engine that cannot make progress.
* **S2 finds an established low-rank route** → S6 collapses to an adaptation, ~2 h saved.
* **S5 proves harder than 90 m** → it still goes first; an uncorrected Self–Liang reference
  would silently contaminate every S6/S7 number, which is precisely this arc's recurring
  failure.
