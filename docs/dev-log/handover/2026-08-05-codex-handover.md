# Handover to Codex — gllvmTMB VA lane: GH is the estimator, and its cost was a constant

**Author:** Claude Code (Fable 5), solo · **Target:** Codex, fresh session, **no chat inherited**
**Branch:** `claude/va-ac-curvature` @ **`c05cc27c`** — ✅ **PUSHED** to `origin`
**Worktree:** `/private/tmp/gllvmtmb-ac-curvature`
**`origin/main`:** `5bf18ab3` — untouched. **A verified merge exists but is UNPUSHED (§2).**

> `AGENTS.md` is your native rule file and overrides this document. The committed repository is
> authoritative; this file supersedes chat. **Classify every item below OWED / DONE / RETRACTED /
> PROTECTED against actual git state before acting.**

---

## 0. REHYDRATE (Codex-tuned)

```sh
bash ~/shinichi-brain/tools/lane_preflight.sh /private/tmp/gllvmtmb-ac-curvature
cd /private/tmp/gllvmtmb-ac-curvature && ./tools/check-push-traps.sh
git log --oneline -8 && git status --short && git fetch origin

export NOT_CRAN=true          # REQUIRED — without it every VA test silently SKIPS
Rscript dev/va-usability/170-gllvm-convention-arbiter.R    # 30 s — settles §3. RUN IT.
```

**Team:** `.codex/agents/*.toml` — 10 agents present (`tmb-engineer`, `simulation-tester`,
`reproducibility-engineer`, `systems-auditor`, `reviewer`, …). ⚠ **There is no `rose.toml`.**
`systems-auditor.toml` is the Rose role under this repo's mapping (`AGENTS.md` "Standing Review
Roles"); use it for the closeout audit.

⚠ **`lane_preflight.sh` checks for a CODEX lane and cannot see a second CLAUDE session.** Two
Claude sessions ran concurrently in this repo today and both committed. Also run
`git log --all --oneline --since="12 hours ago"`.

---

## 1. YOU RUN THE LIVE TOOLCHAIN — what is yours vs what was planning-side

Per the hub's division of labour, **Codex owns real fits, `R CMD check`, simulations and
rendering.** Everything below was measured on a 20-core Mac by Claude; **none of it has had
`devtools::check()` run against it.** That is the first thing that is yours.

```r
devtools::document()                       # already run; man/gllvmTMBcontrol.Rd regenerated
devtools::test()                           # VA subset verified: 207 files, 1538 pass, 0 fail
devtools::check(args = "--no-manual")      # 🔴 NOT RUN THIS SESSION — OWED, see §6
pkgdown::check_pkgdown()                   # 🔴 NOT RUN — the roxygen change touches an exported fn
```

**Compute:** **Totoro** reachable via the standing `ssh` ControlMaster, no Duo needed —
**budget 50 cores, 150 maximum** (shared; do not size off its 384-core total). Results stay
**LOCAL** — **D-50: never GitHub Actions, never as Actions artifacts.**

---

## 2. 🔴 THE ONE OUTSTANDING ACTION — a verified merge that could not be pushed

The maintainer approved merging **only** `claude/va-ac-curvature` into `main`. I performed it and
**verified it needs no re-test**, but the push was **blocked by a permission gate** and I did not
work around it.

- Merge commit **`e3b09139`** lives in a detached worktree `/private/tmp/gllvmtmb-merge`.
- **It is not pointed at by any branch** — treat it as disposable, not as state.
- Why no re-test was needed: `origin/main` was already an **ancestor** of the branch, and the
  merged tree hash **`c82f3219`** is **byte-identical** to the branch tree that the suite
  certified green.

**Do not try to recover `e3b09139`.** Redo the merge cleanly:

```sh
cd "/Users/z3437171/Dropbox/Github Local/gllvmTMB"
git stash push -u -m "uinit-2026-08-05-parked"     # see §4 FIRST — this tree is dirty
git fetch origin && git merge --ff-only origin/main
git merge --no-ff origin/claude/va-ac-curvature
git push origin main
```

⚠ **Local `main` is 29 commits BEHIND `origin/main`, 0 ahead** — the `--ff-only` step is what
stops you merging into a stale base. Repo rules make merging the maintainer's act; **confirm
before pushing `main`.**

---

## 3. 🔴 TWO LANES DISAGREE — one is wrong, and the trap is subtle

**`claude/va-lane2` @ `7fd4fe19` contains a REGRESSION** — *"stop folding sigma.lv into gllvm
loadings; quarantine the bad CSV rows"* (unpushed, authored by the other Claude session).
**Do not merge or propagate it.**

**Correct: `Λ = theta %*% diag(sigma.lv)`.** Two proofs
(`dev/va-usability/170-gllvm-convention-arbiter.R`):

1. gllvm's `theta` has its diagonal pinned at **exactly 1** — an identifiability constraint. **A
   loading matrix with a fixed unit diagonal cannot carry loading magnitude.**
2. Reconstruct **gllvm's own linear predictor**: raw `theta` is off by **4.78e-01**;
   `theta %*% diag(sigma.lv)` matches to **4.44e-16**.

⚠ **THE TRAP.** The regression cites `eta_var` as "convention-free" evidence. **It is not.**
`eta_var = var(U %*% t(L))` is computed *from* the convention under test, so both conventions
yield one and it cannot arbitrate. Only reproducing gllvm's own arithmetic can. **This convention
has flipped three times on argument.** Full history: `dev/va-usability/CONVENTION-SETTLED.md`.
**Do not re-argue it — re-run the arbiter.**

---

## 4. 🔴 THE DROPBOX CHECKOUT IS DIRTY AND PROTECTED

`/Users/z3437171/Dropbox/Github Local/gllvmTMB` is **D-112 PROTECTED** (746 commits behind on its
feature branches; never build or edit there). An `ultra-init` run left it dirty **on `main`**:

- `docs/dev-log/coordination-board.md`: **991 committed lines → 10 in the working tree** (995
  deleted). The coordination board is the **cross-team message bus** — it carries Codex↔Claude
  traffic. Do not let that truncation land.
- Also dirty: `AGENTS.md`, `CLAUDE.md`, `.gitignore`, **10 `.codex/agents/*.toml`**, plus an
  untracked `.codex/agents/tiers.tsv`.

**All uncommitted, so all recoverable.** Park it before touching that checkout:
`git stash push -u -m "uinit-2026-08-05-parked"`. Whether to re-apply the doctrine refresh is the
maintainer's call; if re-run, it belongs on a **fresh worktree off `origin/main`**, on its own
branch, with the board **merged, never replaced**.

---

## 5. WHAT LANDED — the science, all measured

**HEADLINE: GH's cost was a hard-wired constant.** The quadrature order was pinned at `H = 61`
with an admitted set of `{15, 25, 61}` — a typo-guard, not a numerical constraint — and
unreachable from the public route.

| q | H=7 vs 61 | paired trace diff | verdict |
|---|---|---|---|
| 2 | **6.66x** | −0.00002 [−0.00005, +0.00001] | indistinguishable |
| 5 | **3.43x** | +0.00023 [−0.00024, +0.00070] | indistinguishable |

**H = 5 is NOT safe** — it separates at q=5 (−0.00044 [−0.00084, −0.00004]).
**Reading the "DIFFERS" flag:** at q=2 it fired on H=15 while 5 and 7 passed — **non-monotonic in
H ⇒ artifact**. At q=5 it is **monotonic ⇒ real**. A genuine quadrature deficiency must be
monotone in H. *(Do not re-derive this.)*

**THE MECHANISM: the attenuation belongs to the METHOD, not to either package.**
`E_q[log Φ(η)]` has no closed form and every cheap treatment attenuates — our constant curvature
(0.528), the JJ bound (0.535), gllvm's exact-curvature expansion (0.587). Only quadrature escapes
(**1.025** at n=1000). **Discriminator: vary the FAMILY, not the implementation.** gllvm's
parameterisation, KL, optimiser and starts are identical across its own gaussian and probit fits;
measured **gaussian 1.0233 / probit 0.5868**. Every structural confound cancels at once.

**FAMILY EXPOSURE follows closed-form-ness exactly.** Gaussian and Poisson safe by mathematics
(`E[exp(η)] = exp(μ+v/2)`). Binomial and **nbinom2** exposed by it — NB2 reuses the *identical*
softplus expectation and escapes only because its registry gives it `tiers = "gh"` alone. Tweedie,
beta, beta-binomial are **not in the VA engine** (family codes 0–4). **The one shipped path taking
a biased tier is `binomial-logit → jj`.**

**USER-FACING CONSEQUENCE: ICC and R² understated 10–44%.** Probit fixes the residual variance at
1, so shrinkage does not cancel in ratios against it — a conditional R² of 0.50 reports as
**0.34**. Applies to `ac`, `jj` **and gllvm**. Ordination (latent-r ≈ 0.86 every tier) and
correlation patterns survive.

**Also measured:** VA-Wald β intervals **cover** (0.9483 gaussian / 0.9575 probit, 30 seeds) and
the **sandwich is not the repair** (narrower, marginally worse). **ψ does not absorb** the
attenuation (ψ verified genuinely free: `n_par` 829 → 6849; both tiers give ψ̂ ≈ 0). A
**closed-form route is ~4.2x faster than GH even at H=7** (`ac` 5.5 s / `gh` H=7 23.2 s / `gh`
H=61 163.2 s) — so **EVA really is the fast option**; I earlier wrote the opposite in this
dev-log and that was **WRONG** (it timed the `ac2` *hybrid*, which contains quadrature).

**NEW PUBLIC SURFACE (additive, default-preserving):** `gllvmTMBcontrol()` gains **`va_H`** (odd
≥ 3, default 61) and **`va_eval_method`** (`auto`/`jj`/`gh`, default `auto` = the previous
hard-wire exactly). Verified end to end through the real API: `auto`→jj 20.8 s; `gh`→42.9 s;
`gh` + `va_H=7` → **6.6 s**, i.e. the accurate tier beats the biased default.

---

## 6. 🎯 OWED — in value order, and most of it is yours

1. **`devtools::check(args = "--no-manual")` + `pkgdown::check_pkgdown()`** on this branch.
   **Never run against these changes.** The roxygen touched an exported function, so both are
   live risks. **Do this before the §2 merge if you can.**
2. **The warm start.** The last unexploited speed lever. gllvm's residual 1.4–2.0x edge at
   matched starts comes entirely from warm-starting off a `num.lv = 0` fit;
   `.va_r3_fit_warm` (`R/va-r3-proto.R:1380`) already partly exists. With H=7 it plausibly puts
   VA-GH **below** Laplace on binary. *Deliverable: matched-start timing before/after, VA suite green.*
3. **Decide the `va_H` default.** Evidence supports 7 at q ∈ {2,5}, probit, p=20. **Maintainer's
   call**; extend the ladder to another link/family first if you want it wider.
4. **Literature re-sweep before ANY novelty claim.** `dr21` records VA-GH as *"a benchmark, not a
   competing production engine"* on **cost** grounds — grounds this arc removed. Test its named
   obstacles: cost scaling in q, and large-m/small-n instability (m=40, n=50).
5. **`failed_variance_domain` at q=5 for EVERY H including 61** — pre-existing, unrelated to
   quadrature, means q=5 fits are rejected regardless of settings. Needs its own look.

**DO NOT:** merge or propagate `va-lane2` @ `7fd4fe19` (§3); re-argue the scaling convention;
move a default without the maintainer; re-chase the four refuted hypotheses in
`docs/dev-log/after-task/2026-08-05-va-attenuation-mechanism-refuted.md` §5.

---

## 7. TRAPS THAT COST REAL TIME TODAY

- **`attenuation-lib.R` defaults `T0` (= p) to 8** — the width where every estimator collapses
  and comparisons discriminate nothing. Set `T0 <<- 20L` at **top level before** `sim_cell`, and
  assert `nrow(b$d) == N0 * T0`.
- **A narrow probe returning nothing is not proof of nothing.** I grepped `"H = 15, H = 25"`; the
  assertion read `"15, H = 25, …"`; I reported "no test asserts it" and **broke the suite**. The
  check for *did I break a test* is running the tests.
- **`CppAD::CondExp` evaluates BOTH branches** — a threshold hybrid can never buy speed in TMB.
- **The VA template is content-addressed by source md5** — editing `inst/tmb/gllvmTMB_va_r3.cpp`
  gets a fresh build dir automatically; no `rebuild = TRUE` needed.
- **`Rscript --vanilla` implies `--no-environ`** — drop it or set `R_LIBS_USER`, else
  `library(gllvm)` fails.
- **All `dev/va-usability/` measurements are pinned to the current `ac` branch** — change the
  engine and every ladder expires.
- **NEVER STAGE:** `dev/va-usability/raw/` (D-50, simulation output stays local),
  `dev/va-speed/80-arcB0-*`, `inventory-analysis.txt`.

---

## 8. FULL RECORD

- `docs/dev-log/handover/2026-08-05-claude-handover-FINAL-va-curvature-and-H.md` — deepest technical account.
- `docs/dev-log/handover/2026-08-05-cursor-handover.md` — sibling handover, same facts.
- `docs/dev-log/after-task/2026-08-05-va-attenuation-mechanism-refuted.md` — ⚠ **TITLE IS STALE**
  (the refutation was withdrawn in `f4691ed2`); read §4b, §4b-bis, §13.
- `dev/va-usability/CONVENTION-SETTLED.md` · `dev/va-speed/GLLVM-VA-ALIGNMENT-TABLE.md` ·
  `dev/va-usability/171-gllvm-internals-dispatch.md` (gllvm's live VA path is `gllvm.TMB`, **not**
  `gllvm.VA`; the per-row fixed point is unreachable dead code in 2.0.13).

**Six of my claims were retracted this session, every one caught by running something rather than
reasoning about it.** Trust the scripts over any prose here, including mine.

```text
Read AGENTS.md and docs/dev-log/handover/2026-08-05-codex-handover.md. Run the handover rehydration steps, reconcile them with the current git state, then continue only the OWED Next Immediate Steps.
```
