# Handover to Cursor — gllvmTMB VA lane: GH is the estimator, and two lanes disagree

**Author:** Claude Code (Fable 5), solo · **Target:** Cursor, fresh agent, **no chat inherited**
**Branch:** `claude/va-ac-curvature` @ **`5f055984`** — ✅ **PUSHED** (`origin/claude/va-ac-curvature`)
**Worktree:** `/private/tmp/gllvmtmb-ac-curvature`
**`origin/main`:** `5bf18ab3` — **PROTECTED, untouched. No PR opened. No default changed.**

> The committed repository is authoritative. This file supersedes chat.
> **Classify every item below OWED / DONE / RETRACTED / PROTECTED against actual git state before
> acting.** Do not trust this document over the repository.

---

## 0. FIRST — rehydrate, in this order

```sh
bash ~/shinichi-brain/tools/lane_preflight.sh /private/tmp/gllvmtmb-ac-curvature
cd /private/tmp/gllvmtmb-ac-curvature && ./tools/check-push-traps.sh
git log --oneline -8 && git status --short
export NOT_CRAN=true
Rscript dev/va-usability/170-gllvm-convention-arbiter.R      # 30 s — settles §1. RUN THIS.
```

⚠ **`lane_preflight.sh` cannot see a second CLAUDE session.** It checks for a *Codex* lane. Two
Claude sessions ran concurrently in this repo today and both committed. Also run:
`ps aux | grep claude` and `git log --all --oneline --since="6 hours ago"`.

---

## 1. 🔴 READ THIS BEFORE TOUCHING ANYTHING — two lanes disagree, and one is wrong

**`claude/va-lane2` @ `7fd4fe19` contains a REGRESSION. Do not merge it. Do not propagate it.**

That commit — *"fix(evidence): stop folding sigma.lv into gllvm loadings; quarantine the bad CSV
rows"* (16:36, **unpushed**) — changes gllvm's scoring to use **raw `theta`** and quarantines
correct CSV rows as bad. It is wrong, and this lane has the disproof.

**Correct: `Λ = theta %*% diag(sigma.lv)`.** Two independent proofs
(`dev/va-usability/170-gllvm-convention-arbiter.R`, 30 s to re-run):

1. **Structural.** gllvm's `theta` has its diagonal pinned at **exactly 1** (`theta[1,1] = 1`,
   `theta[2,2] = 1`, `theta[1,2] = 0`) — an identifiability constraint. **A loading matrix with a
   fixed unit diagonal cannot represent loading magnitude.** The scale must live in `sigma.lv`.
2. **Convention-free and decisive.** Reconstruct **gllvm's own linear predictor** and ask which Λ
   reproduces it:

   | convention | max abs difference from gllvm's own η |
   |---|---|
   | raw `theta` | **4.78e-01** |
   | **`theta %*% diag(sigma.lv)`** | **4.44e-16** — machine precision |

**⚠ THE TRAP, and why a careful person got this wrong twice.** The `va-lane2` commit cites
`eta_var` from `130-scale-convention-crux.R` as its "convention-free" evidence. **`eta_var` is NOT
convention-free for this question.** It is computed as `var(U %*% t(L))` — i.e. *from* the
convention under test. Both conventions produce an `eta_var`; you cannot use it to choose between
them without an external reference. The genuinely convention-free test is **reproducing gllvm's own
arithmetic**, which is what the arbiter does and what `eta_var` cannot do.

**This convention has now flipped THREE times on argument** (see `dev/va-usability/CONVENTION-SETTLED.md`
for the full history and why the wrong answer is seductive: raw scoring makes gllvm look unbiased at
trace ~1.0, which is what a mature CRAN package "should" look like). **Do not re-argue it. Re-run
the arbiter.**

**Consequence:** `100-probit-stage8-summary.csv`'s original `gllvm` rows were **CORRECT**. The
`va-lane2` quarantine should be reverted, but that is **a maintainer decision, not Cursor's** —
surface it, do not act unilaterally.

---

## 2. THE HEADLINE — GH's cost was a hard-wired constant

**The quadrature order was pinned at H = 61. It needs 7.**

| q | H=7 vs 61 | paired trace diff | verdict |
|---|---|---|---|
| 2 | **6.66x** | −0.00002 [−0.00005, +0.00001] | indistinguishable |
| 5 | **3.43x** | +0.00023 [−0.00024, +0.00070] | indistinguishable |

`gh` was 172 s against Laplace's 12.9 s; at H=7 it is ~25 s. **H = 5 is NOT safe as a default** — it
separates from 61 at q=5 (−0.00044 [−0.00084, −0.00004]).

**How to read the "DIFFERS" flag — use this, do not re-derive it.** At q=2 it fired on H=15 while
H=5 and H=7 passed: **non-monotonic in H ⇒ artifact** (nothing makes 15 nodes worse than 5). At q=5
it is **monotonic ⇒ real**. A genuine quadrature deficiency must be monotone in H.

**Why nobody found this:** the admitted set was `c(15, 25, 61)` — a typo-guard, not a numerical
constraint — and `R/va-routing.R` hard-wires the default, so no user could reach it. Now widened to
any odd H ≥ 3 (`e33151b3`), with moment-exactness asserted in tests.

---

## 3. THE SCIENCE — the attenuation belongs to the METHOD, not to either package

`E_q[log Φ(η)]` has **no closed form, and every cheap treatment of it attenuates**:

| treatment | who | trace (truth 1) |
|---|---|---|
| constant curvature −1 | our `ac` | 0.528 |
| Jaakkola–Jordan bound | our `jj` | 0.535 |
| exact-curvature 2nd order | **gllvm** | 0.587 |
| **full quadrature** | our `gh` | **1.025** (n=1000) |

**The discriminator:** vary the FAMILY, not the implementation. gllvm's parameterisation, KL,
optimiser and start count are **identical across its own gaussian and probit fits**, so a structural
cause would attenuate both. Measured: gaussian **1.0233** (expectation *exact*), probit **0.5868**.
Every structural confound eliminated at once. (Start count independently ruled out: `n.init` 1 and
4 both gave 0.6072.)

**So it is a property of second-order variational treatment of binary GLLVMs — not a gllvmTMB
defect and not a gllvm defect.** Gaussian and Poisson, where the expectation *is* closed-form
(`E[exp(η)] = exp(μ + v/2)`), are unbiased in both packages. Only quadrature escapes.

**Family exposure follows closed-form-ness exactly.** Gaussian/Poisson safe by mathematics.
Binomial and **nbinom2** exposed by it — NB2 reuses the *identical* softplus expectation as
binomial-logit and escapes only because its registry gives it `tiers = "gh"` alone. Tweedie, beta,
beta-binomial are **not in the VA engine** (family codes 0–4 only).
**The one shipped path taking a biased tier is `binomial-logit → jj`** (`R/va-routing.R:350`).

---

## 4. THE USER-FACING CONSEQUENCE — ICC and R² understated 10–44%

Probit fixes the residual variance at 1, so the shrinkage does **not** cancel in ratios against it:

| true Σ_jj | true ICC | estimated | error |
|---|---|---|---|
| 0.25 | 0.200 | 0.113 | **−44%** |
| 1.00 | 0.500 | 0.337 | **−33%** |
| 4.00 | 0.800 | 0.670 | −16% |

A conditional R² of 0.50 reports as **0.34**. Applies to `ac`, `jj` **and gllvm**. Ordination
(latent-r ≈ 0.86 for every tier) and correlation *patterns* survive.

---

## 5. OTHER RESULTS (all measured this session)

- **VA-Wald β intervals COVER** — first coverage score ever run, 30 seeds: gaussian **0.9483**,
  probit **0.9575**, nominal 0.95. **The sandwich is NOT the repair** — narrower (0.995), not
  wider, and marginally worse. Coverage succeeded where the estimate is unbiased, so **GH is the
  precondition for loading inference**, not merely the better option.
- **ψ does NOT absorb the attenuation.** With ψ verified genuinely free (20 parameters, `n_par`
  829 → 6849) both tiers estimate ψ̂ ≈ 0. The worst case — shared structure laundered into
  trait-specific noise — does not happen. *Scope: this DGP plants true ψ = 0.*
- **VA's free SEs cover z ONLY**, and only under GH (understates by 0.1–1.1%). β/Λ/ψ have no
  variational distribution; `calibrated` is hard-coded FALSE repo-wide.
- **`CppAD::CondExp` evaluates BOTH branches** — a threshold hybrid can never buy speed in TMB.
- **Laplace's cost is 22–39% `sdreport`, only 0.5–2.6% setup.** `se = FALSE` is a free 1.66–1.70x.
- **gllvm's speed edge is 1.40x at matched starts**, not 4.5x — ours ran `n_starts=4` against its
  default `n.init=1`. Its residual edge is warm-starting from a `num.lv=0` fit.

- **A closed-form (EVA-style) route is ~4.2x faster than GH even after the H fix** — measured on
  matched seeds, same cell, same `n_starts`:

  | arm | secs | trace | closed form? |
  |---|---|---|---|
  | `ac` | **5.5** | 0.6157 | **yes** |
  | `gh` H=7 | 23.2 | 1.3941 | no — quadrature |
  | `gh` H=61 | 163.2 | 1.3942 | no — quadrature |

  ⚠ **I earlier wrote in this repo's dev-log that EVA's speed advantage "evaporates". THAT WAS
  WRONG** — it came from timing the `ac2` **hybrid**, which *contains* quadrature and pays for it
  at every threshold because `CondExp` evaluates both branches. That measured the hybrid's flaw,
  not a closed form's speed. **The literature's position is correct: avoiding quadrature entirely
  beats making quadrature cheap.** H=7 narrows the gap from ~30x to ~4.2x; it does not close it.

  **But EVA's ACCURACY is implementation-sensitive in a way we do not understand.** Two
  exact-curvature second-order routes land in very different places: gllvm's at trace **0.587**
  (attenuated) and our `ac2` at **1.197** (overshooting), against a truth of 1.0. That is why
  `dr21` calls EVA a *fallback* and Design 108 makes GH primary — *"GH is the only tight route."*
  **Fastest, yes. Most reliable, not on this evidence.**

---

## 6. LANDING STATE

| item | state |
|---|---|
| `claude/va-ac-curvature` @ `5f055984`, 16 commits | ✅ **COMMITTED AND PUSHED**, verified via `git ls-remote` |
| `origin/main` | **PROTECTED** `5bf18ab3`. **No PR opened — that is the maintainer's act.** |
| **`claude/va-lane2` @ `7fd4fe19`** | 🔴 **CARRIED-OVER, UNPUSHED, CONTAINS A REGRESSION** (§1). Not mine. Do not merge. Resume/decide: maintainer only. |
| `dev/va-usability/raw/` | 🔶 **untracked BY DESIGN (D-50)** — simulation output stays local. **Never stage.** |
| ~285 unpushed commits on ~30 `agent/*` branches | 🔶 pre-existing, unrelated, not this session's. Left alone. |
| new engine surface | `eval_method = "ac2"` (internal, opt-in) + GH rule widened to odd H ≥ 3 |

**Verification at HEAD:** `devtools::test(filter="va")` → **202 files, 1505 passed, 0 failed,
0 errors, 1 skipped**. `va_r3_probit_ac_expectation` byte-identical to `aba2d21e`;
`R/va-routing.R` untouched; `resolve("auto", probit)` still `gh` — **no default moved**.

---

## 7. LIVE ENVIRONMENT (Cursor does not inherit my shell)

```sh
cd /private/tmp/gllvmtmb-ac-curvature        # NOT the Dropbox checkout (D-112: 746 commits behind)
export NOT_CRAN=true                          # required, or VA tests skip
Rscript -e 'devtools::load_all("."); testthat::test_local(filter="va")'   # safe verify, ~10 min
```

- **R 4.6**, TMB, RcppEigen, `gllvm` 2.0.13 installed. CRAN gllvm source unpacked in the session
  scratchpad only — **not in the repo**.
- The VA template is **content-addressed by source md5**, so editing `inst/tmb/gllvmTMB_va_r3.cpp`
  automatically triggers a fresh build directory. No `rebuild = TRUE` gymnastics needed.
- **`Rscript --vanilla` implies `--no-environ`** — drop `--vanilla` or set `R_LIBS_USER`, else
  `library(gllvm)` fails.
- **Totoro** available (`ssh` ControlMaster, no Duo needed): **budget 50 cores, 150 max** — it is
  shared, do **not** size off its 384-core total. Results stay LOCAL (**D-50 — never GitHub Actions**).
- **NEVER STAGE:** `dev/va-usability/raw/`, `dev/va-speed/80-arcB0-*`, `inventory-analysis.txt`.

---

## 8. TRAPS THAT COST REAL TIME TODAY

- **`attenuation-lib.R` defaults `T0` (= p) to 8** — the width where every estimator collapses and
  comparisons discriminate nothing. Set `T0 <<- 20L` at **top level, before** `sim_cell`, and assert
  `nrow(b$d) == N0 * T0`.
- **A narrow probe returning nothing is not proof of nothing.** I grepped `"H = 15, H = 25"`; the
  assertion read `"15, H = 25, …"`; I reported "no test asserts it" and **broke the suite**. The
  check for *did I break a test* is **running the tests**.
- **All `dev/va-usability/` measurements are pinned to the current `ac` branch.** Change the engine
  and every ladder expires.
- **`Rscript -e` with nested quotes will fight you** — write the script to a file.
- **`nohup … &` inside a backgrounded call returns exit 0 immediately** — that is the launcher, not
  the job. Check the process table before reporting a run finished or dead.

---

## 9. 🎯 NEXT — OWED, in value order

1. **The warm start.** The last unexploited lever. gllvm's remaining 1.4–2.0x edge at matched starts
   comes entirely from warm-starting off a `num.lv = 0` fit. `.va_r3_fit_warm`
   (`R/va-r3-proto.R:1380`) already partly exists. Combined with H=7 it plausibly puts VA-GH
   **below** Laplace on binary. *Deliverable: matched-start timing before/after + VA suite green.*
2. **Re-measure closed-form vs GH at H=7 on matched seeds** and correct the EVA speed claim (§5).
3. **Expose `H` and `eval_method` via `gllvmTMBcontrol()`.** Additive and reversible; the accurate
   route is currently unreachable from the public API. **Maintainer has asked for this.** Default
   stays 61 unless the maintainer moves it; the evidence now supports 7.
4. **Literature re-sweep before ANY novelty claim.** `dr21` records VA-GH as *"a benchmark, not a
   competing production engine"* on **cost** grounds — grounds this arc removed. Test its named
   obstacles: cost scaling in q, and the large-m/small-n instability (m=40, n=50).
5. **`failed_variance_domain` at q=5 for EVERY H including 61** — pre-existing, unrelated to
   quadrature, and it means q=5 fits are rejected regardless of settings. Needs its own look.

**DO NOT:** merge anything to `main`; merge or propagate `va-lane2` @ `7fd4fe19`; move a default;
re-argue the scaling convention (§1); or re-chase the four refuted hypotheses in
`docs/dev-log/after-task/2026-08-05-va-attenuation-mechanism-refuted.md` §5.

---

## 10. WHERE THE FULL RECORD LIVES

- `docs/dev-log/handover/2026-08-05-claude-handover-FINAL-va-curvature-and-H.md` — the Claude-side
  technical handover, deeper than this one.
- `docs/dev-log/after-task/2026-08-05-va-attenuation-mechanism-refuted.md` — after-task. ⚠ **its
  TITLE is stale** (the refutation was withdrawn in `f4691ed2`); read §4b, §4b-bis and §13.
- `dev/va-usability/CONVENTION-SETTLED.md` — the scaling convention, with the full flip history.
- `dev/va-speed/GLLVM-VA-ALIGNMENT-TABLE.md` — symbolic ↔ our C++ ↔ gllvm's C++.
- `dev/va-usability/171-gllvm-internals-dispatch.md` — `gllvm(method="VA")` reaches `gllvm.TMB`,
  **not** `gllvm.VA`; the per-row fixed point is unreachable dead code in 2.0.13.
- Brain note: *"gllvmTMB VA — GH is the estimator, and its cost was a hard-wired quadrature order"*
  (verified retrievable).

**Six of my claims were retracted this session, every one caught by running something rather than
reasoning.** Trust the scripts over any prose here, including mine.

```text
Read AGENTS.md and docs/dev-log/handover/2026-08-05-cursor-handover.md. Run the handover rehydration steps, reconcile them with the current git state, then continue only the OWED Next Immediate Steps.
```
