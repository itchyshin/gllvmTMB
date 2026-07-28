## Arc 0 -- 00-cells.R
##
## Builds dev/arc0/cells.csv: the cell set Arc 0 fits, carrying TWO designs
## side by side.
##
##   design == "primary": the 32 rows of
##     dev/lambda-spectrum-vs-degeneracy.csv, unchanged. This is the cell set
##     named in the handover. It is CONFOUNDED with n (all 16 degenerate rows
##     are n=40; 13/16 healthy rows are n=100) -- the audit below states that
##     plainly, it does not try to fix it.
##
##   design == "matched": within-stratum balanced draws -- up to 8 degenerate
##     and 8 healthy per (n, q) stratum, equal counts within a stratum, chosen
##     by ascending seed -- from strata that can supply both groups. This is
##     the actual de-confounded control.
##
## Source of truth for "matched": /tmp/grid-ref.csv, filtered to
## arm == "gtmb_laplace", family == "bernoulli", is.finite(rel_frob); grp is
## "degenerate" if rel_frob > 10 else "healthy". p is 8 throughout.
##
## Output columns: cell_id, design, stratum, grp, n, p, q, seed, rel_frob.
## A cell may appear in both designs; cell_id is always unique (design is part
## of the id).

grid_ref_path   <- "/tmp/grid-ref.csv"
primary_path    <- "dev/lambda-spectrum-vs-degeneracy.csv"
out_csv         <- "dev/arc0/cells.csv"
out_audit       <- "dev/arc0/cells-audit.txt"
n_per_group_max <- 8L

stopifnot(file.exists(grid_ref_path), file.exists(primary_path))

## ---------------------------------------------------------------------------
## 1. Primary design: the handover's named 32-row cell set, unchanged.

primary_raw <- read.csv(primary_path, stringsAsFactors = FALSE)
stopifnot(nrow(primary_raw) == 32L)

primary <- data.frame(
  cell_id  = paste0("primary_", seq_len(nrow(primary_raw)), "_n", primary_raw$n,
                     "q", primary_raw$q, "s", primary_raw$seed),
  design   = "primary",
  stratum  = paste0("n", primary_raw$n, "q", primary_raw$q),
  grp      = primary_raw$grp,
  n        = primary_raw$n,
  p        = primary_raw$p,
  q        = primary_raw$q,
  seed     = primary_raw$seed,
  rel_frob = primary_raw$rel_frob,
  stringsAsFactors = FALSE
)

## ---------------------------------------------------------------------------
## 2. Matched design: balanced within-stratum draws from grid-ref.csv.

gr <- read.csv(grid_ref_path, stringsAsFactors = FALSE)
gr <- subset(gr, arm == "gtmb_laplace" & family == "bernoulli" & is.finite(rel_frob) & p == 8)
gr$grp <- ifelse(gr$rel_frob > 10, "degenerate", "healthy")

candidate_strata <- c("n40q2", "n100q2", "n100q4", "n200q4")
gr$stratum <- paste0("n", gr$n, "q", gr$q)

matched_list <- list()
skipped <- character(0)

for (st in candidate_strata) {
  sub <- gr[gr$stratum == st, ]
  n_deg <- sum(sub$grp == "degenerate")
  n_hea <- sum(sub$grp == "healthy")
  if (n_deg == 0L || n_hea == 0L) {
    skipped <- c(skipped, st)
    next
  }
  k <- min(n_per_group_max, n_deg, n_hea)
  deg_rows <- sub[sub$grp == "degenerate", ]
  hea_rows <- sub[sub$grp == "healthy", ]
  deg_rows <- deg_rows[order(deg_rows$seed), ][seq_len(k), ]
  hea_rows <- hea_rows[order(hea_rows$seed), ][seq_len(k), ]
  matched_list[[st]] <- rbind(deg_rows, hea_rows)
}

if (length(skipped) > 0L) {
  message("Skipping strata with no both-group support: ", paste(skipped, collapse = ", "))
}

matched_raw <- do.call(rbind, matched_list)
row.names(matched_raw) <- NULL

matched <- data.frame(
  cell_id  = paste0("matched_", matched_raw$stratum, "_", matched_raw$grp, "_s",
                     matched_raw$seed),
  design   = "matched",
  stratum  = matched_raw$stratum,
  grp      = matched_raw$grp,
  n        = matched_raw$n,
  p        = matched_raw$p,
  q        = matched_raw$q,
  seed     = matched_raw$seed,
  rel_frob = matched_raw$rel_frob,
  stringsAsFactors = FALSE
)

## ---------------------------------------------------------------------------
## 3. Combine and write.

cells <- rbind(primary, matched)
stopifnot(!anyDuplicated(cells$cell_id))

dir.create(dirname(out_csv), showWarnings = FALSE, recursive = TRUE)
write.csv(cells, out_csv, row.names = FALSE)

## ---------------------------------------------------------------------------
## 4. Control audit: cross-tabs, per-group rel_frob range, confound verdicts.

audit_lines <- character(0)
add <- function(...) audit_lines <<- c(audit_lines, paste0(...))

for (des in c("primary", "matched")) {
  sub <- cells[cells$design == des, ]
  add("==== design: ", des, " (", nrow(sub), " cells) ====")

  add("-- grp x n --")
  tab_n <- table(sub$grp, sub$n)
  add(paste(capture.output(print(tab_n)), collapse = "\n"))

  add("-- grp x q --")
  tab_q <- table(sub$grp, sub$q)
  add(paste(capture.output(print(tab_q)), collapse = "\n"))

  add("-- rel_frob median/range per grp --")
  for (g in sort(unique(sub$grp))) {
    rf <- sub$rel_frob[sub$grp == g]
    add(sprintf("  %s: median=%.4g, range=[%.4g, %.4g], n=%d",
                g, stats::median(rf), min(rf), max(rf), length(rf)))
  }

  ## Confound check: is grp perfectly (or near-perfectly) aliased with n or q?
  ## Use: does every n value appear in only one grp, or vice versa?
  n_by_grp <- tapply(sub$n, sub$grp, function(x) sort(unique(x)))
  q_by_grp <- tapply(sub$q, sub$grp, function(x) sort(unique(x)))
  n_overlap <- length(intersect(n_by_grp[["degenerate"]], n_by_grp[["healthy"]])) > 0
  q_overlap <- length(intersect(q_by_grp[["degenerate"]], q_by_grp[["healthy"]])) > 0

  ## Also report the max proportion of one grp concentrated in a single n (or q)
  ## level, as a softer confound signal than pure overlap.
  prop_max_n <- max(prop.table(tab_n, margin = 1))
  prop_max_q <- max(prop.table(tab_q, margin = 1))

  if (des == "primary") {
    verdict <- sprintf(
      "VERDICT: design '%s' IS confounded with n (grp-by-n overlap=%s, max within-grp n-concentration=%.2f) -- as expected, this is the point of the audit.",
      des, n_overlap, prop_max_n)
  } else {
    conf_n <- !n_overlap || prop_max_n > 0.9
    conf_q <- !q_overlap || prop_max_q > 0.9
    verdict <- sprintf(
      "VERDICT: design '%s' is %s with n (overlap=%s, max concentration=%.2f) and %s with q (overlap=%s, max concentration=%.2f).",
      des,
      if (conf_n) "CONFOUNDED" else "NOT confounded",
      n_overlap, prop_max_n,
      if (conf_q) "CONFOUNDED" else "NOT confounded",
      q_overlap, prop_max_q)
  }
  add(verdict)
  add("")
}

if (length(skipped) > 0L) {
  add(sprintf("Strata skipped (no both-group support): %s", paste(skipped, collapse = ", ")))
}

add("-- per-stratum counts (matched design) --")
matched_sub <- cells[cells$design == "matched", ]
strat_tab <- table(matched_sub$stratum, matched_sub$grp)
add(paste(capture.output(print(strat_tab)), collapse = "\n"))

audit_text <- paste(audit_lines, collapse = "\n")
cat(audit_text, "\n")
writeLines(audit_lines, out_audit)

cat("\nWrote:", out_csv, "(", nrow(cells), "rows )\n")
cat("Wrote:", out_audit, "\n")
