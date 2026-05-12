---
name: prose-style-review
description: Review and improve gllvmTMB prose in README files, vignettes, pkgdown articles, after-task reports, release notes, design docs, and manuscript-style text for clarity, concrete claims, stable terminology, citations, and reader fit.
---

# Prose Style Review

Use this skill for substantial prose, especially public documentation
and after-task reports. It is a compact gllvmTMB adaptation of
the upstream prose-style discipline; do not vendor external
prose-style projects.

## Reader First

Before editing, name the reader:

- applied ecology, evolution, or environmental-science user;
- adjacent-field graduate student;
- statistical method developer;
- R package contributor;
- reviewer of a paper, grant, or release.

Write for that reader's current knowledge. Explain a term when the
reader would otherwise have to infer it from context.

## Review Checklist

1. Lead with purpose before mechanics.
2. For model docs, pair symbolic equation, R syntax, and
   interpretation. The 5-row alignment table from the
   `add-simulation-test` skill is the canonical form when an article
   exposes the multi-tier covariance structure.
3. Replace vague nouns with concrete functions, parameters, files,
   equations, checks, or numerical results.
4. Use active voice when the actor matters.
5. Delete filler phrases such as "it is important to note that",
   "in order to", "various factors", "significant improvements",
   and "leverages".
6. Do not over-bullet. Use bullets for genuine lists; use prose for
   one or two connected ideas.
7. Keep terms stable: `Sigma`, `Lambda`, `s`, `latent()`, `unique()`,
   `indep()`, `dep()`, `phylo_*()`, `spatial_*()`, `meta_known_V(V =
   V)`, `traits()`. The decomposition mode is `latent + unique`
   paired (Sigma = Lambda Lambda^T + diag(s)); standalone `latent`
   is the no-residual subset and standalone `unique` is the
   marginal/independent mode -- describe these correctly.
   **Notation convention** (per `decisions.md`, 2026-05-12):
   the unique-variance diagonal in math is always `S` / `s`,
   never `U`. The string "two-U" is OK as a task label / function
   nickname (it matches existing function names and file paths),
   but in user-facing math prose write `Sigma_phy = Lambda_phy
   Lambda_phy^T + diag(s_phy)`, `Omega = Sigma_phy + Sigma_non`,
   etc. A `diag(U)` in roxygen or article body is a drift to flag.
8. **Two-shape data framing** (per `decisions.md`, Option B + sugar
   pivot in PR #39): the package accepts data as either *long*
   (`gllvmTMB(value ~ ..., data = df_long, ...)`) or *wide*
   (`gllvmTMB_wide(Y, ...)` where `Y` is a numeric matrix or a
   wide data frame). The `traits(...)` formula LHS marker is the
   parser path that also accepts the sugar form
   `traits(...) ~ 1 + latent(1 | unit, d = K)`. Tier-1 and
   user-facing prose should describe two shapes, not three.
8. Support factual, statistical, or literature claims with citations,
   local evidence, check outputs, or a clear "design assumption" label.
9. For tutorials and error-message docs, tell the reader what to do
   next when a model or syntax is unsupported.
10. Define each technical term at first use. The 3 x 5 keyword grid
    (correlation x mode) is the most-glossed concept; treat it as
    new every time.
11. End paragraphs with the point the reader should carry forward.
12. Avoid repeated sentence openings and repeated paragraph-summary
    closers.

## Role Guidance

- Pat checks whether an applied user can follow the prose, run the
  example, and interpret the output.
- Rose checks stale wording, unsupported claims, duplicated summaries,
  and contradictions with code, docs, tests, roadmap, or after-task
  notes.
- Documentation writers (Boole + Pat in the team table) check
  examples, headings, equations, citations, and pkgdown navigation as
  one learning path.

## Output

For a review-only task, return:

- blocking confusion;
- important friction;
- small polish;
- suggested wording for the highest-impact fixes.

For an edit task, make the smallest prose edits that fix the problem,
then record what changed in the check log or after-task report when
the task is meaningful.
