# Reviewed task map for the public gllvmTMB function guide.
#
# This is deliberately not an inventory of every export: compatibility aliases,
# developer helpers, and constructors that deliberately fail for unsupported
# response routes do not belong on the primary reader path.

function_map_inventory <- list(
  list(
    id = "prepare", label = "Step 1: Prepare and specify", colour = "#3D7A57",
    purpose = "Put responses into long or wide data and state the covariance question.",
    functions = c("traits", "gllvmTMBcontrol", "latent", "indep", "dep"),
    route = "Start with ordinary covariance; add a relationship source only when the study design supplies one."
  ),
  list(
    id = "fit", label = "Step 2: Fit", colour = "#2D6FA3",
    purpose = "Fit every stacked-trait model through one entry point.",
    functions = c("gllvmTMB"),
    route = "Use a supported response family and retain the formula that defines the estimand."
  ),
  list(
    id = "check", label = "Step 3: Check fit health", colour = "#9367A6",
    purpose = "Check convergence, gradients, Hessian information, and fitted-response mismatch before interpretation.",
    functions = c("check_gllvmTMB", "gllvmTMB_diagnose", "predictive_check"),
    route = "A syntactically valid model can still be weakly identified for its data."
  ),
  list(
    id = "interpret", label = "Step 4: Interpret covariance", colour = "#B06C31",
    purpose = "Extract rotation-invariant covariance, correlation, and shared-variance summaries first.",
    functions = c("extract_Sigma", "extract_correlations", "extract_communality", "extract_ordination"),
    route = "Loadings and ordination scores are orientation-dependent; interpret them after covariance summaries."
  ),
  list(
    id = "uncertainty", label = "Step 5: Choose a target-specific uncertainty route", colour = "#A64E5F",
    purpose = "Inspect available methods and their returned status rather than assuming a generic confidence interval.",
    functions = c("profile_targets", "confint_inspect", "bootstrap_Sigma", "loading_ci"),
    route = "Interval availability and calibration depend on the estimand, family, and covariance tier."
  ),
  list(
    id = "report", label = "Step 6: Report, predict, or simulate", colour = "#167C7C",
    purpose = "Make report-ready tables and figures, predict fitted responses, or simulate new responses.",
    functions = c("extract_Sigma_table", "plot_Sigma_heatmap", "plot_correlations", "predict", "simulate"),
    route = "Name the target and scale in every reported table or figure."
  )
)

function_map_primary_exports <- unique(unlist(lapply(
  function_map_inventory, `[[`, "functions"
)))

function_map_compatibility <- c(
  "gllvmTMB_wide", "unique", "animal_unique", "phylo_unique",
  "spatial_unique", "kernel_unique", "meta_known_V", "gr", "meta",
  "phylo_rr", "spde", "extract_Sigma_B", "extract_Sigma_W",
  "extract_ICC_site", "extract_residual_split", "VP", "getLV",
  "getLoadings", "getResidualCor", "getResidualCov", "ordiplot"
)

# Every exported name is deliberately classified before the print generator
# runs. `reference_only` means public, but not a primary first-use route on
# this page; readers can find it through the reference index or specialist
# articles.  This keeps a task map from accidentally becoming a claims list.
function_map_classify_exports <- function(exports) {
  status <- rep("reference_only", length(exports))
  names(status) <- exports
  status[intersect(exports, function_map_primary_exports)] <- "featured"
  status[intersect(exports, function_map_compatibility)] <- "compatibility"
  status
}

function_map_escape_html <- function(x) {
  x <- gsub("&", "&amp;", x, fixed = TRUE)
  x <- gsub("<", "&lt;", x, fixed = TRUE)
  gsub(">", "&gt;", x, fixed = TRUE)
}

# The HTML cards are generated from the same inventory as the printable PDFs.
function_map_html <- function() {
  card_class <- c(
    prepare = "map-prepare", fit = "map-fit", check = "map-check",
    interpret = "map-interpret", uncertainty = "map-uncertainty",
    report = "map-report"
  )
  anchors <- c(
    prepare = "#prepare-and-specify", fit = "#fit-the-model",
    check = "#check-before-you-interpret", interpret = "#interpret-the-fitted-quantity",
    uncertainty = "#choose-uncertainty-by-target", report = "#report-predict-or-simulate"
  )
  links <- c(
    prepare = "Prepare a model", fit = "Fit with gllvmTMB()",
    check = "Check the fit", interpret = "Extract a scientific quantity",
    uncertainty = "Inspect interval support", report = "Report or predict"
  )
  cards <- vapply(function_map_inventory, function(item) {
    id <- item$id
    sprintf(
      '<section class="gllvm-map__card %s"><h3>%s</h3><p>%s</p><a href="%s">%s</a><small>%s</small></section>',
      card_class[[id]], function_map_escape_html(item$label),
      function_map_escape_html(item$purpose), anchors[[id]], links[[id]],
      function_map_escape_html(item$route)
    )
  }, character(1))
  paste(cards, collapse = "\n")
}
