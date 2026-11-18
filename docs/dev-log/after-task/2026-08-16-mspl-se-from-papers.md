# After Task: MSPL SE extract from the two source papers

**Branch**: `docs/mspl-se-from-papers`
**Date**: `2026-08-16`
**Roles (engaged)**: Ada / Fisher / Noether / Jason / Rose / Shannon

```text
🎯 GOAL
Solo: Cursor
Deliverable: paper-grounded SE/interval extract + docs PR
HEADLINE: SK2023 publishes Wald from the unpenalized approximate-likelihood Hessian; SKM2026 gives no SE formula
DEFER: R/src edits · admit · public vcov/confint · sandwich · family rates
```

## 1. Goal

Read both MSPL PDFs and write a cited research note for the D-149
internal \(Q_P\)/\(Q_0\) pins. Do not invent claims the papers do
not make. Open a docs-only PR.

## 2. Implemented

- `docs/dev-log/research/2026-08-16-mspl-se-from-papers.md`
  from `pdftotext -layout` of both Desktop PDFs.
- Load-bearing extract: SK2023 SEs are the inverse negative
  Hessian of the **approximate log-likelihood** (our \(Q_0\)),
  blanked when that inverse diagonal is negative. SKM2026 has
  no Wald formula; the penalized Hessian is a Heywood
  diagnostic only (our \(Q_P\) role). Softness licences the
  **ML** information, not \(\nabla\nabla^\top(\ell+P)\).
- Poisson / nbinom / beta / Tweedie: **not in the papers**.

## 3. Files Changed

- `docs/dev-log/research/2026-08-16-mspl-se-from-papers.md` (new)
- `docs/dev-log/after-task/2026-08-16-mspl-se-from-papers.md` (this file)
- `docs/dev-log/check-log.md` (append)

No `R/`, `src/`, tests, NEWS, register, or `ROADMAP.md`.

## 3a. Decisions and Rejected Alternatives

- **Decision:** write in a clean worktree off `origin/main`, not
  the dirty `cursor/mspl-poisson-admit-packet` tree.
  **Rejected:** editing the live MSPL tree. **Confidence:** high.
- **Decision:** map paper objects onto \(Q_0\)/\(Q_P\) only after
  quoting the paper words. **Rejected:** treating Claude’s
  “admission not calibration” handover line as a paper claim.
  **Confidence:** high.

## 4. Checks Run

```sh
pdftotext -layout s11222-023-10217-3-1.pdf          # 992 lines
pdftotext -layout maximum-softly-penalized-likelihood-in-factor-analysis.pdf  # 772 lines
rg -n "calibrated|NEWS covered|sandwich|Godambe|I_LA|sdreport" \
  docs/dev-log/research/2026-08-16-mspl-se-from-papers.md
```

Those tokens appear only as negations or as names of objects the
papers do not supply. No `devtools::test()`: docs-only.

## 5. Tests of the Tests

N/A — no tests added.

## 6. Consistency Audit

| Pattern | Verdict |
|---|---|
| `rg "invert the penalized" docs/dev-log/research/2026-08-16-mspl-se-from-papers.md` | clean — we say the papers do **not** do this |
| `rg "Poisson.*Wald\|Tweedie.*information" ...` | clean — those families are “not treated” |
| `rg "Q_P.*paper SE\|paper.*Q_P" ...` | \(Q_P\) labelled diagnostic only |

## 7. Roadmap Tick

N/A. No `ROADMAP.md` row moved.

## 7a. GitHub Issue Ledger

No relevant open issue; no new issue created. This is a research
extract for the already-authorised D-149 pin series, not a defect.

## 8. What Did Not Go Smoothly

The live MSPL worktree was dirty, so the note landed in a new
`/private/tmp/gllvmtmb-mspl-se-from-papers` worktree. Subagent
`move_agent_to_root` is blocked; files were written by absolute
path. Brain hybrid search for “D-149” initially missed the
ledger; the accepted text is in `memory/DECISIONS.md` §D-149.

## 9. Team Learning (per AGENTS.md Standing Review Roles)

- **Jason.** Both PDFs extracted; no third-party paraphrase.
- **Fisher.** Published SE in SK2023 is observed Hessian of
  \(\ell\), not \(\ell+P\). No sandwich in either paper.
- **Noether.** Jeffreys \(X^\top WX\) is the penalty atom, not
  \(I_{\mathrm{LA}}(\beta)\). Soft \(c_n\) is a score condition.
- **Rose.** “An SE was formed” is still not “MSPL has standard
  errors.” Public door stays closed.
- **Shannon.** Docs-only branch off `origin/main`; no collision
  with #1058’s SE-series note or the dirty Poisson tree.
- **Ada.** Checklist is do/don’t for the next pin coder.

## 10. Known Limitations And Next Actions

- SK2023 Appendix B.4’s extra Laplace score conditions are
  **stated, not verified** for our GLLVM tape.
- Next coding (not this PR): D-149 internal pins only; do not
  invert \(Q_P\) as the paper SE; do not invent count-family
  information from these PDFs.
