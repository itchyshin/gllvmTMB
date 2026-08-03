## GUARD: no internal register codes on reader-facing surfaces.
##
## WHY THIS EXISTS, and why it is a test rather than a note.
##
## The rule ("reader-facing content shows only what makes sense to the reader --
## no internal register codes on any surface") has been in CLAUDE.md for months,
## and the codes came back anyway. The dev-log records at least four prior
## manual sweeps -- 2026-05-12-long-wide-reader-sweep,
## 2026-06-19-animal-model-reader-scope-diagnostics,
## -mixed-family-extractors-reader-scope, -ordinal-probit-reader-scope -- and on
## 2026-08-02 the maintainer hit `2C` on a published article and asked, plainly,
## "what is 2C". That sweep found 14 sites across 14 files.
##
## Manual sweeps do not work here, because the mistake is a SIDE EFFECT OF DOING
## THE RIGHT THING. An author who wants to state a validation limit honestly
## reaches for docs/design/35-validation-debt-register.md, which is indexed BY
## CODE -- so citing the limit drags the identifier along with it. The incentive
## points at the defect. Asking authors to try harder cannot fix that; only a
## check that fires can.
##
## WHAT TO DO WHEN THIS TEST FAILS. Do NOT delete the code and move on. The
## codes carry two different kinds of content:
##   * Pure redundancy (e.g. `2C`, where the prose beside it already says
##     "reference-invariant multiple correlation") -- just remove it.
##   * A VALIDATION-SCOPE caveat (e.g. SPA-01, FG-13) that a reader genuinely
##     needs. Removing the label must NOT remove the honesty. Restate the limit
##     in plain words. Deleting a scope caveat to silence this test is a worse
##     outcome than the code was.
## If you cannot determine what a code means, leave it and ask -- an invented
## meaning is far worse than a surviving identifier.
##
## SCOPE: reader-facing surfaces only. Internal surfaces (docs/design/, dev/,
## docs/dev-log/, tests/) are where these codes BELONG and are not checked.

testthat::test_that("no internal register codes reach reader-facing surfaces", {
  testthat::skip_on_cran()

  ## Runs from a source checkout only: vignettes/, NEWS.md and README.md are not
  ## present in an installed package. Skipping there is correct, not a gap --
  ## the guard's job is to stop codes being COMMITTED, and CI runs from source.
  root <- testthat::test_path("..", "..")
  testthat::skip_if_not(
    dir.exists(file.path(root, "vignettes")) && file.exists(file.path(root, "NEWS.md")),
    "not a source checkout"
  )

  targets <- c(
    list.files(file.path(root, "vignettes"), pattern = "[.]Rmd$",
               recursive = TRUE, full.names = TRUE),
    list.files(file.path(root, "man"), pattern = "[.]Rd$", full.names = TRUE),
    file.path(root, c("NEWS.md", "README.md"))
  )
  targets <- targets[file.exists(targets)]
  testthat::skip_if(length(targets) == 0L, "no reader-facing files found")

  ## Register-code shapes actually used by this project's registers. Anchored so
  ## ordinary prose ("Figure 2C", a chemical name) does not trip it: each needs
  ## the LETTERS-DASH-DIGITS form, or the explicit "decision <n><LETTER>" phrasing
  ## that the 2026-08-02 sweep found.
  patterns <- c(
    "\\b(SPA|FG|FAM|EXT|MIS|CI|VA|PHY|COE|QG)-[0-9]{2,}\\b",
    "\\((?:reporting )?decision [0-9]+[A-Z]\\)",
    "\\bthe [0-9]+[A-Z] (?:multiple correlation|summary|decision)\\b"
  )

  offenders <- list()
  for (f in targets) {
    txt <- tryCatch(readLines(f, warn = FALSE), error = function(e) character())
    if (!length(txt)) next
    hit <- rep(FALSE, length(txt))
    for (p in patterns) hit <- hit | grepl(p, txt, perl = TRUE)
    if (any(hit)) {
      offenders[[length(offenders) + 1L]] <- sprintf(
        "%s:%s: %s", sub(paste0("^", root, "/?"), "", f),
        paste(which(hit), collapse = ","),
        trimws(substr(txt[which(hit)[1]], 1, 90)))
    }
  }

  testthat::expect_true(
    length(offenders) == 0L,
    info = paste0(
      "Internal register codes found on reader-facing surfaces (", length(offenders),
      " file(s)). A reader cannot resolve these.\n",
      paste(unlist(offenders), collapse = "\n"),
      "\n\nRestate the MEANING in plain words; do not simply delete a scope caveat.",
      "\nFor man/*.Rd, fix the roxygen source in R/ and re-run devtools::document()."
    )
  )
})
