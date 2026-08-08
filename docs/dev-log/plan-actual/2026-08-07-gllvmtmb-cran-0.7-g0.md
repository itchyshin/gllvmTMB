# G0 lock — gllvmTMB first CRAN is `0.7.0` (Path A `0.6.1` superseded for upload)

**Date:** 2026-08-07 evening  
**Author:** Cursor (Ada inventory + recommendation; **no implementation**)  
**Worktree:** `/private/tmp/gllvmtmb-cran-0.7-20260807` · branch `cursor/cran-0.7-20260807` from `origin/main` @ `d7bee2fa`  
**Orthogonal / do not use:** VA merge-fence `/private/tmp/gllvmtmb-va-arc1-merge-fence`  
**Historical Path A (do not abandon; do not retag as 0.7):** `/private/tmp/gllvmtmb-cran-path-a-0.6.1` · `cursor/cran-path-a-0.6.1-20260807` · freeze/tag **`v0.6.1-rc.1` @ `6a58683c`**  
**Status:** **G0 LOCKED for upload identity.** Track *menu* inventoried. **STOP for Shinichi track pick** before DESCRIPTION bump, remint, or D-113 implementation.  
**D-49 rung:** still **NOT READY**. No tarball-clean 0.7 candidate exists.

---

## G0 statement (locked 2026-08-07 evening)

Shinichi chose **option 3**: re-scope first CRAN from Path A **`0.6.1`** to **`0.7.0`**.

| Lock | Value |
| --- | --- |
| First **CRAN upload** identity | **`0.7.0`** — supersedes D-66 “first CRAN = 0.6.0” *for upload identity only* |
| Historical, keep | GitHub-only **`v0.6.0` @ `c0af58d3`**; Path A freeze/tag **`v0.6.1-rc.1` @ `6a58683c`** (S7 STOPPED: PDF `≈` ERROR + galamm 404 NOTE). **Do not force-retag 0.6.1 as 0.7.** |
| Upload | **Shinichi-only.** **Not before 19 Aug 2026.** CRAN submit portal offline **5–19 Aug 2026**. |
| Laplace | **Remains package default** unless he later says otherwise. AGHQ / VA stay opt-in and fenced. |
| D-112 | Holds: recovery-only intervals; **no** coverage re-measure as a CRAN blocker. |
| D-113 | Full six-track *capability* programme is **not** automatically the 0.7 tarball. Inventory + **minimum honest subset** below; **do not start implementing all D-113**. |
| DESCRIPTION / NEWS bump to 0.7.0 | **Not yet** — wait for track pick. |
| CRAN upload | **Not this slice.** |

Vault follow-on (same evening): D-66 clarifying note → `0.7.0`; D-89 still “on the table after 19 Aug”; Path A `0.6.1` **PARKED/superseded for upload**.

---

## Vacation / portal calendar

| Window | Fact |
| --- | --- |
| **5–19 Aug 2026** | CRAN **submit portal offline** (cannot upload). |
| **≥19 Aug 2026** | Earliest possible Shinichi upload. |
| **Now → 19 Aug** | Time to do *more* before 0.7 if he wants — hygiene + Rose fence always; optional D-113 INCLUDE only after track pick. |
| **drmTMB** | Still **FAR AWAY** under D-89 unless separately G0'd. |

There is still **no clock** after the portal reopens: “on the table after 19 Aug” ≠ “must upload on 19 Aug.”

---

## Path A 0.6.1 — PARKED / superseded for upload (history retained)

| Item | Value |
| --- | --- |
| Lane | `gllvmTMB-cran-path-a-0.6.1` · `/private/tmp/gllvmtmb-cran-path-a-0.6.1` |
| Freeze | `6a58683c20573267dfef1d442e6b5b4b9442b9db` = **`v0.6.1-rc.1`** (pushed) |
| Tarball SHA-256 | `e6342bb53ec1130d5fe2ac65b64e480e013a2c8e82da9de613397c7f89146a9f` |
| Local `--as-cran` | **1 ERROR / 1 WARNING / 2 NOTEs** — PDF manual Unicode `≈` (U+2248) in `man/gllvmTMBcontrol.Rd` / `R/gllvmTMB.R`; galamm URL 404 NOTE |
| D-49 | Highest proven: RC tagged + hashed. **Not tarball-clean.** Verdict **NOT READY**. Failed RC **retained**. |
| Next for this SHA | **Do not remint as CRAN 0.6.1.** Carry the leave-M5 hygiene (`≈` + galamm URL) into the **0.7** candidate. Optional: keep `v0.6.1-rc.1` as a GitHub historical tag only. |

LOOP checkpoint on the Path A lane is updated to **PARKED / superseded for upload**. Next programme lane is this 0.7 G0 + track pick.

---

## D-113 track inventory (not the CRAN tarball by default)

Source: vault [[DECISIONS#D-113|D-113]] (2026-08-01): EVA; Ayumi / missing-data #332; AGHQ claims; #750; SEPARABLE; ≥1 random-slope cell per exported family.  
Register / handovers / issues read 2026-08-07 evening. **#949 VA Arc-1 is already on `origin/main` (`d7bee2fa`).**

| # | Track | Status | CRAN honesty blocker? | Ada 0.7 bucket |
| ---: | --- | --- | --- | --- |
| 1 | **EVA** (`integration = "eva"`) | **OPEN / blocked as public route.** VA-08 `blocked`: not an admitted `integration` value (`laplace`/`va` only). Engine exists as research; `Sigma_B` / `ΛΛ'` recovery is the worst arm (same pathology as gllvm EVA; 71% silent `convergence = TRUE` on blown fits). Codex-owned unless reassigned. | **No**, if it stays **unadmitted and unadvertised**. Becomes a blocker only if NEWS/README/`integration` copy implies EVA ships. | **PARK** |
| 2 | **Ayumi / missing-data #332** | **PARTIAL.** Laplace missing-data v1 **shipped**: MIS-21..31 `covered` (response include + scoped `mi()`); #336/#337/#338 ledger-closed 2026-08-01. Umbrella **#332 still OPEN**. MIS-32 `blocked` (multi-`mi()`, EM/profile, joint fields, MNAR, …). Design 107 VA response-include = VA-10 `partial` (no VA `mi()`, not a public missing-data certificate). Ayumi usability branch parked separately. | **Honesty only:** do not advertise MIS-32 / VA `mi()` / Ayumi-complete. Closing #332 is ledger hygiene, not a PDF/URL blocker. | **PARK** capability; **MUST** keep reader fence. Optional INCLUDE: umbrella closeout comment if Shinichi wants the GitHub ledger honest before upload. |
| 3 | **AGHQ public claims** | **PARTIAL engine, OPEN claims.** Opt-in `aghq = k`; Laplace remains default. Audit headline: *integrator correct; estimator not established.* MIS-36 `aghq_ridge = "auto"` opt-in / `partial`. D3 (`τ = 2` on whenever AGHQ is on) still **unowned**. Path A S1: NEWS “calibrated 9-node” easy to misread as coverage calibration. | **Yes, as a claim fence** — not as a missing engine. Unearned “AGHQ is the better default / calibrated coverage” language would fail Rose/D-112. | **PARK** claim-earning. **MUST** Rose-fence wording. |
| 4 | **#750** unconditional `simulate` redraw (spatial / `phylo_diag`) | **OPEN.** Phylo `phylo_rr` half landed; **`spde` + `phylo_diag` absent** — conditional fallback + fail-loud `bootstrap_Sigma()`. Docs corrected 2026-07-21 (R-5); issue body still says target **0.6**. Stranded spatial commits live on parked coverage branch, **not** `origin/main`. | **No**, if docs stay honest (too-narrow / unavailable intervals named). Becomes a blocker only if `?simulate` / `bootstrap_Sigma()` again claim a redraw they do not do. | **PARK** (INCLUDE-if-time candidate — see Q2). |
| 5 | **SEPARABLE** (`SEPARABLE_t` / Bolker Kronecker, non-identity trait factor) | **OPEN / unstarted.** `src/gllvmTMB.cpp` has **0** `SEPARABLE` uses; hand-rolled identity-trait GMRF loops exist. Capability prize, not a check failure. | **No.** | **PARK** |
| 6 | **Slope-per-family** (≥1 random-slope recovery cell per exported family) | **PARTIAL.** Ledger 2026-08-01 + betabinomial C1 **#887** (`2716f74b`): core + lognormal/student/ordinal/nbinom1 **met** (some `c1_partial`). **OPEN:** tweedie (gated campaign), `truncated_poisson`, `truncated_nbinom2`, `delta_lognormal`, `delta_gamma` (delta fence). DoD is the *full* exported list, not the core seven. | **No**, if reader surfaces do not claim every family has slope recovery. | **PARK** remaining gaps. Optional INCLUDE: one gated family (tweedie) only if he picks it. |
| — | **VA Arc-1** (not a D-113 numbered track; already on main) | **DONE on `origin/main`** via [#949](https://github.com/itchyshin/gllvmTMB/pull/949) @ `d7bee2fa` (this 0.7 worktree base). Fence: `calibrated = FALSE`; Laplace default; no soft-PASS Arc-2. VA-01..04 `covered` (routing/fence); VA-05..12 mostly `partial`; VA-07/`q≥3` and VA-08 EVA `blocked`. | **Honesty:** do not widen VA advertising. Including the already-merged code in the tarball is **not** a new capability programme. | **INCLUDE as already-landed base.** Do **not** revert. Do **not** expand claims. |
| — | **D-112 coverage re-measure** | **PARKED** by decision. | Reopening it would *create* a false CRAN blocker. | **PARK** |
| — | **Default engine flip** (Laplace → AGHQ/VA) | **Not proposed.** G0: Laplace stays default. | Would be a product-contract change, not hygiene. | **PARK / forbidden unless new G0** |

---

## Ada recommendation — smallest honest `0.7.0` tarball

If Shinichi says **“use your judgment”**, ship this and stop:

### MUST (honesty + incoming hygiene — not D-113 capability)

1. **Leave-M5 hygiene** carried from Path A rc.1 into a **new 0.7 freeze** (do not patch `6a58683c` in place):
   - Rd / roxygen Unicode **`≈` (U+2248) → ASCII or `\\approx`** so PDF manual builds (`R/gllvmTMB.R` → `man/gllvmTMBcontrol.Rd`; Rose-scan other Rd).
   - **galamm URL 404** (`https://lcbc-uio.github.io/galamm/` in vignette HTML) — fix or drop.
2. **Rose claim-fence** on reader surfaces (DESCRIPTION, NEWS, README, Rd, articles, `cran-comments.md`):
   - D-112 recovery-only; reconcile `profile_ci_total_variance()` `certified-0.94` vs DESCRIPTION “no cell's interval coverage is certified.”
   - Disambiguate AGHQ “calibrated 9-node” ≠ coverage calibration.
   - Laplace **is** the default; VA/AGHQ/EVA **not** advertised as certified or default.
   - VA Arc-1: keep `calibrated = FALSE`; no Arc-2 soft-PASS; no `method=` export story.
   - #750 / spatial-phylo simulate: docs match code.
   - MIS-32 / VA `mi()` / EVA / SEPARABLE: not implied shipped.
3. **Identity bump** (only **after** track pick): `DESCRIPTION` + `NEWS.md` + citation → **`0.7.0`**; rewrite `cran-comments.md` for **this** identity (not 0.6.0 / 0.6.1 / `c0af58d3` / `6a58683c`).
4. **New freeze + exact-tag D-49** on the 0.7 lane. Path A rc.1 receipts are **predecessor evidence only**. Upload still Shinichi, **≥19 Aug**.

### INCLUDE if time (optional; not required for an honest first CRAN)

| Candidate | Why it might be worth the portal wait | Cost / risk |
| --- | --- | --- |
| **#750** spatial / `phylo_diag` unconditional redraw | Ayumi-facing `bootstrap_Sigma()` currently fail-loud; stranded commits exist on a parked branch | Touches simulate / bootstrap; coverage claim still D-112-fenced |
| **#332 umbrella closeout** (ledger comment / close if v1 + MIS-32 named) | GitHub honesty; no new engine | Low code risk; do not reopen MIS-32 |
| **One slope gap** (tweedie **or** one truncated_*) | Moves D-113 track 6; not a check blocker | Campaign cost; do not advertise “all families” |
| **VA reader-fence pass** on #949 NEWS/articles | Arc-1 already on main; cheap Rose | Docs only |

### PARK (post-0.7 / not this tarball)

EVA public route · AGHQ estimator advertising / default flip · SEPARABLE · remaining slope list · Design 108 Stage 7 (#911) / further VA stages · VA `mi()` · coverage re-measure · paper/capstone · drmTMB CRAN.

**Do not implement “all D-113” before 19 Aug.** That is a multi-arc capability programme, not a CRAN honesty delta.

---

## Ada default if “use your judgment”

**MUST only:** leave-M5 hygiene + Rose claim-fence + `0.7.0` identity bump + new D-49 freeze/ceremony.  
**INCLUDE:** VA Arc-1 **as already on `main`**, fenced.  
**PARK:** every numbered D-113 capability track (EVA, Ayumi/#332 engine, AGHQ claims, #750, SEPARABLE, remaining slopes).  
**Upload:** Shinichi, after portal reopen (**≥19 Aug 2026**), still fail-closed D-49.

---

## Questions for Shinichi (max 3) — STOP here

1. **Confirm Ada default tarball?** Hygiene + Rose fence + `0.7.0` bump + new freeze, **with #949 VA Arc-1 kept as already-on-main (no claim widening)** — vs revert/exclude VA from the CRAN tree (Ada does **not** recommend revert).
2. **Any D-113 INCLUDE before upload?** `(a)` none / fence only **[Ada default]** · `(b)` #750 simulate redraw · `(c)` #332 umbrella ledger closeout only · `(d)` one slope gap (name tweedie vs truncated_*).
3. **Upload timing after 19 Aug?** First possible day the portal is back · or wait until the chosen INCLUDE (if any) lands · or no date, still “when D-49 says submission-ready.”

Do **not** bump `DESCRIPTION` to `0.7.0`, do **not** remint Path A as 0.7, do **not** upload, until these are answered.

---

## Worktree / identity map

| Tree | Branch | Role |
| --- | --- | --- |
| `/private/tmp/gllvmtmb-cran-0.7-20260807` | `cursor/cran-0.7-20260807` | **0.7 G0 + future cleanup/freeze** (this file). `DESCRIPTION` still `0.6.0` until track pick. |
| `/private/tmp/gllvmtmb-cran-path-a-0.6.1` | `cursor/cran-path-a-0.6.1-20260807` | Path A history; **`v0.6.1-rc.1` @ `6a58683c`**; LOOP **PARKED** for upload. |
| `/private/tmp/gllvmtmb-va-arc1-merge-fence` | `cursor/va-arc1-merge-fence-20260807` | **Do not use for 0.7 programme.** #949 already merged to `main`. |
| Dropbox primary | `claude/profile-coverage-remeasure-20260718` (dirty) | **PROTECTED** D-112; do not stage. |

---

## Explicit non-goals this slice

- No `DESCRIPTION` / `NEWS` version bump.  
- No CRAN upload.  
- No in-place patch of freeze SHA `6a58683c` as 0.7.  
- No force-retag `v0.6.1-rc.1` → 0.7.  
- No implementing all (or any) D-113 tracks until Q1–Q3 answered.
