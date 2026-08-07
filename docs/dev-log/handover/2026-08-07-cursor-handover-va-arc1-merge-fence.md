# Handover to Cursor — VA Arc-1 merge/fence (C) · G0 APPROVED

**Author:** Cursor (parent session) · **Target:** Cursor, **fresh agent** (no chat inherited)  
**Date:** 2026-08-07  
**G0:** Shinichi **approved C** — scaffold new lane and start Arc 0; **no merge to main** until a further merge G0 (default stop-for-merge).

---

## 0. First — rehydrate and ownership

```sh
# Prefer the NEW worktree once scaffolded; until then evidence tip is donor-only.
cd /private/tmp/gllvmtmb-va-arc1-merge-fence 2>/dev/null \
  || cd /private/tmp/gllvmtmb-va-gh-all-families

bash /Users/z3437171/Dropbox/Github\ Local/Shinichi/tools/lane_preflight.sh "$PWD" \
  || bash ~/shinichi-brain/tools/lane_preflight.sh "$PWD"

git status --short --branch
git log --oneline --decorate -8
git fetch origin
git rev-list --left-right --count origin/main...HEAD
export NOT_CRAN=true
```

Read, in order:

1. `AGENTS.md` + multi-lane warning in `CLAUDE.md`
2. `docs/dev-log/handover/2026-07-25-active-lane-split.md` (coordination map — refresh row below)
3. **This handover**
4. `docs/dev-log/plan-actual/2026-08-07-va-arc1-merge-fence-arc.md` (**binding plan**)
5. Working-position lock: `docs/dev-log/audits/2026-08-07-va-series-synthesis.md`
6. Arc-1 closeout: `docs/dev-log/after-task/2026-08-06-va-gh-h7-arc1-public-closeout.md` (or nearest on tip)
7. Design `docs/design/110-va-gh-h7-all-scalar-families.md` (fence / calibrated)

Classify every Next Immediate Step as **OWED / DONE / RETRACTED / PROTECTED**. Continue only **OWED**.

---

## 1. Mission

Land a **reviewable Arc-1 ship path** onto `main` without dumping the ~173-commit evidence tip:

- **Code/fence PR** from a **new lane** based on `origin/main` (path transplant)
- Keep **`calibrated=FALSE`** and **Laplace package default**
- Thin NEWS honesty citing series lock — **no soft-PASS** of Arc-2
- **Do not merge** until Shinichi issues a merge G0 (unless he later amends)

---

## 2. B finished? YES

| Item | Status |
| --- | --- |
| **B** truncnb2 + delta_lognormal Totoro n-ladders | **DONE** @ `98839853` |
| Audit | `docs/dev-log/audits/2026-08-07-va-truncnb2-delta-ln-nladder.md` |
| Verdict | Σ recovers with n; prefer LA for delta_ln; truncnb2 mild VA mid-n edge; gllvm N/A |
| Fence / merge from B | **none** |

Evidence tip (donor): `/private/tmp/gllvmtmb-va-gh-all-families` · `codex/va-gh-all-families` @ ≥`98839853`.

---

## 3. Landing State ledger (handoff_gate)

GATE reported unlanded dirty on the evidence tip. Declare **CARRIED-OVER** (do not absorb into C PR):

| Item | Branch / path | Why not landed | Resume |
| --- | --- | --- | --- |
| Dirty probes | `dev/va-gh-h7-campaign/probe-sigma-*.R`, `probe-va-sigma-structure.R` | Research probes; not Arc-1 ship surface | Leave untracked; do not stage |
| JJ match probe | `lanes/va-s1-binomials/scripts/probe-jj-gllvm-match.R`, audit `…-va-jj-gllvm-match.md` | Optional dig leftover | Leave on evidence tip |
| Ladder CSVs | `lanes/va-s0b-exact/results/` | D-50 local results | Never stage to GitHub |
| PoisG audit edit | `docs/dev-log/audits/2026-08-07-va-poisg-sigma-scale.md` (modified) | Evidence tip hygiene | Commit on evidence tip only if needed; **out of C code PR** |
| Unpushed C plan/check-log/LOOP | may be ahead 1+ | Land with this handover commit on evidence tip | Push evidence tip after handover lands |
| Historical unpushed sibling branches | many `codex/*` | Other lanes; not this C | Ignore |

**Evidence tip stays the donor archive.** C executes on a **new worktree**.

---

## 4. New lane (OWED — scaffold first)

| Item | Value |
| --- | --- |
| **Branch** | `cursor/va-arc1-merge-fence-20260807` |
| **Base** | `origin/main` |
| **Worktree** | `/private/tmp/gllvmtmb-va-arc1-merge-fence` |
| **Import** | Path-scoped transplant from tip `98839853` (or pin Arc-1 closeout `537e6da4` + honesty fixes) — **not** cherry-pick of 100+ commits |
| **Split** | Code/fence PR first; bulk series audits stay on fat tip (optional docs PR later) |
| **Out of first PR** | `lanes/*/results`, Totoro dumps, PoisG feat unless amended, dirty probes |

Suggested scaffold:

```sh
git fetch origin
git worktree add -b cursor/va-arc1-merge-fence-20260807 \
  /private/tmp/gllvmtmb-va-arc1-merge-fence origin/main
cd /private/tmp/gllvmtmb-va-arc1-merge-fence
# then Arc 0: freeze file inventory; transplant paths from donor tip
```

Optional LOOP kit: `lanes/va-arc1-merge-fence/LOOP/` on the **new** lane after scaffold.

---

## 5. Key decisions (locked unless Shinichi amends)

1. No fat-tip PR from `codex/va-gh-all-families`.
2. Keep `calibrated=FALSE`; keep Laplace default; VA remains opt-in / fenced as Arc-1 shipped.
3. Series synthesis informs NEWS **scope boundary** only — not Arc-2 soft-PASS.
4. PoisG cloglog closed-form **out** of first code PR (Σ collapse documented).
5. After code PR green → **STOP for merge G0** (not merge-on-green).
6. Standing Totoro permission exists for heavy sims — **C is local/PR only**, no Totoro required.

---

## 6. Next Immediate Steps (OWED only)

1. **OWED — Scaffold** worktree `/private/tmp/gllvmtmb-va-arc1-merge-fence` · branch `cursor/va-arc1-merge-fence-20260807` from `origin/main`.
2. **OWED — Arc 0 inventory** — table: code vs docs vs leave-behind; pin donor SHA; write into new-lane `docs/dev-log/` or LOOP.
3. **OWED — Path transplant** Arc-1 surface (fence, routing, control, tests, man, thin NEWS) from donor tip; no `lanes/*/results`.
4. **OWED — Focused tests** — `test-integration-fence`, `test-va-routing-oracle`, `test-va-all-family-*`, `test-va-control-exposure` (adjust to what lands).
5. **OWED — Rose claim-fence** on NEWS/roxygen — no soft-PASS Arc-2; no register codes on reader surfaces.
6. **OWED — Open code PR** against `main` when local green; **do not merge**.
7. **DEFER** — docs-evidence PR; merge G0; `calibrated=TRUE`; multinomial VA; #947/#948 builds.

---

## 7. Files / artefacts to know

| Path | Role |
| --- | --- |
| `docs/dev-log/plan-actual/2026-08-07-va-arc1-merge-fence-arc.md` | Binding Arc Card + ultra-plan |
| `docs/dev-log/audits/2026-08-07-va-series-synthesis.md` | Working-position lock (G0=1) |
| `docs/dev-log/audits/2026-08-07-va-truncnb2-delta-ln-nladder.md` | B done |
| `lanes/va-series-synthesis/LOOP/` | Prior goal closed / park |
| Donor tip | `/private/tmp/gllvmtmb-va-gh-all-families` @ `codex/va-gh-all-families` |

**Do not stage:** `lanes/*/results/`, `/private/tmp/va-*`, secrets, foreign untracked probes into the C PR.

**Safe verify (new lane):**  
`Rscript -e 'devtools::load_all(); testthat::test_file("tests/testthat/test-integration-fence.R")'`  
(+ other focused files from inventory).

---

## 8. Multi-lane note

Do **not** overwrite `CLAUDE.md` Live Phase Snapshot to a single-lane pointer. Route via  
`docs/dev-log/handover/2026-07-25-active-lane-split.md` and add/refresh the **VA Arc-1 merge/fence (C)** row pointing at **this** handover. Sibling lanes (profile dirty Dropbox, eta Codex, etc.) remain PROTECTED / out of scope.

Older same-day handover `2026-08-07-cursor-handover.md` (Arc-2 diagnosis) is **superseded for the next action** by this C handover — diagnosis is not the active OWED programme unless Shinichi reopens it.

---

## 9. How to Resume

Paste into a **fresh Cursor agent** opened on the repo (ideally already in the new worktree after scaffold):

```text
Read AGENTS.md and docs/dev-log/handover/2026-08-07-cursor-handover-va-arc1-merge-fence.md. Run the handover rehydration steps, reconcile them with the current git state, then continue only the OWED Next Immediate Steps.
```
