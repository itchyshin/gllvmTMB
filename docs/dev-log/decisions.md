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
