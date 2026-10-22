#!/usr/bin/env Rscript

args <- commandArgs(trailingOnly = TRUE)
site_dir <- if (length(args)) args[[1L]] else "pkgdown-site"
site_dir <- normalizePath(site_dir, mustWork = TRUE)

private_stems <- c("AGENTS", "CLAUDE", "CONTRIBUTING", "ROADMAP")
private_pages <- paste0(private_stems, ".html")
leaked_pages <- private_pages[file.exists(file.path(site_dir, private_pages))]
if (length(leaked_pages)) {
  stop(
    "Private root pages were generated: ",
    paste(leaked_pages, collapse = ", "),
    call. = FALSE
  )
}

required_pages <- c(
  "index.html",
  file.path("articles", "gllvmTMB.html"),
  file.path("articles", "current-limits.html")
)
missing_pages <- required_pages[!file.exists(file.path(site_dir, required_pages))]
if (length(missing_pages)) {
  stop(
    "Expected reader pages are missing: ",
    paste(missing_pages, collapse = ", "),
    call. = FALSE
  )
}

required_indexes <- c("search.json", "sitemap.xml", "llms.txt")
missing_indexes <- required_indexes[
  !file.exists(file.path(site_dir, required_indexes))
]
if (length(missing_indexes)) {
  stop(
    "Expected site indexes are missing: ",
    paste(missing_indexes, collapse = ", "),
    call. = FALSE
  )
}

# The source README is the home-page body, but its Markdown is not the public
# artifact. Parse the generated main content so an apparently harmless template
# or sidebar change cannot put the safety notice ahead of the explanation.
home <- xml2::read_html(file.path(site_dir, "index.html"))
home_main <- xml2::xml_find_first(home, "//main")
home_text <- xml2::xml_text(home_main)
definition_at <- regexpr(
  "GLLVM means generalized linear latent-variable model",
  home_text,
  fixed = TRUE
)[[1L]]
purpose_at <- regexpr("several responses together", home_text, fixed = TRUE)[[1L]]
warning_at <- regexpr("Experimental software", home_text, fixed = TRUE)[[1L]]
if (definition_at < 1L || purpose_at < 1L || warning_at < 1L ||
    definition_at >= warning_at || purpose_at >= warning_at) {
  stop(
    "Rendered landing page must define GLLVM and its multi-response purpose before the experimental warning.",
    call. = FALSE
  )
}

html_files <- list.files(
  site_dir,
  pattern = "[.]html$",
  recursive = TRUE,
  full.names = TRUE
)
files_to_scan <- c(html_files, file.path(site_dir, required_indexes))
private_target <- paste0("(?i)(?:^|[/\"'])", paste(private_pages, collapse = "|"))
reader_tracking <- paste(
  "(?i)(?:",
  "\\b(?:PR|issue)\\s*#\\d+|\\bArc\\s+\\d+\\b|",
  "\\b(?:implementation|development|work|active)\\s+lane\\b|\\bworktree\\b|\\bdev-log/|",
  "\\b(?:agent|persona)\\s+(?:review|approved|approval|handoff)\\b|",
  "\\b(?:Rose|Pat)\\s+(?:reviewed|approved)\\b|",
  "\\bfixture(?:-backed|\\s+evidence)\\b|\\bcapability\\s+ledger\\b|",
  "\\b(?:catch-up\\s+)?scoreboard\\b|\\boptimizer-health\\b|",
  "\\b[A-Z]{2,4}-[0-9]{2,}\\b|\\bM[0-9](?:\\.[0-9])?\\b|\\bD-[0-9]{1,3}\\b",
  ")",
  sep = ""
)

is_spde_matrix_notation <- function(text, start, length) {
  token <- substr(text, start, start + length - 1L)
  if (!grepl("^M[0-9](?:[.][0-9])?$", token, ignore.case = TRUE, perl = TRUE)) {
    return(FALSE)
  }

  # pkgdown's search index keeps both flattened and source-like mathematics,
  # turning M_2 into M2. Exempt only an M-number inside the local SPDE matrix
  # triad (M0, M1, M2), not a bare M2 or a milestone-labelled M2.
  context_start <- max(1L, start - 160L)
  context_end <- min(nchar(text), start + length - 1L + 160L)
  context <- substr(text, context_start, context_end)
  tracking_cue <- grepl(
    paste0(
      "(?i)(?:\\b(?:milestone|phase|stage|track|gate)\\s+",
      "M[0-9](?:[.][0-9])?\\b|\\bM[0-9](?:[.][0-9])?\\s+",
      "(?:milestone|phase|stage|track|gate|status)\\b)"
    ),
    context,
    perl = TRUE
  )
  if (tracking_cue) {
    return(FALSE)
  }
  matrix_matches <- gregexpr("M_?[0-2]", context, perl = TRUE)[[1L]]
  if (matrix_matches[[1L]] == -1L) {
    return(FALSE)
  }
  matrix_tokens <- regmatches(context, list(matrix_matches))[[1L]]
  matrix_tokens <- unique(toupper(gsub("_", "", matrix_tokens, fixed = TRUE)))
  has_matrix_context <- grepl(
    "(?i)(?:\\bmesh\\b|\\bmatri(?:x|ces)\\b|Q\\s*[(]|kappa|κ)",
    context,
    perl = TRUE
  )
  has_matrix_context && all(c("M0", "M1", "M2") %in% matrix_tokens)
}

contains_reader_tracking <- function(text) {
  matches <- gregexpr(reader_tracking, text, perl = TRUE)[[1L]]
  if (matches[[1L]] == -1L) {
    return(FALSE)
  }
  lengths <- attr(matches, "match.length")
  for (i in seq_along(matches)) {
    if (!is_spde_matrix_notation(text, matches[[i]], lengths[[i]])) {
      return(TRUE)
    }
  }
  FALSE
}

leaks <- vapply(files_to_scan, function(path) {
  any(grepl(private_target, readLines(path, warn = FALSE), perl = TRUE))
}, logical(1))
tracking_leaks <- vapply(files_to_scan, function(path) {
  text <- paste(readLines(path, warn = FALSE), collapse = " ")
  contains_reader_tracking(text)
}, logical(1))
if (any(leaks | tracking_leaks)) {
  stop(
    "Private links or internal process language leaked into generated site files: ",
    paste(
      sub(paste0("^", site_dir, "/"), "", files_to_scan[leaks | tracking_leaks]),
      collapse = ", "
    ),
    call. = FALSE
  )
}

cat("PKGDOWN PUBLIC SURFACE PASS\n")
