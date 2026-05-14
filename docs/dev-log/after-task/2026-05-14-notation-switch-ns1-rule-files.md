# After-task: Notation switch NS-1 -- rule files + decisions.md + check-log.md -- 2026-05-14

**Tag**: `docs` (rule files + dev-log; no R/, no math content
change -- only the symbol used in math prose).

**PR / branch**: this PR / `agent/notation-switch-rule-files`.

**Lane**: Claude (rule files; Codex absent assumption from
2026-05-14 still in force).

**Dispatched by**: maintainer 2026-05-14 ~07:00 MT: *"let's
go Psi!"* (in response to my workload estimate for switching
math notation from S/s to Psi/psi for the unique-variance
diagonal). Originating question: *"at the moment we use S for
a unique bit (diagonal matrix) - I am thinking of changing it
to \Psi (Greek letter) - which may be more consistent with
the literature - many small changes through the pkgdown
pages and function documentations - how much work is this?"*

**Files touched**:

- `AGENTS.md` (1 line in the math-convention paragraph).
- `CONTRIBUTING.md` (1 line).
- `CLAUDE.md` (1 line).
- `docs/dev-log/decisions.md` (1 new ~70-line entry dated
  2026-05-14 reversing the 2026-05-12 S/s entry; original
  2026-05-12 entry preserved per append-only convention).
- `docs/dev-log/check-log.md` (Kaizen points 8 and 9
  rewritten; historical entries unchanged per append-only
  convention).
- `docs/dev-log/after-task/2026-05-14-notation-switch-ns1-
  rule-files.md` (this file).

No R/ source, no R/ roxygen, no article, no NAMESPACE, no
generated Rd, no `_pkgdown.yml`, no CI config change. This
PR is the foundational establishing change for the larger
notation-switch sequence (NS-2 through NS-5).

## Math contract

The unique-variance diagonal matrix is now `\boldsymbol\Psi`
(bold Greek capital Psi) in user-facing math, replacing
`\mathbf{S}`. The per-trait derived scalar from
`extract_phylo_signal()` is now italic lowercase `\psi_t`,
replacing capital `\Psi_t`. The decomposition equations
keep their structure:

- Within-tier: `\boldsymbol\Sigma = \boldsymbol\Lambda
  \boldsymbol\Lambda^{\!\top} + \boldsymbol\Psi`.
- Paired four-component (when both $\boldsymbol\Psi$
  diagonals identifiable):
  `\boldsymbol\Sigma_{\text{phy}} =
  \boldsymbol\Lambda_{\text{phy}}
  \boldsymbol\Lambda_{\text{phy}}^{\!\top} +
  \boldsymbol\Psi_{\text{phy}}`,
  `\boldsymbol\Sigma_{\text{non}} =
  \boldsymbol\Lambda_{\text{non}}
  \boldsymbol\Lambda_{\text{non}}^{\!\top} +
  \boldsymbol\Psi_{\text{non}}`,
  `\boldsymbol\Omega = \boldsymbol\Sigma_{\text{phy}} +
  \boldsymbol\Sigma_{\text{non}}`.
- Three-piece fallback (when $\boldsymbol\Psi_{\text{phy}}$
  not separately identifiable):
  `\boldsymbol\Omega =
  \boldsymbol\Lambda_{\text{phy}}
  \boldsymbol\Lambda_{\text{phy}}^{\!\top} +
  \boldsymbol\Lambda_{\text{non}}
  \boldsymbol\Lambda_{\text{non}}^{\!\top} +
  \boldsymbol\Psi`.
- Per-trait scalar partition: $H^2_t + C^2_{\text{non},t}
  + \psi^2_t = 1$.

No change to model parameterisation, likelihood, parser, or
families. The engine algebra in `src/gllvmTMB.cpp` still
uses internal variable names with `S` or `s` (those are
private to the implementation); the change is only in
public-facing math prose.

## Checks run

- `rg -lc '\\mathbf\{S\}|\\boldsymbol\{S\}|diag\(s\)' .` to
  confirm scope coverage. Rule files + decisions.md +
  check-log.md updated; everything else queued for NS-2
  through NS-5.
- Read each edited file end-to-end to confirm no straggling
  S/s references in the math-convention sentences.

## Consistency audit

- Function- and file-name "two-U" task labels: preserved per
  `decisions.md` 2026-05-12 + 2026-05-14 entries. The
  separation is documented: function/file names = task
  labels (legacy "U"); math notation = canonical convention
  (now Psi/psi).
- Historical check-log entries (lines 669, 687, 893, 962,
  1131 in the original file) reference the 2026-05-12 S/s
  decision; those are append-only history and were not
  rewritten. The new Kaizen points 8 and 9 explicitly cite
  the 2026-05-14 reversal so future readers can resolve the
  apparent contradiction.

## Tests of the tests

No tests in this PR (rule files + dev-log only). Tests that
reference S/s in their fixtures or expected outputs (~15 test
files per the scope grep) will be updated in NS-3 alongside
the R/ roxygen sweep.

## What went well

- The decisions.md reversal entry quotes both the 2026-05-12
  original decision and the 2026-05-14 maintainer
  authorisation, making the appears-then-reverses pattern
  fully auditable from one read.
- The Ψ matrix vs ψ_t scalar disambiguation is *cleaner*
  under the new convention than under S/s (where S and Ψ_t
  were arbitrarily different symbols). The check-log Kaizen
  point 9 rewrite makes this explicit.
- Three rule files updated in one PR with minimal-diff
  edits; the foundational sentence in each ("Sigma = Lambda
  Lambda^T + diag(...)") is one-line per file.

## What did not go smoothly

- Initially considered amending the existing 2026-05-12
  decisions.md entry rather than appending a reversal entry.
  Caught it before editing -- the decisions.md is append-only
  by convention (`docs/design/10-after-task-protocol.md`
  implies durable record); rewriting history would lose the
  audit trail. Resolved: append a 2026-05-14 entry that cites
  + supersedes the 2026-05-12 one for math notation only.
- The 2026-05-14 reversal reverses a 2-day-old decision. The
  optics read instability-ish; the decisions.md entry
  explicitly addresses this by quoting the maintainer's
  literature-consistency rationale and the pre-CRAN
  reversal-cost argument.

## Team learning, per AGENTS.md role

- **Ada (maintainer)**: surfaced the literature-consistency
  concern with one well-formed question ("how much work is
  this?"). The reply-then-authorize cycle worked: a clear
  workload estimate (4-5 PRs, 1-2 days) made the decision
  cheap. Going forward, this is the right shape for any
  "should we change X across the package?" question.
- **Boole (R API)**: not engaged this PR; will engage in
  NS-3 (R/ roxygen) and NS-4/5 (article formula syntax
  consistency).
- **Gauss (TMB likelihood / numerical)**: not engaged this
  PR; will engage in NS-3 to verify the R/ roxygen rewrites
  match the unchanged C++ internal variable names.
- **Noether (math consistency)**: not engaged this PR;
  will engage in NS-3 and NS-4/5 to verify each rewritten
  equation matches the implementation. Particularly the
  three-piece fallback formula (must not roll Lambda Lambda^T
  up as Sigma_phy).
- **Darwin (biology audience)**: not engaged this PR;
  will engage in NS-4/5 to check that the notation change
  does not introduce biology-reader confusion (Ψ is more
  familiar from psychometrics / SEM than from ecology; the
  vocabulary article will need a definitional pointer).
- **Fisher (statistical inference)**: not engaged this PR;
  will engage in NS-3 to verify the `extract_phylo_signal()`
  roxygen uses italic-lowercase $\psi_t$ for the per-trait
  scalar (was capital $\Psi_t$ pre-switch) and that the
  partition equation reads $H^2_t + C^2_{\text{non},t} +
  \psi^2_t = 1$.
- **Emmy (R package architecture)**: not engaged this PR;
  will spot-check S3 method consistency in NS-3 (extractor
  print methods may include the old S notation in default
  outputs).
- **Pat (applied PhD user)**: not engaged this PR; will
  engage in NS-4/5 to check that articles still read
  navigably for a new applied user -- specifically that the
  `gllvm-vocabulary` article (when written in Phase 1c)
  defines `\boldsymbol\Psi` plainly.
- **Jason (literature / scout)**: pre-engaged via the
  literature-consistency argument (Bollen 1989, Mulaik 2010,
  lavaan, Anderson 2003 -- Psi is the factor-analysis
  standard). The 2026-05-14 decisions.md entry cites these.
- **Curie (simulation / testing)**: not engaged this PR;
  will engage in NS-3 to update test-fixture comments and
  recovery-test expected outputs that reference S/s in
  string form.
- **Grace (CI / pkgdown / CRAN)**: not engaged this PR;
  will engage in NS-3 and NS-5 to verify `pkgdown::check_pkgdown()`
  passes after each sweep and that the rendered articles
  display Psi cleanly.
- **Rose (systems audit)**: standing pre-publish audit for
  every NS PR. This PR's audit: the three rule-file edits
  + decisions.md entry + check-log Kaizen rewrite are
  internally consistent and don't contradict the function-
  name task-label preservation.
- **Shannon (cross-team coordination)**: with Codex absent,
  Shannon's audit role narrows to "is the dev-log + rule
  files internally consistent post-PR?" Particularly: do the
  rule files, decisions.md, and check-log all agree on the
  new convention? Answer: yes.

## Design-doc + pkgdown updates

None in this PR. Design docs (00-vision, 03-phylogenetic-
gllvm, 04-sister-package-scope) are in NS-2's scope. pkgdown
rebuild deferred to NS-5 (after all sweeps).

## Known limitations and next actions

**Known limitations**:

- Articles, R/ roxygen, README, design docs, and NEWS still
  use S/s. Will be updated in NS-2 through NS-5; reads
  inconsistent in the interim. Justification: foundational
  change (this PR) is small + reviewable; the larger sweeps
  cite this PR's decisions.md entry for canonical authority.
- Article `functional-biogeography.Rmd` was JUST converted
  from $\boldsymbol\Psi$ to $\boldsymbol{S}$ in PR #82
  (Batch C, 2026-05-13). NS-5 will reverse that conversion
  back to $\boldsymbol\Psi$. Net effect on the file: it
  bounces. Justification: the 2026-05-13 conversion
  followed the then-canon S/s; the 2026-05-14 reversal
  follows the new-canon Psi/psi. Both were correct under
  their canon at the time.

**Next actions**:

1. NS-2: README + design docs (00-vision.md, 03-phylogenetic-
   gllvm.md, 04-sister-package-scope.md).
2. NS-3: R/ roxygen sweep across 7 files + `devtools::document()`
   to regenerate `man/*.Rd`. Persona reviews: Gauss + Noether
   + Fisher + Rose.
3. NS-4: articles part 1 (Concepts + lighter Worked examples).
4. NS-5: articles part 2 (heavier Worked examples) +
   `NEWS.md` entry explaining the reversal + final pkgdown
   sanity check.
5. After NS-1 through NS-5 merged: start Phase 1a Batch A
   under the new convention.
