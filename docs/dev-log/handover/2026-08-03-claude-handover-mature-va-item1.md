# Session Handoff: mature-VA Item 1(A) SHIPPED behind the fence · Design 108 campaign REFUTED

**Meta:** 2026-08-03 · from Claude · to Claude · fresh context required
**`origin/main` at write:** `d53dfa29`
**Arc branch:** `claude/mature-va-albert-chib` @ `f60451bb` (pushed, no PR)
**Worktree:** `/private/tmp/gllvmtmb-mature-va` (cut from `origin/main`, clean base)

## Mission-control summary

| Field | Value |
| --- | --- |
| Repo | `gllvmTMB` |
| This session | Closed the previous handover's OWED items; then built Item 1(A) of the mature-VA arc |
| **Item 1(A)** | **Albert-Chib closed-form probit tier LANDED** — `eval_method = "ac"`, 21/21 verify checks pass, 245 existing VA tests green |
| **Design 108** | **Campaign verdict REFUTED by two independent panels.** Corrected in place |
| Fence | **untouched** — no export, no `method=`, no public claim, `default_tier` still `"gh"` |
| 🔴 Needs Shinichi | **PR #917** · the Stage-5 supersession call · the Amdahl re-aim (below) |

## What was accomplished

### 1. The previous handover's OWED items — all four closed

- **#919 reconciliation (OWED 1): SETTLED.** Every scored quantity in the campaign is a Gram
  matrix, and `ΛΛ'` is exactly invariant under a column sign flip (`S = diag(±1)`, `SS' = I`)
  and any rotation. Confirmed numerically over all `2^q` modes — difference **exactly 0**. The
  unconstrained loadings diagonal never touched the estimand.
- **Totoro grid (OWED 2): was already collected but UNPUSHED.** Pushed. ⚠ It needed an explicit
  refspec: the local branch is named `claude/design108-stage7-phylo-kl` but *tracks*
  `claude/d108-recovery-campaign`, and a **different** remote branch owns the matching name.
  `git push origin <branch-name>` would have clobbered the Stage-7 lane. **Check `@{upstream}`
  before pushing any branch by name in this repo.**
- **Adversarial verification (OWED 3): DONE — see §2.**
- **Mature-VA arc (OWED 4): STARTED and Item 1(A) landed — see §3.**

### 2. The Design 108 campaign verdict is REFUTED — twice, independently

The review dispatched at the last handover had not written its file, so this session
re-dispatched it as **five fresh adversaries in independent contexts**, default NOT-HOLDING.
The original then landed mid-session. **Neither panel saw the other and they converge** — the
fatal defect was found independently by three agents.

Full detail: `dev/design108-recovery/ADVERSARIAL-REVIEW.md` (original §§1–12, second panel
§APPENDIX A1–A9) on `claude/d108-recovery-campaign` @ `fa0cee95`. The retraction is written
into `PILOT-FINDINGS.md`.

Two fatal defects:

1. **The arms fitted different models.** The driver inlined VA as `gaussian_anchor`/identity on
   `scale(y)` while Laplace was `binomial(probit)` on raw `y`, both scored against eta-scale
   truth. VA's oracle floor is 0.71–0.78; Laplace's is 0. **In 3 of 4 cells a perfect VA loses
   anyway**, and the tier-1 "8×" *reverses* under floor correction. The harness had
   **prohibited this comparison in writing** (`harness.R:448-469`).
2. **The 34% completion rate is a harness property.** `mclapply(mc.cores = 40)` called
   `.va_r3_fit()` without the required per-worker DLL seeding (`harness.R:103-110`), so 40
   workers raced to compile. Laplace used the already-loaded main DLL — hence 80/80.

Plus: 9 of 27 VA "successes" are `Σ̂ → 0` collapses scoring `rel_frob` **exactly 1**, which beats
every genuine return; two PROTOCOL-mandated analyses (per-cell sign test, `d_prop`) were never
run and each flips the headline; the `~7 days` denominator is **inflated 3–5×** (the design doc
costs the stages at 1.5–2.5 d).

**What survives:** VA produces degenerate structured-tier estimates, and **four restarts do not
rescue them** (two cells identical to 6 s.f., one collapse unchanged, one collapse → runaway) at
~4× the cost. That single-arm finding is the only thing that should be cited.

**None of this is evidence against VA.** On the target family the same engine is more accurate
than gllvm's mature VA and 2.4× faster than our own Laplace. The problem is cost.

### 3. Item 1(A) — the Albert-Chib tier, SHIPPED behind the fence

**The derivation answered the gating question: OBJECTIVE SUBSTITUTION.**
`dev/va-speed/ALBERT-CHIB-DERIVATION.md`. The auxiliary `z` profiles out analytically and
exactly:

> **E_AC(μ, v; y, n) = y·logΦ(μ) + (n−y)·logΦ(−μ) − n·v/2**

No residual free parameter; TMB never sees `z`; the variational parameter block is unchanged.
Four lines of C++ over primitives already merged in #896. Because `v` enters **linearly**, the
`sqrt(v)` unbounded-derivative problem that forces the GH evaluator's small-`v` branch does not
arise — **no threshold, no `CondExp`**.

**We diverge from the reference, and the reference is wrong.** gllvm subtracts its `calc.quad`
term (`= v/2`) once per cell regardless of `trial.size`. The derivation gives **`−n·v/2`** — one
latent `z` per trial. They coincide only at `n = 1`; at `n > 1` gllvm's form is **not a lower
bound at all**. Measured here: our form's min `(exact − bound)` is **+0.00287**, gllvm's is
**−15.584 nats**. Our reference cell uses `n_trials = 6`, so copying the reference would have
been wrong.

**Two more places we are better than the reference** (`dev/va-speed/GLLVM-REFERENCE-READ.md`):
gllvm's ordinal CDF difference is computed **naively** with no log-space cancellation guard, and
non-finite cells are **silently dropped from the objective or zeroed in the gradient**; and its
probit gradient carries a `+1e-05` denominator ridge that biases it wherever `|η| ≳ 4.4`.

**Verified — 21 checks, `dev/va-speed/06-ac-tier-verify.R`, all pass.** Note this is **not an
identity check**: AC is a strict *lower bound*, so ARC.md's "objective identical to ~1e-13"
discipline does not apply and would fail a correct implementation. The checks are: tier
round-trip (`"ac"` → template code 2, confirmed by `REPORT`); family guard both directions;
unknown tier is a hard error; **AC never below GH on the NLL scale** over 26 parameter points
(min gap 331.4) and the gap is **strict**; **`he()` finite, not just `gr()`**; AD gradient
matches finite difference to 1.4e-08; and the `n`-scaling check above.

**Regression: 245 existing VA tests pass, 0 failures** across `test-va-r3-prototype.R`,
`test-va-probit-adsafety.R`, `test-integration-fence.R`, `test-va-routing-oracle.R`,
`test-va-mixed-family.R`, `test-approximation-engine.R`.

## 🔴 THE RE-AIM — Item 1 alone cannot hit the speed target

**This is the most important thing in this handover.** The derivation found that Amdahl caps
Item 1 at **~4×**: GH is ~75% of runtime, so removing it entirely gives 45.6 s → ~11.4 s, still
**16× slower than gllvm's 0.70 s**.

But it also located the probable real source of the reference's speed, from the algebra:
`∂E/∂v ≡ −n/2` identically forces

> `A_i⁻¹ = Σ⁻¹ + Σ_j n_ij λ_j λ_j'`

which for complete data with constant `n` is **independent of `i` and of the data entirely** —
every unit gets the same variational covariance. Derived here, then found **verbatim** in
gllvm's source: it computes `A_1` (lines 1142-1144), **breaks out of the per-unit loop**
(1188-1190), and copies it to all `n` units (1192-1198), while Poisson and negbin *do* get a
per-unit data-dependent `A_i`. At the reference cell that collapses **250 variational-covariance
parameters to 1**.

**This is NOT the deprioritised block-diagonal-`S` item** (which restructures each `A_i`); it is
a consequence of the AC objective itself, so the GOAL's DO-NOT list does not cover it. It is the
licensed follow-on slice and the plausible route to the actual target.

**A fence that follows:** under AC the variational covariance is structurally data-independent,
so per-unit variational SDs carry **no per-unit information**. Any interval, coverage, or
`getLV(se = TRUE)` claim built on VA-AC posterior SDs is far weaker than the same claim under
GH. State this wherever AC output is surfaced. (Constancy needs complete data, constant `n`,
pure-probit traits, the unstructured single-tier KL; **UNVERIFIED for the Stage-7 structured
tiers**. The *objective* is unaffected by any of that — only the `A_i` corollary.)

## Landing state

| Artifact | Branch | State |
|---|---|---|
| AC tier + derivation + reference read + design-108 correction | `claude/mature-va-albert-chib` | **PUSHED** `f60451bb`, no PR |
| Adversarial review + campaign correction + the driver | `claude/d108-recovery-campaign` | **PUSHED** `fa0cee95` |
| Register-code guard | `claude/register-code-guard` | **PR #917 OPEN** — needs Shinichi |
| Brain log | `~/shinichi-brain` | committed `184eacd` (local-only, D-37) |

Campaign and benchmark results are **LOCAL (D-50)** — `.rds`/`.csv` gitignored, never committed.

## Next immediate steps (classify OWED / DONE / BLOCKED)

1. **OWED — finish the speed/accuracy measurement.** `dev/va-speed/07-ac-vs-gh-vs-gllvm.R`
   (interleaved, arm order rotates per seed). **It did not complete in this session**: two runs
   at the locked N=250/T=20 cell were killed mid-GH-fit with no error written (once on the joint
   route after 10 min, once on the profile route). The script is now scaled to N=150/T=10, 3
   seeds, and its header says plainly that absolute seconds are **not** comparable to the locked
   0.70 s / 45.6 s and that acceptance gate (a) is therefore **not tested**. **Until this lands,
   NO speed claim exists for the AC tier — only the correctness evidence in §3.**
2. **OWED — the accuracy gate is the arc's binding falsifier.** `rel_frob ≤ 0.298`. AC is a
   *strictly looser* bound and is loosest on well-fitted cells, i.e. most of them at convergence.
   This is the most likely way Item 1 fails, and it is **unmeasured**.
3. **🔴 Needs Shinichi — the Amdahl re-aim.** Item 1 alone gets ~4×, not the target. Is the
   `A_i`-collapse slice authorised as Item 1(c)?
4. **🔴 Needs Shinichi — Stage 5.** Design 108 Row 5 (ordinal via `logspace_sub` of two GH
   `log Φ`s) may now be negative work. The correction block in
   `docs/design/108-va-parity-programme.md` records the decision as **his**, not taken.
5. **OWED — Item 1(B), ordinal.** A **new family code 5**, not a branch: the VA template has no
   ordinal support at all (codes validated `0..4`). Needs two `DATA_IVECTOR`s, a
   `PARAMETER_VECTOR`, `va_r3_log1mexp` + a `log_pnorm_diff`, and full R-side wiring.
   `gll_log_pnorm_diff` **cannot be ported as-is** — it needs re-pointing at `va_r3_log_pnorm`
   and an input clamp, because its unselected `CondExp` branch is `−Inf` for `|a|,|b| > 8.2924`,
   a **NaN Hessian that `obj$gr()` cannot detect**.
6. **DEFERRED:** Items 2–4 of MATURE-VA (the `profile_variational` default is HALF-established —
   the objective identity is settled, the speed rule is **not**; do not set a threshold from
   that data).

## Gotchas — paid for this session

- **`git push origin <branch-name>` is not safe here.** A local branch's name collided with a
  *different* remote branch while tracking a third. Push with an explicit `HEAD:<upstream>`
  refspec, or check `git rev-parse --abbrev-ref <branch>@{upstream}` first.
- **`pgrep -f "<pattern>"` matches its own command line** — it reported a 71-second-old process
  that was the poll itself. Split the literal: `ps aux | grep "[0]7-ac-vs"`.
- **`timeout` is not on this macOS path.** Use the harness's own backgrounding instead.
- **Don't run competing CPU work while an interleaved timing benchmark is live** — it corrupts
  exactly the measurement being made.
- **A registry-drift test will fail the moment you add a tier, and that is correct.**
  `test-va-r3-prototype.R:510` holds an expected per-tier optimizer map; adding `"ac"` without
  updating it is a subscript error, not a mystery.
- **The `default` of `profile_variational` is the slow route at the reference cell.** At
  N=250/T=20 the joint route hands `nlminb` ~28,700 outer coordinates with an O(P²) PORT
  workspace. The locked baseline was measured with `profile_variational = TRUE`.

## Live environment

```sh
REPO="/Users/z3437171/Dropbox/Github Local/gllvmTMB"   # PROTECTED — never build here (D-112)
WT="/private/tmp/gllvmtmb-mature-va"                    # branch claude/mature-va-albert-chib
export NOT_CRAN=true
Rscript --vanilla -e 'devtools::load_all(quiet=TRUE)'
Rscript --vanilla dev/va-speed/06-ac-tier-verify.R      # 21 correctness checks
Rscript --vanilla dev/va-speed/07-ac-vs-gh-vs-gllvm.R   # the unfinished measurement
```

**Do not stage:** the Dropbox `.claude/` or `.uinit/` dirs, any campaign or benchmark
`.csv`/`.rds` (D-50), or foreign lane trees.

## Resume prompt

```text
Read AGENTS.md and docs/dev-log/handover/2026-08-03-claude-handover-mature-va-item1.md.
Run the handover rehydration steps, reconcile with git, then continue the OWED steps —
starting with the unfinished speed/accuracy measurement, which is the arc's binding falsifier.
```
