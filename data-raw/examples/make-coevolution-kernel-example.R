## data-raw/examples/make-coevolution-kernel-example.R
## ====================================================
## Regenerate inst/extdata/examples/coevolution-kernel-example.rds.
##
## The RDS stores a portable teaching fixture for the cross-lineage
## coevolution kernel article: block-missing long and wide data, host and
## partner relatedness matrices, an association matrix W, K_star, a
## block-diagonal null kernel, truth, formulas, and the alignment table.
## It deliberately does not store fitted TMB objects.
##
## Re-run from the repo root:
##   Rscript data-raw/examples/make-coevolution-kernel-example.R

suppressPackageStartupMessages({
  devtools::load_all(".", quiet = TRUE)
})

if (!requireNamespace("ape", quietly = TRUE)) {
  stop("Install ape to regenerate the coevolution kernel example.")
}

OUT_PATH <- file.path(
  "inst", "extdata", "examples", "coevolution-kernel-example.rds"
)

tree_corr <- function(n, prefix) {
  tree <- ape::rcoal(n)
  tree$tip.label <- paste0(prefix, seq_len(n))
  A <- ape::vcv(tree, corr = TRUE)
  A <- A[tree$tip.label, tree$tip.label, drop = FALSE]
  storage.mode(A) <- "double"
  A
}

make_W <- function(n_H, n_P, A_H, A_P) {
  h_axis <- seq(-1, 1, length.out = n_H)
  p_axis <- seq(-1, 1, length.out = n_P)
  W <- exp(-abs(outer(h_axis, p_axis, "-")) / 0.35)
  dimnames(W) <- list(rownames(A_H), rownames(A_P))
  W
}

block_diag_kernel <- function(A_H, A_P) {
  n_H <- nrow(A_H)
  n_P <- nrow(A_P)
  K <- matrix(0, n_H + n_P, n_H + n_P)
  K[seq_len(n_H), seq_len(n_H)] <- A_H
  K[n_H + seq_len(n_P), n_H + seq_len(n_P)] <- A_P
  nm <- c(rownames(A_H), rownames(A_P))
  dimnames(K) <- list(nm, nm)
  K
}

seed <- 2L
set.seed(seed)

n_H <- 36L
n_P <- 72L
n_rep <- 5L
rho <- 0.65
resid_sd <- 0.10

A_H <- tree_corr(n_H, "H")
A_P <- tree_corr(n_P, "P")
W <- make_W(n_H, n_P, A_H, A_P)
K_star <- make_cross_kernel(A_H, A_P, W, rho = rho)
K_null <- block_diag_kernel(A_H, A_P)

trait_names <- c("h_size", "h_defence", "p_size", "p_attack")
host_traits <- trait_names[1:2]
partner_traits <- trait_names[3:4]

Lambda_H <- matrix(c(
  1.00, 0.00,
  0.45, 0.85
), 2, 2, byrow = TRUE)
Lambda_P <- matrix(c(
  0.75, 0.25,
  -0.25, 0.90
), 2, 2, byrow = TRUE)
Lambda <- rbind(Lambda_H, Lambda_P)
rownames(Lambda) <- trait_names
colnames(Lambda) <- c("axis_1", "axis_2")

Gamma_true <- Lambda_H %*% t(Lambda_P)
dimnames(Gamma_true) <- list(host_traits, partner_traits)

n_total <- n_H + n_P
L_K <- t(chol(K_star + diag(1e-8, n_total)))
G <- L_K %*% matrix(rnorm(n_total * 2L), n_total, 2L)
shared <- G %*% t(Lambda)

psi <- c(h_size = 0.02, h_defence = 0.025,
         p_size = 0.02, p_attack = 0.025)
U <- L_K %*% matrix(rnorm(n_total * length(trait_names)),
                    n_total, length(trait_names))
unique <- sweep(U, 2L, sqrt(psi), `*`)
eta <- sweep(shared + unique, 2L,
             c(h_size = 0.2, h_defence = -0.15,
               p_size = 0.1, p_attack = -0.05), `+`)
colnames(eta) <- trait_names

species <- rownames(K_star)
lineage <- c(rep("host", n_H), rep("partner", n_P))
wide_rows <- vector("list", n_total * n_rep)
k <- 1L
for (i in seq_len(n_total)) {
  for (r in seq_len(n_rep)) {
    y <- eta[i, ] + rnorm(length(trait_names), 0, resid_sd)
    wide_rows[[k]] <- data.frame(
      row_id = paste0("obs", k),
      species = species[i],
      lineage = lineage[i],
      h_size = if (lineage[i] == "host") y[1L] else NA_real_,
      h_defence = if (lineage[i] == "host") y[2L] else NA_real_,
      p_size = if (lineage[i] == "partner") y[3L] else NA_real_,
      p_attack = if (lineage[i] == "partner") y[4L] else NA_real_,
      stringsAsFactors = FALSE
    )
    k <- k + 1L
  }
}

data_wide <- do.call(rbind, wide_rows)
data_wide$row_id <- factor(data_wide$row_id)
data_wide$species <- factor(data_wide$species, levels = species)
data_wide$lineage <- factor(data_wide$lineage, levels = c("host", "partner"))

data_long <- do.call(
  rbind,
  lapply(trait_names, function(tr) {
    data.frame(
      row_id = data_wide$row_id,
      species = data_wide$species,
      lineage = data_wide$lineage,
      trait = tr,
      value = data_wide[[tr]]
    )
  })
)
data_long$trait <- factor(data_long$trait, levels = trait_names)
data_long <- data_long[order(data_long$row_id, data_long$trait), ]
rownames(data_long) <- NULL

formula_long <- value ~ 0 + trait +
  kernel_latent(species, K = K_star, d = 2, name = "cross") +
  kernel_unique(species, K = K_star, name = "cross")

formula_wide <- traits(h_size, h_defence, p_size, p_attack) ~ 1 +
  kernel_latent(species, K = K_star, d = 2, name = "cross") +
  kernel_unique(species, K = K_star, name = "cross")

alignment <- data.frame(
  symbol = c("K_star", "G", "psi", "Gamma_HP", "Gamma_0"),
  keyword = c(
    "make_cross_kernel()",
    "kernel_latent(..., d = 2)",
    "kernel_unique()",
    "extract_Gamma()",
    "block-diagonal K"
  ),
  dgp = c(
    "K_star = f(A_H, A_P, W, rho)",
    "G ~ N(0, K_star)",
    "trait-specific diagonal kernel variation",
    "Lambda_H %*% t(Lambda_P)",
    "blockdiag(A_H, A_P)"
  ),
  extractor = c(
    "fit$phylo_vcv",
    "extract_Sigma(part = \"shared\")",
    "extract_Sigma(part = \"unique\")",
    "extract_Gamma(level = \"cross\")",
    "extract_Gamma(level = \"cross\") on null fit"
  ),
  truth_column = c(
    "example$K_star",
    "truth$Lambda %*% t(truth$Lambda)",
    "truth$psi",
    "truth$Gamma",
    "zero host-partner block"
  )
)

example <- list(
  data_long = data_long,
  data_wide = data_wide,
  A_H = A_H,
  A_P = A_P,
  W = W,
  K_star = K_star,
  K_null = K_null,
  truth = list(
    seed = seed,
    n_host = n_H,
    n_partner = n_P,
    n_rep = n_rep,
    rho = rho,
    resid_sd = resid_sd,
    trait_names = trait_names,
    host_traits = host_traits,
    partner_traits = partner_traits,
    Lambda = Lambda,
    Lambda_H = Lambda_H,
    Lambda_P = Lambda_P,
    Gamma = Gamma_true,
    psi = psi
  ),
  formula_long = formula_long,
  formula_wide = formula_wide,
  fit_args = list(
    trait = "trait",
    unit = "row_id",
    cluster = "species",
    family = stats::gaussian()
  ),
  story = list(
    title = "Cross-lineage coevolution kernel",
    question = paste(
      "Do host traits covary with partner traits across an observed",
      "association matrix after accounting for both phylogenies?"
    ),
    host_traits = c(
      h_size = "host body size",
      h_defence = "host defence investment"
    ),
    partner_traits = c(
      p_size = "partner body size",
      p_attack = "partner attack investment"
    )
  ),
  alignment = alignment,
  generator = "data-raw/examples/make-coevolution-kernel-example.R"
)

attr(example, "created_at") <- format(Sys.time(), tz = "UTC", usetz = TRUE)
attr(example, "gllvmTMB_version") <-
  as.character(utils::packageVersion("gllvmTMB"))

if (!dir.exists(dirname(OUT_PATH))) {
  dir.create(dirname(OUT_PATH), recursive = TRUE)
}
saveRDS(example, OUT_PATH)

cat(sprintf("[data-raw] saved -> %s (%d bytes)\n",
            OUT_PATH, file.size(OUT_PATH)))
