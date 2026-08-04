# Session Handoff: arcs F/A/D/E landed, the silent-NA defect closed — and three of my own claims retracted

**Meta:** 2026-08-04 · Claude Code (solo) → Claude · fresh context required
**Branch:** `claude/va-lane2` @ `62e5e8d4` — **NOT pushed**
**Worktree:** `/private/tmp/gllvmtmb-va-lane2` · 60 commits off `origin/main` @ `5bf18ab3`

> **Supersedes** `2026-08-04-claude-handover-arcs-f-a-done.md`.

## State

| Arc | State |
|---|---|
| **F** push-trap guard | ✅ done, negative-controlled (`9d560616`) |
| **A** lazy `sdreport()` | ✅ done, bit-exact (`29d7db7e`) |
| **silent-NA** (spin-off) | ✅ done + **corrected twice** (`0a280205`, `bf2226ba`, `258ec3b3`) |
| **D** cheap speed levers | ✅ done — scope was wrong; one real lever, ~1.1× (`9055c485`) |
| **E** gllvm head-to-head | ✅ done — claim 30 settled, **mostly against us** (`dde30a61`) |
| **B** sandwich scoring | ⛔ still blocked (spec defect + a decision) |
| **C** ordinal | deferred to a ~45-min probe |

## 🔴 Three claims I made and retracted this session

**Read this before citing anything below.** All three were caught by measurement or by a fresh
reviewer, not by me re-reading my own work.

1. **An Arc B compute estimate** (~13 core-hours) derived from per-fit seconds whose status column
   read `failed_health_gate` **9/9** at 1–2 iterations. Withdrawn before it reached a plan.
2. **A test that could not fail.** `test-standard-errors.R` claimed to prove the `sdreport`
   state-replay was load-bearing. Three measured arms are bit-identical: `sdreport()` reads
   `last.par.best`, and `obj$fn()` does not move it. Comment and test rewritten to claim only what
   was measured.
3. **A false closure claim, published.** NEWS and the register said `confint()` no longer returns
   an unmarked NA matrix. `.confint_wald_targets()` returns **nineteen lines before** the guard and
   swallowed a NULL `sd_report` into `NA_real_` — so `confint(parm = "sigma_eps", method = "wald")`
   still returned a silent all-NA interval for 7 of 7 non-`b_fix` targets. Found by the
   **adversarial reviewer**, fixed in `bf2226ba`. **This is the strongest argument in the session
   for keeping the fresh-agent panel: a self-check would not have found it.**

## What the silent-NA work actually closes

`confint(method = "wald")` aborts on **both** Wald routes (`gllvmTMB_confint_no_sdreport`), naming
`fit <- standard_errors(fit)` **and** `method = "profile"` — the latter verified to work, not just
offered. `summary()` and `extract_cutpoints()` keep working and **say why** the SE column is empty.

**Scope, stated honestly:** the gate keys on `sd_report` being **missing**, not on the SEs being
**usable**. A non-positive-definite Hessian still yields bare `NaN`, unexplained. Register row
**EXT-36 is `partial`**, not `covered`. That is the next obvious follow-on.

**The main regression risk is guarded:** a mapped-out `Xcoef_fixed` coefficient still returns `NA`
**silently** — a fixed parameter legitimately has no SE, and flattening that into the defect class
was how this change could have done harm. Explicitly tested.

## Arc D — the scope was the finding

**Four of the five "cheap untested levers" are not reachable.** `sdreport` knobs, `multiphase`, and
`optimHess` polish have **zero presence in `R/`**; gllvm's `inner.control` is a comparator's knob.
Only `nlminb(scale=)` is plumbed (`R/fit-multi.R:5196`). Measured: `scale = 10` ≈ **1.10–1.13×**
faster, both controls passing, estimates unmoved, 3/3 converged everywhere.
⚠ **Arms were not interleaved** — direction stands, **magnitude is soft**. Nothing promoted.

## Arc E — claim 30 is settled, and the answer is uncomfortable

12 seeds, paired per-seed (the medians overlap ~0.15–0.49 across every arm and would have misled —
which is exactly what killed the 1-seed and 6-seed attempts):

- **ours-GH beats gllvm-VA on accuracy 11 of 12** — a real, narrow, properly-powered win
- **ours-AC beats gllvm-VA 6 of 12 — a coin flip**, and it destroys ψ (0.0002 vs a planted 0.6,
  where GH recovers 0.5417)
- **speed: 0 of 12 on every comparison**, gllvm 10–50× faster

**Claim 30 stays NOT ESTABLISHED.** The defensible sentence is *"our GH tier is more accurate than
gllvm's VA on this cell"*. ⚠ **The speed line is regime-bound:** N=120 sits far below the measured
VA-vs-LA crossover (~N≈2500), so it does **not** settle large-N, where our VA's case always lay.

## Verification state

- Full suite for arcs F+A: **371 files, 9236 pass, 0 fail** ✅
- **A clean full run at `258ec3b3` was in flight at handover time — CHECK IT.** Two earlier runs
  reported failures that were **artefacts**: those sessions `load_all()`-ed pre-fix code and then
  read post-fix test files from disk. Narrow suite is **31/31**.
- ⚠ **Do not edit `R/` or `tests/` while a full suite runs** — that is what produced the artefacts.

## Unmerged work — needs integration

**`worktree-agent-a1ea2c74dc077c425` @ `e57258ca`**, based on `0a280205`, **not merged**:
`.wald_block()` **confirmed dead** by five checks (including `git log -S` across full history — it
was never called from the moment it was written); marked, not deleted. And **28 of 33 checkable
rows in `dev/aghq-scope/06-consumers.md` were stale** — I had flagged one. Includes a fabricated
caller name and a function that never existed. Tests: 0 fail, 523 pass. **Merge it.**

## Open, needing Shinichi

1. **Totoro core budget.** You authorised **150** on 2026-08-03, but `COMPUTE-PLAYBOOK.md:33/36`
   and the per-repo `AGENTS.md` files still say **≤100**. The note had been invisible for a day
   (filed into the symbolizer repo by the MCP routing bug; recovered to the vault this session).
   In `OPEN_QUESTIONS`, not reconciled unilaterally.
2. **D-113 priority.** The primary post-0.6 slice on record is **missing-data #332**. None of
   arcs A/B/D/E/F is one of the six 0.7 tracks.
3. **Arc B's arm.** `gaussian_anchor` has `tiers = "gh"` only, so "score under both `eval_method`s"
   is unsatisfiable on the Gaussian primary cells. (a) binomial-probit DGP, (b) family-conditional
   — recommended, or (c) two comparisons.

## Also open, recorded

`vcov.gllvmTMB` does not exist despite roxygen at `R/gllvmTMB.R:295` claiming it dispatches ·
non-finite SEs (non-PD Hessian) still surface as bare `NaN` · the other ~20 files containing
`rep(NA_real_, …)` were never swept for the same class.

## Live environment

```sh
WT=/private/tmp/gllvmtmb-va-lane2     # git worktree add "$WT" claude/va-lane2
export NOT_CRAN=true
ssh -o BatchMode=yes totoro           # 384 cores, R 4.5.3, gllvmTMB+gllvm installed
#   lane ~/gllvm_work/va-lane2 · OPENBLAS_NUM_THREADS=1 per worker
#   ⚠ Rscript --vanilla implies --no-environ -> pass R_LIBS_USER=$HOME/R/lib or library(gllvm) fails
```

⚠ `/private/tmp` has been cleaned mid-session before. **Commit at every boundary.**
**Push trap is closed** — `claude/va-lane2` tracks `origin/claude/va-lane2`; `tools/check-push-traps.sh`
enforces it repo-wide. Still confirm with `git rev-parse --abbrev-ref claude/va-lane2@{upstream}`.

## How to resume

```sh
bash ~/shinichi-brain/tools/lane_preflight.sh /private/tmp/gllvmtmb-va-lane2
cd /private/tmp/gllvmtmb-va-lane2 && ./tools/check-push-traps.sh && git log --oneline -8
```

Read: this file → `dev/va-speed/67-ARC-E-RESULT.md` → `65-ARC-D-RESULT.md` →
`dev/va-speed/20-CLAIMS-LEDGER.md` (**check status before citing anything**; rows 30 and 46 both
carry verdicts written this session).

---

# UPDATE — later the same day: three decisions taken, deferred work closed

**Branch now:** `claude/va-lane2` @ `6dd1914f` · **still NOT pushed**

## Shinichi's three answers, and what they changed

| # | question | answer | done |
|---|---|---|---|
| 1 | Totoro core budget | **"150 is fine"** — standing default | ✅ reconciled across the vault |
| 2 | Does this lane precede missing-data #332? | **"not necessarily"** | ✅ recorded on the campaign design note |
| 3 | Arc B's arm defect | **"please fix this"** | ✅ family-conditional |

**1 — Totoro 150.** Updated hub `AGENTS.md` §Compute, `projects/COMPUTE-PLAYBOOK.md`,
`tools/totoro-setup.md` (its worked example moved 96 → 144 workers — a stale example is how a
raised cap quietly goes unused), and the **eight `projects/<repo>.md` LOAD-FIRST sources** that
`route.py` generates the per-repo manifests from. `route.py` now emits 150 for all eight.
⚠ **Residual drift:** seven per-repo `AGENTS.md` copies still carry ≤100. `route.py` has **no write
mode** and those are other lanes' repos — each refreshes its own; `route.py <repo> --check` detects it.

**2 — priority.** Recorded on `docs/design/va-interval-route-selection.md` beside the approval:
the campaign is **unblocked, not prioritised**. D-113 still names #332 primary.

**3 — Arc B unblocked.** The "score under both `eval_method`s" requirement was unsatisfiable
(`gaussian_anchor` has `tiers = "gh"` only). Now **family-conditional**: Gaussian primary cells on
`gh` alone, keeping them comparable to the 0.897/0.935 pilot; AC-vs-GH on a `binomial_probit` cell,
reported as a **separate claim about a different family**. Moving the primary DGP was rejected — it
would change the cell underneath the pilot numbers, the exact substitution behind this lane's
retractions. **Arc B is now runnable**; open it with a timed pilot on health-gate-passing fits.

## Deferred work, closed

- **EXT-36 `partial` → `covered`.** The non-finite-SE carve-out is closed: `summary()` reports it
  and `confint()` aborts (`gllvmTMB_confint_nonfinite_se`), with **different advice** —
  `standard_errors()` cannot help a non-positive-definite Hessian, so it points at
  `gllvmTMB_diagnose()`. Both surfaces done together on purpose. **Discriminator is ALL-non-finite,
  not any** — a single `NA` is the legitimate mapped-out-coefficient case, with inverse guards.
- **Arc D's caveat discharged.** Re-run interleaved + order-rotated: **10/10 cells**, 1.11–1.13×,
  null control passing throughout. And one of my own claims **tightened**: "identical log-likelihood"
  rested on a relative-tolerance gate; exact comparison shows 1.5e-07 worst difference (~8e-11
  relative). Optimiser noise, not a different answer — but **not bit-exact**, unlike the `se = FALSE`
  bootstrap speedups which really did pass `all.equal(tol = 0)`.
- **`vcov` gap — bigger than flagged.** `coef()` is *also* missing for `gllvmTMB_multi`, and **no
  method is registered on the bare `gllvmTMB` class at all**, so the roxygen's premise was wrong even
  where its examples were right. **Documentation corrected; the methods were NOT added** — new
  exported S3 methods are an API change and this repo's rule is to raise those. `vcov` is ~10 lines
  (`sd_report$cov.fixed` with names) if approved.
- **Silent-NA sweep — 0 new sites.** ⚠ **The dispatched sweep was INVALID and is recorded as such:**
  it cited only paths in the protected Dropbox checkout (a different branch, **76 files apart**) and
  never wrote its artefact. Redone by hand on the real tree: 21 `error = function(e) NA` sites,
  classified, none a new defect. Scope stated on the page — one probe pattern, `R/` only.

## In flight at write time — CHECK BOTH

- **Arc C feasibility probe** (Totoro, 15 cells): does AC's ψ-collapse depend on information per
  observation? Sweeping `n_trials ∈ {2,4,6,12,20}` at `psi_true = 0.6` as a **proxy**, because the
  literal question is unmeasurable — ordinal VA is family code 5 and is not built. Early signal:
  at `n_trials = 2`, AC ψ = **0.0000** vs truth 0.6 while GH recovers 0.4766.
- **Final full suite** at `d80f308e`. Last clean run was `258ec3b3`: **371 files / 9257 / 0 fail**.

## Still open

`vcov()` / `coef()` for `gllvmTMB_multi` (approval needed) · seven per-repo `AGENTS.md` core-count
refreshes · Arc B itself (now unblocked) · Arc C as a **build** (the probe only sizes it) ·
**nothing pushed**.
