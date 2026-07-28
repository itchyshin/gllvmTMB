```
🎯 GOAL — gllvmTMB: build a Σ interval route that survives its own validation gate.
SOLO PLATFORM: CLAUDE. Worktree /private/tmp/gllvmtmb-arc0-identifiability, branch
claude/aghq-engine-20260728 (PR #801 OPEN — merging is Shinichi's call, never a goal state).

HEADLINE: EXTEND THE EXISTING PROFILE ROUTE TO LOW-RANK Σ. gllvmTMB already HAS a
simulation-validated interval route — the Gaussian Sigma_unit DIAGONAL profile at n≥150,
d≤2, ~0.946-0.948 against a 0.94 gate, under Laplace. But R/profile-route-matrix.R:631 is
explicit that "pure diagonal Sigma_unit profiles directly; LOW-RANK TOTAL SIGMA FALLS BACK TO
BOOTSTRAP" — and the 2026-07-18 handover already concluded bootstrap is the WRONG route for
this target. The repo names its own gap: "target-explicit full-Sigma profile needs a separate
gate". Low-rank Σ = ΛΛ' (unique = FALSE) is exactly what the whole AGHQ arc measured, so
every one of its coverage numbers went through the fallback. The delta route built on
2026-07-28 to fill that hole FAILED its own pre-registered SE/SD gate in 45 of 48 cells.
Every coverage number in the last arc — for AGHQ *and* for Laplace, favourable and
unfavourable alike — was therefore instrument-limited, and two headline findings were
retracted for exactly that reason. This is not an AGHQ problem: interval coverage is the
0.6 release's own headline gap. Fix the instrument and several blocked questions unblock at
once.

IN PARALLEL: prior-art sweep (Ranga/NotebookLM — do comparable packages already solve this?);
poisson-stall root cause; multinomial AGHQ.
DEFER: flipping the aghq default; any capability claim; merging #801.
DISCIPLINE: COMPUTE EVERY GATE YOU PRE-REGISTER — the last arc wrote one and never ran it ·
after ANY engine edit re-run every measurement that engine produced, not only the invariant ·
Gaussian exactness ~1e-9 and identical across k · Totoro ≤150 cores, incremental writes ·
local cores ≤6 · verify jobs with `ps aux | grep exec/R` · D-43 panel (2 build + 1 ceiling,
default NOT-DONE) before any claim, and record whatever it returns.
```

# Context — why this arc, and why not more AGHQ

The 2026-07-28 arc fixed four real engine bugs and cleared two of three original panel
objections. Two successive D-43 panels still withheld the claim, and the reason converged
both times on one thing: **the measuring instrument, not the engine.**

Four results dissolved under a mechanism check, and the last one is the diagnostic:

| dissolved | cause |
|---|---|
| poisson "null control" | AGHQ wasn't running |
| complete-case coverage | asymmetric entry-level SE missingness |
| "nominal at every n" | DGP redrew Λ per seed = the ridge's own prior |
| **"Laplace covers 0.023"** | **~90% an artefact of the delta SE route** |

The fourth matters most because it was an *unfavourable* finding. Direction of flattery gave
no protection. What all four share is an untrustworthy or unchecked instrument.

**So the binding constraint is the interval route, and it is not AGHQ-specific.**

**IMPORTANT CORRECTION to how this was first framed (Shinichi caught it).** It is NOT true
that gllvmTMB has no trustworthy Σ interval. It has exactly one, it is a PROFILE route, and
it WAS validated under Laplace: the Gaussian `Sigma_unit` diagonal at n≥150, d≤2, ~0.946-0.948
against a 0.94 gate. Asserting an absence from a negative `ADREPORT`/`confint` probe was the
same error this arc kept documenting — a negative probe cannot prove absence
([[CROSS-REPO-GUARDS]]).

The precise statement is narrower and more useful: **the validated route covers the pure
diagonal; low-rank total Σ = ΛΛ' explicitly falls back to bootstrap**
(`R/profile-route-matrix.R:631`), and bootstrap was already ruled out for this target on
2026-07-18. Since `unique = FALSE` is forced everywhere AGHQ runs, the entire AGHQ arc
measured through that fallback.

This makes the arc CHEAPER and better founded: **extend a route that already has a coverage
certificate, rather than build a delta method from scratch.** The repo has already scoped the
work — "target-explicit full-Sigma profile needs a separate gate". Interval coverage is also
the 0.6 release's headline gap, so this unblocks the AGHQ question, the Laplace question and
a release gate at once.

`ARC PROGRAM` — size mode, recommended **10 h** (range 7–12), confidence *inferred*.
Two unknowns retired by S0/S1 before any build.

---

# Phase 0.25 — sweep receipt (carry this forward; Phase 1 may not start without it)

| surface | evidence run | finding | call |
|---|---|---|---|
| repo git | `git status -sb`, `git log`, `worktree list` | branch clean, in sync, 47 commits; concurrent lane `claude/aghq-family-axis-20260728` conflicts on `decisions.md` | **resume** this branch; surface the conflict to Shinichi |
| this repo's own designs | `docs/design/75-*` (inference-route matrix), `80-nongaussian-re-evidence-bars.md` | a route matrix and an evidence-bar ladder already exist; "covered" means *dispatches*, never *calibrated* | **reuse** — do not invent a new taxonomy |
| existing interval code | `R/bootstrap-sigma.R`, `R/z-confint-gllvmTMB.R:1862-1880` | `bootstrap_Sigma()` exists (percentile, known to under-cover); log-SD Wald convention already established at `:1873` | **reuse** the log-SD convention; bootstrap is a *comparator*, not the route |
| brain | (S0 re-runs this properly) | 2026-07-18 handover already concluded bootstrap is the WRONG route for `Sigma_unit_diag`; profile / log-SD-Wald is the certificate path | **reuse** — the direction was already decided and not followed |
| **external prior art** | **NOT DONE — this is S0** | — | **must run before building** |

**Verdict:** resume the branch; reuse the log-SD convention and the existing route matrix;
the genuine gap is a *validated* Σ SE plus the stall. External prior art is unswept and is
the first slice, because building an interval route without checking how `gllvm`, `Hmsc`,
`boral` and `sdmTMB` do it risks reinventing — or worse, reinventing worse.

---

# Slices

| # | slice | member | model · effort | time | depends |
|---|---|---|---|---|---|
| **S-1** | **🔴 READ THE BRAIN FIRST — four items already on record.** (a) location-axis VCs may need a **t**-quantile not z (`qnorm` at `22-sigma-se-delta.R:104`); per-class map already filed as **gllvmTMB#565** — Λ/Ψ/sd_B = location → t may help; NB2 φ/Γ shape/Beta φ/Tweedie = dispersion → do NOT; correlations → Fisher-z. (b) profile already **certified NOMINAL at g=32** (0.948-0.956) in drmTMB. (c) profile has a KNOWN unfixed defect — bare `qchisq` at **`R/profile-ci.R:32`**, Self-Liang chi-bar-square at boundaries. (d) **`R/check-consistency.R` already wraps `TMB::checkConsistency()`** — the built-in Laplace-bias diagnostic this arc re-derived by simulation | Ada | — | 20 m | — |
| **S0** | **Prior art — NARROWED by the brain sweep.** The small-sample-VC literature (Satterthwaite / Kenward-Roger / t-vs-z) is ALREADY in the `Fast & Accurate Algorithms` NotebookLM (`3b3d2ec5`) — do not re-gather it. Ask only the genuinely open question: **does anyone profile a REDUCED-RANK covariance, and what happens to a profile under rotational non-identifiability** (Σ identified, Λ not)? Plus: how do `gllvm` / `Hmsc` / `boral` / `sdmTMB` report Σ uncertainty? | **Ranga** (NotebookLM) | n/a — outside context | 30 m | S-1 |
| **S1** | **Profile-route inventory** — read `R/profile-route-matrix.R`, `profile-ci.R`, `profile-targets.R`, `profile-derived.R` and `design/73`. What exactly does the validated diagonal profile do, why does low-rank fall back, and what would a target-explicit full-Σ profile need? This is now the load-bearing recon slice, not a survey | recon | **Sonnet · med** | 45 m | — |
| **S2** | **Poisson stall ROOT CAUSE** — why does one capped iteration make no progress? Optimiser handoff, stale tape, or genuinely flat objective? These have opposite fixes. Last arc only *labelled* it | Curie | Sonnet · high | 120 m | — |
| **S3** | **EXTEND THE PROFILE ROUTE TO LOW-RANK Σ** — the target-explicit full-Σ profile the route matrix already names as its own gap. Reuse the validated diagonal profile machinery and the log-SD convention; do NOT rebuild a delta method. Validate against the **within-truth empirical SD**, not the bootstrap; **COMPUTE the SE/SD gate per cell as a precondition to quoting any coverage number** | Gauss | Sonnet · high | 180 m | S0, S1 |
| **S4** | **Multinomial AGHQ** — move the grouped softmax reduction inside the node loop; assert a contrast group never straddles sites | Curie | Sonnet · high | 150 m | S2 |
| **S5** | **Re-measure coverage on the fixed instrument** — 4 arms × fixed truths × lam_sd {0.5,1,3}, gate computed first | Gauss | Sonnet · med | 60 m + async | S3 |
| **S6** | **Adversarial verify** — attack S3's validation specifically | Rose | Opus · high | 60 m | S3, S5 |
| **S7** | **D-43 panel**, 2 build + 1 ceiling, default NOT-DONE; record whatever it returns | panel | 2×Sonnet + 1×Opus · high | 60 m | S6 |
| — | Melissa reconcile + after-task + handover | Melissa/Rose | Sonnet · low | 45 m | all |

**PARALLEL:** {S0, S1, S2} at once. Then S3 ‖ S4. Then S5 → S6 → S7.
**FAN-OUT BUDGET:** 6 new children max, 1 ceiling. S0 is free (runs outside context).

## Why Ranga first, and what to ask

This is the slice most likely to change the plan, which is why it runs before the build.
Concretely, ask:

1. How does **`gllvm`** report uncertainty on `Sigma`/loadings — does it, and by what route?
2. **`Hmsc`** and **`boral`** are Bayesian: they get posterior intervals on Σ for free. Is
   there a published comparison of frequentist vs posterior interval behaviour for
   reduced-rank Σ that tells us what coverage to *expect*?
3. Is there known prior art on **delta-method intervals for ΛΛ'** under rotational
   non-identifiability, and is the log scale for the diagonal the established convention?
4. **`sdmTMB`** shares our TMB lineage — does it ADREPORT derived covariance quantities, and
   what did that cost?
5. Any literature on **why a Wald interval on a variance component under-covers** that would
   let us predict rather than discover.

Honour the guardrails: **triage, not authority**; auto-added sources are UNVERIFIED until
checked; exclude our own vignettes/drafts or the sweep will cite us back to ourselves.

---

# Verification

* **The SE/SD gate is a PRECONDITION, not a report.** No coverage number may be computed,
  let alone quoted, until SE/sd(est−truth) within truth strata is near 1. Last arc wrote
  that rule and skipped it; this arc computes it first and prints it per cell.
* **After any engine edit, re-run every measurement that engine produced.** The invariant is
  necessary but was insensitive to exactly what `12648f44` changed.
* Gaussian exactness ~1e-9 and identical across k after every edit.
* Full `devtools::test()` before close; AGHQ suite must stay ≥1504 passing, 0 skipped.
* S6 attacks S3's *validation*, not its output — that is where the last two arcs failed.

# Not in this arc

Flipping the `aghq` default · merging PR #801 · any capability claim before S7 ·
`R/diagnose.R` · the remaining 12 unexercised families · CRAN work.

# Risk branch

If **S0 finds an established route** (e.g. `sdmTMB` already ADREPORTs a derived covariance),
adopt it and cut S3 to an adaptation — likely saving 2 h. If **S2 finds the stall is a
genuinely flat objective** rather than a handoff bug, then AGHQ cannot help those cells at
all and S4 (multinomial) should be *deferred*, because adding a family to an engine that
cannot make progress widens an unusable surface. That is a real possible outcome and the
plan should be allowed to end there.
