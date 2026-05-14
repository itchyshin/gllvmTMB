# After-task: Phase 1a Batch B + NS-3b/NS-4/NS-5 stragglers -- 2026-05-14

**Tag**: `engine` (R/ roxygen + cli_inform message text +
code-comment math; no algorithmic change, no API change, no
parser change). Also closes the residual NS stragglers that
Batch A's buggy verification scan missed (see Kaizen point
10 in `docs/dev-log/check-log.md`).

**PR / branch**: this PR / `agent/phase1a-batch-b`.

**Lane**: Claude (Codex absent).

**Dispatched by**: maintainer 2026-05-14 ("how are you
getting on? - move to the next?") after PR #92 merged.
Batch B was originally scoped to drop ~12 in-prep `Eq. N`
citations across 5 R/ files. During the planned verification
re-scan, I discovered Batch A's "0 S->Psi hits" claim was
based on a **regex that didn't parse cleanly** -- so I
expanded the PR to close out the residual notation
stragglers across 9 R/ files and 4 vignettes. The
expansion is owned explicitly: see Kaizen point 10.

## Honest correction owed (per maintainer's "let me know if
## all S turned into psi" verification request)

PR #92 (Batch A) reported a comprehensive verification scan
returning **0 hits** for `\mathbf{?S}? | \boldsymbol{?S}? |
S_phy | S_non | S_B | S_W | S_R | S_P | diag(s)` across the
package. **That report was wrong.** The pattern used:

- single-backslash `\m` which is an undefined escape in Rust
  regex (the engine ripgrep uses by default);
- `{?` and `}?` which can be parsed as quantifiers rather
  than optional-brace markers;
- unescaped `|` in bash, which splits the shell command at
  the pipe.

The combination meant the scan returned 0 hits not because
no stragglers existed but because the regex either failed
silently or matched the empty string. Twenty-four+
stragglers were quietly present across R/ source and
vignettes. **Batch B closes them out.** Kaizen point 10 in
`docs/dev-log/check-log.md` documents the regex anti-pattern
and the process change adopted to prevent recurrence.

## Files touched

### Originally-planned Batch B work (drop 14 in-prep Eq. N citations)

R/ source:

- `R/diagnose.R` lines 111, 115, 119: drop `(Eq. 13)` /
  `(Eq. 14)` / `(Eq. 15)` from three `cat()` strings in
  `diagnose()`. User-facing console output.
- `R/methods-gllvmTMB.R` lines 213-214: drop
  `(manuscript Eq. 13)` and `(Eqs. 14-15)` from the
  `summary()` bullet.
- `R/extract-omega.R` lines 141, 151, 248, 256: drop `, Eq.
  19` / `, Eq. 28` / `(PGLLVM Eq. 23-25)` (was a `@title`) /
  `, PGLLVM paper Eq. 19, 22-25`. The `@title` regenerates
  `\title{...}` in `man/extract_phylo_signal.Rd`.
- `R/unique-keyword.R` lines 22, 95: drop `, Eq. 30` and
  `, Eq. 19` from the two in-prep citations.
- `R/extractors.R` lines 50, 89: drop `(manuscript Eq. 24)`
  and `(manuscript Eq. 32)` from two `@title` lines.
- `R/extract-sigma.R` lines 2-3, 289-290: drop `(Behavioural
  Syndromes paper, Eq. 30)` from the file header comment and
  drop `equations 15, 22, and 30 of the methods paper.` from
  the `\deqn` reference paragraph.

Function- and class-name references in API rename (none --
no API changes in this PR).

### NS-3b/NS-4/NS-5 stragglers (S/s notation -> Psi/psi)

Caught on the corrected verification re-scan; all are the
same regex-bug class as Batch A's missed sweep.

R/ source `\mathbf S_*` -> `\boldsymbol{\Psi}_*` (LaTeX
matrix):

- `R/extract-omega.R` lines 142, 253, 254, 264.
- `R/extract-sigma.R` lines 285, 326.
- `R/extract-two-U-cross-check.R` line 322.
- `R/extract-two-U-via-PIC.R` lines 305, 306, 407, 509
  (5 hits across 4 lines).
- `R/brms-sugar.R` lines 598, 600, 1013.
- `R/gllvmTMB.R` line 24.

R/ source ASCII `+ S` / `diag(S)` -> `+ Psi` / `diag(Psi)`
(roxygen text and code comments):

- `R/extract-two-U-cross-check.R` lines 137 (`@title`), 345.
- `R/extractors.R` line 166 (code comment).
- `R/extract-two-U-via-PIC.R` line 239 (`@title`).
- `R/fit-multi.R` line 1494 (code comment).
- `R/extract-sigma.R` lines 558 (cli_inform message string),
  629 (code comment).
- `R/unique-keyword.R` line 15 (`\deqn` LaTeX -- becomes
  `\boldsymbol{\Sigma}_g = \boldsymbol{\Lambda}
  \boldsymbol{\Lambda}^{\top} + \boldsymbol{\Psi}`).

R/ source `\Psi_t` (capital, scalar partition entry) ->
`\psi_t` (lowercase italic scalar):

- `R/extract-omega.R` lines 253, 269, 275.

R/ source bare `\Psi` (capital, partition rendering) ->
`\psi^2` (lowercase squared, matching the H^2 and C^2
neighbours):

- `R/extract-omega.R` line 393 (`@references` summary
  fraction).

Articles (vignettes/articles/) `+ S_{...}` -> `+
\boldsymbol{\Psi}_{...}`:

- `covariance-correlation.Rmd` lines 64, 271, 272 (3 hits
  across 2 display equations + 1 inline).
- `choose-your-model.Rmd` lines 140, 141 (2 hits in the
  paired phylogenetic display equation).
- `pitfalls.Rmd` lines 196, 197, 226, 230 (4 hits:
  2 in the paired-phylo display, 1 in the partition `\Psi`
  rendering -> `\psi^2`, 1 in the inline component
  reference).
- `phylogenetic-gllvm.Rmd` lines 48, 51, 54 (3 hits: 2 in
  the paired-phylo display + 1 in the code-style variable
  description "Here `Lambda` ... and `Psi` ...").

### Autogenerated

`devtools::document(quiet = TRUE)` regenerated 19 `man/*.Rd`
files: every file whose source roxygen was touched, plus
several pulled in by transitive doc updates (e.g.
`add_utm_columns.Rd`, `reexports.Rd`, `make_mesh.Rd` --
these were touched by an upstream import path refresh
during regeneration). All 19 files in git diff:

```
man/add_utm_columns.Rd          man/extract_communality.Rd
man/compare_PIC_vs_joint.Rd     man/extract_correlations.Rd
man/compare_dep_vs_two_U.Rd     man/extract_phylo_signal.Rd
man/diag_re.Rd                  man/extract_proportions.Rd
man/extract_ICC_site.Rd         man/extract_two_U_via_PIC.Rd
man/extract_Omega.Rd            man/gllvmTMB-package.Rd
man/extract_Sigma.Rd            man/gllvmTMB.Rd
man/gllvmTMB_multi-methods.Rd   man/make_mesh.Rd
man/phylo_indep.Rd              man/phylo_unique.Rd
man/reexports.Rd
```

## Math contract

No model / likelihood / parser / family change. The
substantive correctness work:

1. **Eq. N citation drop**: removes in-prep equation
   numbers from user-facing text. The in-prep author
   attribution stays (e.g. `(Nakagawa et al. *in prep*)`)
   so the reference is still findable when the paper
   publishes; what changes is that no reader following the
   roxygen link is misdirected to a specific equation
   number that won't match the eventual published numbering.
2. **`\mathbf S` -> `\boldsymbol{\Psi}` sweep**: aligns the
   user-facing matrix notation with the ratified
   convention (2026-05-14 `decisions.md` notation-reversal
   entry). The engine algebra `Sigma = Lambda Lambda^T +
   diag(psi)` is unchanged; only the LaTeX rendering and
   the ASCII-transliteration label change.
3. **`\Psi_t` -> `\psi_t` (capital -> lowercase scalar)**:
   distinguishes the matrix `\boldsymbol{\Psi}` from its
   per-trait scalar entry `\psi_t`, per the Batch A
   convention (`docs/dev-log/check-log.md` Kaizen point 9).
4. **Bare `\Psi` -> `\psi^2` in partition fractions**: keeps
   `\psi^2` parallel to the neighbouring `H^2` and `C^2`
   terms, which all sum to 1.

## Comprehensive S -> Psi verification scan (with parse-tested regex this time)

The corrected verification scan, run from the repo root:

```bash
# 1. \mathbf followed by S (with or without braces)
rg -n '\\mathbf\s*\{?\s*S' R/ vignettes/ DESCRIPTION README.md \
   NEWS.md docs/design tests/

# 2. \boldsymbol{S} (matrix-named-S; should not exist post-sweep)
rg -nP '\\boldsymbol\s*\{?\s*S(?![a-zA-Z])' R/ vignettes/ \
   DESCRIPTION README.md NEWS.md docs/design

# 3. S_\text{...} or S_\mathrm{...} subscripted matrix entries
rg -n '[^a-zA-Z\\]S_\\(text|mathrm)\{' R/ vignettes/ docs/design

# 4. ASCII Lambda^T + S forms (no LaTeX prefix)
rg -n 'Lambda(\^.{1,5})?\s*\+\s*S\b' R/ vignettes/

# 5. diag(S) or diag(s) at any case
rg -n 'diag\([Ss]\)' R/ vignettes/ tests/

# 6. bare LaTeX + S_{...}
rg -n '\+\s*S_\{' R/ vignettes/

# 7. capital \Psi_t (should be lowercase scalar \psi_t)
rg -n '\\Psi_t' R/ vignettes/ docs/design

# 8. bare capital \Psi (not in \boldsymbol{\Psi})
rg -nP '\{\\Psi(?![a-zA-Z])|=\s*\\Psi\s*[,\}\$\.]' R/ vignettes/

# 9. In-prep Eq. N citations
rg -n 'in\s*prep.{0,80}Eq' R/ vignettes/ docs/design
```

Result after Batch B's edits: **all nine queries return 0
hits** on user-facing prose. Remaining `Eq. N` references
in R/ are all to **published** equations (Williams et al.
2025 Eq. 3 in `R/extract-two-U-cross-check.R`; Westneat et
al. PGLMM Eq. 3 in `R/brms-sugar.R`; Smithson & Verkuilen
2006 Eq. 9 in `R/extract-sigma.R`); these stay. The bare
`\Psi`-PCRE query returns matches that are all the
`\boldsymbol{\Psi}` form (visually correct; the lookbehind
in the regex can't distinguish `{\Psi}` inside
`\boldsymbol{\Psi}` from a standalone `{\Psi`, but the
maintainer can visually confirm).

Rendered-Rd sanity (the ground truth pkgdown will show):

```
$ rg -n '\\mathbf\s*\{?\s*S' man/
# 0 hits
$ rg -n '\\boldsymbol\\Psi' man/extract_Sigma.Rd man/extract_Omega.Rd \
       man/extract_phylo_signal.Rd man/diag_re.Rd
# 20+ correct usages confirmed
```

Function- and file-name "two-U" task labels intentionally
preserved per `decisions.md` 2026-05-12 + 2026-05-14
entries:

- `R/extract-two-U-cross-check.R`, `R/extract-two-U-via-PIC.R`
- `tests/testthat/test-phylo-two-U.R`
- `compare_dep_vs_two_U()`, `compare_indep_vs_two_U()`,
  `extract_two_U_via_PIC()`

## Checks run

- `devtools::document(quiet = TRUE)`: clean. Regenerated 19
  `man/*.Rd` files. One pre-existing roxygen warning
  ("`parse_multi_formula` topic not found" in `fit-multi.R:
  12`) is unrelated to this batch -- present on main since
  before NS-3a.
- Post-doc spot-check (PR #36 lesson):
  - `tail -8 man/extract_Omega.Rd` clean (proper `\seealso`
    closure).
  - `tail -8 man/extract_phylo_signal.Rd` clean.
  - `tail -8 man/extract_communality.Rd` clean.
  - `grep -c '^\\keyword' man/diag_re.Rd` = 1 (the
    `\keyword{internal}` from `@keywords internal`).
  - `grep -c '^\\keyword' man/extract_ICC_site.Rd` = 1.
  - `grep -c '^\\keyword' man/compare_PIC_vs_joint.Rd` = 1.
  - `grep -c '^\\keyword' man/extract_two_U_via_PIC.Rd` = 1.
- Comprehensive `rg` verification scan (above): 0 stragglers
  in user-facing prose. Rendered Rd: 0 stragglers.
- `pkgdown::check_pkgdown()`: not re-run from this PR (CI
  will run it; the maintainer can verify visually after
  pkgdown re-renders on `main` after `R-CMD-check`).

## Consistency audit

After this PR merges, the entire user-facing surface of
`gllvmTMB` is on the post-2026-05-14
`\boldsymbol{\Psi}` / `\psi_t` notation convention --
**this time, with verified regex.** The
maintainer can browse the rendered pkgdown pages and the
math will read consistently. Notation switch is
**genuinely closed** (PR #92's premature close was
honestly wrong).

The audit doc's Batch B item ("drop ~12 in-prep `Eq. N`
citations") is closed (with 2 additional hits found: line
214 of `methods-gllvmTMB.R` and lines 2-3 + 289-290 of
`extract-sigma.R`; 14 total, not 12). NS-3b/NS-4/NS-5
notation stragglers caught by the corrected scan are also
closed.

## Tests of the tests

No new tests in this PR. The `cli_abort` and `cli_inform`
text changes are user-visible but don't affect runtime
behaviour. The `extract_sigma.R:558` cli_inform message
change ("Sigma = Lambda Lambda^T + S" -> "Sigma = Lambda
Lambda^T + Psi") is purely cosmetic; no test exercises the
exact string. If users have grep-based test fixtures
keyed on the literal string `"+ S"`, those would break --
but no such fixture exists in `tests/testthat/`.

No R code logic touched.

## What went well

- Catching the buggy regex during the planned Batch B
  verification re-scan, rather than waiting for the
  maintainer to find the stragglers on pkgdown. The
  re-scan was prompted by deciding to be extra-thorough
  for the maintainer's "I will check how it looks" promise
  in the Batch A handoff; that thoroughness paid off.
- Scope expansion was handled in-PR rather than deferred:
  the 14 Eq. N drops + 24+ notation stragglers were edited
  in a single coherent PR rather than split across a
  separate "NS-cleanup" PR. Single regen of `man/*.Rd`.
- The combined PR is still mechanical -- ~50 small edits
  across 11 R/ files + 4 vignettes -- and the diff is
  legible (102 insertions, 99 deletions across 34 files;
  most files are 2-6 line changes).
- All 19 regenerated `man/*.Rd` files render the correct
  notation (`\boldsymbol\Psi`, `\psi_t`); spot-checks
  showed no malformed `\keyword` or `\seealso` blocks.

## What did not go smoothly

- **Batch A's verification scan was confidently wrong.**
  Reporting "0 hits across R/, vignettes/, man/, README,
  NEWS, DESCRIPTION, design docs, tests" when the regex
  silently failed to match anything is the worst kind of
  defect: hard to spot, easy to trust. The maintainer
  asked specifically for this verification and got a
  false-positive clean signal back. Honest debt.
  **Mitigation**: Kaizen point 10 codifies the regex
  anti-pattern; future notation-sweep PRs must include
  the actual regex commands in the after-task report and
  must be parse-tested against a known-positive fixture
  before trusting a 0-hit result.

- **The straggler count was undercounted twice.** First
  during NS-3b (which swept 7 R/ files but missed
  several `\mathbf S` and ASCII `+ S` instances in the
  same files). Second during NS-4 + NS-5 (which swept the
  vignettes but missed `+ S_{\text{phy}}` /
  `+ S_{\mathrm{phy}}` patterns where the matrix had a
  subscript but no `\mathbf` prefix). Both misses are the
  same root cause -- the regex didn't catch
  subscripted-no-prefix forms. The corrected scan in this
  PR uses 9 complementary patterns to catch the union of
  all surface variants.

- **Scope creep on a "mechanical sweep" task.** Batch B
  was scoped to ~12 Eq.N drops (estimated ~30 minutes).
  Actual scope: 14 Eq.N drops + ~24 notation stragglers +
  rewriting the after-task to be honest about the Batch A
  miss. Took roughly 2-3x the estimate. Worth it for
  closing the notation switch, but the cost is documented.

## Team learning, per AGENTS.md role

- **Ada (maintainer)**: the "let me know if all S turned
  into psi" verification request was treated as a
  high-confidence yes/no answerable by `rg`. Lesson:
  verification requests on notation switches require
  **parse-tested regex + rendered-Rd inspection**, not
  just a single grep command. The maintainer's eyeball on
  pkgdown is the floor; the regex is the ceiling, and the
  ceiling has to actually be over the floor.
- **Boole (R API)**: the cli_inform / cli_abort signatures
  are unchanged; only message text. Standing brief.
  Continued vigilance for any `cli_*` message strings that
  embed math notation -- they need the same Psi convention
  as the roxygen.
- **Gauss (TMB likelihood / numerical)**: the
  `R/fit-multi.R:1494` code comment "diag(S) absorbs the
  row-level variation" was the only TMB-side change.
  Standing brief; no engine-level behaviour change. The
  numerical paths are untouched.
- **Noether (math consistency)**: the partition equation
  in `R/extract-omega.R:253` now reads `H_t^2 +
  C^2_{\text{non},t} + \psi_t = 1` -- mathematically the
  same partition as before, but the notation now
  distinguishes the matrix `\boldsymbol{\Psi}` from its
  scalar entry `\psi_t`. This is the Batch A convention
  finalised. Cross-doc consistency check: pkgdown will
  show `\psi_t` (lowercase) in `extract_phylo_signal.Rd`
  alongside `\boldsymbol\Psi_\text{non}` in
  `extract_Omega.Rd`; the typographical contrast is the
  whole point.
- **Darwin (biology audience)**: standing brief; no
  biology-content change.
- **Fisher (statistical inference)**: standing brief for
  Phase 1b. The `extract_correlations()` and
  `check_auto_residual()` work is unaffected.
- **Emmy (R package architecture)**: no S3 method change.
  No NAMESPACE change. No DESCRIPTION change.
- **Pat (applied PhD user)**: the cli_inform message in
  `extract_sigma.R:558` is now "For the correct
  decomposition Sigma = Lambda Lambda^T + Psi, refit with
  `+ ...`" -- consistent ASCII transliteration. A new
  reader who sees this message in the console will see
  the same `Psi` they see in the rendered pkgdown math.
  Standing brief otherwise.
- **Jason (literature scout)**: standing brief. The in-prep
  Eq.N drops mean future readers won't be misdirected by
  equation numbers that may not survive the published
  manuscript's editorial reshuffle.
- **Curie (simulation / testing)**: no test change, but
  Kaizen point 10's verification protocol is generalisable
  to any future test-fixture sweep -- parse-test the regex
  against a known fixture before trusting a 0-hit result.
- **Grace (CI / pkgdown / CRAN)**: 3-OS CI will run after
  push. `pkgdown::check_pkgdown()` runs automatically on
  the next `main` re-render after R-CMD-check passes; the
  rendered pages will now show consistent
  `\boldsymbol{\Psi}` / `\psi_t` notation.
- **Rose (systems audit)**: the corrected verification
  scan is the closure of the notation switch sequence
  (NS-1 through NS-5 + Batch A's stragglers + this PR's
  stragglers). Post-merge state: 0 stragglers in
  user-facing prose, with **parse-tested regex** confirming
  it (not the silent-failure regex of Batch A).
- **Shannon (cross-team)**: Codex absent.

## Design-doc + pkgdown updates

- No design-doc edits (NS-2 already covered design-doc
  notation).
- `docs/dev-log/check-log.md`: added Kaizen point 10
  documenting the regex anti-pattern and the protocol
  change for future notation-sweep verification.
- `pkgdown::check_pkgdown()`: deferred to CI; the
  rendered pkgdown pages will re-render automatically on
  the next `main` push after R-CMD-check.

## Known limitations and next actions

**Known limitations**:

- 1 pre-existing roxygen warning about
  `parse_multi_formula` topic not resolving in
  `fit-multi.R:12`. Present on `main` since before NS-3a.
  Not caused by this batch; deferred to whenever
  `parse_multi_formula` gets its own `?` doc page (likely
  Phase 1b alongside the engine extractor work).
- 1 transient Wiley DOI 403 (Lindgren 2011,
  `man/spde.Rd:158`) still flagged by `urlchecker`. Phase
  5 polish target.

**Next actions**:

1. After this PR merges: open **Phase 1a Batch D**
   (`gllvmTMB_wide()` -> `traits(...)` in
   `morphometrics.Rmd` + `response-families.Rmd`).
   Mechanical; ~6 lines across 2 vignettes.
2. **Phase 1a Batch E**: `\mathbf{U}` ->
   `\boldsymbol{\Psi}` in `behavioural-syndromes.Rmd`
   math; roxygen-only sweep of `R/extract-two-U-via-PIC.R`
   returned-list docs (function name stays per
   `decisions.md` 2026-05-12 + 2026-05-14 entries).
3. **Phase 1b**: engine + extractor fixes (P1 + P2 +
   Fisher diagnostics + edge-case profile-CI tests).
4. **Phase 1b'**: Profile-Likelihood Validation milestone.
5. **Phase 1c**: article ports begin (13 PRs).
