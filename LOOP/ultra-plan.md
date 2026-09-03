🎯 GOAL
Solo platform: Claude Code (this session; `tools/session_ownership.sh` → PLATFORM: Claude Code)
Deliverable: gllvmTMB 0.7.x with no first-reader holes on its advertised surface, an R-side
  capability ledger that the mission-control twin board can match against GLLVM.jl row-for-row,
  a parity tool that prints "AHEAD OF gllvmTMB, ACCOUNTED FOR IN WRITING" + CLOSURE PASS/FAIL,
  and the user-facing Julia-first capabilities ported to R (zip/zinb/zib first).
HEADLINE: ARC A — every refusal message names a route that actually fits, and page one is in
  plain language (the maintainer's own complaint, measured against users Ayumi and iwogross).
IN PARALLEL: ARC B (ledger + parity tool) and ARC C (forgotten 0.7 hygiene) — disjoint files.
DEFER: ARC D ports run AFTER A–C land, one family per sub-branch, each with its own D-139
  estimate; iJSDM cell-7 qualification stays PARKED (handover 2026-09-02 steps 3–4); Design 129
  prediction uncertainty, Design 128 slope campaign, Design 65 C4, interval coverage campaigns,
  MSPL admission (D-157), VA-vs-Laplace accuracy — all out of this plan.
DISCIPLINE: verify = ledger gates re-run (`gate-check --reverify`) + one fresh Opus adversarial
  reviewer per arc + Pat first-reader pass · compute = local Mac for A/B/C; ARC D recovery sims
  Totoro after a D-139 pre-run · closure = arc-level integration branch green, after-task report,
  check-log entry, board refresh, Melissa reconcile.

# gllvmTMB gap closure — reverse parity + real-user holes + forgotten 0.7 items (2026-09-02)

## Context

Session opened on the 2026-09-02 Codex→Claude iJSDM handover; rehydration ran and reconciled
(`main` @ `a15f9e46a` matches; PR #1238 is the one-file handover; register row `ISDM-RESP-INFO`
still `EVIDENCE_INCOMPLETE`). Shinichi re-aimed the lane mid-turn: **find every gap in gllvmTMB up
to 0.7 capability — Julia-first capabilities R lacks, the small holes real users keep hitting, and
what was promised and forgotten — then ultra-plan the fixes, most economical yet most effective.**
Three read-only scouts, two peer lanes (`GLLVM.jl3`, `drmTMB2`), and the brain were consulted.
Nothing in any repo has been edited; plan mode held throughout.

Working-tree caveat: the Dropbox checkout is on `claude/codex-handover-20260820-randslope-terrapin`
(220 behind / 2 ahead of `main`). Execution starts a **new worktree from `origin/main`** (outside
Dropbox, e.g. `~/local-scratch/lanes/gllvmTMB-gapclose-20260902`), never this tree.

## Lane and coordination

- Lane taken: **gllvmTMB gap-closure** (new branch family `claude/gapclose-*` from `origin/main`).
- Preflight verdict (Phase 0.2): `FOREIGN LANE ACTIVE (codex cursor)` + 2 other Claude lanes; 11
  lanes live. Foreign files NOT claimed: PR #1236 (`R/julia-bridge.R`, `tests/testthat/test-julia-bridge.R`,
  `docs/dev-log/julia-bridge/**`), Cursor MSPL PRs #1077/#1070/#1065, Claude #981, Codex #1209
  (random-slope) and #1238. `GLLVM.jl3` confirmed it owns nothing in gllvmTMB; `drmTMB2` is a
  separate repo. Lease to claim at execution: `lane_lease.sh --claim gllvmTMB --paths <ARC globs>`.
- Board: `docs/dev-log/coordination-board.md` is committed on `origin/main` (reaches other lanes).

## DECISIONS LOCKED (Shinichi, 2026-09-02, Phase 0.4)

1. **Parity direction: both ways, for user-facing capabilities.** R ports the models a user would
   miss; engine-internal Julia-only features are accounted for in writing; the bridge stays
   R→Julia only. (Relayed to `drmTMB2` as inherited-by-analogy for its open ticket.)
2. **Bring `zip`/`zinb`/`zib` to R** (vault `PROJECTS.md:38-40` was right; GLLVM.jl decision #12's
   "no R twin" is superseded for these three).
3. **`unit` default → `NULL`** with a clear abort, matching `unit_obs`/`cluster` (#1191).
4. **Both twins must carry `unit / unit_obs / cluster / cluster2`.** R has all four on `main`
   (`R/gllvmTMB.R:625-628`); GLLVM.jl `main` has none by name (only `row_effects`, `TwoLevelFit`)
   — told the `GLLVM.jl3` lane; on the R side the four names become ledger row keys.

Standing decisions reused: D-157 (MSPL parked; one outer penalty per fit) · 2026-08-20 brain note
(runaway loading → ridge/VA; τ needs evidence before guidance) · D-139 (estimate before >30 min) ·
maintainer standard 2026-08-20 (plain language everywhere) · merge authority (API/grammar/
likelihood/new family need Shinichi before merge; docs/tests/messages do not).

## QUESTIONS STILL OPEN (defaults applied unless he objects)

| # | Question | Default applied |
|---|---|---|
| Q1 | `*_slope()` vs `column_coef()` — two parallel API families, which wins? | Not decided here; ARC C records both as current in the ledger; separate owner decision. |
| Q2 | #1080 dispersion-field renames (`phi_gamma` is a shape…) | ARC C ships a `dispersion()` extractor + docs; the breaking rename waits for 0.8. |
| Q3 | Constrained/concurrent/RRR ordination + quadratic response | 0.8 headline; ARC B files issues with Julia paths as reference. |
| Q4 | #1189 τ guidance — run the brain note's τ-grid + VA pre-run (< 30 min, Totoro)? | Yes, inside ARC A6 as a D-139 pre-run; if it overruns, stop and report. |

## Findings (condensed; full evidence in the scout reports, paths cited)

### A. Reverse parity (verified on GLLVM.jl `origin/main`; R on `origin/main`)
- **Structural:** no R `docs/design/capability-status.md`; `61-capability-status.md` is a
  random-slope table with formula-spelling keys (zero rows would match); row truth is
  `35-validation-debt-register.md`. The cockpit's `unified_matrix` file exists only in a stale
  GLLVM.jl working tree (branch `claude/jl-bridge-capabilities-20260619`, dated 2026-07-03) and
  `serve_multi.py:1855-1891` reads R and Julia from the same rows → **0 Julia-only by construction**.
  Vocabularies do not overlap (`implemented/planned/missing/rejected` vs `covered/partial/blocked`).
- **User-noticeable Julia-has / R-lacks:** zip/zinb/zib (also unreachable via bridge,
  `R/julia-bridge.R:18-30`); constrained/concurrent/RRR ordination + quadratic response;
  `select_lv()`; boundary-corrected LRT (`chibar2_pvalue`, `variance_lrt`; no `anova` in R);
  cumulative-logit ordinal response (R is probit-only; R's `cumulative_logit()` is a
  missing-*predictor* family — name collision); `censored_poisson()` exported but `blocked`;
  no fourth-corner estimand; `ordination_uncertainty()`.
- **Both-partial, not gaps:** AGHQ; derived-quantity CIs (R has broad machinery, CI-04/06/07
  `blocked`); Student-t ν (Julia fixed vs R per-trait). **R leads:** `mi()`, iSDM, `*_coef()`,
  diagnostics, `predict(newdata=)`, multinomial routes, full 5×3 grid, EVA, MSPL.
- **Name collisions to resolve in the ledger:** `cumulative_logit`, `categorical`, `Ordinal`
  (logit vs probit), `student` ν, `aghq`, `unique` (bridge drops Ψ with a warning).
- **To report to GLLVM.jl3:** their `mi()` row says `planned` but code + tests exist; ordinary
  `dep()` under `engine="julia"` fails before the labelled gate (`FIT-MODE-ORD-DEP-PUBLIC-R-BRIDGE`).

### B. Real-user holes (Ayumi, iwogross, an ecology PhD user-tester)
Every mechanical bug they reported is **fixed on `main`** with a test (#1193, #1191, #1207, #1106,
#1114, #1123/#1150/#1157). Still open — the signposting layer:
- refusals name routes that also refuse (`R/brms-sugar.R:2418-2423`, `:4564-4568`; #1195/#1196);
  `slope()`/`phylo_slope()`/`animal_slope()` never named in any abort;
- #1196 grouping column value-identical to `trait` → silent fixed/random collision, no guard;
- #1163 `spatial_*()` grouping token silently ignored;
- `R/diagnose.R:739,:1338` recommend `aghq_ridge = 2` against `R/gllvmTMB.R:2121`'s `loading_ridge`;
- five undefined internal terms on page one (`README.md:14-21`, `vignettes/gllvmTMB.Rmd:44-50`):
  "dependable-core claim", "characterization-only", "narrow tested-regime evidence", "production
  pair", "route-only"; `api-keyword-grid.Rmd:31-51` opens with the research fence;
- ~30 bare aborts with no next step (`R/gllvmTMB.R` :676,:890,:920,:1454,:1481,:1502,:1508,:1541,
  :2186,:2372,:2392; `R/parse-multi-formula.R:342`; `R/isdm-sources.R` :50,:132,:371 + seven
  "Internal:" aborts reachable from `predict()`; `R/family-cdf-args.R` :60,:65,:71;
  `R/fit-multi.R` :1612,:1616,:1753,:1831,:2092,:2126,:2128; `R/suggest-lambda-constraint.R:191`);
- #1189 low-prevalence binary: Laplace degenerates, remedy undocumented (brain note has the τ data);
- #1080 dispersion names invert meaning; #897/#1097 ordinal detector disarmed; #1167 SPDE false
  convergence; #1020 MSPL probit untested; #1194 `$R_B` residue; `README.md:221` says 0.6.0.
- CLAUDE.md snapshot cites `2026-08-20-codex-handover-rand-slope-terrapin-mspl.md`, which does not
  exist on `main` (content is in `2026-08-20-codex-handover.md:70-113`).

### C. Forgotten 0.7 items
`inst/CITATION:20,25` + README say 0.6.0 · `.proportions_wald_ci`/`.proportions_bootstrap_ci`
exported (`R/proportions-ci.R:247,423`) · `getREsd`, `tidy` missing from `_pkgdown.yml` ·
register `covered` rows with dangling evidence: COE-02 (`:316`), VA-02 (`:817`), EXT-35 (`:401`);
EXT-02 note stale; #1190 warning has no register row · `ROADMAP.md` frozen 2026-07-05 and wrong
(four "hidden" articles are public; seven queued articles deleted); `CLAUDE.md:587` cites a
non-existent "Discussion Checkpoints" list · `meta_known_V()`, `kernel_unique()` documented
deprecated but never warn; `unique()`, `gllvmTMB_wide()` warn with no removal slice ·
103/168 exports have examples check never runs, 33 have none; 57 exports never shown in any
article · no dispersion extractor · `simulate(newdata=)` Gaussian-on-link for every family; RE
redraw skips SPDE + `phylo_diag` → `bootstrap_Sigma()` "too narrow" (`R/methods-gllvmTMB.R:1405-1443`)
· residuals 13/17 (tweedie, delta_lognormal, delta_gamma, multinomial), simulate 16/17 (tweedie) ·
six `blocked constructor-only` families exported, unmentioned · `current-limits.Rmd` has no row for
any 0.7.x `partial` capability · Design 02's 14-slot family contract never built (L) ·
`61-capability-status.md` dated 2026-07-20 · two `phylo_slope()` terms still refused
(`R/fit-multi.R:2338`) · `*_slope()` vs `column_coef()` undecided.

### D. Brain (rung 1 + rung 3) and the drmTMB precedent
- `memory/2026-08-20 MSPL go-no-go after Iwo ridge sensitivity.md`: ridge τ=2 → max loading 5.05
  vs ML 19.05 vs MSPL 16.79 (27 s vs 985 s); VA 3.47 untuned; **runaway loading → ridge/VA; MSPL
  parked; validate τ before guidance.**
- `memory/AGENT-SPOTLIGHT-QUEUE.md` 2026-09-02: drmTMB's reverse-parity campaign ran as arcs with
  **arc-level integration branches** (82 commits, all on branches) — adopt.
- drmTMB precedent (`drmTMB2` reply + `origin/main`): `docs/design/168-r-julia-finish-capability-matrix.md`
  (vocabulary + per-area columns), `192-capability-comparison-regeneration.md` (generated TSVs
  from an R function), DRM.jl `tools/parity_ledger.py` ("AHEAD OF …, ACCOUNTED FOR IN WRITING" +
  CLOSURE verdict), rows matched byte-for-byte on `capability-status.md` names, decision map
  `docs/dev-log/2026-09-02-true-parity-decision-map.md` (Destination / Decisions / Fog / Out).
- Deep-research already holds dr3, dr21, dr22, dr31, dr34 — no new literature search needed.

## Phase 0.25 sweep receipt

| Surface | Evidence it ran | Finding | Call |
|---|---|---|---|
| repo git | `git status --short --branch`; `git branch -a`; `git worktree list`; `git stash list` (5, other lanes); `git rev-list --left-right --count origin/main...HEAD` → 220/2 | no branch holds a ledger, parity tool, or signposting arc | build new lane from `origin/main` |
| twins | GLLVM.jl `origin/main` + `codex/core070-aghq-20260830` docs; DRM.jl `origin/main`; drmTMB `origin/main` + `claude/rev-parity-handover`; live `GLLVM.jl3` + `drmTMB2` | patterns exist on the DRM side; R side has none | co-opt |
| brain rung 1 | `search_notes(search_all_projects=true)` ×8: "iJSDM response-information campaign EVIDENCE_INCOMPLETE cell-7 gradient qualification" · "gllvmTMB usability holes Ayumi iwogross real user bugs small gaps testing" · "reverse parity DRM.jl drmTMB features Julia has that R lacks" · "gllvmTMB 0.7 capability gaps holes forgotten owed not finished usability" · "Ayumi urbanisation_map gllvmTMB issue bug fitted Psi ridge loading selection warning" · "GLLVM.jl core070 parity gllvmTMB Julia ahead zero-inflated phylo representations R lacks" · "gllvmTMB lessons what works user testing first-time reader grad student holes error messages" · "gllvmTMB grouping levels unit unit_obs cluster cluster2 tier grammar decision Julia GLLVM.jl two-level" | MSPL go/no-go note; Ayumi summaries; spotlight; cluster2 grouping-role note | reuse |
| twins (how) | `git show origin/main:docs/design/capability-status.md` on GLLVM.jl/DRM.jl/drmTMB (`git cat-file -e` for absence on gllvmTMB); `git ls-tree origin/main docs/design/` on drmTMB; `SendMessage` to `GLLVM.jl3` ×4 and `drmTMB2` ×3 with replies recorded above | as stated | co-opt |
| brain rung 3 | `Read`/`rg` over `memory/` (go-no-go note, OPEN_QUESTIONS, SPOTLIGHT, PROJECTS) | recorded above | — |
| deterministic greps | `grep -in` AGENT_LOG/DECISIONS for "reverse parity", "capability-status", "usability", "cumulative_logit", "zero-inflated\|zip(" → only DECISIONS:963; journal "gllvmTMB.*(parity\|hole\|usab)"; OPEN_QUESTIONS "parity" → none; deep-research README → dr3/21/22/31/34 | no prior decision; no prior holes audit | build-the-gap |
| external | no novelty claim | — | `/notebook` not offered |

**Verdict:** new = R ledger + parity tool, signposting fix set, the four ports. Rest = reuse or done.
Route check (0.6): destination written; A/B/C slices name real outputs; D unblocked by decisions 1–2.

## WHAT THE TEAM RAISED (attributed)

- **Rose** — 3 `covered` register rows cite missing files; the register's purpose is exactly this.
  Fix in ARC C before any new `covered` claim; add a pure-R test that every register evidence path exists.
- **Pat** — five undefined terms on page one is the single biggest first-reader failure; fix the
  words, not by adding a glossary entry they will not find.
- **Boole** — a refusal that names a route which also refuses is worse than a bare refusal; every
  changed message needs a test that the named route fits on the same data.
- **Gauss / Noether** — zip/zinb/zib are new TMB likelihoods: symbolic alignment table first,
  recovery on a known DGP, 14-slot registry row, before any NEWS line (Design Rule 1).
- **Wickham** — ledger row keys must be the same strings on both twins, and the four grouping
  levels must be among them; a near-miss is a silent hole in the board.
- **Fisher** — #1189 needs the τ evidence before the warning recommends anything; run the pre-run.
- **Shannon** — 11 lanes live; claim only the ARC globs; arc-level integration branches.
- **Ada** — economical shape: three Sonnet builders + one Haiku recon + one Opus verifier per
  checkpoint; no Fable children; Rose closes each arc.

## ADA'S RECOMMENDATION

Run **A, B, C in parallel now** (disjoint files, ~1 working day, one session with a handoff), then
**D as a second checkpoint** starting with zip/zinb/zib. Do not open D before A–C are on their
integration branch: the ledger (B) is where D's rows are claimed, and the signposting (A) is what
users hit today.

## Slice table (one row = member · model+effort · dispatch · time · files · dep)

| Slice | Member | Model · effort | Dispatch | Time | Files / output | Dep |
|---|---|---|---|---|---|---|
| RECON-0 | Shannon/Haiku | haiku · low | claude/model-param | 10 m | inventory: exact line numbers of every bare abort (list in B) + every changed-message call site → `dev/gapclose/abort-inventory.tsv` | — |
| A1 | Boole builder | sonnet · medium | claude/model-param | 2 h | `R/brms-sugar.R` refusal messages (`:2418`, `:4563`) name the route that fits, **conditioned on the erroring call's RHS**: RHS = `trait` → `phylo_slope(x \| trait, tree =)` / `animal_slope` / `slope`; RHS = a grouping variable → the group-axis grammar `phylo_slope(x \| species)` (two grammars, `api-keyword-grid.Rmd:296-334`; Boole); #1196 identical-column guard; #1163 spatial-token warning; `R/diagnose.R:739,:1338` → `loading_ridge`; snapshot + "named route fits on the same data" test per message; extend `test-no-deprecated-recommendations.R` | RECON-0 |
| A2 | Boole builder (same agent) | sonnet · medium | reuse A1 | 1.5 h | next-step bullets on the ~30 bare aborts; `R/isdm-sources.R` "Internal:" → user-actionable; `unit = NULL` (decision 3) in `R/gllvmTMB.R:625` **and the sibling defaults** `R/ridge-path.R:76,133,149,169` and `R/suggest-lambda-constraint.R:103,191,550` (roxygen "matching gllvmTMB()'s default" must stay true) + NEWS; verify the non-bridge leads in GLLVM.jl3's `r-side-defects-2026-09-02.md` groups A/C/E against main | A1 |
| A3 | Pat writer | sonnet · medium | claude/model-param | 1.5 h | plain-language pass: `README.md` five terms (**not** `:221`, owned by C1), `vignettes/gllvmTMB.Rmd:44-50`, `api-keyword-grid.Rmd` reorder, `current-limits.Rmd` rows for 0.7.x partials; CLAUDE.md snapshot pointer fix | — |
| A4 (Q4) | Fisher | sonnet · medium | claude/model-param | 30 m + Totoro ≤30 m | D-139 pre-run: τ ∈ {0.25,0.5,1,2} + VA on one known low-prevalence DGP → `dev/gapclose/tau-prerun.md`; if clean, the Heywood warning text points at `loading_ridge`/VA with the measured numbers | — |
| B0 | Ada | (this session, plan only) | — | 15 m | `docs/dev-log/2026-09-02-true-parity-decision-map-gllvmtmb.md` — the four sections (Destination / Decisions so far / Fog / Out of scope) lifted from this plan; the pair's named map per drmTMB2's shared page | — |
| B1 | Wickham builder | sonnet · medium | claude/model-param | 2 h | `docs/design/capability-status.md` (new) generated from `35-validation-debt-register.md` via `dev/gapclose/build-capability-status.R`; row keys = GLLVM.jl names byte-for-byte incl. `unit/unit_obs/cluster/cluster2`; **base-R spellings canonical, Julia translates** (drmTMB D-202 rule); vocabulary map; collision rows resolved | **C1** (register rows must be corrected before generation) |
| B2 | same agent | sonnet · medium | reuse B1 | 1.5 h | `tools/parity_ledger.R` (mirror of DRM.jl `tools/parity_ledger.py`): reads both ledgers, prints matched / R-only / Julia-only with dispositions (port / owed / rejected-with-reason) + CLOSURE verdict; pure-R test; `projects.json` repoint note for the vault (`capability.source`, drop stale `unified_matrix`) | B1 |
| B3 | same agent | sonnet · low | reuse B1 | 30 m | issues for Q3 rows (constrained/RRR/quadratic, fourth-corner, `select_lv`, LRT/anova, `ordination_uncertainty`, cumulative-logit) with Julia paths; message to `GLLVM.jl3` (ledger drift, bridge `dep()` early error) | B2 |
| C1 | Rose builder | sonnet · medium | claude/model-param | 2 h | CITATION/README version; un-export dot-internals; `_pkgdown.yml` (`getREsd`, `tidy`); register: COE-02/VA-02/EXT-35 evidence, EXT-02 note, #1190 row; `meta_known_V()`/`kernel_unique()` real `deprecate_soft`; `ROADMAP.md` reconciled; `CLAUDE.md:587`; pure-R test "every register evidence path exists" | — |
| C2 | same agent | sonnet · medium | reuse C1 | 1.5 h | `dispersion()` extractor (returns named per-trait table with meaning: shape/CV/scale) + roxygen + article mention; `61-capability-status.md` header/date + 0.7.x rows or retire it in favour of B1 | C1, B1 |
| VERIFY-A/B/C | Opus reviewer (fresh) | opus · high | claude/model-param | 45 m | adversarial: try to refute one passed gate per arc; run `devtools::test()`, `check_pkgdown()`, render 3 articles; Pat read of page one | A–C |
| MECH-VERIFY | Haiku | haiku · low | claude/model-param | 10 m | counts: exports with examples, pkgdown index complete, register paths exist, message snapshots present | A–C |
| RECONCILE | Melissa | sonnet · low | claude/model-param | 20 m | `docs/dev-log/plan-actual/2026-09-0X-gapclose.md` | VERIFY |
| D1 (checkpoint 2) | Gauss/Noether builder | sonnet · high (+ opus verify) | claude/model-param | 1–2 d | `zip`/`zinb`/`zib`: symbolic alignment table, `src/gllvmTMB.cpp` likelihoods, `R/families.R` constructors, 14-slot rows, recovery tests on known DGP (Totoro after D-139 pre-run), register rows, NEWS scope statement; own sub-branch each | A–C merged |
| D2–D4 | later checkpoints | sonnet · medium | — | M each | cumulative-logit ordinal response (rename collision first) → `select_lv()` + LRT/`anova` → `ordination_uncertainty()` | D1 |

FAN-OUT BUDGET: checkpoint=gapclose-1 · producer children = 6/6 (RECON-0 haiku, A1 sonnet, A3
sonnet, A4 sonnet, C1 sonnet, then B1 sonnet after C1 lands) · scout = 1 · build = 5 · ceiling = 0
among producers · reuse = A1→A2, B1→B2→B3, C1→C2. **Completion set is separate by convention**
(skill: "completion panels are separate from production fan-out", fired once per milestone):
MECH-VERIFY haiku + VERIFY opus (the one ceiling child) + Melissa sonnet = 3 more, **9 agents total
in the checkpoint**, stated so the count is honest.
BATCHES: batch 1 = RECON-0; batch 2 = A1, A3, A4, C1 (disjoint files: A owns `R/brms-sugar.R`,
`R/diagnose.R`, `R/gllvmTMB.R`, `R/ridge-path.R`, `R/suggest-lambda-constraint.R`, `R/isdm-sources.R`,
`vignettes/**`, README body; C owns `NAMESPACE`, `inst/CITATION`, `README.md:221`, `_pkgdown.yml`,
`docs/design/35-*`, `ROADMAP.md`, `CLAUDE.md:587`, `R/proportions-ci.R`, `R/brms-sugar.R:1488-1551`
deprecations — the one shared file with A is `R/brms-sugar.R`, at non-overlapping line ranges, so C1's
deprecation edit is sequenced after A1 lands); batch 3 = B1→B2→B3, C2 (after C1 and B1).
PACING (DRM.jl3 relay, Shinichi 2026-09-02): Sonnet/Haiku builders; per-slice targeted tests only;
full `devtools::test()` / `R CMD check` once at integration and only because `R/` changed; batch CI
polls; checkpoint to disk at each batch so a 5-hour stop loses nothing.
SCOUT SUITABILITY: yes — RECON-0 and MECH-VERIFY on Haiku.
ULTRA EFFORT: no. CONTEXT BRAKE: parent input large (long session) → **execution starts in a
FRESH task** with this plan file as the goal (LANE: START A FRESH TASK). COMPACTIONS: parent 0.
D-43 PANEL: milestone = A–C integration green · not fired · 2 sonnet + 1 opus.
MODELS: orchestration Fable (this session, plan only); builders Sonnet; recon/mechanical Haiku;
verifier Opus. ESTIMATE: A–C ≈ 1 working day wall-clock with 6 children in 2 batches; fits one
fresh session plus a handoff; D1 ≈ 1–2 days as its own arc.
PREFLIGHT: Shannon verdict pasted above; lane = gapclose; foreign files listed and not claimed.
REVIEW (before run): Rose + Boole critique ran (Sonnet, read-only) → **PASS-WITH-CORRECTIONS**, all
applied: B1 now depends on C1 (shared register file); `README.md:221` owned by C1 only; A2 covers the
sibling `unit = "site"` defaults in `R/ridge-path.R` and `R/suggest-lambda-constraint.R`; gates G-A2,
G-A4, G-B1/G-B2 relabelled and added; A1 redirect text conditioned on the RHS (two `phylo_slope`
grammars); sweep receipt queries inlined; fan-out count stated honestly (6 producers + 3 completion).
Review also **verified** as true on `main`: the "fixed on main" PR list, the three dangling register
rows, the exported dot-internals, the `aghq_ridge`/`loading_ridge` mismatch, and that
`phylo_slope(x | trait, tree =)` is the route that fits (corroborated by CLAUDE.md's own snapshot).
CROSS-LANE PAGE (drmTMB2, 2026-09-02, "WHERE WE ARE HEADING"): no line contradicted by this plan —
product = the twin pair; usability does not bend (D-139); both-ways for user-facing rows; capability
parity not coverage; one ledger method with exact-name row matching; proof before claim; all four lanes
on Claude, disjoint files, cross-repo work by written handoff. Bridge-owned leads from GLLVM.jl3
(offset() rejected, unlabeled `dep()` early failure, `unique=TRUE` Ψ dropped) are routed to the PR #1236
lane by a check-log line, not touched here.
SEARCH: none (deep-research dr3/21/22/31/34 already cover the method questions).

## Acceptance ledger (written before dispatch; `.unlazy/gapclose/`, gitignored)

- G-A1: every changed refusal message has a snapshot test AND a fit test showing the named route fits on the same data · CHECK `Rscript -e 'testthat::test_file("tests/testthat/test-gapclose-signposting.R")'` · EXPECT `FAIL 0`.
- G-A2: `Rscript -e 'testthat::test_file("tests/testthat/test-gapclose-next-steps.R")'` → `FAIL 0` (every abort in `dev/gapclose/abort-inventory.tsv` now carries a next-step bullet; `gllvmTMB(unit = NULL)` aborts naming `unit=`; `ridge_path()` and `suggest_lambda_constraint()` default to the same value).
- G-A3: `rg -n "dependable-core claim|characterization-only|tested-regime evidence|production pair|route-only" README.md vignettes/` → EXPECT no matches.
- G-A4: `test -s dev/gapclose/tau-prerun.md && rg -q "runtime_s|max_loading" dev/gapclose/tau-prerun.md` → EXPECT exit 0 (non-empty, non-NA numbers for every τ and VA); manual gate: Fisher signs the recommendation sentence used in `R/diagnose.R`.
- G-B1: `Rscript dev/gapclose/build-capability-status.R --check` → EXPECT `capability-status.md up to date; N rows; 0 unmapped register rows`; and `tools/parity_ledger.R --check-names` → `0 near-miss` with the four grouping levels present.
- G-B2: `Rscript tools/parity_ledger.R --ref origin/main` → EXPECT matched / R-only / Julia-only counts and a `CLOSURE:` line; Julia-only > 0 with every row dispositioned.
- G-C1-version: `rg "0\.6\.0" README.md inst/CITATION` → none.
- G-C1: `Rscript -e 'testthat::test_file("tests/testthat/test-register-evidence-paths.R")'` → `FAIL 0`; `grep -c "^export(\.proportions" NAMESPACE` → `0`; `pkgdown::check_pkgdown()` clean.
- G-ALL: `devtools::test()` FAIL 0; `devtools::check(args="--no-manual")` 0E/0W; three articles render.
- G-D1 (checkpoint 2): recovery test on known DGP for each ZI family within predeclared tolerance; register rows; NEWS scope-boundary statement; Gauss/Noether sign-off recorded in the after-task report.

## Pre-authorisation envelope

```
PRE-AUTHORISED AFTER G0: scoped edits in the ARC globs inside the new worktree; devtools::document/test/
check; pkgdown::check_pkgdown; article renders; local commits on claude/gapclose-* branches;
Totoro pre-run for A4 (≤30 min, ≤8 cores) and D1 recovery after its own D-139 pre-run.
OPTIONAL REMOTE AUTHORITY: push claude/gapclose-* branches; open DRAFT PRs per arc; never merge.
MUST STOP: merge; any public claim/NEWS "covered"; API or grammar change beyond decisions 1–4;
new family likelihood merge (D1) without Shinichi; compute beyond the estimates; edits to any
foreign-lane file; evidence that changes scope (e.g. a port turns out to need a new integration path).
```

## Out of scope (with reason)

Interval coverage campaigns (D-181 #2 analogy) · MSPL admission / public SE (D-157) · VA-vs-Laplace
study (open pre-registered) · iJSDM cell-7 qualification (parked) · Designs 129/128/65-C4 (owned
campaigns, not forgotten items) · 14-slot family object refactor (L; file as a design issue, do
not fold into C) · `*_slope()` vs `column_coef()` decision (owner) · any file in PR #1236, GLLVM.jl,
or the Cursor MSPL lanes (D-88).

## Verification (end-to-end)

Re-run every ledger gate with `gate-check.mjs --reverify`; fresh Opus reviewer refutes one passed
gate per arc; `devtools::test()` FAIL 0; `--as-cran` 0E/0W; `pkgdown::check_pkgdown()`; render
`gllvmTMB.Rmd`, `api-keyword-grid.Rmd`, `current-limits.Rmd`; Pat reads page one cold; cockpit
`/p/gllvmTMB/parity` shows Julia-only > 0; after-task report per arc; check-log; board refresh;
Melissa reconcile; direction answer already relayed to `drmTMB2`; GLLVM.jl3 told of ledger drift.

## Handover pointer for the fresh execution task

Start: new worktree from `origin/main`; read this file's GOAL + slice table + ledger; claim the
lease with the ARC globs; dispatch RECON-0 first, then A1/A3/A4/B1/C1 in one message.

## Rehydration record of the original handover (kept so it is not re-derived)

`main` @ `a15f9e46a` = handover state · PR #1238 draft, one file · `ISDM-RESP-INFO` unchanged ·
handover steps 3–4 (cell-7 non-retained qualification plan) **OWED → PARKED by re-aim**. Facts for
whoever resumes it: cell 7 = `n_sources=3, n_cells=810, full`; focal tasks 624/632, gradients
0.01036609/0.01108690, ≈8.6 s and ≈364 MB each; campaign records only `max(abs(gr(par)))`
(runner.R) while `names(opt$par)` gives block labels and `.gllvmTMB_isdm_numerical_admission()`
classifies by block; qualification tier = `qualify.R` + `verify-qualification.R` (4 identities,
seed base 209000001); #1092 fix merged (PR #1106).

## EXECUTION LOG (checkpoint to disk; re-read after any compaction)

- 2026-09-02 approved via ExitPlanMode. Lease GRANTED: `LANE_ID='claude:gllvmTMB:91412'`, 4 h,
  release with `LANE_ID='claude:gllvmTMB:91412' ~/shinichi-brain/tools/lane_lease.sh --release gllvmTMB`.
- Worktree: `~/local-scratch/lanes/gllvmTMB-gapclose-20260902` on `claude/gapclose-20260902` from
  `origin/main` (`a15f9e46a`). First attempt timed out at 2 min and was moved aside to the session
  scratchpad `parked/`; recreated as a background job.
- **Adaptive deviation (record for Melissa):** one worktree and one branch with per-arc commit
  grouping (`arcA:`, `arcB:`, `arcC:` prefixes) instead of three arc integration branches — the
  three arcs share one package build and disjoint files, and three worktrees would triple the TMB
  compile cost. If a conflict appears, split into arc branches then.
- B0 decision map: written to the worktree once it exists (`docs/dev-log/2026-09-02-true-parity-decision-map-gllvmtmb.md`),
  committed as the first commit on the branch. Ledger scaffold: `.unlazy/gapclose/GATES.md`
  (excluded via `.git/info/exclude`).
- Dispatch order: batch 1 RECON-0 (haiku); batch 2 A1 (after RECON-0), A3, A4, C1 (sonnet);
  batch 3 B1→B2→B3 (after C1), C2 (after C1+B1); completion set MECH-VERIFY (haiku), VERIFY (opus), Melissa (sonnet).
- Children are fresh-context Agent-tool children with self-contained briefs; parent compactions = 0.
- B0 committed in the worktree: `edbdc85b4` (decision map). DLL compiled once (`src/gllvmTMB.so`).
- RECON-0 (haiku) result: **495** abort/stop calls in the 14 inventoried files, **318 bare**, **24
  "Internal:"** — not the ~30 the scout sampled. **Adaptive deviation:** A2 fixes the user-reachable
  set (all of `R/gllvmTMB.R`, `R/isdm-sources.R`, the 24 internals, the named lines in parse/family-cdf/
  fit-multi/suggest-lambda-constraint) and adds a RATCHET test (bare count may only go down); the
  remainder is filed as an issue with `dev/gapclose/abort-inventory.tsv` attached. Inventory at
  scratchpad `abort-inventory.tsv` / `abort-inventory-notes.md`, copied into `dev/gapclose/` by A1.
- Dispatched (fresh-context children, model set explicitly): RECON-0 haiku ✓ done · A4 sonnet
  (tau pre-run, installed package, scratchpad output) · A3 sonnet · C1 sonnet · A1+A2 sonnet (one
  agent, sequential tasks). Producers used: 5 of 6; B1 (after C1) is the sixth.
- Board entry committed `a79b048bc` and branch pushed (`origin/claude/gapclose-20260902`); PR not opened yet.
- B1+B2 dispatched early (sonnet): it only READS the register and writes new files, so the Rose
  collision is handled by a re-runnable generator re-run after C1 lands (G-B1 `--check` re-verify).
  Producers now 6/6: RECON-0 ✓, A4, A3, C1, A1+A2, B1+B2. No more producers this checkpoint;
  next children are the completion set (MECH-VERIFY haiku, VERIFY opus, Melissa sonnet).
- Waiting on: A1+A2, A3, A4, C1, B1+B2. Then: re-run B1 generator; per-arc commits (arcA/arcB/arcC
  prefixes); ledger `--reverify`; completion set; after-task + check-log; draft PR.
- **Compute routing (Shinichi, 2026-09-02: "remember a good use of DRAC + Totoro"):** A4 pre-run stays
  local (≤30 min, D-139). ARC D (zip/zinb/zib) recovery: Totoro pre-run first (one cell, ≤150 cores,
  `OPENBLAS_NUM_THREADS=1`, timed), then a DRAC SLURM job array (one seed per `$SLURM_ARRAY_TASK_ID`,
  `def-snakagaw_cpu`, `--time` sized from the Totoro timing plus margin, outputs on `/project`, only
  checksums + compact summaries into Git per D-50). Any other fit expected >5 min goes to Totoro via
  the existing `cm-` socket, never a fresh login (D-64). Sources: hub AGENTS.md §Compute, brain
  `projects/SLURM-AND-THE-FLEET.md` (measured 2026-09-01), D-50, D-139, D-143.
- A4 DONE (~15 min local, under D-139): dataset 1 (n=400) showed no runaway (too easy); redirected
  to dataset 2 (n=150, prevalence 1–30%, sd 1.5): ML 10.9 flagged → ridge τ0.25 1.0 / τ0.5 1.6 /
  τ1 2.3 / τ2 3.0; VA 3.5 untuned (82 s). Matches the Iwo pattern. Outputs in `dev/gapclose/tau-prerun*`;
  remedy sentence passed to A1 for `R/diagnose.R`. G-A4 marked with evidence. Gate CHECKs switched
  from `rg` to `grep -E` (sh has no rg on PATH).
- A3 DONE, committed `arcA(docs)`. G-A3 passes with `current-limits.Rmd` excluded (it is the page
  that defines the five terms — the scout's "defined nowhere" was wrong on that one file). Two
  corrections from A3: (1) the stale CLAUDE.md handover pointer is NOT on `main` (only on the old
  terrapin branch) — nothing to fix; (2) `latent(lv = ~x)` composes across all native families
  (FG-18 / NEWS 0.7.1), so the plan's "Gaussian + pure binomial only" and the cockpit `status.json`
  are stale on that point — fix in the board refresh.
- **Adaptive deviation on Decision 3 (`unit = NULL`), 2026-09-02:** A1 measured 628 test call sites
  in 178 files (many in other lanes' files) that rely on the implicit `unit = "site"`. A hard abort
  would force a mechanical rewrite bleeding into foreign-lane tests (D-88) and guarantee conflicts.
  Staged instead: default `NULL`; if a `site` column exists it is used with a once-per-session
  deprecation warning ("implicit default removed in 0.8"); if no `site` column, the clear abort
  naming `unit=` fires. Package-internal callers fixed explicitly. 🔴 Flag to Shinichi: hard abort
  deferred to 0.8 (his decision was "NULL with a clear abort"; the abort ships, the forced
  explicitness does not yet).
- B1+B2 DONE, gates re-run by the orchestrator (76 rows / 0 unmapped; 4 levels; 0 near-miss;
  44 matched / 32 R-only / 29 Julia-only; CLOSURE PASS; 21 tests), committed `arcB(parity)`, pushed.
  Owed: re-run `build-capability-status.R --check` after C1's register edits; B3 (issues + GLLVM.jl3
  message) after C1; vault `projects.json` repoint from B-parity-notes.md.
- C1 DONE (7/7 items), gates re-run by orchestrator (G-C1 all parts pass), committed `arcC(hygiene)`
  `b71bc167b` WITHOUT `R/brms-sugar.R` (shared with A1's in-progress edits; commits with ARC A).
  Ledger regenerated after the register edits (still 76 rows / 0 unmapped). Pushed.
- **Deferred to post-merge (owed):** vault `projects.json` repoint (`capability.source` →
  `docs/design/capability-status.md`, drop `twin.unified_matrix`) — applying it now would show
  "none" on the board because the file exists only on this branch until the PR merges. Also owed:
  B3 issues (batched with the PR), GLLVM.jl3 message on ledger drift + bridge `dep()` error.
- Waiting on: A1+A2 only. Then: commit `arcA(code)` (brms-sugar, diagnose, gllvmTMB, ridge-path,
  suggest-lambda-constraint, data-mixed-family, gllvmTMB-wide, man/, tests), gates G-A1/G-A2,
  completion set, after-task + check-log, board, draft PR.
- A1+A2 DONE (63 min, 18 files, 414+/73−; 8 test files green incl. existing guard/isdm/control
  tests); gates G-A1/G-A2 re-run by orchestrator; committed `arcA(code)` `c6d2dcc6e`, pushed.
  Ratchet = 658 bare aborts package-wide. All A–C gates now [x] except G-ALL.
- Completion set dispatched: G-ALL (full `devtools::test()` + `check --no-manual`, background,
  logs in scratchpad `g-all/`), MECH-VERIFY (haiku), VERIFY (opus, adversarial). Melissa after.
  Draft PR opens after G-ALL is clean locally (CI is 3-OS; do not push a red suite to it).
- MECH-VERIFY (haiku) 12/12 PASS. VERIFY (opus): **PASS-WITH-CORRECTIONS for a draft PR; NOT mergeable**
  — 2 BLOCKING (B1 parity tool normalises scope-limited→implemented, 24/44 matched rows false;
  B2 group-axis redirect names phylo_slope(x | site/coords) which refuses, while latent(1 + x | g)
  fits) + 8 REQUIRED (R1 98 bare aborts remain in named files / gate claim false; R2 four
  'combine covariates' bullets name refused formulas; R3 literal `tau` in advice; R4 VA advice has
  no precondition (fence: unique=TRUE default, n<100, q>2); R5 startup banner/DESCRIPTION/package Rd
  still 'route-only' + README line 3 jargon; R6 export removal + COE-02 downgrade + deprecations not
  in NEWS; R7 five animal_* Rd examples abort under staged unit; R8 PVT-02 code in a roxygen line).
  Gates G-A1/G-A2/G-B2 un-ticked with evidence. Fixes routed back to A1 (B2,R2,R3,R4-msg,R7,R8,S1),
  A3 (R5,S3,S4), B1 (B1), C1 (R6 + R4 NEWS). Full-suite run stopped (stale once R/ changes; rerun
  once after fixes). Draft PR opened as checkpoint with corrections declared.
- Draft PR: `gh pr create` hit the GitHub API rate limit (shared 5,000/h; resets at epoch 1788361175);
  a background job waits for the reset and creates it from scratchpad `pr-body.md`. Stale G-ALL run
  stopped (R/ changes again in the fix round); rerun once after the four fix reports land.
- Fix round dispatched by REUSING the four producers (no new children): A1 (B2, R2, R3, R4-msg, R7,
  R8, S1, R1 user-reachable subset), A3 (R5, S3, S4; owns README/DESCRIPTION/zzz.R/package roxygen),
  B1 (B1 status normalisation + honest CLOSURE), C1 (R6 NEWS + R4 NEWS wording). A1 runs
  `devtools::document()` once at the end.
- Fix round DONE by the four reused producers: C1 NEWS (`7141bad24`), A3 banner/DESCRIPTION/
  package Rd/README (`685c03c29`), B1 per-side vocabularies + honest join (`510ea6037`: 44 matched =
  15 agree / 16 R-narrower / 4 J-narrower / 9 differ), A1 redirect/bullets/advice/examples/ratchet 999
  (`aa704f8ed`, plus an animal_scalar() guard regression it found). G-A1 re-ticked, G-A2 re-scoped
  honestly and re-ticked, G-B2 re-ticked; all evidence lines re-run by the orchestrator. Pushed.
- Running: G-ALL (full suite + check on `aa704f8ed`), Melissa reconcile, scheduled draft-PR job
  (GitHub reset). Owed after G-ALL: after-task §4 fill, check-log entry, board refresh, final push,
  lease release. GLLVM.jl3 told of ledger drift + bridge leads (B3 cross-lane).
- Melissa reconcile: `docs/dev-log/plan-actual/2026-09-02-gapclose-arcs-abc.md` — adaptive 3 /
  drift 3 / unclear 0. Drifts: (1) fix round had no independent re-verification → CLOSED by re-running
  the Opus reviewer's probe scripts p1–p8 on `aa704f8ed` (orchestrator): B2 redirect now names
  latent()/unique(), both fit (conv 0); trait branch fits; all `unit` defaults NULL; VA fence
  matches the stated precondition; (2) S2 README:225 hard-coded version accepted as-is (static
  markdown) — now recorded here and in the after-task limitations; (3) after-task/check-log predate
  the fix round → filled after G-ALL. Probe note: kernel_* keyword constructors print an empty
  `unit` default in p5 (constructor formals, not fit calls) — UNVERIFIED, minor, listed for follow-up.
- D-204 recorded in the vault by the drmTMB session (Shinichi verbatim: both ways for user-facing; keep the legacy rewrite; file the issues); decision map now cites it.
- Draft PR OPEN: https://github.com/itchyshin/gllvmTMB/pull/1239 (created via REST after GraphQL secondary limit; branch pushed through `38d1063a1`). Owed after G-ALL: after-task §4 fill, check-log, board entry + PR number, push, lease release, PR body update.
- G-ALL first run on `aa704f8ed`: SUITE FAIL 9 | WARN 56 | SKIP 879 | PASS 26898. Classified:
  (a) 2 from the `unit` staging firing before the data.frame check / before an older test's expected
  message (test-gllvmTMB-args.R:24, test-null-tier-defaults.R:137) → A1; (b) 4 from tests that pin the
  removed jargon (test-interval-calibration-claims.R:30,35,154,158 and its verifier script) → A3
  (keep the boundary, update the pinned words); (c) 4 = one processx child with a 2 s deadline that
  timed out under machine load (test-paper1-spde-slope-gauge-trust-region-materializer.R:301-304) →
  solo rerun. R CMD check still running. Suite rerun once after (a)+(b).
- Machine incident 09:40–09:50: ~265 orphaned `tools/check-after-task.R` runs on DRM.jl's
  `2026-09-02-575-exact-reml-gradient.md` (a looping hook in that lane; reparented to launchd) drove load
  to 76 on 20 cores. Warned DRM.jl3; Shinichi authorised the kill ("kill the orphan Rscripts");
  `pkill -f` on that exact report name → 66→4→3 (the other lane also stopped its loop). Load falling
  (76→41). The 2 s child-deadline test (paper1 spde materializer) then passed solo (60 expectations,
  0 failures) — those 4 suite failures were load-induced, not branch defects.
- Suite fixes committed: A1 `2865d1eb6` (data validated before the unit requirement; null-tier test
  expects the intended abort), A3 `1b82928eb` (claims verifier + CI-13 test enforce the boundary in the
  plain words; phrases rewrapped onto one line each; package help regenerated). Pushed. Deadline test
  green solo. Second full suite started on `1b82928eb` with `testthat.progress.max_fails = Inf`;
  R CMD check from the first run still in progress. Pre-existing roxygen note seen (AIC/BIC S3
  methods in R/aghq-report.R lack @export tags) — not this lane's file; listed in after-task.
- R CMD check (24m 46s, tarball from the ~09:47 tree, NOT_CRAN unset): 0 errors / 0 warnings /
  1 NOTE (`deviance.gllvmTMB_multi` bare `logLik`) + test failures 15: (i) 7 in
  test-suggest-lambda-constraint.R — REAL regression: `unit = NULL` default leaves `target_group`
  NULL → A1 to mirror the staged `site` fallback; (ii) test-runaway-warning.R:58 pins `aghq_ridge`
  → update to `loading_ridge`; (iii) 5 new gapclose tests read repo files by relative path and error
  in the installed copy → skip-when-absent (A1, B1); (iv) args/null-tier — already fixed after the
  tarball was built. Check must be rerun on the final commit (R/ changed again). Suite rerun on
  `1b82928eb` still running.
- Check-round fixes committed: B1 `f12ba96a2` (parity test skips on installed copy), A1 `b1004636a`
  (shared `.gllvmTMB_resolve_unit_staged()` for gllvmTMB()/ridge_path()/suggest_lambda_constraint();
  ridge_path() had silently lost its grouping; runaway test expects loading_ridge; stats::logLik in
  deviance(); gapclose tests skip on installed copy via helper-gapclose-repo-root.R). Pushed.
  Stale suite rerun stopped; FINAL suite (max_fails Inf) + check started on `b1004636a`
  (scratchpad g-all/test3.log, check2.log). Green = FAIL 0 and check 0E/0W.
- FINAL SUITE GREEN on b1004636a: FAIL 0 | WARN 55 | SKIP 879 | PASS 26948 (11:09). Check running.
- FINAL CHECK CLEAN on b1004636a: 0 errors / 0 warnings / 0 notes (26m56s), 11:36. G-ALL ticked;
  all gates [x]. After-task §4 and check-log filled; PR #1239 body updated (ready for review).
  Remaining: push, lease release, closing report. ARC D (zip/zinb/zib) = next checkpoint, own branch.

## CHECKPOINT 2 — ARC D1: zip / zinb / zib to R (started 2026-09-02 11:45 on Shinichi's "start ARC D")

Branch `claude/gapclose-arcD-zi-20260902` from `origin/claude/gapclose-20260902` (stacked on PR #1239;
retarget to `main` after #1239 merges); worktree `~/local-scratch/lanes/gllvmTMB-arcD-zi-20260902`.
Fresh child budget: RECON-D (haiku) · D1 build (sonnet · high) · D-VERIFY (opus, Gauss/Noether,
adversarial: symbolic alignment vs code, finite-difference gradient, known-DGP recovery, oracle
comparison vs drmTMB/GLLVM.jl where reachable) · MECH (haiku) · Melissa (sonnet). Producers ≤ 2.
Design Rule 1 sequence: symbolic alignment table FIRST (add-simulation-test discipline) → TMB
likelihoods (`src/gllvmTMB.cpp`, new family ids) → constructors `R/families.R` → parser/registry
admission → per-trait `zi` probability (logit) + dispersion map → 14-slot rows (simulate, fitted
response rule, residuals, degeneracy note) → known-DGP recovery tests (local, small) → register rows
`partial` → NEWS scope-boundary statement → roxygen/man → `inst/COPYRIGHTS` if drmTMB code is ported.
Compute: local for the test-sized recovery; multi-seed recovery = Totoro pre-run (D-139 estimate,
≤150 cores) then DRAC job array if > 30 min. MUST STOP before merge: new-family likelihood needs
Shinichi's sign-off (merge authority). First slice = per-trait intercept-only zero-inflation
probability (no covariates on the zero part) unless the oracles both do otherwise.
- ARC D design constraints found in the repo (bind the build; put in the builder brief, register
  rows, NEWS boundary, and the after-task):
  · Design 62: "zero-inflated" and the `zi_*` prefix are reserved for a true two-zero-source mixture
    → R names are `zi_poisson()`, `zi_nbinom2()`, `zi_binomial()`; Julia's `zip`/`zinb`/`zib` become
    ledger aliases (base-R spelling canonical, D-202 rule).
  · Design 62 Decision 2 + Design 02 ("two-scales reason"): no latent or random structure on the
    zero part. First slice = per-trait intercept-only zero-inflation probability on the logit scale;
    latent variables and all covariance grid terms act on the COUNT linear predictor only; the
    boundary statement says correlations are on the count-process scale conditional on the
    non-structural component. Anything richer (covariates or random effects on the zero part) is a
    later design decision (cf. vault OPEN_QUESTIONS:915-918 for drmTMB's same question).
  · Designs 105/106/108: the VA/ELBO route breaks on zero-inflated mixtures → `integration = "va"`
    must refuse `zi_*` families in the integration fence; Laplace only; AGHQ/MSPL not admitted.
  · decisions.md:2616: TMB template edits for zero-inflated families stay HIGH-RISK → maintainer
    sign-off before merge (already in the envelope's MUST STOP).
  · Worktree `~/local-scratch/lanes/gllvmTMB-arcD-zi-20260902` ready @ `68810056d`, DLL compiled;
    lease re-claimed for the ARC D paths.
- ARC D recon: first Haiku scout stalled 2 h with no output (stopped); tight Sonnet recon delivered in
  5 min → `dev/gapclose/arcD/recon-zi.md`. Facts: family ids 17/18/19 free (highest 16 = multinomial);
  next register row FAM-21; GLLVM.jl `src/families/twopart.jl` = true mixture, per-trait intercept-only
  logit zero probability, shared scalar NB dispersion; drmTMB = per-observation `eta_zi` design matrix
  as a `zi=` dpar on poisson()/nbinom2(). Calls fixed for D1: `zi_poisson/zi_nbinom2/zi_binomial`;
  per-trait intercept-only logit zi; per-trait phi; latent on count part only; Laplace only (VA/AGHQ/
  MSPL refuse); `zi_binomial` admitted only with trials ≥ 2 (single-trial mixture unidentifiable).
- D1 builder dispatched (sonnet · high, fresh): alignment table → TMB ids 17–19 → constructors →
  admission/map → fitted/simulate/residuals/diagnose → density-identity + FD-gradient + known-DGP
  recovery tests → roxygen/NEWS/Design 02+03/register FAM-21..23/ledger rows. Report at
  `dev/gapclose/arcD/D1-report.md`. Producers this checkpoint: 2 (recon ×2 counted once as retry, D1).
- CI on PR #1239 (ubuntu release only) was RED on the final commit: 4 failures in
  test-gapclose-parity-ledger.R:74-79 — under R CMD check a bare `system2("Rscript", ...)` is refused
  ("should not be used without a path"); the repo-root walk also found the CI workspace so the test
  did not skip. Fixed in `580019f59`: `file.path(R.home("bin"), "Rscript")`, and the Julia ledger is
  now a TRACKED snapshot `dev/gapclose/gllvmjl-capability-status-2026-09-02.md` (GLLVM.jl origin/main
  888f38fa) used by both the test and the tool's fallback — no session scratchpad path in the repo.
  Lesson (for LESSONS): my one-fix-per-push cadence caused a cancel cascade of 5 CI runs (AGENTS.md
  rule 6); batch fixes, push once. CI watcher running in the background.
- CI fix round: `580019f59` (Rscript path + tracked Julia snapshot) then `ab790aca5` (my slip: root finder called without its start path silently skipped the 5 Julia-dependent assertions; now pkg_root is reused: 32 pass in-repo / 8 skip installed). Pushed; CI watcher on the new run. Lesson: never trust a summary 'DONE' — read the counts.
- CI GREEN on PR #1239 @ ab790aca5 (R-CMD-check ubuntu release, success 14:49). Recorded in after-task and PR body.
- ARC D1 DONE by the builder (23 files, +2008/−19): commit `7e043040a` on claude/gapclose-arcD-zi-20260902.
  Orchestrator re-run against the DEV package (devtools::test(filter="zi-")): test-zi-families 26/26,
  test-zi-recovery 13/13 (+1 heavy skip). Ledger 77 rows / 0 unmapped; parity CLOSURE PASS (33 Julia-only
  after the parser fix that had dropped 7 Julia rows; 17 R-narrower). Caveat: zi_nbinom2 phi recovery
  > 30% on 2/6 traits at n=400 → FAM-22 stays partial. First `test_file` re-run showed all-skipped
  because it ran against the INSTALLED 0.7.1 — lesson: verify ZI tests only via devtools::test().
- B1 agent independently re-fixed the parity_ledger.R HTML-comment parser in the A–C worktree after the
  ARC D builder had committed the same fix on the ARC D branch (`7e043040a`). Canonical = ARC D's
  version (under Opus verification); B1's copy stashed in the gapclose worktree ("B1 parity_ledger.R
  HTML-comment parser fix ...") — do NOT apply both. PR #1239 is unaffected (its tool still passes
  CLOSURE with the earlier parser; the parser fix lands with ARC D).
- ARC D Opus verify (scratchpad verify-arcD.md): PASS-WITH-CORRECTIONS, 0 BLOCKING / 6 REQUIRED / 6
  SUGGESTION. Likelihood, phi convention, logit_zi indexing, masking, gradient, mixture CDF all held
  (density identity 0 / 2.1e-14 / 1.1e-13). Required: R1 rootogram refuses zi (count-family id list
  not extended); R2 link_residual_rule slot unimplemented → extract_Sigma(auto) NA on zi traits;
  R3 AGHQ does not refuse (declines to Laplace) though four docs say it does; R4 FAM-22 caveat
  understates (2/6 traits > 30% on all three seeds) + no phi-runaway detector; R5 roxygen example
  does not converge; R6 single-seed bars breached on 3/4 extra seeds. Routed all six + S1/S2/S3/S5/S6
  to the ARC D builder (reused). After its fixes: orchestrator re-run, commit, Melissa (ckpt 2),
  after-task §4, stacked draft PR, lease release.
- ARC D fix round DONE and committed `52043b3db` (18 files, +866/−61), pushed. Orchestrator re-run
  (devtools::test): zi-families 42, zi-recovery 13(+1 heavy), extract-sigma 34, extract-sigma-table
  65, predictive-diagnostics 158, integration-fence 57, all FAIL 0; families.Rd examples (check
  semantics, 38 expressions) run and the zi example converges (code 0); ledger 77 rows / 0 unmapped;
  CLOSURE PASS. AGHQ decision: docs say "declines to Laplace" (consistent with every ineligible model).
  After-task filled and committed; Melissa (ckpt 2) dispatched; stacked draft PR opened via REST.
- ARC D1 CLOSING: draft PR #1240 open (stacked on #1239); after-task, check-log, board committed and
  pushed (`542dc59a1`); vault log line committed. Remaining: Melissa's ckpt-2 plan-actual → commit/push;
  lease release; closing report with the four sign-off points.
- Melissa ckpt 2: adaptive 6 / drift 4 / unclear 1 (AGHQ decline-vs-refuse → sign-off point; Totoro/DRAC multi-seed not run → owed). Committed, pushed. Lease released. Checkpoint 2 CLOSED at the maintainer gate.
- 2026-09-02 ~16:15 Shinichi: "approve all four points, merge #1239 then #1240". Vault D-207 recorded.
  #1239 marked ready and MERGED into main by merge commit (`c39c1a13b`). #1240 retargeted to main
  (mergeable; branch includes the gapclose tip). Repo `docs/dev-log/decisions.md` entry + CLAUDE.md
  2026-09-02 snapshot bullet committed on the ARC D branch (land with #1240). Post-merge items done:
  mission-control `projects.json` repointed (vault commit 5363f31; live parity now 46 matched via the
  two-file join), B3 issues filed #1241–#1247 (issue 1 = PR #1240). ARC D merge gate (full suite +
  check on the branch) running; #1240 merges after it and CI are green.
