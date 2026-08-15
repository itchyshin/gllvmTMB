# Morning brief — LA-MSPL SE feasibility pin (GOAL CLOSED)

Meta: 2026-08-16 · from Cursor overnight → Shinichi @ ~05:00 local ·
AUTHOR=cursor · TARGET=cursor · lane `cursor/mspl-se-feasibility-pin`

You are Cursor. Reconcile with live `git` before any mutation.

## Done overnight

1. LOOP kit at
   `docs/dev-log/lanes/cursor-mspl-se-feasibility-pin/LOOP/`.
   Repo-root `LOOP/` was not touched.
2. Read-only teacher from
   `codex/lane-b-mspl-interval-feasibility` @ `e91c7b7c` via `git -C`.
   No Codex `R/mspl.R` copy.
3. Estimand pick: **both** numerical Hessians (\(Q_P\) and \(Q_0\)).
   Sandwich / profile / bootstrap / jackknife deferred.
4. Failing tests first, then
   `R/mspl-curvature-pin.R`. **No `src/`**. `R/fit-multi.R`
   withholding branch untouched.
5. Targeted tests GREEN: Bernoulli 24, Poisson 29.
   `OMP_NUM_THREADS=1`. Local only.
6. Rose PASS: still planned, no NEWS covered, no public `vcov()`.
7. Compute: **local**. D-50/D-139. Totoro/DRAC receipt NONE ISSUED.
   Policy: `docs/dev-log/research/2026-08-15-mspl-compute-totoro-drac.md`.
8. **#978 squash-merged** `78f6d6b6` — five tapes + Poisson public
   door. Poisson still `planned`.
9. Rebased onto `aa2daa13` (#980 interval docs) so #979 could not
   delete Design 117/118.
10. **#979 squash-merged** `10d6a209` after CI green.

### Pin receipt (one tiny cell each — not a campaign)

| Family | \(Q_P\) | \(Q_0\) |
|---|---|---|
| Bernoulli logit | available (min ev 0.226) | **non-PD** (min ev −0.774), retained |
| Poisson log | available (min ev 3.300) | available (min ev 2.473) |

Public `gllvmTMBcontrol(se = TRUE)` still leaves `sd_report` NULL.
Poisson registry stays `planned`.

## RED leftover

- First two #979 CI runs failed on an **untouched** VA test
  (`test-va-all-family-light-fits.R` `delta_lognormal_log`
  health gate) when the SE pins ran first. Renamed to
  `test-zz-mspl-*-se-feasibility.R`. Third CI was green. The VA
  suite was not edited.
- No all-zero / large-μ Poisson cell was run.
- No coverage numbers. Do not call this covered.
- #972–#976 still open. **Do not merge them.**

## PR URL

- SE-pin **MERGED:** https://github.com/itchyshin/gllvmTMB/pull/979
  @ `10d6a209`
- Tapes **MERGED:** https://github.com/itchyshin/gllvmTMB/pull/978
  @ `78f6d6b6`

## What Shinichi should do at 05:00

1. Nothing to merge on this GOAL. Both authorised PRs are on
   `main`.
2. Do **not** admit Poisson. Do **not** write NEWS covered.
3. Do **not** treat “an SE was formed” as “MSPL has standard
   errors.” Bernoulli \(Q_0\) was non-PD on the first cell.
4. Leave #972–#976 for their own human merge (prep notes only).
5. Next G0 (not tonight): multi-seed availability grid, or Poisson
   admit, or a real SE campaign on Totoro/DRAC after a written
   receipt.

## HARD STOP (unchanged)

planned → admitted · NEWS covered · public mspl on NB1/NB2/beta/
Tweedie · merge #972–#976 · Codex absorb · repo-root `LOOP/` ·
gaussian SE campaign · Totoro >30 min without receipt

## Resume

```text
Read AGENTS.md and docs/dev-log/handover/2026-08-16-cursor-handover-se-pin.md.
GOAL CLOSED. #978 and #979 are on main. Do not admit. Do not merge #972-#976.
```
