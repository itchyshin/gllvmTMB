# Lane starter — MISSING-DATA lane (lane 3), gllvmTMB, 2026-07-28

Written for a fresh session opening the **third** concurrent lane. Paste §4 to start.

This supersedes the missing-data scope in
`docs/dev-log/handover/2026-07-28-lane-starter-parallel-lanes.md` §3-D, **whose premise is
false** — see §2.

---

## 1 · The three-lane map (do not narrow it)

| Lane | Branch | Owns | State |
|---|---|---|---|
| 1 | `claude/sigma-intervals-boundary-20260728` | interval machinery (fenced set below) | **PR #802 OPEN** — do not merge, do not edit |
| 2 | `claude/docs-honesty-20260728` | reader surfaces: `vignettes/` (**except** `missing-data.Rmd`), `README.md`, `_pkgdown.yml`, unfenced `man/*.Rd`, roxygen in unfenced `R/` | **MERGED** (PR #805) — closed, not a live writer |
| 3 | **this lane** | `vignettes/articles/missing-data.Rmd`, `R/missing-predictor.R`, `R/gllvmTMB-wide.R` (missing-data paths), `tests/testthat/test-missing-*.R`, `man/{predict_missing,impute_model,imputed}.Rd` | opening |

**Lane 1's fenced files — this lane must not edit any of them:**

```
R/profile-ci.R          R/coverage-study.R      R/gllvmTMB.R
R/fit-multi.R           R/aghq-control.R        R/confint-inspect.R
R/z-confint-gllvmTMB.R  NEWS.md
man/gllvmTMBcontrol.Rd  man/confint_inspect.Rd  man/tmbprofile_wrapper.Rd
tests/testthat/test-profile-ci-level-budget.R
tests/testthat/test-profile-bounds-terminus.R
tests/testthat/test-profile-bounds-zeta.R
tests/testthat/test-coverage-study-nonfinite.R
tests/testthat/test-aghq-control-wiring.R
```

Reading them is fine. **`R/gllvmTMB.R` and `R/fit-multi.R` are fenced but carry missing-data
logic** — if this lane needs to change them, ask on PR #802 first; do not edit unilaterally.

**Totoro is at the 150-core cap** with lane 1's campaign. Start nothing there.

## 2 · 🔴 The lane-D premise in the old starter is WRONG

The old starter says missing-data is *"the likely cheapest high-value gap … users are told
nothing about NA handling."* Every part of that is false. Verified on `origin/main` @ `869e92b5`:

| Claim in old starter | Actual |
|---|---|
| "users are told nothing" | `vignettes/articles/missing-data.Rmd` is **314 lines**, titled *"Handling missing data"* |
| implied: no machinery | `R/missing-predictor.R` is **2,859 lines** |
| implied: nothing exported | **3 exports** — `predict_missing` (NAMESPACE:157), `impute_model` (:112), `imputed` (:113), plus `S3method(imputed, gllvmTMB)` (:7) |
| implied: undocumented | **3 man pages** — `predict_missing.Rd`, `impute_model.Rd`, `imputed.Rd` |
| implied: untested | **13 test files** (listed in §3) |

The article's own description promises three strategies: *"Choose among omitted, retained, or
explicitly modelled missing values and verify how each choice changes the estimand and fitted
rows."*

**So this lane is an AUDIT of a large existing subsystem, not gap-filling.** The question is not
"what happens?" but **"does the shipped machinery do what the article tells users it does?"**

That reframing matters for scope: gap-filling would be write-a-vignette work; auditing is
read-the-code-then-write-failing-tests work.

## 3 · What is VERIFIED vs what is the lane's JOB

**Verified by direct inspection** (facts you may rely on):

* the file sizes, export list, man pages, and article title in §2
* the 13 test files:
  `test-binomial-cbind-missing-response.R`, `test-lv-missing-response.R`,
  `test-missing-data-robustfix.R`, `test-missing-data-robustness.R`,
  `test-missing-predictor-{binary,categorical,gaussian,ordered,phylo}.R`,
  `test-missing-response-{gaussian,nongaussian,traits}.R`, `test-missing-response.R`
* `predict_missing()` is referenced from `R/gllvmTMB.R:55,307,1318` and
  `R/gllvmTMB-wide.R:158`; the latter comments that NA cells are dropped "out of the
  likelihood (and `predict_missing()` can return them)"
* `R/missing-predictor.R:2565` roxygen distinguishes itself from `predict_missing()` as
  operating "at the level, not the data"

**NOT established — this is the lane's actual work.** Do not assume any of it:

1. **Does the article match the code?** Every behavioural claim in the 314 lines, checked
   against the implementation.
2. **Default behaviour, stated plainly.** If a user passes data with NAs and sets nothing, what
   happens — dropped, errored, or silently passed? **Are they told at call time?** Silent
   row-dropping that changes the estimand without a message is the highest-value finding
   available here.
3. **Do long-format and `traits(...)` wide-format AGREE?** Same data, two shapes — same observed-row
   set, same fit, same accounting? `R/gllvmTMB-wide.R:158` is the thread to pull.
4. **What do the 13 tests actually pin** versus merely smoke-test, and which are skipped by
   default (`skip_on_cran`, `skip_if_not_installed`)? Name the uncovered cells.
5. **`impute_model()` / `imputed()` contract** — these are exported and the old starter did not
   know they existed. What do they promise, and is it honoured?

An audit that returns "the docs are accurate" is a **valid and valuable result**. Do not
manufacture findings.

## 3a · Scoping audit results — 3 confirmed leads, 4 killed

A read-only scoping audit ran on 2026-07-28 (14 agents: 6 auditors → reconciler → one
adversarial refuter per candidate, each instructed to default to *refuted*). It produced **7
candidates; 4 were refuted on inspection.** The 3 survivors below are **leads, not findings**.

> ⚠️ **NONE OF THIS WAS EXECUTED.** Every claim is from reading source, not from running a fit.
> That is precisely why lane 3's first move is *write the failing test*. Treat each as
> `AGENT-INFERRED` until a test reproduces it at runtime. If a test does not reproduce it, the
> lead is wrong — say so and delete it.

### Lead A (HIGH) — `gllvmTMB_wide()` drops NA response cells silently

`R/gllvmTMB-wide.R:218-221` strips NA cells with **no `cli_inform`, no warning** (grep for
`cli_inform`/`cli_warn` in that file returns nothing) — while the long path and the `traits()`
path both message for the same event (`R/traits-keyword.R:448-452` emits
`traits(): dropped N (trait, row) cell(s) with NA response.`). `man/gllvmTMB_wide.Rd` never
mentions NA response handling; its `Y` argument documents only "A `n_units × n_traits` numeric
matrix of responses".

*User impact:* rows vanish from the likelihood with no signal at all. **This is the
silent-estimand-change finding §3 predicted was the highest-value one available here.**

Note `gllvmTMB_wide()` is soft-deprecated (CLAUDE.md), which bears on the **fix** (message vs
document vs leave) — but not on whether the behaviour is currently undisclosed.

### Lead B (HIGH) — docs promise a guard on missing grouping variables that does not exist

`man/gllvmTMB.Rd:51` (roxygen `R/gllvmTMB.R:56`) and `man/gllvmTMB.Rd:373` (roxygen
`R/gllvmTMB.R:310-312`) both state *"Ordinary missing predictors, grouping variables, and
design-matrix values still error."* The predictor half is real. **The grouping half is not:**
`R/gllvmTMB.R:662-667` coerces the trait/unit columns with `factor()` and no NA check, and
`R/gllvmTMB.R:683-687` then builds `site_species` by `paste()` — so an NA propagates into the
factor and into the TMB integer index.

*User impact:* a user reads that the fit will fail loudly, does not pre-clean the column, and
gets an opaque TMB failure — or a bad index — instead of the promised error. **This is the most
serious of the three: a documented safety guarantee with no implementation behind it.**

*Suggested first test:* long-format fit, one NA in the `unit` column, assert a clear error.
Watch for the case where it currently neither errors nor warns.

### Lead C (MEDIUM) — `predict_missing()` on an AGHQ fit, with a suppressible warning

`predict_missing()` delegates wholly to `predict()` (`R/methods-gllvmTMB.R:1816`), which on an
AGHQ fit returns fixed-effects-only predictions omitting the unit's latent contribution. The
guard `.aghq_warn_re_gap(object, "predict()")` at `R/methods-gllvmTMB.R:1604` hard-codes the
label `"predict()"` and is registered **once per session under that label** — so a prior
`predict()` call suppresses the warning for the later `predict_missing()` call. The man page
never mentions AGHQ.

*User impact:* `est` is read as a per-unit reconstruction of the missing cell but is
systematically missing the latent score — the exact purpose the extractor exists for.

### Killed — do NOT re-derive these four

Each was refuted by an agent that opened the files. Recorded so lane 3 does not spend time on
them:

1. **`predict_missing()` returns zero rows under default `drop` mode without warning.** The
   code half is right, but four of the five cited doc locations explicitly scope the promise to
   `response = "include"` (`man/gllvmTMB.Rd:243-248`, `:47-50`, `:365-371`;
   `man/predict_missing.Rd:26-32`). Not a doc/code contradiction.
2. **Wide `fit$missing_data` under-reports `n_dropped`.** Real code asymmetry, but the doc
   locations naming that slot are scoped to include-mode, and `missing_data` appears nowhere in
   `vignettes/`. Worth a *bug* report; not a documentation defect.
3. **`type = "response"` returns the probit latent scale for `ordinal_probit`.** Misread:
   `R/methods-gllvmTMB.R:338` is `out[i] <- stats::pnorm(e)`, which *applies* the inverse link.
   The agent believed the code's own loose comment instead of the expression under it. What
   survives is one imprecise gloss ("conditional mean") at `man/predict_missing.Rd:13`.
4. **Wide and long declare different factor level sets.** Overstated — the refuter found
   `R/traits-keyword.R:435` re-pins the full trait level set after the pivot. Divergence needs
   an *entirely* NA wide row, and with a factor `unit` column even that mostly agrees. Neither
   cited doc location claims level-set equivalence.

**Read the kill list as calibration:** more than half of a careful audit's candidates did not
survive contact with the source. Expect the same of your own.

## 4 · Copy-paste opener

```
Open the MISSING-DATA lane on gllvmTMB — this is a THIRD concurrent lane, not a switch.
Lane 1 = PR #802 (interval machinery, OPEN). Lane 2 = claude/docs-honesty-20260728.

FIRST read the lane starter IN FULL. It has the three-lane map, lane 1's fenced file list, and
— critically — §2, which documents that the OLDER starter's missing-data scope is factually
wrong. Do not work from the older one.

    docs/dev-log/handover/2026-07-28-lane-starter-missing-data.md

  (It is on main as of PR #805. If that path is missing, list what exists — do NOT fall
  back to the older parallel-lanes starter, whose missing-data scope is wrong:
    git ls-tree origin/main docs/dev-log/handover/ | grep missing)

Set up: git worktree add /private/tmp/gllvmtmb-missing-data -b claude/missing-data-20260728 origin/main

THE JOB: audit, not gap-fill. gllvmTMB has a LARGE existing missing-data subsystem —
R/missing-predictor.R (2,859 lines), 3 exports (predict_missing, impute_model, imputed),
3 man pages, a 314-line article, 13 test files. Establish whether the shipped machinery does
what vignettes/articles/missing-data.Rmd tells users it does. The highest-value question:
if a user passes NAs and sets nothing, what happens by default, and are they TOLD at call time?
Silent row-dropping that changes the estimand without a message is the finding worth having.

DO NOT re-attempt (settled, other lanes): the chi-bar-square boundary correction (points the
wrong way, 2.706 vs 3.841); boundary detection (unimplementable under log-SD); any claim a
coverage certificate exists (disposition is WITHHELD — read the after-task record, NOT
decisions.md:2130-2135, which overstates it); any "first to profile a low-rank covariance"
novelty claim (SAS GLIMMIX COVTEST TYPE=PLR predates us).

DISCIPLINE:
  * QUERY THE BRAIN BEFORE BUILDING (/ask-brain, or shinichi-brain MCP with
    search_all_projects: true). drmTMB ran an equivalent docs-accuracy audit on 2026-07-11
    (docs/dev-log/dashboard/2026-07-11-docs-accuracy-audit.md) — read its METHOD before
    inventing one. Its lesson: the surface erred toward UNDER-claiming, and the real damage was
    broken examples, not adjectives.
  * Check the PRIMARY source, not the summary citing it. That error cost a full day here.
  * An agent's confident file:line is NOT evidence; open the file yourself.
  * macOS BSD `grep -E` silently ignores \b word boundaries and returns ZERO matches. Never use
    \b; verify every zero result a second way. This produced two false "clean" findings today.
  * Test-first: write the failing test that pins the real behaviour before changing anything.
  * No internal register codes (CI-xx, D-xx, Design NN, Phase NN) on reader surfaces.
  * No coverage claim, anywhere.
  * Totoro is at its 150-core cap (lane 1's campaign). Start nothing there. Local cap 6-8.
  * Verify R jobs with `ps aux | grep exec/R`, NEVER `pgrep -f Rscript` (reports 0 for healthy jobs).
  * Local devtools::test() / rcmdcheck before pushing — not CI-first.
  * Never `git add -A`. Scoped staging only.
  * Run tools/lane_preflight.sh . at orient AND before claiming the lane; state the line
    PLATFORM / LANE / FOREIGN LANE.

FIRST ACTION: open docs/dev-log/capability-surface.html and show it to Shinichi (CLAUDE.md
step 0), then read the starter above.
```

## 5 · Shinichi's call, not an agent's

1. **`vignettes/articles/missing-data.Rmd` is contested** between lane 2 (reader surfaces) and
   lane 3 (missing-data). It is assigned to **lane 3** above, and lane 2 has fenced it out. If
   you want it the other way, say so before both lanes are running.
2. **`R/gllvmTMB.R` and `R/fit-multi.R` are lane 1's**, but carry missing-data logic. If the
   audit finds a defect there, it is a cross-lane change and yours to sequence.
3. **`CLAUDE.md` is stale**: it says `DESCRIPTION`/`NEWS` "still read 0.5.0". `DESCRIPTION`
   reads **0.6.0** on `origin/main`. Unowned by any lane — assign it.
