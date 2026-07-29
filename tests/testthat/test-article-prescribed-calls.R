## Articles live in vignettes/articles/, which is listed in .Rbuildignore, so
## `R CMD check` never builds them. pkgdown builds them only after a merge to
## main, and `eval = FALSE` chunks are not executed even then. This test is the
## compensating static check: it does not run any article code, it only asks
## whether the calls an article tells a reader to write can resolve at all.

articles_dir <- testthat::test_path("..", "..", "vignettes", "articles")

## Extract R code from the chunks of an .Rmd, including eval = FALSE ones --
## those are precisely the chunks nothing else ever looks at.
chunk_code <- function(path) {
  lines <- readLines(path, warn = FALSE)
  opens <- grep("^```\\{r", lines)
  closes <- grep("^```\\s*$", lines)
  out <- list()
  for (o in opens) {
    close <- closes[closes > o]
    if (!length(close)) next
    body <- lines[seq(o + 1L, close[1] - 1L)]
    ## Chunks legitimately reference objects defined in earlier chunks; we
    ## parse only, never evaluate, so undefined objects are irrelevant here.
    expr <- tryCatch(parse(text = body), error = function(e) NULL)
    if (!is.null(expr)) out[[length(out) + 1L]] <- list(line = o, expr = expr)
  }
  out
}

## Walk a parse tree and collect every call as (fname, arg_names, char_args).
## parse() returns an `expression`, for which is.call() is FALSE -- descend into
## it explicitly or the walker silently returns nothing and the test passes
## vacuously.
calls_in <- function(x, acc = list()) {
  if (is.expression(x)) {
    for (e in as.list(x)) acc <- calls_in(e, acc)
    return(acc)
  }
  if (is.call(x)) {
    fn <- x[[1]]
    if (is.name(fn)) {
      args <- as.list(x)[-1]
      chars <- Filter(is.character, args)
      acc[[length(acc) + 1L]] <- list(
        fname = as.character(fn),
        argnames = names(args),
        chars = chars
      )
    }
    ## as.list() on a call yields the empty symbol for missing arguments (the
    ## blank in `x[i, ]`). That value errors on *any* evaluation -- even a
    ## predicate meant to detect it -- so it cannot be filtered out in advance;
    ## guard the recursion itself.
    parts <- as.list(x)
    for (i in seq_along(parts)) {
      acc <- tryCatch(calls_in(parts[[i]], acc), error = function(e) acc)
    }
  }
  acc
}

skip_if_no_articles <- function() {
  testthat::skip_if_not(
    dir.exists(articles_dir),
    "vignettes/articles is not present (expected under R CMD check on a built tarball)"
  )
}

test_that("articles call only functions gllvmTMB actually exports", {
  skip_if_no_articles()
  exported <- getNamespaceExports("gllvmTMB")

  bad <- character()
  for (f in list.files(articles_dir, pattern = "[.]Rmd$", full.names = TRUE)) {
    for (ch in chunk_code(f)) {
      for (cl in calls_in(ch$expr)) {
        ## Only adjudicate names that look like ours: a name that is not
        ## exported and not resolvable anywhere else is a broken prescription.
        if (cl$fname %in% exported) next
        if (exists(cl$fname, envir = globalenv(), inherits = TRUE)) next
        ## Unknown symbol that resembles a gllvmTMB entry point.
        if (grepl("^(extract_|plot_|diagnose_|predict_|impute|miss_|gllvmTMB)", cl$fname)) {
          bad <- c(bad, sprintf("%s:%d %s()", basename(f), ch$line, cl$fname))
        }
      }
    }
  }
  expect_equal(bad, character())
})

test_that("articles pass only admissible values to match.arg'd arguments", {
  skip_if_no_articles()
  exported <- getNamespaceExports("gllvmTMB")

  ## Values that survive match.arg() but that the function then rejects
  ## unconditionally. These cannot be caught by the choices vector alone --
  ## extract_correlations() still lists "profile" in its formals and aborts on
  ## it (class "gllvmTMB_nonlinear_profile_withdrawn").
  withdrawn <- list(extract_correlations = list(method = "profile"))

  bad <- character()
  for (f in list.files(articles_dir, pattern = "[.]Rmd$", full.names = TRUE)) {
    for (ch in chunk_code(f)) {
      for (cl in calls_in(ch$expr)) {
        if (!cl$fname %in% exported) next
        fml <- formals(getExportedValue("gllvmTMB", cl$fname))
        nms <- cl$argnames
        if (is.null(nms)) next

        for (i in seq_along(nms)) {
          nm <- nms[i]
          if (!nzchar(nm)) next

          ## (a) the argument must exist, unless the function absorbs dots
          if (!nm %in% names(fml) && !"..." %in% names(fml)) {
            bad <- c(bad, sprintf(
              "%s:%d %s(%s = ) -- not in formals", basename(f), ch$line, cl$fname, nm
            ))
            next
          }

          val <- as.list(cl)$chars[[nm]]
          if (is.null(val) || !is.character(val) || length(val) != 1L) next

          ## (b) a literal string must be one of the declared choices.
          ## A formal with no default (e.g. `fit`) is the empty symbol, which
          ## errors when forced -- hence the guard around the inspection.
          default <- fml[[nm]]
          is_choices <- tryCatch(
            is.call(default) && identical(as.character(default[[1]]), "c"),
            error = function(e) FALSE
          )
          if (is_choices) {
            choices <- as.character(unlist(as.list(default)[-1]))
            if (length(choices) > 1L && !val %in% choices) {
              bad <- c(bad, sprintf(
                "%s:%d %s(%s = \"%s\") -- not among: %s",
                basename(f), ch$line, cl$fname, nm, val, paste(choices, collapse = ", ")
              ))
            }
          }

          ## (c) ... and must not be a value the function withdraws
          w <- withdrawn[[cl$fname]]
          if (!is.null(w) && identical(w[[nm]], val)) {
            bad <- c(bad, sprintf(
              "%s:%d %s(%s = \"%s\") -- withdrawn; the call aborts",
              basename(f), ch$line, cl$fname, nm, val
            ))
          }
        }
      }
    }
  }
  expect_equal(bad, character())
})

## ---------------------------------------------------------------------------
## An article can prescribe a call that resolves perfectly and still be broken,
## if the object it operates on does not exist. That is the class that produced
## drmTMB's only BLOCKER in its equivalent audit, and it produced one here:
## response-families.Rmd operated on `mixed_long`, defined nowhere in the repo.

## Walk every call in a parse tree, applying fn to each.
walk_calls <- function(x, fn) {
  if (is.expression(x)) {
    for (e in as.list(x)) walk_calls(e, fn)
    return(invisible(NULL))
  }
  if (is.call(x)) {
    fn(x)
    parts <- as.list(x)
    for (i in seq_along(parts)) {
      tryCatch(walk_calls(parts[[i]], fn), error = function(e) NULL)
    }
  }
  invisible(NULL)
}

## Names bound anywhere in the chunk: plain assignment, for-loop variable, and
## function formals. NOT `x$col <- v` -- in R that ERRORS when x is absent, so
## counting it as a binding makes this check vacuous for the very defect it
## exists to catch.
assigned_names <- function(expr) {
  acc <- character()
  walk_calls(expr, function(cl) {
    f <- as.character(cl[[1]])[1]
    if (f %in% c("<-", "=", "<<-") && length(cl) >= 2L && is.name(cl[[2]])) {
      acc <<- c(acc, as.character(cl[[2]]))
    }
    if (f == "for" && length(cl) >= 2L && is.name(cl[[2]])) {
      acc <<- c(acc, as.character(cl[[2]]))
    }
    if (f == "function") {
      fm <- cl[[2]]
      if (!is.null(names(fm))) acc <<- c(acc, names(fm))
    }
  })
  unique(acc)
}

## Objects the chunk OPERATES ON: `x$col`, `x[["col"]]`. A name merely passed as
## `data = x` is deliberately excluded -- that is a placeholder in a syntax
## sketch, where the reader substitutes their own frame, not a broken example.
operated_on <- function(expr) {
  acc <- character()
  walk_calls(expr, function(cl) {
    f <- as.character(cl[[1]])[1]
    if (f %in% c("$", "[[") && length(cl) >= 2L && is.name(cl[[2]])) {
      acc <<- c(acc, as.character(cl[[2]]))
    }
  })
  unique(acc)
}

test_that("articles do not operate on objects they never define", {
  skip_if_no_articles()
  known <- c(ls("package:base"), ls("package:datasets"), getNamespaceExports("gllvmTMB"))

  bad <- character()
  for (f in list.files(articles_dir, pattern = "[.]Rmd$", full.names = TRUE)) {
    chs <- chunk_code(f)
    ## Whole-article binding set first: flag only names bound NOWHERE in the
    ## article. "Used before defined" is a weaker, separate defect (it only
    ## bites when chunks are run out of order) and would drown this one.
    defs <- unique(unlist(lapply(chs, function(ch) assigned_names(ch$expr))))
    for (ch in chs) {
      missing <- setdiff(operated_on(ch$expr), c(defs, known))
      if (length(missing)) {
        bad <- c(bad, sprintf(
          "%s:%d operates on undefined %s", basename(f), ch$line,
          paste(missing, collapse = ", ")
        ))
      }
    }
  }
  expect_equal(bad, character())
})
