#!/usr/bin/env Rscript
# Current article check: parsing, frozen DGP regeneration and receipt reads only.
# No fits, plotting, rendering or objective/gradient evaluations are performed.
library(gllvmTMB)
root <- "/private/tmp/gllvm-tree-axis-latent-20260830/coefficient-standardization-7c88"
article_path <- "vignettes/articles/where-does-the-tree-go.Rmd"
html_path <- "pkgdown-site/articles/where-does-the-tree-go.html"
fixture_path <- "dev/tree-axis-latent/fixture.R"
sha <- function(path) digest::digest(file = path, algo = "sha256")
stopifnot(identical(unname(tools::md5sum(fixture_path)),
                    "6c3bae640dd86491171cb20fbb56b0e4"))
.article_check_fit_entries <- 0L
.article_check_optimizer_entries <- 0L
trace("gllvmTMB", where = asNamespace("gllvmTMB"), print = FALSE,
  tracer = quote({
    .GlobalEnv$.article_check_fit_entries <- .GlobalEnv$.article_check_fit_entries + 1L
    stop("No fit permitted in the current article checker")
  }))
trace(".gllvmTMB_run_nlminb", where = asNamespace("gllvmTMB"), print = FALSE,
  tracer = quote({
    .GlobalEnv$.article_check_optimizer_entries <- .GlobalEnv$.article_check_optimizer_entries + 1L
    stop("No optimizer permitted in the current article checker")
  }))
for (name in c("nlminb", "optim")) trace(name, where = asNamespace("stats"),
  print = FALSE, tracer = quote({
    .GlobalEnv$.article_check_optimizer_entries <- .GlobalEnv$.article_check_optimizer_entries + 1L
    stop("No optimizer permitted in the current article checker")
  }))

# Parse the current code chunks, preserving displayed eval=FALSE alternatives.
lines <- readLines(article_path)
chunks <- list()
headers <- list()
active <- NULL
for (line in lines) {
  if (grepl("^```\\{r", line)) {
    stopifnot(is.null(active))
    active <- sub("^```\\{r +([^,} ]+).*", "\\1", line)
    stopifnot(!active %in% names(chunks))
    headers[[active]] <- line
    code <- character()
  } else if (!is.null(active) && identical(line, "```")) {
    chunks[[active]] <- parse(text = code)
    active <- NULL
  } else if (!is.null(active)) code <- c(code, line)
}
stopifnot(is.null(active))
fit_calls <- list()
walk <- function(x) {
  if (!is.call(x) && !is.expression(x) && !is.pairlist(x)) return(invisible(NULL))
  if (is.call(x) && identical(x[[1]], as.name("gllvmTMB"))) {
    named <- names(as.list(x))[-1L]
    stopifnot(all(named[nzchar(named)] %in% names(formals(gllvmTMB))))
    call <- match.call(gllvmTMB, x)
    stopifnot(identical(call$control, quote(fit_control)),
      identical(call$family, quote(gaussian())))
    fit_calls[[length(fit_calls) + 1L]] <<- call
  }
  for (y in as.list(x)) {
    if (missing(y)) next
    if (is.recursive(y)) walk(y)
  }
}
invisible(lapply(chunks, walk))
stopifnot(length(fit_calls) == 6L)
fit_labels <- c("morphology-long", "morphology-wide", "community-long", "community-wide")
seed_count <- 0L
for (label in fit_labels) {
  expr <- chunks[[label]]
  stopifnot(length(expr) %% 2L == 0L)
  for (i in seq.int(1L, length(expr), by = 2L)) {
    stopifnot(identical(expr[[i]], quote(set.seed(202608501L))),
      identical(expr[[i + 1L]][[1]], as.name("<-")),
      identical(expr[[i + 1L]][[3]][[1]], as.name("gllvmTMB")))
    seed_count <- seed_count + 1L
  }
}
stopifnot(seed_count == 6L,
  all(vapply(headers[c("morphology-wide", "community-wide")],
    function(x) grepl("eval\\s*=\\s*FALSE", x), logical(1))),
  !any(vapply(headers[c("morphology-long", "community-long")],
    function(x) grepl("eval\\s*=\\s*FALSE", x), logical(1))))

article <- new.env(parent = globalenv())
# Deliberately exclude setup, plot helpers, model calls and every figure chunk.
for (name in c("packages", "simulation-helpers", "morphology-dgp", "community-dgp")) {
  eval(chunks[[name]], envir = article)
}
expected_control <- gllvmTMBcontrol(se = FALSE, n_init = 1L,
  optimizer = "nlminb", optArgs = list(), init_jitter = 0,
  start_method = list(method = NULL, jitter.sd = 0))
stopifnot(identical(article$fit_control, expected_control))
reference <- new.env(parent = globalenv())
sys.source(fixture_path, reference)
frozen <- reference$make_tree_axis_fixture("target")
stopifnot(identical(article$fixture, frozen))

# Require the embedded DGP's executable expressions themselves to match, not
# merely one coincidentally equal draw. The frozen formula helper is separate.
fixture_expr <- parse(fixture_path)
formula_assignment <- vapply(fixture_expr, function(x) is.call(x) &&
  identical(x[[1]], as.name("<-")) && identical(x[[2]], as.name("tree_axis_formulae")), logical(1))
stopifnot(sum(formula_assignment) == 1L)
canonical <- function(x) {
  replace <- c(tree_morph = "tree", tree_columns = "tree",
    traits_morph = "morph_traits", species_comm = "community_species")
  if (is.name(x) && as.character(x) %in% names(replace)) return(as.name(replace[[as.character(x)]]))
  if (is.call(x)) return(as.call(lapply(as.list(x), canonical)))
  if (is.expression(x)) return(as.expression(lapply(as.list(x), canonical)))
  x
}
stopifnot(identical(canonical(chunks[["simulation-helpers"]]),
                    canonical(fixture_expr[!formula_assignment])))
formula_names <- c("morphology_long", "morphology_wide", "community_iid_long",
                   "community_phylo_long", "community_iid_wide", "community_phylo_wide")
formula_reference <- reference$tree_axis_formulae(frozen)
data_names <- c("morphology", "morphology_wide", "community", "community",
                "community_wide", "community_wide")
for (i in seq_along(fit_calls)) {
  call <- fit_calls[[i]]
  stopifnot(identical(canonical(call$formula), canonical(formula_reference[[formula_names[i]]])),
    identical(call$data, as.name(data_names[i])),
    identical(call$unit, if (i <= 2L) "species" else "site_id"))
  if (i <= 2L) stopifnot(identical(call$cluster, "species"))
  if (i %in% c(1L, 3L, 4L)) stopifnot(identical(call$trait, "trait"))
  if (i >= 5L) stopifnot(identical(call$column_data, quote(column_data)))
}
cat("ARTICLE_FROZEN_DGP_EXPRESSIONS_AND_VALUES_PASS\n",
    "ARTICLE_SIX_SUPPORTED_CALLS_FORMULAS_CONTROLS_SEEDS_PASS\n", sep = "")

# Bind installed code and DLL to the completed validation block, then bind
# today's presentation render to the exact source, HTML and primary fits.
manifest <- jsonlite::read_json(file.path(root, "provenance.json"), simplifyVector = TRUE)
current_manifest <- manifest
expected_sources <- c(list.files("R", pattern = "[.]R$", full.names = TRUE),
  "src/gllvmTMB.cpp", "inst/include/gllvmTMB/detail/column_prior.hpp", "NAMESPACE", "DESCRIPTION")
stopifnot(setequal(names(manifest$source_sha256), expected_sources),
  setequal(names(current_manifest$source_sha256), expected_sources),
  identical(normalizePath(find.package("gllvmTMB")), current_manifest$library),
  identical(sha(file.path(current_manifest$library, "libs/gllvmTMB.so")), current_manifest$dll_sha256))
for (path in expected_sources) stopifnot(identical(sha(path), current_manifest$source_sha256[[path]]))
primary_path <- file.path(root, "primary-render-1/receipt.rds")
primary <- readRDS(primary_path)
stopifnot(primary$primary_render_entries == 3L, primary$standalone_count == 41L)
render_paths <- list.files(root, pattern = "^presentation-render-[1-9][0-9]*[.]rds$", full.names = TRUE)
stopifnot(length(render_paths) > 0L)
render_ids <- as.integer(sub(".*presentation-render-([0-9]+)[.]rds$", "\\1", render_paths))
render_path <- render_paths[which.max(render_ids)]
render <- readRDS(render_path)
stopifnot(render$outer_optimizer_calls == 0L,
  identical(render$article_sha256, sha(article_path)),
  identical(render$html_sha256, sha(html_path)),
  identical(render$fitted_objects_sha256, sha(primary_path)))
for (i in 1:3) {
  id <- c("G1", "Q2", "Q3")[[i]]
  reference_root <- if (i == 1L) "/private/tmp/gllvm-tree-axis-latent-20260830/cell-integration-7c88" else root
  saved <- readRDS(file.path(reference_root, paste0("fit-", id, ".rds")))
  entry <- readRDS(file.path(root, "primary-render-1", paste0(id, "-start.rds")))
  returned <- readRDS(file.path(root, "primary-render-1", paste0(id, "-result.rds")))
  fit <- primary$fits[[i]]
  if (i > 1L) stopifnot(identical(saved$provenance, manifest))
  stopifnot(identical(isTRUE(fit$standardized_column_coef), i > 1L),
    identical(entry$start, saved$optimizer_calls[[1L]]$start),
    identical(returned$par, fit$opt$par), returned$convergence == 0L,
    identical(as.numeric(returned$objective), as.numeric(fit$opt$objective)),
    identical(as.numeric(fit$tmb_data$y), if (i == 1L) frozen$morphology$long$value else frozen$community$long$value),
    isTRUE(fit$integrated_gaussian_diag_B))
}
stopifnot(.article_check_fit_entries == 0L, .article_check_optimizer_entries == 0L)
continuity <- readRDS(file.path(root, "prefit-gate.rds"))
stopifnot(isTRUE(continuity$pass))
cat("ARTICLE_SOURCE_DLL_RENDER_PRIMARY_RECEIPTS_PASS\n",
    "article_sha256=", sha(article_path), "\nhtml_sha256=", sha(html_path),
    "\npresentation_receipt=", basename(render_path),
    "\nCURRENT_ARTICLE_CHECK_PASS fit_calls=0 outer_optimizer_calls=0 plots=0 renders=0\n", sep = "")
