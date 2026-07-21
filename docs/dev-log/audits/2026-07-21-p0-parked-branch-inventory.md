# P0 parked-branch inventory receipt

**Timestamp:** `2026-07-21T12:19:23Z`
**Active builder HEAD at inventory:** `580e9801842b8edc88e93572f6fcef10ce5cd7b3`
**Active branch:** `codex/gllvmtmb-060-m1-baseline-20260720`
**Unique commits reachable from local branches but no remote:** `252`
**Local branches with at least one such commit:** `141`
**Sum of per-branch counts:** `259` (larger than 252 because some commits are reachable from more than one branch)
**Canonical sorted mapping SHA-256:** `cc0ebe1982dbeca00bd0024cb4fab73cc8c1ad8c83503f170c4abe97eb750f97`

## Purpose and disposition

This is the reproducible inventory behind the repository-wide handoff gate's
`252 UNPUSHED on other branch(es)` result. These branches predate the active
M1 programme and are not artifacts or owners of the current lane. The common
disposition for every row is:

- **State:** `CARRIED-OVER` as quarantined historical state.
- **Why:** outside the active programme's ownership; deleting, switching,
  pushing, or reconciling it would be a separate and potentially destructive
  project.
- **Resume:** `PROHIBITED — separate ownership and maintainer authority
  required.` Claude must not attach to or mutate any listed branch.

The active M1 branch itself had zero commits absent from remotes at this scan.
The final handoff gate must still be rerun after the handoff commit is pushed.

## Reproduction

```sh
git rev-parse HEAD
git rev-list --count --branches --not --remotes
git for-each-ref --format='%(refname:short)' refs/heads | \
  xargs -n 1 -P 16 sh -c 'branch_name="$1"; branch_count=$(git rev-list --count "$branch_name" --not --remotes 2>/dev/null || echo 0); if [ "$branch_count" -gt 0 ]; then printf "%s\\t%s\\n" "$branch_name" "$branch_count"; fi' sh | \
  sort
```

The first count is the unique stranded-commit union. Each mapping row counts
stranded commits reachable from that branch, so shared commits appear in more
than one row.

## Branch mapping

```text
branch	unpushed_count
agent/a1-phylo-unique-slope	1
agent/a1-phylo-unique-slope-v2	1
agent/a1-recovery-test-skeleton	1
agent/ci-concurrency-no-cancel-main	1
agent/coord-board-phase-56-1-handoff	1
agent/coord-validation-factory	2
agent/cross-package-memo-lambda-cleanup	2
agent/day-retro-r200-wording	1
agent/design-55-structural-slope	1
agent/design-56-amend-scalable-names	2
agent/lambda-constraint-chunk-label	2
agent/methods-paper-outline	1
agent/phase-56-5-prespec-note	1
agent/phase-56-5-scoping	1
agent/phase-a-skel-bundle	1
agent/phase-a-skel-remaining	1
agent/phase-a6-prep	1
agent/phase-b-mix-0-link-residual-design	1
agent/phase-b0-nongaussian-scoping	1
agent/phase-b0-per-family-scoping	1
agent/phase-b1-phylo-unique-slope-binomial-probit	1
agent/phase1e-audit-sweep-2026-05-15	4
agent/phase56-1-merge-closeout	1
agent/phase56-2-merge-closeout	1
agent/phase56-3-merge-closeout	1
agent/phase56-4-merge-closeout	1
agent/phase56-5-relmat-unique-slope-2026-05-26	1
agent/set-c-r200-prep	2
agent/structural-slope-phase-a-close	1
chore/worktree-house-rule	1
claude/bridge-finish-20260619	3
claude/bridge-followups-20260619	2
claude/coe-a15-cells	1
claude/coe-b1-ext10	1
claude/coe-b2-metav	1
claude/coe-b3-extcorr	1
claude/coe-b5-truncated	1
claude/coe-c1-plotsnap	1
claude/coe-c2-predcheck	1
claude/coe-d1-animal	1
claude/coe-d2-relowrank	1
claude/doc-examples-20260619	2
claude/input-validation-tests-20260619	1
claude/lvb-modelA-extend	1
codex/api-keyword-grid-status-2026-05-24	1
codex/article-audit-2026-05-20	2
codex/article-binary-lambda-coordination	1
codex/autonomous-surface-wave1-2026-05-24	2
codex/bridge-admission-clean-20260619	2
codex/bridge-gate-registry	2
codex/ci-ignored-docs-fast-path-2026-05-19	2
codex/coevolution-engine-split-20260619	3
codex/convergence-wording-audit-2026-05-24	1
codex/correlation-matrix-plots-2026-05-23	4
codex/covariance-article-closeout-wave3-2026-05-24	1
codex/covariance-correlation-matrix-qa-2026-05-23	1
codex/dep-slope-run32-triage-2026-06-07	1
codex/diagnostic-table-2026-05-25	1
codex/diagnostic-teaching-reset-2026-05-25	5
codex/families-doc-mixed-family_backup	2
codex/fir-slurm-library-smoke	1
codex/florence-covariance-plots-2026-05-21	47
codex/gaussian-reml-pilot-2026-06-09	1
codex/get-started-correlation-matrix-qa-2026-05-23	1
codex/in-prep-citation-hygiene	1
codex/joint-sdm-scope-rewrite-2026-05-25	1
codex/joint-sdm-sigma-heatmap-repair-2026-05-26	4
codex/kernel-c0-coevolution	1
codex/lv-binary-links-20260625	1
codex/m3-3-failure-mode-triage-2026-05-19	2
codex/m3-3-target-explicit-pilot-2026-05-19	1
codex/m3-3-target-scale-audit-2026-05-19	2
codex/m3-3a-nbinom2-corrected-r20-audit-2026-05-20	1
codex/m3-3a-nbinom2-fit-diagnostics-2026-05-20	1
codex/m3-3a-nbinom2-stress-pilot-r10-2026-05-19	2
codex/m3-3a-nbinom2-target-audit-2026-05-19	2
codex/m3-3b-nb2-start-probe-2026-05-20	2
codex/m3-3b-nb2-stress-report-2026-05-20	4
codex/m3-3b-source-map-dashboard-2026-05-20	2
codex/m3-3b-surface-visual-gate-2026-05-20	1
codex/m3-production-artifact-review-2026-05-19	4
codex/m3-production-grid-workflow	1
codex/mixed-family-extractors-refresh-2026-05-26	1
codex/offline-report-checkpoint	6
codex/phase56-1-tmb-promotion-2026-05-26	1
codex/phase56-2-rside-audit-2026-05-26	1
codex/phase56-3-parser-2026-05-26	1
codex/phase56-4-phylo-unique-recovery-2026-05-26	1
codex/pitfalls-balanced-prose-2026-05-24	1
codex/pitfalls-boundary-2026-05-24	1
codex/pitfalls-general-balance-2026-05-24	1
codex/pkgdown-families-index	1
codex/pkgdown-julia-index	1
codex/pkgdown-logo-alpha-size-2026-05-24	1
codex/pkgdown-logo-size-2026-05-24	1
codex/power-pilot-aggregate-report-20260623	1
codex/power-pilot-audit-mini-manifest-20260623	1
codex/power-pilot-audit-mini-runner-20260623	1
codex/power-pilot-chunk-aggregator-20260623	1
codex/power-pilot-chunk-runner-20260623	1
codex/power-pilot-run39-readout-2026-06-07	1
codex/power-pilot-scoring-audit-2026-06-05	1
codex/power-pilot-scoring-ledger-2026-06-06	1
codex/power-pilot-slice-artifacts	1
codex/power-pilot-slurm-smoke-20260624	1
codex/power-pilot-smoke-runbook-20260624	1
codex/profile-ci-article-promotion-2026-06-06	1
codex/psychometrics-irt-figure-scope-2026-05-26	1
codex/public-article-nav-reml-2026-06-09	1
codex/public-diagnostics-2026-05-20	2
codex/public-workflow-polish-2026-06-09	1
codex/re03-nongaussian-s2-sweep-2026-06-05	4
codex/re03-run38-readout-2026-06-07	1
codex/re03-s2-diagnostic-scout-2026-06-06	1
codex/re03-s2-targeted-diagnostic-2026-06-07	2
codex/re03-slope-scale-fixture-2026-06-08	1
codex/reference-cleanup-2026-05-21	1
codex/response-families-boundary-2026-05-24	1
codex/roadmap-claude-coordination-2026-05-24	1
codex/roadmap-post-m3-evidence-refresh-2026-05-19	2
codex/sister-package-citation-hygiene-2026-05-20	4
codex/symbol-syntax-alignment-2026-05-21	3
codex/technical-reference-closeout-2026-05-24	1
codex/troubleshooting-profile-companion-2026-06-06	1
codex/twin-truth-and-issue-map	1
codex/unique-latent-psi-split-20260619	3
codex/v1-contract-drift-20260703	6
codex/visible-article-closeout-wave2-2026-05-24	2
delta-lift	1
deprecate-unique	2
feat/power-pilot-local-engine	1
feat/power-pilot-report-drmtmb-plots	1
fix/local-pilot-balanced	1
missing-data-robustness	1
missing-data-sim-impl	1
missing-data-with-pigauto	1
page-sweep	3
remove-unique-family	4
worktree-agent-a001dee2509c89dc2	1
worktree-agent-a283d56f6868709e7	1
worktree-agent-a6930931ce81e02da	1
```

## Scope boundary

This receipt names state; it does not approve cleanup, push, deletion, merge,
or resumption of any parked branch. It does NOT alter the active M1 evidence
denominator or provide release qualification.
