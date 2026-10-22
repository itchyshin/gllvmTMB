args <- commandArgs(trailingOnly = TRUE)
mode <- if (length(args)) args[[1L]] else "all"
root <- file.path("dev", "isdm-requalification")

read_text <- function(name) paste(readLines(file.path(root, name), warn = FALSE),
                                  collapse = "\n")
require_text <- function(text, patterns, label) {
  missing <- patterns[!vapply(patterns, grepl, logical(1L), x = text,
                             fixed = TRUE)]
  if (length(missing)) stop(label, " missing: ", paste(missing, collapse = ", "))
}

verify_inventory <- function() {
  text <- read_text("RECONCILIATION.md")
  require_text(text,
               c("SHIPPED", "STALE", "OWED", "RETRACTED", "PROTECTED",
                 "22,200", "0.23--0.82", "Private G2"),
               "inventory")
  cat("ISDM_INVENTORY_VERIFIED\n")
}

verify_alignment <- function() {
  text <- read_text("SYMBOLIC-ALIGNMENT.md")
  require_text(text,
               c("DGP draw", "Public R formula/declaration", "Fitted target",
                 "Extractor/score", "Sigma", "Psi", "centered",
                 "Raw latent axes", "Wilson 90%"),
               "alignment")
  cat("ISDM_ALIGNMENT_VERIFIED\n")
}

verify_manifest <- function() {
  source(file.path(root, "contract.R"), local = TRUE)
  ordinary <- isdm_point_plan("ordinary")
  attack <- isdm_point_plan("attack")
  spatial <- isdm_point_plan("spatial")
  interval <- isdm_interval_plan()
  stopifnot(
    nrow(ordinary) == 1600L, nrow(attack) == 200L,
    nrow(spatial) == 800L, nrow(interval) == 4800L,
    identical(range(c(ordinary$seed, attack$seed)),
              c(202608280L, 202610079L)),
    identical(range(spatial$seed), c(202610080L, 202610879L)),
    identical(range(interval$seed), c(202610880L, 202615679L)),
    length(unique(c(ordinary$seed, attack$seed, spatial$seed,
                    interval$seed))) == 7400L,
    nrow(isdm_prerun_plan()) == 38L,
    identical(isdm_frozen_gates()$interval$wilson90_acceptance,
              c(0.92, 0.98))
  )
  cat("ISDM_MANIFEST_VERIFIED\n")
}

switch(mode,
       inventory = verify_inventory(),
       alignment = verify_alignment(),
       manifest = verify_manifest(),
       all = { verify_inventory(); verify_alignment(); verify_manifest() },
       stop("unknown verification mode: ", mode))
