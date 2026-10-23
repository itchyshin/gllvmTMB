## dev/mizuno-vignette/fetch-mizuno-data.R
## ============================================================
## Fetch-on-build data layer for the planned Mizuno et al. (2025) J. Evol.
## Biol. 38:1699-1715 (doi 10.1093/jeb/voaf116) worked-example article.
## Archive: https://github.com/Ayumi-495/PGLMM_tutorial (Zenodo
## 10.5281/zenodo.17038830), CC BY 4.0. The archive README says the
## tutorial is still being updated, so this layer PINS and SCHEMA-CHECKS
## rather than trusting stability.
##
## NEVER redistributes data into the repo: cached outside version control
## at tools::R_user_dir("gllvmTMB", "cache") (or GLLVMTMB_CACHE_DIR if
## set). The trees are Jetz/BirdTree-derived with no explicit licence.
##
## Usage:
##   source("dev/mizuno-vignette/fetch-mizuno-data.R")
##   ex1 <- mizuno_load_ordinal()      # accipitridae body-mass/migration
##   ex2 <- mizuno_load_nominal()      # turdidae lifestyle
## Both return NULL (with a message, never an error) if there is no cache
## AND no network -- callers (the article) must check for NULL and skip
## the chunk with a visible note rather than rendering half a page.

.mizuno_cache_dir <- function() {
  d <- Sys.getenv("GLLVMTMB_CACHE_DIR", unset = "")
  if (!nzchar(d)) d <- tools::R_user_dir("gllvmTMB", "cache")
  d <- file.path(d, "mizuno-vignette")
  if (!dir.exists(d)) dir.create(d, recursive = TRUE)
  d
}

.mizuno_urls <- list(
  accip_csv = "https://raw.githubusercontent.com/Ayumi-495/PGLMM_tutorial/main/data/bird%20body%20mass/accipitridae_sampled.csv",
  accip_nex = "https://raw.githubusercontent.com/Ayumi-495/PGLMM_tutorial/main/data/bird%20body%20mass/accipitridae_sampled.nex",
  turd_csv  = "https://raw.githubusercontent.com/Ayumi-495/PGLMM_tutorial/main/data/potential/avonet/turdidae.csv",
  turd_nex  = "https://raw.githubusercontent.com/Ayumi-495/PGLMM_tutorial/main/data/potential/avonet/trees.nex"
)

## Fetch one file to cache if not already cached; never re-download a
## cached file. Returns the local path, or NULL (with a message) if the
## file is neither cached nor reachable.
.mizuno_fetch <- function(name) {
  url <- .mizuno_urls[[name]]
  dest <- file.path(.mizuno_cache_dir(), basename(URLdecode(url)))
  if (file.exists(dest)) return(dest)
  ok <- tryCatch({
    utils::download.file(url, dest, mode = "wb", quiet = TRUE)
    TRUE
  }, error = function(e) FALSE, warning = function(w) FALSE)
  if (!ok || !file.exists(dest) || file.size(dest) == 0) {
    if (file.exists(dest)) unlink(dest)
    message(
      "gllvmTMB Mizuno-vignette data layer: could not fetch '", name,
      "' from ", url, " (no network, or the archive moved) and no cache ",
      "exists. This example will be skipped -- see the archive at ",
      "https://github.com/Ayumi-495/PGLMM_tutorial."
    )
    return(NULL)
  }
  dest
}

## Load a (possibly multi-tree) Nexus file and take the first tree, as
## the tutorial itself does (`trees[[1]]`).
.mizuno_read_tree1 <- function(path) {
  tr <- ape::read.nexus(path)
  if (inherits(tr, "multiPhylo")) tr <- tr[[1]]
  tr
}

## Fail loudly with an actionable message if the schema moved.
.mizuno_schema_check <- function(df, required_cols, label) {
  missing <- setdiff(required_cols, names(df))
  if (length(missing) > 0) {
    stop(
      "gllvmTMB Mizuno-vignette data layer: '", label, "' is missing ",
      "expected column(s): ", paste(missing, collapse = ", "), ". The ",
      "PGLMM_tutorial archive README says it is still being updated -- ",
      "re-check https://github.com/Ayumi-495/PGLMM_tutorial for a schema ",
      "change before re-running.",
      call. = FALSE
    )
  }
  invisible(TRUE)
}

## ---------------------------------------------------------------
## Example 1 -- ordinal: accipitridae Migration_ordered ~ logMass
## ---------------------------------------------------------------
mizuno_load_ordinal <- function() {
  csv <- .mizuno_fetch("accip_csv")
  nex <- .mizuno_fetch("accip_nex")
  if (is.null(csv) || is.null(nex)) return(NULL)

  dat <- utils::read.csv(csv, stringsAsFactors = FALSE)
  .mizuno_schema_check(dat, c("Phylo", "Mass", "Migration"), "accipitridae_sampled.csv")

  mig_levels <- c("sedentary", "partially_migratory", "migratory")
  seen <- setdiff(unique(dat$Migration), mig_levels)
  if (length(seen) > 0) {
    stop(
      "gllvmTMB Mizuno-vignette data layer: accipitridae_sampled.csv's ",
      "'Migration' column has unexpected level(s) ", paste(seen, collapse = ", "),
      " -- expected only ", paste(mig_levels, collapse = ", "),
      ". Data schema moved; re-check the archive.",
      call. = FALSE
    )
  }
  dat$Migration_ordered <- factor(dat$Migration, levels = mig_levels, ordered = TRUE)
  dat$logMass <- log(dat$Mass)
  dat$species <- factor(dat$Phylo)

  tree <- .mizuno_read_tree1(nex)
  mismatch <- union(setdiff(tree$tip.label, levels(dat$species)),
                     setdiff(levels(dat$species), tree$tip.label))
  if (length(mismatch) > 0) {
    stop(
      "gllvmTMB Mizuno-vignette data layer: accipitridae tree tip labels ",
      "and data$Phylo do not match exactly (", length(mismatch), " mismatched ",
      "name(s), e.g. ", paste(utils::head(mismatch, 3), collapse = ", "),
      "). Data/tree pairing moved; re-check the archive.",
      call. = FALSE
    )
  }

  list(data = dat, tree = tree)
}

## ---------------------------------------------------------------
## Example 2 -- nominal: turdidae Primary.Lifestyle
## ---------------------------------------------------------------
mizuno_load_nominal <- function() {
  csv <- .mizuno_fetch("turd_csv")
  nex <- .mizuno_fetch("turd_nex")
  if (is.null(csv) || is.null(nex)) return(NULL)

  dat <- utils::read.csv(csv, stringsAsFactors = FALSE)
  .mizuno_schema_check(dat, c("Phylo", "Primary.Lifestyle"), "turdidae.csv")
  dat$species <- factor(dat$Phylo)
  dat$Primary.Lifestyle <- factor(dat$Primary.Lifestyle)

  tree <- .mizuno_read_tree1(nex)
  if (!isTRUE(setequal(tree$tip.label, levels(dat$species)))) {
    mismatch <- union(setdiff(tree$tip.label, levels(dat$species)),
                       setdiff(levels(dat$species), tree$tip.label))
    stop(
      "gllvmTMB Mizuno-vignette data layer: turdidae tree tip labels and ",
      "data$Phylo are not setequal (", length(mismatch), " mismatched ",
      "name(s), e.g. ", paste(utils::head(mismatch, 3), collapse = ", "),
      "). Data/tree pairing moved; re-check the archive.",
      call. = FALSE
    )
  }

  list(data = dat, tree = tree)
}
