# Decisions log

Date-stamped one-paragraph design decisions. Append-only.

## 2026-08-18  G0 SIGNED: Design 125 G4c — MSPL profile fork **B** (unpenalized Laplace at fixed MSPL nuisance); fork A is ablation only

Decision (Shinichi, chat, 2026-08-18 — explicit paste against the deferred G4c
gate, not blanket lane approval): the Design 125 profile fork is **B**. The
signature profile path for LA-MSPL intervals inverts a likelihood ratio built on
the **unpenalized** Laplace-approximated marginal likelihood, evaluated at
nuisance parameters **fixed at their MSPL values**. Fork **A** (profiling the
penalised MSPL tape) is retained as an **ablation arm only** — measurable,
reportable as a comparator, never the claim path. Fork **C** (hybrid) is **not
picked** and is out of the v1 claim set.

This **discharges G4c `FORK-DEFER`**, which had been `SIGNED` on 2026-08-17 as
*"no live profile impl / smoke until fork G0"* and was the single gate blocking
G3 smoke. `docs/design/125-mspl-profile-led-intervals.md`,
`docs/dev-log/research/2026-08-17-mspl-profile-led-prereg-ademp.md` and
`LOOP/decision-queue.md` are updated to read **FORK-B** rather than
**FORK-DEFER**.

**Why B and not A** — the reason is measured, not stylistic. Kosmidis & Firth
(2021, *Biometrika* 108(1):71–82, §2.2 p. 5), read directly and verified
2026-08-17 (`docs/dev-log/research/2026-08-17-kosmidis-firth-2021-profile-caveat.md`),
state that the coverage failure under a finiteness penalty *"is also true when
the penalized likelihood is profiled for the construction of confidence
intervals"*. The mechanism rules out the obvious workaround: this is **not** a
quadratic-approximation artefact — the one failure mode profiling repairs — but
a consequence of their Corollary 1, that with binomial responses the penalised
estimator takes only finitely many values with finite components while the true
parameter is unbounded. Profiling changes the interval's shape, not the
boundedness of what it is built from. **Fork A therefore profiles exactly the
object the penalty's own authors say cannot be made to cover**, so a fork-A
coverage programme would be pre-refuted; fork B profiles the unpenalized
objective and is not reached by that argument. The transfer of the caveat from a
fixed-design binomial GLM to a latent-variable GLLVM remains **AGENT-INFERRED,
not established** — which is a reason to prefer B, not a licence to claim B
covers.

**What B still does not have.** No evidence that fork B's intervals cover: B is
now the *named construction to be tested* under the SIGNED ADEMP pre-registration,
not a validated one. `MSPL-04` stays **`blocked`**. Hard stops unchanged and
explicitly **not** waived here: no public `se = TRUE` / `vcov()` / `confint()`;
#1077 stays **draft** (undraft needs its own explicit ask); no Totoro/DRAC
(D-50/D-139); no Design 118 or B1 reopen (D-157); no NEWS/article `covered`
language; `codex/lane-b-mspl-interval-feasibility` stays **PROTECTED**. The
docs sitting left `R/` untouched; L0 authorising code is the next entry
(#1130), which lifts G3 `WAIT` for L0/L1 local compute only.

**Ledger-citation correction shipped with this entry.** Vault decisions
renumbered the MSPL-interval decision from `D-148` to
[`D-159`](../../../shinichi-brain/memory/DECISIONS.md) on 2026-08-18, because
`D-148` had been reused hours later by the *never-ask-a-bare-question* rule and
a Markdown anchor resolves to the first matching heading. Every gllvmTMB
citation that meant *MSPL-interval withhold / calibrated route / jackknife
rejected* now reads **D-159**; the two citations that genuinely meant
*paste-ready draft answer* (`2026-08-17-mspl-b1-aftermath-G0.md`) still read
**D-148**, correctly. **D-149** (SE pins ≠ public intervals; Lane B ownership) is
unchanged throughout.

**Poisson \(W\) PARK → REPLACE sync (same sitting, not a new G0).** Design 125
and the ADEMP pre-reg still presented `G1 PARK SE doors` / "tape unchanged"
as current. That freeze was superseded on 2026-08-17 and landed on `main`
as #1111 (`3053fce3`). Those two files now say **SIGNED REPLACE**. SE-series
family doors and public `se` stay closed.

## 2026-08-18  Authorising code: `objective=` selector for Design 125 fork B (L0; supersedes #1126)

Decision (Shinichi, this sitting, given once and then reaffirmed twice
explicitly when the lane paused to confirm):

> G0 Design 125 fork: B — profile the unpenalized Laplace objective at fixed
> MSPL nuisance coordinates. Fork A retained as ablation only. This unlocks L0
> plumbing + L1 local smoke (local compute only). Still NOT: Totoro, T\*
> thresholds, undraft #1077, public `se=TRUE`/`vcov`/`confint`, MSPL-04 off
> blocked.

This closes **G4c FORK-DEFER**, the gate that had blocked every downstream item
in `docs/design/125-mspl-profile-led-intervals.md` and its ADEMP pre-registration
(`docs/dev-log/research/2026-08-17-mspl-profile-led-prereg-ademp.md`). G3 **WAIT**
is lifted **for local compute only**: gates **L0** (plumbing) and **L1** (small
local coverage smoke) in the pre-reg's §P5 are now runnable. **L2 onward, and
every Totoro/DRAC gate, stay blocked.**

What fork B *is*, stated so no later reader over-reads it: the walked objective
is `fit$mspl$unpenalized_tmb_obj` (the ordinary Laplace tape, `estimator_id = 2`)
and the nuisance coordinates are **held fixed** at the MSPL point estimate
\(\tilde\theta\). It is therefore a fixed-nuisance one-dimensional slice, **not**
a nuisance-maximised profile, and a threshold crossing on it is a computability
observable. Fork **A** (walk the penalised tape, re-optimising nuisance) stays in
the code as the **ablation** arm so the two can be measured on the same fit; it
is not the construction.

Why B rather than A: the Kosmidis & Firth (2021, *Biometrika* 108(1) §2.2)
caveat verified under [#1090](https://github.com/itchyshin/gllvmTMB/pull/1090)
bites fork A directly — regions built from the finiteness-penalised objective
fail to cover *including when the penalised likelihood is profiled*. Fork B
walks an objective that carries no finiteness penalty, so the KF2021 mechanism
does not apply to the curve itself. That is a reason to prefer B as the
construction to *measure*; it is **not** a coverage claim, and none is made here.

Consequences recorded in the same sitting: the `#1090` probe
(`.gllvmTMB_mspl_profile_feasibility()`) previously **hard-refused** the
penalty-off tape and so structurally could not run fork B. That refusal is
replaced by an explicit `objective = c("penalised", "unpenalized")` selector,
default `"penalised"` (fork A, byte-identical to prior behaviour). `tape =
c("Q_P", "Q_0")` is accepted as the existing curvature-pin synonym so the
parallel L0 (#1126) and L1 (#1128) callers keep working; disagreeing
`objective`/`tape` pairs are a typed refusal. Both arms keep
`calibrated = FALSE`, `public_confint = "refused"`, `coverage_claim = "none"`,
stay unexported, and stay binomial logit/probit/cloglog fenced.

This sitting ships the signed G0 **and** the authorising code together. The
parallel L0 PR #1126 implemented the same estimand under `tape = "Q_0"` only
and recorded a weaker "computability unlock, not a fork pick" G0; that API is
retained as the synonym, and that PR is superseded rather than dual-merged.

Unchanged hard stops: **`MSPL-04` stays `blocked`**; no public `se = TRUE` /
`vcov()` / `confint()`; [#1077](https://github.com/itchyshin/gllvmTMB/pull/1077)
stays **draft**; no Totoro/DRAC campaign; **T\* thresholds are not frozen** (that
needs its own G0); no NEWS/README/article `covered` claim; Design 118 / B1 stay
parked under D-157.

## 2026-08-17  G0 SIGNED: Poisson MSPL \(W\) — REPLACE with working \(W_*\) (supersedes PARK)

Decision (Shinichi, chat — *"as you recommended"* after Cursor’s REPLACE
recommendation; explicit three-way paste against the G0 card, not blanket
lane approval): Poisson MSPL live weight moves from GLM-outer
\(W=\operatorname{diag}(\mu)\) / `return eta` to working logistic \(W_*\) on
the same \(X_*\), following the Tweedie precedent.

Card: `docs/dev-log/research/2026-08-17-mspl-poisson-W-G0.md` Status
**SIGNED — REPLACE**. The earlier **SIGNED — PARK SE doors** reading from
*"approve all things in this lane"* / `G1 PARK SE doors` is **superseded**
(#1096 provenance flag answered). Signed paste requires `src/` change with
`tmb-likelihood-review` + Gauss/Noether + `03-likelihoods.md` + simulation
recovery, and rewrite of #1064 W2/W7 oracles (they pin `return eta` by design).

**This sitting signs the G0 only.** Implementation is **not** started here;
Codex owns the tape PR. REPLACE unlocks the *programme* to change the tape;
SE-series family doors **stay closed** until twin rematch + recovery are green.
Hard stops unchanged: no public `se`; `MSPL-04` `blocked`; no Design 118;
Lane B PROTECTED; no rebuild #1090.

## 2026-08-17  G0 RECORDED: land the binomial profile-computability probe from the Claude lane

Decision (Shinichi, this sitting, repeated and explicit — *"a pin — build it
now"* in direct answer to the pin-vs-parked-construction question; *"you can go
ahead — you choose the best one"*; and a `/goal` naming the two functions
`landed on current main`): the internal, unexported, uncalibrated binomial
profile-COMPUTABILITY probe lands on `main` from
`claude/mspl-interval-computable-pin`.

Recorded here because the authority was given in chat and the repo is the message
bus. Three **written** fences would otherwise forbid it, and an adversarial
review correctly refused to open them on a lane's own say-so:

- **D-149** — *"Codex Lane B remains the binomial SE owner. Do not rebuild,
  reassign, or absorb it."*
- `docs/dev-log/handover/2026-07-25-active-lane-split.md` — the source branch
  `codex/lane-b-mspl-interval-feasibility` is **PROTECTED**, *"No
  absorb/rebase/merge"*.
- **Design 125 G4c (SIGNED)** — *"no live profile impl / smoke until fork G0."*

**Waived for this artefact ONLY.** Explicitly NOT waived: no public `confint()` /
`vcov()` / `se = TRUE`; `MSPL-04` stays `blocked`; no coverage claim of any kind;
no admission gate (softness ratio / N2′-curvature / separation stays with the
parked construction, D-157); no `src/` change; PR #981 stays open for its own
`src/` work; #1077 stays draft. Codex Lane B keeps binomial SE ownership — this
probe is a computability instrument, not an SE route, and does not reassign that.

Two facts the next reader needs. (1) The probe profiles the **penalised tape
only** (hard-refused otherwise), so it implements Design 125's **fork A** and
structurally cannot run fork B (`unpenalized_tmb_obj`) or C; landing it must not
be read as picking that fork. (2) Kosmidis & Firth (2021, Biometrika 108(1),
§2.2 p. 5), verified this sitting, state the coverage failure under a finiteness
penalty *"is also true when the penalized likelihood is profiled"* — so a finite
bracket from this probe is evidence of computability and nothing else. See
`docs/dev-log/research/2026-08-17-kosmidis-firth-2021-profile-caveat.md`.

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

## 2026-05-14  Retire the "two-U" task label and PIC cross-check entirely

Decision: **retire the legacy "two-U" task label and the PIC
(phylogenetic independent contrasts) cross-check diagnostics
from the package surface.** This overrides the 2026-05-12
naming-convention decision and the 2026-05-14 notation-reversal
entry's "function- and file-name retention" clause. Going
forward there is **only one canonical phylogenetic fit per
parameterisation**; no parallel "joint vs unstructured" or
"joint vs PIC-MOM" diagnostic exists in the public API.

What is retired:

- **R/ source files** deleted: `R/extract-two-U-via-PIC.R`,
  `R/extract-two-U-cross-check.R`.
- **Test files** deleted: `tests/testthat/test-phylo-two-U.R`,
  `tests/testthat/test-pic-mom.R`,
  `tests/testthat/test-two-U-cross-check.R`.
- **Exported functions removed**: `compare_PIC_vs_joint()`,
  `compare_dep_vs_two_U()`, `compare_indep_vs_two_U()`,
  `extract_two_U_via_PIC()`. Internal helper `.is_two_U_fit()`
  removed with `R/extract-two-U-cross-check.R`.
- **`man/*.Rd`** removed (auto via `devtools::document()`):
  the four `.Rd` files matching the exported names above.
- **`_pkgdown.yml`** Diagnostics reference-index entries
  removed (two lines).
- **Prose scrub**: every "two-U" / "two U" / "two_U" wording
  in R/ roxygen, code comments, design docs, README, NEWS,
  and `ROADMAP.md` is rewritten to use "paired phylogenetic
  decomposition" or removed entirely. Function-name "U"
  retention is voided.

What replaces them: the canonical identifiability diagnostic
for paired phylogenetic fits is **`check_identifiability(fit,
sim_reps = ...)`** (Phase 1b deliverable; Fisher-designed
signature recorded in
`docs/dev-log/after-task/2026-05-14-phase-1a-batch-d.md`).
`check_identifiability()` returns a multi-component list
(`$recovery / $loadings / $hessian / $flags`) that subsumes
the rejected legacy cross-checks: Procrustes-aligned loading
residuals, Hessian eigenvalue rank check, and recovery-rate
table across `sim_reps` simulated refits. No PIC-MOM
two-stage estimator is exposed.

Rationale: the legacy "two-U" nickname predates the current
package vocabulary by ~6 months and the PIC-MOM cross-check
was scoped before profile-likelihood and bootstrap CIs landed
on the canonical fit. Keeping function and file names on a
retired task label costs every new reader an interpretive hop;
PIC-MOM is a Gaussian-Brownian-motion-only diagnostic that
the more general `check_identifiability()` covers without the
restriction. The maintainer's 2026-05-14 framing: *"this must
be only fit -- we do not use PIC and do not use U any
longer."* Pre-CRAN; no downstream user code depends on these
exports.

Migration: this is a hard break. Pre-CRAN agents using
`compare_dep_vs_two_U()` etc. will get an unexported-function
error after this PR merges. No `lifecycle::deprecate_*()`
window is offered (pre-CRAN). The migration target is
`check_identifiability()` (when it ships in Phase 1b).

Recording context: maintainer messages 2026-05-14 evening,
paraphrased: *"this must be only fit - we do not use PIC and
do not use U any longer"*, followed by *"3 confirm"* on the
explicit ask whether to drop PIC + drop U from function/file
names.

## 2026-05-14  Elevate random slopes to pre-CRAN (Phase 1c-slope)

Decision: **insert a new pre-CRAN phase "Phase 1c-slope"
between Phase 1b validation and Phase 1c article ports** to
implement random slopes (a.k.a. reaction-norm random effects;
"plasticity" *sensu* O'Dea et al. 2022). This overrides the
prior placement of random slopes as a Phase 6 (post-CRAN)
deferred item.

Why pre-CRAN: the package's canonical methods paper (Nakagawa
et al. *in prep*) includes random slopes as Appendix B
(Examples B.1 and B.2 plus the general formulation B.3).
Shipping CRAN without the Appendix-B machinery would publish a
package that does not cover the maintainer's own published
worked examples. The legacy gllvmTMB-legacy package had a
779-line article on this topic
(`vignettes/articles/random-slopes-personality-plasticity.Rmd`,
status note: engine-blocked on hardcoded `n_traits` sizing) but
the engine work was deferred at the 2026-05-10 reset. This
decision recovers it.

Scope (six PRs, persona-consulted 2026-05-14 evening; Darwin /
Fisher / Boole briefs recorded in the Phase 1a close after-task
report at
`docs/dev-log/after-task/2026-05-14-phase-1a-close.md`):

1. **Engine generalisation** (Boole + Gauss): four `n_traits`
   hardcoded sites in `R/fit-multi.R` (lines 901, 1196,
   1198-1199 and W-block mirror at 1200-1203) generalise to
   `n_lhs_cols = T * (1 + Q)` where `Q` = number of
   random-slope covariates. C++ side: `src/gllvmTMB.cpp`
   `Lambda_B` / `s_B` packing comments + new `Z_lhs`
   `DATA_MATRIX` for linear-predictor assembly. Includes
   Fisher's joint-block sign-pinning (combined intercept +
   slope block, not block-by-block) and the slope-covariate
   centering guard (`cli::cli_warn` if `|mean(x) / sd(x)| >
   0.1`).
2. **Extractor extensions**: `extract_Sigma()` with `block =
   c("u", "b", "u,b", "aug")`; `extract_repeatability()` with
   `temp = focal_value` and `marginalised = TRUE/FALSE`
   (Eqs. 50 and 52); `extract_communality()` with `temp =
   focal_value` (Eq. 56).
3. **Recovery test** with Fisher's five DGPs (`tests/testthat/test-random-slope-recovery.R`):
   RS-1 aligned $\Lambda_u = \Lambda_b$ (Eq. 41 running
   example); RS-2 two-axis ($d_B = 2$); RS-3 boundary
   ($\text{Cov}(u, b) = 0$); RS-4 degenerate
   ($\text{Var}(b) = 0$); RS-5 mixed-attribute sex covariate
   (Appendix B.2). `skip_on_cran()` and `skip_on_ci()` gated.
4. **`check_identifiability()` augmentation**: three new flag
   classes (`$flags$intercept_slope_decoupled`,
   `$flags$slope_boundary`,
   `$flags$temp_within_var_low`) per Fisher's brief.
5. **Random-slope-tailored plot types in the dispatcher** (Darwin
   priorities, per `R/plot-gllvmTMB.R`): add `type =
   "reaction_norm"` (per-individual spaghetti, faceted by
   trait), `type = "intercept_slope_ellipse"` (BLUP scatter
   with 95 % bivariate ellipse, per trait), `type =
   "repeatability_curve"` ($R_t(\text{temp})$ across the
   covariate range, Eq. 50). Update existing `type =
   "correlation"` to accept `block = c("u", "b")` for
   personality-syndrome and plasticity-syndrome separately.
6. **Article port + biological worked example**: port
   `random-slopes-personality-plasticity.Rmd` from
   gllvmTMB-legacy (779 lines) and update for current API and
   Ψ / ψ notation. Add Darwin's missing-question worked
   example: *"Does temperature variability erode the
   boldness-activity syndrome?"* using Eq. 54's
   $\boldsymbol\Sigma_B(x) = \boldsymbol\Sigma_B^{(u)} +
   x\boldsymbol\Sigma_B^{(u,b)} + x\boldsymbol\Sigma_B^{(b,u)}
   + x^2\boldsymbol\Sigma_B^{(b)}$.

API decision (Boole-locked): **extend existing `latent()` /
`unique()` keywords** to accept augmented LHS:
`latent(0 + trait + (0 + trait):temp | ID, d = d_B) +
unique(0 + trait + (0 + trait):temp | ID)`. Byte-for-byte the
paper's Appendix B.1 syntax. No new keywords. 3 × 5 grid
untouched. `phylo_latent` / `spatial_latent` augmented-LHS
flagged as `lifecycle::experimental` post-CRAN.

Sequencing: Phase 1c-slope runs **between Phase 1b validation
and Phase 1c article ports**. Phase 1c-viz (visualization
layer completion) absorbs the random-slope plot types as part
of its dispatcher polish work and runs *after* Phase 1c-slope
so the visualization is tailored to the augmented decomposition
(maintainer 2026-05-14: *"we best do the random slope stuff
before visualization because visualization tailored to this
needs to be developed"*).

Expected timeline: ~2 – 3 weeks. Phase 1 close timeline
extends by that amount. CRAN target slips ~2 – 3 weeks.

Recording context: maintainer messages 2026-05-14 evening
asking about random slopes (referencing the methods-paper
Appendix B and the legacy article), then *"3 yes this has to
be pre-CRAN -- actually this is important one and we should
put more ideas to it -- opinions on this random slopes
because it's really interesting. You can get different
correlations, all sorts of things. The visualization there is
an important one as well. So we best do the random slope
stuff before visualization because visualization tailored to
this needs to be developed."* Approval of the six-PR scope
above (Phase 1c-slope) is recorded in the *"1 yes 2 yes and
3 confirm"* maintainer message 2026-05-14.

## 2026-05-15  Partial restoration of joint-vs-unstructured cross-checks under `two_psi` rename

Decision: **partially roll back the 2026-05-14 PIC / "two-U"
retirement**. The PIC-based cross-checks
(`extract_two_U_via_PIC()`, `compare_PIC_vs_joint()`) **stay
retired** -- those were Gaussian-Brownian-motion-only and
genuinely superseded by `check_identifiability()`. But the
**joint-vs-unstructured** cross-checks (originally
`compare_dep_vs_two_U()` and `compare_indep_vs_two_U()`) are
**restored under new names**: `compare_dep_vs_two_psi()` and
`compare_indep_vs_two_psi()`. Same signatures, same engine
calls, same return structure -- only the names change to
match the new Psi notation.

What is restored:

- **R/ source file** (new path):
  `R/extract-two-psi-cross-check.R` (was
  `R/extract-two-U-cross-check.R` before the 2026-05-14
  retirement; content restored from the pre-deletion git
  history at commit `3eafd61^` and renamed `two_U` → `two_psi`
  throughout).
- **Exported functions** restored (NAMESPACE auto-regenerated):
  `compare_dep_vs_two_psi`, `compare_indep_vs_two_psi`.
- **Internal helpers** restored (renamed):
  `.is_two_psi_fit`, `.refit_inputs(fit_two_psi)`.
- **`_pkgdown.yml`** Diagnostics reference-index entries:
  `compare_dep_vs_two_psi`, `compare_indep_vs_two_psi`.
- **`man/*.Rd`**: two entries auto-regenerated by
  `devtools::document()`.

What stays retired:

- PIC-MOM diagnostic (`extract_two_U_via_PIC()`,
  `compare_PIC_vs_joint()`) and its R/ source file
  (`R/extract-two-U-via-PIC.R`). The maintainer's
  2026-05-14 phrasing was *"this must be only fit -- we do
  not use PIC and do not use U any longer"*; on reflection
  the PIC restriction was the substantive scope decision,
  and the U → Psi rename was the naming decision. The two
  joint-vs-unstructured cross-checks are NOT PIC-based;
  they refit the same data with `phylo_dep + dep` or
  `phylo_indep + indep` using the **same engine** as the
  canonical fit. They are useful and were caught up in the
  deletion overzealously.
- Test files (`tests/testthat/test-phylo-two-U.R`,
  `test-two-U-cross-check.R`, `test-pic-mom.R`) **stay
  deleted**. Replacement tests for
  `compare_*_vs_two_psi()` can land in Phase 1b alongside
  `check_identifiability()`; the immediate priority is
  unblocking the pkgdown render.

Why this restoration is needed: the `phylogenetic-gllvm.Rmd`
article (lines 286, 292) calls
`compare_indep_vs_two_U(fit)` and
`compare_dep_vs_two_U(fit)` directly in eval=TRUE code
chunks. After the 2026-05-14 retirement, pkgdown render
failed with `could not find function "compare_indep_vs_two_U"`
(workflow run #95 on commit `b597673`). I should have
caught this in the Phase 1a close PR's article scrub but
did not; the article-side function-call references were
not in scope. The right fix is to restore the functions
under the new naming convention (matching the maintainer's
"we do not use U any longer" while preserving the
behavioural scope of the article).

Migration: this is a partial reversal of the 2026-05-14
PIC / "two-U" retirement decision. The two retired-then-
restored functions get new names; the four deleted PIC
exports stay deleted. The NEWS bullet for the 2026-05-14
notation reversal is rewritten in this PR to reflect the
partial restoration.

Recording context: maintainer message 2026-05-15 morning,
paraphrased: *"we deleted this file ! could not find
function 'compare_indep_vs_two_U' but you can get it from
gllvmTMB-legacy -- also it should be named
compare_indep_vs_two_psi and you may find a function
named like that."* (No `compare_*_vs_two_psi` existed in
legacy; the rename happens in this restoration PR.)

## 2026-05-15  Audit-driven replan: P0 multi-start fix + P1 API surface + partial reset of Phase 1c sequencing

Context: an external code/architecture/statistical-design
audit of gllvmTMB was shared 2026-05-15 (after the morning's
wave of Phase 1b merges -- #100, #101, #102, #103, #104,
#105, #106, #109, plus the Phase 1e phylo-3piece-fallback
PR #107 and the Phase 1c lambda-constraint port PR #108).
The audit's full text and triage live in
`docs/dev-log/audits/2026-05-15-external-audit-response.md`.

Three ratified outcomes from this audit:

### 1. P0 fix: multi-start `obj$report()` / `sdreport(obj)` consistency

The audit's #1 concrete concern was a multi-start
bookkeeping bug at `R/fit-multi.R:1700-1702`: `obj$report()`
with no args uses `obj$env$last.par` (TMB's LAST-evaluation
tracking, NOT necessarily `best_opt$par`). When restart 1
won but restart N (N > 1) ran last, every downstream
extractor reading `fit$report` consumed values for the
wrong parameter vector.

Verified by code inspection (~30 min before patching).
Fix: three-step pinch of TMB's internal state to `opt$par`
(`obj$fn(opt$par); obj$env$last.par.best <- obj$env$last.par;
obj$report() + TMB::sdreport(obj, par.fixed = opt$par)`).
Regression test bundled (`tests/testthat/test-multi-start-sdreport-consistency.R`,
17 expectations). Shipped as PR #116.

### 2. P1 API-surface alignment

Three follow-on docs/API PRs, all small:

- **P1a**: `profile_targets()` inventory + `confint(method =
  c("wald", "profile", "bootstrap"))` for fixed effects.
  Mirrors drmTMB's pattern (per PR #109 scan and the
  Explore-agent surface map). Closes the API mismatch
  between gllvmTMB's profile-likelihood machinery and the
  current Wald-only `confint()` surface.
- **P1b**: `README.md:23` and `README.md:291` softening from
  "ML / REML estimates" to "ML estimates" (matches NEWS.md
  which is already honest). Plus a Stable-core feature
  matrix in the README per the audit's recommendation.
- **P1c**: the external-audit-response doc + this
  `decisions.md` entry.

### 3. Partial reset of Phase 1c sequencing

Maintainer decision (via AskUserQuestion 2026-05-15
afternoon): the 6 in-flight docs PRs from earlier today
(#110-#115) keep flowing and merge as their CI clears.
After they land, **pause new Phase 1c article ports** and
pivot to P0 -> P1a/P1b/P1c -> Phase 1b validation
milestone. Resume Phase 1c article ports only after the
validation milestone closes (estimated ~3-7 days).

Items the audit raises that are explicitly deferred to
post-CRAN / Phase 6:

- C++ template modularization (audit says "becoming too
  large", not "currently broken").
- Storage controls (`keep_tmb_object = FALSE`); mirror
  drmTMB.
- Family-aware `simulate.gllvmTMB_multi()` rewrite (Phase
  5.5 will exercise; pre-CRAN scope item, but not in this
  replan).
- Family-aware `predict.gllvmTMB_multi()` (typed outputs
  for ordinal-probit / delta / mixed-family).
- Dense known-V threshold warning.

Random slopes (Phase 1c-slope in the original roadmap)
remain queued. The audit explicitly says: don't add until
P0 + P1 + Phase 1b validation milestone are stable. This
matches the existing roadmap order.

Cross-references:
- `docs/dev-log/audits/2026-05-15-external-audit-response.md`
  -- full triage.
- `docs/dev-log/audits/2026-05-15-drmtmb-cross-team-scan.md`
  (PR #109, merged) -- drmTMB `profile_targets()` reference
  pattern.
- Active plan:
  `/Users/z3437171/.claude/plans/please-have-a-robust-elephant.md`
  -- revised 2026-05-15 with the audit-driven section.

## 2026-05-15 (evening)  External audit #2 -- triage outcome

A second external audit landed on the evening of 2026-05-15
(*"Architectural Review and Strategic Evaluation of the drmTMB
and gllvmTMB Statistical Computing Frameworks"*). The audit
explicitly stated it did not have access to the source code,
so its "strategic recommendations" were back-inferred from
the lab's published track record + general TMB / GLLVM
theory.

The triage (in
`docs/dev-log/audits/2026-05-15-external-audit-2-response.md`)
found that ~9 of the audit's ~10 headline recommendations
describe features already in main: rotation-invariance
constraints via `glmmTMB::rr()`, known-variance support via
`meta_known_V()` + `block_V()`, identifiability diagnostics
via `check_identifiability()`, Laplace-breakdown diagnostics
via `gllvmTMB_check_consistency()`, coverage / bias via
`coverage_study()`, profile-curve interpretation via
`confint_inspect()`, robust multi-start (P0 fix bundled in
PR #122), pkgdown pedagogy with 13 articles in main, 3-OS CI.

Two items remain genuinely new and queued:

**A1 (deprioritised after maintainer review 2026-05-15
evening: "stay Laplacian")**: adaptive Gauss-Hermite
quadrature was the audit's prescription. On reflection
against the literature (Pinheiro & Chao 2006; Joe 2008;
Niku et al. 2017, 2019), AGHQ would be cosmetic at the
gllvmTMB user base's typical data shapes (20--50 items per
person, $d = 2$--$3$ for IRT; $n_\text{species} \ge 20$ per
site for JSDM). The Laplace approximation's bias rate
$O(1/n_i)$ puts the empirical discrepancy from MCMC
ground-truth within sampling noise on identifiable
parameters. The narrow regimes where AGHQ would actually
help -- short scales ($\le 10$ items), floor/ceiling
respondents, $d = 1$ unidimensional IRT, hyper-sparse JSDM
-- are not flagship gllvmTMB use cases.

**Resolution**: no engine implementation. Instead, a
single-paragraph pedagogy note in `psychometrics-irt.Rmd`
during the Phase 1e Rose+Darwin sweep:

> *"`gllvmTMB` uses the Laplace approximation. For typical
> IRT data ($\ge 15$ items per person, $d \le 3$), this is
> accurate to within sampling noise on identifiable
> parameters. For very short scales or fits flagged by
> `gllvmTMB_check_consistency()`, cross-check against
> `mirt` (with AGHQ) or a Bayesian fit."*

Present-day user protection comes via `gllvmTMB_check_consistency()`
(PR #121) which detects when Laplace fails on a specific fit.

**A3 (new, higher-priority post-CRAN integrator candidate)**:
variational approximation (VA) for high-$d$ binary JSDM. This
is the regime where Laplace genuinely degrades (5+ latent
factors, hyper-sparse rare-species detections) and AGHQ is
infeasible anyway (dimensionality curse: $K^d$ quadrature
points). The gllvm package's authors (Niku, Hui, Taskinen,
Warton 2017, 2019) chose VA over Laplace for exactly this
regime. If any post-CRAN integrator work is undertaken, VA
ranks above AGHQ. Still **not committed**; implement only if
the Phase 5.5 external validation sprint surfaces specific
user cases where Laplace clearly fails on high-$d$ JSDM.

**A2 (Phase 1e)**: single-paragraph addition to `pitfalls.Rmd`
(or `simulation-recovery.Rmd` Caveats) saying *"an inflated
$\boldsymbol{\Psi}$ diagonal is not automatically biological
heterogeneity -- supply `meta_known_V()` if you have known
sampling variances"*. Bundled into the Phase 1e Rose+Darwin
reframe sweep.

Both items are tracked in
`docs/dev-log/audits/2026-05-15-external-audit-2-response.md`
so they do not dissolve into chat.

The principle established here: when an audit doesn't read
the code, treat it as a confidence check that the published
record aligns with the actual package state -- not as a
punch list. Audit #1 produced a CRAN-blocking fix (the
multi-start `obj$report()` bug). Audit #2 produced two
queued items, neither blocking. Both filed for the record.

## 2026-05-16  Phase 0A infrastructure prep — function-first pivot + drmTMB-parity discipline upgrade

Decision: ratify the function-first pivot and the discipline
upgrade delivered in Phase 0A PR (`agent/phase0-infrastructure-prep`,
14 commits, ~50 files, zero R/ source touched).

Trigger: the 2026-05-15 article-port batch shipped articles
describing capabilities that were partially or aspirationally
implemented (mixed-family extractors; queued cross-package
comparators; hard-coded recovery numbers). The team had skipped
the drmTMB-style "machinery first, examples second" discipline.
Maintainer-led replan 2026-05-16 established Phase 0A as a
docs-only infrastructure PR before any further article work.

Ratified scope:

1. **Vision**: `gllvmTMB` is the user-first R package for
   multivariate latent-variable models in ecology / evolution /
   environmental sciences. Lab motto: transparent / reproducible
   / super easy to use / accessible / inclusive. The
   unparalleled-capability differentiator is mixed-family
   latent-scale correlations on **non-delta families**. Delta
   families deferred post-CRAN (two-scales problem).
2. **8 design docs as canon**: `00-vision.md` (refresh),
   `01-formula-grammar.md` (NEW), `02-family-registry.md`
   (NEW), `03-likelihoods.md` (NEW), `04-random-effects.md`
   (NEW), `05-testing-strategy.md` (NEW),
   `06-extractors-contract.md` (NEW),
   `35-validation-debt-register.md` (NEW). Plus
   `03-phylogenetic-gllvm.md` refresh and
   `11-task-allocation.md` PAUSED banner.
3. **Validation-debt register** with 102 honest rows
   (40 covered, 48 partial, 0 opt-in, 14 blocked). drmTMB
   Doc #34 template. This is the overpromise-preventer.
4. **AGENTS.md upgrade**: 6-item Definition of Done hard
   contract; scope-boundary statement template in Writing
   Style; Design Rules 1–5 cross-refs to the new design docs;
   Recovery Checkpoints section (drmTMB kit absorption); NEW
   Design Rule #10 — Convention-Change Cascade (function ↔
   help-file binding).
5. **`10-after-task-protocol.md` upgrade**: 6 gllvmTMB-specific
   stale-wording rg patterns; rg-patterns-verbatim recording
   rule; 3-rule tests-of-the-tests contract (failure-before-fix
   / boundary / feature-combination); paragraph-per-engaged-
   role team-learning depth rule; Convention-Change Cascade
   section; 10-section after-task report template; strengthened
   Closing Rule.
6. **README upgrade**: Stable-core feature matrix refreshed
   against the validation-debt register; vocabulary mapping
   (stable ⇔ covered, experimental ⇔ partial, planned ⇔
   blocked); register row-IDs cited; Current boundaries
   expanded with explicit "Removed in 0.2.0" and "Deferred to
   post-CRAN" subsections.
7. **Skills**: `after-task-audit` upgraded to 14-item Required
   Audit + 3-rule tests contract + gllvmTMB rg patterns;
   `rose-pre-publish-audit` fixed its own stale guidance (S/s
   → Ψ/ψ; gllvmTMB_wide REMOVED, not soft-deprecated;
   meta_known_V → meta_V) + added validation-debt /
   stable-core matrix / cascade-verification cross-checks; NEW
   `stop-checkpoint` skill (Shannon authors, Ada invokes).
8. **Convention decisions ratified in this PR**:
   - **Option A uniform-naming**: long-format `gllvmTMB()`
     calls always pass `trait`, `unit`, `unit_obs`, `cluster`
     explicitly. Wide-format (`traits()` LHS) does not take
     `trait =`.
   - **Option C variance-share framing**: `level = "phy"` and
     `level = "spatial"` are variance-share shortcuts on the
     unit-tier covariance, NOT peer grouping levels. Engine
     code unchanged; documentation matches real semantics.
   - **1-slope cap for M1 random slopes.** Higher slope counts
     are post-M1, contingent on validation evidence.
   - **`meta_known_V()` → `meta_V(value, V = V)` rename**;
     old name is a deprecated alias.
   - **`gllvmTMB_wide(Y, ...)` REMOVED in 0.2.0** per
     validation-debt register FG-16.
9. **Phase 0A / 0B / 0C sequencing**:
   - 0A (this PR): docs-only infrastructure.
   - 0B: empirical verification — walk every `claimed` row
     to `covered` or honestly downgrade. No new features.
   - 0C: transition cleanup (revert overpromise articles;
     rewrite ROADMAP; Phase 1b empirical coverage artefact).
10. **Persona-active naming** as first-class discipline: every
    design doc has a "Maintained by" header naming lead +
    reviewers; commit messages name the lead persona;
    after-task reports have per-persona contribution
    paragraphs for engine / article / scope PRs.

Rationale: drmTMB ships 3× more design docs and 3.7× more
after-task reports for 1/3 the R/ source files. They write more
about what they're doing than they write code. Phase 0A closes
that gap before any further machinery work.

Next: Phase 0B walks every `claimed` row to evidence; Phase 0C
cleans up overpromise articles; Phase 1 M1 Gaussian completeness
adds random slopes (capped at 1) and validates the full
extractor surface on Gaussian.

## 2026-06-21  Keep fixed-rho for the Design 65 coevolution kernel (no in-engine rho)

Decision: keep the cross-lineage bridge strength `rho` as a
fixed-at-construction, post-hoc-profiled scalar; do NOT add an
in-engine (TMB-estimated) `rho` parameter in the current arc. The
profile machinery -- `profile_cross_rho()` plus the merged
`profile_cross_rho_ci()` (a 1.92-drop chi-square(1) interval) --
already delivers the scientifically honest summary an estimated `rho`
would be reduced to anyway. Rationale, in priority order: (1)
identifiability is fragile, not absent -- `rho` and the cross-loading
magnitude trade off along a ridge broken only by the within-lineage
blocks and by tip/`W` replication, and a single shared association
matrix `W` is one replicate of the coevolution signal (Design 65
evidence base; Boettiger et al. 2012), so a free scalar on that signal
piles onto a near-flat ridge; (2) the profile is the same object
without the per-evaluation dense Cholesky cost, `tanh`-boundary
pile-up, sign aliasing, or cross-package (drmTMB) likelihood/API
divergence an in-engine parameter would introduce; (3) sequencing --
Design 65 C3.3 lists simpler gaps (moderate/high-overlap recovery,
reusable null thresholds, interval coverage, module uncertainty) that
should land before turning `rho` into a parameter. If estimation is
revisited, the zero-engine first step is the pure-R outer-optimiser
identifiability simulation in the design note section 4 step 1 --
promote to C++ only if it shows a usable interior maximum with finite
curvature in the realistic-design regime. Full analysis:
`docs/dev-log/2026-06-20-coevolution-in-engine-rho-design.md`
(design-note-only PR #507). Closes the parked in-engine-`rho`
decision.

## 2026-07-12  Deprecated covariance functions leave the active teaching model

Decision: the reader-facing covariance grammar teaches four modes only:
Scalar, Independent, Dependent, and Latent. `unique()` and the source-specific
`*_unique()` functions are deprecated compatibility functions, not a fifth
mode. Remove them from overview grids, articles, ordinary help topics,
examples, and navigation prose. Keep them only in the dedicated deprecated
function reference set, the release-note deprecation entry, and the minimum
internal design, test, and historical records required to maintain old
formulas. The current `unique = TRUE/FALSE` argument on `latent()` helpers is a
separate interface and remains documented.

General rule: a central API deprecation is not complete merely because its
replacement exists. Completion requires changing the package's teaching model,
centralising migration guidance, and maintaining a regression scan that rejects
the deprecated spelling outside explicitly allowed compatibility paths.

## 2026-07-12  Keep the applied phylogenetic article latent-focused

Decision: the applied phylogenetic covariance article teaches the
`phylo_latent(..., unique = TRUE)` decomposition. Its primary examples and
interpretation expose the shared `Lambda Lambda^T` component, the phylogenetic
diagonal `Psi` companion, and their total, with long and `traits(...)` wide
forms aligned. `phylo_dep()` and `phylo_indep()` remain current API choices but
belong in the formula/reference guide or a separate article rather than
dominating this applied page. The same latent-plus-diagonal framing applies to
the page's comparison of phylogenetic and non-phylogenetic species covariance.

Rationale: the article's purpose is interpretable latent covariance and its
reader-facing limits, not an undifferentiated catalogue of covariance modes.

## 2026-07-12  Renew generated pages as part of every documentation change

Decision: a documentation change is incomplete until the affected generated
pkgdown HTML is rebuilt and checked against its source. Rmd/README correctness
alone is not evidence that readers see the current page; generated pages,
navigation, search, sitemap, and examples can age independently. Whenever one
stale page is found, sweep the neighbouring affected estate for the same
source/render drift, stale internal codes, hidden warnings, and old API
examples. Record the source/render synchronization evidence in the check log.

Rationale: the profile-likelihood page exposed an old rendered scope block even
after its source had been rewritten. The served artefact, not the editor's
source file, is the reader's contract.

## 2026-07-28  AGHQ becomes the main integration engine — reversing "stay Laplacian"

Decision (maintainer): adaptive Gauss-Hermite quadrature becomes gllvmTMB's main
integration engine, implemented across all 16 families and all model classes, adaptive
and auto-by-default. Laplace is retained only where it is mathematically required, and
never as a silent fallback. This **reverses** the 2026-05-15 evening decision recorded
in this log at "A1 (deprioritised … 'stay Laplacian')" and in
`docs/dev-log/audits/2026-05-15-external-audit-2-response.md:60-66`.

The 2026-05-15 grounds were literature-based and remain sound on their own terms.
Pinheiro & Chao (2006, JCGS) measured the AGHQ gain falling from 5-15% on variance
components at d=1 with ~5 observations per cluster, to 2-5% at d=2 with 20, to
three-decimal agreement with Laplace at d=3 with >= 30. Joe (2008) puts Laplace's GLMM
bias at O(1/n_i). On that evidence AGHQ was judged "theoretically correct but practically
low-impact at the gllvmTMB user base's typical data shapes".

What changed. (1) The simulation campaign's 70 degenerate bernoulli fits — 59 of them
reporting `convergence == 0` and `pdHess == TRUE` — are real and remain unexplained after
four hypotheses. (2) The variational route was built, measured, and frozen; its coverage
was the deciding argument against it. (3) AGHQ was measured to move attenuation
0.9215 -> 1.0438 at q=2, clearing a kill rule written before the run. (4) Decisively,
**the literature's `n_i` is observations per cluster, which in this package is TRAITS PER
SITE, not the number of sites.** The 2026-05-15 reading treated the gain as uniformly
small; it is not — it is large exactly where `T` is small. That is a design input for the
`aghq = "auto"` rule, not a veto, and it is the specific misreading this reversal corrects.

Rationale for recording the reversal explicitly rather than superseding silently: the
earlier decision was correct on its evidence, and a future reader who finds only the new
entry would be unable to tell whether the old one was overturned or overlooked.

## 2026-07-28  The AGHQ coverage claim, stated in its honest narrower form

Decision: the sentence that justified redirecting this project from VA to AGHQ — "AGHQ is
a refinement layer on the Laplace objective, so it inherits all 16 families, phylogeny,
spatial and missing data" — is **not established as stated** and must not be advertised in
that form. Adversarial testing against the source returned: family-agnosticism SURVIVES
(all 16 families reach the latent only through the scalar `eta_o` in one lambda,
`src/gllvmTMB.cpp:1994`, single call site `:2363`; the hurdle families branch on observed
`y`, not on the latent, so they are not mixtures in the integration variable); missing data
SURVIVES; **dimension and phylogeny/spatial BREAK** under a product rule, because those
priors couple every species or mesh node into one block.

The honest form, which is what may be claimed: *AGHQ inherits gllvmTMB's full family
surface — all 16 — and missing data. It does not inherit phylogenetic, spatial or kernel
structure under a product rule; those require a nested AGHQ-inside-Laplace decomposition,
and `REML = TRUE` is excluded outright because `b_fix` enters the random vector with no
prior term.*

Rationale: the redirection away from VA was argued on coverage, and VA was faulted
specifically for rejecting structured models. AGHQ's family coverage is genuinely better
(16 of 16 against 4 of 16); its structural coverage under a product rule is not better.
This is not an argument to unfreeze VA. It is that the comparison was scored on a premise
nobody had checked, and the plan that follows from it must be scoped to what is true.

## 2026-07-28  H4 — the 59/70 degeneracy may be an artefact of one-node Laplace

Decision: record, as an untested hypothesis with a named source, that the campaign's
degenerate fits may be caused by the Laplace approximation itself rather than by the data
or the optimiser. Rabe-Hesketh, Skrondal & Pickles (2002), held in the engineering
notebook, state that a single quadrature point **is** the first-order Laplace
approximation, and that a single point "can make the log-likelihood flat with respect to
the covariance parameters and drive predicted posterior SDs to zero."

That is a description of the observed defect: flat likelihood in the covariance
parameters, collapsed variance components, and `convergence == 0` because the optimiser
genuinely reached a stationary point on a flat surface. Three earlier hypotheses (the
relative-collapse diagnostic, the Lambda_B eigen-spectrum, and ordinary marginal
separation) are dead; this one is literature-predicted and untested.

It is tested as AGHQ's first acceptance test, with matched healthy controls and a kill
rule registered before the run: AGHQ resolves the 59/70 only if, at k=9, the degenerate
group's median `rel_frob` falls below 10 while the matched healthy controls are unchanged
within MCSE. The pre-registration exists because all three previous hypotheses died by
behaving identically on healthy cells.

Consequence if H4 holds: Arc 0 and the AGHQ programme are the same problem, and the
deliverable is an estimator improvement rather than an identifiability warning.

## 2026-07-28  AGHQ ships opt-in; Laplace stays the default until evidence decides

Decision (maintainer, in response to the plan's one flagged gate): **do not flip the
default.** AGHQ is built as an opt-in integration route, tested head-to-head against
Laplace under the pre-registered kill rule, and the decision to make it the default is
taken separately, with the comparison in hand. Until then `gllvmTMB()` behaves exactly
as it does today and no existing user's numbers move.

Rationale: flipping the default changes the numbers every user gets while touching no
export and no NAMESPACE, so it is invisible to `R CMD check` — a larger behavioural
change than a normal API change, not a smaller one, and it would land against a package
heading for its first CRAN release at 0.6.0. Building opt-in first also means a family
that fails its kill rule simply never gets promoted, instead of leaving the default
pointing at an unvalidated route.

Practical consequence for the build: `aghq = "auto"` is implemented and tested, but
`"auto"` is not yet the value of the formal argument's default. The flip, when
authorised, is a one-line change plus the evidence that justifies it.

## 2026-07-28  What "AGHQ for structured models" can and cannot mean

Decision: record the distinction, because "AGHQ supports phylogenetic models" is true
under one reading and false under another, and the false reading is the natural one.

**Quadrature over the structured field itself is out of reach.** Under `phylo_*`,
`animal_*`, `spatial_*`, `kernel_*` and `propto()`, the prior couples every species or
mesh node into a single block: `g_phy` is one connected block over the augmented tree,
`omega_spde` is a joint GMRF with treewidth O(sqrt(n_mesh)), and `propto`/`kernel_*` are
dense. A product rule would need k^(large) nodes. This is combinatorial impossibility,
not expense, and no fence tweak changes it.

**Quadrature over the per-site block, nested inside a Laplace over the field, is
reachable.** Conditional on the structured field, sites are independent again, so the
marginal factorises as an outer Laplace over the field wrapping an inner per-site
quadrature. The structured field stays in TMB's `random=` exactly as today; only the
ordinary per-site latent block is quadratured. This is the INLA decomposition and it is
the same template code path as the unstructured case — Stage 1 is simply the special case
where `random=` is empty.

**The honest limit, to be stated in user-facing text.** The gain requires the model to
*have* a per-site latent tier to refine. `latent(1 | site, d = q) + phylo_latent(...)`
benefits on its ordinary tier. A phylo-only or spatial-only model, where all latent
structure lives on the field, has no per-site block and AGHQ does nothing for it. Such a
model must be told so plainly rather than silently accepting an `aghq` argument that
changes nothing.

UNVERIFIED at the time of this entry: whether the outer Laplace converges reliably when
its inner likelihood is a quadrature sum rather than a plug-in density. That is the
gating validation for the structured stage and it is not assumed.

## 2026-07-28  What AGHQ actually buys — a correct likelihood, not a better point estimate

Decision: state the deliverable precisely, and record it BEFORE the multi-seed campaign
returns, so that campaign is read against a stated expectation rather than an adjustable
one.

The evidence (`dev/aghq-evidence/`, both tests against a `stats::integrate()` oracle on
models small enough to integrate exactly). In the regime the literature identifies as
Laplace's worst — few observations per cluster, which in this package is TRAITS PER
SITE `T`, not the number of sites, with strong loadings — at `T = 2`, `n = 80`:

| | objective error vs oracle | ‖Λ‖ |
|---|---|---|
| Laplace | **+1.0340 nll** | 1.592 |
| AGHQ k=9 | +2.1e-04 | 2.164 |
| AGHQ k=25 | **+1.2e-09** | 2.155 |
| truth | — | **0.962** |

**AGHQ is near-exact at integration.** It is not worse at its job; it is almost perfect
at it, and the template's objective matches the oracle at every `k` tested. But the TRUE
MLE is itself biased upward in this regime, and Laplace's approximation error happens to
shrink in the opposite direction — so the *worse integrator produced the better point
estimate, by accident*. Laplace's wrongness is acting as shrinkage, and shrinkage lowers
error when an estimate is noisy.

**Therefore, what may be claimed:** AGHQ delivers a correct likelihood. Likelihood-ratio
tests, AIC/BIC, profile intervals and standard errors all rest on the likelihood being
right, and a Laplace objective wrong by 1.03 nll units makes every one of them quietly
wrong. That is the deliverable.

**What may NOT be claimed:** that AGHQ automatically improves point recovery at small
`n`. Which engine wins on recovery is a bias-variance question, it cannot be settled on
a single dataset, and it may well go Laplace's way in some regimes. Any promotion of a
family or model class must be scored on the pre-registered `|attenuation − 1|` rule over
at least 8 seeds, never on a favourable single cell.

Corollary for the `aghq = "auto"` rule: "auto" should not be sold as "more accurate
estimates". It should route on where the LIKELIHOOD is unreliable — small `T`, strong
latent signal — which is exactly where the literature and this measurement agree.

Recorded also: at `T = 3` with strong signal both engines land at ‖Λ‖ = 47.8 against a
true 3.15. In that runaway regime the integrator is not the problem, and neither engine
should be credited or blamed for it.

## 2026-07-28  AGHQ is ONE of two levers, and it is the smaller one

Decision: record, before the 16-family campaign runs, that AGHQ alone cannot reach
nominal variance-component recovery, and that no node count will get it there. This is
not a projection — it is measured, in a sister repo, and it was already in the brain.

Source: `memory/Two-lever fix for small-cluster non-Gaussian variance-component bias
(AGHQ + Cox-Reid REML) — cross-repo map.md` (2026-07-18; origin drmTMB
`cumulative_logit`, 40 seeds, validated against glmmTMB / glmer / lme4 oracles).

**The bias has two stacked, ORTHOGONAL components.**

1. **Laplace integral error** — the one-point-at-the-mode approximation to the marginal.
   Fixed by AGHQ. Shrinks with observations PER CLUSTER, which in this package is traits
   per site `T`.
2. **ML finite-cluster variance-component bias** — present even under EXACT integration.
   Fixed only by a restricted likelihood: exact REML for Gaussian, or the **Cox-Reid
   adjusted profile likelihood** for non-Gaussian (integrate the fixed effects out under
   a flat prior, subtract ½·log|I_ββ|). Shrinks with the NUMBER of clusters.

Measured, M=40, n_each=15, true slope-SD 0.5:

```
Laplace         -7.3%
  + AGHQ        -5.0%   (integral lever, +2.3 pt)
  + Cox-Reid    -0.9%   (variance lever, +4.0 pt)  -> nominal
```

**Cox-Reid is the bigger lever, about 1.7x.** And the decisive line: the AGHQ node sweep
converges by nq ≈ 5 and then **plateaus dead flat at −5.0% — nodes cannot cross the
variance-bias floor; only Cox-Reid drops it.** A node ladder that appears to converge is
therefore not evidence that the remaining gap is closable by more nodes.

**Consequences for this plan, adopted:**

* The deliverable claim stays as recorded earlier — AGHQ buys a CORRECT LIKELIHOOD — and
  must NOT be extended to "AGHQ reaches nominal recovery". It does not, alone.
* The 16-family kill rule remains as pre-registered, but a family failing it is now
  ambiguous between "the quadrature is inadequate" and "the ML variance bias dominates".
  The campaign must therefore report the node-ladder plateau per family, since a flat
  plateau is the signature that the residual gap is the OTHER lever.
* `gllvmTMB`'s `reml_bridge` **aborts for non-Gaussian** (`R/reml-bridge.R:106`,
  "Gaussian-only"), so the second lever does not exist here yet. Building it is a
  separate arc and is NOT in scope today.
* The GLLVM shape of that lever is not drmTMB's. Latent variables are fixed `N(0, I)` and
  the variance lives in the loadings `Lambda` and `Psi`, not in a scalar random-effect
  SD, so a Cox-Reid adjustment here is a multi-dimensional-latent build rather than the
  scalar probe drmTMB could run.

Recorded because the alternative was to run a 16-family campaign, watch families miss the
kill rule, and diagnose the quadrature — when the measured cause may be a lever we have
not built.

## 2026-07-28  The routing surface is (T, M, family) — and the campaign measures levers, not pass/fail

Decision: redefine what the 16-family evidence campaign produces, before it runs on the
earlier design.

**Why the earlier framing was wrong.** The campaign was scoped as "does AGHQ pass its
kill rule for family X". But AGHQ works for every family BY CONSTRUCTION — there is one
`obs_loglik` call site (`src/gllvmTMB.cpp:1994`, single use at `:2363`) and no
per-family quadrature code exists or will be written. Pass/fail is therefore close to
vacuous; what actually varies between families is **how much each lever buys**.

**The two levers have different arguments, so the routing surface is three-dimensional.**

* AGHQ corrects the Laplace **integral error**, which shrinks with `T` (observations per
  cluster = traits per site) and grows with how NON-QUADRATIC the conditional
  log-likelihood is.
* Cox-Reid corrects the ML **finite-cluster variance bias**, which shrinks with `M`
  (number of clusters = sites) and is largely a degrees-of-freedom effect, so much more
  family-agnostic.

| | few sites (M small) | many sites (M large) |
|---|---|---|
| few traits/site (T small) | **both levers** | **AGHQ only** |
| many traits/site (T large) | **Cox-Reid only** | **neither** — plain Laplace ML is adequate |

`T` and `M` are both known BEFORE fitting, so `aghq = "auto"` can route with no extra
computation and every choice is explainable to a user in one sentence.

**The family axis, with its anchor already measured.**

| family | expected AGHQ lever | reason |
|---|---|---|
| gaussian | **exactly zero** | Laplace is exact; measured −9.9e-10, identical at k = 3 and k = 9 |
| binary / bernoulli | largest | one bit per observation, strongly non-quadratic |
| poisson / nbinom | mean-dependent | low counts behave like binary, high counts near-Gaussian on the log scale |
| Gamma / beta | intermediate | continuous but skewed |
| ordinal / tweedie / delta-hurdle | unknown, possibly large | sharp boundaries and mixture structure |

**Consequences adopted.**

1. The campaign reports a **lever-size table** — the change in `|attenuation − 1|` from
   adding AGHQ, and from adding Cox-Reid — not a pass/fail column. The kill rule still
   applies to any promotion, but the deliverable is the map.
2. The gaussian row is the campaign's own positive control: if AGHQ's measured lever is
   NOT ~zero there, the harness is wrong, not the family.
3. An open design question, recorded rather than assumed: families with dispersion
   parameters (`phi` for nbinom/beta/Gamma, `p` for tweedie, cutpoints for ordinal)
   carry EXTRA estimated nuisance parameters, so a correct Cox-Reid adjustment for them
   should plausibly integrate those out too, not only `b_fix`. Unresolved.
4. Sweeps must cross `T` as well as `n`. An earlier ladder held `T = 4` fixed, which
   walks a single row of the table above and would have calibrated `auto`'s thresholds
   on one cell.

## 2026-07-28  The fair four-arm comparison — and a correction to my own claim

Decision: record the comparison against a FAIRLY PENALISED Laplace, and retract the
claim made before it was run.

**The claim I made:** "AGHQ + ridge recovers sigma and rho better than Laplace at every
sample size tested." That was measured against UNPENALISED Laplace, which is not the
right control: if the ridge is doing the work, the gain is not attributable to the
quadrature. The control was already in the same 954-fit dataset and I did not report it.

**All four arms, p = 6 traits, q = 2 latent, 30 seeds/cell — |sigma - 1| / rho error,
smaller better in both:**

```
     n | Laplace+none   Laplace+ridge  AGHQ+none      AGHQ+ridge
   100 | 0.175 / 0.310  0.053 / 0.223  0.197 / 0.233  0.043 / 0.230
   200 | 0.191 / 0.305  0.140 / 0.204  0.063 / 0.224  0.040 / 0.225
   400 | 0.149 / 0.155  0.105 / 0.130  0.070 / 0.121  0.054 / 0.120
  1600 | 0.118 / 0.087  0.138 / 0.091  0.012 / 0.075  0.011 / 0.062
```

**What survives:** AGHQ + ridge wins **sigma at every n**.

**What does NOT survive:** the rho half. Against a penalised Laplace, **Laplace + ridge
is marginally better on rho at n = 100 and n = 200** (0.223 vs 0.230; 0.204 vs 0.225).
AGHQ only leads on rho from n = 400 upward. The sentence "better on both at every n" is
false and must not be used.

**The attribution, which is the useful finding.** The two components fix DIFFERENT
regimes, and that is why they compose rather than duplicate:

* **The ridge dominates at small n.** It takes Laplace from 0.175 to 0.053 at n = 100 --
  a larger improvement than the same penalty gives AGHQ. It is treating the flat-ridge
  runaway, which is a small-n phenomenon.
* **The quadrature dominates at large n.** At n = 1600, AGHQ + ridge reaches 0.011
  against Laplace + ridge's 0.138 -- a **12x** difference that no penalty can produce,
  because it removes the O(1/T) integral bias, which does not shrink with n at all.

Neither alone is sufficient. That is a coherent design story and it is better than the
one I told, but it is NOT the story I told, and the difference matters for what may be
advertised.

**Consequence for the claim.** The defensible sentence is: *AGHQ corrects an integral
error that no amount of data removes; a weakly-informative ridge on the loadings removes
a small-sample runaway that no amount of quadrature removes. Together they give the best
latent-SD recovery at every sample size tested, and the best correlation recovery from
moderate n upward.* Anything stronger is not supported.

## 2026-07-28  Correction to the correction — the claim was fine; only the attribution needed care

Decision: the previous entry withdrew more than the evidence required. Restoring the
claim, with the comparator named.

**The claim IS true against the comparator that matters.** gllvmTMB ships UNPENALISED
Laplace; that is what every user gets today, and `Laplace + ridge` is not a route anyone
can currently run — not in this package and not in `gllvm`. Against the shipped default,
p = 6, q = 2, 30 seeds/cell, |sigma - 1| / rho error:

```
     n | Laplace (as shipped) | AGHQ + ridge
   100 |    0.175 / 0.310     | 0.043 / 0.230
   200 |    0.191 / 0.305     | 0.040 / 0.225
   400 |    0.149 / 0.155     | 0.054 / 0.120
  1600 |    0.118 / 0.087     | 0.011 / 0.062
```

Four of four on sigma, four of four on rho. **"AGHQ + ridge beats Laplace at every n on
both sigma and rho" is a good and defensible statement**, provided the comparator is
stated as the shipped Laplace default.

**What the Laplace + ridge arm actually changes is ATTRIBUTION, not truth.** It shows
that much of the small-n gain comes from the penalty rather than the quadrature, and
that a hypothetical penalised Laplace would edge rho at n <= 200. That is a methods
point — which component does what — and it belongs in the discussion of the design, not
in the user-facing claim.

The previous entry conflated the two and withdrew a true statement. Recorded because
OVER-correction is its own failure mode: it destroys defensible results and makes the
record less accurate, not more. The discipline is to name the comparator, not to
abandon the comparison.

## 2026-07-28  D-43 lens 3 returns NOT-DONE — the claim is withdrawn to its defensible form

Decision: honour the panel. The load-bearing reviewer's verdict is accepted in full and the
2026-07-28 "restore the claim" entry above is **superseded**.

**The reviewer's central point, which I concede.** I restored "beats Laplace at every n on
both sigma and rho" on the ground that `Laplace + ridge` "is not a route anyone can
currently run". But **that coupling is one I created**, in ~12 lines of `run_one` — the
ridge is applied only on the AGHQ path by my own choice. Defending a claim by appealing to
a restriction I authored is self-serving, and the control is legitimate.

**Findings that stand against the claim:**

* Paired on shared seeds, the QUADRATURE's contribution to rho is **indistinguishable from
  zero at n = 100, 200 and 400**, and points the wrong way at n = 100 on both metrics.
* **The ridge alone takes runaways to 0% exactly as well as AGHQ + ridge does.**
* **AGHQ without the ridge is WORSE than Laplace on runaways in the p = 4 shape.**
* **The sigma metric is anti-correlated with the failure it is meant to summarise**
  (r = −0.21): diverged fits at ‖Λ̂‖/‖Λ‖ ≈ 16 score sigma = 0.80 while healthy fits score
  0.92, so a substantial part of the advertised n = 100 effect is contamination. This is a
  defect in my summary statistic, not in the engine.
* **tau = 2 was adopted AFTER tau = 1 was measured**, and sits on a monotone sensitivity
  curve spanning 1.45–0.74 that was never run at a true loading scale other than the one
  matching the prior. The "chosen a priori" defence is weaker than I stated.
* **A real defect, not just a claim problem:** with the ridge on, the shipped configuration
  returns a MAP point with ML curvature — `logLik` sits off its own maximum and the gradient
  diagnostic cannot converge. That must be fixed or fenced before anything is advertised.

**The claim is withdrawn to:** *AGHQ corrects an integral error that no amount of data
removes — measured as a flat ~21% downward bias in Laplace that 16x more data does not
touch, and an AGHQ ratio of 1.0021 at n = 3200. A weakly-informative ridge on the loadings
removes a small-sample runaway. Their separate and joint contributions to sigma and rho at
small n are NOT yet cleanly attributed, and no coverage evidence exists for the shipped
configuration.* "At every sample size" is dropped. The comparator is named.

**The one measurement that would settle it**, per the reviewer: a 30-seed coverage cell for
the ACTUALLY SHIPPED configuration — AGHQ k = 9 **with** `aghq_ridge = 2`, p = 6, q = 2, at
n = 400 and n = 1600 — reporting Wald coverage of the Sigma diagonal and off-diagonal
against nominal 0.95 with MCSE, alongside the equivalent Laplace + ridge cell. One script,
one Totoro run. It adjudicates the MAP-point/ML-curvature problem and it is what this
project actually gates on.

Recorded because a panel that is overruled is not a panel. Two NOT-DONE verdicts withhold
the claim entirely; one is already in.

## 2026-07-28  D-43: TWO NOT-DONE verdicts — the capability claim is WITHHELD

Decision: the AGHQ capability claim is **withheld**. Lens 2 (scope) and lens 3 (method)
both returned NOT-DONE. Under D-43, two NOT-DONE verdicts withhold the claim entirely,
and the panel is not overruled.

Nothing about the *code* is retracted by this. The engine is built, the Laplace default is
untouched, and the correctness evidence (Gaussian exactness at ~1e-13 and k-independent;
agreement with a brute-force integrate() oracle to 1.2e-09) stands. What is withheld is the
CLAIM — specifically any statement that AGHQ improves recovery of sigma or rho.

**The three things the next lane must clear, in order:**

1. **A real defect, not a claim problem.** With the ridge on, the shipped configuration
   returns a MAP point with ML curvature: `logLik` sits off its own maximum and the gradient
   diagnostic cannot converge. Fix or fence it before anything is advertised. This is the
   only item that also blocks a merge.
2. **The adjudicating measurement.** A 30-seed coverage cell for the ACTUALLY SHIPPED
   configuration — AGHQ k = 9 **with** `aghq_ridge = 2`, p = 6, q = 2, at n = 400 and
   n = 1600 — reporting Wald coverage of the Sigma diagonal and off-diagonal against nominal
   0.95 with MCSE, alongside the equivalent Laplace + ridge cell. One script, one Totoro run.
3. **The correctness evidence is not automated.** Lens 2 notes it exists only as manually
   run scripts under `dev/aghq-evidence/`; the golden-accuracy assertions do not run in the
   suite. Evidence that only a human can reproduce is not evidence a package can rely on.

Recorded so that a later session cannot mistake "the engine works" for "the claim passed".

## 2026-07-28  D-43: THREE of three NOT-DONE — and two findings the author did not have

Decision: all three lenses returned NOT-DONE. Recording the two findings that were NOT in
the earlier withhold, because both are more serious than what was recorded, and one makes a
statement I put in the PR body and told the maintainer **false**.

**FINDING 1 (lens 1) — the headline evidence does not exercise the shipped code.**
Of the 16 scripts in `dev/aghq-evidence/`, only the two toy-scale ones (n <= 30) call the
real `gllvmTMB()`. **Every** multi-seed and large-n script — including the 954-fit Totoro
suite and the n = 3200 descent that produce *every* sigma, rho and runaway number in the
claim — sources `dev/aghq-r-reference.R`, a standalone R re-implementation whose own header
says it "is NOT a shipping route and must never become one". The link between that reference
and the real engine is validated only at n = 3–30.

This is not a small caveat. The reference was built deliberately as an INDEPENDENT ORACLE
and it did its job; but independence from the engine is exactly what disqualifies it as
evidence ABOUT the engine at scale. Lens 1 hand-ran one real-engine cell at the suite's own
DGP (n = 100, p = 6, q = 2): Laplace frob_rat 11.4 -> AGHQ+ridge 1.10, rho 0.507 -> 0.192.
Directionally reassuring, and n = 1.

**FINDING 2 (lens 2) — "no existing user's results move" is FALSE as stated.** The default
is unchanged and the quadrature is properly gated, but the same branch carries two
UNCONDITIONAL changes to shared likelihood code: a pinned-trait constant-offset fix, which
**moves `logLik`/AIC for existing default-engine models with pinned traits**, and an
`ordinal_probit` rewrite (machine-precision only, verified numerically). I asserted the
stronger sentence in the PR body and in chat. It is withdrawn.

**FINDING 3 (lens 2) — the golden accuracy tests all silently SKIP.** All three
accuracy-proving tests in `test-aghq-golden.R` self-skip, and the mechanism is a genuine
bug: the gating smoke probe runs at k = 1, but k = 1 is DEFINED to route to the plain-Laplace
branch (`aghq$used = FALSE` by design), so the probe can never observe `used = TRUE` and the
tests can never run. **"Validated" therefore has zero automated regression protection** — the
5/0 I reported was five passing tests plus three that never executed.

**FINDING 4 (lens 2) — the second shape was never reported.** `totoro-suite-inc.csv` holds
480 fits at p = 4, q = 1 — the authors' own script calls it "where the runaway was worst" —
and every `decisions.md` analysis covers only p = 6, q = 2. In that shape AGHQ+ridge runaway
is **3.3%, not 0%**, so "eliminates the divergent-fit mode" is wrong.

**FINDING 5 (lens 3) — an error cancellation inside the shipped default.** Laplace+ridge at
n = 1600 is |sigma-1| = 0.138 against plain Laplace's 0.118: the ridge COSTS where no
divergence confound is present. AGHQ+ridge shows no such cost because AGHQ's upward bias and
the ridge's shrinkage CANCEL. That is an undiagnosed error-cancellation mechanism inside the
shipped configuration — recorded one session after this same lane retracted an
error-cancellation story about Laplace.

**FINDING 6 (lens 3) — ridge-on fits can never pass the gradient check.** At the ridge
optimum the honest gradient is lambda/4 ~ 0.25 against `grad_tol = 1e-4`.

**Consequence.** The claim stays withheld. The merge stays blocked. The PR body must be
corrected on "no existing user's results move" before anyone reads it as a guarantee.

## 2026-07-28  ⚠️ EARLY SIGNAL: the shipped AGHQ arm may NOT reproduce the reference

Recorded mid-run, on THREE fits, precisely because it is the pre-registered failure
condition and must not be lost if the session ends first.

`dev/aghq-evidence/18-shipped-engine-campaign.R` re-runs the campaign through the real
`gllvmTMB()` rather than `dev/aghq-r-reference.R`, after a D-43 lens found that only 2 of
16 evidence scripts exercise the shipped engine. Partial, 33 of 90 fits:

```
     n  arm          nfit    sigma   rho|e|    frob   runaway%
   100  laplace        15    1.011    0.293   1.458      47%
   100  aghq (no ridge) 3    1.090    0.200  29.700     100%
  1600  laplace        15    0.868    0.103   0.807       7%
```

**The Laplace arm reproduces the reference well** — 0.868 at n = 1600 against the
reference's 0.882; 47% runaway at n = 100 against 50%. That is reassuring for the
reference's fidelity on that arm.

**The AGHQ arm does NOT, on the evidence so far.** The reference put unpenalised AGHQ at
**13% runaway** at n = 100; the shipped engine is showing **100% on 3 fits**, with a median
`frob_rat` of 29.7. If that survives more seeds, the reference does not represent the
engine on the arm that carries the claim, and **every AGHQ number derived from it must be
withdrawn** — which is exactly the outcome the pre-registration named as more important
than a confirmation.

**Do not over-read three fits.** It may be chance; the `aghq_ridge` arm — the shipped
default, and the one that actually matters — had not reported at all when this was written.
But the direction is recorded now, unhedged, so that a later session cannot quietly inherit
the reference-based numbers without checking this first.

**Next session: read `dev/aghq-evidence/18-shipped-inc.csv` BEFORE citing any AGHQ figure
from the reference campaigns.**

## 2026-07-28  The wide factorial: Laplace's bias is O(1/T) and BINARY-SPECIFIC — and poisson is the correctness control we did not have

Decision: record, from 7550 fits through the SHIPPED engine on Totoro, the three findings
that together scope what AGHQ is for. This supersedes every AGHQ comparative number
derived from `dev/aghq-r-reference.R`, which D-43 lens 1 showed is not a valid model of
the engine (the reference reproduces the shipped LAPLACE arm but not the shipped AGHQ arm).

**1. Laplace's bias obeys O(1/T) in traits per site, and is invisible in n.** Binomial,
q=1, lam_sd=1, n=1600, median `||Lambda_hat||/||Lambda||`:

```
   T =      2       4       6      12
 Laplace  0.653   0.824   0.887   0.962      bias = 0.347 / 0.176 / 0.113 / 0.038
```

The bias halves as T doubles. This is the mechanism, measured: it is an approximation
error in EACH SITE's integral, so adding sites adds clusters each carrying the same error
and it never averages away. **Laplace is consistent for the WRONG value** — more data makes
it more precisely wrong. That resolves the apparent paradox that Laplace looks "more
biased" at n=1600 (0.798) than n=100 (0.924): at small n the constant downward error is
masked by noise and by an opposing upward small-sample effect; as n grows the noise clears
and the systematic error is revealed underneath. It does not grow; it is exposed.

**2. The bias is BINARY-SPECIFIC. Poisson has none, at any T.**

```
   T =      2       4       6      12
 poisson  1.006   1.006   0.995   0.997     AGHQ correction: +0.006 -0.002 0.000 0.000
```

A Bernoulli carries at most one bit and its conditional log-likelihood is far from
quadratic in eta; a poisson with reasonable counts is nearly Gaussian, and Laplace is exact
for a Gaussian integrand. So AGHQ's entire measured value proposition applies to binomial,
NOT to poisson. Any claim of the form "AGHQ corrects an integral error in gllvmTMB" must
name the family.

**3. Poisson is a LIVE null control, and it is stronger evidence than Gaussian exactness.**
`aghq_used` is TRUE on 100% of poisson AGHQ fits — the quadrature is fully active on a
genuinely non-Gaussian integrand at k=9 — and it independently concludes there is nothing
to correct, to three decimals, at all four T. Gaussian exactness cannot do this: a gaussian
integrand IS the GH kernel after adaptation, so any correctly-normalised rule reproduces it
and AGHQ is effectively inactive. This is the non-Gaussian check lens 1 recorded as
missing, and it is now satisfied by a control that arrived unplanned.

**Why AGHQ is sometimes WORSE, stated so it is not re-litigated.** Two errors of opposite
sign. The true MLE of `||Lambda||` is biased UP at small n (the flat likelihood direction
lets the optimiser drift); Laplace's integral error biases DOWN by O(1/T). At small n they
partially cancel, so LAPLACE IS RIGHT BY ACCIDENT. AGHQ removes the downward error and
exposes the upward MLE bias in full. This is not a quadrature defect and it is exactly why
the recorded deliverable is "a correct LIKELIHOOD", never "a better point estimate".

**The ridge's job is RUNAWAY PREVENTION, not shrinkage to truth — refuting our own
prediction.** Pre-registered: the ridge would HURT where its prior is mis-specified. It does
the opposite. Binomial, T=4, q=1, median |frob-1|:

```
  lam_sd = 0.5 : laplace 0.717 -> +ridge 0.613   HELPS
  lam_sd = 1.0 : laplace 0.109 -> +ridge 0.156   hurts slightly
  lam_sd = 3.0 : laplace 5.418 -> +ridge 0.227   HELPS ENORMOUSLY
```

At lam_sd = 3 the unpenalised fit DIVERGES, and a badly-specified prior still beats
divergence. So the ridge is not competing with the truth, it is competing with a runaway.

**The routing map this licenses** (and `aghq = "auto"` should route on THIS, not on keywords):

| regime | route |
|---|---|
| poisson, any T, any n | Laplace — AGHQ buys 0.000 |
| binomial, T small (<= 4), large n | AGHQ + ridge — the O(1/T) error is large and real |
| binomial, T large (12) | Laplace nearly adequate (4% bias) |
| binomial, small n | the RIDGE is the lever; AGHQ ALONE IS HARMFUL (runaway 47% -> 73%) |
| strong signal / weak identification | ridge essential regardless of engine |

**Scope, stated rather than implied.** 2 families of 16 (binomial-logit, poisson-log);
q in {1,2}; T in {2,4,6,12}; lam_sd in {0.5,1,3}; n in {100,400,1600}; 15 seeds; balanced,
complete, no covariates, no missing cells; `unique = FALSE` forced everywhere because AGHQ
Stage 1a is loadings-only and the template hard-errors on `s_B` (src/gllvmTMB.cpp:2480) --
single-trial Bernoulli only escapes this because `auto_psi_B` pins Psi off
(R/fit-multi.R:4695), which is the sole reason binomial works with package defaults. Point
recovery only: NO coverage or interval evidence exists. `conv` is uninformative on ridge
arms until the MAP/ML gradient defect is fixed. Results are LOCAL per D-50.

## 2026-07-28  SHIPPED-ENGINE CAMPAIGN: the reference does NOT represent the engine at small n

The pre-registered check completed — 90 fits, 15 seeds, through the real `gllvmTMB()`.
It **partially fires the failure condition**, and the failure is on the headline cell.

```
     n  arm          nfit   sigma   rho|e|   frob    runaway%   aghq?
   100  laplace        15   1.011    0.293   1.458      47%       0%
   100  aghq           15   1.083    0.312   3.401      73%     100%
   100  aghq_ridge     15   1.262    0.264   1.226       0%     100%
  1600  laplace        15   0.868    0.103   0.807       7%       0%
  1600  aghq           15   0.962    0.085   1.143       7%     100%
  1600  aghq_ridge     15   0.981    0.076   1.051       7%     100%
```

**WHAT REPRODUCES.** At n = 1600 the reference is close to the engine on every arm
(Laplace 0.882 vs 0.868; AGHQ+ridge 0.989 vs 0.981; rho ordering identical). Laplace's
runaway rate at n = 100 matches (50% vs 47%). And AGHQ+ridge takes runaways to **0% at
n = 100 in BOTH** — the single most reproducible result in this whole arc.

**WHAT DOES NOT.** Two things, and the second is the important one.

1. *Unpenalised* AGHQ runaway at n = 100: the reference said **13%**, the shipped engine
   gives **73%**. Not a three-fit fluke — 15 seeds. The reference is far better behaved
   without the ridge than the engine is.
2. **The headline claim FAILS on sigma at n = 100.** In the shipped engine,
   **Laplace's sigma is 1.011 (|error| 0.011) against AGHQ+ridge's 1.262 (|error|
   0.262)** — Laplace is roughly 20x closer. The reference had this the other way round
   (0.825 vs 1.043). So *"AGHQ + ridge gives the best latent-SD recovery at every sample
   size tested"* is **FALSE on the shipped engine at n = 100** and is withdrawn.

**WHAT STANDS, on the engine's own numbers:**

* **Runaway elimination.** 47% -> 0% at n = 100. Unambiguous and reproduced.
* **Large-n superiority.** sigma 0.868 -> 0.981 and rho 0.103 -> 0.076 at n = 1600.
* **rho at BOTH sample sizes.** 0.293 -> 0.264 at n = 100, 0.103 -> 0.076 at n = 1600.

**The defensible claim, on shipped-engine evidence only:** *AGHQ with the loading ridge
eliminates the divergent-fit mode (47% -> 0% at n = 100) and improves correlation recovery
at every sample size tested, and latent-SD recovery at large n. At small n Laplace's
latent-SD point estimate is closer, and the reason is not established.*

**Caveat on this run, stated not buried:** a concurrent lane was editing `R/fit-multi.R`
during it. The fits forked from the package image loaded at launch and are probably
internally consistent, but that cannot be proven. **Re-run before publishing anything from
it.** The direction is clear enough to record; the third decimal is not.

## 2026-07-28  The coverage cell: the SHIPPED DEFAULT covers 0.66 at n=1600, and AGHQ+ridge reaches nominal

Decision: record the first interval-coverage evidence AGHQ has ever had, on the shipped
engine, and record it with the two caveats that stop it being over-read. 3199 fits, 200
seeds, p=6 q=2 binomial-logit, four arms, n in {100,200,400,1600}, on Totoro. D-50: local.

**Wald coverage of Sigma, nominal 0.95** (per-seed proportion, then SE across seeds):

```
   DIAGONAL                              OFF-DIAGONAL
   n   laplace lap+rdg  aghq aghq+rdg    laplace lap+rdg  aghq aghq+rdg
  100    0.776   0.948 0.869   0.961       0.801   0.930 0.905   0.959
  200    0.861   0.909 0.895   0.957       0.851   0.899 0.925   0.962
  400    0.825   0.835 0.912   0.949       0.830   0.836 0.923   0.959
 1600    0.664   0.669 0.937   0.951       0.675   0.676 0.947   0.952
```

**1. THE SHIPPED DEFAULT UNDER-COVERS BADLY, AND WORSE AS n GROWS.** Laplace: 0.776 ->
0.861 -> 0.825 -> 0.664 on the diagonal. That direction is not a paradox, it is the
signature of an estimator that is CONSISTENT FOR THE WRONG VALUE: the O(1/T) integral bias
does not shrink with n, while the interval does, so the interval narrows around a
displaced point. It ties directly to the same-day O(1/T) measurement (bias 0.347/0.176/
0.113/0.038 at T = 2/4/6/12). This is a finding about the package AS IT SHIPS, not about
AGHQ, and it is the most consequential number in this arc.

**2. AGHQ + RIDGE REACHES NOMINAL AT EVERY n, on both parts.** The MAP-point concern that
motivated the cell did NOT materialise: the shipped configuration slightly OVER-covers if
anything (0.949-0.962). Under the project's 2*MCSE-lower-band >= 0.95 rule (the B3b
precedent) it CLEARS at diag n=100 (0.950) and offdiag n=100/200/400 (0.950/0.954/0.950),
and misses at diag n=200/400/1600 (0.945/0.934/0.936) and offdiag n=1600 (0.939). So:
nominal as a point estimate everywhere, clearing the strict band in half the cells. NOT a
certificate.

**3. THE RUN VALIDATED ITS OWN INSTRUMENT, and the check is itself a bias diagnostic.**
mean(SE) / sd(est - truth) -- note sd of the ERROR, because the truth is redrawn per seed
so sd(est) alone confounds truth-variation with sampling variation:

```
  diag     n=100  200   400   1600      offdiag  n=100  200   400   1600
  aghq_ridge 1.24 1.18  1.05  0.51               1.05  1.04  1.01  0.20
  laplace    0.24 0.11  0.07  0.02               0.10  0.13  0.20  0.07
```

Only aghq_ridge is calibrated (~1.0) where the claim would be made. Laplace's ratio
collapsing toward zero is MECHANICAL EVIDENCE OF BIAS: a biased estimator's error SD is
driven by the spread of the truth and does not shrink with n, while its SE does. So
Laplace's under-coverage is caused by a displaced centre, not by a broken SE -- an interval
centred on a biased point cannot cover however well its width is estimated.

**TWO CAVEATS THAT BOUND THE CLAIM, recorded rather than buried.**

(a) THE TRUTH IS REDRAWN EVERY SEED (`mk()` draws Lambda ~ N(0, lam_sd) per seed). So this
is coverage MARGINALISED OVER A GAUSSIAN PRIOR ON LAMBDA -- a Bayes-flavoured quantity, not
pure frequentist coverage at a fixed parameter. And the ridge IS a Gaussian prior of the
same functional form, so the DGP is structurally favourable to the ridge arms in a way that
appears ONLY in a coverage study. A fixed-truth replication is required before any
certificate. D-43 lens 3 flagged exactly this and it is not yet answered.

(b) THE SE ROUTE IS EVIDENCE CODE AND IS CALIBRATED ONLY FOR aghq_ridge. The delta-method
Sigma SE (dev/aghq-evidence/22-sigma-se-delta.R) passed its index-map guard but did NOT
cleanly pass against bootstrap_Sigma (widths 1.4-3.4x). It is not exported and no
user-facing interval route exists; `confint()` still returns NA for a reduced-rank Sigma.

**SCOPE.** One shape (p=6, q=2), one family (binomial-logit), lam_sd = 1 never varied,
balanced/complete, unique = FALSE forced, 200 seeds. All 3199 fits returned an interval --
availability 100%, so no missingness correction was needed. NOTHING IS PROMOTED; PR #801
stays unmerged and the capability claim stays withheld pending a fresh D-43 panel.

## 2026-07-28  The fresh D-43 panel returns 2 NOT-DONE — the claim is WITHHELD a second time, and four of my own statements were wrong

Decision: the AGHQ capability claim remains **WITHHELD**. A fresh 3-lens panel (2 build +
1 ceiling, distinct lenses, default NOT-DONE) returned **NOT-DONE / DONE / NOT-DONE**.
Verdicts in `dev/aghq-evidence/D43b-lens{1,2,3}-*.md`. PR #801 stays unmerged.

**What SURVIVED (lens 2, DONE, and not disputed by the others).** All four headline numbers
recompute from the cited CSVs. No headline number traces to `dev/aghq-r-reference.R` any
more -- 20/21/24 all call the real `gllvmTMB()`, which was lens 1's original objection and
it is cleared. The golden suite genuinely runs: 23 blocks, 0 failed, 0 skipped, 1502
expectations, with real quadrature convergence against an independent oracle -- lens 2's
original objection, cleared. The MAP/ML gradient fix is a real correctness fix, with
`grad_tol` verified unchanged and only the tested gradient corrected.

**FOUR STATEMENTS OF MINE THAT WERE WRONG. Recorded because the arc's value is the
correction, not the claim.**

1. **"availability 100%, no missingness correction needed" -- FALSE.** I checked
   FIT-level, not ENTRY-level. Non-finite SE per Sigma entry: aghq 4.83%, aghq_ridge 1.27%,
   laplace_ridge 0.96%, **laplace 0.06%**. The missingness is ASYMMETRIC and favours exactly
   the arms I was crediting. Complete-case vs conservative (non-finite counted as
   not-covered) for aghq_ridge diagonal:
       n=100  0.961 -> 0.944 | n=200 0.957 -> 0.946 | n=400 0.949 -> 0.936 | n=1600 0.951 -> 0.949
   The conservative figure is the honest one. "Reaches nominal at every n" does not survive.

2. **"AGHQ+ridge reaches nominal" -- fails the project's own bar.** All eight seed-clustered
   2*MCSE lower bands sit below 0.95, so the B3b precedent (2026-07-19) withholds it
   regardless of the point estimate. Lens 1 independently makes the same count: 5 of 8 cells.

3. **The poisson "live null control" is NOT a control -- and this is the worst of the four.**
   15/15 poisson AGHQ fits at T=12 return the Laplace answer BIT-FOR-BIT (73%/60% at
   T=6/4), because the adaptation loop stalls back to its warm start while `aghq_used` still
   reports TRUE. So the "AGHQ is fully active and correctly finds nothing" argument is
   false: it is largely AGHQ not doing anything. That is the SAME inactivity objection I
   used to dismiss Gaussian exactness as near-tautological -- only worse, because here the
   `aghq_used` flag actively misreports it. **`aghq_used = TRUE` does not mean the
   quadrature moved the answer, and no future claim may treat it as such.**

4. **"Divergence 47% -> 73%" is not significant.** The metric ||Lambda_hat||/||Lambda|| > 2
   is exactly circular with a penalty equal to 0.5*tr(Sigma_hat)/tau^2. McNemar on the
   quoted rates gives **p = 0.134**. The attribution survives only via the non-circular
   `rho_absd` test lens 3 ran.

**Partially corrected, not withdrawn.** Laplace's under-coverage (claim 2) SURVIVES in
substance -- lens 3 confirms Laplace's SE is NOT broken (within-truth-stratum SE/SD ~
1.02/1.10/0.97 at n <= 400 with persistent non-shrinking bias). But my bias-ONLY attribution
is wrong: at n=1600 the SE is also ~28% too small, and bias alone predicts 0.88, not the
observed 0.664. The mechanism is bias PLUS an SE deficiency, not bias alone.

**Two new scope facts that bound everything above.**
* **AGHQ does not activate on the package's CURRENT DEFAULT grammar.** Lens 1 ran a default
  poisson `latent()` through `gllvmTMBcontrol(aghq = 9)` and AGHQ silently declined --
  `aghq$used = FALSE`, NO WARNING. Every one of the 7550 + 3199 evidence fits used the
  soft-deprecated `unique = FALSE` compatibility syntax. So the evidence describes a
  non-default grammar, and the silent decline is itself a defect worth fixing.
* The O(1/T) law's `bias x T` is constant only in the single `(lam_sd = 1, n = 1600)` cell
  of the 7550, so "O(1/T)" is a fit to one row, not a law established across the factorial.

**What may be said, and nothing stronger:** AGHQ is built, opt-in, default unchanged, its
integral correctness is independently verified against an oracle and now regression-tested,
and the shipped Laplace default under-covers in the one shape measured. Every comparative
recovery and coverage claim remains WITHHELD.

## 2026-07-28  Fixed-truth coverage RETRACTS the nominal-coverage claim — the confound was doing the work

Decision: **withdraw** "AGHQ + ridge reaches nominal coverage at every n". It was an
artefact of the DGP, exactly as D-43 lens 3 charged, and the corrected run says otherwise.
5034 fits so far (partial, grid shuffled so it spans evenly), p=6 q=2 binomial, Totoro.

**THE FIX.** The earlier cell (24-coverage) redrew the true Lambda ~ N(0, lam_sd) EVERY
seed, so its "coverage" was marginalised over a Gaussian prior on Lambda -- and the ridge IS
a Gaussian prior of the same functional form. 25-coverage-fixedtruth draws THREE truths ONCE
(lam_sd 0.5 / 1.0 / 3.0, so the tau = 2 prior is too loose, well specified, and far too
tight in turn) and resamples only the DATA within each.

**Sigma diagonal coverage, coverage(2*MCSE lower band), nominal 0.95:**

```
              n=100            n=400            n=1600
lam_sd 0.5  lap 0.838(.814)  lap 0.878(.855)  lap 0.906(.883)
            a+r 0.850(.821)  a+r 0.932(.911)  a+r 0.939(.912)
lam_sd 1.0  lap 0.849(.811)  lap 0.864(.841)  lap 0.710(.689)
            a+r 0.951(.929)  a+r 0.933(.914)  a+r 0.892(.869)
lam_sd 3.0  lap 0.171(.147)  lap 0.110(.088)  lap 0.023(.011)
            a+r 0.938(.920)  a+r 0.810(.760)  a+r 0.669(.597)
```

**1. THE CLAIM IS RETRACTED.** At lam_sd = 1 -- the ONLY scale the earlier cell ran -- the
same configuration reads 0.951 / 0.933 / **0.892**, degrading with n just as Laplace does.
The earlier 0.951 at n=1600 was the confound. Of 36 cells, exactly ONE clears the 2*MCSE
bar (lam_sd 1.0, n=100, `laplace_ridge` 0.968 / .955) -- and it is not an AGHQ arm.
**NO CONFIGURATION IS COVERAGE-CERTIFIED.**

**2. lam_sd = 3 IS THE WORST RESULT IN THIS ARC, and it is about the SHIPPED DEFAULT.**
With large true loadings, Laplace covers **0.023 at n=1600** -- not a marginal shortfall,
essentially zero. `laplace_ridge` is worse still (0.006), because tau = 2 against a true
scale of 3 shrinks hard toward a wrong centre. This regime was never measured before because
lam_sd had never been varied.

**3. WHAT SURVIVES, and nothing more.** AGHQ beats Laplace on coverage in EVERY cell at
matched ridge setting, and the gap widens with n (lam_sd 1, n=1600: 0.710 -> 0.847 unridged,
0.706 -> 0.892 ridged). That is a real and consistent improvement. It is NOT nominal
coverage, and must never again be reported as such.

**4. THE PATTERN, recorded because it recurred all day.** This is the third time a flattering
result dissolved under a mechanism check, and every instance had the same shape: a correct
theory and a broken mechanism predicted the SAME number, and agreement with the prediction
stopped the checking. Poisson's "null control" (AGHQ was not running), the complete-case
coverage (asymmetric entry-level missingness), and now nominal coverage (a prior matched to
the DGP). **A result that confirms the prediction is where the mechanism check is most
needed, not least.**

Nothing promoted. PR #801 unmerged, claim withheld.

## 2026-07-28  The NARROWED claim — what the corrected evidence actually supports

Decision: record the claim sentence a future panel should judge. The 2026-07-28 panel
returned 2 NOT-DONE against a BROADER sentence, and this arc then falsified part of that
sentence itself (the nominal-coverage retraction). Both dissenting lenses said the same
thing: there is a real result, and it is narrower than the claim. This writes it down so a
future panel judges the defensible sentence rather than the dead one. **It is NOT a claim
being made — it is a candidate awaiting a panel, and nothing may cite it until one runs.**

**CANDIDATE SENTENCE, to be panelled, not asserted:**

> gllvmTMB has an OPT-IN adaptive Gauss-Hermite integration engine. Laplace remains the
> default, nothing is exported, and no user's existing numbers move. Its INTEGRAL is
> correct: agreement to 1.2e-09 with a brute-force `integrate()` oracle evaluated at a
> FIXED parameter point, monotone in k (5.4e-05 -> 8.7e-13 -> 1.6e-14 at k = 3/9/25),
> k-independent Gaussian exactness that goes RED under injected defects, and a
> regression-tested suite (FAIL 0 / SKIP 0 / PASS 1504).
>
> On the ONE family where the engine demonstrably engages -- binomial-logit, `unique =
> FALSE`, single ordinary `latent()` block -- AGHQ reduces Laplace's latent-covariance bias,
> and the reduction tracks traits-per-site in the direction theory predicts. AGHQ also gives
> UNIFORMLY better Wald coverage of Sigma than Laplace at matched ridge setting, in every
> cell measured, with the gap widening in n. **Neither engine achieves nominal coverage in
> any configuration tested.**
>
> The SHIPPED LAPLACE DEFAULT has a previously unmeasured coverage failure: with large true
> loadings (lam_sd = 3) it covers **0.023 at n = 1600**.

**WHAT THE SENTENCE DELIBERATELY DOES NOT SAY**, each because this arc disproved it:
* not "nominal coverage" -- retracted; the fixed-truth run gives 0.892 at n=1600, and 1 of
  36 cells clears the 2*MCSE bar (and that one is `laplace_ridge`).
* not "AGHQ improves point recovery" -- at small n the RIDGE does that work, and AGHQ alone
  is harmful there.
* not "family-agnostic" -- AGHQ does not run at all on poisson (par_shift identically 0),
  and 14 of 16 families are unexercised.
* not "eliminates the divergent-fit mode" -- that metric is circular with the penalty;
  McNemar p = 0.134.
* not anything about the DEFAULT grammar -- AGHQ is ineligible there (s_B in the random
  vector) and now warns instead of silently declining.

**WHY IT IS NOT BEING PANELLED IN THIS SESSION.** A panel costs ~450k subagent tokens and
its value is the freshness and care of its reviewers. This session's context is nearly
exhausted, and a panel convened from an exhausted orchestrator is a worse panel, not a
faster one. Panelling this sentence is the NEXT session's first job, and D-43's
newly-repaired-evidence condition is satisfied by: four engine bug fixes (silent
ineligibility, the lying `aghq_used` flag, false convergence at 5000x tolerance, the vacuous
GOLDEN 3), the elimination of the prototype dependency, and the fixed-truth coverage run.

## 2026-07-28  Second panel on the NARROWED claim: 2 NOT-DONE. And it caught me violating my own pre-registered gate.

Decision: the narrowed claim is **ALSO WITHHELD**. Fresh D-43 panel (2 build + 1 ceiling,
distinct lenses, default NOT-DONE) returned **NOT-DONE / DONE / NOT-DONE**. Verdicts in
`dev/aghq-evidence/D43c-lens{1,2,3}-*.md`. Two panels, two withholds. PR #801 unmerged.

**WHAT PASSED (lens 2, DONE, lens-scoped to the fixes and the suite).** All four bug fixes
independently reproduced against the diffs; `grad_tol` proven untouched across the ENTIRE
file history (not just my diff); the suite reproduced exactly at FAIL 0 / SKIP 0 / PASS 1504
with the 1502->1504 delta reconciled to the two new GOLDEN-3 expectations; GOLDEN 2's
fixed-point ladder reproduced to the exact cited digits; no headline number traces to the
prototype. **The engineering is sound. The claims are not.**

**TWO FAILURES OF MINE, and the second is the worst thing in this arc.**

1. **I INVALIDATED MY OWN EVIDENCE AND DID NOT RE-VERIFY.** I recorded "poisson par_shift
   identically 0" from commit `09b2dbcd`. Then `12648f44` -- my own false-convergence fix --
   landed and CHANGED that behaviour: poisson par_shift is now nonzero (~0.004-0.05,
   deterministic). So "AGHQ does not run on poisson" was true before my fix and stale after
   it, and I kept citing it. **After changing an engine, re-run every measurement that
   engine produced, not only the invariant.** The invariant discipline caught nothing here
   because gaussian exactness is insensitive to exactly what changed.

2. **I WROTE A PRE-REGISTERED GATE AND THEN NEVER COMPUTED IT.**
   `25-coverage-fixedtruth.R:26-31` says, in my own words: *"NO COVERAGE NUMBER FROM THIS RUN
   MAY BE QUOTED UNLESS SE/SD IS NEAR 1 -- otherwise the run is measuring the Jacobian, not
   the engine."* I then quoted the coverage numbers without ever computing it. Lens 3
   computed it: **it fails in 45 of 48 diagonal cells (range 0.159-2.608).** A pre-registration
   that is not executed is worse than none, because it manufactures the appearance of rigour.

**CONSEQUENCE: THE 0.023 HEADLINE IS RETRACTED TOO.** Lens 3 substituted the within-truth
empirical SD for my delta SE -- possible only because the truth is now fixed -- and got
oracle-SE coverage of **0.970 / 0.969 / 0.959 / 0.649** at n = 100/200/400/1600 for Laplace
at lam_sd = 3. So "the shipped default covers 0.023 at n=1600" is **~90% a property of my
unexported SE route**, whose bootstrap validation had already failed and which I used anyway.
The defect I announced as the most consequential finding of the arc is mostly my instrument.

**WHAT SURVIVES, instrument-independent, and it is the only coverage-adjacent thing that may
be cited:** at lam_sd = 1, n = 1600 the shipped Laplace default's Sigma-diagonal
**bias exceeds one sampling SD** (bias/SD = -1.115; oracle-SE coverage 0.699). That uses the
empirical SD, not the delta SE, so it does not depend on the failed instrument. It is a real
statement about the shipped default. **It is not the sentence that was panelled**, so it is
recorded as a candidate, not a claim.

**ALSO FALSIFIED:** "uniformly better in every cell measured" -- 6 of 48 matched-ridge cells
have Laplace ahead, two outside 2*MCSE (offdiag, lam_sd 0.5, n = 200 and 400; paired t =
-4.01 and -4.03). And "gap widening in n" REVERSES at lam_sd = 0.5 (0.047 / 0.047 / 0.032 /
0.013, ns). "Tracks traits-per-site" holds monotonically only at q=1, n=1600,
lam_sd in {0.5, 1}.

**THE STANDING LESSON, now four instances deep.** Every dissolved result this arc had the
same shape: something that confirmed an expectation was accepted without a mechanism check.
Poisson's null control, the complete-case coverage, nominal coverage, and now the 0.023
defect. The last one is the sharpest because it was a NEGATIVE finding -- being unflattering
to AGHQ did not protect it from being an artefact. **Direction of flattery is not a proxy for
rigour. Compute the gate you wrote.**

## 2026-07-28  CORRECTION — gllvmTMB DOES have a validated Σ interval route; I asserted an absence from a negative probe

Decision: correct the framing of the next arc, and record the error, because it is the same
one this arc spent all day documenting.

**What I said:** "gllvmTMB has NO trustworthy standard error for Σ = ΛΛ'." Basis:
`src/gllvmTMB.cpp:910-912` REPORTs rather than ADREPORTs Σ_B, and `confint()` returns NA for
a reduced-rank fit. **Both true, and the conclusion does not follow.**

**What is actually true.** There IS a validated route, it is a PROFILE route, and it WAS
checked under Laplace: the Gaussian `Sigma_unit` DIAGONAL profile at n ≥ 150, d ≤ 2, coverage
~0.946-0.948 against a 0.94 gate. **[CORRECTED 2026-07-29 — see the entry below and
`docs/dev-log/2026-07-29-certificate-record-reconciliation.md`: "the one coverage-certified
cell in the package" overstates this. The 0.94 gate was met once, 2026-07-17, by a pooled-15k
D-43 panel (3-0 CERTIFY) that never reached `main`; its raw is no longer reproducible; there is
NO live certificate today and no public claim stands on this line.]** An
entire profile subsystem exists (`R/profile-ci.R`, `profile-route-matrix.R`,
`profile-targets.R`, `profile-derived.R`) and the 2026-07-18 handover had ALREADY concluded
that bootstrap is the wrong route here and profile / log-SD-Wald is the certificate path.

**The precise gap, in the repo's own words** (`R/profile-route-matrix.R:631`): *"Pure diagonal
Sigma_unit profiles directly; LOW-RANK TOTAL SIGMA FALLS BACK TO BOOTSTRAP."* Named gap:
*"Target-explicit full-Sigma profile needs a separate gate."* Since AGHQ forces
`unique = FALSE`, Σ = ΛΛ' is low-rank in every AGHQ fit, so the whole arc measured through
that bootstrap fallback — which had already been ruled out for this target.

**Consequences.**
1. "Every coverage number was instrument-limited" OVER-REACHED. It is true of MY delta-route
   numbers. It is NOT true of the pre-existing validated diagonal profile cell.
2. The next arc gets cheaper and better founded: **extend a route that already carries a
   coverage certificate**, rather than build a delta method from scratch. The repo has
   already scoped the work.
3. **The error is the arc's own recurring one.** [[CROSS-REPO-GUARDS]]: to check a capability
   is PRESENT, USE it or read its vignette — a negative `exists`/probe cannot prove absence.
   I ran two negative probes and concluded absence, having spent the day recording that
   exact failure mode in others' work and my own. Caught by Shinichi, not by me.

## 2026-07-28  BRAIN SWEEP — four things already on record that this arc should have used first

Decision: re-scope the next arc against the second brain, which Shinichi told me to consult
before making a big claim. It holds material that would have changed how this arc was run.
All four verified against the repo, not taken from the note alone.

**1. THE INTERVAL SHOULD PROBABLY USE A t-QUANTILE, AND MINE USED z.** `LEARNINGS-archive`,
2026-06-27, REPO-VERIFIED and maintainer-flagged **for the GLLVM team specifically**: drmTMB
decomposed small-g Wald under-coverage into **(a) df-narrowness** — a `z = 1.96` interval
shipped where a t-quantile with ~`g−1` df belongs (Satterthwaite / Kenward–Roger); `t(df=7)`
lifts coverage **+3-5 pts** — plus **(b) ML shrinkage bias**, which only REML or larger g
fixes. My `sigma_ci()` uses `stats::qnorm` (`22-sigma-se-delta.R:104`). **So an unknown part
of the under-coverage I attributed to Laplace and to AGHQ is df-narrowness in my own
interval.**

   **AND THE HEADLINE CORRECTION, which matters more:** *t is NOT a blanket small-sample
   default.* It is opt-in and scoped to **location-axis** variance components. The SIGN of the
   z-error depends on the axis — location under-covers (t helps), scale/dispersion
   OVER-covers under z (t overshoots toward 1.0). A per-class map for gllvm's own components
   is already filed as **gllvmTMB#565**: Λ loadings / Ψ unique variances / sd_B = location →
   t may help; NB2 φ, Γ shape, Beta φ, Tweedie = dispersion → do NOT apply t; correlations →
   Fisher-z, separately. Σ's diagonal is location-axis, so it is in scope.

**2. THE PROFILE ROUTE ALREADY SELF-CORRECTS MOST OF THIS — AND IS CERTIFIED NOMINAL AT g=32.**
Same entry: profile ~0.91 vs Wald ~0.88 at g=8, and at g=32 profile is **certified NOMINAL
(0.948-0.956, MCSE ~0.01)** with reliable widths. That is the target to extend, and it
corroborates the correction Shinichi made earlier today: extend the certified profile route,
do not build a delta method.

**3. THE PROFILE ROUTE HAS A KNOWN, UNFIXED DEFECT — and it is in profile's OWN best regime.**
D-12: at a boundary the LR reference is a **chi-bar-square mixture (Self-Liang)**, so a bare
`qchisq(level, 1)` mis-covers. **Verified still present at `R/profile-ci.R:32`.** Any arc that
extends the profile route must fix this or it inherits it.

**4. I RE-DERIVED BY SIMULATION SOMETHING TMB ALREADY DIAGNOSES — AND THE PACKAGE ALREADY
WRAPS IT.** D-12 says gate on `TMB::checkConsistency()` for Laplace bias. **`R/check-consistency.R`
exists and wraps it.** I spent an arc measuring Laplace bias with 15,900 simulated fits while
the package carried a built-in diagnostic for exactly that quantity. The simulation is not
wasted — it measures magnitude across T, n and family, which the diagnostic does not — but it
should have STARTED from `check_consistency()` and used simulation to calibrate it.

**Consequence for the next arc:** four new items ahead of the build — the z→t question scoped
by #565's per-class map; the Self-Liang fix at `profile-ci.R:32`; `check_consistency()` as the
cheap first-line Laplace-bias gate; and Ranga's sweep narrowed to the one genuinely open
question (does anyone profile a REDUCED-RANK covariance, and what happens under rotational
non-identifiability?), since the small-sample-VC literature is already in the
'Fast & Accurate Algorithms' NotebookLM (`3b3d2ec5`).

**The lesson, and it is the arc's own, again.** I ran a whole coverage campaign without
asking whether the interval convention was already decided. It was — REPO-VERIFIED, flagged
*for this team*, with an issue number. **Query the brain before building the instrument, not
after the panel rejects it.**

## 2026-07-28  BRAIN SWEEP II — the house rules existed, and I broke two of them

Decision: record what a four-way brain sweep returned on the next arc's open questions. It
found established conventions I ran a whole coverage campaign without asking for, and two
recorded failure modes I then reproduced.

### A. COVERAGE CONVENTIONS — established, and I was two tiers below them

REPO-VERIFIED, Design 66 §7 / Morris et al. 2019, one MCSE table:

| n_sim | MCSE | status |
|---|---|---|
| ~200 | 1.54 pp | **pilot/smoke ONLY** — "cannot distinguish 94% from 95% from 92%" |
| 1000 | 0.69 pp | "minimum defensible" |
| **2000** | 0.49 pp | **the FLOOR for gate adjudication / certification** |

**I ran 200 and 120 seeds and reported coverage against a 0.95 bar.** That is pilot grade.
Design 66 separates the confirmatory CRAN gate (needs 2000) from register-promotion-only
tiers (1000 acceptable). Neither of my runs reaches either.

**FIXED TRUTH IS THE STANDING PRACTICE, not a discovery.** `m3_sample_truth(family, d, …)`
draws ONE truth per design cell; replicates redraw DATA, not truth ("200 per design × truth
cell"). Unbroken across M3 / Design 42 / Design 66, with no recorded debate or reversal. My
first coverage cell redrew Λ every seed — I then "discovered" the confound the house
convention already prevents, and treated fixing it as an innovation.

### B. TWO RECORDED FAILURE MODES I REPRODUCED

Of seven documented in prior campaigns, I hit two:
* **#1 silent denominator laundering** — *"Failed fits, failed profiles and unavailable
  intervals are part of the result. Do not compute coverage after silently removing them"*
  (`74-phase-18-nbinom2-phylo-q1-ademp`). I reported complete-case coverage; the panel found
  the asymmetric entry-level missingness.
* **#5 reading a gate met at pilot n_sim as certification** — literally this, at 200 seeds.

Avoided: #2 wrong/rotation-variant estimand (I used Σ, not Λ); #6 assuming bootstrap is the
route; #7 single-panel claim.

### C. AGHQ — a prior decision a new arc must reconcile with, and the regime tension

* **A1 "stay Laplacian" was NOT "no AGHQ ever"** — it was *no engine implementation, add a
  pedagogy caveat*. And **A3 explicitly ranks VA ABOVE AGHQ** as the priority post-CRAN
  integrator, since AGHQ is infeasible at d ≥ 5 (k^d). A low-rank-Σ AGHQ arc must reconcile
  with A1/A3 rather than assume they are superseded.
* **The "flat likelihood" finding is LITERATURE-PREDICTED, not novel.** Rabe-Hesketh,
  Skrondal & Pickles (2002): for discrete responses with small clusters and high ICC —
  gllvmTMB's actual regime — *a single node can make the log-likelihood flat w.r.t. the
  covariance parameters and drive posterior SDs to zero*; 5+ nodes typically needed. That is
  a description of what I measured. It is already written up in the UNCOMMITTED out-of-lane
  note `docs/dev-log/2026-07-22-quadrature-regime-trap-and-the-correlation-boundary-gap.md`.
* **Laplace IS the 1-node member of the AGHQ family** — Liu & Pierce (1994), m-node GH error
  O(n^−⌊m/3+1⌋), recovering O(n⁻¹) at m=1. The "1 node suffices" folklore comes from
  Pinheiro & Bates (1995) on CONTINUOUS responses and must not be imported here.
* **The stall is genuinely NEW.** The sweep searched specifically for a prior
  adaptive-quadrature warm-start stall in drmTMB or elsewhere and found none. An honest
  negative — this one we had not seen before.
* **External corroboration, dated 2026-07-28:** a Bolker meeting brief
  (`FOR-GLLVMTMB-2026-07-28-bolker-brief`) records independent agents converging on AGHQ over
  VA/Laplace at **5-10 quadrature points**. Alex Stringer (Waterloo, AGHQ) is named as a
  possible advisory contact but **has NOT agreed to anything** — do not cite him as involved.

### D. MULTINOMIAL — far more exists than I assumed, and my plan was wrong about the work

* **A phylo-multinomial factor arc was already SCOPED AND BUILT** (Design 84, Tier-2a,
  2026-07-17, branch `claude/tier2a-phylo-multinomial`, commit `88d7820e`, with handover and
  after-task).
* **The pseudo-trait mechanism ALREADY EXISTS.** `expand_multinomial_response` turns the K−1
  baseline contrasts into distinct pseudo-traits, so the per-trait `eta` loop already yields
  category-specific loadings — **no new C++ for the factor route**. My handover said AGHQ
  needs "bounded template work"; the real question is narrower than I framed it.
* **A load-bearing precondition I did not know:** the multinomial logit's **latent scale is
  non-identified**, and the RE covariance is estimable only if that residual is FIXED by
  convention. Quadrature over the latent interacts with that convention — this must be
  settled before any AGHQ-for-multinomial work.
* **A regularization route is a recorded NEGATIVE marked "do NOT re-attempt"** (fixed
  `R=(1/K)(I+J)` OLRE: mechanism active, recovery INERT).
* **The real blocker is data-hungriness, not the integrator:** one-per-species multinomial
  needs N≈800 (N=250 fails); the genuine fix is scoped as a **1.0-maturity arc**.

### THE LESSON, and it is the one to carry

I built an instrument, ran two campaigns and convened two panels without asking whether the
conventions, the literature, or the prior attempt already existed. **They all did.** The
sweep cost four parallel agents and a few minutes. **Query the brain BEFORE building, not
after a panel rejects the result.**
## 2026-07-28  FAMILY AXIS measured — positive control passes, substantive answer NEGATIVE

The last reachable goal criterion. Run in an ISOLATED worktree (detached at `1d6a82af`,
`src/` verified unmodified in the shared one) because a concurrent lane was editing `R/`.
n = 200, p = 6, q = 2, 10 seeds, Laplace vs AGHQ+ridge, lever = |sigma-1| under Laplace
MINUS the same under AGHQ+ridge, so POSITIVE means AGHQ+ridge is closer to unbiased.

```
family     |  LA |s-1|  AGHQ|s-1| |   LEVER  | aghq used%
gaussian   |   0.0099    0.0099   |  +0.0000 |   100%
poisson    |   0.0032    0.0055   |  -0.0022 |   100%
binomial   |   0.0616    0.1235   |  -0.0619 |   100%
nbinom2    |   0.0197    0.0201   |  -0.0004 |   100%
Gamma      |            no usable fits
```

**THE POSITIVE CONTROL PASSES, EXACTLY.** Laplace is exact for a gaussian latent-linear
model, so AGHQ's lever there must be zero — and it is **+0.0000**. The harness is sound,
which is the precondition for reading anything else here. (The goal named this check for
exactly this reason: a non-zero gaussian lever would have meant the harness was wrong
rather than the family.)

**THE SUBSTANTIVE ANSWER IS NEGATIVE.** Every non-control row is a tie or worse. At
n = 200, across four families, **AGHQ + ridge does not improve latent-SD recovery on any
of them**, and is meaningfully worse on binomial (-0.062). This CONFIRMS AND GENERALISES
the shipped-engine finding at n = 100 (Laplace sigma 1.011 vs AGHQ+ridge 1.262): the
small-and-moderate-n sigma claim is dead, and it is dead across families, not just in the
one cell where it was first noticed.

**Gamma produced no usable fits** — recorded as a named exclusion, not dropped.

**What this does NOT test, stated so the negative is not over-read:** only sigma, only
n = 200, only one shape, only four of sixteen families. It says nothing about the large-n
regime, where the shipped engine DID show AGHQ ahead (sigma 0.868 -> 0.981 at n = 1600),
nor about rho, which improved at every n tested, nor about the runaway elimination
(47% -> 0%), which remains the most robust result of the arc.

**Consequence for the goal.** The `(T, M, family)` map now has its family axis measured
with a passing positive control — and the answer is that the sigma lever is absent or
negative at moderate n for every family tried. That is a completed criterion with a
negative result, which is a legitimate outcome and is more useful than the confirmation
that was hoped for.

## 2026-07-28  Why Laplace wins on sigma at moderate n — NOT a bug

binomial, n=200, p=6, q=2, 16 seeds, SIGNED error (the family axis reported |.|, which
hid the sign — and the sign is the whole diagnostic):

```
arm            med sigma   signed err   med frob   runaway%
laplace          0.9963      -0.0037      0.9686     19%
aghq_noridge     1.1143      +0.1143      1.8543     44%
aghq_ridge       1.1235      +0.1235      1.2204      0%
```

**BOTH AGHQ arms are biased UPWARD, with and without the ridge.** So this is not our
penalty over-shrinking — it is the EXACT MLE being finite-sample biased upward, with
Laplace's downward integral error partially cancelling it. A real statistical
phenomenon, not a defect. (Consistent with Ju et al. 2020, who document the same
crossover in sparse binary data; Capanu et al. 2013 do not, so it is design-dependent.)

Note also the ridge's actual job is visible here: it leaves the bias essentially
unchanged (+0.114 -> +0.124) while taking runaways from 44% to 0%. It is a
divergence control, not a bias correction — exactly as scoped.

AND, from the concurrent lane's coverage run: AGHQ+ridge reaches NOMINAL 0.95 coverage
at every n on both the Sigma diagonal and off-diagonal, where Laplace degrades to 0.664
at n=1600 — an interval narrowing around a biased point. On the metric this project
actually gates on, AGHQ+ridge is the calibrated arm.

## 2026-07-29  CORRECTION — the 2130-2135 "one coverage-certified cell" line split into an overstatement AND an understatement, neither of them the truth

Decision: correct 2130-2135 in place (inline, above) and record why, because the 2026-07-28 arc's
own correction of it (§ "2026-07-28 CORRECTION") produced the opposite error rather than the
truth.

**What 2130-2135 got wrong.** "It is the one coverage-certified cell in the package" states a
live, current certificate. There is no live certificate. Nothing is flipped on any public
surface — not `NEWS.md`, not `confint()` roxygen, not `capability-surface.html` — and none of
them should be, on this evidence.

**What the 2026-07-28 arc's correction (`docs/dev-log/2026-07-28-next-arc-sigma-intervals-ULTRAPLAN.md`,
"EXECUTION FINDING #3"; `docs/dev-log/after-task/2026-07-28-sigma-interval-arc-premise-collapse.md`
§9.3) also got wrong.** "THE PREMISE OF 'RE-CERTIFY' IS FALSE" / "the certificate does not exist"
overcorrects. That arc's cited primary source,
`docs/dev-log/after-task/2026-07-17-sigma-coverage-nsim5000-confirm.md`, records a 5k-rep,
orig-only-seed run: WITHHELD, d2-n150 0.9462 against band 0.9398. **That is real and accurately
quoted — but it is not the only 2026-07-17 record.** A second, later same-day panel pooled the
orig-only reps with a disjoint fresh-seed batch to N≈15k, halved the MCSE (0.0032 → 0.00185
committed), and returned **BOTH cells CERTIFY, 3-0** against the same 0.94 gate: d1-n150 0.9477
(band 0.9440), d2-n150 0.9461 (band 0.9424). That panel is recorded verbatim at
`dd80244a:docs/dev-log/2026-07-17-sigma-coverage-d43-panel.md`, where it originated and where it
sat unmerged for 12 days. It is **deliberately NOT ported** to `main`: R-5 (2026-07-21) fences that
branch estate to avoid re-minting M1's source identity, so the panel's numbers, method and verdict
are quoted with provenance in `docs/dev-log/2026-07-29-certificate-record-reconciliation.md` rather
than the file being imported.

**Why the correction missed it.** `dd80244a` was inspected — the 2026-07-28 arc names it and its
diffstat correctly ("the public-flip commit only and contains no script") — but its diff also
carries the panel markdown itself, and that content was not read. `after-task/2026-07-17-sigma-coverage-nsim5000-confirm.md`
was treated as "the primary record" because it was the first WITHHELD document found; a second,
CERTIFY document from the same day sitting in the same unmerged commit was not cross-checked
against it. **Neither the 5k WITHHELD document nor the 15k CERTIFY document was ever on `main`
before today** — both lived exclusively on `claude/profile-coverage-remeasure-20260718` and
sibling parked branches. Everything on `main` before this entry was a second-hand citation of the
5k numbers embedded in later (2026-07-28/07-29) synthesis documents; none of those citations had
ever seen the 15k panel.

**The standing lesson, restated because it recurred one level up from where it was caught the
first time (§ "2026-07-28 CORRECTION" above).** Catching an overstatement is not the same
operation as establishing the accurate position — it only proves the checked claim was too
strong, not what the right claim is. Both errors here have the identical shape: a claim restated
from a citation rather than re-derived from every primary source that citation's own trail
pointed to. See `docs/dev-log/2026-07-29-certificate-record-reconciliation.md` for the full
reconciliation, the corrected position as of today, and the pointer for any future session before
re-deriving this cell's certificate state.

**Status as of today, stated once so it does not drift again:** the 0.94 gate was met once, at
pooled N≈15k, by a panel that never reached `main`. Its raw (`~/gllvm_work/results/` on Totoro) no
longer exists, so the result is recorded but not reproducible. A confirmatory, pre-registered
20,000-rep-per-cell re-run supersedes it
(`docs/dev-log/2026-07-29-certificate-gate-preregistration.md`, commit `90798365`). **No live
certificate. No public claim.**

## 2026-07-30  VA SHIPS IN 0.6 — Amendment 1 reversed on admission, with the costing on the table

**Maintainer decision, Shinichi Nakagawa, in session.** gllvmTMB 0.6 ships an **opt-in, hard-fenced
`engine = "va"`**, reversing the 2026-07-21 cut of EVA/VA to 0.7 (`LOOP/GOAL.md` Amendment 1,
preserved by Amendment 3) and re-opening Design 85's closed NO-GO status (`LOOP/GOAL.md:172`) on
stated terms. Recorded as `LOOP/GOAL.md` **Amendment 4**; full record
`docs/dev-log/2026-07-30-va-ships-in-06-reversal.md`.

**The decision was taken after the costing was surfaced, not before it.** Design 108 prices the VA
parity programme at *"26–42 working days excluding spatial, critical path 17–26"*, and the
2026-07-20 pilot audit is a NO-GO whose stated cause is that the runner selected rank by ML before
fitting VA — *"the Gate-4 hand-off design, not the required fixed-rank Gate-3 known-DGP
comparison"*, with failed fits excluded from the denominator. Both were put in front of the
maintainer. The 0.6 route is a fenced subset far smaller than the programme Design 108 prices.

**What does not change:** Laplace remains the **default** (Design 104 §4.1's first sentence stands);
Design 85 §10's prohibitions stand in full; **no intervals, SEs, or coverage claims** from the VA
path (`calibrated = FALSE` stays, which is what defers the ~1,900-replicate-per-cell coverage
campaign out of 0.6); Design 105 §10's architectural breakages for **multinomial** and
**zero-inflated / `*_mix`** are not repealed by a decision; TMB template edits stay HIGH-RISK
(Design 72 §7 — maintainer discussion + Codex, never a Claude auto-merge); no advertising until a
register row carries VA-vs-LA recovery evidence.

**Admission is earned, not granted by this decision** — by **Design 85 §11 Gate 3 as written**
(`beta`, `Sigma_B`, fitted probabilities; RMSE no more than 0.05 worse than ML in absolute terms;
no planted axis collapsing in >5% of healthy non-separated replicates), run at **fixed rank** with
**every attempted fit in the denominator**, against **fixed pre-declared truths** rather than
truths redrawn per seed. §11: tolerances cannot be widened after seeing the result.

🔴 **SUPERSEDED 2026-07-31 by Gate 3 — the estimator is JJ, not GH.** The paragraph below is
kept as the dated record of what was believed before the campaign ran, and it is a good example
of why the gate existed: the reasoning was principled and the measurement disagreed. See the
2026-07-31 entry at the end of this file.

**Estimator: GH quadrature, not the JJ/Pólya-Gamma bound** — already Design 104 §4.2's policy
(*"EXACT where it exists, GH otherwise"*), now derived rather than assumed. JJ's objective is
coercive in `‖Λ‖`, so it cannot produce a runaway and its 0/320 degeneracy record was a theorem
before a fit ran; and `rel_frob > 10` requires `‖Sigma_hat‖ > 9‖Sigma_true‖`, so the detector is
structurally blind to contraction. Recomputed from `dev/totoro-grid/results/grid.csv`, JJ's signed
scale `tr(Sigma_hat)/tr(Sigma_true)` runs 1.670 → 1.015 → 0.857 → 0.780 across n = 40/100/200/400
— through 1 and still falling. GH is not innocent either: **4.302 at n=40**, which is why the fence
sets `n >= 100` as a hard error rather than a warning.
## 2026-07-31  The AGHQ small-n runaway is an OPTIMISER FAILURE, not the MLE — every "AGHQ alone" number is single-start

Decision: record, from 120 fits through the SHIPPED engine (#843, PR #870), that the AGHQ
runaway at n = 100 is substantially an optimiser artefact, and that the fix already exists in
the code, switched off. This **withdraws the empirical basis** for the in-source claim at
`R/fit-multi.R:5314-5318` that "the runaway IS the maximum-likelihood solution -- ties in
40/40". That investigation (`09C-truthstart.csv`) ran on `dev/aghq-r-reference.R`, invalidated
at `decisions.md:1706-1709`. Re-run on `gllvmTMB()` itself, in exactly the `aghq` arm of
`18-shipped-engine-campaign.R` (n=100, p=6, q=2, binomial, `aghq = 9`, `aghq_ridge = Inf`,
40 seeds), **the objective ties in 13/40, not 40/40 -- and 0/16 on the catastrophic seeds.**

**On the 16/40 seeds with ||Lambda_hat||/||Lambda|| > 5, the runaway is not the MLE, 16/16.**
Started at the truth the same engine reaches a strictly better objective by 1.14-12.94 nll
(median 4.70) and median frob 16.23 -> 2.12. Where the default fit is already fine the two
arms agree and the objective is genuinely flat, so the start is the whole story exactly where
it fails.

**The fix needs no new idea.** The truth-free alternative start the engine already builds
(`R/fit-multi.R:5296-5313`) is discarded under `aghq_ridge = Inf` because the selection at
`:5321` is gated on a finite tau. Run to convergence it recovers the lost optimum 16/16,
median gap closed 1.00. Best-of-both (run both, keep the better FINAL objective -- not the
start-point objective, which is the weak proxy that made the unpenalised case look unfixable)
takes catastrophic fits 16/40 -> 1/40 and matches the truth start's objective without using
the truth (381.433 vs 381.434). Altstart is worse on 6/40, so the rule is multi-start, not
"always use the alternative".

**Consequence, binding on future citation:** `aghq_ridge = Inf` IS the `aghq` arm of every
campaign in `dev/aghq-evidence/`, so **no "AGHQ alone" small-n number may be cited without the
single-start caveat**, including the 73%-runaway-at-n=100 headline in #842/#843. "AGHQ alone
is worse at small n" cannot stand as measured.

**Not decided here:** whether to ungate the selection. That changes fitted results for every
`aghq_ridge = Inf` fit and is the maintainer's call (#843). **Not established here:** anything
at n >= 400, any other family, the default grammar, or whether the AGHQ argmin is *good* --
this slice says where the optimiser lands, not whether the answer is right. Residual moderate
runaway survives the start fix (65% -> 52%, and 48% from the truth) and is unexplained.

Two secondary findings, both in-source comments that now mislead and neither changing
behaviour: (1) `aghq_multistart` is read at `:5308` but `gllvmTMBcontrol()` never produces it,
so the documented off-switch is dead and it mislabels `19-warmstart-vs-flatness.R`'s
"discriminating arm" -- same class as D2/#844, filed as #871; (2) the `MEASURED (Totoro, 954
fits)` table justifying the ridge's tau = 2 at `:4997` is from the invalidated reference AND
is contradicted in direction by the shipped engine (it says Laplace runs away MORE than AGHQ,
50% vs 13%; `18-shipped.csv` measured laplace 47% / aghq 73%) -- routed to #847, where it
implies the tau recalibration should be sequenced AFTER the start decision or it will be
calibrated to compensate for an optimiser bug.

Evidence: `docs/dev-log/audits/2026-07-31-aghq-truthstart-shipped-engine.md`,
`dev/aghq-evidence/22-truthstart-shipped.R`, `23-altstart-shipped.R`. Results LOCAL (D-50).

## 2026-07-31  The AGHQ estimator campaign is DESIGNED and BLOCKED — the loop cannot certify convergence at n >= 400

Decision: record the ADEMP campaign design as pre-registered and turnkey, and record that
it must NOT run yet, for a measured reason rather than caution.

**The design** (`docs/design/2026-07-31-aghq-estimator-campaign-ADEMP.md`) follows Morris,
White & Crowther (2019) and the Williams et al. (2024) 11 reporting items. Five arms fitted
to the SAME data per replicate (PAIRED -- 2.2x tighter than unpaired, which is how
n_sim = 400 was justified from a real 40-seed pilot rather than habit). The primary estimand
is the ROTATION-INVARIANT trait correlation, because Lambda is identified only up to
rotation. Contrasts are LIKE-FOR-LIKE on the penalty and `aghq_ridge` vs plain `laplace` is
BANNED by pre-registration as the confound #842 named. `Lambda_hat` is stored for every fit,
so the primary estimand remains a post-hoc choice. Arm `aghq_ms` is DERIVED
(`min(aghq, aghq_alt)` on the final objective), so the campaign costs 5 fits per replicate,
not 6. The acceptance rule is fixed in advance with an EQUIVALENCE branch, so "no practical
difference" is a conclusion rather than a failed test, and four predictions are
pre-registered with P2's failure named in advance as a publishable, lane-closing result.

**The blocker (#874).** The smoke test showed the AGHQ loop reports convergence in **0% of
fits at n = 400 and n = 1600**, and 0-2.5% at n = 100, under the engine's own criterion.
Two parts, both binding on future work:

 1. **`opt$convergence` is the WRONG FIELD on the AGHQ path** -- it is nlminb's code for the
    per-pass iteration cap from the continuation schedule and returns 1 on a healthy fit.
    The engine's verdict is `aghq$stop_reason`; only a value beginning "converged" counts.
    **No future AGHQ convergence number may be taken from `opt$convergence`.**
 2. **`aghq_grad_tol` is a FIXED 1e-4 while the gradient at the stop grows ~sqrt(n)**
    (median max|grad| 1.39e-4 -> 2.68e-4 -> 6.72e-4 at n = 100/400/1600; step ratios 1.93
    and 2.51 against an n-ratio of 4.00). Under a tolerance scaled 1e-4*(n/100), 27/27
    near-misses at n = 400 and 34/37 at n = 1600 would clear. Same class as #847 (tau = 2)
    and the #857 inventory, and the worst instance so far: it does not bias an estimate, it
    stops the engine certifying convergence in the regime the method is for.

**Consequence, binding:** the campaign's converged-only analysis population -- the one that
answers "is AGHQ a better ESTIMATOR" rather than "does the AGHQ code emit better numbers" --
is EMPTY at every n. Running the 16,000 fits now returns a full table tagged
OPTIMISER-LIMITED, comparing Laplace AT ITS OPTIMUM against AGHQ SOMEWHERE. The design does
not change; the sequence does: fix the tolerance and have the stalled branch report its
gradient (engine changes, maintainer's call), then run.

**Not claimed:** that the fits are bad (accuracy is a separate axis); that the stopped
points are true optima ("mode fixed, objective stagnated" plus a small tolerance multiple is
supportive, not a certificate); that sqrt(n) is a derived rate (it describes three points).
The `stalled at cap 1` branch does not report its gradient, so a third of the fits are
unclassifiable from outside the engine and the counterfactual is a LOWER bound.

Evidence: `docs/dev-log/audits/2026-07-31-aghq-convergence-nladder.md` (270 fits; 150 on
Totoro in its own lane dir, Codex's design90/91 untouched). Results LOCAL (D-50).

## 2026-07-31  Three AGHQ engine fixes land — and multi-start selection is only as good as the objective it ranks on

Decision: record the three fixes (#843, #871, #874, PR #875) and, more importantly, the
correction that emerged while making them.

**#843 -- multi-start.** AGHQ ran from ONE start under `aghq_ridge = Inf`. Both starts now run
to convergence and the better fit wins. Catastrophic fits **16/40 -> 1/40**; seed 2003 frob
29.700 -> 2.365, objective 379.7134 -> 375.179. **#871 -- `aghq_multistart`** was read but
never produced by `gllvmTMBcontrol()`; it had to be made reachable BEFORE the default could
change, and `FALSE` reproduces the old answer exactly. **#874 -- convergence.** The gradient
tolerance was ABSOLUTE while the gradient grows with the data, so convergence was unreachable
at scale (0% at n = 400 and n = 1600, in three families). A RELATIVE leg, OR-ed with the
absolute one so it can only ever ADD convergent cases: n=100 8.3% -> 25%, n=400 0% -> 58.3%,
with the estimates **byte-identical** -- a criterion fix must change the verdict, not the
answer.

**THE CORRECTION, and it is binding on future work.** "Select the better final objective" --
this lane's own recommendation two slices earlier -- is INCOMPLETE. Selection is only as
trustworthy as the objective it ranks on. Measured on the q = 2 golden fixture at **k = 3**:
the alternative start reached a LOWER AGHQ objective (1.884065 vs 1.909543) at a point where
the k = 3 quadrature is wrong by **0.107** against an independent nested-`integrate()` oracle,
while the warm start sat at 2.9e-09 from it. **The optimiser had exploited quadrature error**
-- the same shape as a runaway exploiting Laplace's error, which is the failure this lane
began on. At k = 5, 7, 9 the two starts agree to the last digit, so the trap is specific to a
grid too coarse to be believed. Ranking is now on **(converged, objective)**; when both runs
agree on convergence it reduces exactly to the objective comparison.

**Two consequences that generalise beyond AGHQ.** (1) Any multi-start or model-selection rule
that ranks on an APPROXIMATE criterion inherits that approximation's error, and fails silently
because the criterion reports success. (2) The campaign's own evidence base could never have
caught this -- it uses k = 9, where the quadrature is accurate. Only a fixture whose ground
truth comes from OUTSIDE the machinery did. Keep at least one such oracle in any estimator
validation.

**Also binding: state which suite number you mean.** The AGHQ suite reports **105** assertions
with skips active and **1571** with `NOT_CRAN=true`. The k = 3 regression was hiding in that
15x gap. Full suite on the final state: **9012 assertions, 0 failures**.

**Not decided here:** whether the campaign may now run. #874 was its blocker and is cleared,
but n = 400 convergence is 58%, not 100%, and the residual STALLS are a separate, unfixed
question -- the new gradient reporting shows they sit at ~50x tolerance, so they are genuinely
not near-misses. The campaign must be RE-GATED on a fresh smoke before 16,000 fits are spent.

Evidence: `docs/dev-log/after-task/2026-07-31-aghq-engine-fixes.md`. Results LOCAL (D-50).

## 2026-07-31  Gate 3 reports — estimator JJ, rule R2, fence q<=2. And two reporting passes were wrong before a panel caught them.

**Maintainer decisions, Shinichi Nakagawa, in session**, on the corrected Gate 3 result
(`docs/dev-log/2026-07-31-gate3-result-corrected.md`): **(1) estimator = JJ; (2) rule = R2 (paired
exclusion); (3) fence at `q <= 2`.**

**This supersedes the 2026-07-30 "Estimator: GH quadrature, not the JJ/Pólya-Gamma bound" entry
above**, which is left in place as the dated record of what was believed before the campaign ran.
That reasoning was principled — JJ's objective is coercive in `‖Λ‖`, so its clean degeneracy record
was a theorem before a fit ran, and the `rel_frob > 10` detector is structurally blind to
contraction. The measurement disagreed anyway. **That is what the gate was for.**

**What Gate 3 measured.** 2,160 datasets × 3 arms = 6,480 fits, known truth, fixed rank, full
denominators, no filtering on status or admitted, run on Totoro
(`docs/dev-log/2026-07-31-gate3-totoro-migration.md`). Under R2, `va_jj` passes the RMSE criterion in
**every cell** (50/50; 54/54 raw) with a worst gap of 0.0393 against a 0.05 tolerance, and holds the
lower `Sigma_B` error in 52 of 54 cells ignoring Laplace entirely (sign test p = 1.7e-13) — in all
eleven leave-one-out subsets over truth, q, p and n. `va_gh` passes 13/50. **`va_jj` clears the full
frozen conjunction in 100% of `q <= 2` cells under BOTH pre-declared rules** (36/36, 34/34), so the
shipped boundary does not depend on the recorded §11 departure.

**`q <= 4` was refused on its own terms.** The 2026-07-31 scope freeze admitted it *conditionally* —
"only if Gate 3's q = 4 cells pass on their own terms." Every `va_jj` axis-collapse failure sits in
the single `q = 4, p = 8` corner at rates 0.26–0.77 against a 0.05 tolerance, every lower 2·MCSE
bound above the threshold. Four latent axes are not identifiable from eight responses. **The fence
ships at `q <= 2` — narrower than hoped, and further from A3's 5+ factors, not closer.**

### 🔴 The reporting failed twice before the numbers were trustworthy

Recorded because the errors are more transferable than the result.

1. **A conjunction reported as one half.** The first pass reported "va_jj passes 50/50" — that is
   `pass_rmse` alone. The frozen rule is RMSE **and** collapse.
2. **A pooled median hid the signal.** κ was said to "clear the contraction worry" from a pooled
   median of 1.68, while a real JJ contraction subgroup (`T-strong × n=400`, median κ 0.74) sat
   underneath it. Exactly the *check the gradient any pooled summary pools over* failure already in
   this repo's ledger.
3. **Then an over-correction.** Told GH scored better on the collapse half, the second pass declared
   "a genuine crossover, neither arm wins." Also wrong — and **declining a conclusion the evidence
   supports is a defect symmetric with overclaiming.**

A **D-43 panel of three fresh reviewers returned 3/3 NOT-DONE**, and an independent reimplementation
then reproduced every shipped number to float precision. **The analyser's arithmetic was never in
doubt; the reporting was.**

### The collapse criterion cannot rank the two arms — do not cite it as if it can

`any_axis_collapsed` is TRUE **zero times in 6,480 rows** for `va_gh`. Not rare — never. Its
degenerate solutions are intercepted upstream by a variance-domain guard that **`va_jj` does not have
at all**, and those rows are then removed from the collapse denominator by `status == "ok"`: va_gh
loses 39.4% of attempts from that denominator, va_jj 28.2%. Under the alternative denominator the
direction **flips**. The two arms are not measured with the same instrument on that criterion.

Also killed: "fails collapse in ~18% of cells" is **not** "above the 5% tolerance" — the tolerance is
a **per-cell rate**, and `va_jj`'s pooled collapse rate is **4.45%**, below it.

### Three analyser defects fixed, all one family

An undefined value silently becoming a verdict: R2 **dropped 4 cells outright** where the ML
comparator was degenerate in 40/40 replicates (breaking the both-rules-every-cell commitment *and*
hiding a finding about Laplace); `is.finite(x) & x <= tol` scored 6 **unmeasured** cells as failures;
and `max_abs_gradient` was computed by the engine and dropped by the row builder. The second was
found only because the first was fixed inconsistently — same bug, one function away.

**Not supported by this evidence, and not claimed:** any interval or coverage statement
(`calibrated = FALSE`); anything at `q >= 3`; anything at `n = 400, p = 80`, where the usable-fit
rate is 6% and the RMSE is a survivor statistic; and poisson-log, which the fence admits on
theoretical grounds but Gate 3 never tested (the campaign was Bernoulli).

> Register: `docs/design/35-validation-debt-register.md` Section 15 (VA-01..VA-09).

## 2026-08-01 -- Spatial helpers are independently authored; range plots remain isotropic

This decision supersedes historical statements that gllvmTMB's R-side mesh,
CRS, or anisotropy helpers are inherited from sdmTMB. `R/mesh.R`, `R/crs.R`,
and `R/plot.R` are now independently authored against the published SPDE/GMRF
construction and public fmesher/sf APIs. Valid legacy `sdmTMBmesh` objects are
accepted temporarily through a warning-and-normalization bridge, but new
objects are `gllvmTMBmesh`. sdmTMB is acknowledged as inspiration for the
original interface and may be used only as an isolated post-implementation
black-box comparator; it is not a required citation, runtime dependency, or
implementation source.

The native TMB engine remains isotropic: it reports scalar `kappa`, not an
estimated anisotropy matrix `H`. Consequently, `plot_anisotropy()` and
`plot_anisotropy2()` draw the practical-range circle `sqrt(8) / kappa`, label
`H = I` as a model assumption, and report
`anisotropy_estimated = FALSE`. Unequal-axis anisotropy remains deferred until
the likelihood estimates the necessary directional structure. See
`docs/dev-log/research/2026-08-01-independent-spatial-helper-literature.md` and
`docs/dev-log/plan-actual/2026-08-01-independent-spatial-helpers.md`.

## 2026-08-16 -- The integrated worked example keeps its non-positive-definite fit

Maintainer decision (Shinichi, 2026-08-16): *"keep the WARN fit - it's honest."*

`vignettes/articles/integrated-two-source-example.Rmd` fits the two-source
integrated model on 108 cells and `check_gllvmTMB()` reports
`pd_hessian = WARN` -- the optimizer reaches a stationary point whose Hessian
is not positive-definite. The article runs that check, shows the WARN, and
explains it rather than omitting the diagnostic it tells readers to run.

**Do not "fix" this by changing the model, the design size, or the seed.** The
warning is the honest state of a small illustrative fit, and it carries real
teaching load:

- It is localised by measurement, not hand-waved. Refitting the same data with
  the spatial terms replaced by an ordinary non-spatial `latent()` block
  returns `pd_hessian = PASS`. The integrated likelihood is not the
  difficulty; the spatial fields at this design size are.
- That is the same conclusion the domain-growth campaign reaches from 1,600
  fits, and it is why `vignettes/articles/integrated-survey-design.Rmd`
  exists. The two articles are complementary because of this warning, not in
  spite of it.
- Making the example pass would require either dropping the augmented
  `spatial_latent(1 + isdm_gbif | ...)` slope -- which is precisely the route
  the public admission opened, so nothing public would exercise it -- or
  growing the design past what an article can render. Neither trade is worth
  a cleaner-looking fit.

The register row `ISDM-01` stays `partial` for the same reason: the spatial
arm's evidence is campaign experience, not a cleared recovery gate.

## 2026-08-17 -- MSPL interval triad Confirm SIGNED under D-157 (no new D-)

Shinichi authorized paste Confirm (via chat: *"paste Confirm for me"*; recorded by cursor/Shinichi-via-chat, 2026-08-17).

> **Confirm MSPL interval triad for the new construction:** Profile = signature / primary claim path; Wald (\(Q_0\)) = quickest baseline / availability check (not the brand; not Design 118 reopen); Bootstrap = asymmetry / non-symmetric sampling. SE pins stay D-149. No Totoro. No public `se=TRUE` without separate G0.

This is **not** a new decision id. Brain **D-157** already requires later intervals = new construction + new pre-registration; **D-12** already makes profile the featured/hero CI. The paste locks the **roles** of the triad for that construction. Card: `docs/dev-log/research/2026-08-17-mspl-ci-wald-plus-profile.md` (**SIGNED**). Hard stops unchanged: no Design 118 reopen, no B1/Totoro, no public `se=TRUE`, #1077 stays draft until a later Design+pre-reg sitting. Poisson \(W\) G0 (`2026-08-17-mspl-poisson-W-G0.md`) stays **UNSIGNED**.


## 2026-08-17 -- Design 125 + ADEMP pre-reg SIGNED; Poisson W PARK SE doors (no new D-)

Shinichi authorized *"approve all things in this lane"* for `mspl-profile-led-ci`
(via chat / interrupt paste; recorded by cursor/Shinichi-via-chat, 2026-08-17).

> **SIGNED block:** G1 PARK SE doors · G2 OPEN-READY-PR · G3 WAIT · G4a BINARY-FIRST ·
> G4b E1-E2-ONLY · G4c FORK-DEFER · G4d THRESHOLDS-SIGN-NOW · G4e BOOT-PARAMETRIC.
> Still NOT: undraft #1077 · Totoro · public `se=TRUE` · Design 118 reopen.

This is **not** a new decision id. Brain **D-157** already requires later intervals =
new construction + new pre-registration; **D-12** already makes profile the featured CI.
Design **125** is the approved programme stub for that construction; the ADEMP pre-reg
(`docs/dev-log/research/2026-08-17-mspl-profile-led-prereg-ademp.md`) is signed with the
Ada/Ranga defaults above (binary-first; L* thresholds frozen; fork deferred; parametric
bootstrap). Poisson \(W\) card
(`docs/dev-log/research/2026-08-17-mspl-poisson-W-G0.md`) is **SIGNED PARK SE doors** —
freezes new SE-series doors; tape unchanged; KEEP/REPLACE remain future choices only.
Hard stops unchanged: #1077 stays draft; MSPL-04 blocked; no public `se=TRUE`; no Totoro
from this sign.


## 2026-08-18 -- iSDM: campaign approved+run, flagship taxon PICKED, #1125 merge authorized

Shinichi (chat, 2026-08-18): *"1 approve 2 do it and 3 merge"* against the three
🔴 asks in PR #1125.

1. **Interval-campaign proposal APPROVED as scoped** (§5 of
   `docs/dev-log/research/2026-08-17-isdm-interval-campaign-proposal.md`):
   smoke ran (12/12 conv, all PD reps pass), estimate came in far under the
   30-minute line, and the 16-cell x 100-rep feasibility grid ran on Totoro
   same-day (1,600 fits, 56.5 s wall, 100 cores). Results:
   `dev/isdm-intervals/2026-08-18-feasibility-results.md` — E1 near-nominal
   (full pre-registered campaign justified), E4 `se.fit` measured NON-viable
   as an eta interval (0.23-0.82 coverage), E2 amplitude interval = new
   construction, E3 not computable. No register row moves; no public claim.
2. **Flagship taxon: Canada Warbler (Cardellina canadensis), ABMI + GBIF**,
   adopting Jason's pick from
   `docs/dev-log/research/2026-08-17-isdm-flagship-candidates.md`
   (runner-up Wood Thrush/BBS). Candidates remain UNVERIFIED until data are
   actually pulled; verification is the flagship arc's first slice.
3. **PR #1125 merge authorized** (probe + tests + Design 126 + ISDM-03), and
   with it the Design 126 §5 issue filings (A: three predict-newdata defects;
   B: prediction-map API).

## 2026-09-02 — Zero-inflated families approved; gap-closure PRs merged in order (Shinichi; vault D-207, D-204)

Verbatim: *"approve all four points, merge #1239 then #1240."* The four ARC D1 points approved as built:
(1) `zi_poisson()` / `zi_nbinom2()` / `zi_binomial()` carry a per-trait, intercept-only zero-inflation
probability on the logit scale; latent variables and the covariance grid act on the count linear
predictor only (Design 62 Decision 2); (2) `zi_binomial()` requires trials ≥ 2 and names `binomial()`
otherwise; (3) AGHQ declines these families to Laplace with a reason-specific warning, VA and MSPL
refuse; (4) FAM-22 stays `partial` with the measured 2/6-trait dispersion caveat. Standing rule
behind it (D-204): twin parity is both ways for user-facing capabilities; the bridge stays R → Julia.
Owed before any FAM-21..23 row leaves `partial`: Totoro pre-run then DRAC job-array multi-seed recovery
against GLLVM.jl's ADEMP campaign.
