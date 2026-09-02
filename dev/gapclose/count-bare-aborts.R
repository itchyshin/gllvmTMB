## Re-derives the "bare abort" count.
##
## S1 correction (adversarial review 2026-09-02): the first cut counted an
## "i" (information-only) or "x" (what-went-wrong) bullet as "has a next
## step", which is not true -- neither one tells the reader what to DO.
## Only a ">" (explicit next-step) or "*" bullet, or a
## `Use |Try |Pass |Set |Choose |Supply |Instead|see \\?` verb anywhere in
## the message, counts as actionable now. This is strictly stricter than
## the first cut, so the honest count only ever goes UP relative to it.
##
## Used both to compute the number for the ratchet test and standalone from
## the CLI for auditing.

count_bare_aborts <- function(r_dir = "R") {
  files <- list.files(r_dir, pattern = "[.]R$", full.names = TRUE)
  bare_hits <- character()

  keyword_re <- "Use |Try |Pass |Set |Choose |Supply |Instead|see \\?"
  ## S1 correction (adversarial review 2026-09-02): "i"/"x" bullets are
  ## information-only, not a next step -- only ">"/"*" count now.
  bullet_names <- c("*", ">")

  for (f in files) {
    expr <- tryCatch(parse(f, keep.source = FALSE), error = function(e) NULL)
    if (is.null(expr)) next

    walk <- function(x, path_line = NA_integer_) {
      if (is.call(x)) {
        head <- x[[1]]
        is_abort <- (is.symbol(head) && identical(as.character(head), "cli_abort")) ||
          (is.call(head) && length(head) == 3 &&
             identical(as.character(head[[1]]), "::") &&
             identical(as.character(head[[3]]), "cli_abort"))
        if (is_abort && length(x) >= 2L) {
          msg_arg <- x[[2L]]
          ## Evaluate ONLY literal character vectors / c(...) of literals --
          ## skip fully dynamic messages (paste0(...) etc.) which the
          ## original scout's static scan also could not classify.
          msg_val <- tryCatch(
            if (is.character(msg_arg)) {
              msg_arg
            } else if (is.call(msg_arg) && identical(msg_arg[[1L]], as.name("c"))) {
              parts <- as.list(msg_arg)[-1L]
              if (all(vapply(parts, is.character, logical(1L)))) {
                v <- unlist(parts)
                names(v) <- names(msg_arg)[-1L]
                v
              } else {
                NULL
              }
            } else {
              NULL
            },
            error = function(e) NULL
          )
          if (!is.null(msg_val)) {
            has_bullet <- any(names(msg_val) %in% bullet_names)
            has_keyword <- any(grepl(keyword_re, msg_val))
            if (!has_bullet && !has_keyword) {
              bare_hits[[length(bare_hits) + 1L]] <<- sprintf(
                "%s: %s", basename(f), substr(paste(msg_val, collapse = " "), 1, 70)
              )
            }
          }
        }
        for (p in as.list(x)) if (!missing(p)) try(walk(p), silent = TRUE)
      }
    }
    for (e in as.list(expr)) walk(e)
  }
  bare_hits
}

if (identical(environment(), globalenv()) && sys.nframe() == 0L) {
  hits <- count_bare_aborts("R")
  cat(length(hits), "bare aborts found.\n")
  writeLines(hits)
}
