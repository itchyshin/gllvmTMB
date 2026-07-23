# Claude → Codex handover — gllvmTMB 0.6.0 first-CRAN, rc.2 honesty reword

**2026-07-23. You are Codex, picking up the gllvmTMB 0.6 CRAN release lane.** Claude prepared and
adversarially reviewed release candidate `v0.6.0-rc.1`; an independent Codex adversarial pass (you,
earlier) found a **real overclaim in the central honesty claim**. Your job: **execute the reword and
cut `v0.6.0-rc.2`** with the live toolchain. This doc stands alone — you will not see the Claude chat.

## 0. Hard lines — never cross (each is the maintainer's act)

- **Do NOT submit to CRAN.** `devtools::submit_cran` / `release()` / upload — Shinichi's act ALONE.
- **Do NOT cut the final `v0.6.0` tag** without Shinichi. rc.2 is fine (a candidate); the release tag is his.
- **Do NOT delete tag `v0.6.0-rc.1`** — it is the evidence anchor for the prior candidate.
- **Do NOT run win-builder / macbuilder yourself** — already submitted (§5); results go to Shinichi's email.
- LOCAL compute only; no Totoro/DRAC, no campaigns on GitHub Actions (D-50). No EVA / Design 86 lane.

## 1. Mission & where we are

**Goal:** gllvmTMB's **first CRAN release, numbered 0.6.0** (D-66), **Laplace-only** (EVA cut to 0.7).
Honest, experimental (D-41). The arc M1 (release truth) · M3 (API freeze + bump 0.5.0→0.6.0) · M4
(reader-ready) is **DONE**. M5 (CRAN ceremony) is in progress: `v0.6.0-rc.1` cut and **platform-clean**,
but **submission is WITHHELD** pending the reword below + win-builder R-devel + Shinichi's submit.

- **Worktree:** `/private/tmp/gllvmtmb-060-m1-builder` — branch `claude/0.6-m1-close-20260722`, head
  `a9ecd29f`, clean, pushed, `0/0` vs origin. (The Dropbox checkout + 34 parked worktrees + stashes stay
  QUARANTINED — do not touch.)
- **RC tag:** `v0.6.0-rc.1` at frozen source `e9bc655a`. Tarball at
  `~/gllvmTMB-0.6-evidence/m5-rc1/gllvmTMB_0.6.0.tar.gz` (`--as-cran` 0/0/1).

## 2. 🔴 YOUR TASK — reword the calibration overclaim (a CLASS), then rc.2

**The finding (verified real, both by design-doc and by the project's own record):** the D-41 line
positively asserts *"interval calibration **is established** only for the Gaussian cases that cleared the
coverage gate."* But `docs/design/75:96-99` states **"No cell in this matrix is
empirical-coverage-calibrated … a cell may not be described as calibrated … CI-08 and CI-10 remain
open/failing."** And the record agrees: the Sigma_unit certificate was **withheld at 0.95**, CI-08
**failed**. So "is established" claims more than the evidence. Full analysis:
`docs/dev-log/2026-07-23-codex-adversarial-findings.md`.

**SWEEP THE CLASS — two usage kinds, both need fixing (do not patch one instance):**

*Kind A — the POSITIVE claim (the actual overclaim):*
| File:line | Current |
|---|---|
| `DESCRIPTION:28-29` | "interval calibration is established only for the Gaussian cases that cleared the coverage gate." |
| `README.md:13-14` | same sentence (the `[!WARNING]` callout) |
| `R/zzz.R:11-13` | `.onAttach` startup message, same sentence ("Gaussian cells") |
| `NEWS.md` | the "Known limitations" boundary bullet (M1 decision 2) — **check and reword to match** |

*Kind B — the CAVEATS with the "outside the cleared cases" implicature* (they negate, but by carving
out "the Gaussian cases that cleared the gate" they imply those cases ARE calibrated):
| File:line | Note |
|---|---|
| `R/extract-repeatability.R:~30` (→ `man/extract_repeatability.Rd:57`) | `@section Interval calibration:` |
| `R/loading-ci.R:~47` (→ `man/loading_ci.Rd:79`) | same section |
| `R/extract-omega.R` (`extract_phylo_signal`, → `man/extract_phylo_signal.Rd`) | same section |

**Proposed wording (Shinichi's voice — he may adjust; confirm with him if he's present):**
- Kind A → *"Point estimates are the supported claim; no cell's interval coverage is certified — the
  covariance routes exist and have focused-test evidence only."*
- Kind B → drop the "outside the Gaussian cases that cleared the gate" carve-out: *"…their empirical
  coverage is not certified for this estimand; treat intervals as exploratory."*

The bar to satisfy: **no shipped surface may state or imply any cell is coverage-calibrated** (design/75).
Point-estimate + route-exists + focused-test-evidence language is fine.

**After rewording:** `devtools::document()` (regenerates only the touched `man/` topics) →
`pkgdown::check_pkgdown(".")` → verify no "is established / calibrated" positive claim remains
(`grep -rniE "calibration is established|is calibrated" R/ DESCRIPTION README.md NEWS.md man/`).

### Optional polish to fold into rc.2 (Shinichi's call — all advisory, none blocking)
- **`\dontrun` (72 topics):** CRAN prefers `\donttest` for merely-slow examples. Reclassify the
  slow-but-runnable ones. *(Note: `\dontrun` count is genuinely 72 — an earlier Codex pass miscounted it
  as 0 using a double-backslash regex; verify with `grep -l '\dontrun{' man/*.Rd | wc -l`.)*
- **`\value` on `ordiplot` + `gllvmTMB_multi-methods`** — add explicit return-value docs.
- **en-GB spelling:** user-facing US spellings in shipped files — `"modeling"` (`add_utm_columns` Rd),
  `"summarized"` (`extract_cross_correlations` Rd), `"standardize"` in some `cli` errors. (False
  positives to leave: the "behavior" book-title citation, `fig.align="center"`, `normalize=TRUE`,
  `initialize`.) `inst/WORDLIST` is the maintainer's **curated 226-term** file — do NOT blind-append.

## 3. The rc.2 ceremony (turnkey — live toolchain, yours)

1. Apply the §2 reword (+ optional polish) → `document()` → `check_pkgdown()`.
2. Local: `devtools::test()` — expect `FAILED 0 | ERROR 0 | SKIP 779 | PASS 7290` (reword is doc-only,
   behaviourally neutral). **Read the structured `as.data.frame()` counts — never grep reporter prose.**
3. Commit (`git commit -F` from a file — `-m` with backticks gets mangled). Push.
4. Build the frozen tarball at the new SHA; ledger it (SHA-256, size, forbidden-path scan:
   no `LOOP/ dev/ docs/ vignettes/articles/ .git .DS_Store`). Run `R CMD check --as-cran` **on the
   tarball** with `NOT_CRAN=false _R_CHECK_CRAN_INCOMING_=true` — expect `Status: 1 NOTE` (New submission).
5. Tag `v0.6.0-rc.2` at the new SHA; push the tag. It auto-triggers `R-CMD-check` (Ubuntu-only, since
   `full_matrix` defaults false on tag push) + `full-check` (heavy). **Immediately dispatch**
   `gh workflow run R-CMD-check.yaml --ref v0.6.0-rc.2 -f full_matrix=true` — it supersedes the Ubuntu-only
   auto-run (concurrency = workflow+ref; cancel-in-progress true on a non-main ref) and gives the 3-OS.
   **Assert all three OS-named jobs** and read `Status: OK` from the LOG, not the green conclusion.
6. Re-run a fresh **NOT-READY-default** adversarial review (Rose + 2 lenses; `.codex/agents/*.toml`) on
   the rc.2 artifact. ≥2 NOT-READY withholds.
7. Update `cran-comments.md` to cite the rc.2 run IDs (it currently cites the rc.1 runs
   29977191886/29977182659). It is `.Rbuildignore`d.
8. Record: `docs/dev-log/check-log.md`, an after-task, overwrite `LOOP/checkpoint.md`. **STOP** —
   report to Shinichi. Do not submit.

## 4. Rehydration recipe (Codex-native)

- `AGENTS.md` is native — read it first, then this doc, then `LOOP/checkpoint.md` (live state),
  `docs/dev-log/2026-07-23-codex-adversarial-findings.md`, `docs/dev-log/known-residuals-register.md`,
  `docs/dev-log/2026-07-22-m4-to-m5-runbook.md`, `docs/dev-log/check-log.md`.
- Team mirror: `.codex/agents/*.toml` — **Rose audit is mandatory** before any readiness claim.
- Live-env (Codex runs the real toolchain): standard R 4.6.0 on this Mac; `export NOT_CRAN=false` +
  `_R_CHECK_CRAN_INCOMING_=true` for the tarball check; `OPENBLAS_NUM_THREADS=1 OMP_NUM_THREADS=1
  MKL_NUM_THREADS=1` for any concurrent R. Evidence dir: `~/gllvmTMB-0.6-evidence/`.
- Verify discipline: read the LOG and open the artifact — exit codes, workflow conclusions, and
  negative greps have each produced a false pass in this programme. RE-DERIVE every SHA from git.

## 5. Blockers / open questions / state you inherit

- **win-builder R-devel: SUBMITTED** (2026-07-23 ~05:00), results email `itchyshin@gmail.com` ~05:25.
  This is the R-devel check CRAN uses for first submissions — the one blocker the rc.1 review raised.
  **macbuilder** returned HTTP 502 (their service down); secondary, redundant with the 3-OS `macos-latest`
  run — optional retry. **Reconcile the win-builder R-devel result into `cran-comments.md` when it arrives.**
  If the reword lands first, a fresh win-builder run on the rc.2 tarball is cleaner.
- **The reword may or may not need Shinichi's exact wording** — he said "fixes done by Codex after
  handover", so proceed with the §2 proposals; if he is present, confirm the phrasing (it's his voice).
- **Rung honesty (D-49/D-66):** name the rung, never unqualified "ready". Current: `platform-clean` at
  rc.1; after the reword + rc.2 checks + win-builder R-devel clean → `submission-ready` PENDING Shinichi's
  submit. Submission remains his.

## 6. Mission control

| Item | State |
|---|---|
| Repo / branch | gllvmTMB · `claude/0.6-m1-close-20260722` @ `a9ecd29f` · pushed `0/0` |
| Release | first CRAN = **0.6.0**, Laplace-only; M1/M3/M4 DONE |
| RC | `v0.6.0-rc.1` platform-clean (tarball 0/0/1, exact-tag 3-OS + heavy green) |
| Blocking | **calibration-claim reword (a class)** → rc.2; then win-builder R-devel + Shinichi's submit |
| CI | authorised (push, Ubuntu, heavy, 3-OS); concurrency = workflow+ref |
| Compute | LOCAL only (D-50) |
| Gates (Shinichi's) | final `v0.6.0` tag · CRAN submission · any readiness claim |

## 7. Files created/modified (this handover)

- `docs/dev-log/handover/2026-07-23-codex-handover.md` (this doc)
- `LOOP/checkpoint.md` (RESUME pointer refreshed to this doc)

The session's full arc (29 commits since `origin/main`) is recorded across `docs/dev-log/check-log.md`
and the `2026-07-22-*` / `2026-07-23-*` dev-log entries; the RC evidence is in
`~/gllvmTMB-0.6-evidence/m5-rc1/`. No source drift since the RC freeze `e9bc655a` (shipped-path diff empty).

## How to resume (paste into a fresh Codex session at the worktree root)

```
Rehydrate from docs/dev-log/handover/2026-07-23-codex-handover.md + AGENTS.md, then execute §2 (reword
the calibration-claim class) and §3 (cut v0.6.0-rc.2, re-run exact-tag checks + NOT-READY review). STOP
at submission-ready; do NOT submit to CRAN or cut the final tag.
```
