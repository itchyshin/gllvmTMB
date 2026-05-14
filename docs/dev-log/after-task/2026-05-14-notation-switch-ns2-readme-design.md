# After-task: Notation switch NS-2 -- README + design docs -- 2026-05-14

**Tag**: `docs` (README + design docs; math prose only, no
math content change).

**PR / branch**: this PR / `agent/notation-switch-readme-design-docs`.

**Lane**: Claude (Codex absent).

**Dispatched by**: maintainer 2026-05-14 "let's go Psi!"
(see NS-1 after-task for the originating chain). NS-2 is the
second PR in the 5-PR notation-switch sequence; cites the new
convention codified in NS-1's `decisions.md` 2026-05-14 entry.

**Files touched**:

- `README.md` -- 3 math-prose hits (lines 75, 200, 221 in the
  pre-edit file). Line 113 (`S_B = c(0.2, 0.3, 0.2)` -- an R
  code chunk passing arguments to `simulate_site_trait()`) is
  **NOT** edited; the argument-name rename question is
  deferred to NS-3. See Known Limitations below.
- `docs/design/00-vision.md` -- 1 line in the canonical
  decomposition statement.
- `docs/design/03-phylogenetic-gllvm.md` -- the paired
  decomposition block + an explanatory paragraph; also added
  the three-piece fallback formulation since the design doc
  didn't yet codify the maintainer's 2026-05-13 correction.
- `docs/design/04-sister-package-scope.md` -- 1 line in the
  `gllvmTMB` row of the package-comparison table.
- This after-task file (new).

## Math contract

Continues NS-1's convention: `\boldsymbol\Psi` (bold capital)
for the unique-variance diagonal matrix; `\psi_t` (italic
lowercase) for the per-trait derived scalar from
`extract_phylo_signal()`. Same equations as NS-1:

- Within-tier: `Sigma = Lambda Lambda^T + diag(psi)`.
- Paired four-component:
  `Sigma_phy = Lambda_phy Lambda_phy^T + Psi_phy`,
  `Sigma_non = Lambda_non Lambda_non^T + Psi_non`,
  `Omega = Sigma_phy + Sigma_non`.
- Three-piece fallback:
  `Omega = Lambda_phy Lambda_phy^T + Lambda_non Lambda_non^T + Psi`
  (single non-tier-specific diagonal).

No engine / parser / likelihood / family change.

## Checks run

- `rg -n "diag\(s\)|S_phy|S_non|S_B|S_W" README.md docs/design/`
  before edits to confirm scope; re-ran after edits to verify
  only the argument-name references (line 113 + similar) remain.
- Read each edited section end-to-end to confirm the new
  notation is internally consistent.

## Consistency audit

- README line 113 (`S_B = c(0.2, 0.3, 0.2)`) is preserved
  because it is an R function call passing parameters to
  `simulate_site_trait()`. The argument name `S_B` is part of
  the public R API. Math prose around it (lines 75, 200, 221)
  now uses Psi; the code chunk uses S_B until the API rename
  decision is made in NS-3.
- `docs/design/03-phylogenetic-gllvm.md` had a sentence saying
  "public math uses S/s". Updated to "public math uses
  `\boldsymbol\Psi` / `\psi_t`" with reference to the
  2026-05-14 decisions.md entry. The "two-U" task-label rule
  is preserved.
- `docs/design/03-phylogenetic-gllvm.md` also now codifies the
  three-piece fallback (was not in the design doc; the
  maintainer's 2026-05-13 correction had landed only in
  `pitfalls.Rmd` section 5 + `check-log.md` Kaizen point 8).
  This brings the design doc in line with the article-level
  pedagogy.

## Tests of the tests

No tests in this PR. NS-3 (R/ roxygen + Rd regen) will update
test fixtures that reference S/s in strings.

## What went well

- Tight scope per PR keeps the diff reviewable. README touched
  3 lines + 1 sentence-extension; design docs touched 1-2 lines
  each except 03-phylogenetic-gllvm.md which gained the
  three-piece fallback paragraph (substantive but
  contained).
- The 03-phylogenetic-gllvm.md design doc was out of date
  relative to the post-2026-05-13 understanding of paired-vs-
  three-piece; NS-2 fixes that incidentally while doing the
  notation switch. The design doc now matches the in-flight
  article (`pitfalls.Rmd` section 5) + Kaizen point 8.
- README's "Tiny example" (rewritten in PR #80) doesn't need
  re-touching here -- the wide-form `traits(...)` block uses
  no math notation, and the long-form block's `diag(s)` is
  now `diag(psi)` (line 200 / 221).

## What did not go smoothly

- **API parameter name question** (`S_B` / `S_W` / `S_phy` /
  `S_non` in `simulate_site_trait()` and related user-facing
  functions). NS-2 punts on this because changing argument
  names is a breaking R API change, which belongs in NS-3
  (R/ source). But the deferral creates a temporary
  inconsistency in README between math prose ("Psi") and code
  chunk ("S_B"). See Known Limitations.

## Team learning, per AGENTS.md role

- **Boole (R API)**: 🔴 needs to weigh in on the argument-name
  decision in NS-3. Rename or keep? Pre-CRAN no-external-users
  argument cuts both ways: clean now is cheap, but every
  function-arg rename ripples through tests + articles +
  user-code-in-flight (if any pilot users exist).
- **Gauss (TMB likelihood / numerical)**: NS-2 has no
  TMB-side touch; standing brief unchanged.
- **Noether (math consistency)**: 03-phylogenetic-gllvm.md
  now matches the three-piece fallback in pitfalls.Rmd and
  check-log point 8. The three sources are aligned for the
  first time.
- **Darwin (biology audience)**: 🔴 Should `gllvm-vocabulary`
  article (Phase 1c, Pat-pedagogy article) introduce Psi to
  ecology readers who may know it only from psychometrics?
  Standing brief for Phase 1c.
- **Fisher**: NS-2 doesn't touch profile-CI material.
  Standing brief for NS-3 + 1b.
- **Pat (applied user)**: README's Tiny example reads cleanly
  with the math prose now Psi while the code chunk argument
  is still S_B. If the argument is renamed to Psi_B in NS-3,
  README's line 113 gets a follow-up update.
- **Rose (systems audit)**: pre-publish audit confirms the
  edits are internally consistent. Cross-doc consistency:
  AGENTS.md / CONTRIBUTING.md / CLAUDE.md / decisions.md
  (from NS-1) all agree with README / design docs (from NS-2)
  on the Psi convention. Articles + R/ roxygen are still on
  the old convention but that's expected (NS-3 / NS-4 / NS-5
  are still to come).
- **Shannon (cross-team)**: Codex still absent. The
  notation-switch sequence is Claude-only.

## Known limitations + next actions

**Known limitations**:

- **R API argument names (`S_B`, `S_W`, `S_phy`, `S_non`)**
  remain unchanged. README line 113 still shows
  `S_B = c(...)`. After the rename decision in NS-3 lands,
  README needs a follow-up update if argument names change.
  **This is a 🔴 maintainer decision point for NS-3.**

- Articles (11 files), R/ roxygen (7 files), tests (~15
  files), NEWS.md are still on S/s. NS-3 / NS-4 / NS-5 will
  bring those in line.

**Next actions**:

1. NS-3: R/ roxygen sweep + `devtools::document()` to
   regenerate `man/*.Rd`. **Includes the API argument-rename
   decision** -- either rename `S_B` -> `Psi_B` (clean,
   breaking; pre-CRAN OK) or keep `S_B` (back-compat; math
   prose says Psi but R arg says S).
2. NS-4: articles part 1 (Concepts + lighter Worked
   examples).
3. NS-5: articles part 2 (heavier Worked examples) +
   `NEWS.md` entry + final pkgdown sanity check.
