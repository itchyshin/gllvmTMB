# CRAN 0.7 v4 harness adversarial review

Date: 2026-08-08  
Reviewer: Noether  
Mode: read-only review; no fits, network research, or compute launched  
Verdict: **HOLD**

## Review boundary

This review covered `AGENTS.md`, the complete `inst/sim/cran07-v4/`
directory, `docs/dev-log/release/2026-08-08-cran07-v4-confirmation-design.md`,
the maintainer authorization receipt, and only the inherited `cran07-core` and
`cran07-v3` functions sourced by v4. The pure counterexamples below were run
without fitting a model. No harness file was edited.

The package scope remains correct: these are stacked-trait, long-format,
multivariate ordinary GLLVM cells. No single-response or spatial-only model is
added. The HOLD is about evidence integrity and public-claim fencing.

## Findings

### P1 — production manifests accept all three forbidden challenge cells

The design says the three challenge cells are pilot-only and that production is
the predeclared 31-cell surface
(`docs/dev-log/release/2026-08-08-cran07-v4-confirmation-design.md:83-86`). The
README says production "always excludes" them
(`inst/sim/cran07-v4/README.md:10-12`). That invariant exists only in the CLI
wrapper (`inst/sim/cran07-v4/run-batch.R:41-50`).

The lower-level manifest constructor defaults to the whole registry when
`cells = NULL` (`inst/sim/cran07-v4/campaign-v4.R:57-65`), and the validator
then treats the whole registry as the expected production set
(`inst/sim/cran07-v4/campaign-v4.R:104-108`). The summarizer also accepts an
arbitrary caller-supplied production cell list without checking the challenge
fence (`inst/sim/cran07-v4/summarize-batch.R:16-25`). Consequently, a direct
manifest/run call or a manually summarized campaign can put challenge cells in
production. The v4 self-test masks this by applying `setdiff()` before it calls
the constructor (`inst/sim/cran07-v4/self-test.R:43-47`); it never tests that
the constructor rejects a challenge cell.

### P1 — warm-restart provenance cannot prove the preregistered algorithm

The preregistration requires the initial fit to have code zero, finite objective
and raw gradient, raw maximum gradient at least `0.01`, positive-definite
Hessian, and no boundary flag; acceptance also requires code zero, finite
objective and gradient, improved raw gradient, positive-definite Hessian, no
boundary, and the frozen objective tolerance
(`docs/dev-log/release/2026-08-08-cran07-v4-confirmation-design.md:16-32`).

The stored record contains no before/after optimizer codes, Hessian flags, or
boundary flags (`inst/sim/cran07-v4/schema-v4.R:26-28`). Its validator does not
require finite before-fields for a successful unattempted restart, does not
require the `>= 0.01` trigger, and does not require gradients to be nonnegative
(`inst/sim/cran07-v4/schema-v4.R:46-65`). Therefore a ledger can validate while
describing an impossible or unauthorized restart. The self-test covers only a
subset of malformed states (`inst/sim/cran07-v4/self-test.R:64-84`) and prints
`restart_accept_reject=OK` despite these open branches
(`inst/sim/cran07-v4/self-test.R:181-188`).

### P1 — the pilot receipt trusts a precomputed admission ledger instead of recomputing it

Per-cell pilot admission is correctly defined from the attempts at
`inst/sim/cran07-v4/gates-v4.R:21-33`. However, the cross-campaign receipt
script extracts `summary$v4_gate` and passes it through as authority
(`inst/sim/cran07-v4/pilot-global-gate.R:23-29`). The final pilot verdict checks
only that the supplied admission table has the expected 34 keys and nonmissing
logical decisions; it does not recompute those decisions from the attempts
(`inst/sim/cran07-v4/gates-v4.R:59-80`). Production then trusts only
`production_authorized` plus the supplied admitted-cell list
(`inst/sim/cran07-v4/run-batch.R:42-50`).

A stale, corrupted, or edited summary can therefore mark a 20/20-unusable cell
as admitted while retaining a qualifying global detector table. This breaks the
pilot-to-production acceptance chain even without falsifying any manifest key.

### P1 — estimand components are not joined to attempt/manifest identity

The six-field attempt/manifest bijection is sound for the attempt table itself
(`inst/sim/cran07-v4/schema-v4.R:99-114`), but it does not cover estimand rows.
The inherited estimand validator requires neither `seed` nor any campaign,
registry, or source identity (`inst/sim/cran07-v3/gates-v3.R:128-136`). The v4
component completeness helper checks only `replicate`, applicability, truth,
and estimate (`inst/sim/cran07-v4/gates-v4.R:83-87`). Summary assembly binds
attempts and estimands from RDS objects but never asserts a row-level join
between them (`inst/sim/cran07-v4/summary-v4.R:8-16`).

Thus 1,600 rows with replicates `1:1600` can pass a component gate with no seed
column at all, or with stale/cross-attempt seeds. This falls short of the design's
exact attempt identity and exact 1,600-contribution contract
(`docs/dev-log/release/2026-08-08-cran07-v4-confirmation-design.md:62-65,110-112`).
The self-test checks only one synthetic phi component shape
(`inst/sim/cran07-v4/self-test.R:142-157`) before printing the broader claim
`components_1600_exact=OK` (`inst/sim/cran07-v4/self-test.R:187-188`).

### P1 — structural Psi can be hidden as already non-applicable

The normalization asserts exact off-diagonal zeros only for rows that arrive
with `applicable = TRUE` (`inst/sim/cran07-v4/attempt-runner-v4.R:4-14`). The
component-schema comparison likewise ignores all non-applicable rows
(`inst/sim/cran07-v4/gates-v4.R:110-115`). A nonzero off-diagonal Psi row marked
non-applicable before normalization survives silently. The normal extractor
currently emits these rows as applicable, so the ordinary generated path is
protected; the receipt is not protected against stale, malformed, or tampered
estimand rows. This contradicts the unconditional exact-zero assertion in the
design (`docs/dev-log/release/2026-08-08-cran07-v4-confirmation-design.md:110-114`).

### P1 — NB2 phi alignment is asserted in prose but not checked in code

The design requires `phi_nbinom2` to align exactly to the three frozen trait
names (`docs/dev-log/release/2026-08-08-cran07-v4-confirmation-design.md:118-123`).
The extractor checks only numeric type, length, finiteness, and positivity, then
discards any report names and assigns the fixture trait names positionally
(`inst/sim/cran07-v4/attempt-runner-v4.R:22-36`). A reversed named report vector
is therefore silently relabelled. Because every frozen truth is 5, the bias,
catastrophic-ratio, and RMSE gates cannot detect a permutation.

The downstream mathematics is otherwise coherent: the per-trait relative-bias
gate is `<= 0.20` (`inst/sim/cran07-v4/gates-v4.R:182-191`), ratios outside
`[0.1, 10]` are catastrophic (`inst/sim/cran07-v4/attempt-runner-v4.R:43-52`),
and phi is added to the expected schema and therefore the NB2 RMSE pair
(`inst/sim/cran07-v4/gates-v4.R:89-108,256-300`). Exact trait alignment remains
unproved.

### P1 — broad closeout can PASS while the public result is only cell-specific

The design permits only cell-specific promotion and explicitly keeps Gaussian
latent `n = 60` and NB2 latent `n = 100` publicly fenced even if their gates
pass (`docs/dev-log/release/2026-08-08-cran07-v4-confirmation-design.md:128-138`).
The closeout has no public-fence field. It labels the Gaussian-latent and NB2
family pairs `PASS` whenever their two admitted cells and RMSE components pass
(`inst/sim/cran07-v4/summary-v4.R:98-111`), and returns a single
`release_verdict = "PASS"` when all *admitted* cells pass
(`inst/sim/cran07-v4/summary-v4.R:112-122`). It does not require all 31
production-eligible cells to have been admitted.

The pure counterexample below obtains `release_verdict=PASS` with only 14 cells
admitted, 17 non-challenge cells held, and both publicly fenced family pairs
reported `PASS`. This is an unsafe broad-vs-cell-specific API: a consumer can
promote exactly the cells the preregistration says must remain fenced.

### P2 — source-archive identity is caller-asserted, not verified

The runner accepts a SHA string (`inst/sim/cran07-v4/run-batch.R:25-33`) and the
manifest contract verifies only the lowercase 64-hex shape
(`inst/sim/cran07-v4/campaign-v4.R:57-63`). No v4 path hashes an archive and
compares the computed digest with the claimed digest. `--load-all` is also
allowed (`inst/sim/cran07-v4/run-batch.R:18-19`), so a dirty source tree can run
under an unrelated archive hash. Pilot and production do check that their
caller-supplied strings agree (`inst/sim/cran07-v4/summary-v4.R:80-85`), but
agreement between two unverified strings is not source provenance.

### P2 — the requested hash-freeze receipt does not yet exist

The design remains explicitly "DRAFT — zero fits; not authorized or frozen"
(`docs/dev-log/release/2026-08-08-cran07-v4-confirmation-design.md:3-14`) and
requires the runner, manifests, schema, gates, and adversarial tests to be
hash-frozen before smoke/pilot (`docs/dev-log/release/2026-08-08-cran07-v4-confirmation-design.md:140-155`).
The maintainer receipt authorizes the narrow optimizer repair, not the v4
campaign (`docs/dev-log/release/2026-08-08-maintainer-release-rights-authorization.md:11,24-32`).
No fixed digest inventory for the v4 files is present in the reviewed files.
This is independently sufficient to withhold launch.

## Checks that survived attack

- **PASS — attempt classification is independent of truth.** The status
  classifier uses only construction, fit, finiteness, optimizer, stationarity,
  Hessian, boundary, and geometry flags
  (`inst/sim/cran07-core/schema.R:30-63`). Validation derives
  `detector_flagged` from terminal status, not from the truth label
  (`inst/sim/cran07-core/schema.R:86-105`). The v4 runner stores catastrophic
  truth error separately (`inst/sim/cran07-v4/attempt-runner-v4.R:123-145`).
- **PASS — global detector arithmetic fails closed on missing classes.** It
  requires exact attempt count, nonmissing labels, positive sensitivity and
  specificity denominators, sensitivity `>= 0.95`, and specificity `>= 0.90`
  (`inst/sim/cran07-v3/gates-v3.R:30-57`; v4 coverage check at
  `inst/sim/cran07-v4/gates-v4.R:36-56`). This does not repair the forged
  per-cell admission problem above.
- **PASS — declared-manifest identity and replicate completeness.** For a
  correctly declared cell set, the validator checks registry identity,
  canonical cell number, exact cell set, exact stage count, unique six-field
  identity, complete replicate sequence, and deterministic seed
  (`inst/sim/cran07-v4/campaign-v4.R:81-134`). The failure is that the production
  cell set itself is not intrinsically fenced and the source digest is not
  computed.
- **PASS — rank-one numerical-zero exception is narrow.** It requires both
  cells to be rank one, only `correlation_shared`, truth magnitude within
  `64 * eps` of one, and estimate error at most `64 * eps`
  (`inst/sim/cran07-v4/gates-v4.R:248-253,265-300`).
- **PASS — pair mechanics require both sample-size cells once the admitted set
  is trusted.** Each frozen pair is HOLD if either cell is absent, either cell
  gate fails, or any RMSE component fails
  (`inst/sim/cran07-v4/summary-v4.R:92-111`). The public-fence and broad-verdict
  semantics remain broken.

## Runnable pure counterexamples

Run from the repository root. These source functions and construct data only;
they fit no model.

### 1. Challenge cells and invalid restart provenance validate

```sh
Rscript --vanilla -e '
source("inst/sim/cran07-core/schema.R")
source("inst/sim/cran07-core/campaign.R")
source("inst/sim/cran07-v3/campaign-v3.R")
source("inst/sim/cran07-v4/campaign-v4.R")
sha <- paste(rep("a", 64), collapse = "")
r <- cran07_v4_read_campaign_registry("cran07-core-recovery-v4", ".")
m <- cran07_v4_manifest(r, "cran07-core-recovery-v4", "production", sha)
cran07_v4_validate_manifest(m, r, "cran07-core-recovery-v4", "production", sha)
print(intersect(unique(m$cell_id), CRAN07_V4_HELD_CHALLENGE_CELLS))

source("inst/sim/cran07-v4/schema-v4.R")
missing_before <- list(warm_restart_attempted = FALSE,
  warm_restart_accepted = FALSE, objective_before_restart = NA_real_,
  objective_after_restart = NA_real_, max_gradient_before_restart = NA_real_,
  max_gradient_after_restart = NA_real_)
below_trigger <- list(warm_restart_attempted = TRUE,
  warm_restart_accepted = TRUE, objective_before_restart = 10,
  objective_after_restart = 10, max_gradient_before_restart = 0.001,
  max_gradient_after_restart = 0.0005)
negative_gradient <- list(warm_restart_attempted = TRUE,
  warm_restart_accepted = TRUE, objective_before_restart = 10,
  objective_after_restart = 10, max_gradient_before_restart = -1,
  max_gradient_after_restart = -2)
cran07_v4_restart_evidence(missing_before)
cran07_v4_restart_evidence(below_trigger)
cran07_v4_restart_evidence(negative_gradient)
'
```

Observed: the production manifest validates with all three challenge cells;
all three invalid provenance examples return successfully.

### 2. Forged admission, hidden structural Psi, unbound phi rows, and phi permutation

```sh
Rscript --vanilla -e '
source("inst/sim/cran07-core/schema.R")
source("inst/sim/cran07-core/campaign.R")
source("inst/sim/cran07-v3/campaign-v3.R")
source("inst/sim/cran07-v3/gates-v3.R")
source("inst/sim/cran07-v4/campaign-v4.R")
source("inst/sim/cran07-v4/schema-v4.R")
source("inst/sim/cran07-v4/attempt-runner-v4.R")
source("inst/sim/cran07-v4/gates-v4.R")
ids <- CRAN07_V4_CAMPAIGNS$campaign_id
regs <- setNames(lapply(ids, function(id)
  cran07_v4_read_campaign_registry(id, ".")), ids)
all_cells <- cran07_v4_expected_campaign_cells(regs)
global <- do.call(rbind, lapply(seq_len(nrow(all_cells)), function(i)
  data.frame(campaign_id = all_cells$campaign_id[i],
    cell_id = all_cells$cell_id[i], catastrophic_truth_error = FALSE,
    detector_flagged = FALSE)[rep(1L, 20L), ]))
global$catastrophic_truth_error[1:20] <- TRUE
global$detector_flagged[1:19] <- TRUE
forged <- all_cells
forged$admitted <- TRUE
bad_cell <- all_cells$cell_id[1]
bad_attempts <- data.frame(cell_id = bad_cell,
  status = rep("boundary", 20), finite_estimands = TRUE,
  stationary = TRUE, pd_hessian = TRUE)
cat("actual=", cran07_v4_pilot_admission(bad_attempts, bad_cell)$admitted,
    " forged=", bad_cell %in%
      cran07_v4_pilot_verdict(global, all_cells, forged)$admitted_cells$cell_id,
    "\n", sep = "")

hidden_psi <- data.frame(cell_id = "p", replicate = 1L, seed = 1L,
  estimand = "Psi", component = "t2_t1", trait_i = 2L, trait_j = 1L,
  applicable = FALSE, truth = 999, estimate = 999)
print(cran07_v4_normalize_structural_psi(hidden_psi))

phi <- do.call(rbind, lapply(paste0("t", 1:3), function(component)
  data.frame(cell_id = "nb2_latent_n100", replicate = 1:1600,
    estimand = "phi_nbinom2", component = component,
    trait_i = 1L, trait_j = 1L, applicable = TRUE,
    truth = 5, estimate = 5)))
cat("phi_without_seed_passes=",
    cran07_v4_phi_pass(phi, "nb2_latent_n100", TRUE, 3L), "\n")

cran07_extract_estimands <- function(...)
  data.frame(cell_id = character(), replicate = integer(), seed = integer(),
    estimand = character(), component = character(), trait_i = integer(),
    trait_j = integer(), applicable = logical(), truth = numeric(),
    estimate = numeric())
fit <- list(report = list(phi_nbinom2 = c(t3 = 30, t2 = 20, t1 = 10)))
fixture <- list(data = data.frame(
  trait = factor(character(), levels = c("t1", "t2", "t3"))), dispersion = 5)
print(cran07_v4_extract_estimands(
  fit, fixture, "x", 1L, 1L, "latent", "nbinom2")[, c("component", "estimate")])
'
```

Observed: the actual bad-cell admission is `FALSE`, the forged receipt admits
it; the nonzero Psi row survives; phi passes without seed identity; and the
named report `t3=30,t2=20,t1=10` is relabelled as `t1=30,t2=20,t3=10`.

### 3. Broad PASS with 17 eligible cells held and both public fences crossed

This isolates closeout aggregation by replacing the lower RMSE calculation with
a passing pure stub. It does not claim the scientific gates passed; it proves
that, conditional on their passing, closeout has no 31-cell completeness or
public-fence guard.

```sh
Rscript --vanilla -e '
source("inst/sim/cran07-core/schema.R")
source("inst/sim/cran07-core/campaign.R")
source("inst/sim/cran07-core/batch.R")
source("inst/sim/cran07-v3/campaign-v3.R")
source("inst/sim/cran07-v3/gates-v3.R")
source("inst/sim/cran07-v4/campaign-v4.R")
source("inst/sim/cran07-v4/gates-v4.R")
source("inst/sim/cran07-v4/summary-v4.R")
ids <- CRAN07_V4_CAMPAIGNS$campaign_id
regs <- setNames(lapply(ids, function(id)
  cran07_v4_read_campaign_registry(id, ".")), ids)
core_cells <- unique(c(CRAN07_V4_RMSE_PAIRS$small_cell,
                       CRAN07_V4_RMSE_PAIRS$large_cell))
admitted <- rbind(
  data.frame(campaign_id = ids[1], cell_id = core_cells),
  data.frame(campaign_id = ids[2], cell_id = regs[[ids[2]]]$cell_id[1]),
  data.frame(campaign_id = ids[3], cell_id = regs[[ids[3]]]$cell_id[1]))
all_cells <- cran07_v4_expected_campaign_cells(regs)
held <- all_cells[!paste(all_cells$campaign_id, all_cells$cell_id) %in%
  paste(admitted$campaign_id, admitted$cell_id), ]
pilot <- list(admitted_cells = admitted, held_cells = held,
  production_authorized = TRUE,
  source_archive_sha256 = paste(rep("a", 64), collapse = ""))
make_summary <- function(id) {
  cells <- sort(admitted$cell_id[admitted$campaign_id == id])
  n <- as.integer(length(cells) * 1600L)
  list(v4_identity = list(campaign_id = id, stage = "production",
      complete = TRUE,
      registry_sha256 = cran07_v4_campaign_spec(id)$registry_sha256,
      source_archive_sha256 = pilot$source_archive_sha256,
      manifest_sha256 = paste(rep("b", 64), collapse = ""),
      expected_attempts = n, observed_attempts = n,
      expected_cells = cells),
    v4_gate = data.frame(cell_id = cells, cell_pass = TRUE,
      component_schema_pass = TRUE, phi_nbinom2_bias_pass = TRUE),
    attempts = data.frame(catastrophic_truth_error = rep(FALSE, n),
      detector_flagged = rep(FALSE, n)), estimands = data.frame())
}
summaries <- setNames(lapply(ids, make_summary), ids)
summaries[[ids[1]]]$attempts$catastrophic_truth_error[1:100] <- TRUE
summaries[[ids[1]]]$attempts$detector_flagged[1:100] <- TRUE
cran07_v4_rmse_pair_gate <- function(estimands, registry, pairs, B, seed)
  data.frame(pair_id = pairs$pair_id, estimand = "mock",
    component = "mock", pass = TRUE)
out <- cran07_v4_production_closeout(summaries, pilot, regs, B = 2L)
cat("admitted=", nrow(admitted),
    " nonchallenge_held=",
    sum(!held$cell_id %in% CRAN07_V4_HELD_CHALLENGE_CELLS),
    " release_verdict=", out$release_verdict, "\n", sep = "")
print(out$family_pair_gate[out$family_pair_gate$pair_id %in%
  c("gaussian_latent", "nb2_latent"), c("pair_id", "verdict")])
'
```

Observed: `admitted=14 nonchallenge_held=17 release_verdict=PASS`, with both
`gaussian_latent` and `nb2_latent` reported `PASS`.

## Smallest fail-closed repair contract

1. Define one immutable campaign-qualified table of the 31 production-eligible
   `(campaign_id, cell_id)` keys. Make the production manifest constructor,
   validator, runner, summarizer, and closeout all reject a challenge key and
   reject any cell outside the pilot-admitted subset. Do not rely on the CLI as
   the only fence.
2. Recompute every pilot cell admission from the retained attempts when building
   the pilot receipt. Validate each input summary's campaign ID, registry hash,
   source hash, exact 20-attempt key set, and attempt schema. Treat any mismatch
   between a stored `v4_gate` and the recomputed gate as corruption.
3. Extend restart provenance with before/after convergence code, PD-Hessian and
   boundary states, plus a trigger reason. Re-derive `attempted` and `accepted`
   from the frozen predicate; require nonnegative raw max-gradients and finite
   before-fields for every successful fit.
4. Put the full six-field identity on every estimand row, or assert an exact join
   from `(cell_id, replicate, seed)` to one attempt and then to the manifest.
   For every attempt, require exactly one row for every expected applicable
   component, no unexpected component, and exact seed agreement.
5. Assert every off-diagonal Psi row has exact zero truth and estimate before
   considering `applicable`; reject pre-hidden non-applicable nonzero rows.
6. Require `phi_nbinom2` names to match the frozen trait names exactly and reorder
   by name. If the engine report is intentionally unnamed, validate and record
   the engine trait-order map explicitly. Add a pure unequal-phi permutation
   test so the alignment claim is falsifiable even though the campaign truth is
   `(5,5,5)`.
7. Separate scientific cell evidence from public promotion. Return explicit
   `cell_verdict`, `evidence_pair_verdict`, and `publicly_promotable` fields.
   Gaussian latent `n=60` and NB2 latent `n=100` must remain
   `CHARACTERIZATION_ONLY` regardless of replicate-level results. Do not emit a
   broad `release_verdict=PASS` from a subset; either require all 31 eligible
   cells or rename the result to a subset execution verdict and keep public
   release status HOLD pending an explicit claim-level adjudication.
8. For frozen stages, accept an archive path and compute its SHA-256 in the
   runner; compare it to the receipt. Forbid `--load-all` in a frozen campaign,
   or replace it with an equally exact source-tree identity contract.
9. Only after the repairs and adversarial tests pass, create the required receipt
   containing fixed SHA-256 digests for every v4 harness file, the exact source
   archive, registries, and manifests. The current draft/authorization documents
   are not that receipt.

Until all nine conditions are met, smoke, pilot, production, and any public
promotion remain **HOLD**.
