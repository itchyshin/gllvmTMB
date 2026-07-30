# Claude → Claude handover — gaussian arm CLOSED; the pluralist route is non-gaussian

Date: 2026-07-30. Author: Claude. Target: **Claude** (same platform).
Predecessor: `docs/dev-log/handover/2026-07-30-claude-handover.md` (whose resume command is
**superseded** — see Gotchas #1).
Lane map (multi-lane repo): `docs/dev-log/handover/2026-07-25-active-lane-split.md`.

**You are picking up a lane whose current arc is finished.** Nothing is blocked on compute.
One decision is waiting on the maintainer.

## Mission control

| item | state |
|---|---|
| **`main`** | `a51ca881` |
| **this lane** | `claude/vgh-pluralism-20260730`, worktree `/private/tmp/gllvmtmb-vgh-pluralism`, **pushed, clean** |
| **PR** | [#840](https://github.com/itchyshin/gllvmTMB/pull/840) **OPEN** — retitled and rewritten to match its actual contents (20 files, +2189/−15) |
| **checks** | narrow VGH tests green: oracle 12/51, warmstart 7/19, pooled-phi 3/35 — all 0 fail / 0 error / 0 skip. **`devtools::check()` and full `test()` NOT run** |
| **shipped** | the same-objective re-scope; the collapse test (24 cells); the degeneracy-reachability negative result; three engine fixes; corrections to 5 surfaces |
| **next by leverage** | ① the maintainer's merge call on #840 ② VGH degeneracy at scale on the **non-gaussian** Totoro grid ③ the `ψ_j → 0` boundary |
| **fenced** | Codex lanes `codex/va-*`, `codex/hvt1-*`, `codex/design86-*`; and the **LA + AGHQ + ridge lane** — one finding is theirs, raised in `check-log.md`, not acted on |

## Landing State ledger

**LANDED:** everything this session produced — 12 commits, `193d035f` … `d80be326`, all pushed to
`origin/claude/vgh-pluralism-20260730`. Working tree clean.

**CARRIED-OVER (declared, not landed on `main`):** PR #840 is **open and deliberately not
self-merged**. `CLAUDE.md`'s self-merge allowance covers docs / dev-log / after-task / design
docs; this PR also touches `tests/` and the `dev/` prototype engine, which sits outside that list
though equally outside the high-risk set (no public exports, no API, no formula grammar, no
likelihood or TMB change; `R/` and `src/` are byte-identical to `main`). **The merge decision is
the maintainer's.** Resume by asking for it, not by merging.

**NOT MINE — do not land:** `handoff_gate.sh` reports unpushed commits on `missing-data-sim-impl`,
`missing-data-with-pigauto`, `page-sweep`, `remove-unique-family`, and three `worktree-agent-*`
branches. **None belong to this lane.** They are other sessions' state; leave them alone.

## Critical context

**The arm's premise was false, and that is the result.** On gaussian, Laplace is exact and the VGH
ELBO is exact, so **both engines optimise the same objective** — recorded in
`dev/vgh/vgh-bench.R:2-3` all along; nobody had drawn the consequence. Therefore:

- **"Which estimator is more accurate" is not well-posed on gaussian.** Same objective ⇒ same MLE.
  A request to "score recovery against known truth" to rank the engines there cannot be answered.
- **VGH's anti-degeneracy mechanism is switched off on gaussian.** The ELBO is `logLik − KL`; a
  tight bound means `KL = 0`, so the regulariser credited for VA's zero-degeneracy record
  contributes nothing.

**The strategic consequence, which is the durable output:** the pluralist "both engines plus an
honest gate" design has **no gaussian instance**. Build VGH properly for **binomial/Poisson**,
where the bound is loose and the 0/148-vs-50/148 degeneracy gap is real and untouched. **Do not
build VGH for gaussian** — that work has no target.

**Do NOT re-derive these** (all measured, all landed):

- `d_ll` collapses from median 9.96 to max **8.3e-07** once matched at 60 parameters; matched arms
  agree on recovery (0.1130 both), residual SD (0.9971 both) and `Σ_B` (~5e-05).
- `2·d_ll ~ χ²₁₉` fits the whole distribution at both n (KS p = 0.810 / 0.901; 0 of 24 cells
  significant). The bench's apparent growth of `d_ll` with n was an artifact of redrawing the
  truth per n — **excluded** at power 0.962.
- 59 gaussian fits: `max|Λ̂|` below each dataset's largest trait SD (max ratio 0.961). The gaussian
  marginal log-likelihood is **coercive in Λ** — derived, not inferred.
- The C-exact figure is **3.76e-13** at `tol = 1e-12`, not 1.3e-12; the old number was 70% stale-
  ELBO artifact. Always quote it with its tolerance.

## Two claims of mine that were RETRACTED — do not resurrect them

1. **"max |Λ̂| = 2.77 against the shipped absolute threshold of 6."** Invalid.
   `loading_absolute_thresh` is **binomial-gated** (`R/diagnose.R:464-471`) and never evaluates on
   a gaussian fit. An adversarial pass exceeded 6 five times (max 32.64) and reached 11.42 by
   *multiplying `Y` by 10*. Use the loading-to-trait-SD ratio instead.
2. **My charge that the 2026-07-29 docs committed a category error.** Wrong — they were correct on
   every point and even named this slice as the missing run. The stale "+6.2 to +10.0" range was
   accurate when written.

## Next immediate steps

1. **Ask the maintainer for the merge call on #840.** Its "🔴 Needs you" section lists all four
   asks. Do not self-merge.
2. **VGH degeneracy at scale — on the non-gaussian Totoro grid** (n 40–400, p 8–80, q 2/4, 10
   seeds). This is lane-brief slice 2 and is now the highest-leverage open arc: it sizes how much
   engine is worth building before anyone builds it. Compute → Totoro (≤100 cores); results stay
   local (D-50).
3. **The `ψ_j → 0` boundary**, if a gaussian degeneracy claim is ever needed. The likelihood is
   *not* coercive in ψ, and my entire reachability search was structurally blind to it (every fit
   used `unique = FALSE`, so no per-trait ψ existed). A 9-fit ψ-model spot check found nothing.
4. **Then** the `devtools::check()` / full-suite run that this session could not do cleanly.

## Gotchas / failed approaches

1. **🔴 A resume command is executable instruction, not prose.** The predecessor handover's
   command said *"note VGH FIXES rather than estimates the residual SD"*. That is true of
   `R/va-vgh.R::.vgh_fit()` (family `"gaussian_anchor"`) and **false** of
   `dev/vgh/vgh-engine.R::vgh_fit()` (family `"gaussian"`), which **estimates** per-trait `φ_j`.
   The predecessor's *predecessor* said `gaussian_anchor` correctly; compressing it to "VGH"
   inverted the fact, and I acted on it before reading the evidence. **Name engines exactly in a
   resume command, even at the cost of brevity.**
2. **`test-vgh-oracle.R` REQUIRES `devtools::load_all()`.** Against the installed package it
   errors **11 of 12** tests with `could not find function ".vgh_fit"` (internals are unexported).
   Trivially misread as a test failure — I nearly did.
3. **The "obvious" stale-ELBO fix is a trap.** Moving `prev <- e$value` above the break test makes
   the predicate compare a value to itself, so **every fit breaks at sweep 1** and `tol` goes
   inert (~70 ELBO units lost). Worse, `Beta` still matches to 2e-16 on an intercept-only fixture,
   so a spot check passes it. Use the `R/va-vgh.R:596` idiom.
4. **A metadata flag proves nothing about the math.** `expect_true(fit$phi_pool)` survived a
   deliberate break that inverted the behaviour it names. Assert values.
5. **Never analyse the collapse driver's console log.** It prints `d_ll_pooled` with `%+9.5f`,
   rounding a genuine ~1e-7 residual to `-0.00000`. Use `dev/vgh/gaussian-collapse-analyse.R`,
   which reads the CSV and documents the trap.
6. **When a ratio metric flags degeneracy, check the absolute magnitude.** `rel_frob` and
   `atten_F` both normalise by the truth, so a near-null Λ inflates them while the fit stays
   small — the flagged fits here had loadings *half* the size of the healthy ones.
7. **Two seeding defects in my own scripts, now documented:** `gaussian-collapse.R:69` does not
   seed on `n` (so 24 cells carry 12 truths), and `gaussian-degeneracy-reachability.R:29` does not
   seed on regime (so 36 fits are 6 streams reused six ways).
8. **`vgh_fit()` cannot be multi-started** — no start argument, deterministic eigendecomposition
   init. Verification needed a scratch start-injectable copy.
9. **Known open defect:** `vgh_fit()` has no input validation and no `$converged` field; NA/Inf in
   `Y` makes its per-unit guards refuse every step silently.

## How to resume

Read the after-task report first — it carries the full negative space and the four things that
went wrong: `docs/dev-log/after-task/2026-07-30-gaussian-arm-vgh-pluralism.md`.

```bash
cd /private/tmp/gllvmtmb-vgh-pluralism && claude "Rehydrate from docs/dev-log/after-task/2026-07-30-gaussian-arm-vgh-pluralism.md and docs/dev-log/handover/2026-07-30-claude-handover-gaussian-arm-closed.md. The gaussian arm is CLOSED — do not re-derive it, and note that on gaussian both engines optimise the SAME objective so accuracy is not a well-posed question there. PR #840 is open and awaiting the maintainer's merge call; ask, do not self-merge. Next arc by leverage: VGH degeneracy at scale on the NON-GAUSSIAN Totoro grid (lane-brief slice 2), which sizes how much engine is worth building. Compute on Totoro, results local per D-50."
```

Durable background in the brain: *VGH in gllvmTMB — the settled position* (now carrying the
**gaussian scope limit** on the KL-regularisation argument) · *Two runaway modes in GLLVM
loadings* · *Query the PHENOMENON, not the PLAN* · *Designing a degeneracy gate*.
