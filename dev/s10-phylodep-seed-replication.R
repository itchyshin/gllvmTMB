## Replication of the S0 single-realization finding that, in the JSDM
## (Site x Species) layout, `phylo_dep(0 + trait | species, tree = tree_X)`
## scored the TRUE tree WORSE than two wrong trees:
##   tree_A (TRUE)  logLik = 46.834572
##   tree_B (wrong) logLik = 49.776670  <- best
##   tree_C (wrong) logLik = 49.360143
## (see dev/s0-rederive-two-tree.R / -RESULTS.md, experiment E1c).
##
## This script is self-contained and re-runnable:
##   Rscript --vanilla dev/s10-phylodep-seed-replication.R
## Set the number of replicates with the S10_NREPS env var (default 20):
##   S10_NREPS=2 Rscript --vanilla dev/s10-phylodep-seed-replication.R   # smoke test
##
## Package load route: devtools::load_all() from this worktree (NOT an
## installed build). Every warning/message from every fit is captured
## (withCallingHandlers, not suppressed) and reported in aggregate (raw
## count preserved; only IDENTICAL repeated text is deduplicated in the
## printed table for readability -- nothing is filtered by content).

suppressPackageStartupMessages({
  library(devtools)
})

args <- commandArgs(trailingOnly = FALSE)
file_arg <- grep("^--file=", args, value = TRUE)
script_path <- if (length(file_arg) == 1L) sub("^--file=", "", file_arg) else NULL
pkg_root <- if (!is.null(script_path)) {
  normalizePath(file.path(dirname(script_path), ".."))
} else {
  normalizePath(".")
}
cat("Loading package from worktree root:", pkg_root, "\n")
devtools::load_all(pkg_root, quiet = TRUE)

suppressPackageStartupMessages({
  library(ape)
  library(mvtnorm)
})

n_reps <- as.integer(Sys.getenv("S10_NREPS", "20"))
cat("n_reps =", n_reps, "\n")

t_start_all <- Sys.time()

## ---------------------------------------------------------------------
## Capture helper (verbatim, unfiltered warnings/messages/errors).
## ---------------------------------------------------------------------
run_capturing <- function(expr) {
  warnings_seen <- character(0)
  messages_seen <- character(0)
  error_seen <- NULL
  value <- withCallingHandlers(
    tryCatch(expr, error = function(e) { error_seen <<- conditionMessage(e); NULL }),
    warning = function(w) { warnings_seen <<- c(warnings_seen, conditionMessage(w)); invokeRestart("muffleWarning") },
    message = function(m) { messages_seen <<- c(messages_seen, conditionMessage(m)); invokeRestart("muffleMessage") }
  )
  list(value = value, warnings = warnings_seen, messages = messages_seen, error = error_seen)
}
ll_of <- function(fit) if (is.null(fit)) NA_real_ else as.numeric(logLik(fit))
conv_ok <- function(fit) if (is.null(fit)) NA else isTRUE(fit$opt$convergence == 0L)

## =======================================================================
## Fixed trees -- IDENTICAL construction to dev/s0-rederive-two-tree.R:
## same seeds (101/202/303), same tip labels. tree_A is the TRUE tree used
## to generate data in every replicate below; tree_B/tree_C are the fixed
## WRONG alternatives. The tree topology itself does NOT vary by replicate
## -- only the data draws do.
## =======================================================================
n_species <- 10L
sp_labels <- paste0("sp", seq_len(n_species))
make_tree <- function(seed) {
  set.seed(seed)
  tr <- ape::rcoal(n_species)
  tr$tip.label <- sp_labels
  tr
}
tree_A <- make_tree(101)  # TRUE
tree_B <- make_tree(202)  # wrong
tree_C <- make_tree(303)  # wrong
trees <- list(tree_A = tree_A, tree_B = tree_B, tree_C = tree_C)
true_tree_name <- "tree_A"

A_true <- ape::vcv(tree_A, corr = TRUE)[sp_labels, sp_labels]

## =======================================================================
## Main + control arm: JSDM layout (E1-style). unit = site (30 levels),
## trait column = species identity, separate species/cluster column.
## Fixed formula ~1 + phylo_dep(...) / ~1 + phylo_indep(...).
## =======================================================================
n_site_main <- 30L
long_template <- expand.grid(
  site = factor(paste0("site", seq_len(n_site_main))),
  species = factor(sp_labels)
)
long_template$trait <- long_template$species

gen_main_data <- function(seed_z, seed_noise) {
  set.seed(seed_z)
  z_sp <- as.numeric(mvtnorm::rmvnorm(1, sigma = 4 * A_true))
  names(z_sp) <- sp_labels
  set.seed(seed_noise)
  noise <- stats::rnorm(nrow(long_template), 0, 0.2)
  d <- long_template
  d$value <- z_sp[as.character(d$species)] + noise
  d
}

fit_main <- function(data, tree, keyword = c("dep", "indep")) {
  keyword <- match.arg(keyword)
  form <- if (keyword == "dep") {
    value ~ 1 + phylo_dep(0 + trait | species, tree = tree)
  } else {
    value ~ 1 + phylo_indep(0 + trait | species, tree = tree)
  }
  run_capturing(
    gllvmTMB(form, data = data, unit = "site", cluster = "species",
             family = gaussian(), control = gllvmTMBcontrol(se = FALSE))
  )
}

## =======================================================================
## Positive control: transposed layout (E3-style). unit = species (10
## levels), trait = 6 pseudo-traits, phylo_latent(species, d = 1, tree=).
## =======================================================================
n_trait_pc <- 6L
lambda_t <- c(1.0, -0.8, 0.6, 0.9, -0.5, 0.7)[seq_len(n_trait_pc)]
grid_pc_template <- expand.grid(
  species = sp_labels, trait = paste0("t", seq_len(n_trait_pc)),
  stringsAsFactors = FALSE
)
grid_pc_template$species <- factor(grid_pc_template$species, levels = sp_labels)
grid_pc_template$trait <- factor(grid_pc_template$trait, levels = paste0("t", seq_len(n_trait_pc)))

gen_pc_data <- function(seed_z, seed_noise) {
  set.seed(seed_z)
  z_sp <- as.numeric(mvtnorm::rmvnorm(1, sigma = A_true))
  names(z_sp) <- sp_labels
  set.seed(seed_noise)
  noise <- stats::rnorm(nrow(grid_pc_template), 0, 0.3)
  d <- grid_pc_template
  eta <- lambda_t[as.integer(d$trait)] * z_sp[as.character(d$species)]
  d$value <- eta + noise
  d
}

fit_pc <- function(data, tree) {
  run_capturing(
    gllvmTMB(value ~ 0 + trait + phylo_latent(species, d = 1, tree = tree),
             data = data, unit = "species", cluster = "species",
             family = gaussian(), control = gllvmTMBcontrol(se = FALSE))
  )
}

## =======================================================================
## Replicate loop. Seeds are fixed and deterministic per replicate index
## so the whole campaign is re-runnable from a clean checkout.
## =======================================================================
main_rows <- list()
pc_rows <- list()
all_warn_msgs <- character(0)
all_errors <- character(0)

for (i in seq_len(n_reps)) {
  seed_z_main    <- 5000L + i
  seed_noise_main <- 6000L + i
  seed_z_pc      <- 7000L + i
  seed_noise_pc  <- 8000L + i

  d_main <- gen_main_data(seed_z_main, seed_noise_main)
  d_pc   <- gen_pc_data(seed_z_pc, seed_noise_pc)

  for (tn in names(trees)) {
    tr <- trees[[tn]]

    fit_dep <- fit_main(d_main, tr, "dep")
    fit_ind <- fit_main(d_main, tr, "indep")
    fit_pos <- fit_pc(d_pc, tr)

    for (tag_fit in list(list("dep", fit_dep), list("indep", fit_ind), list("pc", fit_pos))) {
      lbl <- sprintf("[rep %d %s %s]", i, tag_fit[[1]], tn)
      fr <- tag_fit[[2]]
      if (length(fr$warnings) > 0) all_warn_msgs <- c(all_warn_msgs, paste0(lbl, " WARNING: ", fr$warnings))
      if (length(fr$messages) > 0) all_warn_msgs <- c(all_warn_msgs, paste0(lbl, " MESSAGE: ", fr$messages))
      if (!is.null(fr$error)) all_errors <- c(all_errors, paste0(lbl, " ERROR: ", fr$error))
    }

    main_rows[[length(main_rows) + 1]] <- data.frame(
      rep = i, tree = tn, is_true_tree = (tn == true_tree_name),
      keyword = "dep", logLik = ll_of(fit_dep$value), conv0 = conv_ok(fit_dep$value),
      error = !is.null(fit_dep$error)
    )
    main_rows[[length(main_rows) + 1]] <- data.frame(
      rep = i, tree = tn, is_true_tree = (tn == true_tree_name),
      keyword = "indep", logLik = ll_of(fit_ind$value), conv0 = conv_ok(fit_ind$value),
      error = !is.null(fit_ind$error)
    )
    pc_rows[[length(pc_rows) + 1]] <- data.frame(
      rep = i, tree = tn, is_true_tree = (tn == true_tree_name),
      logLik = ll_of(fit_pos$value), conv0 = conv_ok(fit_pos$value),
      error = !is.null(fit_pos$error)
    )
  }
  cat(sprintf("replicate %d/%d done (%.1f s elapsed)\n", i, n_reps,
              as.numeric(difftime(Sys.time(), t_start_all, units = "secs"))))
}

main_df <- do.call(rbind, main_rows)
pc_df <- do.call(rbind, pc_rows)

t_end_all <- Sys.time()
total_runtime_sec <- as.numeric(difftime(t_end_all, t_start_all, units = "secs"))
cat(sprintf("\nTotal runtime: %.1f sec (%.2f min) for n_reps = %d\n",
            total_runtime_sec, total_runtime_sec / 60, n_reps))

## =======================================================================
## Analysis
## =======================================================================
usable_replicate <- function(sub) {
  ## sub = rows for one replicate, one keyword, all 3 trees
  all(!is.na(sub$logLik)) && all(sub$conv0 %in% TRUE) && !any(sub$error)
}

analyze_arm <- function(df, keyword_filter = NULL, label = "") {
  if (!is.null(keyword_filter)) df <- df[df$keyword == keyword_filter, , drop = FALSE]
  reps <- sort(unique(df$rep))
  n_total <- length(reps)
  discarded <- integer(0)
  true_wins <- integer(0)
  deltas <- numeric(0)   # logLik_true - logLik_best_wrong, only for usable reps
  tie_flags <- logical(0)  # for control arm: are all 3 logLiks numerically tied?
  per_rep_rows <- list()
  for (r in reps) {
    sub <- df[df$rep == r, , drop = FALSE]
    ok <- usable_replicate(sub)
    if (!ok) {
      discarded <- c(discarded, r)
      per_rep_rows[[length(per_rep_rows) + 1]] <- data.frame(
        rep = r, usable = FALSE, best_tree = NA_character_,
        true_is_best = NA, delta = NA_real_, max_abs_diff = NA_real_
      )
      next
    }
    best_idx <- which.max(sub$logLik)
    best_tree <- sub$tree[best_idx]
    true_ll <- sub$logLik[sub$is_true_tree]
    wrong_ll <- sub$logLik[!sub$is_true_tree]
    delta <- true_ll - max(wrong_ll)
    is_best <- sub$is_true_tree[best_idx]
    true_wins <- c(true_wins, as.integer(is_best))
    deltas <- c(deltas, delta)
    max_abs_diff <- max(sub$logLik) - min(sub$logLik)
    tie_flags <- c(tie_flags, max_abs_diff < 1e-4)
    per_rep_rows[[length(per_rep_rows) + 1]] <- data.frame(
      rep = r, usable = TRUE, best_tree = as.character(best_tree),
      true_is_best = is_best, delta = delta, max_abs_diff = max_abs_diff
    )
  }
  per_rep_df <- do.call(rbind, per_rep_rows)
  list(
    label = label,
    n_total = n_total,
    n_discarded = length(discarded),
    discarded_reps = discarded,
    n_usable = length(true_wins),
    n_true_wins = sum(true_wins),
    prop_true_wins = if (length(true_wins) > 0) sum(true_wins) / length(true_wins) else NA_real_,
    mean_delta = if (length(deltas) > 0) mean(deltas) else NA_real_,
    sd_delta = if (length(deltas) > 0) sd(deltas) else NA_real_,
    all_tied = if (length(tie_flags) > 0) all(tie_flags) else NA,
    n_tied = if (length(tie_flags) > 0) sum(tie_flags) else NA_integer_,
    per_rep = per_rep_df
  )
}

res_dep <- analyze_arm(main_df, "dep", "phylo_dep (main)")
res_indep <- analyze_arm(main_df, "indep", "phylo_indep (control)")
res_pc <- analyze_arm(pc_df, NULL, "phylo_latent transposed (positive control)")

## Verdict logic --------------------------------------------------------
control_ok <- isTRUE(res_indep$all_tied) && res_indep$n_discarded == 0
pc_ok <- !is.na(res_pc$prop_true_wins) && res_pc$prop_true_wins >= 0.8  # "high rate"

verdict <- if (!control_ok) {
  "INCONCLUSIVE -- CONTROL ARM FAILED: phylo_indep() did not tie across trees (or a control fit failed to converge), so the harness itself is suspect; the phylo_dep numbers below cannot be trusted without further investigation."
} else if (!pc_ok) {
  "INCONCLUSIVE -- POSITIVE CONTROL FAILED: the transposed layout did not show the true tree winning at a high rate, so this harness cannot be shown to detect a real phylogenetic effect at all; the phylo_dep numbers below are not interpretable."
} else if (!is.na(res_dep$prop_true_wins) && res_dep$prop_true_wins <= 0.45) {
  "SYSTEMATIC -- the true tree does not win more often than chance (~1/3 with 3 trees); the S0 single-draw result replicates as a repeatable pattern, not noise."
} else if (!is.na(res_dep$prop_true_wins) && res_dep$prop_true_wins >= 0.6) {
  "NOT REPLICATED -- the true tree wins clearly more often than chance; the S0 draw was noise, not a systematic effect."
} else {
  "INCONCLUSIVE -- true-tree win rate for phylo_dep is close to chance-level (~1/3) but not clearly at or above it; more replicates would be needed to distinguish systematic under-performance from noise."
}

## =======================================================================
## Write markdown report.
## =======================================================================
say_table_per_rep <- function(per_rep, keyword_label) {
  lines <- c(
    paste0("#### Per-replicate detail -- ", keyword_label),
    "",
    "| rep | usable | best tree | true is best | delta (true - best wrong) | max abs logLik diff |",
    "|---|---|---|---|---|---|"
  )
  for (k in seq_len(nrow(per_rep))) {
    r <- per_rep[k, ]
    lines <- c(lines, sprintf(
      "| %d | %s | %s | %s | %s | %s |",
      r$rep, r$usable,
      ifelse(is.na(r$best_tree), "NA", r$best_tree),
      ifelse(is.na(r$true_is_best), "NA", r$true_is_best),
      ifelse(is.na(r$delta), "NA", sprintf("%.6f", r$delta)),
      ifelse(is.na(r$max_abs_diff), "NA", sprintf("%.6f", r$max_abs_diff))
    ))
  }
  lines
}

warn_summary <- function(msgs) {
  if (length(msgs) == 0) return("(no warnings or messages captured from any fit)")
  tab <- sort(table(msgs), decreasing = TRUE)
  out <- character(0)
  for (nm in names(tab)) {
    out <- c(out, sprintf("[x%d] %s", tab[[nm]], nm))
  }
  out
}

md <- c(
  "# S10: phylo_dep() tree-discrimination replication",
  "",
  paste0("Generated: ", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")),
  "",
  paste0("Package loaded via `devtools::load_all()` from this worktree (`", pkg_root,
         "`), NOT an installed build. Script: `dev/s10-phylodep-seed-replication.R`. ",
         "Seeds are fixed and deterministic per replicate; re-running this script from ",
         "a clean checkout with the same `S10_NREPS` reproduces every number below."),
  "",
  "## Question replicated",
  "",
  "A single S0 realization (`dev/s0-rederive-two-tree.R`, experiment E1c) found",
  "`phylo_dep(0 + trait | species, tree = tree_X)` scored the TRUE tree (tree_A)",
  "WORSE (logLik 46.834572) than two WRONG trees (tree_B: 49.776670, tree_C:",
  "49.360143), in the JSDM Site x Species layout. This script replicates that",
  "single draw across independent data realizations under the SAME fixed tree_A",
  "(true) / tree_B / tree_C (wrong) trio, to determine whether the true tree",
  "loses SYSTEMATICALLY or that was noise.",
  "",
  "## Design",
  "",
  paste0("- `n_reps` = ", n_reps, ", each with its own fixed seed (main-arm z: ",
         "5000+i, main-arm noise: 6000+i, positive-control z: 7000+i, ",
         "positive-control noise: 8000+i)."),
  "- Trees are FIXED across replicates (identical construction to S0: `ape::rcoal(10)`",
  "  under seeds 101/202/303 for tree_A (TRUE) / tree_B (wrong) / tree_C (wrong)).",
  "  Only the data draws vary by replicate.",
  "- **Main + control arm** (JSDM layout, E1-style): `unit = site` (30 levels),",
  "  `trait` = species identity (10 levels), intercept-only fixed formula so the",
  "  phylo variance is well-identified (matches S0's deconfounded E1b/E1c design,",
  "  not the collinear E1a naive formula). Per replicate: one shared draw",
  "  `z_sp ~ MVN(0, 4*A_true(tree_A))` broadcast across sites, plus",
  "  `N(0, 0.2^2)` row noise. The SAME generated dataset is fit under",
  "  `phylo_dep(0 + trait | species, tree = tree_X)` (main) and",
  "  `phylo_indep(0 + trait | species, tree = tree_X)` (control), for each of",
  "  the 3 trees.",
  "- **Positive control** (transposed layout, E3-style): `unit = species` (10",
  "  levels), 6 pseudo-traits, fixed loadings `c(1.0, -0.8, 0.6, 0.9, -0.5, 0.7)`,",
  "  `z_sp ~ MVN(0, A_true(tree_A))`, `N(0, 0.3^2)` noise, fit with",
  "  `phylo_latent(species, d = 1, tree = tree_X)` for each of the 3 trees.",
  "- Species count fixed at 10 throughout (matching S0's scale); the optional",
  "  species-count sweep (6/10/20) in the task brief item 6 was SKIPPED to stay",
  "  inside the local runtime budget -- see Runtime below.",
  "",
  "## Runtime",
  "",
  sprintf("Total wall time for %d replicates x 3 trees x 3 fit-types (dep + indep + positive-control latent) = %d fits: **%.1f sec (%.2f min)**.",
          n_reps, n_reps * 9L, total_runtime_sec, total_runtime_sec / 60),
  "",
  "## Control arm (phylo_indep) -- checked FIRST per task instructions",
  "",
  paste0("S0 proved `phylo_indep()` is a structural no-op in this exact JSDM layout ",
         "(tree never enters the likelihood). If that does not replicate as an exact ",
         "tie here, the harness is suspect and the phylo_dep numbers below are not ",
         "trustworthy."),
  "",
  sprintf("- Replicates: %d total, %d discarded for non-convergence/error, %d usable.",
          res_indep$n_total, res_indep$n_discarded, res_indep$n_usable),
  sprintf("- All usable replicates numerically tied across trees (max abs logLik diff < 1e-4): **%s** (%d / %d tied).",
          res_indep$all_tied, res_indep$n_tied, res_indep$n_usable),
  "",
  paste0("**Control arm verdict: ", if (control_ok) "PASSED (tree is a confirmed no-op for phylo_indep on every usable replicate)." else "FAILED -- see verdict below.", "**"),
  "",
  say_table_per_rep(res_indep$per_rep, "phylo_indep (control)"),
  "",
  "## Positive control (transposed layout, phylo_latent)",
  "",
  paste0("S0 showed the true tree wins decisively in this layout (true -8.730365 vs ",
         "wrong -28.430023). If the true tree does NOT win at a high rate here, the ",
         "harness cannot be shown to detect a real phylogenetic effect and nothing ",
         "else in this report is interpretable."),
  "",
  sprintf("- Replicates: %d total, %d discarded for non-convergence/error, %d usable.",
          res_pc$n_total, res_pc$n_discarded, res_pc$n_usable),
  sprintf("- TRUE tree best logLik in %d / %d usable replicates (proportion = %.3f).",
          res_pc$n_true_wins, res_pc$n_usable, res_pc$prop_true_wins),
  sprintf("- Mean (logLik_true - logLik_best_wrong) = %.6f, SD = %.6f.",
          res_pc$mean_delta, res_pc$sd_delta),
  "",
  paste0("**Positive control verdict: ", if (pc_ok) "PASSED (true tree wins at a high rate)." else "FAILED -- see overall verdict below.", "**"),
  "",
  say_table_per_rep(res_pc$per_rep, "positive control (phylo_latent, transposed)"),
  "",
  "## Main result: phylo_dep(), JSDM layout",
  "",
  sprintf("- Replicates: %d total, %d discarded for non-convergence/error (discard rate = %.1f%%), %d usable.",
          res_dep$n_total, res_dep$n_discarded, 100 * res_dep$n_discarded / max(res_dep$n_total, 1), res_dep$n_usable),
  sprintf("- **TRUE tree (tree_A) achieved the best logLik in %d / %d usable replicates (proportion = %.3f).** Chance level with 3 trees is ~0.333.",
          res_dep$n_true_wins, res_dep$n_usable, res_dep$prop_true_wins),
  sprintf("- Signed (logLik_true - logLik_best_wrong): mean = %.6f, SD = %.6f (negative mean means the true tree systematically scores WORSE than the best wrong tree).",
          res_dep$mean_delta, res_dep$sd_delta),
  ifelse(length(res_dep$discarded_reps) > 0,
         paste0("- Discarded replicate indices: ", paste(res_dep$discarded_reps, collapse = ", "), "."),
         "- No replicates discarded."),
  "",
  say_table_per_rep(res_dep$per_rep, "phylo_dep (main)"),
  "",
  "## Warnings and messages -- verbatim, unfiltered",
  "",
  paste0("Every warning/message from every one of the ", n_reps * 9L,
         " fits was captured via `withCallingHandlers` (never suppressed at the ",
         "point it fired). Identical repeated text is deduplicated below for ",
         "readability with an explicit repeat count `[xN]` -- nothing is filtered ",
         "by content or grepped away."),
  "",
  "```",
  warn_summary(all_warn_msgs),
  "```",
  "",
  "## Errors",
  "",
  "```",
  if (length(all_errors) > 0) all_errors else "(no errors -- every fit call returned a value)",
  "```",
  "",
  "## VERDICT",
  "",
  paste0("**", verdict, "**"),
  "",
  sprintf("Numbers: phylo_dep true-tree-wins proportion = %.3f (%d/%d usable reps); control arm all-tied = %s; positive-control true-tree-wins proportion = %.3f (%d/%d usable reps); mean signed delta (true - best wrong) for phylo_dep = %.6f (SD %.6f).",
          res_dep$prop_true_wins, res_dep$n_true_wins, res_dep$n_usable,
          res_indep$all_tied,
          res_pc$prop_true_wins, res_pc$n_true_wins, res_pc$n_usable,
          res_dep$mean_delta, res_dep$sd_delta)
)

out_path <- file.path(pkg_root, "dev", "s10-phylodep-seed-replication-RESULTS.md")
writeLines(md, out_path)
cat("\nWrote results to:", out_path, "\n")
