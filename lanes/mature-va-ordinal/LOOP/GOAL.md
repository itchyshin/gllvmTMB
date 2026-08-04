# GOAL — gllvmTMB mature-VA Item 1(B): ordinal-probit Albert–Chib

**IMMUTABLE FOR THIS RUN. Re-read this file at the start of every arc.**

> This is **not** the 0.6 release lane. That lane's kit is the top-level `LOOP/` and its goal is
> **done** (`v0.6.0` tagged). Do not read it as current instruction, and do not edit it.

## Mission

Build **ordinal-probit Albert–Chib as a real VA family in the engine — family code 5** —
completing the binomial + ordinal scope the maintainer set on 2026-08-03 (*"binomial-probit AND
ordinal-probit together, Albert–Chib Theorem 1 + Theorem 3"*). After this, only `nbinom2` lacks a
closed form, by design.

**Finish line:** the ordinal AC tier exists, is verified correct against the exact NLL, has a
recovery test, keeps the whole VA suite green, and is **fenced** — no export, `default_tier` still
`"gh"`, integration fence shut, no public claim.

## Headline

**The derivation is already DONE** — `dev/va-speed/ALBERT-CHIB-DERIVATION.md` §5 carries the full
cumulative-probit ordinal derivation (B1–B4), the stable `log(Φ(a) − Φ(b))` in §5.7, and the
cutpoint parameterisation **pinned** in §5.8. This arc is **implementation, not derivation**.

The crux is one function. `gll_log_pnorm_diff` **cannot be ported as-is**: `CppAD::CondExp`
evaluates **both** branches, and the unselected branch is `-Inf` whenever both category bounds sit
more than 8.2924 from `eta` **on the same side**. That is a **NaN Hessian that `fn()` and `gr()`
stay finite and correct through** — no gradient check can see it. The clamp magnitude is
load-bearing: **`-1.2e-16`** (double unit roundoff); `-1e-300` and `-1e-20` both fail. This is the
defect PR #925 fixed in the shipped Laplace path; do not re-pay for it.

## Invariants — never violated, even after compaction

1. **One lane.** Worktree `/private/tmp/gllvmtmb-va-lane2`, branch `claude/va-lane2`. **Never build
   in the Dropbox checkout** (PROTECTED, D-112; it is also 746 commits stale).
2. **Nothing is promoted.** `default_tier` stays `"gh"`. No new export. `R/integration-fence.R`
   untouched. `confint.gllvmTMB_va` / `vcov.gllvmTMB_va` still refuse.
3. **Compute on Totoro** (`~/gllvm_work/va-lane2`, ≤150 cores, `OPENBLAS_NUM_THREADS=1`,
   `R_LIBS_USER=$HOME/R/lib`). Results stay **LOCAL** (D-50) — never GitHub Actions, never an
   Actions artifact.
4. **Every claim states its regime**: `eval_method`, `collapse_variational_cov`, `H`, `n_trials`,
   and planted `psi`. The arc's founding error was reporting a `gh`/`collapse=FALSE` measurement as
   a verdict on the `ac`/`collapse=TRUE` route.
5. **Verify `he()`, not just `gr()`.** A finite, *correct* `fn`/`gr` is not evidence of a finite
   Hessian in this template.
6. **AC is a STRICT LOWER BOUND.** `ARC.md`'s *"objective identical to ~1e-13"* discipline does
   **not** apply and would fail a correct implementation. Check `AC ≥ exact NLL` with a strict gap.
7. **Never `git add -A`.** Stage explicit paths (D-88; a second session shares this repo).
8. **Do not push** `claude/va-lane2` — maintainer's call, standing since the previous handover.

## Fence — explicitly OUT of scope for this run

- **EVA** and **AGHQ** — raised in error during planning; neither is this arc. Codex owns the EVA lane.
- **The VA interval-coverage campaign** — D-112 fences the compute ("capabilities, not coverage").
  Both its blockers are now closed, so it is *available*, but it is not this arc.
- **Package-vs-package accuracy claims** — the mature-VA handover is explicit that nothing is
  claimed before the multi-seed Totoro arc. That is the arc *after* this one.
- **Promoting AC to a default** — it collapses a real ψ at low `n_trials`; disqualifying on its own.

## Authoritative WHAT

`lanes/mature-va-ordinal/LOOP/ultra-plan.md` (binding detail wins there).
This file wins on *"what must never be lost."*

Background, read in order when resuming cold:
`docs/dev-log/handover/2026-08-03-claude-handover-mature-va-item1.md` (the arc; read the FINAL
STATE section first, then SESSION 2, then the top) → `dev/va-speed/ALBERT-CHIB-DERIVATION.md` §5 →
`dev/va-speed/20-CLAIMS-LEDGER.md` (**check status before citing anything**).

## Definition of done

1. `eval_method = "ac"` accepts an ordinal-probit fit through **family code 5**, end to end.
2. A verify script mirroring `06-ac-tier-verify.R` passes for ordinal: tier round-trip, family
   guard both directions, **AC ≥ exact NLL with a strict gap**, `he()` finite over the
   `|a|,|b| > 8.2924` same-side region, AD gradient vs finite difference, and the `n`-scaling check.
3. A recovery test plants an ordinal DGP and recovers cutpoints and loadings.
4. `devtools::test(filter = "va")` ≥ 1335 passed, **0 failed**.
5. The fence is asserted intact by a test, not by assertion in prose.
6. After-task report + check-log entry + validation-debt register row + handover.
