# Claude → Claude handover — 2026-08-18 (Ayumi / diagnostics lane)

You are Claude, picking up the **Ayumi collaborator lane** in gllvmTMB. The authoring chat is
gone; this document and the repo are authoritative.

**START BY RUNNING** `bash ~/shinichi-brain/tools/lane_preflight.sh <repo-path>` — 33+ lanes
live, commits land on `main` all day. Then reconcile this file against `git log origin/main`
and classify every item below `OWED` / `DONE` / `RETRACTED` / `PROTECTED`.

> **MULTI-LANE REPO.** This is ONE lane's handover. The lane map
> (`docs/dev-log/handover/2026-07-25-active-lane-split.md`) is authoritative for ownership.
> Do not treat this document as the project's status.

---

## Goals / mission

Shinichi, standing: finish the package for **0.7**, not a 1.0 push. CRAN is off the table.
The filter is user-visible completeness and honest evidence surfaces.

This lane specifically serves **Ayumi (@Ayumi-495)**, a real external user running
191-review × 73-binary systematic-map GLLVMs (`binomial("probit")`, `latent(1|review, d=2)`).
Her three issues (Ayumi-495/urbanisation_map#23/#24/#25) produced five package defects and a
reanalysis of her data. **She is an active collaborator, not a ticket** — replies are
evidence-based and posted by Shinichi's explicit approval, one at a time.

## Critical context

1. **All Ayumi-facing replies have been POSTED** (#24, #25, #23, plus a correction and a
   follow-up). Do not re-post or duplicate. If you reply again, read the whole #23 thread
   first — it now contains measured numbers from her own data that must stay consistent.
2. **Use GitHub handles in GitHub replies** (`@Ayumi-495`, `@itchyshin`) — Shinichi's
   explicit preference, recorded in `~/shinichi-brain/memory/WORKING-STYLE.md`.
3. **Her repo is a private clone at `/private/tmp/ayumi-map` — READ-ONLY.** Never write,
   never push. Verified untouched (`git status --porcelain` empty) at handover.
4. **Reanalysis artifacts live at `/private/tmp/ayumi-reanalysis/`** (RESULTS.md, fitted
   `.rds`, CSV tables, all scripts). These are OUTSIDE the repo and will not survive a
   `/private/tmp` clear — if any of it matters long-term, copy it into `dev/` first.
5. **The recurring failure class in this repo:** "fixed one member of an instrument class,
   left the siblings." Seven instances in four days, every one caught only by a
   fresh-context adversarial review. **Run the refute stage on any instrument fix.**

## What was accomplished (all merged to `main` unless stated)

| PR | What |
|---|---|
| #1106 | #1092 penalised-gradient at every reader; ridge narrowed to `theta_rr_B` |
| #1114 | Ayumi #25's three defects (mapped-off boundary flags both tiers, `fitted.gllvmTMB_multi`, objective provenance) |
| #1121 | #1117 per-trait dispersion pinning — mixed-family fits get valid Hessians/SEs |
| #1122 | #1118 `deviance.gllvmTMB_multi` + pkgdown index gap from #1114 |
| #1123 | Slice 3: response-dependency screen + `ridge_path()` |
| #1146 | #1082 seven compact worked family examples |
| #1150 | #1147 `known_groups` partial-order nesting + rank-based unresolved count + typo validation |
| #1157 | **OPEN, CI running** — #1154 bounded one-hot subset search |

### The reanalysis of Ayumi's data (all measured, posted to her)

- **Restoring her seven low-loading indicators does not change the ordination**: Procrustes
  correlation **0.9953** (protest p = 0.001, 999 perms), axis correlations 0.9983 / 0.9920,
  communality correlation **0.9917** on the shared 44. The seven have communalities
  0.004–0.092. `ridge_path()` on the restored 51: **51/51 interior**.
- **Her `5.97 / 6.98` reproduces exactly**: 45-set, `n_init = 5` — τ=8 → 5.971, plain ML →
  6.985, communality 0.9803, **44/45 interior, `level_ecosystem` alone penalty-determined**.
- **`d = 3` is degenerate and AIC prefers it** (loading 146, communality 1.000, converged,
  PD Hessian). BIC prefers d = 1. Flagged to her for the methods section.
- **Her `start_method = "res"` is safe here**: identical objective (3858.574493) to default
  starts at d=2/44 indicators, though soft-deprecated. NOT re-checked at d=1 or d=3.
- Data hygiene: `model_matrix_primary.rds` is full rank; the fuller export has deficiency 5
  (3 one-hot blocks + `realm_aquatic`≡`realm_water`, `realm_terrestrial`≡`realm_land` —
  never co-fitted, so no live collinearity).

## Landing State ledger

| Item | Branch | State | Resume |
|---|---|---|---|
| #1154 one-hot subset search | `claude/1154-onehot-subsets` | **CARRIED-OVER** — pushed, PR #1157 open, CI running at handover | `gh pr checks 1157`; merge on green. **Verify `headSha` matches the branch head before merging** — six CI cancellations occurred today under lane traffic and a green check can belong to a superseded commit. |
| Reanalysis artifacts | n/a | **OUTSIDE THE REPO** at `/private/tmp/ayumi-reanalysis/` | Copy into `dev/` if it should persist |
| `.git/index.lock` in the Dropbox checkout | n/a | **STALE — REPORT ONLY** | Do NOT `rm` (harness blocks `.git` deletions). Shinichi clears it. |
| `tmp/rebase-*`, `worktree-agent-*` unpushed branches | various | **FOREIGN, NOT THIS LANE** | Leave alone |

## Next immediate steps (OWED, in order)

1. **Merge #1157** on green CI (verify `headSha` first). Nothing in it needs a decision.
2. **#1080's remaining halves** — items 1 and 2 shipped in #1108. Still owed: **item 3**, the
   rename (`shape_gamma`/`cv_gamma_delta`/`scale_student`, a breaking change), and **item 4**,
   the `sigma_eps` gaussian/lognormal sharing, which is an **estimand question, not naming**.
   Both need Shinichi. Do not implement unilaterally.
3. **#1082's residual half** — the capability-board pip promotion. The article work is done
   (#1146); the pips are gated on *evidence*, not prose. Check `docs/design/35-...` before
   moving anything.
4. **Unowned and fair game** (confirmed free by the categorical lane at its close): **#897 /
   #1097** ordinal degeneracy detection — **read `dev/ordinal-degeneracy/pass-criteria-curvature.md`
   §8.2a FIRST** (seven eliminated candidates with numbers; do not re-run them); **#1134**
   (Design 123 advertises rows that do not fit at T=1); **#1149** (ten untested `family_id`
   branches, hand-verified, not a suspected bug); **#813** (profile-likelihood intervals for
   communality — its old branch `claude/813-instrument-20260730` is dead, 0 ahead / 1022
   behind, ending in a revert of its own work); **#750**, **#565**, **#488**.

## Blockers / open questions (Shinichi's, not yours)

- #1080 items 3 and 4 (above).
- Whether the reanalysis artifacts should be committed into `dev/`.
- Ayumi's own scientific decision — restoring the seven low-loading indicators — is
  **hers**, deliberately left open. The evidence is posted; do not push a recommendation.

## Gotchas

- **A filtered `devtools::test()` is scoped by FILENAME, not content.** It can pass while a
  differently-named file pins the literal you changed. After changing any user-facing message,
  `grep -rn "<the old phrase>" tests/`.
- **A green CI check may belong to a superseded commit** — verify `headSha`.
- **A test can encode the defect.** #1120's only dependent test documented the bug as its
  contract. When you change such a test, do it in a clearly-worded hunk saying so.
- **A fixture can silently stop discriminating** — #1154's own first draft of test 7 passed
  pre-fix for the wrong reason and had to be rebuilt. Prove a guard fails before trusting it.
- Long R fits exceed the Bash tool's 10-minute cap; run them detached and monitor. Background
  R here is also reaped when its parent agent stops — checkpoint set definitions BEFORE fitting.
- CI on this repo runs ~40–75 min under load; do not push fix-ups while a run is active.

## How to resume

```bash
cd <your worktree off origin/main>
bash ~/shinichi-brain/tools/lane_preflight.sh .
git fetch origin main && git log origin/main --oneline -5
gh pr checks 1157
```
Toolchain: R 4.6.0; `devtools::test(filter = "...")`, `devtools::document()`,
`pkgdown::check_pkgdown()`. Campaigns never on GitHub Actions (D-50); Totoro capped at 150
cores (D-143); estimate before any run > 30 min (D-139).
