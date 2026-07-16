# After-task — `multinomial(baseline=)` wired + verified (Lane C follow-up)

**Date:** 2026-07-16 · **Author:** Claude (Fable 5) · **Branch:** `agent/lane-c-multinomial`
(worktree `.claude/worktrees/lane-c-multinomial`, based `48a66b93`). **Local, unpushed.**
Follow-up to `2026-07-16-multinomial-c1-c2-core.md` (Next Immediate Step 1 of the multinomial
handover).

## Scope
Honour the `multinomial(baseline=)` constructor argument. The constructor accepted and documented
`baseline` (a reference category pinned at η = 0), but `expand_multinomial_response()` ignored it
and always used the first factor level — users could only change the reference via `relevel()` on
the response. This wires the argument through. Tier-1 fixed-effects-only scope is unchanged; no C++
change.

## Mechanism (minimal, reuse-not-rebuild)
`expand_multinomial_response()` (`R/gllvmTMB.R`) now:
1. reads `requested_baseline <- mn_family$baseline` from the multinomial family object (after the
   mixed-family guard);
2. after the existing `K < 3` redirect, validates the requested level against the observed
   categories (fail-loud "not a category of the response" otherwise) and
   `yf <- stats::relevel(yf, ref = requested_baseline)`, then recomputes `cats <- levels(yf)`;
3. returns `family = multinomial(baseline = requested_baseline)` for metadata consistency.

Because everything downstream already treats `cats[1L]` as the pinned baseline and `cats[-1L]` as
the K−1 contrasts, releveling the response to put the requested category first is **provably
equivalent to the user calling `relevel()` themselves** — the exact operation the existing
baseline-invariance test exercises. No parser, likelihood, or C++ change; `man/multinomial.Rd`
already documents the argument, so no doc regeneration was needed.

## Tests added (`tests/testthat/test-multinomial.R`)
- **`baseline=` equivalence:** `multinomial(baseline = "3")` on the original data yields the same
  maximised objective (`tol 1e-6`), the same coefficient vector (`tol 1e-4`), and
  `multinomial_meta$baseline == "3"` as manually releveling the response to `c("3","1","2")` with a
  default `multinomial()`.
- **Invalid baseline fails loud:** `multinomial(baseline = "nonesuch")` errors with
  "not a category of the response".

## Checks (evidence)
- `devtools::load_all()` + `testthat::test_file("test-multinomial.R")` under `NOT_CRAN=true`:
  **48 PASS / 0 FAIL / 0 SKIP** (was 43 before these 2 tests; every case now runs non-skipped).
- Regression: `test-enum-runtime-ids.R` **15 PASS / 0 FAIL / 0 SKIP** — id 16 unaffected.

## Discipline
Surgical change to one internal function + two tests + this report + a registry evidence touch
(FAM-20 stays `partial` — no promotion, no public claim). Local commit on the Lane-C branch; not
pushed (maintainer's call). Follows the multinomial handover's Next Immediate Step 1.

## Follow-ups (unchanged from the handover, all optional)
- Typed condition classes for the 3 message-matched fences (latent/RE, K<3, mixed).
- `dev/multinomial-recovery.R` band-calibration harness (Totoro/DRAC, never GitHub Actions — D-50).
- FAM-20 promotion off `partial` only after maintainer sign-off + a clean D-43 re-audit.
