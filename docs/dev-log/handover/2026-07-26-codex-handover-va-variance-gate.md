# Codex Handoff — VA lane: the variance-domain-gate question

**Meta:** 2026-07-26 · author = Claude · **target = Codex** · fresh context.

You are Codex, picking up `gllvmTMB`. You have never seen the authoring session's chat, so this
document stands alone. Read `AGENTS.md` (native to you) first, then
`docs/dev-log/handover/2026-07-25-active-lane-split.md` — this repository runs multiple fenced lanes
and is **not** a single writable workspace.

**Codex already owns the EVA / VA / JJ family (`design90`–`design98`) and the eta-simulation lane at
`/private/tmp/gllvmtmb-design100-progress-oracle`.** This handover adds one bounded task adjacent to
them. It does **not** hand you those lanes' open questions.

---

## 🔴 READ THIS BEFORE WRITING ANY VA CODE

**Design 85 §10 "Prohibited interpretations and outputs"
(`docs/design/85-highdim-nongaussian-va-formal-contract.md:338-339`) forbids widening the R3
prototype to Bernoulli**, verbatim:

> *"widening to **Bernoulli**, incomplete responses, mixed families, alternative links, structured
> sources, random slopes, or public syntax by analogy"*

A Bernoulli widening WAS implemented overnight on `claude/va-implementation-20260725` (`2392996b`),
**before §10 was discovered**. That branch is marked **DO NOT MERGE** and is awaiting Shinichi's
decision (new formal contract / revert / park). Its reopening condition
(`docs/dev-log/audits/2026-07-20-va-r3-pilot-no-go.md:75-76`) requires *"a genuinely new evidence
source identifies a tractable alternative **and the maintainer approves a new formal contract**"* —
reusing va-r3's *code* does not exempt new work.

**Your task below is deliberately scoped to NOT require that decision.** It is a measurement of
existing behaviour, not a widening. Do not extend it into one.

---

## Goals / mission

`gllvmTMB` 0.6 ships **Laplace-only**; EVA/VA is cut to 0.7. The rung is **NOT READY** and the gap to
submission is **EVIDENCE, not capability**. Nothing about VA is admitted — no export, no
user-facing route, no public claim. `NAMESPACE` is under a signed freeze (SHA-256 `c97ae039`,
153 exports / 33 S3 methods).

## Current state — what was established 2026-07-25/26

All of this is verified and reproducible; scripts are on
`claude/va-implementation-20260725` under `dev/`.

1. **The VA objective is CORRECT.** Both terms of
   `ELBO = Σᵢ E_q[log p(yᵢ|uᵢ)] − Σᵢ KL(q(uᵢ)‖N(0,I))` were independently re-derived and match the
   TMB template to **machine precision**. `dev/va-elbo-bisection-RESULTS.md`.
2. **The ELBO is a valid lower bound** — 14/14 independently computed ELBO−truth gaps negative.
3. **Ground truth is computable**: brute-force per-unit 2-D product Gauss-Hermite, H-ladder stable,
   cross-checked against nested adaptive `stats::integrate` to 1.3e-15–5.3e-15.
4. **VA is closer to truth than Laplace in direction** (9/10 verdict-eligible reps) — but the
   advantage **shrinks** as data get sparser, the opposite of the programme's motivation.
5. **Laplace's error CHANGES SIGN with sparsity** — 5/10 reps below truth, 5/10 **above** by up to
   **+3.38 nats** — while the ELBO stayed a valid bound throughout. The most promising qualitative
   VA argument produced so far.
6. **AGHQ is NOT a usable oracle** — `INFRASTRUCTURE_INCOMPLETE`, uncertified, external comparator
   only at q=1, fenced from repair. Do not rely on it.

## 🎯 YOUR TASK — is the variance-domain gate a real limit or a scope choice?

**This is the question that decides whether the va-r3 route has a future.**

An independent 15-rep sweep found the prototype's own gate —

```r
variance_domain_ok <- max_projected_variance <= 4     # R/va-r3-proto.R:648
```

— returns status `healthy` in only **5 of 15** reps:

| sparsity | healthy | max projected variance observed |
|---|---|---|
| p̄ ≈ 0.35 | 4/5 | 4.20 |
| p̄ ≈ 0.18 | 1/5 | 5.95 – 7.36 |
| **p̄ ≈ 0.09** | **0/5** | **14.71 – 27.01** |

**Design 86's admission band is p̄ ∈ [0.03, 0.10]** — exactly where nothing is healthy.

`n_trials >= 2` turned out to be a pure **scope choice** with no recorded mechanism (confirmed by a
dedicated probe: `log C(1,y) = 0` exactly for y ∈ {0,1}, and `va_r3_softplus_expectation()` never
receives `n`, so quadrature accuracy is independent of `n_trials` **by construction**).

**So: is `<= 4` the same kind of arbitrary scope choice, or a genuine numerical limit?**

**Answer it empirically, without widening anything:**

- Find where `4` comes from. Grep the contract, the design docs, the NO-GO record, and the code's own
  comments. Quote verbatim whatever justification exists — **or report plainly that none is
  recorded**, which is itself the answer.
- Measure what actually degrades as `max_projected_variance` rises. Using **multi-trial binomial
  fixtures only** (no Bernoulli — §10), construct fits that push projected variance through 4, 6, 10,
  20. At each level compare the ELBO against the brute-force ground truth. **Does the bound stay
  valid? Does quadrature accuracy degrade? Does the H-ladder still converge?**
- The decisive question: **does anything actually break at 4, or does the gate merely fire?**

**Outcome shapes, all valuable:**
- `4` is arbitrary and nothing degrades until much higher → the route may reach the target regime,
  and the gate should be re-derived (a contract change, Shinichi's).
- Something genuinely degrades near 4 → **the va-r3 route cannot serve sparse binary**, and Design 86's
  separate objective is the right path. That closes a question that has consumed many lanes.
- Unrecorded and undeterminable → say so; do not infer.

### Secondary, only if the above finishes cleanly

The **separation guard** added overnight (`.va_r3_check_separation()`, on the DO-NOT-MERGE branch) is
defective and should not be reused as-is: it computes `converged` and never consults it; it varies
`maxit` (25→200) and `epsilon` (1e-8→1e-12) *together* so its "drift" is not attributable to
tolerance; and it is called on the **whole binomial branch** unconditional on `n_trials`, so it can
refuse `n_trials >= 2` designs the frozen prototype previously accepted — including Gate-2/Gate-3
fixtures. If a separation detector is needed later, design it fresh.

## Why this is Codex's work

Per `AGENTS.md` and the hub division of labour, **Codex runs the live toolchain** — real R/TMB fits,
`R CMD check`, simulation campaigns. This task is exactly that: repeated TMB fits, quadrature ladders,
numerical degradation curves. Claude's half (planning, forensics, the corpus reading) is done and is
in this document.

## Live environment

```sh
export NOT_CRAN=true
Rscript --vanilla -e 'devtools::load_all(); packageVersion("TMB")'
```

The prototype needs its template compiled; `R/va-r3-proto.R` resolves it via
`system.file("tmb", "gllvmTMB_va_r3.cpp", package = "gllvmTMB")`. Fit helpers and a working
brute-force truth routine are on `claude/va-implementation-20260725` in
`dev/va-first-light.R`, `dev/va-elbo-bisection-RESULTS.md`, `dev/va-bernoulli.R` — **reuse the truth
routine; do not rewrite it.**

## Hard constraints

- **No exports.** Do not edit `NAMESPACE` or `DESCRIPTION`. The M3 freeze holds.
- **No Bernoulli.** §10. Multi-trial fixtures only.
- **No public claim, no register row, no NEWS entry.** Nothing about VA is admitted.
- **D-50:** campaigns run on Totoro/DRAC, never GitHub Actions; results stay **local**.
- **Codex fences:** do not absorb the Claude branches listed below into your lanes.
- **Compare against TRUTH, never against Laplace.** Laplace is itself an approximation with no
  guaranteed direction; §10 explicitly prohibits treating an ELBO/Laplace gap as an error measure.
  This exact confusion produced a wrong diagnosis on 2026-07-25 that stood for an hour.

## Rehydration

`AGENTS.md` → `docs/dev-log/handover/2026-07-25-active-lane-split.md` → this doc →
`docs/dev-log/handover/2026-07-26-claude-handover-va-bernoulli.md` (the full VA arc record, on
`claude/va-implementation-20260725`) → `docs/design/85-highdim-nongaussian-va-formal-contract.md`
(read §10 and its NO-GO triggers in full).

Team mirror: `.codex/agents/*.toml`. **`systems-auditor.toml` (Rose) is mandatory before any public
claim.** `simulation-tester.toml` (Curie) is the right lens for the sweep design.

Resume prompt, from the repository root:

```
Rehydrate from docs/dev-log/handover/2026-07-26-codex-handover-va-variance-gate.md + AGENTS.md, then answer the variance-domain-gate question. Multi-trial fixtures only — Design 85 §10 prohibits Bernoulli widening and that decision is the maintainer's, not yours.
```

## Branch state — nothing of this arc is merged

| Branch | State |
|---|---|
| `claude/va-implementation-20260725` | **DO NOT MERGE** (§10). Carries the verified objective evidence and the Bernoulli widening. |
| `claude/getlv-score-se-20260725` | PR #792 — CI red on a fragile test fixture, fix in progress |
| `claude/eva-record-consolidation-20260725` | record rejected `NOT_ESTABLISHED`; needs a second pass |
| merged to `main` | #790 (`a767026e`), #791 (`95c38cb4`), and the 07-25 arc `a0f568d1..84ca8290` |

## Method warnings earned the hard way

- **Local green ≠ CI green.** PR #792 reported FAIL 0 locally and failed on ubuntu-latest — a
  `pdHess` assertion that is platform/BLAS-sensitive.
- **Every synthesis run through an adversarial reviewer on 2026-07-25 was rejected, and every
  distortion leaned optimistic** (four for four). Keep the adversarial step.
- **Never impose a controlled vocabulary on a status corpus** — an enum manufactured six positive
  verdicts that appear nowhere in the sources. Quote verbatim.
- **"It fitted" is not evidence.** Three silent-wrong-answer bugs were found in one day.
