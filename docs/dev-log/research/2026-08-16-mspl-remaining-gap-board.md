# MSPL remaining-gap board — 2026-08-16

**Census time:** 2026-08-16 ~12:00Z.
**`origin/main`:** `af1edd2c` (includes Poisson admit #1017, Gaussian pin
#1006, Poisson SE-next #997, Tweedie/Beta/nbinom1 *docs* preps
#973/#975/#976).
**Reader:** next Cursor sitting that must finish gllvmTMB's own LA-MSPL
without touching drmTMB or Codex Lane B.

This board is a coordination snapshot, not an admission or NEWS claim.
Re-derive from `git` + `gh pr list` before merging anything.

## How to read the buckets

| Bucket | Meaning |
|---|---|
| **admitted (experimental point)** | Public `estimator="mspl"` may run `se=FALSE`. Not covered. No public `vcov()`. |
| **merge-wait** | Sibling PR already owns the slice. Fetch; do not fork a competing branch. |
| **needs-code** | No prep note / oracles / planned row / door on `main` *and* no sibling PR. Safe to open a new isolated branch. |
| **needs-evidence** | Code or planned row exists; admit packet / multi-seed smoke / SE pin is still missing or FAIL. Do **not** flip `admitted`. |
| **excluded / protected** | Fence or other-lane ownership. Do not start. |

## Family census (all 17 `family_id`s)

C++ GLM-outer weight `gll_mspl_log_weight_glm` on `main` already knows
fids **1, 2, 5, 6, 7, 15**. That is a tape, not an admission.

| fid | family | link | `main` registry | Prep on `main` | Door / planned row PR | SE pin | Tape | Bucket |
|---|---|---|---|---|---|---|---|---|
| 0 | gaussian | identity | `admitted` / `oracle_local` | Phase 3 Hirose | public | #1006 on `main`; #995 draft conflicting | Hirose (not GLM-outer) | admitted; SE pin merge-wait |
| 1 | binomial | logit/probit/cloglog | `admitted` / `partial_b2_incomplete` | Design 88 | public | #979 on `main`; **Lane B PROTECTED** | yes | admitted; **do not touch** |
| 2 | poisson | log | `admitted` / `admit_packet` | yes (#972/#1008) | public (#978/#1017) | #997 on `main` | yes | admitted; **needs-evidence** (#990 operational PASS / admit-evidence FAIL) |
| 3 | lognormal | log | none | no | **#1003** (planned rows + oracles) | #1000 expected-red | no | **merge-wait** |
| 4 | Gamma | log | none | no | **#1003** | #1000 | no | **merge-wait** |
| 5 | nbinom2 | log | `excluded` | no | **#974** prep (stays excluded); **#1007** door | #998 expected-red | yes | **merge-wait** |
| 6 | tweedie | log | none | yes (#973) | **#1014** door | #999 expected-red | yes | **merge-wait** |
| 7 | Beta | logit | none | yes (#975) | **#1014** door | #999 | yes | **merge-wait** |
| 8 | betabinomial | logit | none | **#1023** (oracles; no row) | none | none | no | **needs-code** (PR open) |
| 9 | student | identity | none | no | **#1005** (oracles; *no* registry row) | #1000 | no | **merge-wait** |
| 10 | truncated_poisson | log | none | **#1024** (oracles; no row) | none | none | no | **needs-code** (PR open) |
| 11 | truncated_nbinom2 | log | none | **#1024** (oracles; no row) | none | none | no | **needs-code** (PR open) |
| 12 | delta_lognormal | logit+log | none | no | **#1004** | #1000 | no | **merge-wait** |
| 13 | delta_gamma | logit+log | none | no | **#1004** | #1000 | no | **merge-wait** |
| 14 | ordinal_probit | probit | none | no | **#1005** | #1000 | no | **merge-wait** |
| 15 | nbinom1 | log | none | yes (#976) | **#1007** door | #998 | yes | **merge-wait** |
| 16 | multinomial | baseline logit | none | **#1025** (oracles; no row) | none | none | no (grouped softmax) | **needs-code** (PR open) |

`main` registry still has **zero `planned` rows**. Mission Control
showing "mostly planned/excluded" is the sibling-PR surface, not
`origin/main`. After #1003/#1004/#1007/#1014 merge, planned rows appear
for Gamma, lognormal, delta_*, nbinom1/2, Tweedie, Beta. Student and
ordinal stay row-less unless a follow-on adds them after #1005.

## Open sibling PRs (do not fight)

| PR | Role | Merge rule |
|---|---|---|
| #974 | nbinom2 Phase-4 *docs* prep | merge if CI-green; stays excluded |
| #1003 | Gamma + lognormal planned rows + oracles | merge if CI-green; not admitted |
| #1004 | delta/hurdle planned rows + oracles | merge if CI-green; not admitted |
| #1005 | student + ordinal_probit oracles | merge if CI-green; no registry row |
| #1007 | nbinom1/nbinom2 **planned door** | merge after #974 science is on `main` *or* stacked cleanly; not admitted |
| #1014 | Tweedie + Beta **planned door** | stacked on #1007; merge after that door; not admitted |
| #998 | nbinom SE pins (expected red) | **do not merge** until #1007 door is on `main` |
| #999 | Tweedie/Beta SE pins (expected red) | **do not merge** until #1014 door is on `main` |
| #1000 | rest-family SE pins (expected red) | **do not merge** until those families have a door |
| #995 | Gaussian SE pin (draft, conflicting) | repair/rebase; not public `se=TRUE` |
| #981 | B0 harness / `c_n` probe | conflicting; Lane-B-adjacent — classify only |

## This sitting's new branches

Opened from `origin/main` @ `af1edd2c`. Docs + pure-R oracles only.
**No** `R/mspl-registry.R`, `R/mspl.R`, `src/`, admit, or NEWS.

| Branch | Worktree | PR | Family | Why it is not merge-wait |
|---|---|---|---|---|
| `cursor/mspl-remaining-gap-board` | `/tmp/gllvmtmb-mspl-gap-board` | **#1022** | (this note) | coordination |
| `cursor/mspl-phase4-betabinomial` | `/tmp/gllvmtmb-mspl-phase4-betabinomial` | **#1023** | fid 8 | no sibling prep |
| `cursor/mspl-phase4-truncated` | `/tmp/gllvmtmb-mspl-phase4-truncated` | **#1024** | fid 10 + 11 | no sibling prep |
| `cursor/mspl-phase4-multinomial` | `/tmp/gllvmtmb-mspl-phase4-multinomial` | **#1025** | fid 16 | no sibling prep |

If #1003/#1004/#1005/#1007/#1014 land mid-flight, rebase these four
onto new `main`. They should be clean: they do not edit the registry.

## What is *not* a next family

- **drmTMB** — parked. Do not continue drmTMB MSPL work from this repo.
- **Binomial calibrated intervals** — Codex
  `codex/lane-b-mspl-interval-feasibility`. Classify only.
- **Public `se=TRUE` / NEWS covered** — forbidden on every family.
- **Admit flip** — needs a real admit packet + smoke. Poisson already
  showed #990 operational PASS / admit-evidence FAIL; do not repeat
  that for NB/Beta/Tweedie.
- **Second Totoro B1** — pid 2779264 was the live campaign at the
  morning census. Do not launch another.

## Recommended next 3 (morning)

1. **Merge-wait drain, in order:** CI-green docs preps
   (#974, #1003, #1004, #1005), then the nbinom door (#1007), then
   the Tweedie/Beta door (#1014). Leave expected-red #998/#999/#1000
   closed until their doors exist on `main`.
2. **Land this sitting's three prep PRs** (#1023 betabinomial,
   #1024 truncated pair, #1025 multinomial; board is #1022) after
   rebase onto the new `main`. Still no planned rows and no admit —
   add rows in a *later* sweep once the sibling registry edits have
   settled.
3. **Do not admit anyone new.** The only admitted non-binary cells
   remain gaussian + Poisson experimental point. Next scientific
   *door that could later seek admit* is nbinom1, and only after
   #1007 + a real admit packet that does not treat Poisson as a
   theorem transfer.

## Rehydrate commands

```sh
git fetch origin
git log -1 --oneline origin/main
gh pr list --state open --limit 40
git show origin/main:R/mspl-registry.R | rg -n 'status = '
```
