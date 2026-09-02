# Claude → Codex handover — 2026-08-20 (D-113 track 6 + Iwo/terrapin bug lane)

You are Codex, picking up two related lanes from a Claude Code session. The authoring chat
is gone; this document, the repo, and the linked PRs/issues are authoritative.

**START BY RUNNING** `bash ~/shinichi-brain/tools/lane_preflight.sh <repo-path>` — this repo
runs **39+ concurrent lanes**; commits land on `main` all day from other sessions. Then
reconcile this file against `git log origin/main` and classify every item below `OWED` /
`DONE` / `RETRACTED` / `PROTECTED` before touching anything.

> **MULTI-LANE REPO.** This is not the project's only active thread. The lane map at
> `docs/dev-log/handover/2026-07-25-active-lane-split.md` is authoritative for ownership —
> read it before claiming a lane, and do not assume this document represents everyone's work.

---

## Goals / mission

Shinichi's standing framing for this repo (from `AGENTS.md`/`CLAUDE.md`): finish the package
toward **0.7**, not a 1.0 push; CRAN is off the table; the filter is user-visible
completeness and honest evidence surfaces (every advertised capability needs a
`docs/design/35-validation-debt-register.md` row).

This session served two things at once:

1. **D-113 track 6** (Shinichi, 2026-08-01): *"at least one random slope for each
   distribution."* Reframed by a prior-work sweep from "unstarted" to "11/16 families
   already met, board under-reporting five of them" — see Critical Context below.
2. **A real external bug report** — `iwogross/terrapin-systematic-map` issue #1 — that
   surfaced two genuine gllvmTMB defects and cost a published analysis its correct
   specification. **He is an active collaborator, not a ticket** — the same posture the repo
   already uses for Ayumi (see the 2026-08-18 handover for that precedent).

## Critical context

1. **The board and the RAND. SLOPE column were WRONG, and are now fixed on `main`.** Five
   cells understated the package (Gamma, Beta, lognormal, student, ordinal_probit); the
   false *"ordinal RE not implemented"* annotation is gone. Random slopes are engine
   **family-agnostic** — `eta` is assembled before the family dispatch
   (`src/gllvmTMB.cpp:2468-2612`); every refusal is R-side evidence policy in
   `.augmented_slope_family_contract()` (`R/fit-multi.R:453`), per the `#388` rule that a
   family joins the allowlist only after its recovery cell passes.
2. **The campaign cost model in `docs/design/128-slope-per-family-campaign.md` was wrong by
   ~3 orders of magnitude**, and the doc now says so: the cited "2.5-3.5h" was the
   betabinomial *arc* total (authoring+review+CI), not fit time. Measured
   `truncated_poisson` fit: **20.35s**, converged, PD Hessian. These campaigns are
   **authoring-bound, not compute-bound** — a multi-seed n-ladder (the actual bar for
   `partial` -> a checkmark) now costs minutes, not hours, for the **eleven already-admitted
   families**. That is the highest-leverage next arc, bigger than adding one more family.
3. **`tweedie` is not an evidence gap, it is a documented ~44% slope-SD bias that survives
   p-fixing** (two independent citations in-repo, incl. `test-tweedie-fixed-p.R`'s header).
   Do not spend a campaign re-measuring it; it needs its own research slice.
4. **A real external user (`iwogross`) hit two genuine bugs**, both root-caused, one fixed
   and merged, one fixed and in draft PR:
   - His long-format model used **one shared intercept across 29 items** instead of 29
     per-item intercepts, because `.assert_no_augmented_lhs()` compared the LHS against the
     **literal string `"trait"`** instead of his resolved `trait = "variable"` argument
     (issue **#1188**, PR **#1193**, merged verdict pending your sign-off — see Landing State).
     Consequence for his science: LV1 loadings tracked item prevalence at **R² = 0.742**,
     falling to **R² = 0.125** once correctly specified — a published ordination axis was
     substantially a common-vs-rare gradient.
   - Our own defaults (`unit_obs = "site_species"`, `cluster = "species"`) are ecology nouns
     presented as required, so he **manufactured a column** (`paste(study_ID, variable)`) to
     satisfy them. It was row-unique (Bernoulli, unidentifiable) and had **zero effect on the
     fit** either way. Fixed as `unit_obs = NULL` / `cluster = NULL`, resolved internally,
     verified **bit-identical** logLik before/after (issue implicit, PR **#1191**).
5. **A separation-remedy estimator sweep this session found MSPL is under-tested at real
   scale and (probably) mis-scored by an earlier read.** See the dedicated section below —
   this is the freshest, least-consolidated finding and needs a second pass before any
   design-doc claim is made from it.

## What was accomplished (all MERGED to `main` unless stated)

| PR | What | Merged |
|---|---|---|
| #1157 | carried-over baton from the prior session (`known_groups` one-hot subset search) | 2026-08-18 |
| #1164 | rand-slope arc: board correction, truth ledger, interval feasibility probe, Design 128 campaign design | 2026-08-18 |
| #1166 | **`slope_sd_ci()`** new export, slice 1 (ordinary `latent()` diagonal route only) | 2026-08-18 |
| #1171 | `truncated_poisson` D-139 pre-run test: PASS (20.35s, gate lifted then reverted, `R/fit-multi.R` byte-identical to `main` after) | 2026-08-18 |
| #1175 | slice 2: `ADREPORT()` marginal slope SDs in `src/gllvmTMB.cpp`, unblocks `slope_sd_ci()` on the phylo (`theta_dep_chol`) and loadings (`theta_rr_B_slope`) routes; CI-15 `blocked` -> `partial` | 2026-08-19 (merged by a **different, concurrent Claude session** after addressing Rose's CHANGES-REQUIRED verdict — see its PR comment thread for what was fixed and what remains a static-only guarantee) |

Also filed: **#1187** (wide format 12 vs 72 in `man/` — scope decision needed on extending
the both-formats rule), **#1189** (VA+probit guidance for low-prevalence binary — needs the
MSPL findings below folded in before it is actioned), **#1190** (warn when `unit_obs`/
`cluster` are supplied but consumed by no keyword), **#1194** (`extract_Sigma_B()`/`_W()` are
`@export` + `@keywords internal` simultaneously, so their deprecation is invisible to the
users who need it).

## Landing State ledger

| Item | Branch | State | Resume |
|---|---|---|---|
| #1191 NULL tier defaults | `claude/null-tier-defaults-20260819` | **CARRIED-OVER** — pushed, PR open, DRAFT, full suite clean (`FAIL 3` — confirmed pre-existing on pristine `main` @ `147da385`, same `test-paper1-spde-slope-gauge-nofit-v2-materializer.R` failures) | Needs Shinichi's sign-off (changes the public `gllvmTMB()` signature) then `gh pr ready 1191 && gh pr merge 1191 --merge` |
| #1193 trait-literal fix | `claude/fix-1188-trait-literal-20260819` | **CARRIED-OVER** — pushed, PR open, DRAFT, full suite clean (same pre-existing 3 failures). Commit message was force-pushed over once tonight by a sibling agent that reverted a measured `R^2` figure to a stale figure-read estimate; **the current PR body has the correct measured pair restored** — do not "fix" it back | Needs sign-off, then merge |
| Draft reply to Iwo | `~/shinichi-brain/projects/terrapin-map-iwo-2026-08-19/DRAFT-reply-to-iwo.md` | **NOT POSTED** — copied out of `/private/tmp` (ephemeral) into the vault for safety. Needs Shinichi's review before anything goes to the public issue thread | Read it, edit if needed, post manually to `iwogross/terrapin-systematic-map#1` |
| Terrapin estimator sweep raw logs | `~/shinichi-brain/projects/terrapin-map-iwo-2026-08-19/*-RESULTS.txt` | landed (vault, local-only, no remote per D-37) | see MSPL section below |
| `~/shinichi-brain` (this session's memory writes) | local `master` | **LANDED per D-37** — this vault has no remote by design; a clean local commit IS landed state. Do not push it or ask about pushing | `git -C ~/shinichi-brain log --oneline -5` |
| ~10 scratch worktrees under `/private/tmp/gllvmtmb-*` and `/private/tmp/terrapin-*` | n/a | **EPHEMERAL, safe to discard** — everything durable from them is on `main`, in the two open PRs, or copied to the vault above | none needed |
| Foreign lanes (60+ branches flagged by `handoff_gate.sh`: `cursor/mspl-*`, `docs/mspl-*`, `tmp/rebase-*`, `worktree-agent-*`, etc.) | various | **NOT THIS LANE'S** — pre-existing, unrelated to tonight's work, do not touch | Leave alone; ownership is the lane map's business |

## MSPL / separation-estimator sweep — the freshest finding, needs a second pass

Triggered by Shinichi asking whether MSPL (opt-in `estimator = "mspl"`, a numerical Jeffreys
log-determinant + loading penalty, ported from Kosmidis & Firth 2021) would have been the
right tool for Iwo's Heywood case instead of `loading_ridge`. Measured on his real data
(406 papers x 29 items, `d=1`, per-item-intercept spec, `binomial`):

| Route | link | max\|loading\| | max\|b_fix\| | time | note |
|---|---|---|---|---|---|
| Laplace | probit | 19.05 | 13.7 | 46s | baseline |
| Laplace + `loading_ridge=0.5` | probit | **1.61** | *not measured* | 33s | tidy number, but the package's OWN runaway diagnostic still fired (Toxicology, `saturated_fit=1`) |
| AGHQ(k=5) + `loading_ridge=0.5` | probit | 1.61 | *not measured* | 56s | `loading_ridge` is an alias for `aghq_ridge` -- same penalty; confirms the ridge dominates integration choice for stability |
| MSPL | probit | 16.79 (-12%) | **6.59 (-52%)** | 984s | |
| VA (`integration="va"`), no ridge | probit | **3.47** | *param names/convergence flag not exposed the way Laplace fits expose them -- see below* | ~130s | robust, no tuning param |
| Laplace | logit | 61.94 | 26.6 | 49s | link matters a LOT for the degeneracy magnitude |
| MSPL | logit | 37.90 (-39%) | **15.51 (-42%)** | 771s | |
| Laplace | cloglog | 18.86 | 6.78 | 36s | |
| **MSPL** | **cloglog** | — | — | **3334s (55.5 min), THEN ERRORED** | admitted by the family/link fence, broken in practice at this scale |

**Corrections to earlier claims made mid-session, both real:**
- **"MSPL barely shrinks" was WRONG**, scored on `max|loading|` alone. Once `max|b_fix|` was
  added, MSPL cuts the fixed-effect separation by **42-52%** in both logit and probit — a
  real, substantial effect. Firth-type penalties primarily target fixed effects, not
  loadings; this was the right quantity to have measured from the start.
- **The "VA vanished with no output" mystery earlier in the session was almost certainly a
  bug in the ad-hoc measurement scripts, not in gllvmTMB.** `f$opt$par` for a VA fit has
  **empty names** and `f$opt$convergence` came back blank when probed the same way as a
  Laplace fit — a diagnostic script that assumed the Laplace naming convention crashed
  silently. `max|loading| = 3.466` was independently confirmed twice and is solid; **whether
  VA fit objects SHOULD expose `opt$par` names / a convergence flag the same way Laplace
  does is an open, unresolved question** — could be intentional (different internal
  representation) or a real API-consistency gap. Needs a clean look at the VA fit object's
  actual structure, not another ad-hoc probe.

**Two things that are NOT yet resolved and should not be asserted as fact:**
- **MSPL's separation-ADMISSION machinery is explicitly parked** — `R/mspl.R` says outright:
  *"Admission gate: DELIBERATELY NOT IMPLEMENTED. The softness-ratio / N2'-curvature /
  separation admission conditions belong to the parked calibrated construction (D-157;
  Design 125), not to this probe."* So MSPL's weak-relative-to-hoped-for shrinkage on
  probit/logit may be **expected** given what is and isn't built yet, not a bug. The
  cloglog crash is a different matter — that family/link IS inside the stated fence
  (`R/mspl.R:244`) and it broke after 55 minutes, which is a genuine defect worth its own
  issue with the actual error text (truncated in the scratch scripts — a clean re-run
  capturing the FULL `try()` condition object is needed, budgeting for another ~1h wall
  clock given the pattern above).
- **MSPL's entire test base (39 files) is toy-scale** — modal fixture `n_site <- 8L`,
  largest `n_site <- 50L`, and **exactly one of the 39 files uses `link = "probit"`**
  (17 use `log`, 8 `logit`). Both real datasets this repo has reanalysed
  (Ayumi's 191x73, Iwo's 406x29) are **probit**. MSPL has essentially never been run at a
  scale or link combination matching either real dataset before this session. Full
  reasoning and the toy-scale evidence table: `~/shinichi-brain/memory/2026-08-19-mspl-toy-scale-only.md`.
- **MSPL was never run on Ayumi's data at all** (`grep -ril mspl` over her whole reanalysis
  returns nothing). Her map is 191x73 — comparable row count to Iwo's, more traits — and her
  `d=3` degeneracy is FULLY CHARACTERISED already (loading 146, communality exactly 1.000,
  converged, PD Hessian, AIC prefers it, BIC prefers d=1). That is a much stronger test case
  than Iwo's (known ground truth) and was the obvious next step, not yet run.

**Concrete next steps for this thread, in order of leverage:**
1. Run MSPL on Ayumi's known-degenerate `d=3` fit (scripts/data at `/private/tmp/ayumi-reanalysis/`
   if still present, else `~/shinichi-brain/projects/ayumi-urbanisation-map/`) — the strongest
   available test of whether MSPL rescues a fully-characterised real Heywood case.
2. Re-run cloglog MSPL capturing the FULL error condition (not just the first line) — budget
   ~1h wall clock given tonight's pattern, or profile-instrument it rather than blind-retry.
3. Resolve the VA `opt$par`/`opt$convergence` structure question directly from the fit
   object's source, not another crash-prone probe.
4. Only after 1-3: decide whether issue #1189 (VA+probit guidance) should also mention MSPL,
   and whether a "MSPL is toy-scale only" issue should be filed against `R/mspl.R` /
   `docs/design/125-*` (Design 125 is the parked calibrated construction referenced above —
   read it before filing, it may already say this).

**Do NOT present any of the above as a finished conclusion about MSPL's viability** — it is
a first real-scale exposure, not a completed evaluation. The Ayumi run (step 1) is the thing
that would turn "suggestive" into "characterised."

## Files created / modified (this session's own diff, `main`-relative)

Merged (already on `main`, listed for completeness — do not re-touch unless correcting):
`docs/dev-log/capability-surface.html`, `docs/design/61-capability-status.md`,
`docs/design/128-slope-per-family-campaign.md` (+ its correction addendum),
`R/slope-sd-ci.R` (new), `man/slope_sd_ci.Rd` (new), `tests/testthat/test-slope-sd-ci.R` (new),
`docs/design/35-validation-debt-register.md` (CI-14/CI-15 rows),
`src/gllvmTMB.cpp` (ADREPORT additions, slice 2), various `dev/` and
`docs/dev-log/after-task/` records, `docs/dev-log/check-log.md`.

Open, in the two draft PRs: `R/gllvmTMB.R` (#1191 — NULL defaults + error-message fix),
`R/brms-sugar.R` (#1193 — six `.assert_no_augmented_lhs()` call sites),
`tests/testthat/test-null-tier-defaults.R` (new, #1191),
`tests/testthat/test-1188-trait-col-augmented-lhs-guard.R` (new, #1193).

## Next Immediate Steps (OWED, in order)

1. **Get Shinichi's sign-off on #1191 and #1193**, then merge both — both are user-facing
   API/behaviour changes (public signature default, parser guard behaviour) that CLAUDE.md's
   merge rules put above what any agent should merge unilaterally, even with prior
   blanket authorisation for the docs/R work earlier in the session.
2. **Review and, if it holds up, post the draft reply to Iwo** — `~/shinichi-brain/projects/terrapin-map-iwo-2026-08-19/DRAFT-reply-to-iwo.md`. It currently references the R² correction, the VA+probit recommendation, and the "your specification was wrong, and it is our bug" framing. **Update it once MSPL's status is clearer** — it currently and deliberately does NOT mention MSPL (Shinichi: "we should not mention to Iwo as this will confuse him"), and that instruction should still hold even after further MSPL work, unless he says otherwise.
3. **Run the Ayumi-data MSPL test** (see MSPL section, step 1) before drawing any conclusion about MSPL's practical viability.
4. **The multi-seed n-ladder for the 11 already-admitted slope families** — the highest-leverage D-113 track 6 work remaining, now that the cost model is corrected (minutes, not hours, per family). No design doc for this exists yet; Design 128's structure (§4 pre-run test spec, §5 wall-clock estimate discipline per D-139) is the template to reuse.
5. **Issue #1187's scope decision** (extend both-formats rule to `man/`) needs Shinichi, not an agent — do not sweep `man/` unilaterally.

## Blockers / open questions (Shinichi's, not yours)

- Sign-off on #1191, #1193 (item 1 above).
- Whether the draft reply to Iwo should reference the (still unpublished) Ayumi pattern-match — the current draft keeps it anonymised as "another binary systematic map", no names or numbers that identify it. His call whether even that much is right.
- #1187's roxygen-scope decision.
- Whether a `Sigma_B`/`Sigma_W` -> canonical-vocabulary sweep across vignettes/articles (part of #1194) is worth doing now or deferred.

## Gotchas

- **Sub-agents in this session repeatedly stalled waiting on their own background R
  processes rather than polling or running in the foreground**, four separate times. If you
  dispatch similar work, budget for driving long R fits yourself or explicitly instruct
  against backgrounding inside a spawned agent's own tool calls.
- **Two agents shared one worktree twice tonight** (once on the slice-2 build, once
  apparently on #1175's post-merge fix by a different concurrent session) — verify a
  worktree's actual `git log`/`git status` before trusting a "done" report; a fresh reviewer
  auditing mid-write will get inconsistent results.
- **An agent force-pushed over a coordinator's commit once**, replacing a measured `R²`
  figure with an earlier, weaker figure-read estimate, because it could not see the sibling
  agent's measurement and judged the better number "unverifiable." The PR body has been
  restored with the correct figure and provenance; if you see `R² = 0.882` / `0.78` anywhere
  for this dataset, that is the SUPERSEDED figure-read number — the measured pair is
  **0.742 -> 0.125** (his spec vs. corrected spec).
- **A concurrent-lane CPU-contention artefact produced a spurious 4.5x `sdreport()`
  slowdown** earlier in this session (resolved via an alternating-build A/B) — the general
  lesson: never trust a single before/after timing on this shared, heavily-loaded machine;
  timings taken while multiple R jobs run concurrently (as in the MSPL sweep above) are
  **not comparable to each other** for the same reason.
- **`aghq_ridge`/`loading_ridge` = 0 is REJECTED, not "no ridge."** The normalizer
  (`R/aghq-auto-ridge.R:9`) accepts `"auto"` or a strictly positive number; "off" is spelled
  `Inf` (flat prior). Backwards from intuition — worth its own small issue if not already filed.
- **`docs/dev-log/check-log.md` is the shared append surface every lane writes to** — expect
  a merge conflict on any PR touching it; resolve by keeping BOTH sides' entries, never
  picking one.
- **A green CI check can belong to a superseded commit** under this repo's lane traffic —
  always re-verify `headRefOid` matches the SHA CI actually ran on, immediately before
  merging, not from an earlier check.

## How to resume

```bash
cd <your worktree off origin/main>
bash ~/shinichi-brain/tools/lane_preflight.sh .
git fetch origin main && git log origin/main --oneline -10
gh pr view 1191 --json isDraft,mergeStateStatus,headRefOid
gh pr view 1193 --json isDraft,mergeStateStatus,headRefOid
```

**Toolchain (Codex-native, live R/TMB):**
```bash
export NOT_CRAN=true
# this repo's tests use NOT_CRAN=true throughout; some also gate on
# GLLVMTMB_HEAVY_TESTS=1 for phylo/spatial recovery cells (heavier, ~minutes each)
Rscript -e 'devtools::load_all(quiet=TRUE)'          # load without installing
Rscript -e 'NOT_CRAN=TRUE; devtools::test()'         # full suite, ~40 min, run detached
Rscript -e 'devtools::document(); pkgdown::check_pkgdown()'
```

Campaigns/heavy runs: never on GitHub Actions (D-50); Totoro capped at 150 cores (D-143,
pin `OPENBLAS_NUM_THREADS=1`); estimate before any run > 30 min and show a pre-run test
before committing to it (D-139) — Design 128 §4 is the worked template, including its own
correction after the first attempt was itself found unexecutable.
