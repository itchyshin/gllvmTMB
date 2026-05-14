# Decisions log

Date-stamped one-paragraph design decisions. Append-only.

## 2026-05-10  Bootstrap fresh repo from gllvmTMB-native subset

Decision: rebuild gllvmTMB from a clean GitHub repository
(`itchyshin/gllvmTMB`, initial commit `ca4e927`) rather than continuing
to ship the legacy package's 133 exports (65 gllvmTMB-native +
68 sdmTMB-inherited). Rationale: the legacy NAMESPACE breaks the
"standalone" promise and the 28-min R CMD check is too slow for the
3-OS CI matrix the maintainer is committing to. Modelled the team
discipline (Codex agents, project-local skills, design docs,
after-task reports, decisions log) on the drmTMB sister package.

## 2026-05-10  Title: "Stacked-Trait GLLVMs with TMB"

Decision: 30-character Title satisfying CRAN's <= 65-char limit. The
candidate `Multivariate Latent-Variable Models for Trait Data` was
also acceptable (51 chars) but loses the "stacked" specificity and
adds the noun "Models" twice (once via "Latent-Variable Models" and
once implicitly).

## 2026-05-10  Vendor mesh; do not Imports: sdmTMB

Decision: keep `R/mesh.R`, `R/crs.R`, and the anisotropy plotting
helpers in `R/plot.R` as gllvmTMB-internal copies of the
sdmTMB-derived code, with provenance recorded in `inst/COPYRIGHTS`
and DESCRIPTION's `Authors@R` crediting Sean Anderson, Eric Ward,
Philina English, and Lewis Barnett (the sdmTMB founding authors).
Rationale: the `Imports: sdmTMB` route would have been the simpler
dependency model but adds a heavy runtime dep with its own
toolchain-validation surface (Windows TMB build, Apple Clang
warnings); vendoring keeps the closed dependency surface
constant. Revisit in 0.3.x if the maintainer chooses to slim
further.

## 2026-05-10  cph trim: 5 entries (was 21)

Decision: trim DESCRIPTION's Authors@R cph list to (Nakagawa,
Anderson, Ward, English, Barnett, Kristensen). The legacy 21-cph
list over-credited glmmTMB / VAST / brms / mgcv code paths that we
cut along with `R/fit.R`, `R/smoothers.R`, `R/visreg.R`, and
`R/emmeans.R`. The remaining cph entries match the upstream code
that still ships in `R/mesh.R`, `R/crs.R`, `R/plot.R`'s
`plot_anisotropy*`, and the TMB engine.

## 2026-05-10  Engine moved from inst/tmb/ to src/

Decision: rename and move the multivariate TMB template from
`inst/tmb/gllvmTMB_multi.cpp` (runtime-compiled via `TMB::compile()`,
cached in user_dir) to `src/gllvmTMB.cpp` (compiled at install
time via `LinkingTo: TMB, RcppEigen`). Rationale: the legacy
package's runtime-compile pattern existed to coexist with a static
single-response engine in the same `.so` (TMB does not support two
templates per shared library). With the single-response engine cut,
this constraint disappears and the standard install-time path
matches drmTMB's structure.

The `TMB_LIB_INIT` token was renamed from `R_init_gllvmTMB_multi` to
`R_init_gllvmTMB`, and the `MakeADFun` `DLL =` argument in
`R/fit-multi.R` was updated to `"gllvmTMB"`. `R/multi-template.R`
(the cache machinery) was removed; `useDynLib(gllvmTMB,
.registration = TRUE)` is added via the package-level roxygen block
in `R/zzz.R`.

## 2026-05-11  Sequence pkgdown after green R-CMD-check

Decision: change `.github/workflows/pkgdown.yaml` from an independent
push workflow to a `workflow_run` workflow that starts only after a
successful `R-CMD-check` on `main` / `master`, with manual dispatch
retained. Rationale: match the drmTMB feedback discipline before
optimising runtime. `gllvmTMB` still keeps the full 3-OS
`R-CMD-check` on PRs and `main`; this decision does not add slow-test
gating or a fast lane.

## 2026-05-11  Use one narrow Rose pre-publish gate

Decision: add a project-local `rose-pre-publish-audit` skill and
document it in `AGENTS.md` and `CONTRIBUTING.md`. Rationale: the team
needed a concrete consistency gate for public prose and reference
navigation, not a larger static role system. The gate checks method
lists, defaults, exported function names, the 3 x 5 keyword grid,
argument names, family lists, and stale terminology for README,
vignettes, pkgdown, NEWS, exported roxygen, and generated Rd changes.

## 2026-05-11  User-facing examples pair long + wide

Decision: when demonstrating how to fit a `gllvmTMB` model in
user-facing prose -- README, vignettes, and Tier-1 articles -- show
both the long-format and the wide-format call side by side. Long
is canonical (`gllvmTMB(value ~ ..., data = df_long)`); wide is the
convenience entry (`gllvmTMB_wide(Y, ...)` or
`gllvmTMB(traits(...) ~ ..., data = df_wide)`). Rationale: readers
vary in mental model -- some think of the data as a matrix
(rows = sites, columns = traits), some as a long tibble (one row
per `(unit, trait)` observation). A single example that shows
both reaches both reader types without forcing a translation step.
Roxygen `@examples` blocks for individual keyword or extractor
functions may stay single-form when the keyword is intrinsically
one shape (for instance, `traits()` is wide-only by construction).
The rule is recorded in `AGENTS.md` "Writing Style".

Locks out: canonical Tier-1 article examples that show only one
form without explanation. Applies to every new article, every
README snippet, and every README-driven smoke test going forward.
The first application is the Priority 2 article-rewrite PR;
Priority 3 (weights unification) will extend the pattern with
matrix-weights examples.

## 2026-05-11  Use discussion checkpoints for multi-agent work

Decision: Codex and Claude Code may work in parallel for bounded
read-only audits, reviews, and non-overlapping implementation tasks,
but the maintainer discussion checkpoint is the default before
deletions, API changes, formula-grammar changes, likelihood changes,
new families, or broad article rewrites. Rationale: the project gets
better evidence from parallel agents, but the roadmap should not drift
through autonomous multi-file work. Claude Code is best used for
audits, prose diagnostics, and decision drafts; Codex is best used for
bounded implementation, CI/pkgdown plumbing, local validation, and PR
integration. The shared message bus remains `docs/dev-log/check-log.md`,
`docs/dev-log/decisions.md`, after-task reports, and PR comments.
Completed tasks and phases should end with an after-task report under
`docs/dev-log/after-task/`, matching the `drmTMB` habit that has
made that team easier to resume and audit.

## 2026-05-11  Add Shannon as cross-team coordination auditor

Decision: add Shannon as a standing read-only coordination role and
project-local skill. Rationale: Rose catches public consistency
within a PR, but the Codex / Claude workflow also needs a narrow check
for branch state, open PR fan-out, merge order, file overlap,
message-bus coverage, and after-task report gaps. Shannon is invoked
at checkpoints before handoffs, branch switches, merge sequencing, or
end-of-session summaries. Shannon reports pass, warn, or fail with
evidence and does not edit, merge, rerun CI, or replace the maintainer.

## 2026-05-11  Agent-to-agent collaboration improvements

Decision: codify five working-rule improvements that surfaced from
the 2026-05-11 doc-PR sprint and end-of-day reflection:

1. **Merge authority default**: Claude Code and Codex may self-merge
   their own PRs when CI is green and the scope is low-risk
   (documentation, dev-log, audits, after-task reports, design docs,
   CI workflow tweaks, asset additions, individual article rewrites
   against an approved snippet). For high-risk scope -- the
   `ROADMAP.md` Discussion Checkpoints (deletions of public exports,
   API changes, formula-grammar changes, likelihood / TMB / family
   changes) plus broad article rewrites -- the agent must ask the
   maintainer before merging. Rationale: today's 13-PR doc sprint
   showed that maintainer-only-merges was the bottleneck when the
   queue was docs-only and CI was uniformly green.
2. **Integrate before adding**: when the maintainer's input could
   fit an existing section in a doc or plan file, integrate inline.
   Add a new section only for genuinely new concerns. Rationale:
   today's earlier reactive-edit pattern accreted plan sections
   without improving comprehension.
3. **Agent-to-agent handoffs go in the repo**: PR comments addressed
   to the other agent, or directed lines in `docs/dev-log/check-log.md`,
   replace maintainer relay. Rationale: the maintainer should not be
   the message bus for routine handoffs.
4. **Surface review asks explicitly**: when opening a PR for
   maintainer review, follow up in chat with a specific list of what
   the maintainer needs to check or decide. Do not leave review items
   for the maintainer to discover by browsing the PR. Rationale: today
   the maintainer asked for this explicitly after several PRs landed
   with no clear "what you need to do" prompt.
5. **Pre-edit lane check on shared rule files**: before editing any
   shared rule file (the documentation triangle of `AGENTS.md`,
   `CLAUDE.md`, `ROADMAP.md`, `CONTRIBUTING.md`, plus
   `docs/dev-log/decisions.md`, `docs/dev-log/check-log.md`,
   `docs/design/`, `docs/dev-log/after-task/`, `inst/COPYRIGHTS`,
   `DESCRIPTION`), run `gh pr list --state open` and
   `git log --all --oneline --since="6 hours ago"`. Rationale: the
   2026-05-11 Shannon double-ship (both agents writing the Shannon
   role at the same time) was the canonical lane-collision failure;
   a pre-edit check would have caught it.

Each rule lives in the most natural file:

- Merge authority, integrate-before-adding, agent-to-agent handoffs,
  surface-review-asks --> `CLAUDE.md` "Collaboration Rhythm".
- Pre-edit lane check --> `AGENTS.md` "Multi-Agent Collaboration".
- After-task report at branch start (also added today as a discipline
  fix) --> `CONTRIBUTING.md` "Definition of Done".

## 2026-05-11  Binomial trial-count API: docs-only path (Option C)

Decision: when the binomial trial-count API is revisited (a Phase 3
implementation question parked in PR #23's Out-Of-Scope list), the
preferred path is **docs-only**:

- the engine continues to accept both `cbind(success, failure)` on
  the formula LHS AND the glmmTMB-style `weights = n_trials`
  overload;
- articles, vignettes, README, Get Started, and roxygen `@examples`
  standardise on `cbind(succ, fail)` as the canonical form;
- the `weights` argument retains its primary meaning (lme4 / glmmTMB
  log-likelihood multiplier) in user-facing prose.

Alternatives considered and not chosen:

- (A) rename to `binom_weights` / `trials` -- adds a near-duplicate
  argument and diverges from glmmTMB convention;
- (B) drop the overload and require `cbind(succ, fail)` LHS on
  binomial models -- cleanest but breaks glmmTMB-style code that
  users copy-paste from existing literature.

Rationale: the family-dependent meaning of `weights` is a real code
smell, but the cost of a rename or a hard migration outweighs the
ergonomic benefit when `cbind()` already provides the cleaner form.
Documentation can carry the canonical form without forcing a code
change.

This decision is referenced from
`docs/design/02-data-shape-and-weights.md` "Out Of Scope". Codex
should not implement A or B in the Phase 3 implementation PR; only
ensure new article examples and roxygen blocks prefer `cbind()`.

## 2026-05-11  Citation policy: Path A (Authors@R = gllvmTMB authors only)

Decision: `DESCRIPTION` `Authors@R` lists only the actual author(s)
of `gllvmTMB`. Upstream copyright holders for inherited code
(`R/mesh.R`, `R/crs.R`, `R/plot.R`'s `plot_anisotropy*`) are
acknowledged in five other places, every one more visible than a
buried `cph` block:

- `inst/COPYRIGHTS` -- canonical license / provenance file, now
  the single source of truth for inherited-code copyright; lists
  Anderson + Ward + English + Barnett (sdmTMB) with ORCIDs and
  Kristensen (TMB) plus Thorson (VAST, transitive) by name.
- `inst/CITATION` (new) -- curates `citation("gllvmTMB")` with the
  Nakagawa methods paper as primary and Kristensen et al. (2016)
  + Anderson et al. (2025) as recommended companions.
- `DESCRIPTION` Description text -- cites Kristensen et al.
  (2016), Anderson et al. (2025), and Hadfield & Nakagawa (2010)
  with DOIs.
- `README.md` "Citation and acknowledgements" -- formatted entries
  + a paragraph naming the four sdmTMB authors and the TMB
  dependency.
- File-top comments in `R/mesh.R`, `R/crs.R`, `R/plot.R` --
  point at `inst/COPYRIGHTS` for provenance.

Alternatives considered and not chosen:

- **Path B (sdmTMB-style maximal cph)**: list Anderson + Ward +
  English + Barnett + Kristensen as `cph` in Authors@R. This is
  the current state and is also CRAN-compliant. Rejected because
  the field name "Authors@R" reads as "authors", and these people
  are upstream copyright holders, not authors of `gllvmTMB`.
- **Path C (drmTMB-style minimal, no extra acknowledgment)**:
  Authors@R = Nakagawa only, no other changes. Rejected because
  gllvmTMB actually includes external code (unlike drmTMB), so
  the acknowledgment scaffolding (`inst/COPYRIGHTS`, README,
  inst/CITATION, file headers) is appropriate.
- **Add James Thorson as `cph` in Authors@R**: rejected because
  the VAST adaptation reached gllvmTMB transitively through
  sdmTMB; sdmTMB itself credits Thorson for its direct VAST
  inheritance. The `inst/COPYRIGHTS` mention is the right scope
  for transitive provenance.

Rationale: CRAN's "Writing R Extensions" §1.1.1 explicitly
supports the Path A pattern: *"If anyone other than the author(s)
has copyright in the package then this should be declared in the
DESCRIPTION file, usually by including a 'Copyright' field which
points to a file COPYRIGHTS in the inst directory."* The
`Copyright: inst/COPYRIGHTS` line already exists in DESCRIPTION;
Path A simply leans on it as the design intended, rather than
duplicating the same info in Authors@R.

Visibility audit:

- README readers see acknowledgment in the new "Citation and
  acknowledgements" section.
- `citation("gllvmTMB")` users see all three curated entries.
- `?make_mesh` / `?add_utm_columns` / `?plot_anisotropy` users
  see file-top provenance comments above the roxygen.
- Anyone reading DESCRIPTION sees four DOIs and a pointer to
  `inst/COPYRIGHTS`.
- Anyone reading `inst/COPYRIGHTS` sees ORCIDs and the upstream
  repo URLs.

Net effect: upstream acknowledgment is more visible after Path A
than before, despite the Authors@R cleanup.

## 2026-05-12  Legacy `gllvmTMB-legacy` archive scope (ratified)

Decision: the following items from `itchyshin/gllvmTMB-legacy`
**stay archived** in the legacy repo and do **not** re-enter the
current cleaned multivariate `gllvmTMB` repo. Source for this
list: Codex's 2026-05-12 read-only legacy excavation (posted as
a PR #35 comment) and Claude's PR #37 dispatch-queue audit; the
maintainer ratified the queue + archive list 2026-05-12
~11:30 MT.

What stays archived:

- **Single-response sdmTMB inheritance layer**: `R/fit.R`,
  `R/predict.R`, `R/residuals.R`, `R/dharma.R`, `R/emmeans.R`,
  `R/visreg.R`, `R/index.R`. These are not the multivariate
  stacked-trait surface; users who need them install
  `pbs-assess/sdmTMB` directly.
- **Single-response tests**: legacy `test-1-*`, `test-2-*`,
  DHARMa, emmeans, forecasting, projection, cross-validation
  tests. The current package's test surface is the multivariate
  one.
- **PIC-MOM as a public extractor path**: kept internal /
  hidden in the current repo. The canonical user-facing two-U
  diagnostic API is `compare_dep_vs_two_U()` and
  `compare_indep_vs_two_U()` (both already in current
  `R/extract-two-U-cross-check.R`).
- **Legacy Tier-3 essays**:
  `vignettes/articles/cross-package-validation.Rmd`,
  `simulation-recovery.Rmd`,
  `stacked-trait-gllvm.Rmd`,
  `morphometric-phylogeny.Rmd` (when distinct from
  `morphometrics.Rmd`), and other long discursive essays. The
  current pkgdown navbar is Tier-1 worked examples only; if a
  Tier-1 article needs to point at a legacy essay, cross-link
  rather than re-publish.

What is NOT archived (separate dispatch queue per PR #37):

- The phylogenetic / two-U doc-validation lane -- legacy article
  ideas and design notes adapted to current vocabulary
  (`vignettes/articles/phylogenetic-gllvm.Rmd`,
  `two-U-phylogeny.Rmd`, `dev/design/03-phylogenetic-gllvm-rewrite.md`).
- Selective Tier-2 reference article salvage (mixed-response,
  response-families, ordinal-probit, profile-likelihood-ci,
  lambda-constraint, api-keyword-grid).
- Curie identifiability simulation scaffolding
  (`dev/sim-two-U-identifiability.R`,
  `dev/two-U-analysis.R`,
  `dev/design/11-identifiability-regime-map.md`).
- Low-cost wording mine from legacy Pat / Design 08 (already
  superseded as a *spec*, but useful UX phrasing).

These positive items are queued in
`docs/dev-log/shannon-audits/2026-05-12-legacy-coopt-dispatch-queue.md`
with role allocations and prerequisites.

Rationale: drawing the archive line here keeps the public
package focused on the multivariate stacked-trait surface and
prevents the same scope-revisit conversation from happening at
each future Codex / Claude dispatch. If a future task wants to
revisit any specific archive entry, the rationale is "scope vs
sdmTMB / glmmTMB / drmTMB sister-package separation" and the
revisit needs an explicit maintainer decision recorded here as
an amendment.

## 2026-05-12  Naming convention: "two-U" is a task label; public math uses S / s

Decision: across the package, **"two-U" is a legacy task /
nickname label** for the four-component phylogenetic model
(`phylo_latent + phylo_unique + latent + unique`). The actual
mathematical notation in roxygen, vignettes, articles, and
user-facing documentation must use `S` / `s` for the unique-
variance diagonal, matching the engine algebra:

```
Sigma = Lambda Lambda^T + diag(s)
```

For each correlation tier the decomposition takes the same shape:

```
Sigma_phy = Lambda_phy Lambda_phy^T + diag(s_phy)
Sigma_non = Lambda_non Lambda_non^T + diag(s_non)
Omega     = Sigma_phy + Sigma_non
```

What stays "two-U":

- **File names**: `R/extract-two-U-cross-check.R`,
  `R/extract-two-U-via-PIC.R`,
  `tests/testthat/test-phylo-two-U.R`,
  `tests/testthat/test-two-U-cross-check.R`, etc.
- **Function names**: `compare_dep_vs_two_U()`,
  `compare_indep_vs_two_U()`, `extract_two_U_via_PIC()`,
  `.is_two_U_fit()`.
- **Task labels** in dev-log entries, PR titles, dispatch queues,
  and informal references to "the four-component model" or "the
  phylo/two-U lane".

What uses `S` / `s`:

- **Roxygen prose** for any extractor or function that describes
  the unique-variance diagonal.
- **Article body text** (`Sigma = Lambda Lambda^T + diag(s)`).
- **Tier-1 / Tier-2 vignettes**.
- **README**, **CONTRIBUTING**, and **`docs/design/*.md`** math.
- **Equations** in `\eqn{...}` LaTeX blocks within roxygen.

Rationale: the function and file names exist already; renaming
them is a high-friction breaking API change (even pre-CRAN it
would invalidate any downstream user / Codex / Claude code that
imports those names). But the *mathematical notation* in public
prose is freely editable, and the engine algebra in code already
uses S/s. The distinction is: **function-name "U" = task-label
nickname; math-notation "S/s" = canonical algebra**.

Recording context: Codex flagged this 2026-05-12 in their
pre-sweep check, after the maintainer named the convention in
chat ("we need S rather than U"). Codex's sweep branch adds a
check-log note that the next phylo/two-U lane must translate
legacy `U` notation to current `S/s`. This `decisions.md` entry
is the parallel Claude-side record so the convention survives
beyond Codex's per-branch check-log notes and into the canonical
scope log.

When the phylo/two-U doc-validation branch (item #1 in the
PR #37 dispatch queue) lands, the article body must use S/s in
math, even though the article title and file paths can still
reference "two-U" as the model nickname.

## 2026-05-14  Naming convention: math notation reversed S/s -> Psi/psi

Decision: **reverse the 2026-05-12 S/s convention.** The
unique-variance diagonal in user-facing math (roxygen,
vignettes, articles, README, design docs, NEWS) is now the
Greek letter **Psi**, matching the factor-analysis / SEM
literature (Bollen 1989, Mulaik 2010, lavaan documentation,
Anderson 2003). The 2026-05-12 decision above is now
superseded for math notation; the function- and file-name
"two-U" task-label convention from that same entry is
preserved (see below).

Engine algebra in code-style:

```
Sigma = Lambda Lambda^T + diag(psi)
```

Math-style for matrices and tier-subscripted forms:

- Within-tier covariance:
  `\boldsymbol\Sigma = \boldsymbol\Lambda \boldsymbol\Lambda^{\!\top} + \boldsymbol\Psi`
  with `\boldsymbol\Psi = \mathrm{diag}(\psi)`.
- Per-tier subscripts:
  `\boldsymbol\Sigma_{\text{phy}} = \boldsymbol\Lambda_{\text{phy}} \boldsymbol\Lambda_{\text{phy}}^{\!\top} + \boldsymbol\Psi_{\text{phy}}`,
  `\boldsymbol\Sigma_{\text{non}} = \boldsymbol\Lambda_{\text{non}} \boldsymbol\Lambda_{\text{non}}^{\!\top} + \boldsymbol\Psi_{\text{non}}`.
- Between- / within-unit tiers: `\boldsymbol\Psi_B`,
  `\boldsymbol\Psi_W`, `\boldsymbol\Psi_R` (spatial),
  `\boldsymbol\Psi_P` (phylogenetic in functional-
  biogeography ladder).
- Total: `\boldsymbol\Omega = \boldsymbol\Sigma_{\text{phy}} + \boldsymbol\Sigma_{\text{non}}`
  (or the 3-piece fallback
  `\boldsymbol\Omega = \boldsymbol\Lambda_{\text{phy}} \boldsymbol\Lambda_{\text{phy}}^{\!\top} + \boldsymbol\Lambda_{\text{non}} \boldsymbol\Lambda_{\text{non}}^{\!\top} + \boldsymbol\Psi`
  when `\boldsymbol\Psi_{\text{phy}}` is not separately
  identifiable).

Per-trait scalars (italic lowercase) for derived quantities:

- `extract_phylo_signal()` output:
  `psi_t = 1 - H^2_t - C^2_{\text{non},t}` -- the t-th
  per-trait uniqueness proportion. Partition:
  `H^2_t + C^2_{\text{non},t} + psi^2_t = 1`. (Lowercase
  `psi_t` to distinguish from the bold-capital
  `\boldsymbol\Psi` matrix; mathematically `psi_t` is a
  scaling of the t-th diagonal of `\boldsymbol\Psi`.)

Function- and file-name "two-U" task-label retention:

- Function names (`compare_dep_vs_two_U()`,
  `compare_indep_vs_two_U()`, `extract_two_U_via_PIC()`,
  `.is_two_U_fit()`) **stay** as-is per the 2026-05-12
  task-label rule. Renaming to "two_psi" is a breaking API
  change with no offsetting benefit; the task-label "U" is
  a search anchor for legacy code.
- File paths (`R/extract-two-U-cross-check.R`,
  `R/extract-two-U-via-PIC.R`,
  `tests/testthat/test-phylo-two-U.R`,
  `tests/testthat/test-two-U-cross-check.R`) **stay**.

The distinction is: **function-name / file-name "U" =
legacy task-label nickname; math-notation "Psi/psi" =
canonical algebra**. Same separation as the 2026-05-12
entry; only the math letter changed.

Migration: in-flight notation-switch PR sequence NS-1
(rule files + decisions.md + check-log.md), NS-2 (README
+ design docs), NS-3 (R/ roxygen + `man/*.Rd` regen via
`devtools::document()`), NS-4 (articles part 1), NS-5
(articles part 2 + NEWS entry).

Rationale: the 2026-05-12 S/s decision was a gllvmTMB-
specific choice; subsequent reading and maintainer reflection
found that the factor-analysis / SEM tradition uses Psi (and
the lavaan + Bollen literature an applied user is likely to
read alongside gllvmTMB articles uses Psi consistently).
Pre-CRAN reversal cost is low; reversal post-CRAN would be
much higher. The maintainer authorized the switch
2026-05-14 ~07:00 MT.

Cross-reference: `check-log.md` Kaizen points 8 and 9 are
updated in the same notation-switch PR sequence to reflect
the new math notation; historical check-log entries
(append-only) keep their original S/s wording because that
was the canon at the time of writing.

Recording context: maintainer message 2026-05-14
~06:50 MT (paraphrased): *"at the moment we use S for a
unique bit (diagonal matrix) - I am thinking of changing it
to \Psi (Greek letter) - which may be more consistent with
the literature - many small changes through the pkgdown
pages and function documentations - how much work is this?"*.
Reply: 4-5 PRs, ~1-2 days mostly mechanical. Maintainer
reply: *"let's go Psi!"*.

## 2026-05-14  Insert Phase 5.5 External Validation Sprint before CRAN submission

Decision: insert a **new Phase 5.5 External Validation Sprint**
between Phase 5 (CRAN mechanics) and the actual
`devtools::submit_cran()` call. The sprint is a 6-12 week
period of external scrutiny -- pilot users, methods reviewers,
cross-package agreement, and a ~10-DGP simulation grid -- after
the package state is mechanically CRAN-ready but before the
submission event fires.

Rationale: CRAN acceptance is a low bar (does not break R;
passes 3-OS `R CMD check`). Scientific credibility is a higher
bar. `src/gllvmTMB.cpp` has had one author (Codex). In-repo
persona-style audits are no substitute for external scrutiny.
Phase 5.5 ratifies that the package has passed external review
before `submit_cran()` fires, so the "ready to submit" signal
inside the repo aligns with "ready for scientific scrutiny"
outside it.

Scope (sequencing locked when Phase 5.5 dispatches; maintainer
2026-05-14):

- **External pilot users** (~3-5 from the Nakagawa lab network):
  release-candidate build (v0.2.99 or similar). Each pilot is
  asked for (a) one fit on their own data, (b) bug reports, (c)
  "this confused me" notes on docs, (d) one publishable-quality
  plot.
- **Methods reviewers** (~1-2): read `src/gllvmTMB.cpp`, check
  the TMB template + likelihood derivation against the
  manuscript equations (Nakagawa et al. *in prep*), and run a
  parameter-recovery study on a non-standard family. If Codex
  returns by Phase 5.5, Codex is the natural reviewer for the
  C++.
- **Cross-package empirical agreement on a wider DGP grid**:
  glmmTMB, gllvm, galamm, sdmTMB, MCMCglmm, Hmsc. Parameter
  agreement within identifiability rotation; CI coverage
  agreement; fit-time comparison. Builds on the Phase 1c
  `cross-package-validation.Rmd` port with broader DGP coverage.
- **~10-DGP simulation grid**: Gaussian / binomial / Poisson /
  NB2 / ordinal × {single-level, two-level, phylo, spatial} ×
  {n = 30, 100, 500}. Report bias, RMSE, and CI coverage in one
  table. This is what `gllvm` and `galamm` have not done at
  this scale; it is the gllvmTMB rigour-paper artefact.
- **No-major-change settling period**: 2-4 weeks of "only bug
  fixes, no API changes" with the merged state to surface
  latent issues.

Exit criterion: all external reviewers report no blocking
issues; simulation grid shows nominal coverage and bias < 10%
RMSE on identified parameters; cross-package parameter agreement
is within identifiability tolerance; maintainer ratifies "ready
for `submit_cran()`".

Estimated duration: 6-12 weeks. Dominates the timeline between
Phase 5 mechanics done and the actual submission event.
Estimated PR count: ~3-8 PRs for the validation artefacts
(sim-grid scripts, cross-package fixtures, release-candidate
build, response-to-reviewers dev-log entries). Each pilot
user's feedback may generate documentation PRs.

Personas engaged: Fisher (lead -- coverage + bias study); Curie
(sim-grid DGPs); Gauss (TMB-template review with external
reviewer); Pat + Darwin (pilot-user feedback synthesis); Rose +
Shannon (final pre-submission audit); Jason (any 11th-hour
landscape scan).

Recording context: maintainer message 2026-05-14 (paraphrased):
*"I have no intention of putting this on CRAN till we do an
amazing number of tests and checking and simulations, not just
me and you, but I include several more people."* The maintainer
also clarified the pilot-user identities and exact reviewer
roster should be locked when Phase 5.5 actually dispatches
(later phase), since the lab roster and reviewer availability
depend on timing.

Cross-reference: this entry is the canon for citing Phase 5.5
from the refreshed `ROADMAP.md` (2026-05-14 roadmap refresh
PR). Phase 5.5 is also covered in
`docs/dev-log/after-task/2026-05-14-strategic-plan-revision.md`
(plan-file lane, not canon) and the active plan at
`~/.claude/plans/please-have-a-robust-elephant.md`.
