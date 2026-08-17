# LA-MSPL SE series board — 2026-08-16

**Date:** 2026-08-16 (overnight refresh after Ranga)
**Track:** SE-arc coordination
**Tip read:** re-derive from `origin/main` (do not trust a frozen sha here)
**Charter (stale roster, still the contract):**
`docs/dev-log/research/2026-08-16-mspl-se-other-families-series.md` (#993)
**Paper + Ranga:**
`docs/dev-log/research/2026-08-16-mspl-se-paper-ranga-synthesis.md`
**Softness / one-sided W audit:**
`docs/dev-log/research/2026-08-16-mspl-softness-w-onesided-audit.md`
**Status:** board + pin-metadata honesty. No pin lift. No admit.
No public `se=TRUE`. No Tweedie public door.

This is **LA-MSPL**. Pins are internal \(Q_P\) / \(Q_0\) availability +
PD (D-149). **Paper-aligned eventual reporting target = \(Q_0\)**
(unpenalized observed info at \(\tilde\theta\)); \(Q_P\) is availability
only. Forming a finite SE is not “MSPL has standard errors.”
Public `sdreport` / `vcov` / `confint` stay withheld.

**Agent paste:** *Pins check that both Hessians exist at θ̃; papers
report unpenalized observed J (Q_0); softness + Laplace error +
separate CI work still gate “SE”; one-sided W blocks honest Jeffreys
doors for Tweedie/Poisson/nbinom until W_\* is settled.*

---

## 0. Ranga G0 list (morning — not tonight)

1. Which matrix ships if public SE ever opens: **Q_0 vs Q_P vs sandwich**.
2. **B1 aftermath** (park / B2 / new construction) — Lane B only;
   hold-out G1–G5 FAIL 10.6% PASS.
3. Whether to **replace live Poisson `W=diag(mu)`** (one-sided red flag)
   before more SE-series doors.
4. Hard stop: public `vcov` / `confint` / `se=TRUE` / NEWS `covered`
   from pins alone.

---

## 1. Live doors with LIVE SE pins (done)

These cells have a public `estimator = "mspl"` door **and** a live
unexported curvature pin on `main`. Public `se=TRUE` still leaves
`sd_report` NULL. Pin metadata now names
`paper_reporting_target = "Q_0"`.

| Family / link | Door | Pin tests | Implementer | Registry |
|---|---|---|---|---|
| binomial / Bernoulli logit | admitted (B2 partial) | [#979](https://github.com/itchyshin/gllvmTMB/pull/979) + honesty [#989](https://github.com/itchyshin/gllvmTMB/pull/989) | `R/mspl-curvature-pin.R` | `admitted` · point only |
| gaussian identity | admitted ordinary \(q=1,2\) | [#1006](https://github.com/itchyshin/gllvmTMB/pull/1006) (`test-zz-mspl-gaussian-se-feasibility.R`) | same; fence includes gaussian | `admitted` · `oracle_local` |
| poisson log | admitted ordinary \(q=1,2\) | [#979](https://github.com/itchyshin/gllvmTMB/pull/979) + next cells [#997](https://github.com/itchyshin/gllvmTMB/pull/997) | same; fence includes poisson | `admitted` · `admit_packet` (not covered); **live `W=diag(mu)` still one-sided** |
| nbinom1 log | planned door [#1007](https://github.com/itchyshin/gllvmTMB/pull/1007) | [#998](https://github.com/itchyshin/gllvmTMB/pull/998) (was expected-red; door + fence now live) | fence includes nbinom1 | `planned` · not admitted; weight saturates |
| nbinom2 log | planned door [#1007](https://github.com/itchyshin/gllvmTMB/pull/1007) | [#998](https://github.com/itchyshin/gllvmTMB/pull/998) | fence includes nbinom2 | `planned` · not admitted; weight saturates |

[#995](https://github.com/itchyshin/gllvmTMB/pull/995) (Gaussian expected-red)
is **CLOSED** as superseded by #1006.

`.gllvmTMB_mspl_curvature_pin()` on `main` is fenced to Bernoulli
logit, Poisson log, Gaussian identity, nbinom1/nbinom2 log, Tweedie
log, and Beta logit. Tweedie/Beta are in the *fence*, not LIVE: the
public prepare door still rejects Tweedie; Beta has planned door
[#1055](https://github.com/itchyshin/gllvmTMB/pull/1055) only.
**Ranga: do not open Tweedie family 6.**

---

## 2. Blocked SE and owning PRs

### #999 — Tweedie log + Beta logit

Merged pin file:
`tests/testthat/test-zz-mspl-tweedie-beta-se-feasibility.R`
([#999](https://github.com/itchyshin/gllvmTMB/pull/999)).
Planned registry rows landed with
[#1014](https://github.com/itchyshin/gllvmTMB/pull/1014).
Beta planned door [#1055](https://github.com/itchyshin/gllvmTMB/pull/1055)
is on `main` (family id 7) — still **not admitted**.
**Tweedie public door stays CLOSED.**

| Cell | Why blocked | Owning PR | Merge posture |
|---|---|---|---|
| Beta logit | Atom FCN \(K_{\beta\beta}\) on main; planned door #1055; soft \(c_n\) + live pin still required. Atom ≠ admit. | [#1045](https://github.com/itchyshin/gllvmTMB/pull/1045) atom · [#1055](https://github.com/itchyshin/gllvmTMB/pull/1055) door | On `main`. No admit. #999 pin may run past “door missing”; skip only for honest nll-tie. |
| Tweedie log | True \(W=\mu^{2-p}/\varphi\) is **one-sided** (same class as Poisson). Hang fix / `PROBE_OK` ≠ soft Jeffreys atom ≠ door. | [#1047](https://github.com/itchyshin/gllvmTMB/pull/1047) hang-fix | Hang may be fixed on main as probe-only. **Do not open family 6.** Diagnosis: `docs/dev-log/research/2026-08-16-mspl-tweedie-hang-wstar.md`. |

### #1000 — rest families

Merged pin file:
`tests/testthat/test-zz-mspl-rest-families-se-feasibility.R`
([#1000](https://github.com/itchyshin/gllvmTMB/pull/1000)).
Gamma / lognormal stay gap-list ([#1051](https://github.com/itchyshin/gllvmTMB/pull/1051)
research-only). No tape from a gap list. Planned ≠ admitted.

---

## 3. B1 FAIL / Lane B deferred

**B1 (Design 118) is closed as a FAIL, not an SE-series input.**

| Fact | Value |
|---|---|
| Table | COMPLETE 7920/7920, 0 fatals ([#1038](https://github.com/itchyshin/gllvmTMB/pull/1038)) |
| Map | FROZEN at M0 ([#1040](https://github.com/itchyshin/gllvmTMB/pull/1040)) |
| Official hold-out | G1–G5 **FAIL** 14/132 = 10.6% PASS |
| Promote? | **no** |
| Second Totoro/DRAC campaign? | **no** |
| Public `se=TRUE` / `vcov` / `confint`? | **still withheld** |
| Aftermath G0 | park vs B2 vs a new construction — **Shinichi**, Lane B |

**Codex Lane B** stays the binomial SE / interval owner. D-148 stands.
Do not absorb sandwich / profile / bootstrap from Cursor.

---

## 4. Next safe action (overnight → morning)

1. **Land** paper+Ranga synthesis + pin metadata + W-onesided audit
   (this refresh).
2. **Do NOT** open Tweedie public door. **Do NOT** public `se=TRUE`.
   **Do NOT** flip admits. **Do NOT** promote B1. **Do NOT** start Lane B.
3. Optional local: #999 Beta pin execution on main — skip only for an
   honest nll-tie, never “door missing.” Still no admit.
4. Morning: answer Ranga G0 list (§0). Softness / \(W_*\) before any
   new Jeffreys door for counts.

Hard stops unchanged: NEWS `covered`, Codex absorb, `git add -A`,
Dropbox checkout, repo-root `LOOP/`, Totoro/DRAC without a D-139
receipt.

---

## Pointers

- Pin implementation: `R/mspl-curvature-pin.R` (`paper_reporting_target`)
- Synthesis: `docs/dev-log/research/2026-08-16-mspl-se-paper-ranga-synthesis.md`
- Softness / W audit: `docs/dev-log/research/2026-08-16-mspl-softness-w-onesided-audit.md`
- LIVE zz twins: `test-zz-mspl-{bernoulli,gaussian,poisson,nbinom}-se-feasibility.R`
- Blocked zz twins: `test-zz-mspl-{tweedie-beta,rest-families}-se-feasibility.R`
- D-149: vault `memory/DECISIONS.md`
- B1 FAIL: `docs/dev-log/research/2026-08-16-mspl-b1-complete.md` + #1040
- Mission Control: `Shinichi/Dashboards/mission-control/live/status/gllvmTMB.json`
