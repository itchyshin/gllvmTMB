# After-task: Strategic plan revision -- 2026-05-14

**Tag**: `plan` (no repo source change; private plan-file
revision + this dev-log artifact).

**PR / branch**: this PR / `agent/after-task-strategic-plan-revision`.

**Lane**: Claude (Ada-adjacent: orchestrator-level planning;
no Codex lane touched).

**Dispatched by**: maintainer 2026-05-14 -- a sequence of
asks across several messages: *"can you actually list things
to do -- and what is your final goal for this package -- how
many steps and phases before we get there?"*, then *"please
just stop and think"*, then *"I want you to revise your
plan you talk to your team; it's the best you can do"*, then
*"every now and then you should plan to do some research,
literature research, research into archive or latest
algorithm"*, then *"I didn't really see some clear plan for
maybe profile likelihood and its test"*, then *"maybe
algorithmic improvement, speed improvement"*, then *"you
need to make sure everybody has memory, memory is improved
as we go"*.

**Files touched**:

- `~/.claude/plans/please-have-a-robust-elephant.md` -- heavy
  revision (1157 lines; was ~365 lines pre-session).
  Outside the repo (Claude's private plan space), so changes
  are not tracked here.
- `docs/dev-log/after-task/2026-05-14-strategic-plan-revision.md`
  -- this file (new).

No source, no rules, no API, no article, no math, no CI
config change.

## Math contract

No public R API, likelihood, formula grammar, family,
NAMESPACE, generated Rd, vignette, or pkgdown navigation
change.

## What changed

The strategic roadmap to first CRAN release of `gllvmTMB`
0.2.0 was rebuilt from a defect-tracking list (12-17 PRs
first-pass) to a comprehensive 36-44-PR plan with **5
strategic pillars** (P1-P5) plus **3 cross-cutting themes**
(P6-P8) added today, **5 design decisions** resolved (D1,
D2, D4, D6, D7), and **phase-by-phase team-contribution
tables** specifying which of the 13 standing-roles personas
leads + supports each phase.

Three team-consult rounds today (read-only Explore agents
role-playing AGENTS.md personas):

- **Round 1** (~16:00 MT): Pat, Curie, Rose.
- **Round 2** (~17:00 MT): Fisher, Darwin (maintainer named
  in original ask; missed in round 1).
- **Round 3** (~18:00 MT): Jason, Gauss, Fisher (second
  pass) -- triggered by maintainer's literature/algorithm/
  profile-CI requests.

Substantive plan additions from each round are recorded in
the plan's "Team-review log" section.

## Checks run

- Read the plan file end-to-end after each edit pass.
- Cross-checked Phase 1 PR-count breakdown against the
  listed sub-phases (1a, 1b, 1b', 1c, 1d, 1e, 1f) -- sums to
  the headline 25.
- Verified the 13-member AGENTS.md roster is consistent with
  the phase-by-phase contribution tables. Shannon is in.
- Verified the open decisions (D3, D5, D8) have stated
  default-leans so execution is not blocked.

## Consistency audit

Stale or imported wording: none introduced. Plan continues
to use the canonical S/s math notation, the paired-or-
three-piece phylo phrasing, and the canonical persona
names. The "two-U" task-label nickname is preserved only
where it refers to existing function names.

In-prep paper citations: only where engine-specific (e.g.
the methods paper). Cross-references to published literature
(Hui et al. 2015, Niku et al. 2017, Westneat et al. 2015,
Pawitan 2001, Venzon & Moolgavkar 1988) routed through the
relevant articles.

## Tests of the tests

This is a plan revision, not an implementation. No tests
added. The plan's own Phase 1b' Profile-Likelihood
Validation milestone adds tests of the tests (the empirical
coverage study), but that test surface lands in Phase 1b'
itself, not here.

## What went well

- **Three team-consult rounds in one day** produced a far
  more comprehensive plan than the initial 12-17-PR sketch.
  Each round surfaced gaps the previous rounds missed: Pat
  caught jargon traps + decision-tree weakness; Curie
  designed the simulation-verification pedagogy article;
  Rose caught Phase 1 PR-count drift (16 -> 18 -> 21 -> 23
  -> 25 across consults); Fisher first-pass added
  `check_identifiability()` + `check_auto_residual()` +
  expanded edge-case tests; Darwin caught the biology-first
  framing gap and proposed 4 post-CRAN applied-ecology
  articles; Jason proposed the once-per-phase-boundary
  landscape-scan cadence; Gauss confirmed the engine is
  performance-adequate and scoped 6 algorithmic alternatives
  as deferred post-CRAN; Fisher second-pass identified the
  missing Profile-CI validation milestone gap.
- **Maintainer iterations on the $\Omega$ formula** (now
  resolved in plan + PR #77) demonstrated that amending the
  open PR while CI is still running is cheaper than
  follow-up PRs.
- **Memory / continuity design** codified as 5 layers
  (durable canon + per-PR + per-phase + per-audit + working
  state). The phase-by-phase team-contribution overview
  table makes each persona's accumulated contributions
  trackable by phase boundary.
- **Phase 1b' Profile-Likelihood Validation milestone** is
  a meaningful new artifact: empirical coverage study +
  `confint_inspect()` interactive tool + troubleshooting
  decision tree. Closes the gap the maintainer flagged
  ("I didn't see a clear plan for profile likelihood and
  its test"). Exit criterion (>= 94% empirical coverage per
  family on Gaussian / NB2 / ordinal-probit) gives CRAN
  reviewers a paper trail.

## What did not go smoothly

- **First-pass team consult missed Fisher and Darwin** even
  though both were named explicitly by the maintainer. I
  substituted Curie (relevant to the simulation question)
  but didn't realise until the maintainer asked me to
  re-read what was said. Lesson: when the maintainer names
  N personas, consult exactly those N personas; do not
  substitute even if a different persona seems "more
  relevant" to one of the asks.
- **Nathan and Amy ambiguity** -- maintainer named them in
  the team list, but they aren't in AGENTS.md. Resolution
  required a question to confirm they were typos.
- **/goal skill ambiguity** -- maintainer asked for "/goal"
  but no skill is named exactly that; six "goal"-named
  candidates exist. Project-local install of
  `refoundai/lenny-skills@setting-okrs-goals` succeeded;
  global install was correctly blocked by the classifier as
  Untrusted Code Integration from an unverified third-party
  source. Currently parked pending maintainer direction on
  which goal-skill is wanted.
- **Plan-mode exit interaction** -- the maintainer rejected
  the first ExitPlanMode attempt with "more to say"; I
  initially missed that and needed a second exit attempt.
  The plan-mode workflow expectation is single-shot exit
  after all clarifications resolved; iterative
  clarification within plan-mode is supported via
  AskUserQuestion. Adjusted mid-session.

## Team learning, per AGENTS.md role

Three rounds engaged 8 personas (Pat, Curie, Rose, Fisher,
Darwin, Jason, Gauss, Fisher-second-pass). Boole, Noether,
Emmy, Grace, Shannon, Ada (the maintainer) and the
persona-of-Claude (orchestrator-level Ada-adjacent) engaged
in the plan structure but did not have their own consult
agents. Per-persona learnings:

- **Ada (maintainer)**: surfaced the planning gap with a
  one-line question ("how many steps and phases?"), then
  iteratively expanded the scope as the team consults
  surfaced findings. Pattern: maintainer asks open-ended,
  Claude consults team, plan grows, maintainer reviews +
  ratifies decisions. This cycle worked well within a
  single day.
- **Boole** (not consulted this round): will engage heavily
  in Phase 1c article ports (formula grammar + paired
  keywords) and Phase 2 export audit. Standing brief: stays
  alert for formula-syntax drift in any rewritten article.
- **Gauss** (consulted round 3): engine audit found
  numerical stability sound; identified `mu_t` finite-check
  polish for Phase 5; documented 6 deferred algorithmic
  alternatives so the team has a backlog when a user reports
  a slow path. Standing brief: re-engage if any test fixture
  exceeds CI budget or if a user reports T > 20 or
  n_species > 500 lag.
- **Noether** (not consulted this round): math-vs-syntax
  alignment will be re-engaged in Phase 1b for
  `extract_correlations()` `link_residual = "auto"` change
  (does the implementation match the equation in the
  vignette?).
- **Darwin** (consulted round 2): biology-first framing
  gap caught in `morphometrics.Rmd` and
  `functional-biogeography.Rmd`; 4 post-CRAN applied-ecology
  article candidates (`temporal-trait-change`,
  `plasticity-across-gradients`, `occupancy-codetection`,
  `spatial-species-trait-landscape`). Standing brief: every
  worked-example port goes through Darwin's biology-first
  reading; new articles open with the biological question,
  not the model machinery.
- **Fisher** (consulted rounds 2 + 3): added
  `check_identifiability()` (Phase 1b), `check_auto_residual()`
  safeguard (Phase 1b), 4 new profile-CI edge-case tests
  (Phase 1b), profile-curve anatomy section in
  `simulation-verification.Rmd`. **Round 3**: identified
  the missing Profile-CI validation milestone (Phase 1b');
  proposed empirical coverage study + `confint_inspect()` +
  troubleshooting decision tree. Standing brief: every
  inference-related PR goes through Fisher; coverage study
  is the CRAN credibility gate.
- **Emmy** (not consulted this round): S3 method coherence
  will be checked in Phase 1b (`extract_correlations()` API
  change) and Phase 2 (export audit). Standing brief: each
  extractor change is read for return-type consistency and
  print-method coverage.
- **Pat** (consulted round 1): caught hidden jargon traps
  in `covariance-correlation.Rmd`, `response-families.Rmd`,
  `choose-your-model.Rmd`. Recommended a new "GLLVM
  vocabulary" Concepts article + a "data shape flowchart"
  Concepts article; both adopted (D6 resolved). Standing
  brief: every article port goes through Pat for jargon /
  navigability / decision-tree readiness.
- **Jason** (consulted round 3): proposed once-per-phase-
  boundary landscape scan cadence (~30 min × 5 phases).
  Output: `docs/dev-log/audits/YYYY-MM-DD-phase-X-landscape-
  scan.md` with algorithmic gaps + sister-package changes +
  top borrow opportunities. Standing brief: file a scan
  before each phase opens; consider sdmTMB barrier-mesh
  developments + galamm's CFA addition for Phase 6.
- **Curie** (consulted round 1): designed the
  `simulation-verification` pedagogy article (Concepts
  tier); identified profile-CI edge-case test gaps; scoped
  recovery-test gating + reorganisation for Phase 4.
  Standing brief: every recovery test PR goes through
  Curie; DGP fixtures are her lane.
- **Grace** (not consulted this round): CRAN-readiness
  pipeline owner for Phase 5 (DESCRIPTION + WORDLIST +
  vignette budget + cran-comments + rhub/devtools/win
  checks). Standing brief: Phase 5 will be Grace-led; the
  current advisory-CI / 3-OS / pkgdown-after-CMD-check
  pipeline is hers.
- **Rose** (consulted round 1): caught Phase 1 PR-count
  drift; flagged Phase 1 close gate buried under
  end-to-end verification; flagged Nathan/Amy ambiguity;
  flagged PR #81/#82 dependency status; flagged Priority 2
  export audit source not cited. Standing brief: every PR
  gets a Rose pre-publish audit; phase boundaries get a
  fuller Rose sign-off.
- **Shannon** (not consulted this round): cross-team
  coordination audits when Codex returns ~May 17. Standing
  brief: Shannon runs at the end of each phase (1a, 1b, 1c,
  ...) and whenever more than one PR is open across teams.

## Design-doc + pkgdown updates

None this PR. Plan file is not in the repo. The phase-by-
phase team-contribution table could eventually move to
`docs/design/11-task-allocation.md` as a permanent home,
but for now it lives in the plan file alongside the
strategic roadmap.

## Known limitations and next actions

**Known limitations**:

- `/goal` skill install pending maintainer direction on
  source. Project-local `setting-okrs-goals` installed but
  not symlinked globally.
- Plan file at ~/.claude/plans/ is Claude's private space;
  Codex doesn't read it directly. Codex coordinates via
  `docs/dev-log/coordination-board.md`. The strategic
  roadmap content is accessible to Codex by reading the
  in-repo dev-log artifacts (decisions.md, ROADMAP.md,
  audit docs, this after-task).
- Phase 1a / 1b are gated on Codex's return (~May 17). No
  action on R/ until then.

**Next actions**:

1. Wait for PR #83 (yesterday's evening-sweep retrospective)
   to clear CI; self-merge when green.
2. Wait for Codex to return (~2026-05-17). When Codex is
   back, dispatch Phase 1a (Batches A + B) and Phase 1b
   (P1 fix + P2 mixed-family tests + Fisher diagnostics +
   edge-case CI tests).
3. After Phase 1b lands, dispatch Phase 1b' Profile-CI
   validation milestone (Fisher lead).
4. Phase 1c article-port programme starts after Phase 1b'
   exits.
5. Jason's first landscape-scan files before Phase 2 opens.
