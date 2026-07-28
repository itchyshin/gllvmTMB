```
🎯 GOAL — gllvmTMB: correct the boundary reference, re-certify, extend Σ intervals to low-rank.
SOLO PLATFORM: CLAUDE. Worktree /private/tmp/gllvmtmb-arc0-identifiability, branch
claude/sigma-intervals-boundary-20260728, based on main @ da7ee99e.

⚠ BASELINE CHANGED 2026-07-28T21:46Z — PR #801 was MERGED by Shinichi (merge commit
da7ee99e). The AGHQ engine and its four bug fixes are now ON MAIN. The old lane
claude/aghq-engine-20260728 is CLOSED (0 ahead / 1 behind) — do NOT continue on it, and do
not read "PR #801 OPEN / do not merge" anywhere in the handover chain as live: that was
true when written and is now spent. This arc runs on the fresh lane named above.

HOUR 0 IS SHINICHI'S, NOT AN AGENT'S: merge claude/aghq-family-axis-20260728 — STILL PENDING
as of the baseline above. It conflicts with this lane on decisions.md, which S1 writes.
S1 IS BLOCKED until it lands; every other CP-1 slice runs unblocked meanwhile. After it
lands, rebase and prove `git rev-list --left-right --count origin/main...HEAD` reads 0 behind.

HEADLINE: FIX THE BOUNDARY REFERENCE PACKAGE-WIDE, THEN EXTEND THE PROFILE TO LOW-RANK Σ.
R/profile-ci.R:32 uses a bare qchisq(level,1)/2 through a SHARED helper with four callers —
including the path that produced gllvmTMB's ONLY coverage-certified interval. At a boundary the
LR reference is a chi-bar-square mixture (Self-Liang, D-12; already specified in Design 76 §5).
🔴 A BLANKET MIXTURE IS WRONG AWAY FROM THE BOUNDARY — it would narrow every interior interval
and UNDER-cover, self-inflicting this arc's own failure mode. The deliverable is a BOUNDARY-
DETECTING reference: mixture iff the constrained optimum is at the boundary, chi-square-1
otherwise, with the detection rule itself tested. Then extend to low-rank total Sigma, which
R/profile-route-matrix.R:631 AND :638 both name as falling back to bootstrap — the route ruled
wrong on 2026-07-18. AGHQ forces unique=FALSE, so every AGHQ Sigma is low-rank and the last
arc measured entirely through that fallback.

RE-CERTIFICATION IS PART OF THE JOB, NOT A RISK TO AVOID: the certified Gaussian Sigma_unit
diagonal cell (n>=150, ~0.946-0.948) must be RE-EARNED at n_sim>=2000 under the new reference,
as a bundled arm of the same campaign. If it lands inside its 2*MCSE band the certificate
carries over with a corrected-reference note; if it lands outside, the certificate is
WITHDRAWN TO PROVISIONAL pending the panel. That response is decided NOW, not when the
number arrives.

THEN MULTINOMIAL (Shinichi's standing ask): expand_multinomial_response() at R/gllvmTMB.R:830
already makes K-1 pseudo-traits, so the factor route needs NO new C++ — but the multinomial
latent scale is NON-IDENTIFIED and must be fixed by convention before quadrature over that
same latent means anything.

IN PARALLEL: the poisson stall ROOT CAUSE (the one genuinely new finding); the never-read Codex
code review task-ms52uh0u-4mcgsc; Ranga's ONE open literature question.
DEFER: flipping the aghq default; any capability claim before the D-43 panel; merging #801;
the multinomial data-hungriness fix (N~800, a 1.0-maturity arc).
DISCIPLINE: COMPUTE EVERY GATE YOU PRE-REGISTER (last arc wrote one and never ran it) ·
n_sim >= 2000 for adjudication, ~200 is PILOT ONLY (Design 66 §7) · FIXED TRUTH PER CELL is the
house standard, not an innovation · report the fit-health denominator, never complete-case alone
· after ANY engine edit re-run every measurement that engine produced · profile targets must be
SIGMA-FUNCTIONALS (rotation invariants), never Lambda elements — Lambda is not identified ·
Gaussian exactness ~1e-9 identical across k · SMOKE BEFORE CAMPAIGN · Totoro <=150 cores,
incremental writes, read cell 1 early and abort on empty · local <=6 cores · `ps aux | grep
exec/R`, never pgrep · D-43 panel (2 build + 1 ceiling, default NOT-DONE) before any claim,
and record whatever it returns.
🔴 NEW DISCIPLINE (S3, 2026-07-28) — MATERIALITY FLOOR ON par_shift. In the near-flat regime a
CORRECTLY WORKING, exhaustively optimised engine still returns par_shift ~1e-4 to 1e-3. So a
nonzero par_shift is NOT evidence that AGHQ did anything useful. Any claim crediting AGHQ with a
correction must clear a materiality floor (par_shift distinguishable from ~3e-4) or it is
REPORTING NOISE. Apply this retrospectively to any prior arc number that cited par_shift.
Also: "the poisson stall" is a MISNOMER — it is a REGIME stall and gaussian does it too. Do not
carry the family framing forward.
THIS IS A TWO-SESSION ARC. Session A ends after S6/S8; hand over; Session B runs the campaign.
```

> # 🔴 EXECUTION FINDING — S5a's DESIGN IS NOT IMPLEMENTABLE AS WRITTEN. READ BEFORE S5a.
>
> **S4b (2026-07-28) establishes that boundary DETECTION cannot be done with the information
> available at the point the threshold is applied.** The GOAL block below still says the deliverable
> is *"mixture iff the constrained optimum is at the boundary"*. **That instruction is now known to
> be unbuildable on the current profile path.** Four independent reasons, each verified against
> installed TMB 1.9.21 source and the package:
>
> 1. `TMB::tmbprofile()`'s inner refit is **unconstrained** — `nlminb(start, newfn, newgr, control)`,
>    no `lower=`/`upper=`.
> 2. Its **convergence status is discarded**. `tmbprofile()` returns **exactly two columns**
>    (parameter, value). No convergence code, gradient norm, or active-set flag reaches the caller;
>    `.profile_bounds()` consumes only those two (`R/profile-ci.R:111-112`).
> 3. **No `parm.range` is ever imposed** in the certified path (`R/profile-ci.R:234` defaults to
>    `c(-Inf, Inf)`; `.tmbprofile_block()` :305-313 has no such argument).
> 4. **Decisive: the log-SD parameterisation puts SD = 0 at −∞** (`src/gllvmTMB.cpp:995`,
>    `sd_B = exp(theta_diag_B)`). There is no finite boundary to detect, so "the optimum is at the
>    boundary" is not a well-defined test here.
>
> **This does not kill the arc — it relocates the problem.** The statistical phenomenon is real: a
> variance component at or near zero still produces an LR statistic with a point mass, whatever the
> parameterisation. What is lost is the *detection mechanism*, not the defect.
>
> **What currently stands in for detection is itself a defect in the CERTIFIED path.**
> `.profile_bounds()`'s `find_cross()` (`R/profile-ci.R:122-159`) treats "the trace never crossed
> within ~20 adaptive steps" as "hit the boundary" and returns ±Inf. **A merely SLOW profile is
> indistinguishable from a genuine boundary case.** That is in the already-certified diagonal cell,
> not only in the routes the design doc marks blocked.
>
> **S5a must therefore choose a route before it writes code** — this is a decision for Shinichi, not
> an agent: **(a)** raise the step budget so slowness is excluded, then treat non-crossing as
> boundary — cheap, but still a heuristic; **(b)** a **simulated / parametric-bootstrap RLRT null
> reference**, which sidesteps detection entirely and is the literature's usual answer; **(c)** an
> explicit **LRT against the reduced model** with the component removed, where the boundary null is
> known by construction rather than detected; **(d)** expose optimizer status through a patched
> profile path, which is the largest change and duplicates the "optimizer-status ledger" the route
> matrix already names as a missing gate. **S2's Q4 asks exactly this of the boundary-asymptotics
> corpus; do not commit to a route before that returns.**

> **Revision note (2026-07-28, refinement pass).** This replaces the first draft of this plan.
> Changed: S5 promoted from prerequisite bugfix to the load-bearing slice, with a boundary-
> **detection** deliverable and a bundled re-certification arm; Design 76 added to the sweep
> receipt (S5 is *resume*, not *build*); six external χ² sites scoped; a scout tier added
> (5 Haiku slices, including the one previously *labelled* "recon" at Sonnet); fan-out re-cut
> into five legal checkpoints; Totoro named on the heavy slice with a smoke gate; the arc
> re-scoped to **two sessions**; missing template fields supplied. Evidence for each change is
> in the final section.

# Context

The 2026-07-28 arc built an opt-in AGHQ engine, fixed four real engine bugs, and cleared two of
three original panel objections. **Two D-43 panels still withheld the claim, converging both
times on the measuring instrument rather than the engine.** Four results dissolved under a
mechanism check; the fourth was *unfavourable* to AGHQ and dissolved anyway, which is the
diagnostic — direction of flattery gave no protection. What they shared was an unchecked
instrument. This arc fixes the instrument.

## WHAT THE BRAIN ALREADY KNOWS

| the last arc did | already on record |
|---|---|
| ran 200- and 120-seed coverage cells | **Design 66 §7: ~200 = PILOT ONLY** (MCSE 1.54pp); **2000 = the adjudication floor** |
| "discovered" the truth-redraw confound | **fixed truth per cell is the unbroken standing practice** (`m3_sample_truth`) |
| reported complete-case coverage | recorded failure mode **#1, silent denominator laundering** |
| built a delta SE with `qnorm` | **z→t for LOCATION-axis VCs**, per-class map already filed as **gllvmTMB#565** |
| measured Laplace bias by simulation | **`R/check-consistency.R` already wraps `TMB::checkConsistency()`** |
| found a "flat likelihood direction" | **Rabe-Hesketh, Skrondal & Pickles 2002** predicts exactly this for discrete + small clusters + high ICC |
| **(gap found this refinement)** | **`docs/design/76-structured-xlv-phylo.md` §5 already specifies the Self–Liang boundary reference**, with ≥500 reps/cell + MCSE and maintainer-authorization gating |

**The stall is the one genuinely new finding** — the sweep searched for a prior
adaptive-quadrature warm-start stall and found none.

## WHAT SHINICHI TOLD US — DECISIONS LOCKED

1. **Instrument first, then multinomial.** Multinomial would otherwise inherit the same broken
   measurement, and its recorded blocker is data-hungriness (N≈800), not the integrator.
2. **A1/A3 are SUPERSEDED — record the reversal explicitly**, the way the 2026-05-15 reversal
   was recorded, so a future reader can tell they were overturned rather than overlooked.
   A1 was *no engine implementation*, not *no AGHQ ever*; A3 ranked VA above AGHQ. An engine
   now exists with measured evidence. **This must be written into `decisions.md` in S1, not
   assumed silently.**
3. **S5 corrects the shared `.qchisq_threshold` and re-certifies** — not an opt-in side path.
4. **All boundary-exposed χ² sites get fixed**, not only the profile route.
5. **The family-axis lane merges first**; S1 rebases onto it.

## WHAT THE TEAM RAISED

```
Gauss  — A blanket 50:50 mixture is wrong at interior points; the certified cell has SD > 0.
         Unconditional swap → narrower intervals → under-coverage on all four shared callers.
         → Deliverable is boundary DETECTION, not a constant. Q: accept a detection rule that
         is itself an approximation?  Default if "your judgment": test the rule, report its
         misclassification rate beside the coverage.
Rose   — Correcting six user-facing interval surfaces is a behaviour change with no coverage
         evidence for five of them. → Each corrected site gets a NEWS entry and is fenced from
         any capability claim until S10. Default: fence, don't advertise.
Fisher — 5 arms x 3 lam_sd x 2000 ~ 30,000 fits plus profile refits. → Smoke first, size the
         grid from measured per-fit cost, not from hope. Default: hold lam_sd at {0.5,1,3}.
Curie  — S3's stall has two opposite fixes (handoff bug vs genuinely flat objective). If flat,
         S8 defers rather than adding a family to an engine that cannot progress.
Ada    — Recommend: S5 goes first and alone on the critical path; S6 must not start until the
         detection rule is tested, or every S6/S7 number is contaminated.
```

## ADA'S RECOMMENDATION

Run it as **two sessions split at the campaign boundary**. Session A is all instrument work and
lands nothing public; Session B runs compute and faces the panel. The split is free — the Totoro
launch is an async boundary anyway — and it keeps the D-43 panel in a fresh context, which is the
condition under which it is worth anything.

## QUESTIONS STILL OPEN

* Does the detection rule need to handle **near**-boundary (SD small but nonzero), where neither
  reference is right? S2 may answer; otherwise a documented limitation, not a silent one.
* If S9 finds the validation sound but S10 still withholds, is the certificate provisional or
  withdrawn? Shinichi's call at the panel, not before.

---

# Phase 0.25 — sweep receipt (complete; Phase 1 may begin)

| surface | evidence run | finding | call |
|---|---|---|---|
| repo git | `git status -sb`, `git worktree list`, `git rev-list --left-right --count` | **re-run 21:5x: PR #801 MERGED (`da7ee99e`)** — old lane 0 ahead/1 behind, closed; re-baselined onto `claude/sigma-intervals-boundary-20260728`; `claude/aghq-family-axis-20260728` still unmerged and still conflicts on `decisions.md` | **re-baseline**; Hour-0 merge is Shinichi's, S1 blocked |
| repo designs | `docs/design/{66,73,75,80}` | MCSE table, log-SD-Wald convention, route matrix, evidence-bar ladder all exist | **reuse** — invent no new taxonomy |
| **repo designs (gap closed this pass)** | `grep -rn "chi.bar\|Self.Liang" docs/design/` | **`76-structured-xlv-phylo.md:350,393,434,487,526,592,631` already specifies the Self–Liang boundary reference + ≥500 reps/cell + MCSE** | **RESUME, not build** — S5 reads §5 first |
| interval code | `grep -rn qchisq R/`; `sed -n '615,660p' R/profile-route-matrix.R` | certified diagonal profile exists; **:631 AND :638** both fall back to bootstrap; `.qchisq_threshold` shared by **4 callers**; **6 more bare χ² sites** outside it; `.qt_threshold` already exists carrying an on-record caution | **extend + correct**, do not rebuild |
| brain (4-way MCP sweep) | `search_notes(search_all_projects=true)` ×4 + `read_note` | coverage conventions, z-vs-t (#565), D-12's Self–Liang defect, `check_consistency()`, Design 84 multinomial, A1/A3 | **reuse all six** |
| external prior art | NotebookLM `3b3d2ec5` exists — **narrow ask only, S2** | the small-sample-VC literature is already gathered | **narrow the ask**, don't re-gather |
| compute | `ssh totoro 'echo; nproc; ls ~/h4_work'` | **TOTORO_OK, 384 cores**, `aghq-lib` + `aghq-src` present | **reuse the installed lane** |

**Verdict: resume + reuse + correct.** The genuine gap is (a) a *boundary-detecting* reference —
Design 76 specifies the target but no implementation exists, (b) a low-rank profile, (c) the stall.

---

# ARC PROGRAM

Size mode. **Two sessions.** Session A ≈ **8.3 h**, Session B ≈ **4.75 h** attended (plus async
Totoro wall-clock). **Effort sum ≈ 19.7 h** across 16 slices. Under-run response: pull S8
forward. Integration/closeout slot: S11 + S12, 55 m.

# Slices

| # | slice | member | model · effort | dispatch | time | dep |
|---|---|---|---|---|---|---|
| **H0** | **Merge `claude/aghq-family-axis-20260728`; agents then rebase and prove 0-behind** | **Shinichi** | — | — | — | — |
| **S0** | **Collect Codex review `task-ms52uh0u-4mcgsc`** — dispatched last arc, result never read; the first reading of this *code* rather than its claims. Summarise findings + severity | recon | **Haiku · low** | native/explicit | 15 m | — |
| **S1** | **Record the A1/A3 supersession** in `decisions.md` (explicit reversal, 2026-05-15 style) + **land the orphan note** `docs/dev-log/2026-07-22-quadrature-regime-trap-*.md` — UNCOMMITTED in the MAIN worktree and out-of-lane; it holds the Rabe-Hesketh/Liu–Pierce regime analysis that *predicts* this arc's flat-likelihood finding | Ada (inline) | Sonnet · low | orchestrator | 40 m | H0 |
| **S2** | 🔴 **BLOCKED ON AUTH.** **Ranga — the ONE open question.** Route via **`/notebook`** — *`/ask-brain` is DEPRECATED (Shinichi, 2026-07-28); do not reach for it.* Blocker: `nlm doctor` reports *"Profile 'default': not found"*, so the MCP returns "No authentication found". Needs **Shinichi** to run `nlm login` (opens Chrome for Google auth — an agent must not perform it). Then: do NOT re-gather small-sample-VC literature (already in NotebookLM `3b3d2ec5`). Ask only: does anyone profile a **reduced-rank** covariance; what happens to a profile under **rotational non-identifiability** (Σ identified, Λ not); how do `gllvm`/`Hmsc`/`boral`/`sdmTMB` report Σ uncertainty; is there a **near**-boundary reference | **Ranga** | outside context | `/notebook` | 30 m | 🔴 auth |
| **S3** | ✅ **DONE — VERDICT (C), genuinely near-flat objective.** → `docs/dev-log/2026-07-28-S3-stall-rootcause.md`. **(A) and (B) both RULED OUT**: a `retape()`d and a fresh `MakeADFun` object agree to *exact floating-point identity* at three points (kills stale tape); `nlminb` fed `par_L` directly returns it unchanged with its own honest *"function evaluation limit reached"* (kills handoff). **The decisive test** (raising the real production loop's first-pass budget via `aghq_iter_cap` to 2 / 25 / 1000): `par_shift` **asymptotes at ≈0.00027** (0.000239 → 0.000272 → 0.000273), objective unchanged to 5 s.f. Budget starvation would grow with budget; this does not. Plus a **dose-response no code bug could produce** — stall rate rises monotonically with `lam_sd`: 40% → 60% → 90% → **100%**. ⚠ **"THE POISSON STALL" IS A MISNOMER — family is NOT the discriminator.** Under a moderate DGP poisson did *not* stall in 5/5 seeds, while **gaussian stalled in 5/5**. It is a REGIME stall (large loading SD relative to the mean scale, small clusters), exactly as Rabe-Hesketh/Skrondal/Pickles predict | Curie | Sonnet · high | native/explicit | 120 m | — |
| **S4a** | ✅ **DONE.** Mechanical inventory → `scratchpad/S4a-inventory.md`. **Result: 8 χ² sites** (the shared helper + 7 external), **4** `.qchisq_threshold` callers, **1** `.qt_threshold` caller (`profile-derived.R:1387`), **2** bootstrap-fallback route rows. New site found: `suggest-lambda-constraint.R:365`. ⚠ **Its raw count of "34" conflates χ² LR references with `qnorm` Wald quantiles — different instruments; the χ² count is 8.** ⚠ **Its line numbers for `profile-derived.R` (1877/1879) and the route rows (520–532) are WRONG** — verified correct: 1387/1389 and 629/636. Content reliable, numbering not | recon | **Haiku · low** | native/explicit | 25 m | — |
| **S4b** | **Profile-route judgment read.** `profile-ci.R`, `profile-route-matrix.R`, `profile-targets.R`, `profile-derived.R`, `design/73`, **`design/76 §5`**. What the certified diagonal profile does; *why* low-rank falls back; what a target-explicit full-Σ profile would need | Noether | Sonnet · med | native/explicit | 45 m | S4a |
| **S5a** | **🔴 Boundary-DETECTING reference in `.qchisq_threshold`.** Mixture iff the constrained optimum sits at the boundary; χ²₁ otherwise; **the detection rule is itself tested**. Regression evidence for **all four callers** (`profile-ci.R:239`, `profile-derived.R:351`, `:1389`, `confint-inspect.R:177`). Honour `.qt_threshold`'s on-record caution — it is *not* a calibrated small-sample correction and stays a labelled sensitivity path | **Gauss** | Sonnet · high | native/explicit | 180 m | S2, S4b |
| **S5b-i** | **Classify the SEVEN external χ² sites** *(S4a raised this from six)* — `loading-profile.R:236,323`, `plot-covariance-tables.R:915`, `profile-derived-curves.R:208,1028`, `kernel-helpers.R:314`, **`suggest-lambda-constraint.R:365`**. Boundary-exposed or interior-only? (a variance/SD can sit at a boundary; a single loading entry under rotation cannot in the same sense; a correlation has *two* boundaries and is a different correction again). **`suggest-lambda-constraint.R:365` is the hard one and the reason this slice exists:** it tests **H0: Λ = 0** at `qchisq(0.95, 1)` to decide loading-entry *retention*. Whether that null is on a boundary depends on whether the test is over a single entry (interior) or an entire column, i.e. a rank reduction (boundary). Settle it, don't assume it | recon | **Haiku · low** | native/explicit | 20 m | ✅ S4a done |
| **S5b-ii** | **Correct the boundary-exposed subset**; fence the rest **with the reason recorded** (a finding, not a skip). NEWS entry per corrected site; all fenced from capability claims until S10 | Gauss | Sonnet · high | native/explicit | 70 m | S5a, S5b-i |
| **S6** | **Extend the profile to low-rank Σ — BOTH tiers** (`Sigma/unit` :631 *and* `Sigma/unit_obs` :638 carry the identical fallback). Reuse the certified diagonal machinery + the log-SD convention. **Targets must be Σ-functionals (rotation invariants), never Λ elements.** Route-matrix rows are a public surface — do not flip a status here | **Gauss** | Sonnet · high | native/explicit | 180 m | S2, S4b, S5a |
| **S8** | ⛔ **DEFERRED — the pre-registered risk branch FIRED.** The plan's own rule: *"S3 finds a genuinely flat objective (not a handoff bug) → AGHQ cannot help those cells; S8 DEFERS rather than adding a family to an engine that cannot make progress."* S3 returned exactly that. Adding multinomial now would extend AGHQ into a regime where the correction it offers is ~1e-4 — indistinguishable from noise. **This arc's discipline is "compute every gate you pre-register"; the gate was computed and it says stop.** Multinomial returns when there is a demonstrated regime in which AGHQ moves materially. *(Unchanged when it resumes: settle the non-identified latent-scale convention first; reuse `expand_multinomial_response()` at `R/gllvmTMB.R:830`, no new C++; do NOT re-attempt `R=(1/K)(I+J)` OLRE — recorded negative.)* | — | — | — | — | ⛔ |
| — | **🔻 SESSION A CLOSES — handover written here** | Rose | Sonnet · low | orchestrator | 30 m | S6, S8 |
| **S7.0** | **SMOKE.** 1 cell, tiny n, 1 rep on Totoro. Prove non-empty, non-NA, in-range; `str()` **one fit past its guards** (guard-blocked ops return all-NA silently); confirm the invocation actually parsed. Measure per-fit cost to size the grid | recon | **Haiku · low** | native/explicit | 20 m | S6 |
| **S7** | **Coverage, to house standard.** `check_consistency()` FIRST as the cheap Laplace-bias gate. Then **n_sim ≥ 2000**, **fixed truth per cell**, `lam_sd ∈ {0.5,1,3}`, 4 arms **+ the re-certification arm** (certified Gaussian `Sigma_unit` diagonal under the new reference). **Compute the SE/SD gate and the fit-health denominator BEFORE quoting any number.** Totoro ≤150 cores, incremental writes, read cell 1 early and abort on empty | Gauss | Sonnet · med | native/explicit + **Totoro** | 90 m attended + async | S7.0 |
| **MV** | **Mechanical verify** — every slice delivered a non-empty artifact; every file:line cited resolves; AGHQ suite ≥1504 passing / 0 skipped; `devtools::test()` clean; Gaussian exactness ~1e-9 identical across k | recon | **Haiku · low** | native/explicit | 20 m | S7 |
| **S9** | **Adversarial verify — attack S5/S6/S7's *validation*, not their output.** That is where both prior arcs failed. Specifically: is the boundary-detection rule right, and does the re-certification arm actually re-earn the number | **Rose** | **Opus · high** | native/explicit | 60 m | S7, MV |
| **S10** | **D-43 panel** — 2 build + 1 ceiling, fresh context, default NOT-DONE; **record whatever it returns** | panel | 2×Sonnet + 1×Opus · high | `--phase completion` | 60 m | S9 |
| **S11** | **Melissa reconcile** → `docs/dev-log/plan-actual/2026-07-2X-sigma-intervals.md` | Melissa | Sonnet · low | native/explicit | 25 m | S10 |
| **S12** | **After-task report + handover** | Rose | Sonnet · low | native/explicit | 30 m | S11 |

**PARALLEL / SEQUENTIAL:**
`{S0, S2, S3, S4a}` → `S4b` → `S5a` → `{S5b-i→S5b-ii ‖ S6 ‖ S8}` → **SESSION SPLIT** →
`S7.0` → `S7` → `{MV → S9}` → `S10` → `S11` → `S12`.
Critical path: `S1 → S4a → S4b → S5a → S6` (Session A), then `S7.0 → S7 → S9 → S10` (Session B).

---

# Fan-out budget

| checkpoint | children | ceiling | contents |
|---|---|---|---|
| **CP-1** | 4 (+Ranga, free) | 0 | S0·Haiku, S2·Ranga, S3·Sonnet, S4a·Haiku, S4b·Sonnet — *(S1 is Ada inline, not a child)* |
| **CP-2** | 5 | 0 | S5a·Sonnet, S5b-i·Haiku, S5b-ii·Sonnet, S6·Sonnet, S8·Sonnet |
| — | — | — | **SESSION SPLIT — handover** |
| **CP-3** | 4 | **1** | S7.0·Haiku, S7·Sonnet, MV·Haiku, **S9·Opus** |
| **CP-4** | *completion phase — separate budget* | 1 | S10: exactly 2 build + 1 ceiling |
| **CP-5** | 2 | 0 | S11·Sonnet, S12·Sonnet |

`LUNA SUITABILITY:` **yes** — S0, S4a, S5b-i, S7.0, MV are bounded, read-only/mechanical.
`ULTRA EFFORT:` **no.**
`MODELS:` Haiku·low ×5 · Sonnet·low ×4 · Sonnet·med ×2 · Sonnet·high ×5 · Opus·high ×1 (+ panel).
`CONTEXT BRAKE:` parent input < 100k at launch; **the session split IS the brake** — no child forked past CP-2.
`COMPACTIONS:` parent 0 · boundary = scope freezes at CP-2, fresh task for Session B.
`LANE RECEIPT:` **START A FRESH TASK** at the Session-A close — the campaign is async and the panel needs a fresh context.
`AUTO-REVIEW:` batch protected/network actions at the Totoro boundary; warn if guardian calls > 25/session.
`D-43 PANEL:` milestone = `low-rank-Σ-interval-v1` · status = not fired · composition = 2 build + 1 ceiling.
`ESTIMATE:` ~19.7 h effort · ~13 h critical path · 16 slices · **needs a handoff — does NOT fit one session.**
`REVIEW:` Rose + Gauss critique **this plan** before any slice runs.
`VERIFY:` see below. `CONSOLIDATE:` S12. `RECONCILE:` S11 → `docs/dev-log/plan-actual/`.

---

# Critical files

`R/profile-ci.R` (**:32** the shared threshold · **:43** `.qt_threshold`'s on-record caution ·
:239) · `R/profile-route-matrix.R` (**:631 and :638** — both fallbacks) · `R/profile-derived.R`
(:351, :1389) · `R/confint-inspect.R:177` · `R/profile-targets.R` ·
`R/loading-profile.R`, `R/plot-covariance-tables.R`, `R/profile-derived-curves.R`,
`R/kernel-helpers.R` (the six external χ² sites) · `R/check-consistency.R` (**reuse, don't
rebuild**) · `R/fit-multi.R` (:5102 the `unique=FALSE` eligibility gate; the AGHQ adaptation
loop, for S3) · `R/gllvmTMB.R:830` (`expand_multinomial_response`, for S8) ·
`src/gllvmTMB.cpp` (:2310 `obs_loglik` fid-16 error, :2530 the grouped softmax, for S8) ·
`docs/design/{66,73,75,76,80}` · `dev/aghq-evidence/22-sigma-se-delta.R:104` (`qnorm` — the
z-vs-t site).

# Verification

* **The SE/SD gate and the fit-health denominator are PRECONDITIONS, not reports.** No coverage
  number is computed, let alone quoted, until both are in hand. Last arc wrote that rule into its
  own script and skipped it — `25-coverage-fixedtruth.R:26-31`, and a panel found it fails in 45
  of 48 cells.
* **✅ S7 PRECONDITION — RESOLVED by S4b. The certificate's script is FOUND; it must be PORTED.**
  `docs/dev-log/decisions.md:2130-2135` records the claim but names no script. S4b located it in
  git history: **`dev/profile-rescore-run.R` + `dev/totoro-profile-rescore.sh`, commit `829c34cd`**
  (2026-07-16, *"genuine profile + log-SD delta-Wald on Sigma_unit total variance V_t"*), together
  with +301 lines in `R/profile-derived.R` (`.total_variance_spec()`,
  `.profile_ci_total_variance()`, `.wald_ci_total_variance_logsd()`) and the `dev/m3-grid.R` wiring
  for `profile_total` / `wald_t_logsd` / `coverage_certificate`. It lives on
  `claude/release-0.5.0` and `claude/profile-coverage-remeasure-20260718` and is **NOT an ancestor
  of this lane** (`git merge-base --is-ancestor 829c34cd HEAD` → false; `ls dev/` has no
  `profile-rescore*`). `dd80244a` is the public-flip commit only and contains no script.
  **So: port `829c34cd`'s scripts and wiring onto this lane BEFORE S7, and the re-certification arm
  is then genuinely like-for-like.** This supersedes the weaker fallback recorded in `f6a317c7`
  ("state it is a fresh measurement"). ⚠ The committed MCSE pointer `m3-pilot-report.R:768` is
  **stale** — the file exists at HEAD (1658 lines), that line no longer holds the formula.
* **🔴 NEW DEFECTS ON MAIN — from the recovered Codex review (S0), now that #801 has merged.**
  Two are CONFIRMED and affect what this arc may assume:
  - **`aghq = "auto"` does not use its advertised auto-routing (BLOCKING).**
    `.aghq_auto_decide()` is **dead code — no call site**, so its trait-count cutoff and
    decline-on-expensive-gate policy never affect a fit. The per-family optimizer recommendation is
    inert too: `.aghq_resolve()` returns `optimizer`/`optArgs` but `.gllvmTMB_aghq_k()` keeps only
    `k`, and `run_one()` uses `control$optimizer`. `"auto"` is materially less conservative than
    documented. `R/fit-multi.R:5043, :5073, :6191, :4888`.
  - **Continuation controls are silently ignored (IMPORTANT — may invalidate prior runs).** The loop
    reads `aghq_continuation`, `aghq_shift_tol`, `aghq_grad_tol`, `aghq_f_tol`,
    `aghq_escalate_patience`, `aghq_rho_min`, but **none is a formal `gllvmTMBcontrol()` argument**
    and `...` is ignored with a warning. `gllvmTMBcontrol(aghq_continuation = FALSE)` **does
    nothing**; only direct mutation of the returned list works. `R/fit-multi.R:5241`,
    `R/gllvmTMB.R:1253`. **Any earlier measurement that set one of these via `gllvmTMBcontrol()` was
    misconfigured and did not test what it recorded — re-check before citing such a run.**
  - *(minor, not user-facing)* C++ does not validate `aghq_n_node > 0`; a direct TMB caller with a
    zero-row grid reaches `aghq_logw(0)`. `src/gllvmTMB.cpp:2651`.
  - **Reviewed and found SOUND:** the quadrature math (the `sqrt(2)` appears exactly once, via the R
    grid), the shadowed-grid equivalence, state hygiene on examined paths, and the ridge
    (`theta_rr_B / tau²` added in both wrapper and convergence gradient).
* **The boundary-detection rule is tested as an object in its own right** — not merely "coverage
  improved". Report its misclassification rate beside the coverage.
* **All four `.qchisq_threshold` callers carry regression evidence.** A change to a shared helper
  is not verified by testing one caller.
* **n_sim ≥ 2000** for anything adjudicating; label a smaller run PILOT in the same sentence.
* **After any engine edit, re-run every measurement that engine produced** — the invariant was
  insensitive to exactly what `12648f44` changed, and stale numbers were cited for hours.
* Gaussian exactness ~1e-9, identical across k, after every edit.
* AGHQ suite ≥1504 passing, 0 skipped; full `devtools::test()` before close.
* **S9 attacks the validation, not the output.**

# Compute (S7)

Totoro, ≤150 cores; branch installed at `~/h4_work/aghq-lib`, source `~/h4_work/aghq-src`.
Rebuild after any `src/` change:

```bash
R CMD INSTALL --no-docs --library=$HOME/h4_work/aghq-lib aghq-src
```

**Delete `src/*.so` and `src/*.o` on the remote first** — `rsync --delete` protects excluded
files, and a macOS `.so` gives `invalid ELF header`. Grid ≈ 5 arms × 3 `lam_sd` × 2000 ≈
**30,000 fits** plus profile refits — **size it from S7.0's measured per-fit cost, not from this
estimate.** `ps aux | grep exec/R`, never `pgrep`. Local ≤6 cores (Codex shares it).

# Not in this arc

Flipping the `aghq` default · merging PR #801 · any capability claim before S10 · flipping a
route-matrix status · `R/diagnose.R` · the remaining 12 unexercised families · CRAN work ·
the multinomial data-hungriness fix (N≈800; recorded as a **1.0-maturity** arc) ·
**the separable/Kronecker lead — see below.**

## Recorded next lead — separable (Kronecker) covariance via TMB `SEPARABLE`

From Ben Bolker's 2026-07-28 follow-up (§9). **Deferred to after this arc by its own honest
priority**, recorded here so it is not re-derived. Claims verified in this worktree 2026-07-28:

| claim | check |
|---|---|
| `SEPARABLE_t` is TMB's own, not RTMB | `TMB/include/tmbutils/density.hpp:1106`; `kronecker.hpp` beside it. **RTMB is not needed.** |
| the package hand-rolls what `SEPARABLE` provides | `grep -c "SEPARABLE\|kronecker" src/gllvmTMB.cpp` → **0**, against **22** `GMRF` uses |
| the simulate caveat is real and is the header's own | `density.hpp:42-46` — every component must supply `cov_sqrt_scale`, or `SEPARABLE(...)` lacks the simulate method |

The per-trait SPDE loop (`~:1468`, `~:1497`, comment `~:1564`) is `SEPARABLE(iid_over_traits,
GMRF(Q_base))` with an identity trait factor; the phylo-slope block near `:1524-1531` hand-writes
an MVN normalising constant (`0.5*(n·log 2π + log_det_A + quad)`). *(Line numbers drift — locate
by pattern, not by number.)* Neither is claimed wrong; the argument is that log-determinant
bookkeeping is where hand-rolled separable densities fail **silently**, and a misplaced `logdet`
perturbs estimates rather than only the reported nll once the trait factor is estimated.

**Ranked:** (1) an **estimated unstructured trait covariance** in the same density without a new
derivation — a capability gain, the one that could justify moving this earlier; (2) `T×T` and
`n×n` determinants/solves stay factored, with `GMRF`'s sparsity surviving; (3) ASReml parity,
which is a comparator argument for the quant-gen audience.

**Before adopting, check per path, not globally:** does the trait factor genuinely stay constant
across units (unbalanced designs and trait-specific fixed effects break the product structure);
does each composed component supply `cov_sqrt_scale`; and do **not** double-count the saving on
`rr(...)` paths, where low-rank already achieves part of it.

**🔗 Forward-coupling to S6 — the one thing this arc must not foreclose.** Opportunity (1) creates
a *new Σ surface that will need intervals*, and it is **not** low-rank. S6 should therefore keep
its Σ-functional targets general over the covariance's structure rather than hard-coding a
`ΛΛ'`-only assumption. This costs nothing now and avoids a rewrite later. Routing: repo-wide
engine, reaches GLLVM.jl as a design question, but **D-94 holds — the R half leads.**

# Risk branches

* **S3 finds a genuinely flat objective** (not a handoff bug) → AGHQ cannot help those cells;
  **S8 defers** rather than adding a family to an engine that cannot make progress.
* **The re-certification arm moves the certified cell out of its 2·MCSE band** → the certificate
  is **withdrawn to provisional** pending S10, per the GOAL block. Not quietly restated.
* **S5b-i finds most sites interior-only** → S5b-ii shrinks to a fencing exercise, ~50 m saved.
* **S2 finds an established low-rank route** → S6 collapses to an adaptation, ~2 h saved.
* **S5a proves harder than 180 m** → it still goes first and alone; an uncorrected reference
  would silently contaminate every S6/S7 number, which is precisely this arc's recurring failure.

---

# Why this revision (evidence, verified in the worktree 2026-07-28)

| change | evidence |
|---|---|
| S5 is load-bearing, not a prerequisite | `.qchisq_threshold` has **4 callers**: `profile-ci.R:239`, `profile-derived.R:351`, `:1389`, `confint-inspect.R:177` |
| **boundary *detection*, not a constant swap** | Self–Liang applies at the boundary; the certified cell has SD > 0 (interior), where χ²₁ is correct. An unconditional mixture narrows interior intervals → under-coverage — this arc's own failure mode, self-inflicted |
| Design 76 added to the receipt | `grep -rn "Self.Liang" docs/design/` → `76-structured-xlv-phylo.md:350,393,434,487,526,592,631` |
| `.qt_threshold` constraint honoured | `R/profile-ci.R:43ff` — on-record: *"not a generally calibrated small-sample profile-likelihood correction"*; requires an explicit justified `df`; label as sensitivity analysis |
| S6 is two tiers, not one | `R/profile-route-matrix.R:631` **and :638** carry identical fallback text |
| six external χ² sites scoped | `loading-profile.R:236,323` · `plot-covariance-tables.R:915` · `profile-derived-curves.R:208,1028` · `kernel-helpers.R:314` |
| Σ-functional targets, not Λ | Λ is not identified under rotation; a profile over a Λ element is not well-posed |
| scout tier added | prior draft: 8 Sonnet + 1 Opus, with S4 *labelled* "recon" priced at Sonnet·med |
| budget re-cut | prior draft: 10 slices against a stated 6-child cap, and **two** ceiling children (S9 + S10's) against a stated cap of 1 |
| Totoro named + smoke gate | prior draft: `"90 m + async"` — no compute target, no smoke, against its own DISCIPLINE line |
| two sessions | prior draft: 900 m of slices under a stated 11 h; after the five locked decisions, ≈19.7 h effort / ≈13 h path |
| S0 exists | Codex review `task-ms52uh0u-4mcgsc` was dispatched last arc and its result never read — the cheapest high-value item available |
| H0 is Shinichi's | `claude/aghq-family-axis-20260728` conflicts on `decisions.md`, which S1 writes; the prior draft quoted the conflict in its own receipt and then scheduled S1 into it |
