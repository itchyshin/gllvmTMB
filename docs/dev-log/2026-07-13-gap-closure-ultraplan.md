# gllvmTMB 0.5 → 0.6 gap closure — ultra-plan (2026-07-13)

**Author:** Claude (rehydrated from `handover/2026-07-13`). **Strategy:** 0.5 is the
"cover-everything" dev cycle; we do **not** release 0.5 — we accumulate the gap list
and release at **0.6**. `main` @ `8ec261bb` (branch `claude/release-0.5.0`).

> **GOAL (one sentence):** close the capability-widget gap list — headline = give the
> point-only interval surface a *coverage certificate* — by **executing existing
> approved designs** (66 coverage ADEMP, 80 evidence bars) through their gates, not by
> re-inventing protocols.

## Prior-work sweep — what already exists (reconcile, don't rebuild)

- **Design 66 (`docs/design/66-capstone-power-study.md`)** — APPROVED ADEMP pre-spec
  for the power/accuracy/**coverage** capstone. Already defines aims, estimands
  (`Sigma_unit_diag`, off-diagonal correlation; loadings diagnostic-only), methods
  (profile vs parametric-bootstrap CIs), and **compute phasing** (Phase 1 local pilot
  n_sim≈200 via `dev/m3-pilot-launch.R` over the validated `dev/m3-grid.R` harness;
  Phase 2 core grid n_sim=2000 on HPC). **This IS the interval-coverage headline.**
- **2026-06-23 scaling gate (Design 66)** — the current blocker. Do NOT launch the
  broad Totoro/DRAC campaign or promote `CI-08`/`CI-10` until four repairs land:
  (1) quarantine pre-2026-06-24 binary-logit artifacts (not `binomial_probit`
  evidence); (2) ordinal-probit cells produce **primary coverage rows** or are
  excluded from the confirmatory core; (3) `signal=0` is **not** reported as Type-I
  for positive `Sigma_unit_diag` targets; (4) decision aggregates report **MCSE with
  explicit fit-health denominators**. First compute step after the audit = an
  immutable-chunk **smoke ladder**, not the full n_sim=2000 grid.
- **Design 80 (`80-nongaussian-re-evidence-bars.md`)** — the three-bar honesty frame.
  Bar 1 identifiability · Bar 2 point recovery at adequate n · **Bar 3 calibrated
  variance across regimes = REML/AGHQ**. Interval coverage = the Bar-3 campaign. AGHQ
  is what lets the **logit families** (binomial, ordinal, beta) reach Bar 3.
- **Design 79** — covariance taxonomy; the `||` cells are landed (§4, §7.2).
- **Branch/worktree state:** the gap-relevant `agent/*` branches
  (`coverage-target-fix`, `nbinom1-tier-coverage`, `nbinom1-unskip`, `cluster2-tier`,
  `cluster2-family-sweep`, `bootstrap`, `fix-animal-slope`) are **all merged** (0
  ahead of main) — their work is in `main`. Only `agent/capstone-power-study` is 1
  commit ahead (a stale Design-66 ISSUE-DRAFT; superseded by the approved doc on
  main). All `/private/tmp/*` worktrees are prunable Codex temps — no live work.

## Phases, slices, sequencing

### PHASE A — Interval coverage (HEADLINE). Execute Design 66 through its gate.
| Slice | Input → Output | Lane / model |
|---|---|---|
| **A0** Punch-list audit | Design 66 §12 locked plan + 2026-06-23 scaling gate + Design 35 rows CI-08/CI-10 → a concrete "what blocks Phase 2" repair list + smoke-ladder spec. **Cheap, this session.** | Claude / Opus + statistical-reviewer lens |
| **A1** Pilot refresh + 4 gate repairs | Run `dev/m3-pilot-launch.R` (n_sim≈200) locally; land the 4 metric repairs (logit-artifact quarantine, ordinal primary rows, signal=0 fix, MCSE+health denominators) | **Codex** (live R/TMB) / Terra |
| **A2** Smoke ladder → Phase 2 grid | Immutable-chunk smoke ladder → n_sim=2000 core grid (family × RE-structure × source × d × n × signal) | **Codex + Totoro** (≤100 cores; **NOT** GitHub Actions, D-50) |
| **A3** Certify + label | Coverage/power/bias surface → flip earned cells point-only→coverage-checked on the widget + NEWS; keep honesty fencing where not earned | Claude / Sonnet + Rose |

Dependency chain: **A0 → A1 → A2 → A3** (sequential). A0 is free and gates everything.

### PHASE B — Random-slope recovery evidence (`||` grammar done; evidence is the gap)
- **B1** Diagnose tweedie ~44% slope-SD over-estimate. Ridge (p↔φ↔σ) already ruled out
  by the fixed-p test → suspect Laplace / small-sample. Design 80 prescribes a
  first-class **`p`-fix escape hatch** (`map`). Output: diagnosis → fix *or* documented
  limitation + #388 gate decision. **Independent, self-contained — parallelizable now.**
  *(statistical-reviewer / Opus + Codex fits)*
- **B2** nbinom1 slope recovery (reconcile merged `nbinom1-*` work, extend). *(Codex)*
- **B3** Ordinary no-prefix `latent||` (block-diagonal Λ) recovery test. *(Claude scaffold + Codex verify)*
- **B4** Heavy `unit_obs`/`cluster2` Tier-3 slope engines — live TMB. *(Codex lane)*

### PHASE C — Missing responses
nbinom1 recovery + `mi()` predictor coverage (Designs 59/67–71 exist). *(Codex)*

### PHASE D — Fitted diagnostics breadth
Extend `predictive_check()`/residuals/`diagnostic_table()` beyond Gaussian/Poisson/NB2
→ binomial, Gamma, beta. *(Claude + Codex)*

### PHASE E — Deep 0.6→1.0 lanes (design-first; most PARK past 0.6)
- **E1 AGHQ** (Design 80 Bar-3) — couples to A: it's what makes logit families *pass*
  coverage. High value, hard. *(Codex, live TMB)*
- **E2** non-Gaussian / weighted / missing-data REML (Gaussian pilot only today).
- **E3** delta/hurdle latent-scale correlation reporting convention (design gap, not a bug).
- **E4** categorical — major development; **likely not 0.6**.

### PHASE F — Doc-honesty one-by-one review WITH Shinichi
The standing gate before ANY eventual 0.6 CRAN submission (intervals framed
recovery-only; delta/hurdle "do not advertise"). Not codeable — a deliberate session
with Shinichi, page by page. Blocks release, not development.

## Leverage order (recommended)
1. **A0 now** (free, this session, Claude) — turn the Design-66 scaling gate into a
   concrete punch list. Highest leverage: it unblocks the headline and costs nothing.
2. **B1 tweedie diagnosis** in parallel (independent, self-contained).
3. **A1 → A2** the campaign (Codex + Totoro) — headline; needs a **cross-tool handoff**.
4. **C / D** fill as capacity allows.
5. **E / F** are 0.6→1.0 — design-first, defer.

## Estimate & shape
- **Fits one session?** No. A0 + B1-scoping + B3-scaffold + this plan fit *this*
  session (Claude). The compute campaign (A1/A2) and heavy live-TMB slices (B2/B4/C/E1)
  are **Codex + Totoro** → **needs a handoff**. Multi-session, cross-tool.
- **Members plan-review before executing A2:** a `statistical-reviewer` lens on the A0
  punch list — coverage campaigns fail on ADEMP design, and A2 spends real Totoro time.
- **Compute:** Totoro (384 cores, ≤100 shared-usage) for A2/E1; DRAC for a larger
  gated array. **Never GitHub Actions** for campaigns (D-50).

## Verify
Every "cell covered" claim → a fresh statistical-reviewer/Rose lens (D-43: default
NOT-DONE). Full-suite closure sums the **`error`** column too. Recovery cells under
`GLLVMTMB_HEAVY_TESTS=1 NOT_CRAN=true`. #388: validate before you advertise a family.
