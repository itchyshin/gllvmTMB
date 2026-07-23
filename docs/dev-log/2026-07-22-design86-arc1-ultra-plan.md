# Design 86 — Arc 1 Ultra-Plan (Gate-0 coordinate freeze + Gate 1 only)

```text
🎯 GOAL — PLATFORM: Codex. Deliver only Design 86 Arc 1 in the isolated
codex/design86-arc1-20260722 worktree: materialise and checksum the tiny Gate-1
fixture file, implement the private EVA algebra prototype and its checks, obtain
fresh adversarial review, and stop. HEADLINE: prove or reject the objective's
algebra and numerical behaviour without changing the shipped Laplace engine.
IN PARALLEL: only the post-build review lenses. DEFER: Gate 2, Gate 3, all
Gate-4 campaign design/compute, public API, and release surfaces. DISCIPLINE:
the shipped src/gllvmTMB.cpp remains byte-identical; no public files change;
every Gate-1 claim has a check receipt; the maintainer alone opens the next arc.
```

## What the brain and repository already know

Design 85 is a closed, read-only NO-GO: only its quadrature, stable-softplus,
and log-Cholesky apparatus may be reused, after a fresh equation-to-code audit.
The approved Design 86 contract proves the sparse-regime EVA objective is not a
bound relative to its exact ELBO; it does not sign the objective relative to the
marginal likelihood. The active Design-86 branch is docs-only relative to the
shipped engine. The separate open PR #780 is the M1 release lane and does not
overlap these files.

## Prior-work sweep receipt

| Surface | Evidence run | Finding | Call forced |
|---|---|---|---|
| Repository | `git status --short --branch`; `git log --oneline -20`; `git branch -a`; `git worktree list`; `git stash list`; `branch_drift_check.sh` | New clean worktree at the approved Design-86 head; other Dropbox checkout is dirty and untouched. | Build only here. |
| Existing apparatus | `rg -n 'va_r3|softplus|Cholesky|AGHQ|EVA' R/va-r3-proto.R inst/tmb/gllvmTMB_va_r3.cpp tests` | R3 supplies only reusable numerical apparatus. | Fresh derivation receipt; do not inherit R3 evidence. |
| Sister repos | `rg -n 'EVA|Korhonen|Gate 1' GLLVM.jl DRM.jl` | No implementation or evidence to resume. | No sister-repo reuse. |
| Brain | `rg -n -i 'design.?86|eva|va_r3' ~/.codex/memories/MEMORY.md`; local Shinichi vault search | Design 85 remains a NO-GO; EVA is an isolated feasibility lane. | Build the genuine Gate-1 gap only. |
| Coordination | `gh pr list --state open --limit 100`; `git log --all --oneline --since='6 hours ago'` | PR #780 is disjoint; no current Design-86 document collision. | Edit Design-86 files only. |

**Verdict:** reuse numerical apparatus; build the standalone EVA objective and fresh evidence;
do not resume any earlier VA/EVA prototype or campaign.

## Decisions locked before build

- The Gate-1 parameter file is `docs/design/86-eva-gate1-parameters.json`, canonical JSON with a
  recorded SHA-256. It contains only tiny algebra fixtures; it does not masquerade as a Gate-4
  campaign freeze.
- The Gate-1 Bernoulli D3 fixture has `q = 1`, predeclared `H = 15/25/61`, and reports its signed
  EVA-minus-AGHQ-marginal difference with no expected direction or pass/fail threshold.
- D4 separately checks the signed EVA-minus-exact-ELBO result using finite differences, analytic
  roots, and a frozen-seed Monte-Carlo remainder check.
- The private template includes a test-only Gaussian identity-link branch solely for the exactness
  identity. No public family, API, or method selector is created.
- Campaign coordinates, 1,000-replicate seed arrays, and both campaign convergence criteria remain
  unavailable until their required Gate-3/optimiser re-derivations; a later Gate-4 campaign file is
  required before any coverage run.

## Slice plan

| Slice | Owner / model / effort | Inputs → output | Dependency and pass condition |
|---|---|---|---|
| S0 | Ada, local implementation | Contract §2.5 → `docs/design/86-eva-gate1-parameters.json`, contract checksum/status, reuse-audit receipt | First. Canonical JSON SHA-256 recorded; no campaign claim. |
| S1–S4 | Ada, local implementation | Contract §§5.1, 5.3, 7 and build brief → `R/eva-proto.R`, `inst/tmb/gllvmTMB_eva.cpp`, `tests/testthat/test-eva-gate1.R` | Sequential shared objective. `random = NULL`; no shared oracle/template code. |
| Mechanical verification | Luna-equivalent scout, low, if available; otherwise Ada records native limitation | Files and test output → file/checksum/scope receipt | After S1–S4. Confirms artifacts, checksums, prohibited-path diff, and non-empty tests. |
| Adversarial completion panel | Gauss/Terra-high (numerics), Noether/Terra-high (math), Rose/Sol-high (scope) | Candidate evidence → three independent default-NOT-DONE verdicts | After mechanical checks. At least two withholds block Arc-1 pass. Fisher's inference lens is included in the numerics brief for the D3 marginal-language boundary. |
| Closeout | Rose/Terra-high plus Ada | `check-log`, after-task report, review receipts | Only after all findings are repaired or honestly carried as NOT-DONE. Stop after reporting. |

The build slices are deliberately not parallelised: they share a single objective and splitting
them would create a code/oracle integration seam. Review is the independent fan-out.

## Verification matrix

1. Bernoulli scalar oracle, isolated KL, and negative-objective convention agree with the template
   to `1e-10`.
2. Test-only Gaussian objective equals its exact Gaussian-VA expression to `1e-10`.
3. TMB autodiff versus central finite differences has relative error below `1e-5`; the small-variance
   value and first derivative are continuous.
4. The frozen `mu × v` grid agrees at GH orders 15/25/61 to `1e-10`.
5. D3 reports all three GH estimates and the observed EVA-minus-marginal difference without calling
   it a bound result. D4 verifies the fourth derivative/root/remainder sign separately.
6. `git diff origin/main -- src/gllvmTMB.cpp` is empty; diffs for NAMESPACE, DESCRIPTION, NEWS,
   `man/`, vignettes, LOOP, and `CLAUDE.md` are empty.

## Closure and stop rule

The check log records exact commands and outcomes, exact stale-wording searches, tests-of-tests
classification, deliberate non-runs, roadmap tick (`N/A` unless changed), issue ledger, limitations,
and engaged roles. The after-task report records the mathematical contract, all created files, and
the Gate-2/3/4 fence. A clean Arc-1 result only permits the maintainer to hand off Arc 2; it is not
an admission, coverage, or public-capability claim.
