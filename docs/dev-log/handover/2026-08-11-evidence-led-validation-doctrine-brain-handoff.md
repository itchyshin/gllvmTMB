# Handoff: cross-package evidence-led validation doctrine

**To:** Shinichi brain lane (platform-neutral)  
**From:** Codex  
**Date:** 2026-08-11  
**Task type:** planning and durable documentation design only.  Do not change
package code, public claims, versions, releases, or ongoing compute.

## Critical context

Two methodological packages, `gllvmTMB` and `drmTMB`, already have substantial
validation infrastructure but need a coherent, lightweight doctrine tying
together theory, code provenance, independent comparators, recovery
simulation, diagnostics, and reader-facing claim boundaries.

The proposed central rule is:

> A converged fit is evidence that an algorithm returned a numerical result.
> It is not, by itself, evidence of identification, accurate estimation, or
> calibrated inference.

Hao's additional requirement has strong maintainer support: substantive
theoretical/algorithmic machinery in code should be traceable to the relevant
literature, with the exact adaptation and assumptions visible.  A citation is
provenance, not a correctness certificate.

## What was accomplished

Two non-binding discussion documents were drafted.

1. `gllvmTMB` doctrine draft:
   `docs/dev-log/research/2026-08-11-draft-validation-development-principles.md`
2. `drmTMB` adaptation and package-specific comparator map:
   `/Users/z3437171/Dropbox/Github Local/drmTMB/docs/dev-log/research/2026-08-11-evidence-led-development-principles-note.md`

They propose:

- exact model/estimand specification before broad validation;
- an A–U *evidence set* (not a hierarchy) separating theorem, conditional
  theory, known-truth simulation, independent comparison, assumption, and
  unknown;
- validation of the reportable estimand rather than the existence of a fitted
  object;
- deliberate stress tests and all-attempt accounting;
- comparator selection by exact package route and estimand; and
- visible failure domains and actionable diagnostics.

## Requested Brain-lane deliverable

Produce an **implementation-ready but not yet binding** governance packet.
It should be short enough to adopt and concrete enough that an implementer
does not have to rediscover the intent.

### 1. Canonical doctrine and ownership model

Recommend the durable home for the shared doctrine.  Prefer one canonical
cross-package note in the Shinichi brain, with package-local companion
documents that link to it and state package-specific comparator maps.  Avoid
copying the full doctrine into two repositories, because it will drift.

State which material belongs in:

| Layer | Proposed role |
| --- | --- |
| Canonical doctrine | Shared principles, terminology, evidence semantics |
| Package design document | Package-specific model families, comparator map, and route boundaries |
| Validation card | Exact model/estimand-level contract and evidence links |
| Validation ledger/capability census | Package-wide status index |
| Issue tracker | Discrete delivery/backfill work with acceptance criteria |

### 2. One-page validation-card template

Design a compact Markdown/YAML template with these mandatory fields:

1. exact model route, estimator, target estimand, and permitted public wording;
2. evidence set A/B/C/D/E/U, dated evidence links, and explicit non-claims;
3. literature/provenance record:
   - original source, DOI/URL, and citation key;
   - direct implementation, adaptation, or independent derivation;
   - R/TMB code locations;
   - differences from source and imported assumptions;
   - what that literature cannot establish for this package;
4. comparator design: exact versus related comparator, parameterisation bridge,
   expected quantity and tolerance;
5. recovery/stress specification, all-attempt denominator, PASS/HOLD rule, and
   scope explicitly not tested;
6. known failure domain, diagnostic protection, user next step, and ledger row.

The card must avoid requiring a citation for every utility helper.  It applies
to method-bearing components: likelihood families, parameterisations,
covariance/latent constructions, approximation/integration routes,
penalties/constraints, inferential transformations, and asymptotic claims.

### 3. Prioritised selective backfill policy

Define a triage scheme that prevents an unbounded retrospective project:

- **P0 before broad public promotion:** public, mathematically substantive,
  inference-adjacent routes; especially approximation/interval claims;
- **P1 next natural revision:** well-bounded public point-estimation routes;
- **P2 historic/internal:** add provenance only when touched or when a public
  claim expands;
- **U/partial:** citation/provenance can be backfilled without launching a new
  simulation; lack of evidence narrows the claim rather than silently failing.

Use the current `gllvmTMB` validation register and `drmTMB` capability census
as indexes, not replacement systems.

### 4. Issue architecture—draft only, do not open yet

Draft one umbrella issue per package and small child issues for:

- canonical/package companion + validation-card template;
- P0 provenance-to-code audit;
- P0 comparator-map reconciliation;
- pilot validation cards (one direct-comparator and one structured/oracle
  route per package);
- later automated linting only if the pilot demonstrates a clear low-cost rule.

Each issue should have a named non-goal and acceptance criterion.  Do not
create one issue per function.

### 5. Adoption recommendation

Propose a pilot-first decision: establish the packet, prepare issue drafts,
choose two routes in each package, and return to Shinichi for approval before
any package code, public claim, new simulation, or issue creation occurs.

## Ground truth to read first

1. This handoff.
2. `gllvmTMB` discussion draft named above.
3. `drmTMB` note named above.
4. `gllvmTMB/docs/design/35-validation-debt-register.md`.
5. `drmTMB/docs/design/05-testing-strategy.md` and its capability-census
   dashboard.
6. The current `AGENTS.md` in each repository before proposing any edit.

## Protected work and non-goals

- The live LA-MSPL B2 campaign on Fir is protected.  Do not inspect, restart,
  alter, aggregate partial output, or use it as a test vehicle.
- Do not modify existing public package claims, version numbers, release plans,
  or CRAN material.
- Do not open issues, commit to either package, or launch a simulation under
  this handoff.  Return governance artifacts and a proposed decision only.

## Current working state and landing ledger

| Artifact | State | Reason / how to access |
| --- | --- | --- |
| `gllvmTMB` discussion draft | CARRIED-OVER, uncommitted | Local working-tree file; do not stage with foreign B2/design work |
| `drmTMB` adaptation note | CARRIED-OVER, uncommitted | Local working-tree file; its checkout has substantial foreign changes |
| This handoff | CARRIED-OVER, uncommitted | Deliberately local so the Brain lane can read it without altering package branches |

`gllvmTMB` is currently a multi-lane checkout.  At handoff creation, the
active branch is `claude/design-117-separation-programme`; another Codex lane
(`codex/isdm-g2d-six-species`) is active.  Do not treat this handoff as
authority to touch their files or to refresh any single global phase pointer.

## How to resume

Run lane preflight in each repository before claiming any work.  Compare this
handoff with current git state and classify every requested item as `OWED`,
`DONE`, `RETRACTED`, or `PROTECTED`.  Prepare the governance packet only.

### Paste-ready prompt

```text
Read AGENTS.md and gllvmTMB/docs/dev-log/handover/2026-08-11-evidence-led-validation-doctrine-brain-handoff.md.
Run lane preflight for gllvmTMB and drmTMB, reconcile the handoff with current
git state, then continue only the OWED governance-design steps.  Do not modify
package code/claims, open issues, launch compute, merge, release, or submit.
```
