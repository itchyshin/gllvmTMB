# Codex handover — CRAN release-evidence audit (2026-07-19)

**You are Codex, picking up gllvmTMB after a read-only release-evidence audit run by Claude.**
This document stands alone: you will never see the authoring chat. Everything you need is here or
linked from here.

**Author:** Claude Code · **Date:** 2026-07-19 · **Branch of authorship:**
`claude/profile-coverage-remeasure-20260718` (28 commits *behind* `main`, 50 ahead) ·
**`main` at handover:** `ff045a38` ("docs: add high-dimensional inference pre-code gates (#771)")

> **This is a sibling handover, not a replacement.** `docs/dev-log/handover/2026-07-19-codex-handover.md`
> (the 0.6-finishing lane map) and the three Codex handovers already on `main`
> (`2026-07-19-codex-aghq-o3-handoff.md`, `-gaussian-reml-reconciled.md`, `-highdim-inference-r0-r2.md`)
> remain live. This doc covers **only the release-evidence lane** and does not narrow or supersede them.

---

## 1. Mission / why this session existed

Establish the **exact CRAN/publication rung** for gllvmTMB — not to make it ready by assertion.
Run under the fail-closed CRAN release gate (`~/shinichi-brain/protocols/cran-release-gate.md`, D-49):
default verdict **NOT READY** until every applicable gate has direct evidence for **one frozen tarball**.

**Constraint honoured throughout: read-only.** No package code, tests, `DESCRIPTION`, `NAMESPACE`, `src/`,
workflows, or CI settings were modified. No simulations run. Parked lanes (CI-11, multinom/tier-2a, Ayumi,
Bartlett) were excluded by instruction and not touched.

---

## 2. The finding, in one line

**Release rung: NOT READY — and specifically *below* `source-clean`, the first rung on the ladder**
(`source-clean → tarball-clean → platform-clean → submission-ready → submitted → confirmed →
incoming-passed → accepted → archived → live-with-check-page`).

Not because the package is weak. Because the evidence chain has **no first link**: **no built tarball
exists anywhere on disk.** Searched repo root, parent, `$HOME` (depth 6), `/tmp`, Desktop, Downloads — no
`gllvmTMB_*.tar.gz`, no `gllvmTMB.Rcheck/`, no `00check.log`. Nine *other* packages' `.Rcheck` directories
are present (pigauto, freqTLS, hsquared, clade, prepR4pcm, orchaRd, alifeR, specieshindex, phyloTraitData),
so the absence is specific, not a failed search.

With no artifact there is nothing for platform evidence to be *about*, nothing to freeze under Gate 5, and
nothing for a Gate-7 adversarial panel to audit.

**The gap to submission is evidence, not capability.**

---

## 3. What is YOURS (live toolchain — route to Codex)

Claude plans/audits/writes prose; **you run the live R/TMB toolchain**. These need a real compiler:

### 3a. The nightly `full-check` has been RED for 7 nights — highest-value item

Last green: run **29185501668, 2026-07-12 @ `5b99421f`**. Every night 07-13 → 07-19 failed. **Predates both
the REML and AGHQ arcs** — not fallout from recent work, but nobody has triaged it. 07-19 run 29679435429:
`[ FAIL 45 | WARN 10 | SKIP 109 | PASS 11807 ]`, `Status: 1 ERROR`. **44 of 45 identical** to the previous
night — stable and reproducible, not flaky.

Clusters, ranked by how much each smells like a real bug rather than test drift:

| Test file | n | Symptom |
|---|---|---|
| `test-profile-proportions.R` | 9 | `'profile_ci_proportions' is not an exported object from 'namespace:gllvmTMB'` — looks like fallout from `660b9178` ("trim unfinished public exports for 0.5.0 surface"). **Release-relevant**: either the export returns or the tests go. |
| `test-extract-sigma-spde-base-slope.R:145–156` | 6 | `spatial_indep(1 + x \| coords)` returns 6×6 (3-trait) `Sigma` where a diagonal 2×2 block is expected; `es$level` is `"spde_dep"` not `"spde_base_slope"`; off-diagonals non-zero (−14.4, −0.045). **Shape/routing regression, not tolerance.** |
| `test-phylo-indep-slope-spike.R:134–183` | 5 | `fit$tmb_data$n_lhs_cols` is 6 not 2; `sd_b`/`cor_b` return 6×6 (36-element) instead of a pinned 2-trait diagonal. **Same symptom family as the spatial one — check whether one cause explains both.** |
| `test-matrix-poisson-unit.R` | 6 | `.ec_unit_finite(fit)` is `FALSE`, expected `TRUE`. |
| `test-confint-derived.R` · `test-m1-4-extract-correlations-mixed-family.R` · `test-matrix-ordinal-unit.R` | 4+3+2 | Withdrawn nonlinear-profile paths: `cli_abort`s firing **as designed** ("penalty-based constrained-refit prototype has been withdrawn…"); tests not updated to expect the new message. **Cheapest cluster to clear**; the ordinal two are only a regex mismatch. |
| `test-binomial-slope-recovery.R:188/197` | 2 | `vapply(res, function(r) r$rho, numeric(1))`: result is length 36, not 1. |
| `test-bootstrap-Sigma.R:51` | 1 | New on 07-19 only; returned names lack `n_effective` / `boot_median`. |

**Why this stays hidden:** these only run under `GLLVMTMB_HEAVY_TESTS=1` (set by `full-check.yaml`, not by
`R-CMD-check.yaml`). The fast PR/`main` lane stays green and conceals them. **A green `R-CMD-check` does
NOT mean the suite is healthy** — different claims, easy to conflate.

### 3b. The release slice (when someone takes the release lane)

Fully specified, blocked on nothing but execution. **Must be run from a CLEAN checkout at a committed
commit** (Gate 3 — `git status --porcelain` empty), not from a dirty working tree:

```sh
export NOT_CRAN=true
Rscript --vanilla -e 'devtools::document()'
Rscript --vanilla -e 'devtools::test()'
Rscript --vanilla -e 'pkgdown::check_pkgdown()'
Rscript --vanilla -e 'urlchecker::url_check()'      # 4 DOIs + 2 URLs in DESCRIPTION, never checked
R CMD build .
R CMD check --as-cran --run-donttest gllvmTMB_0.6.0.tar.gz
```

Do **not** set `_R_CHECK_FORCE_SUGGESTS_=false` for the claim-bearing check (Suggests is 30 packages).
Then bump `DESCRIPTION` + `NEWS.md` `0.5.0 → 0.6.0` (see §4), rewrite `cran-comments.md` **from that log**,
and freeze one candidate recording: absolute path, SHA-256, byte size, entry count, full tarball inventory
+ forbidden-path scan, generating commit, and the empty `git status --porcelain`.

**Sequencing constraint:** a Gate-5-valid candidate needs the 0.6.0 bump **committed** first. A tarball
built from an uncommitted bump is a dry run, not a candidate.

### 3c. WINDOWS FAILS A REAL TEST — the run completed after this doc was first written

3-OS `R-CMD-check` on `main` @ `ff045a38`
([run 29704770522](https://github.com/itchyshin/gllvmTMB/actions/runs/29704770522)) — the first
macOS/Windows evidence since 2026-07-12. **It has now COMPLETED and it found a blocker.**

| Leg | Result | Reading |
|---|---|---|
| `ubuntu-latest` | **success** | Clean. |
| `macos-latest` | failure | **NOT a package result** — died in `actions/checkout@v5` on a network timeout (`curl 56 Recv failure`; `Failed to connect to github.com port 443 after 75004 ms`), three retries, before R started. **macOS remains UNKNOWN, not red.** |
| `windows-latest` | **failure — REAL** | Failed inside `check-r-package@v2`. `Status: 1 ERROR`; `1 error ✖ \| 0 warnings ✔ \| 0 notes ✔`. |

**The Windows failure:**

```
── Failure ('test-example-behavioural-reaction-norm.R:316:3'):
   behavioural reaction-norm audited fit passes curvature checks ──
```

- **Ubuntu passed this same test in the same run** → **platform-specific**, most likely a numerical /
  BLAS-landing difference on Windows rather than a logic bug.
- It is a `Failure` (expectation not met), **not** an `Error` (crash).
- **This is the FAST lane** — `GLLVMTMB_HEAVY_TESTS` is unset — so it is **NOT** one of the 44 nightly
  failures in §3a. It is a **separate, previously-unseen Windows-only failure in the default suite**, hidden
  simply because Windows had not run in a week.

**A re-run of both failed legs was dispatched** (`gh run rerun 29704770522 --failed`) and was **still
in flight when this doc was last updated**. **Check it.** It answers the question that decides the fix:
**is the curvature failure deterministic, or a flaky optimiser landing?** Deterministic → a real
Windows-specific defect to fix. Flaky → a tolerance/seed problem in the test.

**Second Windows signal — timing:** `checking tests` ran 21:51:55 → 22:03:33 ≈ **11.6 min**; the whole check
≈ **15 min** (`install` 154s, `examples` 15s, `--run-donttest` 22s, vignettes OK). CRAN's observed Windows
incoming threshold is ~10 min, and **a total in this range is a blocker even when the status is only a NOTE**
(release-gate Gate 2). This needs a measured per-vignette/per-example timing budget before submission.

**Consequence for the rung:** still **NOT READY**, but the reason list grew. It was "no tarball." It is now
also **"the default suite does not pass on Windows"** — which must be resolved *before* a candidate is worth
freezing at all. Sequencing: fix Windows → then §3b.

---

## 4. Key decisions made this session

### D-66 — the first CRAN release is `0.6.0`, not `0.5.0`

Issue [#772](https://github.com/itchyshin/gllvmTMB/issues/772) (closed); recorded durably as **D-66** in
`~/shinichi-brain/memory/DECISIONS.md`.

D-42 (2026-07-11) settled the **principle** *"first release is a 0.x, NOT 1.0"* and named `0.5.0`. The
**number** is superseded by the 0.6 strategy — which is why the premature `v0.5.0` tag was dropped. D-42's
other half stands unchanged: **1.0 remains reserved** for capability-maturity (complete surface + full story
+ committed-stable API), mirroring drmTMB's D-40.

**What this means for you concretely:**
- `DESCRIPTION`, `NEWS.md`, `README.md` and the live site keep reading `0.5.0` — that is the **dev-cycle**
  number, not a release commitment. **Do not bump them ad hoc.**
- The bump to `0.6.0` happens **as part of the release slice** (§3b), not before.
- **Any NEWS entries you write for current work land under the `0.6.0` heading.**

### #773 withdrawn — the "D-50 artifact breach" was a false premise

Issue [#773](https://github.com/itchyshin/gllvmTMB/issues/773), closed as not-planned. I filed it claiming
8,256 live artifacts ≈ 39.4 GB breached D-50's "hard 2 GB/month cap." **Wrong.**
`itchyshin/gllvmTMB` is a **PUBLIC** repo, and GitHub Actions on public repositories has **free unlimited
minutes and free artifact storage**. The 2 GB cap applies to **private** repos on the Free plan.

**Propagation warning:** D-50's *storage-cost* rationale in `AGENTS.md` rests on that same mistaken premise.
If you ever see it cited as a cost constraint, it does not hold for this repo. **D-50's OTHER half — that
simulation/coverage/power campaigns run on Totoro/DRAC and results stay local — stands on independent
merits (runtime, core count, reproducibility) and is completely untouched by this.**

---

## 5. Full release-evidence ledger

| Gate | Status |
|---|---|
| Version / DESCRIPTION / NEWS consistency | **Consistent** — DESCRIPTION `0.5.0`, NEWS `# gllvmTMB 0.5.0`, README and live site agree. Now governed by D-66 (ships as 0.6.0). |
| Clean source build + `--as-cran` | **NO EVIDENCE.** No tarball, no `.Rcheck`, no `00check.log`. `cran-comments.md` claims 0E/0W/0N but is dated **2026-07-11** and predates **42 commits** to `R/ src/ tests/ DESCRIPTION NAMESPACE` — incl. a new exported family (`multinomial()`, `e4c63b4e`), an export trim (`660b9178`), and two crash fixes (`aa76b84c`, `6f84b3f0`). **It cannot describe `main`.** |
| GitHub CI + platform coverage | Routine `main`/PR runs are **ubuntu-only**; 3-OS runs only on `workflow_dispatch (full_matrix: true)` or a release tag. **No macOS/Windows evidence since 2026-07-12.** Nightly red 7 nights (§3a). Two commits — `75a19b3e` (#768), `f78342bb` (#769) — have **zero CI runs of any kind** (`runs?head_sha=` → `total_count: 0`); cause undetermined, both were ordinary pushes. |
| pkgdown / rendered site | **HTTP 200**, reports `0.5.0`. Last successful deploy: run 29660991377, 2026-07-18 @ `ab3098e4` — several commits stale. Deploy is gated on an R-CMD-check `workflow_run` **success**, so the two zero-CI commits also produced no site deploy. |
| CRAN incoming / portability / deps | **NO EVIDENCE.** Not on CRAN (404 → **first submission**). Compiled code (`LinkingTo: RcppEigen, TMB`; `SystemRequirements: GNU make, C++17`) makes native-symbol registration and sanitizer/valgrind diagnostics **mandatory under Gate -1** — none run. **No win-builder, no R-hub, ever.** No vignette/example timing budget. No `urlchecker` run. |
| Generated-artifact / untracked blockers | **Clean on `main`** — `git ls-tree -r main` matches nothing for `.new.svg`, `Rplots.pdf`, `.o/.so/.dll/.dylib`, `check/`, `revdep/`, `*.Rcheck`. **Caveat:** `.Rbuildignore` proves *intent*, not exclusion — only listing a built tarball proves it, and none exists. |
| Reverse dependencies | **NOT REQUIRED.** First submission (CRAN 404), no `revdep/`, no dependents can exist. Correctly absent. |

**Not blockers — recorded so nobody re-investigates:** the two `*.new.svg` files that appear in some working
trees are the **documented** vdiffr drift from PR #760 (`b4ca86b0`); both tests carry `testthat::skip_on_ci()`
and the drift is expected cross-BLAS variation on weakly-identified partition cells.

---

## 6. What REML and O3 AGHQ do / do NOT imply for release

**Read this before writing any user-facing prose about either.**

**Gaussian REML (#768) — DOES imply:** `gllvmTMB(REML = TRUE)` is a genuinely shipped, exported, documented
capability. Register row `docs/design/35-validation-debt-register.md:447` (**MIS-33**) is `covered`: a dense
Patterson–Thompson oracle agrees at fitted and perturbed covariance parameters, and matched fixtures agree
with `glmmTMB(..., REML = TRUE)` on likelihood and df metadata. #768 **narrowed** the public caveats
(`man/gllvmTMB.Rd:177-183`, `README.md:210-211`, `model-selection-latent-rank.Rmd:454-463`) — it moved in the
honest direction.

**DOES NOT imply:** an oracle-agreement check is a **correctness** check, not a **coverage** check. **The 0.6
Gaussian REML certificate remains WITHHELD.** Nothing licenses any statement about calibrated interval
coverage. The pilot is Gaussian-only, unweighted, no `mi()`, no predictor-informed `lv`, no `Xcoef_fixed` —
all four already fenced in the man page. **Do not convert the oracle agreement into a coverage claim.**

**O3 AGHQ (#769, #770) — DOES imply:** nothing for release. It is a research spike with, correctly, **zero
public footprint** — no hits in NEWS, README, `man/*.Rd`, roxygen, vignettes, or `_pkgdown.yml`, and **no
validation-register row at all**. `docs/dev-log/after-task/2026-07-19-aghq-o3-scalar-reference.md:92` states
the discipline: *"No public claim moves."*

**DOES NOT imply:** any estimator capability. `aghq_cox_reid` is a research-only numerical reference. It must
not appear in NEWS or any reader-facing surface, and its internal numerical references must not become a
claim about what the package estimates.

---

## 7. Landing State ledger (handoff gate — CARRIED-OVER declarations)

`~/shinichi-brain/tools/handoff_gate.sh` returns **GATE FAIL**. Declaring every item, per the gate's rule:

| Item | Status | Why not landed / resume |
|---|---|---|
| `docs/dev-log/check-log.md` (+~145 lines) | **CARRIED-OVER, uncommitted** | Contains **two lanes' work**: ~79 lines from a prior Claude coverage-lane session (which left its own reverse-staging instructions in-file) and ~65 from this audit. Committing them together misattributes both. **Stage per lane.** Everything this audit put there is reproduced in THIS document, so nothing is lost to you if it is never committed. |
| `CLAUDE.md` (D-66 reconciliation, `:55`) | **CARRIED-OVER, uncommitted** | Branch-local. The branch is 28 commits behind `main`, and `main`'s `CLAUDE.md` never carried the contradicting "release at 0.6" text — so this edit fixes a **branch-local** file, not `main`. Landing it properly means carrying D-66 to `main`'s `CLAUDE.md` separately. |
| `docs/dev-log/handover/2026-07-18-claude-handover-profile-route.md` | **CARRIED-OVER, uncommitted** | Prior session's edit, not mine. Untouched. |
| Untracked prior-session drafts (`dev/phylo-multinomial-harness-DRAFT.R`, 5 × `docs/dev-log/**2026-07-17-tier2a*`) | **CARRIED-OVER, untracked** | Prior session's Tier-2a material. **Not mine — do not stage.** |
| 2 × `tests/testthat/_snaps/plot-visual-snapshots/*.new.svg` | **Disposable** | Documented vdiffr drift (#760); `skip_on_ci`. Safe to delete. |
| ~13 old unpushed local branches (`delta-lift`, `page-sweep`, `remove-unique-family`, 3 × `worktree-agent-*`, …) | **PRE-EXISTING, not this session's** | Predate this audit entirely. Flagged only because the gate lists them. |

**⚠ Because `check-log.md` is uncommitted and you read `origin`, the audit's check-log entries do not exist
for you. This document is the authoritative copy.**

---

## 8. Files created / modified by this session

| Path | Change |
|---|---|
| `docs/dev-log/handover/2026-07-19-codex-handover-release-evidence.md` | **NEW** — this document |
| `CLAUDE.md` | Modified `:55` — D-66 reconciliation (uncommitted, branch-local) |
| `docs/dev-log/check-log.md` | 3 appended entries: main-lane finding, session close-out, Codex-directed message (uncommitted, mixed-lane) |
| — | **No package code, tests, `DESCRIPTION`, `NAMESPACE`, `src/`, workflow, or CI-settings change of any kind.** |

**External (already landed, nothing to do):** #772 closed with the 0.6.0 decision; #773 closed as
not-planned; D-66 appended to `~/shinichi-brain/memory/DECISIONS.md`.

---

## 9. Gotchas / failed approaches — read this, it is the most transferable part

**This audit asserted from stale or unchecked premises FOUR times.** The core findings held, but the failure
pattern was identical each time: *treating something verified earlier, or stated in a loaded file, as still
true now.*

1. **Read branch-local `CLAUDE.md` as repo state.** Reported a "Gate-0 contradiction on `main`" that does not
   exist — `main`'s `CLAUDE.md` is consistent; both contradicting claims live only in the unmerged branch file
   at `:48` and `:55`. **A subagent flagged this correctly and was overridden using loaded context.**
2. **Reported a blocker you had already fixed.** Claimed `test-aghq-o3-scalar-spike.R` sourcing build-ignored
   `dev/` was breaking `--as-cran` on `main`. **#770 fixed it ~40 minutes earlier** — it now sources
   `testthat::test_path("helper-aghq-o3.R")` (in-tarball), and no test sources `dev/` anywhere. Run
   29702277444 @ `39bb80b5` ran a **real** `check-r-package` step (fast-pass skipped) and **passed**. The wrong
   check-log entry was removed.
3. **Recommended `0.5.0` on "main says so."** Missed that D-42's *content* was "a 0.x, NOT 1.0" and that the
   *number* was the only thing in dispute. **A superseded number is not a contradiction — check what a decision
   actually decided before arbitrating between two statements of it.**
4. **Filed #773 against a cap that does not apply.** Took D-50's "hard 2 GB/month cap" from `AGENTS.md` at face
   value without checking repo visibility. **The maintainer caught this one.**

**The operative lesson: the repo and live GitHub state move faster than a session's context. Re-verify
currency before stating a finding — especially a blocker, and especially one you are handing to another agent.**

Also worth knowing: **`.Rbuildignore` proves intent, not exclusion.** Only listing a built tarball proves what
ships. Every "nothing forbidden is tracked" claim in §5 carries that caveat.

---

## 10. Mission control

| Item | State |
|---|---|
| **Repo / branch** | `gllvmTMB` · `main` @ `ff045a38` · authored from `claude/profile-coverage-remeasure-20260718` |
| **CI** | 3-OS run 29704770522 **complete**: ubuntu green · **windows RED on a real test** (§3c) · macOS infra-failed, still unknown. Re-run of both dispatched, **check it**. Nightly `full-check` **RED 7 nights** (§3a). |
| **Release rung** | **NOT READY**, below `source-clean` — no built tarball **and** the default suite fails on Windows |
| **Version** | Ships as **0.6.0** (D-66); DESCRIPTION/NEWS stay `0.5.0` until the release slice |
| **Shipped this session** | Two issues resolved (#772 decided, #773 withdrawn); D-66 recorded; release ledger established; **the Windows failure found** |
| **Highest leverage next** | **§3c — the Windows curvature failure.** Check the re-run first: deterministic = real defect, flaky = tolerance. It gates the candidate. |
| **Then** | §3a nightly triage (7 nights red, your lane, invisible to fast CI) → release slice (§3b) from a clean checkout |
| **Do NOT** | Promote REML coverage · advertise AGHQ · cite D-50's storage-cost rationale · bulk-commit `check-log.md` |

---

## 11. How to resume

From the repo root, start Codex (it reads `AGENTS.md` natively) and paste:

```
Rehydrate from docs/dev-log/handover/2026-07-19-codex-handover-release-evidence.md, then continue
with §3a — triage the 7-night full-check failures. Do not promote any REML coverage or AGHQ claim.
```

Live-toolchain env this repo needs:

```sh
export NOT_CRAN=true
export GLLVMTMB_HEAVY_TESTS=1   # ONLY to reproduce the nightly failures in §3a; leave unset otherwise
```

**Read first:** `AGENTS.md` (source of truth) → this doc → `ROADMAP.md` →
`docs/design/35-validation-debt-register.md` (every advertised capability needs a row). Team mirror:
`.codex/agents/*.toml` — **Rose audit is mandatory before any public claim.**

**Routing:** you (Codex) own the live toolchain — real fits, `R CMD check`, sims, rendering. Claude owns
planning, refactors, prose, and pure-logic checks. **gllvmTMB runs one tool at a time** — this handover
transfers the lane to you.

---

> Related: `docs/dev-log/handover/2026-07-19-codex-handover.md` (0.6-finishing lane map — still live) ·
> `~/shinichi-brain/protocols/cran-release-gate.md` (D-49) · `~/shinichi-brain/memory/DECISIONS.md` D-66 ·
> issues [#772](https://github.com/itchyshin/gllvmTMB/issues/772),
> [#773](https://github.com/itchyshin/gllvmTMB/issues/773)
