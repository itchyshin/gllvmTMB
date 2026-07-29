# Man-page honesty sweep — clean on two axes, and the third is not automatable

Lane `claude/manpage-honesty-20260729`, 2026-07-29, on `origin/main` @ `66502e9c`.
`PLATFORM: claude | LANE: manpage-honesty | FOREIGN LANE: none detected (weak evidence, D-87)`

This is a **negative result**, recorded so it is not re-derived. It also narrows what the
remaining reference-doc work actually is, which turns out to be the more useful half.

## The structural surface

138 man pages; **97 carry `\examples`**. Of those, **72 contain `\dontrun{}`** — never executed
by anything, including `R CMD check --run-donttest`. Only 3 use `\donttest{}` (which *is* run,
and passed in the 2026-07-29 `--as-cran` run on merged `main`).

So the unexecuted example surface here is **larger than the articles'** (72 pages vs 27 chunks).
That made it the obvious place to look.

## Axis 1 — executable honesty: CLEAN

Extracted every example including `\dontrun{}` (`tools::Rd2ex(commentDontrun = FALSE)`), parsed
it, and checked each call against `NAMESPACE` and `formals`: **1,774 calls across 98 pages with
parseable examples.**

**3 candidates, all 3 false positives.** No defect found.

| Candidate | Why it is not a defect |
|---|---|
| `animal_slope(x \| species, A = A)` — `A` not in formals | `animal_slope` is a **formula DSL keyword**, parsed by the package's grammar and never evaluated as an R call. `formals()` is not its contract. This is the exact trap `CROSS-REPO-GUARDS` names: DSL keywords are invisible to function-level probes |
| `extract_Sigma(fit, level = "known")` — not among `level` choices | Correct usage. `kernel_latent.Rd:66` declares `name = "known"`, and `.kernel_level_alias()` resolves a kernel tier by **its name**. The checker does not model the alias path |
| `suggest_lambda_constraints(methods = "profile_retention")` | Valid. `R/suggest-lambda-constraint.R:533-540` defines an `allowed` set of six; the formals default is a **subset**, validated by `setdiff`, not `match.arg` |

**The article guard was therefore NOT shipped against `man/`.** It is wrong here in three
distinct ways — DSL keywords, alias resolvers, and default-as-subset-of-allowed — and would
have produced three confident false alarms. A guard with a 100% false-positive rate on a
surface is worse than no guard on that surface.

Worth noting for the record: `kernel_latent.Rd` has had `level = "known"` **right all along**,
while `api-keyword-grid.Rmd` had `level = "kernel"` **wrong** until it was fixed in #814. The
reference documentation was more accurate than the narrative documentation.

## Axis 2 — overclaim vocabulary: CLEAN

82 hits across 8 words. **Polarity checked for every word individually** — not generalised from
a subset, which is the error made on the article surface on 2026-07-28 and corrected in #809.

| Word | Hits | Verdict |
|---|---:|---|
| `certified` | 6 | all negative ("has not been certified", "is not yet certified") |
| `calibrated` | 20 | all negative; the six with no same-line negation are line-wrap fragments, each verified in context |
| `coverage` | 29 | no positive claim; residuals are fragments of negations or scoped statements |
| `reliable` | 18 | **not claims at all** — every hit is the function name `flag_unreliable_loadings()` or its `unreliable` column |
| `validated` | 4 | 2 are the status string `heuristic_unvalidated`; 1 negative; 1 genuine positive, and it is **backed** — see below |
| `guarantee` | 4 | 3 negative; 1 positive that is true by construction (`tanh` bounds lie inside [-1, 1]) |
| `accurate` | 1 | explicitly negative: *"it is not a certificate that the Laplace approximation is accurate"* |
| `unbiased`, `proven` | 0 | — |

**The one positive claim was checked, not assumed.** `pedigree_to_Ainv_sparse.Rd:71` says the
builder "is validated against" `MCMCglmm::inverseA()`. That is backed:
`tests/testthat/test-pedigree-precision.R:36,42` assert reproduction for both the non-inbred and
inbred (F>0) cases; MCMCglmm is declared in `DESCRIPTION` Suggests (`:70`) and every use is
guarded by `skip_if_not_installed()`.

## Axis 3 — behavioural accuracy: NOT CHECKED, and not automatable

This is the important part, because it is where the article defects actually lived.

Of the 13 confirmed article findings, **most were neither invalid calls nor loaded adjectives**.
They were prose that described behaviour incorrectly — `part = "unique"` called "a named numeric
vector" when it returns a **list**; rootograms said to support two families when they support
three; a reader pointed at a message the article's own chunk options suppress. Every one ran
fine and used no overclaiming vocabulary.

**Nothing in this sweep tests that class for man pages.** No parser can: settling "does this
sentence describe what the function actually does?" requires reading the sentence and the
implementation together.

That is precisely the job `CLAUDE.md` names — *"the one-by-one human review of the pkgdown pages
and the function docs WITH Shinichi (slow, deliberate; not a batch rewrite)"* — and this sweep's
main contribution is to show it cannot be short-circuited by tooling. The two cheap axes are
now demonstrably clear, so that review can start from the expensive one.

## Method note

Three shell patterns **silently under-reported** during this sweep, each of which would have
read as "clean":

1. `.{75}word` — requires 75 characters before the word on the same line; hits near a line start
   vanish. Showed 3 of 6 `certified` hits.
2. An `awk` range over `DESCRIPTION` dependency fields — missed a multi-line continuation and
   reported MCMCglmm as undeclared. A plain `grep -c` on the same file returned 1. Had this not
   been cross-checked, it would have been filed as a false CRAN-policy defect.
3. (2026-07-28, same class) `\b` in `grep -E` on macOS BSD grep, which is ignored outright.

The generalisable point: **every one of these failures produces a false negative, and a false
negative on an audit is indistinguishable from a clean result.** Cross-check any zero a second
way before reporting it.

## Deliberately NOT claimed

* No claim that the man pages are *correct* — only that they contain no invalid example calls
  and no unsupported overclaiming vocabulary.
* No guard test added. 3/3 false positives on this surface; shipping it would manufacture noise.
* `\examples{}` blocks outside `\dontrun{}` do execute under `R CMD check` and passed; that
  proves execution, not truth.
