# After-task — Structural-slope Phase A scaffold close (2026-05-26)

**Date:** 2026-05-26
**Lead:** Claude/Shannon (composer), with persona-named per-PR
review (Boole + Gauss + Noether + Curie + Fisher + Rose + Pat).
**Status:** Phase A *design + test scaffold* lane closed. Phase A
*implementation* lane (Design 56 §9.1-§9.6 = TMB engine + parser +
recovery-test activation) opened and handed off to Codex's lane.
**Backed by:** [Active Plan](../../../plans/please-have-a-robust-elephant.md)
ratified 2026-05-26.

## 1. Scope

This after-task closes the Claude/Shannon contribution to the
**structural-dependence × random-slope** plan (Active Plan 2026-05-26).
The plan's full surface is multi-week TMB engine work + parser work +
non-Gaussian validation (estimated 30-50 days, 18-30 PRs total per
the plan). What landed today is the design + test scaffolding;
the implementation lane is Codex's.

## 2. PRs landed today

Six PRs, in commit order (~2200 lines of design + test scaffold
total):

| PR | Slice | Lines | What |
|---|---|---:|---|
| **#277** | A0 | 513 | Design 55 — Structural-dependence × random-slope grammar contract. Drop `phylo_slope`/`animal_slope`; extend canonical structural keywords (`phylo_*`, `animal_*`, `spatial_*`, user-supplied A via `vcv = A`) to accept `(1 + x | id)` LHS wide / `(0 + trait + (0 + trait):x | id)` long. |
| **#279** | A1 closeout + Design 56 stub | ~250 | Design 55 §A1 failure memo — parser-only hypothesis structurally disconfirmed by 2026-05-26 Explore audit. Design 56 stub opened as escalation slot. |
| **#280** | Design 56 full | 593 | Stage 3 engine-generalisation contract. Six implementation sub-phases 56.1 → 56.6, ~13-21 days estimated. Codifies the matrix promotion (b_phy_slope → b_phy_aug), the n_traits → n_lhs_cols audit (nine sites), the 2 × 2 (intercept, slope) covariance parameterisation, and the fail-loud / silent-collapse invariant (§7). |
| **#282** | Phase 56.4 skeleton | 232 | `tests/testthat/test-phylo-unique-slope-gaussian.R` — the canonical recovery-test template. Records σ²_int, σ²_slope, cov, byte-identity wide↔long, and the negative-test contract per Design 56 §7.3. |
| **#283** | A2-A5 skeleton bundle (6 cells) | 320 | `phylo_{latent, indep, dep}`, `animal_unique`, `spatial_unique`, `relmat_unique` × slope × Gaussian — mirror the #282 template; per-cell Σ_b shape documented in each. |
| **#284** | Phase A skeleton bundle (rest, 9 cells) | 327 | `animal_{latent, indep, dep}`, `spatial_{latent, indep, dep}`, `relmat_{latent, indep, dep}` — closes the 16-cell APPLICABLE matrix per Design 55 §5. |

**Net contribution to the test surface**: 16 skeleton test files
covering all 16 APPLICABLE cells per Design 55 §5 (4 keywords ×
4 structural families; `scalar` × any family stays NOT APPLICABLE
by design). Each test is gated by `skip_until_stage3()`; activates
by deleting one line per file once Phase 56.1-56.3 lands.

## 3. What this session did NOT do

Honestly cataloguing the remaining work so the handoff is clean:

- **Phase 56.1**: TMB template promotion (engine PR, ~3-5 days). Promote `b_phy_slope` from `vector<Type>` to 3D array `b_phy_aug(n_aug × n_lhs_cols × n_blocks)`; add `DATA_INTEGER(n_lhs_cols)` + bivariate-prior parameters; gate behind `use_phylo_slope_correlated` flag default FALSE. Existing path stays byte-identical.
- **Phase 56.2**: R-side `n_traits` → `n_lhs_cols` audit edit (~2-3 days). Nine sites in `R/fit-multi.R` per the Sokal 2026-05-09 audit; per-site decision documented in PR.
- **Phase 56.3**: parser changes per Design 55 §4 (~2-3 days). `.assert_no_augmented_lhs()` permits `1 + x` LHS within phylo_*; `parse_covstruct_call()` classifies LHS form; `phylo_unique` rewrite extended to accept bar form.
- **Phase 56.4 activation**: small follow-up to delete `skip_until_stage3()` from the 16 skeleton files as engine catches up; per-cell recovery and byte-identity assertions go live.
- **Phase 56.5**: walk APPLICABLE cells per Design 55 §5 (~3-5 days, multiple sub-PRs). Each cell's skeleton becomes a real recovery test.
- **Phase 56.6**: deprecation + register update (~1-2 days). Soft-deprecate `phylo_slope` and `animal_slope`; update six articles per Design 55 §6.4; walk validation-debt rows RE-02, FG-15, PHY-06, ANI-06, new SPA-slope row to `covered` for Gaussian.
- **Phase B (B0-B5)**: ~17-25 days of non-Gaussian validation. Each (structural × keyword × LHS × family) cell evaluated for identifiability; recovery tests added family-by-family.

Total remaining: ~30-46 days of focused TMB engine + parser + test-activation work.

## 4. Lessons captured (Kaizen)

Each is a numbered point for `docs/dev-log/check-log.md` once
this slice closes (deferred — `check-log.md` is owned by Codex's
active PR #281 and shouldn't be edited from here per the
worktree-discipline rule).

### 4.1 Parser-only-hypothesis structurally disconfirmable in code review

Design 55 §A1 specified an "iterative engine-effort approach" — try
parser-only on the simplest case, escalate to Stage 3 if it fails.
The 2026-05-26 Explore audit + subsequent code reading showed the
hypothesis was **structurally disconfirmable before running any
code**: (a) `phylo_unique` parser doesn't accept bar form today;
(b) the Sokal 2026-05-09 silent-collapse bug means the engine
truncates augmented LHS even if the parser accepts; (c) the 2 × 2
covariance for correlated intercept+slope isn't representable in
the current TMB block. Rose's stop condition fired by argument
rather than by empirical run.

**Lesson**: when an iterative hypothesis can be falsified by code
reading at lower cost than empirical run, document the falsification
in a closeout memo and escalate. Don't burn the empirical run when
the structural disconfirmation is durable.

### 4.2 Test scaffolds before engine work

Per the maintainer's protocol note this session: *"small simulations
to see whether it's running and also estimating the stuff. I think
that's how you've been implementing new capabilities."* Test
skeletons landed BEFORE the engine work catches up — gated by
`skip_until_stage3()`, recording the per-cell recovery contract
in code. When the engine lands, removing `skip_until_stage3()` per
file activates the test instantly. The skeleton is durable evidence
of the contract, not just design-doc prose.

**Lesson**: test surface FIRST when the design is more stable than
the engine implementation. The test files lock in the contract that
the engine must meet; activation is mechanical (delete one line).

### 4.3 The fail-loud / silent-collapse boundary (Design 56 §7)

Sokal's 2026-05-09 empirical confirmation (commit `7e90f036`)
documented that loosening the parser without extending the engine
produces silently-wrong fits — byte-identical objectives across
intercept-only and augmented-LHS formulas, T × d_B `Lambda_hat`
instead of `2T × d_B`. Design 56 §7 codifies the invariant: parser
loosening + engine block + runtime assertion + negative test must
all land together. Any PR that loosens `.assert_no_augmented_lhs()`
without extending the engine block it routes through is rejected
at review time.

**Lesson**: the silent-collapse anti-pattern has a named
mitigation now. Cite Design 56 §7 in any PR that touches the
augmented-LHS parser surface.

### 4.4 Persona-active naming + worktree discipline held

All six PRs today named the active personas in commit messages
and PR descriptions. Worktree discipline held — each PR on its
own branch in its own filesystem worktree, no shared edits with
Codex's parallel work (Codex on `codex/morphometrics-long-wide`
and `codex/joint-sdm-figure-repair-2026-05-26` etc.). The
prior session's Sokal-style accidental fast-forward of the
maintainer's branch did not recur.

**Lesson**: the worktree pattern + persona naming is paying
dividends. Continue the discipline.

### 4.5 CI infrastructure outage handled

GitHub Actions had a window of HTTP 403 / `r-lib/actions` download
failures (~12:17-12:50 UTC). Four main-branch R-CMD-check runs
went red as a result; one rerun succeeded once infra recovered.
The fast-path docs-only classifier still works. Admin-merge under
broken-infra was used once (PR #280 for the design-doc expansion)
and immediately produced a noise-floor red on main; future PRs
in similar situations should prefer waiting for infra recovery.

**Lesson**: don't admin-merge when infra is broken and the only
verification path is CI. The noise-floor cost is real even when
the diff is trivially safe.

## 5. Personas active this session

| Persona | Contribution |
|---|---|
| Boole | Parser-spec §3.1 + §4 of Design 56; per-cell parser-spec citations in skeleton tests; phylo_unique bar-form extension specification |
| Gauss | TMB template promotion §3 + §5.2 + §9.1 of Design 56; engine-change risk assessment in Design 56 §11 |
| Noether | Math contract §3 + §5.1 of Design 56; identifiability §5.3; cross-family generalisation §6 |
| Curie | Simulation-fixture design `make_phylo_unique_slope_fixture()`; per-cell recovery test templates §9.4 + §9.5 |
| Fisher | Per-cell recovery targets in the 16 skeleton tests; Phase B scoping §B0 framing |
| Rose | Scope honesty §1 + §7 + §8 of Design 56; scope-honest skip-gating on every skeleton test; "what this session did NOT do" §3 of this report |
| Pat | Reader-clarity sanity check on Design 55 + Design 56 prose; matching test-file naming convention to existing patterns |
| Shannon | Drafting + cross-team coordination; the Codex handoff message; this after-task report |
| Claude | Composer; session-level pacing and scope decisions |

## 6. Handoff to Codex

The Codex-facing handoff message was drafted and delivered to the
maintainer earlier in this session. Key handoff content:

- Phase 56.1 entry points: `R/brms-sugar.R:1543-1576`,
  `R/brms-sugar.R:2317-2325`, `R/parse-multi-formula.R:107-145`,
  `R/fit-multi.R:1150-1301`, `src/gllvmTMB.cpp:186-195,
  526-542, 701-704`.
- Hard boundaries: no engine work from Claude; no shared worktree
  edits.
- Estimated calendar: 13-21 days Phase A + 17-25 days Phase B
  from authorisation to plan close.
- Outstanding question for Codex: timeline + alternative
  framing if engine work is too heavy for current Codex queue.

## 7. Validation-debt register (no rows moved)

Per Design 50 §9 and Design 55 §A6: register row movement waits
for evidence. No row moved this session because no engine work
landed. The relevant rows stay:

- **RE-02** (one random slope): `partial` (test-phylo-slope.R only).
- **RE-03** (s ≥ 2 random slopes): `blocked`.
- **FG-15** (phylo_slope keyword): `partial`.
- **PHY-06** (phylo-slope keyword): `partial`.
- **ANI-06** (animal_slope): `partial`.
- **SPA-slope row**: not yet added (Phase 56.6 adds it).

All five rows walk to `covered (Gaussian)` only when Phase 56.5
sub-phases land their recovery tests AND Phase 56.6 ships the
register edit + soft-deprecation.

## 8. Cross-references

- [`docs/design/55-structural-slope-grammar.md`](../../design/55-structural-slope-grammar.md) — Phase A0 contract.
- [`docs/design/56-augmented-lhs-engine-stage3.md`](../../design/56-augmented-lhs-engine-stage3.md) — Stage 3 engine contract (6 sub-phases).
- [`docs/dev-log/audits/2026-05-26-design-55-a1-closeout.md`](../audits/2026-05-26-design-55-a1-closeout.md) — A1 failure memo.
- [PR #277](https://github.com/itchyshin/gllvmTMB/pull/277), [PR #279](https://github.com/itchyshin/gllvmTMB/pull/279), [PR #280](https://github.com/itchyshin/gllvmTMB/pull/280), [PR #282](https://github.com/itchyshin/gllvmTMB/pull/282), [PR #283](https://github.com/itchyshin/gllvmTMB/pull/283), [PR #284](https://github.com/itchyshin/gllvmTMB/pull/284) — the six structural-slope PRs.
- [`tests/testthat/test-phylo-unique-slope-gaussian.R`](../../../tests/testthat/test-phylo-unique-slope-gaussian.R) — canonical template; mirror file for additional cells.
- 15 sibling skeleton test files in `tests/testthat/test-{phylo,animal,spatial,relmat}-{latent,unique,indep,dep}-slope-gaussian.R`.

## 9. Roadmap tick

**N/A.** No `ROADMAP.md` row changed status because the structural-slope
lane is mid-implementation per Design 55 + Design 56. The roadmap
row that walks to a status change is Phase A close (per Design 55
§A7) and Phase B close (per Design 55 §B5); both are downstream
of Phase 56.1-56.6 implementation. Codex's PR #281 owns active
ROADMAP edits; this slice deliberately doesn't touch it per
worktree discipline.

— Claude/Shannon, with Boole + Gauss + Noether + Curie + Fisher
+ Rose + Pat lenses applied across the six PRs.
