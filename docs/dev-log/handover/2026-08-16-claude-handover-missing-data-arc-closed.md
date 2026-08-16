# Handover — the missing-data arc is CLOSED; the interval programme stopped on a pre-registered rule

**From**: Claude (Fable 5), overnight session 2026-08-15 → 2026-08-16
**Lane**: `claude/missing-all-families-20260815` → `claude/predict-missing-se-20260815`
→ `claude/pm-se-r2-sim-20260816` → `claude/pm-se-r3-boot-20260816` (all merged or merging)
**To**: whoever takes the next arc in this repo (Claude, Codex, or Cursor)
**Read time**: 5 minutes. Everything below is measured, not planned.

---

## 1. What is DONE and on `main`

**The capability Shinichi asked for — "all distributions, responses =
include missing responses" — is delivered and evidenced.**

| PR | What landed |
|---|---|
| #982 | All 17 Laplace families + all 18 VA scalar cells evidenced for `miss_control(response = "include")`; multinomial NA fence lifted (R-side); first masked-cell ACCURACY numbers; P3CA/Rphylopars head-to-head |
| #1012 | Missing-data evidence chapter draft for the paper |
| #992 | `predict_missing(se = TRUE)` — internal, gaussian; routes `quad`, `joint`, `joint_load` |
| #1021 | Route `sim` (R2) + empirical-quantile columns |
| #1013 | #985 fixed: VA start-agreement tolerance was an ABSOLUTE `1e-6` on a family-dependent objective — green on macOS, red on ubuntu CI for identical fits |
| #1029 | Route `boot` (R3) + `boot_dgp = "reml"` + waves 3 and 4 + the closing verdict |
| #1011 | #986 fixed: ordinal `type = "response"` is the expected category, not an elementwise `pnorm`; multinomial `original_row` maps through `.multinom_group_` |

## 2. The one thing to read before touching intervals

**`predict_missing(se = )` is `heuristic_unvalidated`, and that label is now
FINAL at this scale rather than provisional.** Do not "improve" it without
reading Design 119 §7–§7f first. Six variance routes were measured on ONE
identical 1,600-fit gaussian grid (n = 50 × p = 25, q = 2, four masking
mechanisms × 400 reps):

| route | conf 95% | verdict |
|---|---|---|
| `quad` (default) | 0.960–0.966 | over-covers |
| `joint` | 0.925–0.933 | under |
| `joint_load` | 0.935–0.939 | best delta route, fails |
| **`sim`** | **0.941–0.946** | **best measured, fails** |
| `boot` (B = 200, full refits) | 0.926–0.933 | fails |
| `boot` + REML DGP | 0.929–0.933 | fails; narrowed 16/16 cells |

**Why this is a finding and not a failure.** The routes BRACKET nominal, so
the estimator family contains a correct member. By `joint_load` no gradient
block remains missing (all three verified against a dense brute force). Yet
every route that propagates MORE uncertainty — the full parametric bootstrap
included — lands 1–2 points low. The last wave tested the remaining
hypothesis directly: generate the bootstrap world from an auxiliary REML fit
so the DGP is not the too-narrow ML fit. Coverage rose in **16 of 16 cells**
(uniform sign, mean +0.36 points) — real signal — but recovered only ~18% of
the gap. **So the residual lives in the fitted model at this sample size, not
in any variance formula.** 50 units against 25 traits with a rank-2 loading
matrix is a small-sample regime for a latent covariance.

That is a boundary condition worth a paragraph in the paper. It is NOT worth
a seventh route, and the maintainer's pre-registered rule (Design 119 §7e,
recorded in commit `c674cea2` and vault `3fefde2` BEFORE the data existed)
says so explicitly: narrows-but-fails → document the measured coverage and
stop. No double bootstrap.

**If you want to move this number, the lever is sample size or a different
estimator, not more propagation.** A useful next question, if anyone asks for
one: at what n does the deficit fall inside the gate? That is a new grid, not
a new route.

## 3. Standing fences — do not cross without the maintainer

- **No public interval claim exists anywhere** — not in NEWS, README, any
  article, any exported surface, any printed output. `se = ` and `se_route = `
  are internal and EXPERIMENTAL; every non-gaussian family aborts loudly.
- **`quad` remains the default route.** No existing user's numbers moved in
  this whole arc.
- **Clustered masking arms are structured MAR, never an MNAR claim.**
- **MIS-32 (MI pooling / EM engines) stays `blocked`.** MSPL refuses masks by
  design; a FIML-MSPL route is deferred and unbuilt.
- **Categorical/binary/hurdle masked-cell reconstruction is NOT accurate at
  these scales** (measured near baseline). Multinomial is the one categorical
  family that clearly beats its baseline. Do not advertise the others.

## 4. Artifacts and where they live

- **Design 119** (`docs/design/119-predict-missing-uncertainty.md`) is the
  scientific record: §7 quad, §7b joint, §7c joint_load + two self-corrections,
  §7d sim, §7e boot + the pre-registered rule, §7f the wave-4 verdict.
- **Register**: MIS-37 carries the full coverage history and the final label.
  MIS-21 (`covered`) and VA-10 (`partial`) carry the family evidence.
- **Raw campaign data**: `dev/cov119/cov119-{summary,cells}-wave*.csv` — six
  waves, same grid, comparable by construction.
- **Totoro**: the campaign lives at `~/cov119-campaign/` (repo/, Rlib/,
  harness, all wave logs). It is NOT cleaned up — reuse it rather than
  rebuilding. Launch pattern is in `dev/cov119/harness/`'s header comments.

## 5. Traps this arc actually fell into (all fixed; do not re-pay)

1. **A positional truth join** in a pre-run reported ~0.25 coverage for
   intervals actually at 0.952 — a fake six-fold failure that nearly got a
   correct route blamed. `predict_missing()` row order is NOT the designed-mask
   order. **Always join on `(original_row, trait)` with `match()`**, and assert
   no NAs. The driver does; so must any new script.
2. **A "monotonicity" test asserting the loading block must ENLARGE the
   variance was mathematically wrong** and was removed. Extending `w` in
   `w' Q⁻¹ w` admits negative cross-covariances, and λ̂/û are anticorrelated
   because only their product is identified. The empirical position-mapping
   check is the real guard.
3. **Operator precedence**: `p*d - d*(d-1) %/% 2` evaluates to 0 at `d = 2`
   because `%/%` binds tighter than `*`. Invisible at rank 1; the campaign runs
   at rank 2. It aborted 1,600 fits.
4. **A stale harness rsynced over a wired one** silently ran the WRONG route
   (2.2 s/fit and `cov90 == cov95` exactly were the tells). Stage from the
   worktree source, never from a scratchpad copy.
5. **A valid run was killed over one sampled row** where `cov90 == cov95` —
   which happens in ~5% of rows by sparse-cell coincidence. Check
   distributions, not single rows.
6. **Never renice or touch another lane's processes or worktree index.** One
   renice of a bench master propagated to its PSOCK workers (inherited at
   fork) and disturbed a concurrent lane.

## 6. State at handover

- **Open**: #1029 and #1011 merge as soon as their CI concludes (both were
  green-pending at handover; #1011 needed a merge-conflict resolution against
  the newly-landed `se_route` docs, which is committed and pushed).
- **Nothing is blocked on Shinichi.**
- **No campaign is running.** Totoro is idle of this lane's work.
- **Next arc is UNCHOSEN.** The standing candidates from the wider repo are
  the Design 66 power-study capstone (the paper's evidence chapter) and the
  MSPL programme, both owned elsewhere — check
  `docs/dev-log/handover/2026-07-25-active-lane-split.md` for current
  ownership before claiming anything.
