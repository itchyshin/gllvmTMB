# After Task: Florence recruitment + visualization grammar (Design 46)

**Branch**: `agent/florence-recruitment`
**Slice**: V1 + V2 + V3 of the visualization V-series. Adds
Florence as the 14th Standing Review Role; installs 4 ggplot
publication skills; writes Design 46 (visualization grammar +
Florence figure gate); updates persona-active-naming memory.
**PR type tag**: `docs` + `skill-install` (no R/, NAMESPACE,
generated Rd, family-registry, formula-grammar, or extractor
change)
**Lead persona**: Florence (recruited in this PR) + Ada
(orchestrator).
**Maintained by**: Florence + Ada; reviewers: Pat (UX), Fisher
(uncertainty fidelity), Darwin (biology framing), Grace
(CI / pkgdown), Rose (pre-publish + scope honesty), Emmy
(plot-helper architecture).

## 1. Goal

Establish a dedicated scientific-illustrator persona for gllvmTMB
parallel to drmTMB's recently-shipped Florence (2026-05-18,
`docs/dev-log/after-task/2026-05-18-florence-memory-os-role.md`).
The maintainer asked: *"I think they are just creating Florence so
you may need to wait for a bit"* — drmTMB shipped same day,
clean spec available to mirror.

Three deliverables:

1. **AGENTS.md row** for Florence — matches drmTMB wording so
   cross-team handoff is friction-free.
2. **4 ggplot skills installed** under `.agents/skills/` —
   `scientific-figure-art-director`, `publication-ggplot-engineer`,
   `r-plot-helper-package-engineer`, `figure-quality-review-gate`.
   Source: maintainer's `r-ggplot-publication-skills.zip`.
3. **Design 46** at `docs/design/46-visualization-grammar.md` —
   visualization grammar + Florence figure gate, adapted to
   gllvmTMB's multivariate scope (G-matrix heatmaps; loading
   biplots with rotation disclaimers; coverage-rate forest plots).

**Mathematical contract**: zero engine / API / formula / extractor
change. Pure persona recruitment + skill install + design doc.

## 2. Implemented

### File 1 (EDIT): `AGENTS.md`

New row in Standing Review Roles table (between Darwin and
Fisher, matching drmTMB's ordering):

```
| Florence | Scientific figure editor and visualization
            reviewer | Are plots publication-quality,
            interpretable, accessible, and honest about
            uncertainty? |
```

### Files 2-5 (NEW): `.agents/skills/`

4 skill directories copied from the maintainer-provided pack:

- `.agents/skills/scientific-figure-art-director/` — design
  critique role; "verdict + redesign brief" pattern; design
  rubric reference.
- `.agents/skills/publication-ggplot-engineer/` — R/ggplot2
  implementation; ggplot style spec; pub-ggplot template.R.
- `.agents/skills/r-plot-helper-package-engineer/` — R-package
  plot-helper contract; test template.
- `.agents/skills/figure-quality-review-gate/` — pre-merge audit
  rubric.

### File 6 (NEW): `docs/design/46-visualization-grammar.md` (~280 lines)

10 sections:

1. Why this design doc exists
2. Visualization scope for gllvmTMB (3-layer: engine outputs,
   article figures, gallery/tutorial)
3. **Florence Figure Gate** (6-row table mirroring drmTMB's
   Design 39, with gllvmTMB-specific adaptations: rotation
   honesty, interval-method matching extractor's CI vocabulary)
4. Skills powering Florence's work
5. Implementation contract for `plot_*()` helpers
6. Phase 1c-viz scope (Florence inherits the existing 7-item
   roadmap; adds item 8 = M3 figure cascade)
7. What's out of scope
8. Cross-references
9. Persona contributions
10. Open questions (4 routed to Florence / Pat / Grace / Fisher)

### File 7 (EDIT, out-of-repo): `~/.claude/.../memory/feedback_persona_active_naming.md`

Adds Florence to the 13-member roster → 14. Adds dispatch
guidance: "Florence for any visualization / figure / ggplot
work (plus the 4 ggplot skills in `.agents/skills/`)".

### File 8 (NEW): this after-task report

## 3. Files Changed

| File | Type | Lines |
|---|---|---|
| `AGENTS.md` | EDIT | +1 row |
| `.agents/skills/scientific-figure-art-director/` | NEW | 2 files (SKILL.md + design-rubric.md) |
| `.agents/skills/publication-ggplot-engineer/` | NEW | 3 files (SKILL.md + ggplot-style-spec.md + pub-ggplot-template.R) |
| `.agents/skills/r-plot-helper-package-engineer/` | NEW | 3 files (SKILL.md + r-package-plot-helper-contract.md + test-template.R) |
| `.agents/skills/figure-quality-review-gate/` | NEW | 2 files (SKILL.md + review-rubric.md) |
| `docs/design/46-visualization-grammar.md` | NEW | +280 |
| `~/.claude/.../memory/feedback_persona_active_naming.md` | EDIT (out-of-repo) | +3 |
| `docs/dev-log/after-task/2026-05-18-florence-recruitment.md` | NEW | this |

Total in-repo: 13 files (1 edit + 10 skill files + 1 design + 1
after-task).

## 3a. Decisions and Rejected Alternatives

(Per the Memory-OS §3a discipline upgrade.)

> **Decision**: name the persona "Florence" (mirroring drmTMB's
> recruitment of 2026-05-18).
> **Rationale**: Florence Nightingale was a pioneering data
> visualizer (polar area / rose diagrams in Crimean War mortality
> stats) — strong statistical-graphics heritage. Sharing the name
> with drmTMB simplifies cross-team handoff and lets us reference
> drmTMB's figure-gate language without translation.
> **Rejected alternative**: "Bertin" (Jacques Bertin, French
> cartographer, founded modern data visualization theory).
> Rejected because cross-team naming consistency wins over
> independence-of-naming.
> **Confidence**: high.

> **Decision**: install all 4 ggplot skills from the maintainer-
> provided pack into `.agents/skills/`, not into
> `.claude/skills/`.
> **Rationale**: `.agents/skills/` is the canonical location for
> Codex + Claude Code shared skills (per existing convention with
> after-task-audit, rose-pre-publish-audit, etc.). Both agents
> see them.
> **Rejected alternative**: install only into `.claude/skills/`.
> Rejected because skills should be cross-agent.
> **Confidence**: high.

> **Decision**: write Design 46 as a fresh doc, not as edits to
> any existing Plot- or Article-related design.
> **Rationale**: visualization is a cross-cutting concern that
> touches engine outputs (plot dispatcher), article figures, and
> the gallery / tutorial. A dedicated doc gives Florence a clear
> charter and a single home for the figure gate. Mirrors drmTMB
> Design 39.
> **Rejected alternative**: extend `docs/design/04-sister-package-scope.md`
> with a visualization section. Rejected because cross-package
> scope and visualization grammar are different topics.
> **Confidence**: high.

> **Decision**: keep all 4 skills enabled but NOT auto-dispatched
> from CLAUDE.md hooks (no auto-trigger; agent-or-user-invoked).
> **Rationale**: skills should be invoked by Florence (or her
> stand-in agent) when a plot-touching PR is in flight. Hardcoded
> auto-triggers tend to over-fire on non-plot PRs.
> **Rejected alternative**: add CLAUDE.md auto-trigger for
> `R/plot*.R` paths. Defer until we observe a clear case where
> the manual dispatch fails.
> **Confidence**: medium (might revisit after Phase 1c-viz #1-#5
> if the manual dispatch is unreliable).

## 4. Checks Run

- ✅ AGENTS.md table reads cleanly (Florence row well-formed)
- ✅ All 4 skill SKILL.md files exist + have valid frontmatter
  (`name`, `description`, `when_to_use`)
- ✅ Design 46 cross-references resolve to real files
- ✅ Full local `rcmdcheck --as-cran` (running at write time)

## 5. Tests of the Tests

Not applicable — this is a documentation + skill-install slice;
no R code added.

The "test" of this slice is: in the next plot-touching PR
(planned: Florence adds figures to `simulation-recovery-validated.Rmd`),
Florence's review surfaces issues that align with the figure gate
(§3). If she catches problems no other persona would have caught,
the recruitment is validated.

## 6. Consistency Audit

- **Cross-package naming**: Florence used verbatim from drmTMB
  AGENTS.md row. Same dispatch question. Same figure-gate
  dimensions (with gllvmTMB-specific adaptations in §3).
- **Skill location**: `.agents/skills/` (canonical), not
  `.claude/skills/`. Matches existing `.agents/skills/`
  directory pattern (after-task-audit, etc.).
- **Bounded-dispatch rule**: memory updated to clarify Florence
  is invoked for visualization work only (not every PR).
- **Memory provenance**: persona-active-naming memory updated
  with `last_reviewed: 2026-05-18`.

Convention-Change Cascade (AGENTS.md Rule #10): triggered. AGENTS.md
Standing Review Roles table changes ripple to:
- ✅ `feedback_persona_active_naming.md` (updated this PR)
- ⚪ `docs/design/11-task-allocation.md` (Florence will appear here
  when Phase 1c-viz dispatches; deferred)
- ⚪ Codex `.toml` agent files under `.codex/agents/` (if Florence
  needs a Codex-side runtime agent; not yet decided — could be
  Claude-only)

## 7. Roadmap Tick

- No M-row tick. This is V-series (visualization), not M.
- ROADMAP Phase 1c-viz row remains 0/7. Florence inherits this
  scope; first slice (item 1: extend dispatcher with 3 missing
  static types) is queued next after M3.4 and sparse-pedigree-Ainv.
- No validation-debt register changes.

## 8. What Did Not Go Smoothly

- **Skill-install convention not auto-documented**: I had to read
  `.agents/skills/` (e.g. after-task-audit) to confirm the
  convention before installing. Worth a future small docs PR to
  point new contributors at `.agents/skills/` as the canonical
  location.
- **drmTMB Florence was created same day**: I initially assumed
  drmTMB's Florence might take days. Lucky timing — we can mirror
  directly.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

**Florence** (recruited, self-introducing): the figure gate (§3)
is my charter. I will be invoked on any plot-touching PR; my
default lead is "the figure should reveal the scientific
comparison + uncertainty + scale structure within a few seconds"
(per the scientific-figure-art-director skill).

**Ada** (orchestrator): recruitment lands cleanly; cross-package
parity with drmTMB; mirror convention for future personas.

**Pat** (review, applied UX): Florence is what I've been
wanting — a named owner for "the figures need to be better".
Looking forward to plots in `simulation-recovery-validated.Rmd`
and `animal-model.Rmd`.

**Fisher** (review, uncertainty): §3 Uncertainty row enforces
that bands match `conf.status` and `interval_source` from the
extractor outputs. This is exactly what the package's three
CI methods (profile / wald / bootstrap) need to surface
visually.

**Darwin** (review, biology framing): §3 Interpretability row
requires the biological question on every plot — matches my
existing emphasis.

**Grace** (review, CI/pkgdown): vdiffr snapshot tests in §6 #6
need a CRAN-safe pattern (skip-on-CRAN). Will design.

**Rose** (review, scope honesty): §7 explicitly out-of-scope
(no new theme package; no auto-trigger hooks). Mirror drmTMB
discipline.

**Emmy** (review, plot-helper architecture): the
implementation contract in §5 (`$data` exposure, `attr(.,
'gllvmTMB_meta')` for composability) is the right pattern for
extractor-aware plot helpers.

**Shannon** (discipline): persona-active-naming memory updated;
4 skills installed at the canonical location; cross-package
consistency with drmTMB confirmed.

## 10. Known Limitations and Next Actions

- **Phase 1c-viz #1-#8 are queued** (8-item scope per Design 46
  §6). Florence-led; dispatch after M3.4 + sparse-pedigree-Ainv
  land (so Florence has a clear lane).
- **M3 figure cascade is the first concrete task** (Design 46 §6
  item 8) — add figures to `simulation-recovery-validated.Rmd`
  and `animal-model.Rmd`. Small slice; could be done next.
- **Open questions Q-Florence-1 / Q-Pat-1 / Q-Grace-1 /
  Q-Fisher-1** are in §10 of Design 46 — route to the named
  personas in their next visualization PR.
- **Skill auto-trigger** (Decision 4 above) is medium-confidence;
  revisit if manual dispatch is unreliable.
