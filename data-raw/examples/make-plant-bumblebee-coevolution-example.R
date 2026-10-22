## Regenerate inst/extdata/examples/plant-bumblebee-coevolution-example.rds.
##
## This is a synthetic teaching fixture.  Its plant and bumblebee names and
## traits are fictional; it is not a re-analysis of the Liang et al. Dryad
## network.  Re-run from the repository root:
##
##   Rscript data-raw/examples/make-plant-bumblebee-coevolution-example.R

suppressPackageStartupMessages({
  devtools::load_all(".", quiet = TRUE)
})

if (!requireNamespace("ape", quietly = TRUE)) {
  stop("Install ape to regenerate the plant--bumblebee teaching fixture.")
}

out_path <- file.path(
  "inst", "extdata", "examples", "plant-bumblebee-coevolution-example.rds"
)

tree_correlation <- function(n, prefix) {
  tree <- ape::rcoal(n)
  tree$tip.label <- sprintf("%s_%02d", prefix, seq_len(n))
  A <- ape::vcv(tree, corr = TRUE)
  A[tree$tip.label, tree$tip.label, drop = FALSE]
}

set.seed(20260905L)
n_plant <- 12L
n_bumblebee <- 8L
n_replicate <- 6L

A_plant <- tree_correlation(n_plant, "plant")
A_bumblebee <- tree_correlation(n_bumblebee, "bumblebee")

plant_axis <- seq(-1, 1, length.out = n_plant)
bumblebee_axis <- seq(-1, 1, length.out = n_bumblebee)
W <- exp(-abs(outer(plant_axis, bumblebee_axis, "-")) / 0.45)
dimnames(W) <- list(rownames(A_plant), rownames(A_bumblebee))

rho <- 0.55
K_cross <- make_cross_kernel(A_plant, A_bumblebee, W, rho = rho)

trait_names <- c(
  "flower_tube_depth", "nectar_volume", "tongue_length", "body_size"
)
plant_traits <- trait_names[1:2]
bumblebee_traits <- trait_names[3:4]

Lambda_plant <- matrix(c(0.85, 0.10, 0.35, 0.75), 2, 2, byrow = TRUE)
Lambda_bumblebee <- matrix(c(0.70, 0.25, -0.20, 0.80), 2, 2, byrow = TRUE)
Lambda <- rbind(Lambda_plant, Lambda_bumblebee)
dimnames(Lambda) <- list(trait_names, c("matching_axis", "size_axis"))

species <- rownames(K_cross)
lineage <- c(rep("plant", n_plant), rep("bumblebee", n_bumblebee))
L_K <- t(chol(K_cross + diag(1e-8, length(species))))
latent_field <- L_K %*% matrix(rnorm(length(species) * 2L), length(species), 2L)
species_effect <- latent_field %*% t(Lambda)
trait_mean <- c(
  flower_tube_depth = 0.20,
  nectar_volume = -0.15,
  tongue_length = 0.10,
  body_size = -0.05
)

rows <- vector("list", length(species) * n_replicate)
k <- 1L
for (i in seq_along(species)) {
  for (replicate in seq_len(n_replicate)) {
    y <- species_effect[i, ] + trait_mean + rnorm(length(trait_names), sd = 0.12)
    rows[[k]] <- data.frame(
      observation = sprintf("observation_%03d", k),
      species = species[[i]],
      lineage = lineage[[i]],
      flower_tube_depth = if (lineage[[i]] == "plant") y[[1]] else NA_real_,
      nectar_volume = if (lineage[[i]] == "plant") y[[2]] else NA_real_,
      tongue_length = if (lineage[[i]] == "bumblebee") y[[3]] else NA_real_,
      body_size = if (lineage[[i]] == "bumblebee") y[[4]] else NA_real_,
      stringsAsFactors = FALSE
    )
    k <- k + 1L
  }
}

data_wide <- do.call(rbind, rows)
data_wide$observation <- factor(data_wide$observation)
data_wide$species <- factor(data_wide$species, levels = species)
data_wide$lineage <- factor(data_wide$lineage, levels = c("plant", "bumblebee"))

data_long <- do.call(
  rbind,
  lapply(trait_names, function(trait) {
    data.frame(
      observation = data_wide$observation,
      species = data_wide$species,
      lineage = data_wide$lineage,
      trait = trait,
      value = data_wide[[trait]]
    )
  })
)
data_long$trait <- factor(data_long$trait, levels = trait_names)
data_long <- data_long[order(data_long$observation, data_long$trait), ]
rownames(data_long) <- NULL

alignment <- data.frame(
  symbol = c("K_cross", "G", "Gamma"),
  keyword = c(
    "make_cross_kernel()",
    "kernel_latent(species, K = K_cross, d = 2, name = \"cross\")",
    "extract_Gamma(level = \"cross\")"
  ),
  dgp = c(
    "K_cross = f(A_plant, A_bumblebee, W, rho)",
    "G ~ MVN(0, K_cross)",
    "Lambda_plant %*% t(Lambda_bumblebee)"
  ),
  extractor = c(
    "kernel eigenvalue and name checks",
    "extract_Sigma(level = \"cross\", part = \"shared\")",
    "extract_Gamma(level = \"cross\")"
  ),
  truth = c("K_cross", "Lambda %*% t(Lambda)", "Gamma_true"),
  stringsAsFactors = FALSE
)

fixture <- list(
  data_long = data_long,
  data_wide = data_wide,
  A_plant = A_plant,
  A_bumblebee = A_bumblebee,
  W = W,
  K_cross = K_cross,
  truth = list(
    seed = 20260905L,
    rho = rho,
    n_plant = n_plant,
    n_bumblebee = n_bumblebee,
    n_replicate = n_replicate,
    trait_names = trait_names,
    plant_traits = plant_traits,
    bumblebee_traits = bumblebee_traits,
    Lambda = Lambda,
    Gamma = Lambda_plant %*% t(Lambda_bumblebee)
  ),
  alignment = alignment,
  story = list(
    title = "Synthetic plant--bumblebee cross-lineage covariance",
    source = "Synthetic teaching fixture; no empirical claim.",
    question = paste(
      "How does a fixed cross-lineage kernel connect flower and bumblebee",
      "trait covariance in a point-estimate GLLVM?"
    )
  ),
  generator = "data-raw/examples/make-plant-bumblebee-coevolution-example.R"
)

dir.create(dirname(out_path), recursive = TRUE, showWarnings = FALSE)
saveRDS(fixture, out_path)
cat(sprintf("[data-raw] saved -> %s (%d bytes)\n", out_path, file.size(out_path)))
