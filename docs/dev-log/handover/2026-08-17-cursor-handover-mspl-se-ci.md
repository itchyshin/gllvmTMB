# Handover → Cursor (MSPL SE/CI lane, all families incl. Poisson)

**Date:** 2026-08-17 · **From:** Claude, `claude/mspl-interval-computable-pin` (lane CLOSED, work
landed) · **To:** Cursor, the MSPL SE/CI-across-families lane
**`main` at handover:** `d22369a3` · **Nothing carried over — this lane has no unlanded work.**

You do not inherit my chat. This document plus the repo is the state.

---

## 1. Why you are getting this

You are implementing SE/CI across the non-binomial MSPL families. This sitting produced **one
verified finding that constrains that work**, and **one landed instrument you should know exists so
you do not rebuild it**. Neither changes your SE (\(Q_0\)) work; both change what may be *claimed*
about intervals.

## 2. 🔴 The finding: profiling does NOT escape the coverage failure — VERIFIED

The question your lane's own research note left open (*"the warning may hold even for profiles.
Verify against the PDF before anyone designs an MSPL interval"*) is now **settled: it does.**

Kosmidis & Firth (2021), *Biometrika* 108(1):71–82, arXiv:1812.01938 v4, **§2.2, p. 5**, read
directly (not from a snippet):

> "…the usual Wald-type confidence intervals \(\tilde\beta_t \pm z_{1-\alpha/2}s_t(\tilde\beta)\),
> **or confidence regions in general, will fail to cover regardless of the nominal level \(\alpha\)**
> that is used… **and it is also true when the penalized likelihood is profiled for the construction
> of confidence intervals**" (citing Heinze & Schemper 2002; Bull et al. 2007; Kosmidis 2014).

**The mechanism matters more than the sentence**, because it rules out the obvious workaround. This
is *not* a quadratic-approximation artefact — which is the one failure mode profiling repairs. With
binomial responses the penalised estimator takes only **finitely many values, each with finite
components** (their Corollary 1), while the true parameter is unbounded. So for \(\beta\) with large
enough components, **no** interval built from that estimator reaches it, at any \(\alpha\).
Profiling changes the interval's *shape*, not the boundedness of what it is built from.

Full note with quotes, scope and qualifications:
`docs/dev-log/research/2026-08-17-kosmidis-firth-2021-profile-caveat.md`.

### 2a. What this forbids

- **Do not** build a profile-CI *claim* path for MSPL on the premise that profiling repairs Wald
  undercoverage. The authors of the penalty you are using say it does not.
- **Do not** treat "profile of the penalised objective" as already calibrated.
- `#1075`'s *"profile = signature / primary claim path"* needs an **MSPL footnote**. D-12's
  profile-over-Wald doctrine stands generally and for ML; what does not stand is the inference that
  profiling rescues coverage under a finiteness penalty.

### 2b. What it does NOT forbid — read this before over-correcting

- **Your SE work is untouched.** The caveat is about *interval coverage*. \(Q_0\) remains the
  paper-aligned SE reporting target (D-149, #1061), and `R/mspl-curvature-pin.R` is unaffected.
- **It does not forbid an internal, uncalibrated interval *computer*.** Computability and coverage
  are different claims — the distinction D-149 encodes as *"pins ≠ public intervals"*. What it
  forbids is calling such endpoints a confidence interval.

### 2c. ⚠ Scope — what you may NOT cite this paper for

The paper is **binomial-response GLMs with full-rank \(X\)**; links logit, probit, c-log-log,
log-log, cauchit (their Table 1). Therefore:

- **NOT citable** for **Gamma, lognormal, Student, Tweedie, ordinal_probit, delta/hurdle, nbinom** —
  i.e. most of your surface. For those families the profile question is **open**, not settled in
  either direction, and the honest label is **UNVERIFIED**.
- Its standing is an **authors' assertion supported by citation**, not a theorem proved there
  (Thm 1/Cor 1 = finiteness; Thm 2 = shrinkage). Cite it as such.
- Transfer to a **latent-variable GLLVM** (our actual setting — Laplace-approximated marginal
  likelihood, not a fixed-design GLM) is **AGENT-INFERRED, not established**. Plausible; unproven.

## 3. What landed on `main` that you should not rebuild

`#1090` (merged, `d22369a3`) added to `R/mspl.R`, **internal and unexported**:

- `.gllvmTMB_mspl_profile_feasibility()` — fixes a `b_fix` coordinate, re-optimises nuisance
  parameters against the **penalised** LA-MSPL tape, grid-walks, brackets the χ²₁ threshold,
  bisects. Typed per-side statuses.
- `.gllvmTMB_mspl_profile_threshold_diagnostic()`
- `.gllvmTMB_mspl_nlminb()` (mock seam for tests)

Re-ported from `claude/mspl-b0-prereqs` (#981), **R-side only — no `src/` change**; the
`mspl_c_n_multiplier` hook is *not* needed (they read only `obj$env$data$estimator_id`, and main's
C++ already computes `mspl_c_n` equivalently to multiplier 1.0). **#981 stays open for its own
`src/` work — do not close it.**

**Three things about it that bear on your lane:**

1. **It is a computability probe, not an interval.** `calibrated = FALSE`,
   `public_confint = "refused"`, `coverage_claim = "none"` are literal tested fields; endpoints are
   named `*_endpoint` / `diagnostic_*` and never `conf.low`/`conf.high`, with a test asserting those
   names are absent. Public `confint()`/`vcov()`/`se = TRUE` still refuse. `MSPL-04` stays `blocked`.
2. **It is fenced to binomial** (logit/probit/cloglog) with an enforced allow-list and typed abort
   `gllvmTMB_mspl_profile_family` — deliberately, because the cited authority is binomial-only (§2c).
   **If you want it for Poisson or another family, that is a scope decision with no evidence behind
   it yet, not a one-line fence edit.**
3. **It profiles the penalised tape only** (hard-refused otherwise). In Design 125's terms it
   implements **fork A** and structurally cannot run fork B (`unpenalized_tmb_obj`) or C. Landing it
   did **not** pick that fork; the G0 record says so explicitly
   (`docs/dev-log/decisions.md`, 2026-08-17 entry).

The **admission gate** (softness ratio / N2′ curvature / separation) is deliberately **absent** — it
belongs to the parked calibrated construction (D-157), not to a probe.

## 4. 🔴 The Poisson G0 is still UNSIGNED and it gates your lane

`docs/dev-log/research/2026-08-17-mspl-poisson-W-G0.md` — **Status: UNSIGNED**, three paste lines
(KEEP / REPLACE \(W_*\) / PARK SE doors). Filed as #1076.

**Why it blocks you:** the same sitting's Design 125 kit signed **G1 PARK SE doors** — new
SE-series doors are frozen until this G0 resolves. That is why Gamma, lognormal, Student,
ordinal_probit, delta_lognormal, delta_gamma and Tweedie sit as `skip`s reading *"family door is
missing"* in `test-zz-mspl-rest-families-se-feasibility.R`.

**The measurement, from #1064** (`docs/dev-log/after-task/2026-08-16-mspl-W-onesided-audit.md`): the
live Poisson MSPL tape still uses GLM-outer \(W=\operatorname{diag}(\mu)\) — `src/gllvmTMB.cpp` still
`return eta`. On a toy cell Poisson \(P_J\) rises **+4 per +4** in the intercept (−6.84 at
\(\beta_0=-8\), +9.16 at +8), i.e. the soft Jeffreys atom is **one-sided and rewards \(+\infty\)**,
while the working \(W_*\) is **symmetric** (−6.84 at both ends). nbinom2 saturates naturally
(\(W/\varphi \to 1\)). Tweedie's live tape **already** uses `gll_mspl_log_weight(eta, 0)`.

**My recommendation (not a decision — it is Shinichi's):** **REPLACE**, following the Tweedie
precedent. Pinning curvature on an atom whose estimator's *existence* is open is weak ground. But it
is a `src/` likelihood change, so AGENTS.md rule 4 pulls in `tmb-likelihood-review`, Gauss + Noether,
a `03-likelihoods.md` update, and simulation recovery — budget most of a day, and note that #1064's
oracles W2/W7 currently **pin `return eta` by design** and will need rewriting with it.

⚠ **History worth knowing:** the Poisson W card was accidentally marked SIGNED and Rose retracted it
twice (`claude/lane-mspl-profile-led-ci`, commits "retract invented Poisson W SIGNED PARK",
"restore Poisson W UNSIGNED after SIGNED fight"). **Confirm its Status line in the file before acting
on any claim that it is signed.**

## 5. Your open PRs, and one collision to watch

| PR | Branch | Note |
|---|---|---|
| #1077 | `cursor/mspl-profile-ci-scaffold` | Fenced profile-CI scaffold, still draft. Its `profile$status = "not_constructed"` and *"Profile bounds are not computed while Design G0 is open"* are now **partly stale**: bounds *can* be computed on `main` for binomial via §3. Reconcile the wording. Its gaussian/poisson fence does **not** overlap the probe's binomial fence — no file collision. |
| #1070 | `cursor/mspl-nbinom-admit-oracles` | nbinom1/2 Pure-R oracles, stay planned |
| #1065 | `cursor/mspl-nbinom-admit-packet` | nbinom admit-packet science, stay planned |
| #981 | `claude/mspl-b0-prereqs` | **Not yours, not mine — leave open.** Still holds the `src/` `c_n` hook. |

**Design 125** (`docs/design/125-*`, kit merged as #1087) now owns the *calibrated* profile-led
construction, with a SIGNED ADEMP prereg whose Aim 1 targets coverage ≈0.95. **§2 is materially
adverse to its fork A and it cites no such caveat.** If your lane and that lane are the same person's
work, treat §2 as an input to the G4c fork decision *before* any campaign — fork B (unpenalized
Laplace at fixed MSPL nuisance) is not obviously covered by the same argument and may be the
survivor.

## 6. Environment

- **Working dir:** the repo. **Never `git checkout` in the shared Dropbox checkout** — it sits on a
  cursor cloud-agent branch and other lanes hold it. Use `git worktree add`.
- **Do not stage:** `dev/isdm-package-recovery/`, `docs/dev-log/lanes/` (untracked, foreign).
- **Verify (fast):**
  `Rscript --vanilla -e 'devtools::load_all("."); testthat::test_local(filter="mspl-api")'`
- **Verify (SE surface):** `filter="zz-mspl-.*-se-feasibility|mspl-W-onesided"`
- **Full:** `R CMD build . && R CMD check --as-cran --no-manual <tarball>` — **build WITH vignettes**;
  `--no-build-vignettes` produces 2 spurious WARNINGs (absent `inst/doc`, unrendered `gllvmTMB.Rmd`)
  that are artifacts, not defects. Clean baseline at `d22369a3` is **`Status: 1 NOTE`**,
  `checking tests ... OK`, ~17 min.
- Local checks over CI (user's standing rule).

## 7. Standing fences — unchanged by this handover

`MSPL-04` `blocked` · \(Q_0\) the paper-aligned SE target, \(Q_P\) availability-only (D-149, #1061) ·
no public `se=TRUE` / `vcov()` / `confint()` · Design 118 not reopened, B1 PARKED (D-157) · jackknife
rejected (D-148) · **Codex Lane B remains the binomial SE owner** and
`codex/lane-b-mspl-interval-feasibility` is **PROTECTED** (*"No absorb/rebase/merge"*).

## 8. OWED — next immediate steps, narrow

1. **Lane preflight** (`~/shinichi-brain/tools/lane_preflight.sh .`), then classify every item here
   `OWED` / `DONE` / `RETRACTED` / `PROTECTED` against current git.
2. **Reconcile #1077's wording** with §3 (bounds are computable on `main` for binomial).
3. **Put the Poisson W G0 to Shinichi** with §4's measurement and a recommendation. Do not sign it
   yourself; do not open new SE doors until it lands.
4. **Add the MSPL footnote to #1075's "profile = signature"** per §2a.
5. **Do not extend KF2021 to non-binomial families** — mark those UNVERIFIED (§2c).

**Not owed, explicitly:** rebuilding the profile probe (§3); the admission gate (parked, D-157);
anything public.

---

## Resume prompt

```text
Read AGENTS.md and docs/dev-log/handover/2026-08-17-cursor-handover-mspl-se-ci.md. Run the handover rehydration steps, reconcile them with the current git state, then continue only the OWED Next Immediate Steps.
```
