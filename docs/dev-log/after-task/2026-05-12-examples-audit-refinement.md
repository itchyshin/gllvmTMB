# After-Task: @examples-audit refinement (Phase 5 prep)

## Goal

Refine the `@examples` punch list in
`docs/dev-log/shannon-audits/2026-05-12-phase5-cran-readiness-pre-audit.md`
(PR #44) by verifying the current Rd state on `origin/main` and
producing concrete proposed `@examples` blocks for each export
still missing one.

Overnight Phase 5 prep work. Done as part of the locked overnight
scope (2026-05-12 18:00 MT -> 2026-05-13 05:00 MT): no source
change, no rule change, single audit doc output.

After-task report at branch start per `CONTRIBUTING.md`.

## Implemented

- **`docs/dev-log/shannon-audits/2026-05-12-examples-audit-refinement.md`**
  (NEW): the refined audit doc. Documents the verification
  method, the actual list of 11 exports still missing both
  `\examples` and `@keywords internal`, and a proposed
  `@examples` block for each.
- **`docs/dev-log/after-task/2026-05-12-examples-audit-refinement.md`**
  (NEW, this file).

The audit doc itself enumerates:

- The verification script (`for rd in man/*.Rd; ...`).
- The 11 missing exports in a single table with source-file,
  whether listed in the original audit, and class label.
- A concrete proposed `@examples` block for each of the 11.
- A shared-structure template (9 of 11 share the same fit
  skeleton).
- A `\dontrun{}` vs `@examplesIf interactive()` rationale.
- Effort estimate (~1-2 hours of Codex work for the
  implementation PR).
- Recommended sequencing relative to in-flight PRs.

Headline numbers:

- PR #44 audit estimated "22 exports without examples";
  current state shows 11 still missing (the other 11 were
  demoted to `@keywords internal` during PR #43 / #44 prep or
  earlier).
- PR #44 missed 5 S3-method Rds (`plot.gllvmTMB_multi`,
  `predict.gllvmTMB_multi`, `simulate.gllvmTMB_multi`,
  `tidy.gllvmTMB_multi`, `gllvmTMB_multi-methods`). These are
  CRAN-reviewer-visible user-facing methods and should have
  examples.

## Mathematical Contract

No public R API, likelihood, formula grammar, family, NAMESPACE,
generated Rd, vignette, or pkgdown navigation change. Two new
markdown files under `docs/dev-log/`.

The proposed `@examples` blocks themselves do not change the
package; they are the *deliverable* of this audit, ready for a
Codex implementation PR to apply.

## Files Changed

- `docs/dev-log/shannon-audits/2026-05-12-examples-audit-refinement.md`
  (new)
- `docs/dev-log/after-task/2026-05-12-examples-audit-refinement.md`
  (new, this file)

## Checks Run

- Pre-edit lane check: 1 open Claude PR (#55 Rose article-sweep,
  CI in progress) + 1 Codex PR (#51 ordinal-probit, CI in
  progress on windows). Neither touches `docs/dev-log/shannon-audits/`
  or `docs/dev-log/after-task/`. Safe.
- Verification script run on `origin/main` HEAD `0d189a3`
  (after PR #54 merged):

  ```sh
  for rd in man/*.Rd; do
    name=$(basename "$rd" .Rd)
    has_ex=$(grep -c '\\examples' "$rd" || echo 0)
    has_int=$(grep -c '\\keyword{internal}' "$rd" || echo 0)
    if [ "$has_ex" = "0" ] && [ "$has_int" = "0" ]; then
      echo "MISSING: $name"
    fi
  done
  ```

  Output:
  ```
  MISSING: gllvmTMB_multi-methods
  MISSING: gllvmTMBcontrol
  MISSING: latent
  MISSING: meta_known_V
  MISSING: plot.gllvmTMB_multi
  MISSING: plot_anisotropy
  MISSING: predict.gllvmTMB_multi
  MISSING: sanity_multi
  MISSING: simulate.gllvmTMB_multi
  MISSING: tidy.gllvmTMB_multi
  MISSING: traits
  ```

  11 exports.

- Source-signature spot-check: confirmed each export's source
  signature so the proposed example uses real argument names:
  - `R/gllvmTMB.R:647` for `gllvmTMBcontrol`
  - `R/brms-sugar.R:929` for `meta_known_V`
  - `R/methods-gllvmTMB.R:475` for `tidy.gllvmTMB_multi`
  - `R/methods-gllvmTMB.R:778` for `sanity_multi`
  - `R/traits-keyword.R:96` for `traits`
  - `R/plot-gllvmTMB.R` for `plot.gllvmTMB_multi` formals
  - `R/methods-gllvmTMB.R` for the S3 method signatures.

## Tests Of The Tests

This is a Phase 5 prep audit. The "tests" are:

1. **Coverage check**: re-run the verification script after the
   Codex implementation PR applies the proposed examples;
   expected output is empty.
2. **Example-correctness check**: each proposed example follows
   the canonical fit skeleton (`gllvmTMB(value ~ 0 + trait +
   latent(...) + unique(...), data = df, unit = "site")`) and
   uses current argument names per the source signatures
   listed above. If Codex's implementation lands with
   different example bodies, the diff is the artefact of
   what the maintainer / Codex preferred.
3. **Rendered-Rd spot-check** (per PR #36 protocol): after
   `devtools::document()`, each affected `man/<file>.Rd` should
   have `tail -5` ending with a clean `\examples{}` block (not
   roxygen-tokenised garbage), and `grep -c '^\\keyword'
   man/<file>.Rd` should return `0` (no `@keywords internal`
   collision).

## Consistency Audit

```sh
rg -n 'dontrun' docs/dev-log/shannon-audits/2026-05-12-examples-audit-refinement.md | wc -l
```

verdict: 11 `\dontrun{}` blocks (one per missing export). Each
proposed example is `\dontrun{}` because each invokes a TMB fit
that exceeds CRAN's per-example budget.

```sh
rg -n '@examplesIf' docs/dev-log/shannon-audits/2026-05-12-examples-audit-refinement.md
```

verdict: zero. The audit explicitly recommends `\dontrun{}` over
`@examplesIf interactive()` so CRAN reviewers can still read the
example body in the rendered Rd.

## What Did Not Go Smoothly

Nothing. The audit was bounded by design: verify the current
state, enumerate the missing, propose example text.

The main surprise was the gap between PR #44's headline count
("22 exports without examples") and the actual current count
(11). That gap is good news -- 11 of the original list were
demoted to `@keywords internal` during PR #43 / #44 prep -- but
it means the original audit's estimate of "~15-20 small
`\dontrun` additions + ~5-6 internal demotions" overshot the
remaining work. The actual Phase 5 implementation PR is closer
to 11 `\dontrun{}` additions plus 0 further internal
demotions.

The audit also surfaced 5 S3-method Rds the original audit
missed entirely. Those are user-facing CRAN-visible methods
(`predict`, `simulate`, `plot`, `tidy`); they belong in the
@examples round.

## Team Learning

By standing-review role per `AGENTS.md`:

- **Grace (release readiness)** -- this is exactly Grace's
  lane: take an upstream audit's TODO and refine it into a
  concrete deliverable Codex can apply. The original audit
  identified the gap; this refinement turns the gap into a
  punch list.
- **Pat (applied user / CRAN reviewer)** -- the 5 missed S3
  methods (`predict`, `simulate`, `plot`, `tidy`) are exactly
  what a CRAN reviewer or new applied user would call first.
  Their Rd pages should show worked examples.
- **Rose (cross-file consistency)** -- 9 of the 11 examples
  share the same fit skeleton. Codex's implementation should
  use one canonical pattern across all 9 so the Rd pages
  read consistently.
- **Shannon (coordination)** -- pre-edit lane check confirmed
  no collision with the in-flight PRs (#51 Codex, #55 Claude).

## Known Limitations

- The proposed example bodies use `df` / `df_wide` as ambient
  data names. Codex's implementation may prefer to use the
  built-in `simulate_site_trait()` output explicitly inside
  the example, to make each Rd self-contained for reviewers
  who paste the example into a fresh R session. Either
  convention works; the bodies as drafted assume `\dontrun{}`
  shields the example from being executed.
- The `plot_anisotropy` example body follows sdmTMB's
  upstream `plot_anisotropy` example, on the assumption that
  cross-package familiarity is more valuable than a
  gllvmTMB-specific framing. If the maintainer prefers
  divergence, the example body can be replaced with a fit
  call that includes `spatial_*()` keywords.
- The `tidy.gllvmTMB_multi` example calls
  `broom.mixed::tidy(fit, ...)` rather than `tidy(fit, ...)`
  to make the broom.mixed dependency explicit in the Rd
  (otherwise a reader might wonder where `tidy` comes from).
  Codex's implementation may prefer the bare `tidy(fit)` form
  if `broom.mixed` is in DESCRIPTION Imports.

## Next Actions

1. Maintainer reviews / merges the audit doc.
2. Codex implementation PR applies the 11 `@examples` blocks
   to the corresponding source files:
   - `R/gllvmTMB.R` (`gllvmTMBcontrol`)
   - `R/parser.R` (or wherever the `latent` keyword is
     exported)
   - `R/brms-sugar.R` (`meta_known_V`)
   - `R/plot.R` (`plot_anisotropy`)
   - `R/methods-gllvmTMB.R` (`sanity_multi`, `tidy`,
     `predict`, `simulate`, `gllvmTMB_multi-methods`
     aggregate)
   - `R/plot-gllvmTMB.R` (`plot.gllvmTMB_multi`)
   - `R/traits-keyword.R` (`traits`)
3. After application, `devtools::document()` and the rendered-Rd
   spot-check (`tail -5 man/<file>.Rd` + `grep -c '^\\keyword'
   man/<file>.Rd`) per PR #36 protocol.
4. After the implementation PR merges, re-run the verification
   script in this audit; expected output is empty (zero
   `MISSING:` lines).
