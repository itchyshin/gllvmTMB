# Overnight arc — Poisson MSPL \(W_*\) REPLACE (Cursor-owned)

**Date:** 2026-08-17  
**Status:** PLAN ONLY — paste into `/goal` or LOOP. **Do not treat this file as G0 for public SE/CI.**  
**Owner override:** Shinichi — **Cursor owns** `src/` implementation (supersedes Codex handover ownership for the tape PR).  
**Authority:** G0 **SIGNED — REPLACE** — `docs/dev-log/research/2026-08-17-mspl-poisson-W-G0.md` (#1102); handover `docs/dev-log/handover/2026-08-17-codex-handover-poisson-W-REPLACE.md`; `decisions.md` 2026-08-17 REPLACE entry.  
**Environment:** **local-scratch git worktree** off `origin/main` (not Dropbox primary, not Cursor cloud-agent). No `git add -A`. Do not touch `dev/isdm-package-recovery/`.

---

## 1. Mission (one paragraph)

Implement the signed Poisson MSPL REPLACE: change live GLM-outer weight from \(W=\operatorname{diag}(\mu)\) / `return eta` (`family_id == 2` in `gll_mspl_log_weight_glm`) to working logistic \(W_*=\mu_*(1-\mu_*)\) via the Tweedie precedent (`return gll_mspl_log_weight(eta, 0)`), then rewrite R twins / A6 / #1064 W2·W7 pins so they assert the new tape, run `tmb-likelihood-review` + Gauss/Noether checklist + `docs/design/03-likelihoods.md` + simulation recovery, and only then land fence-honest docs/NEWS. Fill remaining overnight hours with secondary hygiene that does **not** undraft public confint, relaunch Totoro, reopen Design 118, absorb Lane B, or invent Design 125 fork B/C smoke. SE-series family doors stay closed until twin rematch is green; public `se=TRUE` / `vcov` / `confint` and `MSPL-04` stay blocked.

---

## 2. Binding context (read before coding)

| Artefact | Role |
|---|---|
| `2026-08-17-mspl-poisson-W-G0.md` | **SIGNED REPLACE** paste; programme unlock ≠ public SE |
| Tweedie branch `family_id == 6` in `src/gllvmTMB.cpp` | Live precedent: working logistic, not true \(W\) |
| `tests/testthat/test-mspl-W-onesided-oracles.R` | #1064 — **W2** pins \(P_J\) rewards \(+\infty\) under \(W=\mu\); **W7** pins C++ `return eta` |
| `R/mspl-poisson-atoms.R` + admit-packet **A6** | Twin R Jeffreys still `W=diag(mu)` — must rematch |
| Design **125** + ADEMP pre-reg | Profile-led construction **binary-first**; docs may still say older PARK — sync wording only; **G4c FORK-DEFER** still blocks inventing fork smoke |
| `2026-08-17-kosmidis-firth-2021-profile-caveat.md` | **Binomial-response only** — do **not** extend KF2021 coverage caveat to Poisson \(W_*\) / non-binomial |
| #1077 | Stays **draft**; wording updates OK; no undraft for public confint |

---

## 3. Arc table (~10–12 h)

| id | hours | deliverable | verify |
|---|---:|---|---|
| **A0** | 0.5 | Fresh **local-scratch** worktree from `origin/main`; branch `cursor/mspl-poisson-W-REPLACE-impl`; lane preflight; confirm no Lane B / `lane_b_*` edits | `lane_preflight.sh`; `pwd` not Dropbox cloud-agent; `git status` clean of `isdm-package-recovery` |
| **A1** | 2.5 | `src/gllvmTMB.cpp`: Poisson `family_id == 2` → working \(W_*\) (Tweedie-style comment + `gll_mspl_log_weight(eta, 0)`); rebuild TMB | Package loads; Poisson MSPL fit smoke `se=FALSE` still finishes |
| **A2** | 2.0 | Rewrite #1064 **W2/W7** (+ W8 registry notes as needed): W2 becomes historical/true-\(W\) contrast OR pins that *live* tape is now two-sided; W7 pins C++ no longer `return eta` for Poisson; keep W1 as true-\(W=\mu\) algebra if useful | `devtools::test(filter = "mspl-W-onesided")` green |
| **A3** | 1.5 | Twin rematch: `R/mspl-poisson-atoms.R` Jeffreys uses \(W_*\); admit-packet **A6** + phase4 oracles that assume live \(W=\mu\) updated honestly (document true vs working) | `filter = "mspl-poisson"` green |
| **A4** | 1.5 | Simulation recovery slice for Poisson MSPL point under new weight (multi-seed local; **not** Totoro); registry notes: still experimental / no `covered` | Recovery test PASS; no NEWS `covered` |
| **A5** | 1.0 | `tmb-likelihood-review` skill checklist + Gauss/Noether notes; update `docs/design/03-likelihoods.md` MSPL Poisson weight row | Checklist filed in after-task; 03-likelihoods mentions \(W_*\) + Tweedie precedent |
| **A6** | 1.0 | Docs fence honesty: sync Design 125 / ADEMP / handover sentences that still say PARK-only; #1077 body/comment if needed (**stay draft**); family-door **unfreeze prep notes only** (Gamma/lognormal/Tweedie public still closed) | `rg` stale PARK-as-current; no undraft; no MSPL-04 flip |
| **A7** | 1.0 | Secondary: `test-mspl-api.R` hygiene + narrow `devtools::test(filter = "mspl")`; optional `--as-cran` **with vignettes** if time (else note deferred) | mspl filter green; as-cran log or explicit defer |
| **A8** | 0.5 | After-task + check-log + PR draft (**not** merge without morning Shinichi if `src/`); hard-stop audit | After-task lists OUT items untouched |

**Sum:** ~11 h. If A1–A5 slip, **cut A7 as-cran / A6 polish first** — never cut twin rematch or W2/W7 rewrite.

---

## 4. Explicit OUT (hard stop if tempted)

- Public `se=TRUE`, `vcov`, user-facing `confint` (Wald or profile)
- Undraft or merge #1077 as public confint
- Totoro / DRAC / Design 118 / B1 relaunch / absorb Lane B / rebuild #1090
- Invent Design 125 fork B/C profile smoke without G0 (G4c **FORK-DEFER**)
- Open Gamma / lognormal / Tweedie / nbinom **public** SE-series doors (prep notes only)
- Extend KF2021 finite-estimator coverage caveat beyond **binomial-response**
- NEWS / register **covered** intervals; flip `MSPL-04` off `blocked`
- `git add -A`; Dropbox cloud-agent as builder; `dev/isdm-package-recovery/**`

---

## 5. OPEN GATES — morning Shinichi

1. **Admit status after rematch:** keep Poisson MSPL `admitted` vs park to `planned` until more recovery?
2. **Merge authority:** merge REPLACE `src/` PR when CI green, or hold for Gauss/Noether human skim?
3. **SE-series doors:** rematch green ⇒ unfreeze *which* next family packet (still no public `se`)?
4. **Design 125:** any change to G4c FORK-DEFER, or still wait?
5. **#1077:** remain draft until separate profile-construction G0?

---

## 6. Paste-ready 🎯 GOAL

```text
🎯 GOAL — overnight Poisson MSPL W_* REPLACE (Cursor · ~10–12 h)

Mission: On a local-scratch worktree from origin/main (NOT Dropbox cloud-agent),
implement SIGNED G0 REPLACE: Poisson MSPL live weight family_id==2 from
return eta / W=diag(mu) → working logistic W_* = gll_mspl_log_weight(eta, 0)
(Tweedie precedent). Rewrite #1064 W2/W7 (+ W8 notes), rematch
R/mspl-poisson-atoms.R + A6, update 03-likelihoods.md, run tmb-likelihood-review
+ simulation recovery. Secondary only after rematch green: fence-honest docs
(sync stale PARK wording), #1077 draft-only wording, family-door unfreeze PREP
notes, mspl-api tests, optional as-cran+vignettes.

OUT: public se/vcov/confint; undraft #1077; Totoro/Design 118/Lane B/#1090;
fork B/C smoke; KF2021 beyond binomial; NEWS covered; git add -A;
isdm-package-recovery.

Arcs: A0 worktree → A1 src W_* → A2 W2/W7 oracles → A3 twin/A6 → A4 recovery
→ A5 likelihood review/docs → A6 fence docs → A7 mspl-api/as-cran → A8 after-task/PR.

Stop for morning Shinichi at OPEN GATES (admit keep vs planned; merge; which
door next; Design 125 fork; #1077 draft).
```

---

## 7. Morning Needs you checklist

- [ ] Review REPLACE PR diff (`src/gllvmTMB.cpp` Poisson branch + oracle rewrites)
- [ ] Decide admit row: keep `admitted` vs `planned` until more seeds
- [ ] Approve / hold merge
- [ ] Name next SE-series *prep* target (still no public `se`)
- [ ] Confirm Design 125 G4c still deferred
- [ ] Confirm #1077 stays draft
