# After Task: Re-verify GLLVM.jl #101 landed clean against the R bridge

Date: 2026-06-20 (Claude / Ada, autonomous; ultracode). Maintainer directive:
"finish both packages well; confirm #101 landed clean against the R bridge"
(handover `docs/dev-log/recovery-checkpoints/2026-06-20-handover-post-101-landing.md`,
DO NEXT #1). **Evidence only — no register-row promotion.**

## 1. Goal

GLLVM.jl PR #101 (the *wide* R→Julia bridge layer: X / response masks /
mixed-family / grouped dispersion / post-fit simulate / Wald-profile-bootstrap
CIs) merged to GLLVM.jl `origin/main` (`186af2d`). Confirm it landed clean
against the gllvmTMB R bridge by re-running the live `julia-bridge` suite from a
fresh gllvmTMB `origin/main` checkout pointed at a fresh GLLVM.jl `origin/main`
checkout. The R bridge already targets the wide surface, so this is a pure
configuration re-verification — **no R code change**.

## 2. Implemented

Nothing in the package changed. What is now *established as evidence*:

- GLLVM.jl `origin/main` (`186af2d`) instantiates cleanly and exposes the wide
  bridge surface: `isdefined(GLLVM, :bridge_fit) == true` **and**
  `isdefined(GLLVM, :bridge_capabilities) == true`. (The narrow local engine had
  `bridge_capabilities == false`; its presence here confirms #101's layer is on
  main, not just in the old integration tree.)
- The gllvmTMB `origin/main` (`b09f510`) live `julia-bridge` suite, run against
  that GLLVM.jl `origin/main` checkout, is **FAIL 0 / WARN 0 / SKIP 0 /
  PASS 1228**. SKIP 0 is the load-bearing fact: every live-Julia row executed
  (the pure-R-only baseline skips 14 live rows when `GLLVM_JL_PATH` is unset).
- The 1228 count matches the post-#493 live count recorded in the overnight
  briefing (`live Julia bridge FAIL 0 / PASS 1228`), now reproduced against the
  freshly-landed GLLVM.jl `main` rather than the old no-touch integration tree
  (`f7be594`).

## 3. Files Changed

Dev-log only; no implementation, no generated `man/*.Rd`, no NAMESPACE, no
design-doc status change:

- `docs/dev-log/after-task/2026-06-20-bridge-reverify-101.md` (this report).
- `docs/dev-log/check-log.md` (one session entry).

No README / NEWS / ROADMAP / vignette / register / `_pkgdown.yml` edit. The
validation-debt register rows JUL-01 / JUL-01A stay **partial** (promotion is
the row-owner's call + Rose audit + maintainer sign-off — not done here).

## 3a. Decisions and Rejected Alternatives

> **Decision**: Re-verify from fresh detached/clean `origin/main` worktrees of
> *both* repos (`/private/tmp/gllvmjl-main` @ `186af2d`,
> `/private/tmp/gllvmtmb-main` @ `b09f510` on branch
> `claude/bridge-reverify-20260620`).
> **Rationale**: The working checkout sits on the held dirty branch
> `codex/r-bridge-grouped-dispersion` (120 behind main + large uncommitted tree),
> explicitly reserved for maintainer reconciliation; the repo is authoritative.
> **Rejected alternative**: Testing in the working checkout — would pile onto the
> held branch and contaminate its reconciliation.
> **Confidence**: high.

> **Decision**: Point `GLLVM_JL_PATH` at a GLLVM.jl `origin/main` worktree, not
> the local GLLVM.jl checkout.
> **Rationale**: The local GLLVM.jl checkout is on `claude/jl-bridge-capabilities-20260619`,
> which sits on the divergent `codex/non-gaussian-fitter-gradients` base — not the
> #101-bearing main.
> **Rejected alternative**: Reusing the local checkout (would test the wrong,
> narrow engine).
> **Confidence**: high.

> **Decision**: Treat 1228 / 0 / 0 / 0 as parity *evidence*, not a JUL-01/JUL-01A
> `partial → covered` promotion.
> **Rationale**: Hard guard — "PR green != bridge complete != scientific coverage
> passed"; promotion needs the row-owner + Rose + maintainer.
> **Rejected alternative**: Editing the register on a clean pass — a silent
> overclaim.
> **Confidence**: high.

## 4. Checks Run

All from the clean worktrees; Julia 1.10 at `~/.juliaup/bin/julia` (juliaup).

1. Instantiate + load the GLLVM.jl `origin/main` worktree
   (`/tmp/gllvmjl-instantiate.log`):
   `julia --project=/private/tmp/gllvmjl-main -e 'using Pkg; Pkg.instantiate(); using GLLVM; println(isdefined(GLLVM,:bridge_fit)); println(isdefined(GLLVM,:bridge_capabilities))'`
   → exit 0; `GLLVM` precompiled in 5 s; `bridge_fit defined: true`;
   `bridge_capabilities defined: true`.
2. Live bridge suite (`/tmp/gllvmtmb-bridge-reverify.log`), from
   `/private/tmp/gllvmtmb-main`:
   `PATH="$HOME/.juliaup/bin:$PATH" GLLVM_JL_PATH=/private/tmp/gllvmjl-main Rscript --vanilla -e 'devtools::test(filter="julia-bridge", reporter=c("summary"))'`
   → exit 0; progress region is 100% `.` with zero `F`/`W`/`S` markers →
   **PASS 1228 / FAIL 0 / WARN 0 / SKIP 0** (counted deterministically from the
   summary-reporter stream; the progress region contained no non-`.` glyphs).

Deliberately **not** run: 3-OS matrix (routine CI is ubuntu-only by cost
discipline; 3-OS is a pre-release gate); full `devtools::check()` (this slice
touches no R/ source, only dev-log); `devtools::document()` (no roxygen change).

## 5. Tests of the Tests

No new or modified tests. This is a re-run of the existing live `julia-bridge`
rows. The diagnostic property exercised is **SKIP → 0**: with `GLLVM_JL_PATH`
set, the 14 normally-skipped live rows execute and pass, so the count rises from
the ~357-pass pure-R-only baseline to 1228. A regression in #101's bridge layer
would surface as a non-zero `F` in the same stream — none appeared.

## 6. Consistency Audit

- `rg -n "JUL-01" docs/design/35-validation-debt-register.md` → rows remain
  `partial`; this report introduces no promotion. **Verdict: clean.**
- `git -C /private/tmp/gllvmtmb-main status --short` → only the two dev-log files
  above are added; no R/, man/, NAMESPACE, NEWS, README drift. **Verdict: clean.**
- No user-facing prose, grammar, keyword, or family text touched → the stale-
  wording / keyword-grid / `meta_known_V` / `gllvmTMB_wide` prose scans are N/A
  for this slice.

## 7. Roadmap Tick

N/A. Evidence run; no `ROADMAP.md` phase status or progress chip changed.

## 8. What Did Not Go Smoothly

The handover estimated `PASS ~1212`; the actual is 1228. This is **not** a
discrepancy: `~1212` was the count against the old no-touch integration tree
(`f7be594`) recorded in the bridge finish-map, while 1228 is the count after
#493's bridge tests (cbind binomial routing, point-only correlations, gate
hardening) landed on `main` — exactly the 1228 the overnight briefing already
recorded for the post-#493 live suite. The fresh GLLVM.jl `main` reproduces it
with zero fails and zero skips. No other friction.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

- **Curie (simulation/testing)**: every live recovery + CI-fan-out row ran
  (SKIP 0) and passed against the freshly-landed engine — the live layer is
  genuinely exercised, not skipped-as-green.
- **Rose (scope honesty)**: a clean 1228 pass is parity evidence, not coverage;
  JUL-01/JUL-01A stay `partial`. The report is dev-log-only by construction.
- **Grace (toolchain/reproducibility)**: the GLLVM.jl `main` worktree instantiated
  against the shared depot in seconds; the verification is reproducible from the
  two recorded commands and the pinned commits (`186af2d` / `b09f510`).

## 10. Known Limitations and Next Actions

- This is **in-sample parity evidence** for the bridge routing against
  `main`-on-`main`; it does not establish native-vs-Julia scientific parity
  (JUL-01/JUL-01A `covered`), 3-OS portability, structured-term routing, or new
  bridge families — all decision-gated per `2026-06-19-bridge-finish-map.md`.
- **Next (held for go-ahead):** J1 — wire issue-#65's analytic Laplace gradient
  (`src/laplace_grad.jl`, FD-verified, *not yet wired into the fitter*) into the
  production `fit_*` (poisson → nb/gamma/beta/binomial) behind a
  logLik-Δ ≤ 1e-6 vs FD gate, on a branch off GLLVM.jl `main`. Engine work;
  building + verifying on a branch is authorized, merge needs sign-off.
- Cleanup: the clean worktrees `/private/tmp/gllvmjl-main` and
  `/private/tmp/gllvmtmb-main` are verification scratch; prune when done.
