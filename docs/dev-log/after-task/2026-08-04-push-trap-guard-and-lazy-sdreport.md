# After Task: push-trap guard closed, and `standard_errors()` shipped

**Date:** 2026-08-04 · **Platform:** Claude Code (solo) · **Branch:** `claude/va-lane2`
**Commits:** `9d560616` (Arc F), `29d7db7e` (Arc A)

## 1. Goal

Run the first two arcs of the approved five-arc VA-lane programme: **Arc F**, close the
repo-wide push trap; **Arc A**, build the approved lazy `sdreport()` accessor. Arcs D, B and E
were planned but not started — see §10.

## 2. Implemented

**Arc F — push-trap guard.** A local branch that *tracks* `origin/main` while carrying its own
commits is a trap: a bare `git push` puts those commits on `main`. Shinichi flagged this on
`claude/va-lane2` and suspected it generalised. Audited all **566** local branches: **43** tracked
`origin/main`, and **16 were ahead of it** — `claude/va-lane2` with **48 commits**, 15 others with
1–2 each. Fixed: 2 retargeted to their own remote branch, 14 upstream-unset (no remote exists, so
a bare push now fails safely). `tools/check-push-traps.sh` keeps it closed.

**Arc A — `standard_errors()`.** Deferred TMB `sdreport()` for a fit made with
`gllvmTMBcontrol(se = FALSE)`. `fit <- standard_errors(fit)` computes it on demand from
`fit$tmb_obj` + `fit$opt`, mirroring the single production call at `R/fit-multi.R:6087`.

## 3. Files Changed

- `tools/check-push-traps.sh` (new)
- `R/standard-errors.R` (new), `man/standard_errors.Rd` (generated), `NAMESPACE`
- `tests/testthat/test-standard-errors.R` (new)
- `NEWS.md` — `## New` bullet under `# gllvmTMB 0.6.0`
- `docs/design/35-validation-debt-register.md` — row **EXT-35**
- `dev/va-speed/60-se-false-consumer-probe.md` (new, probe evidence)

## 3a. Decisions and Rejected Alternatives

- **Unset rather than invent upstreams** for the 14 trap branches with no remote counterpart. A
  bare push then fails safely; inventing a remote branch would have pushed 14 stale branches.
- **`fit <- standard_errors(fit)`, not in-place mutation.** `fit` is a plain S3 list, so R's
  copy-on-modify makes in-place impossible. Documented explicitly because silently discarding the
  result is the obvious user error.
- **Scoped v1 same-session.** A TMB ADFun's external pointers do not survive `saveRDS()`. Shared
  by every `fit$tmb_obj` consumer; closed here only with a *typed error*, not a fix.
- **Rejected: folding in the silent-NA `confint` fix.** Confirmed real (§5) but a user-facing
  behaviour change outside the approved scope. Recorded OPEN in EXT-35 and spawned separately.
- **Naming debt accepted.** `standard_errors()` matches neither the `extract_*()` contract nor the
  deprecated `get*()` family. Shipped as-is; flagged rather than silently resolved.

## 4. Checks Run

- `devtools::document()` — clean; `export(standard_errors)` at `NAMESPACE:195`.
- `testthat::test_local(filter = "standard-errors")` — **10/10 pass**.
- `tools/check-push-traps.sh` — exit 1 on the 16 real traps, exit 0 after the fix.
- Full suite: launched (`devtools::test()`); result recorded in the check-log entry.

## 5. Tests of the Tests

This is where the session earned its keep, and it went against me twice.

**Arc F's guard was negative-controlled.** It fired on 16 real traps (exit 1), passed after the
fix (exit 0), then fired again (exit 1) on a manufactured trap branch that was deleted afterwards.
A guard that has never fired is not a guard.

**Arc A's drift test was vacuous, and I caught it only by trying to make it fail.** The test
claimed to prove the internal-state replay was load-bearing. Three measured arms said otherwise:

| arm | result |
|---|---|
| state moved, no replay, no `par.fixed` | bit-identical to truth |
| state moved, no replay, with `par.fixed` | bit-identical to truth |
| shipped accessor (replay + `par.fixed`) | bit-identical to truth |

Repeated with a genuine 30-element random-effect block: unchanged. **Mechanism:** `sdreport()`
reads `last.par.best`, and `obj$fn()` moves `last.par`, not `last.par.best` — so the scenario the
test simulated cannot occur. Directly corrupting `last.par.best` *does* change the answer (max abs
SE diff **0.20**) and **the replay does not recover from it either**. The code comment and the
test were rewritten to say what is true; the replay is kept as fidelity to the fit-time path, not
as a guarantee it does not provide.

## 6. Consistency Audit

`sdreport()` is called in exactly one production place (`R/fit-multi.R:6087`); the accessor mirrors
it rather than adding a second route. `sdreport_error` is cleared on success so
`gllvmTMB_diagnose()`'s `sdreport_ok` row stays truthful.

## 7. Roadmap Tick

Neither arc is one of D-113's six 0.7 capability tracks — see §10.

## 7a. GitHub Issue Ledger

None opened or closed. [#934](https://github.com/itchyshin/gllvmTMB/issues/934) untouched (Arc B
not started).

## 8. What Did Not Go Smoothly

**I repeated the lane's own signature mistake.** Sizing Arc B, I read per-fit seconds from
`43-vala-ac_N*.rds` and concluded "~13 core-hours, ~15 min on Totoro" — then read the status
column: all 9 rows `failed_health_gate`, at 1–2 iterations. Those are the seconds a fit costs when
it *gives up*. The estimate was retracted before it reached a plan Shinichi could act on, but it
was the third occurrence of this class in this lane and the first by me, written into the same
document where I had just recorded the lesson.

**A spec defect surfaced late.** Arc B's design note requires scoring under both `eval_method`s,
but `gaussian_anchor` has `tiers = "gh"` only (`R/va-r3-proto.R:1164-1176`); `binomial_probit` is
the only family with a choice. The primary coverage cells are Gaussian, so the requirement is
unsatisfiable as written. Escalated, not worked around.

## 9. Team Learning

- **Rose:** the approved programme sits *off* the declared 0.7 queue (D-113 names missing-data
  #332 as the primary post-0.6 slice). Approval of an arc is not the same as it being next.
- **Fisher:** a route ranking is meaningless without its specification status — prior art from
  inside the group (Qin, Mizuno, Morrison & Nakagawa 2026 §7.2, tracked as CI-17) shows sandwich
  and parametric-bootstrap intervals *reverse ordering* with specification.
- **Gauss:** every timing table in this lane must carry its health-gate column beside the seconds.

## 10. Known Limitations And Next Actions

**Not done, in plan order:**

1. **Arc D — cheap speed levers** (~1–1.5 h). Smaller than the handover implies: the "one-liner"
   AD-framework lever is *already closed* (`b4fb920f`, TMBad 1.76× slower), and `nlminb(scale=)` is
   **already whitelisted** in the Laplace/AGHQ pass-through (`R/fit-multi.R:5196`, verified) — it
   needs a *value*, not plumbing. VA-R3 has no such mechanism (`R/va-r3-proto.R:1523-1526`).
   Remaining: `multiphase`, `optimHess` polish, `sdreport` knobs, gllvm `inner.control`
   (⚠ `tol10` may move estimates).
2. **Arc B — sandwich scoring.** Blocked on two answers: the `eval_method` spec defect (§8) and a
   healthy-fit timing probe to replace the retracted estimate. Cite CI-17.
3. **Arc E — gllvm head-to-head.** Ledger claim 30 unresolved; two prior attempts retracted.
4. **Arc C — ordinal.** Deferred to a ~45-min feasibility probe; the shipped Laplace
   `ordinal_probit` (family_id 14) is a ready template and comparator.

**Open, recorded, not closed:** `.gllvmTMB_b_fix_se()` (`R/methods-gllvmTMB.R:209`) returns NA with
no warning when `sd_report` is NULL, and `confint(method = "wald")` propagates it to an all-NA
interval **silently** — confirmed by runtime probe. Row EXT-35 marks it OPEN. Separately,
`vcov.gllvmTMB` does not exist despite roxygen at `R/gllvmTMB.R:295` claiming it dispatches.

**Needs Shinichi:** (1) does this VA programme precede D-113's missing-data #332? (2) Arc B's arm
choice. (3) `standard_errors()` naming.
