# B1/B2 parity notes -- gllvmTMB capability ledger vs GLLVM.jl

Companion notes to `dev/gapclose/build-capability-status.R` (B1) and
`tools/parity_ledger.R` (B2). This file documents the design decisions the
generated artifacts don't spell out inline, so a future editor of the
register or the mapping table can see the reasoning without re-deriving it.

## Vocabulary map (register -> ledger)

| Register status | Ledger status | When |
|---|---|---|
| `covered` | `implemented` | always |
| `partial` | `scope-limited` | default |
| `partial` | `point-fit-recovery` | register text specifically scopes evidence to point estimation/recovery with no interval/calibration claim (the three ISDM rows) |
| `opt-in` | `scope-limited (opt-in)` | MIS-36 (`aghq_ridge = "auto"`) |
| `blocked` | `planned` | default |
| `blocked` | `rejected` | register's OWN text says the capability is withdrawn or deliberately refused by decision, not merely untested (`FORCE_REJECTED` in the B1 script) |
| `claimed` / `reserved` (parser-syntax vocabulary) | `planned` | if either leaks into a mapped row (none currently do -- the register's parser-syntax vocabulary from `01-formula-grammar.md` is a different table this register does not reuse) |

A ledger row backed by several register ids only becomes `rejected` when
**every** contributing id is force-rejected (e.g. `Nonlinear communality
profile` <- CI-06 alone). A row backed by a mix (e.g. `VA / ELBO alternative`
<- VA-01..13, where only VA-08 is force-rejected for `integration = "eva"`)
keeps its normal aggregated status and carries the withdrawal as a note
instead, so one narrow refusal inside a 13-row aggregate doesn't mislabel the
whole capability as rejected.

`FORCE_REJECTED` entries and their textual grounding:

- `CI-06`, `CI-07`: FG-13's own note says "nonlinear communality/correlation/
  proportion profile intervals are withdrawn and blocked, not a pending
  smoke gate."
- `EXT-11`: the same FG-13 note, for `extract_proportions()`'s nonlinear
  profile specifically (distinct from EXT-34's covered boundary contract).
- `VA-08`: "Not an admitted value of `integration`... the EVA engine and
  template remain research-only" -- a considered refusal, not a pending gap.

## Collision resolutions

Per the task brief's "Known name collisions to resolve explicitly":

1. **`cumulative_logit`** -- Julia: ordinal cumulative-logit RESPONSE family
   (folded into its combined row `ordinal_probit / cumulative_logit`). R:
   MIS-30, an ORDERED missing-PREDICTOR imputation family inside
   `mi()`/`miss_control()`. Resolution: the R ledger row is named
   `cumulative_logit (missing-predictor family)` (not bare `cumulative_logit`)
   so `norm_name()` never produces the same key as Julia's combined response-
   family row. Verified structurally by test (5) in
   `tests/testthat/test-gapclose-parity-ledger.R`: the row shows up R-only,
   never in the matched table.
2. **`categorical`** -- Julia: no such row (Julia's unordered response family
   is `multinomial`, and its row is literally named `multinomial /
   categorical`, using "categorical" as a stats-vocabulary synonym for
   *unordered*, not as a distinct family). R: MIS-31, an UNORDERED
   missing-predictor imputation family. Resolution: ledger row named
   `categorical (missing-predictor family)`, distinct from the response-family
   row `multinomial / categorical (response family)` (<- FAM-20 etc.), which
   carries its own note pointing at MIS-31 to warn against confusing the two.
3. **`Ordinal` / `ordinal_probit`** -- R only ships the probit link
   (FAM-14); Julia's row is the combined `ordinal_probit / cumulative_logit`
   (its own default is logit). Resolution: the R ledger row stays named
   `ordinal_probit` only (no alias to the combined Julia string), so the
   logit half of Julia's row is visible as a genuine Julia-only gap,
   dispositioned `port` in `tools/parity_ledger.R` ("gllvmTMB only ships
   ordinal_probit; the logit-link variant is a genuine port target").
4. **`student` (nu)** -- both sides literally use `student`; the row DOES
   match by name (both `implemented`). The divergence is semantic, not a
   naming collision: gllvmTMB's `student()` estimates nu per trait by
   default, GLLVM.jl's parity delta is paid only with nu fixed on both
   sides. Handled via `NOTED_DIVERGENCES` in `tools/parity_ledger.R`, which
   annotates the MATCHED row rather than forcing a false non-match.
5. **`aghq`** -- R: a public opt-in knob (`gllvmTMBcontrol(aghq = ...)`).
   Julia: internal AGHQ-shaped kernel code, unreceipted as a public
   capability, `missing` on Julia's own ledger. The row name matches
   (`AGHQ estimator`), the status genuinely disagrees (R `scope-limited`
   opt-in vs Julia `missing`), and `NOTED_DIVERGENCES` explains why that
   status disagreement is a real finding, not an artifact.
6. **`unique`** -- per CLAUDE.md's modifier doctrine, `unique` is a modifier
   of `latent()` (the diagonal Psi companion), not a separate mode. It never
   appears as its own grid cell in either ledger; R's `unique()`/`*_unique()`
   register rows (FG-05, ANI-02, etc.) are folded as modifier evidence into
   their parent `indep`/`latent` cells. Julia's ledger does not carry a
   `unique` row either, so there is nothing to collide with -- the risk
   named in the brief ("the bridge drops it entirely") is about the R-Julia
   *bridge*, tracked separately under JUL-01/01A, not the covariance-grid
   join.

## Disposition table (Julia-only rows, `tools/parity_ledger.R`)

**`port`** (genuinely owed to R, from the brief's list plus what running the
tool against the live GLLVM.jl repo actually surfaced):
zip/zinb/zib, the logit half of `ordinal_probit / cumulative_logit`,
`censored_poisson`, `Fourth-corner / trait–environment`,
`Concurrent / constrained / RRR ordination`, `Quadratic response`. Three more
named in the brief (`select_lv`, `boundary LRT/anova`,
`ordination_uncertainty`) were not found as literal rows in this build's read
of the Julia ledger (live, `origin/main` of the Dropbox GLLVM.jl checkout) --
kept in the disposition table for completeness per the brief, inert unless a
future Julia-ledger edit turns them into real rows.

**`accounted`** (engine-internal or already-explained, not owed): the
brief's eight items (Felsenstein contrasts, edge-incidence, relaxed clock,
node-frame gradient, Takahashi, EM family, pPCA init, Laplace curvature
contract) plus a substantial second batch discovered by actually running the
tool against the live repo -- granularity mismatches where R has the same
capability under a differently-named/coarser ledger row (the ten `Bridge
...` sub-rows fold into R's two JUL-01/JUL-01A rows; `Species-specific
environmental coefficients` / `Row effects fixed` / `Row effects random` /
`@formula / long+wide data` fold into already-matched rows), Julia's own
parity-testing scaffolding (`Light gllvmTMB logLik named routes`,
`Shared-X light logLik`), and rows where BOTH sides share the same fence by
decision (`Full family R↔Julia parity claim`, `Phylo Model A public interval
promotion`, `Delta/hurdle latent-scale correlation advertising`,
`Non-Gaussian REML`).

**`divergence`** (a real semantic gap under a shared-sounding name, applied
to MATCHED rows via `NOTED_DIVERGENCES`, not the Julia-only disposition
table, since none of the three actually end up Julia-only by name): Student-t
nu, kernel PSD-vs-PD, AGHQ shape. See "Collision resolutions" items 4-5
above; kernel PSD-vs-PD is the third -- R's `kernel_*()` docs require a PSD
input `K`, GLLVM.jl's dense-kernel fitter's positive-definiteness contract
has not been cross-checked against that requirement, so a status MATCH on
the three `kernel × *` rows should be read as unverified equivalence.

## UNVERIFIED (AGENT-INFERRED) items

Four of the brief's eight `accounted` items could not be grounded in the
text actually read from GLLVM.jl's `docs/design/capability-status.md` (full
read, all ~610 lines, at `origin/main` of the Dropbox checkout, this build):
**relaxed clock**, **node-frame gradient**, **Takahashi**, **EM family**,
**pPCA init** (five, not four -- see below). These do not appear as prose or
table content anywhere in the file as read. They are retained in
`tools/parity_ledger.R`'s `ACCOUNTED` table verbatim from the brief, each
marked `UNVERIFIED:` in its reason string, and are inert (never fire) unless
a future edit to the Julia ledger introduces matching content. Two items
from the brief's list WERE grounded directly in the file's own prose:
`Felsenstein contrasts` and `edge-incidence` (the covariance-grid section's
note: "Julia phylo rows share three equivalent likelihood representations
(sparse CHOLMOD, contrasts, edge-incidence)"), and `Laplace curvature
contract` is grounded in the file's own dedicated section (excluded from
row-level parsing by this tool's design, since it uses a different table
header). Treat the five UNVERIFIED reasons as leads, not load-bearing
claims, per the standing AGENT-INFERRED discipline.

## Mission-control config note (ready to paste)

For `~/shinichi-brain/Shinichi/Dashboards/mission-control/live/projects.json`,
the `gllvmTMB` entry -- **not edited by this agent**, per the task brief:

```json
"capability": {
  "source": "docs/design/capability-status.md"
},
"twin": {
  // "unified_matrix" intentionally DROPPED: that file exists only in a
  // stale GLLVM.jl working tree, not at origin/main, so the server's
  // two-file join (this repo's capability-status.md + GLLVM.jl's
  // capability-status.md via tools/parity_ledger.R) should run without it.
}
```

## Files

- `dev/gapclose/build-capability-status.R` -- B1 generator (register ->
  `docs/design/capability-status.md`). Re-run it whenever the register
  changes; `--check` fails loudly on drift or an unmapped row.
- `tools/parity_ledger.R` -- B2 parity tool (R ledger <-> GLLVM.jl ledger).
- `docs/design/capability-status.md` -- generated output, 76 ledger rows
  covering 244 register rows (32 more deliberately unmapped-by-design, with
  reasons, in that file's own trailing table).
- `tests/testthat/test-gapclose-parity-ledger.R` -- the five required tests.
