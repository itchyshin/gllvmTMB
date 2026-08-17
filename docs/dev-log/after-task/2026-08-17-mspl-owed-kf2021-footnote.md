# After Task: MSPL OWED — KF2021 triad footnote (+ #1077 wording)

**Branch:** `cursor/mspl-se-ci-owed-docs` (footnote) · `cursor/mspl-profile-ci-scaffold` (#1077 wording)
**Date:** 2026-08-17
**Roles:** Ada / Rose / Fisher

## 1. Goal

Continue handover OWED after Shinichi/Claude correction: Poisson W **SIGNED — PARK SE doors** stands (do not restore UNSIGNED). Defer provenance to #1096. Land remaining OWED: #1075 KF2021 footnote; #1077 stale bounds wording. Do not rebuild #1090; do not sign KEEP/REPLACE.

## 2. Classification vs handover

| Item | Class | Evidence |
|---|---|---|
| Poisson W Status | **DONE / PROTECTED** (signed PARK in force) | card on `main`; #1096 owns provenance pastes |
| Handover §4 “UNSIGNED” | **RETRACTED by #1096** (correction pending merge) | #1096 |
| #1077 stale “bounds not computed while G0 open” | **DONE** (this sitting) | draft #1077 commit |
| #1075 KF2021 footnote | **DONE** (this sitting) | triad research note |
| Rebuild #1090 | **PROTECTED / not owed** | merged `d22369a3` |
| Sign REPLACE/KEEP | **OWED to Shinichi** | #1096 §3 pastes |
| Lane B / MSPL-04 / undraft public confint | **PROTECTED** | standing fences |

## 3. Files

- `docs/dev-log/research/2026-08-17-mspl-ci-wald-plus-profile.md` — KF2021 MSPL footnote; Poisson line aligned to SIGNED PARK + #1096
- `docs/dev-log/check-log.md`, this after-task
- On #1077: `R/mspl-profile-ci-stub.R`, scaffold research + after-task notes

## 4. Checks

```sh
rg -n 'KF2021|coverage rescue|UNVERIFIED' docs/dev-log/research/2026-08-17-mspl-ci-wald-plus-profile.md
rg -n '1090|not_constructed|Design G0 is open' R/mspl-profile-ci-stub.R docs/dev-log/research/2026-08-17-mspl-profile-ci-scaffold.md
# deliberately not: Poisson W Status flip; undraft #1077; src/ REPLACE
```

## 5. Needs you

Paste one line from #1096 §3 if you want to re-choose: **Confirm PARK** / **Switch to REPLACE** / **Switch to KEEP**. Recommendation remains REPLACE for the tape later; do not treat this sitting as signing REPLACE. REPLACE ⇒ Codex + `tmb-likelihood-review` + Gauss/Noether + sim recovery unless Cursor override is explicit.
