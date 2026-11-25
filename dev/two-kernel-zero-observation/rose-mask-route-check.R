## Read-only admission check for the frozen Rose mask. No response values are
## read or fitted; observed cells are filled with zero only to exercise formula
## parsing and TMB-data construction before the optimizer is reached.
args <- commandArgs(trailingOnly = TRUE)
stopifnot(length(args) == 1L, dir.exists(args[[1L]]))
coevolution <- normalizePath(args[[1L]], mustWork = TRUE)
mask_path <- file.path(coevolution, "analysis/results/rose-design/observed-mask.tsv")
tree_path <- file.path(coevolution, "sources/working/polemoniaceae-audit/phylogeny.zip")
stopifnot(file.exists(mask_path), file.exists(tree_path))

fields <- c(
  "calyx_length", "fused_corolla_length", "corolla_tube_wdith",
  "corolla_lobe_lenth", "corolla_lobe_width", "anther_length",
  "mean_androecium_length", "style_length"
)
saved <- utils::read.delim(mask_path, check.names = FALSE)
mask <- as.matrix(saved[, fields, drop = FALSE])
species <- as.character(saved$tree_tip)
stopifnot(nrow(mask) == 464L, ncol(mask) == 8L, sum(mask) == 3432L,
          sum(rowSums(mask) > 0L) == 463L, !anyDuplicated(species))

tree <- ape::read.nexus(unz(tree_path, "phylogeny/polemoniaceae.MCC.tre"))
tree$tip.label <- gsub("'", "", tree$tip.label, fixed = TRUE)
tree$tip.label <- sub("^Polemonium_pulcherrimum_var\\._delicatum$",
                      "Polemonium_delicatum", tree$tip.label)
tree$tip.label <- sub("^Gilia_ophthalmoides_$", "Gilia_ophthalmoides",
                      tree$tip.label)
tree$tip.label <- sub("^Ipomopsis_sancti_spiritus$",
                      "Ipomopsis_sancti-spiritus", tree$tip.label)
outgroup <- grepl("^(Fouquieria|Actinidia|Saurauia)_", tree$tip.label)
stopifnot(length(tree$tip.label) == 490L, sum(outgroup) == 13L)
focal <- ape::drop.tip(tree, tree$tip.label[outgroup])
focal <- ape::keep.tip(focal, species)
A <- ape::vcv.phylo(focal, corr = TRUE)[species, species, drop = FALSE]
I <- diag(length(species))
dimnames(I) <- list(species, species)
stopifnot(identical(rownames(A), species), identical(colnames(A), species),
          max(abs(diag(A) - 1)) < 1e-12,
          min(eigen(A, symmetric = TRUE, only.values = TRUE)$values) > 0)

dat <- data.frame(species = factor(species, levels = species),
                  stats::setNames(lapply(fields, function(x) {
                    y <- rep(NA_real_, length(species))
                    y[mask[, x]] <- 0
                    y
                  }), fields), check.names = FALSE)
formula <- stats::as.formula(paste0(
  "traits(", paste(fields, collapse = ","),
  ") ~ 1 + kernel_latent(species, K = A, d = 1, name = 'phy', unique = TRUE) + ",
  "kernel_latent(species, K = I, d = 1, name = 'tip', unique = TRUE)"
), env = environment())

captured <- NULL
testthat::test_that("the frozen Rose mask enters the exact A + I route", {
  testthat::local_mocked_bindings(
    MakeADFun = function(data, parameters, ...) {
      captured <<- c(list(data = data, parameters = parameters), list(...))
      stop("ROSE_EXACT_ROUTE_CAPTURE", call. = FALSE)
    },
    .package = "TMB"
  )
  error <- tryCatch({
    gllvmTMB::gllvmTMB(
      formula, data = dat, family = stats::gaussian(), unit = "species",
      cluster = "species", missing = gllvmTMB::miss_control(response = "include"),
      control = gllvmTMB::gllvmTMBcontrol(se = FALSE), known_sigma_eps = 0,
      silent = TRUE
    )
    NULL
  }, error = conditionMessage)
  testthat::expect_identical(error, "ROSE_EXACT_ROUTE_CAPTURE")
  testthat::expect_identical(captured$data$use_exact_pair_marginal, 1L)
  testthat::expect_length(captured$data$exact_y, 3432L)
  testthat::expect_equal(unname(captured$data$K_kernel_raw[1L, , ]),
                         unname(A), tolerance = 1e-10)
  testthat::expect_equal(unname(captured$data$K_kernel_raw[2L, , ]),
                         unname(I), tolerance = 1e-12)
  testthat::expect_setequal(
    paste(captured$data$exact_unit_id, captured$data$exact_trait_id),
    paste(rep(seq_len(464L) - 1L, times = 8L)[as.vector(mask)],
          rep(seq_len(8L) - 1L, each = 464L)[as.vector(mask)])
  )
})

cat("ROSE_ROUTE=PASS; tips=464; contributing_tips=463; observed_cells=3432; ",
    "kernels=Brownian_A+identity_I; optimizer=not_started; observed_values=not_read\n",
    sep = "")
