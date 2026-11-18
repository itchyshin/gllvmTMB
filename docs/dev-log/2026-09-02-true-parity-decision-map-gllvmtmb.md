# Decision map — true R<->Julia parity (gllvmTMB half), 2026-09-02

A map, not a build plan: what is decided, what is still fog, and what is out. Twin counterpart:
GLLVM.jl `docs/dev-log/core070/true-parity-decision-map.md` (branch `codex/core070-aghq-20260830`).
Sibling pair: drmTMB `docs/dev-log/2026-09-02-true-parity-decision-map.md`. Owner: Ada (Claude lane
`claude/gapclose-20260902`). Shared page across the four lanes: drmTMB2's "WHERE WE ARE HEADING"
(2026-09-02), not contradicted here.

## Destination

gllvmTMB and GLLVM.jl fit the same user-facing models under the same names and the same four
grouping levels (`unit`, `unit_obs`, `cluster`, `cluster2`), with the R spellings canonical and Julia
translating. gllvmTMB carries `docs/design/capability-status.md` whose row names match GLLVM.jl's
byte-for-byte so the mission-control twin board can show matched, R-only, and Julia-only rows.
`tools/parity_ledger.R` prints every Julia-only export as "AHEAD OF gllvmTMB, ACCOUNTED FOR IN
WRITING" with a reason or "genuinely owed", and returns CLOSURE PASS. The user-facing rows Julia
added first (zero-inflated families first) are ported to R; engine-internal Julia-only machinery is
accounted for in writing, never ported for its own sake. The bridge stays one-way: R calls Julia.
An ecology graduate student reading gllvmTMB's front page for the first time meets no undefined
term, and every refusal names a route that fits.

## Decisions so far

- 2026-09-02 (Shinichi; recorded in the approved plan `~/.claude/plans/read-agents-md-and-docs-dev-log-handover-lovely-grove.md`):
  parity is both ways for user-facing capabilities; the bridge stays R->Julia; `zip`/`zinb`/`zib` come
  to R; `unit` defaults to `NULL` like `unit_obs`/`cluster`; both twins must carry the four grouping levels.
- **D-204 (vault, 2026-09-02, Shinichi in the drmTMB session, verbatim "both ways for user-facing; keep the
  legacy rewrite; file the issues"):** twin parity is BOTH WAYS for user-facing capabilities as the standing
  rule across the twin pairs — Julia-first user-facing models get ported to R; engine-internal Julia-only
  machinery is accounted for in writing; the bridge stays one-way. This map's direction line now cites a
  recorded decision, not an analogy.
- D-157 (2026-08-17): MSPL parked; one outer penalty per fit; never stack ridge and MSPL.
- Brain note 2026-08-20 (Iwo ridge sensitivity): runaway loading -> ridge/VA lane; tau needs evidence
  before it becomes guidance.
- Maintainer standard 2026-08-20: plain language on every reader-facing surface and in reports.
- By analogy from the DRM pair: intervals = capability parity, not coverage (D-181 #2); cross-family
  native routes are a permanent boundary (D-179 #3); base-R names are canonical (D-202).
- Merge authority (CLAUDE.md): API, grammar, likelihood, and new-family changes need Shinichi before
  merge; docs, tests, and message text do not.

## Not yet specified (the fog)

| ticket | kind | default if "use your judgment" |
|---|---|---|
| `*_slope()` vs `column_coef()`: two parallel API families both live on main (NEWS 0.7.1). Which is canonical, and does the other get a deprecation path? | decide-with-Shinichi | both recorded as current in the ledger; no deprecation in this arc |
| #1080 dispersion field names invert their meaning (`phi_gamma` is a shape, `phi_gamma_delta` a CV, `sigma_student` a scale). Breaking rename with shims, or extractor + docs only? | decide-with-Shinichi | `dispersion()` extractor + docs now; rename deferred to 0.8 |
| Constrained / concurrent / RRR ordination and the quadratic response model: 0.7.x or 0.8 headline? | decide-with-Shinichi | 0.8; issues filed with GLLVM.jl paths as reference |
| A cumulative-logit ordinal response family in R collides with R's `cumulative_logit()` missing-predictor family. Rename which? | decide-with-Shinichi (Boole) | the new response family takes a distinct name; the imputation family keeps its name |
| Ordinal-probit degeneracy detector ships disarmed (#897/#1097). Calibrate now or leave disarmed with a warning? | research (Fisher) | leave disarmed; document in current-limits |
| Student-t nu: Julia fixes it, R estimates it per trait. Structural divergence or a parity row? | task (read both ledgers), then decide | record as divergence with a written reason |
| R accepts PSD kernels, Julia requires PD (GLLVM.jl lane lead). Which contract is canonical? | decide-with-Shinichi | R's PSD acceptance stays; Julia documents the stricter check |

## Out of scope (with the reason)

- Interval coverage campaigns: capability parity is the claim, not coverage (D-181 #2 by analogy).
- MSPL admission or public SE / vcov / confint: D-157 signed park.
- VA-vs-Laplace accuracy study: an open pre-registered study, not a parity item.
- iJSDM cell-7 non-retained qualification: parked by the 2026-09-02 re-aim; handover steps 3-4 remain owed to whoever resumes it.
- Designs 129 (prediction uncertainty), 128 (slope-per-family campaign), 65 C4 (kernel unification): owned campaigns, not forgotten items.
- The 14-slot family object refactor (Design 02): L-sized; filed as a design issue, not folded into hygiene.
- Porting engine-internal Julia machinery (Felsenstein contrasts, edge-incidence, relaxed clock, EM family, Takahashi selected inversion): accounted for in writing.
- Any edit under PR #1236's files, GLLVM.jl, or the Cursor MSPL lanes: live foreign lanes (D-88).
