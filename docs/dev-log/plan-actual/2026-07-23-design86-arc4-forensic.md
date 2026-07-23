# Plan versus actual — Design 86 Arc 4 forensic decision packet

| Axis | Planned | Actual | Classification |
|---|---|---|---|
| Scope | Private decision packet; no runner, protocol, engine, public, Gate-2 campaign, Gate-3/4, push, or PR work | One private forensic memo plus closeout records; all fences retained | Met |
| Evidence | Compare both immutable artifact chains and the controlled diagnostic harness | Both manifests, results, receipts, V1 contract, Arc-3 report, and harness were read; artifact files were not changed | Met |
| Review | Gauss for numerical boundaries and Rose for provenance/scope | Gauss PASS; Rose required two wording corrections, which were applied | Met |
| Mechanical verification | Luna tiered read-only provenance and wording check | Ada ran `jq`, `shasum`, `rg`, and `git diff --check` inline; no Luna dispatcher receipt exists | Drift: Ada owns the routing deviation; evidence checks themselves passed |
| Safety | Explicit maintainer approval before tracked memo edit | User supplied `PLEASE IMPLEMENT THIS PLAN`; tracked memo was then created | Met |
| Claims | Neutral park/amend/defer options with no diagnosis or remedy | Memo keeps neutral options and records no causal or capability claim | Met |
| Closure | Reconcile, check-log, and after-task report; no push/PR | This record, the check-log entry, and after-task report close the arc locally | Met |

**Melissa disposition:** one recorded routing drift, with no scope or evidence
drift. The missing Luna receipt must not be described as Luna execution.
Rose owns any future closeout wording; Ada owns routing compliance.
