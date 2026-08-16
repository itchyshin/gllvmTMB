# LA-MSPL SE series board — 2026-08-16

**Date:** 2026-08-16
**Track:** SE-arc speed-up 5 (coordination)
**Tip read:** `origin/main` @ `55666f1e` (#1041)
**Charter (stale roster, still the contract):**
`docs/dev-log/research/2026-08-16-mspl-se-other-families-series.md` (#993)
**Status:** board only. No pin lift. No admit. No public `se=TRUE`.

This is **LA-MSPL**. Pins are internal \(Q_P\) / \(Q_0\) availability +
PD (D-149). Forming a finite SE is not “MSPL has standard errors.”
Public `sdreport` / `vcov` / `confint` stay withheld.

---

## 1. Live doors with LIVE SE pins (done)

These cells have a public `estimator = "mspl"` door **and** a live
unexported curvature pin on `main`. Public `se=TRUE` still leaves
`sd_report` NULL.

| Family / link | Door | Pin tests | Implementer | Registry |
|---|---|---|---|---|
| binomial / Bernoulli logit | admitted (B2 partial) | [#979](https://github.com/itchyshin/gllvmTMB/pull/979) + honesty [#989](https://github.com/itchyshin/gllvmTMB/pull/989) | `R/mspl-curvature-pin.R` | `admitted` · point only |
| gaussian identity | admitted ordinary \(q=1,2\) | [#1006](https://github.com/itchyshin/gllvmTMB/pull/1006) (`test-zz-mspl-gaussian-se-feasibility.R`) | same; fence includes gaussian | `admitted` · `oracle_local` |
| poisson log | admitted ordinary \(q=1,2\) | [#979](https://github.com/itchyshin/gllvmTMB/pull/979) + next cells [#997](https://github.com/itchyshin/gllvmTMB/pull/997) | same; fence includes poisson | `admitted` · `admit_packet` (not covered) |
| nbinom1 log | planned door [#1007](https://github.com/itchyshin/gllvmTMB/pull/1007) | [#998](https://github.com/itchyshin/gllvmTMB/pull/998) (was expected-red; door + fence now live) | fence includes nbinom1 | `planned` · not admitted |
| nbinom2 log | planned door [#1007](https://github.com/itchyshin/gllvmTMB/pull/1007) | [#998](https://github.com/itchyshin/gllvmTMB/pull/998) | fence includes nbinom2 | `planned` · not admitted |

[#995](https://github.com/itchyshin/gllvmTMB/pull/995) (Gaussian expected-red)
is **CLOSED** as superseded by #1006.

`.gllvmTMB_mspl_curvature_pin()` on `main` is fenced to Bernoulli
logit, Poisson log, Gaussian identity, nbinom1/nbinom2 log, Tweedie
log, and Beta logit. Tweedie/Beta are in the *fence*, not LIVE: the
public prepare door still rejects them, and the zz tests `skip_if`.

---

## 2. Blocked SE and owning PRs

### #999 — Tweedie log + Beta logit

Merged pin file:
`tests/testthat/test-zz-mspl-tweedie-beta-se-feasibility.R`
([#999](https://github.com/itchyshin/gllvmTMB/pull/999)).
Planned registry rows landed with
[#1014](https://github.com/itchyshin/gllvmTMB/pull/1014).
**Public door stays closed** (`fam_ids` still `0/1/2/5/15`).

| Cell | Why blocked | Owning PR | Merge posture |
|---|---|---|---|
| Beta logit | Live 8×3 pin used `skip_if(TRUE)` after R accepted only status 0. Status **1 is `OK_MP_CERTIFIED`**, not invalid. Atom is FCN \(K_{\beta\beta}\). | [#1045](https://github.com/itchyshin/gllvmTMB/pull/1045) `cursor/mspl-beta-jeffreys-atom` | **Next merge** after rebase. OPEN, **CONFLICTING** vs `main` (post-#1039/#1041). After land, Beta live skip becomes “door is missing,” not atom-invalid. Still no public door / admit. |
| Tweedie log | 8×3 live MSPL hangs (`W=\mu^{2-p}/\varphi` one-sided, \(\varphi\to 0\)). Working \(W_*\) taped; timeout-bounded probe still >180 s. | [#1047](https://github.com/itchyshin/gllvmTMB/pull/1047) `cursor/mspl-tweedie-hang` | **Do not merge as a hang-fix.** DRAFT. Hang still **BLOCKED**. Keep `.mspl_se_tweedie_live_hangs`. Diagnosis: `docs/dev-log/research/2026-08-16-mspl-tweedie-hang-wstar.md`. |

Track 6 (sibling) may lift Beta `skip_if` only after #1045 is on
`main` **and** a door exists. Do not lift the Tweedie hang fuse
until a timeout-bounded probe prints `PROBE_OK`.

### #1000 — rest families

Merged pin file:
`tests/testthat/test-zz-mspl-rest-families-se-feasibility.R`
([#1000](https://github.com/itchyshin/gllvmTMB/pull/1000)).
Original six: Gamma, lognormal, Student-t, `ordinal_probit`,
delta-lognormal, delta-Gamma. Live fits `skip_if` the prepare door
is missing. The unexported pin still raises
`gllvmTMB_mspl_curvature_family` for these names.

| Family | Planned row on `main` | Door / tape | Owning work |
|---|---|---|---|
| gamma / lognormal | [#1003](https://github.com/itchyshin/gllvmTMB/pull/1003) Phase-4-style prep | no public door; no GLM-outer fid on the live prepare fence | **Track 4** [#1051](https://github.com/itchyshin/gllvmTMB/pull/1051) DRAFT — oracles→door gap list; **no tape tonight**. |
| student / ordinal_probit | [#1039](https://github.com/itchyshin/gllvmTMB/pull/1039) rows; Phase-4 [#1005](https://github.com/itchyshin/gllvmTMB/pull/1005) | no public door | later rest-door slice; not tonight |
| delta_lognormal / delta_gamma | [#1004](https://github.com/itchyshin/gllvmTMB/pull/1004) prep | no public door | later rest-door slice; not tonight |
| betabinomial / truncated_* / multinomial | [#1039](https://github.com/itchyshin/gllvmTMB/pull/1039) rows; oracles [#1023](https://github.com/itchyshin/gllvmTMB/pull/1023)–[#1025](https://github.com/itchyshin/gllvmTMB/pull/1025) | not in #1000’s original six; no door | after the original six |

Notes retarget [#1041](https://github.com/itchyshin/gllvmTMB/pull/1041)
is already on `main`. Planned ≠ admitted. Registry edits are not pins.

---

## 3. B1 FAIL / Lane B deferred

**B1 (Design 118) is closed as a FAIL, not an SE-series input.**

| Fact | Value |
|---|---|
| Table | COMPLETE 7920/7920, 0 fatals ([#1038](https://github.com/itchyshin/gllvmTMB/pull/1038)) |
| Map | FROZEN at M0 ([#1040](https://github.com/itchyshin/gllvmTMB/pull/1040)) |
| Official hold-out | G1–G5 **FAIL** 14/132 = 10.6% PASS |
| Promote? | **no** |
| Second Totoro/DRAC campaign? | **no** (Design 118: no second campaign) |
| Refit map on hold-out? | **no** |
| Public `se=TRUE` / `vcov` / `confint`? | **still withheld** |
| Aftermath G0 | park vs B2 vs a new construction — **Shinichi**, not this board |

**Codex Lane B** (`codex/lane-b-mspl-interval-feasibility`) stays the
binomial SE / interval owner. D-148 public-interval fence stands
(binary-only; MSPL-04 blocked). Do not absorb, rebase, or duplicate
sandwich / profile / bootstrap / coverage from Cursor. Cursor fan-out
is non-binomial internal pins only.

[#981](https://github.com/itchyshin/gllvmTMB/pull/981) B0 harness
remains a Claude draft. It is not in the SE-pin merge stack.

---

## 4. Next merge order for the SE series

Hygiene already on `main` this sitting: #1039 planned-rest rows
(`a1c008db`), #1041 notes (`55666f1e`), #995 closed.

1. **Rebase + merge [#1045](https://github.com/itchyshin/gllvmTMB/pull/1045)**
   (Beta atom). Conflicts vs current `main`. Keep planned. No family
   id 7. No admit.
2. **Leave [#1047](https://github.com/itchyshin/gllvmTMB/pull/1047) draft.**
   Tweedie hang is BLOCKED. Do not squash-merge as a fix. Do not lift
   the hang fuse.
3. **Leave [#1051](https://github.com/itchyshin/gllvmTMB/pull/1051) draft**
   (track 4). Gamma/lognormal door is **not ready**; gap list only.
   Do not implement a speculative tape from this board.
4. **Track 6 — lift `skip_if` only for cells that are actually live.**
   Beta after #1045 **and** a door. Tweedie only after `PROBE_OK`.
   Rest-family pin-family tests stay red/`skip_if` until the fence
   and door exist.
5. **Later rest doors** (student / ordinal / delta_* / BB / truncated /
   multinomial). One family, one PR. Local only.
6. **Do not** start Lane B. **Do not** promote B1. **Do not** open
   public `se=TRUE`. **Do not** flip planned → admitted from a pin.

Hard stops unchanged: NEWS `covered`, Codex absorb, `git add -A`,
Dropbox checkout, repo-root `LOOP/`, Totoro/DRAC without a D-139
receipt.

---

## Pointers

- Pin implementation: `R/mspl-curvature-pin.R`
- LIVE zz twins: `test-zz-mspl-{bernoulli,gaussian,poisson,nbinom}-se-feasibility.R`
- Blocked zz twins: `test-zz-mspl-{tweedie-beta,rest-families}-se-feasibility.R`
- D-149: vault `memory/DECISIONS.md`
- B1 FAIL: `docs/dev-log/research/2026-08-16-mspl-b1-complete.md` + #1040
- Mission Control: `Shinichi/Dashboards/mission-control/live/status/gllvmTMB.json`
