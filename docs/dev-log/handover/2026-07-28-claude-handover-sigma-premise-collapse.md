# Claude → Claude handover, 2026-07-28 — the Σ-interval arc: premise collapse + four machinery fixes

Lane `claude/sigma-intervals-boundary-20260728` · worktree `/private/tmp/gllvmtmb-arc0-identifiability`
· **15 ahead / 3 BEHIND `origin/main`** · **UNPUSHED — see Landing State** · working tree clean.
Totoro campaign **RUNNING**.

---

## 1 · Mission control

| | |
|---|---|
| **the stated goal** | **UNACHIEVABLE.** Three of four deliverables rest on false premises; the fourth was deferred by the plan's own gate |
| **what shipped** | **four machinery fixes**, all test-first, all one defect class |
| **suite** | 11 profile/coverage files: **117 passed, 0 failed, 0 errors** (99 skipped — partial coverage) |
| **package claim** | **NONE made.** No capability claim, no certificate, no route-matrix status flipped |
| **blocking on Shinichi** | replace/clear the goal · **(A) or (B)** · push? |
| **START HERE** | this file → `docs/dev-log/after-task/2026-07-28-sigma-interval-arc-premise-collapse.md` |

---

## 2 · 🔴 Read before re-attempting ANY of the original plan

**The arc's headline was wrong in three independent ways. Do not rebuild it.**

1. **The boundary correction POINTS THE WRONG WAY.** χ̄²'s 95% crit is **2.706**; χ²₁'s is **3.841**
   (`P(T≤c) = 0.5 + 0.5·P(χ²₁≤c) = 0.95 ⇒ c = 2.706`). The mixture **narrows** intervals and
   **lowers** coverage. Our defect is *under*-coverage. **χ²₁ at a boundary is the conservative,
   safe choice — the current code is already the wide one.** This is arithmetic; it does not
   depend on parameterisation and will not change.
2. **Boundary DETECTION is unimplementable on the current path.** `TMB::tmbprofile()`'s inner
   refit is unconstrained, its convergence status is **discarded** (two columns returned), no
   `parm.range` is imposed, and log-SD puts SD = 0 at **−∞**. *(Partially answerable — see §6.)*
3. **THERE IS NO CERTIFICATE.** `after-task/2026-07-17-sigma-coverage-nsim5000-confirm.md` (in git
   history, **not on this branch**) reads **"Disposition: WITHHELD"**. Two D-43 audits, both 0/3.
   Against a **0.94** gate (not 0.95): d1-n150 passes; **d2-n150 FAILS on rorqual** (0.9462, band
   0.9398) and clears on Totoro by +0.0009.
   ⚠ **`decisions.md:2130-2135` overstates this as "the one coverage-certified cell in the
   package".** I inherited that sentence and repeated it in every summary until a panel caught it.
   **Read the primary record, not the summary citing it.**
4. **Multinomial deferred** — S3 fired the plan's own pre-registered risk branch.

**Also: we are NOT first.** SAS PROC GLIMMIX `COVTEST … CL / TYPE=PLR` profiles factor-analytic
`FA(q)` = ΛΛ'+D and `FA0(q)` = ΛΛ', tracing to **Jennrich & Schluchter (1986)**, shipped ~20 years.
Any "first to profile a low-rank covariance" wording is false.

---

## 3 · What shipped — four fixes, one defect class

**The instrument reported a definite answer where it had failed to measure.**

| commit | defect | evidence |
|---|---|---|
| `e34176eb` | `ytol` hard-coded to 2 while `crit = qchisq(level,1)/2` reaches 2.0 at level **0.9545** — **manufactured** ±Inf | reproduced: level 0.99 → 6/10 bounds finite, 0.95 → 10/10. Mechanism isolated by varying only `ytol`: 2→0/4, **3→0/4**, 4→4/4 |
| `fde628bf` | `is.na(-Inf)` is `FALSE`, so `(−Inf, Inf)` **scored as a successful cover**; `n_excluded` counted only NA | a vacuous method would have measured **100% coverage** |
| `26ac8301` | `.profile_bounds()` **asserted** ±Inf when the profile was merely truncated | separates **asymptotic** (flat → ±Inf honest) from **truncated** (still climbing → `NA`), decidable from the trace alone |
| `bb4862bb` | interpolation on the **deviance** scale where the grid is coarsest | ζ-scale interpolation: exact on a quadratic to 1e-6; **>10×** closer than the old rule on a coarse grid (asserted in-test) |

The `ytol = 3` row in fix 1 is the subtle one: the trace *exceeds* crit yet bounds stay infinite,
because `.profile_bounds()` must **bracket** the crossing on each side. Hence `crit + margin`, not
`crit`. Reasoning alone would have missed it.

---

## 4 · 🔴 Landing State (gate FAILS — declared CARRIED-OVER)

`tools/handoff_gate.sh` returns **GATE FAIL**. Declared, per option (b):

* **`claude/sigma-intervals-boundary-20260728` — 15 commits, UNPUSHED. CARRIED-OVER.**
  *Why not landed:* I asked twice whether to push and received no answer. Four commits change
  `main`-visible behaviour (`R/profile-ci.R`, `R/confint-inspect.R`, `R/coverage-study.R`), so
  pushing is not an agent's unilateral call under CLAUDE.md's merge rule.
  *Resume:* `cd /private/tmp/gllvmtmb-arc0-identifiability && git fetch origin`
* **The lane is 3 BEHIND `origin/main`** — caused by my own H0 merge (`869e92b5`, family-axis).
  **Rebase or merge before resuming**, then re-prove `git rev-list --left-right --count
  origin/main...HEAD` reads 0 behind.
* **LANDED:** `869e92b5` on `origin/main` — the family-axis merge (H0), pushed. Verified 0 lines
  lost from either side of the `decisions.md` conflict.
* 8 untracked `dev/aghq-*` files are a prior session's; left alone.

---

## 5 · Compute — RUNNING, do not duplicate

**Totoro, 150 cores, ~432,000 fits.** `~/h4_work/`: `regime.csv` (authoritative combine on
completion), `regime-inc.csv` (crash insurance), `regime.log`,
`regime-binomial-lam05-sorted-partial.csv` (34,891 rows from the first, aborted launch).
Script committed as `dev/aghq-evidence/23-flat-regime-campaign.R`. **Results stay LOCAL (D-50).**

**Discriminates three hypotheses for S3's near-flat objective:**
H1 DGP artefact (`eta_cap` on/off) · H2 inherent Rabe-Hesketh regime (`lam_sd`) ·
**H3 quadrature artefact (`aghq_k ∈ {9,25,51}`)** — added from the S2 sweep, which found the
adaptive-quadrature literature reports too-few nodes flatten the likelihood in covariance
parameters with spuriously **exactly zero** SDs, indistinguishable from a true boundary.

⚠ **S3's verdict (C) is PROVISIONAL until the `aghq_k` arm returns.**

⚠ **Launch error, corrected:** the first run **sorted** the grid, so at 8% every row was
`binomial, lam_sd = 0.5` — one corner, none of H1/H2/H3 readable. Relaunched with a **seeded
shuffle** (`set.seed(20260728L)`), so **any prefix is now an unbiased sample**. Read partial
results freely.

That corner did say something: **0 stalls in 34,629 binomial `lam_sd=0.5` cells** across all
three `aghq_k` and all three `n`; median `par_shift` 0.86–0.98, three orders above the
materiality floor.

---

## 6 · Next arc — the MixedModels.jl lead (Shinichi's pointer)

`docs/dev-log/2026-07-28-mixedmodels-jl-profile-lead.md`. **API docs verified; source not read.**

* **The "no finite boundary" blocker is a PARAMETERISATION CHOICE, not a law.** MixedModels'
  `lowerbd()` gives *canonical finite lower bounds* on θ, and `profile()` runs "until reaching a
  parameter bound". **Obstacle: ours lives in the TMB `.cpp`** — every `theta_*` consumer, every
  extractor, the AGHQ engine, all stored fits. **A scoping pass, not an afternoon. UNPRICED.**
* **`issingular(m, θ)`** is a **parameter-space** predicate, so the "optimizer-status ledger" the
  route matrix demands never has to interrogate the optimizer at all.
* `profile(m; threshold = 4)` on |ζ| ≈ a deviance budget of 16 vs our `crit + 1`. **Ours is the
  low end**; this is the dial to turn if truncated terminuses prove common.
* ζ-scale interpolation — **already adopted** (`bb4862bb`).

MIT licensed. Design ideas only were used; **no code ported**, so no `inst/COPYRIGHTS` entry.

---

## 7 · Do not repeat

* Do **not** rebuild the boundary-detecting reference (§2.1, §2.2).
* Do **not** cite "the certified 0.946–0.948 cell" — it is **WITHHELD** (§2.3).
* Do **not** claim novelty in profiling a low-rank covariance (SAS GLIMMIX, §2).
* Do **not** trust an agent's file:line. Three agent outputs this session carried confidently
  wrong references (`1877/1879` vs `1387/1389`; `520–532` vs `629/636`) or over-claims ("±Inf for
  every parameter, always" — it is level-dependent) **alongside correct substance**. Re-verify.
* Do **not** treat a nonzero `par_shift` as evidence AGHQ did anything: a correctly working engine
  returns ~1e-4–1e-3 in the flat regime. **Materiality floor ~3e-4.**
* "The poisson stall" is a **misnomer** — gaussian stalled 5/5 where poisson did not. It is a
  **regime** stall.
* `.tmbprofile_curve_grid()` still hard-codes `ytol = 2` — **deliberately left**: internal, no
  `level`, plotting path, and its cutoff uses the **unhalved** `qchisq`.
* `pgrep -f Rscript` reports 0 for healthy R jobs — R runs as `exec/R`.

---

## 8 · Open ledger

* `aghq = "auto"` never applies its routing — `.aghq_auto_decide()` is **dead code, no call site**
  (`R/fit-multi.R:5043, :5073, :6191, :4888`).
* Six `aghq_*` continuation controls are **not** `gllvmTMBcontrol()` arguments and are silently
  dropped (`R/fit-multi.R:5241`, `R/gllvmTMB.R:1253`). **`aghq_iter_cap` and `aghq_n_adapt` ARE
  real** — verified. Any past run that set one of the six via `gllvmTMBcontrol()` was misconfigured.
* #801 merged **without regenerating docs** — codoc mismatch on `man/gllvmTMBcontrol.Rd`, fixed
  here as a side effect.
* `.profile_terminus_status()`'s slope-ratio tolerance (0.1) is a **chosen constant**, uncalibrated.
* The certificate scripts are `dev/profile-rescore-run.R` + `dev/totoro-profile-rescore.sh`,
  commit **`829c34cd`**, on `claude/release-0.5.0` and `claude/profile-coverage-remeasure-20260718`
  — **not an ancestor of this lane**. Port before any re-measurement.
* Cross-repo: the `is.na()`-not-`is.finite()` scoring defect is worth checking in **drmTMB** and
  **hsquared**, which run analogous harnesses.

---

## 9 · 🔴 The three decisions

1. **Replace or clear the goal.** It is unsatisfiable by construction and fires on every stop.
   A replacement block is in the session transcript.
2. **(A)** invest the fresh-seed lift so d2-n150 clears 0.94 with margin — the withheld document's
   own "primary lift" and the only route to a real certificate for 0.6 — or **(B)** accept
   recovery-only framing for 0.6 and defer. *This fork was put to Shinichi in July and is still
   open.* If (A), Totoro should switch; the flat-regime run resumes without loss.
3. **Push the lane?** 15 commits, four touching `main`-visible behaviour.

---

## 10 · The one thing to carry

Every fix this session was the same shape: **the instrument returning a definite answer where it
had failed to measure** — an infinite bound manufactured, then credited, then asserted, then
imprecisely placed. The arc set out to correct a *critical value* and found the *machinery* was
the defect.

And the session's own worst error was the same class, one level up: **"the one coverage-certified
interval" was repeated all day because it appeared in a summary that agreed with what the plan
wanted to be true.** The primary record said WITHHELD the whole time.

> **Check the source, not the sentence that cites it. Especially when it confirms you.**
