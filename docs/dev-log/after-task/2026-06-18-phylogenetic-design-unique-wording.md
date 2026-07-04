# After-task report: phylogenetic design unique wording cleanup

Date: 2026-06-18 21:05 MDT

Branch: `codex/r-bridge-grouped-dispersion`

Guard preserved: `PR green != bridge complete != release ready != scientific coverage passed`.

## Task

Continue the post-coevolution `unique()` deprecation cleanup on the
phylogenetic design surface.

## Files touched

- `docs/design/03-phylogenetic-gllvm.md`
- `docs/dev-log/check-log.md`
- `docs/dev-log/dashboard/status.json`
- `docs/dev-log/dashboard/sweep.json`

## What changed

- The three-piece fallback now says the non-phylogenetic diagonal `Psi` comes
  from default ordinary `latent()`, with explicit `unique()` retained as
  compatibility syntax.
- The syntax table now teaches:
  - `latent(...)` for non-phylogenetic shared + diagonal `Psi`;
  - `indep(...)` for standalone non-phylogenetic diagonal terms;
  - `phylo_unique()` as diagonal-Psi compatibility.
- The implementation map now points standalone `phylo_unique()` users to
  `phylo_indep()` for new code.

## Definition-of-done accounting

1. Implementation: design-doc cleanup only on the local branch; not merged to
   `main`.
2. Simulation recovery: not applicable; no model behavior changed.
3. Documentation: design doc updated.
4. Runnable example: not applicable; this was a design contract wording slice.
5. Check-log: `docs/dev-log/check-log.md` has the 21:05 MDT entry with exact
   commands and outcomes.
6. Review pass: no likelihood, parser, or exported API change. This was a
   lifecycle/design consistency slice.

## Validation

- `pkgdown::check_pkgdown()` reported `No problems found.`
- Stale wording scan found only intentional compatibility mentions and the new
  `indep()` row.
- `git diff --check` was clean.

## Still open

- No keyword removal.
- No source-specific paired-Psi fold.
- No Paper 2 multi-kernel explicit Psi.
- Broader post-arc `unique()` lifecycle/deprecation cleanup remains ongoing.
