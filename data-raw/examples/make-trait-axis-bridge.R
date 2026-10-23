## Regenerate inst/extdata/examples/trait-axis-bridge.rds.
##
## A deterministic bridge between measured trait columns
## phylogenetic comparative data and a 48-species Gaussian community model.
## Run from the repository root:
##   Rscript data-raw/examples/make-trait-axis-bridge.R

suppressPackageStartupMessages({
  library(ape)
  devtools::load_all(".", quiet = TRUE)
})

out_path <- file.path("inst", "extdata", "examples", "trait-axis-bridge.rds")
seed <- 20260824L
set.seed(seed)

n_species <- 48L
n_populations <- 6L
n_sites <- 60L
species <- sprintf("montane_%02d", seq_len(n_species))
tree <- ape::rcoal(n_species)
tree$tip.label <- species

## Brownian covariance makes the simulated species effects visibly structured
## by the supplied tree, while the small diagonal ridge avoids numerical ties.
A <- ape::vcv.phylo(tree, corr = TRUE)[species, species]
A <- A + diag(1e-8, n_species)
draw_phylo <- function(sd) {
  as.numeric(t(chol(A)) %*% stats::rnorm(n_species, sd = sd))
}

pcm_traits <- c(paste0("morph_", 1:8), paste0("life_", 1:8))
column_domain <- c(setNames(rep("morphology", 8), pcm_traits[1:8]),
                   setNames(rep("life_history", 8), pcm_traits[9:16]))
domain_slope <- c(morphology = 0.55, life_history = -0.40)
trait_slope_deviation <- c(setNames(seq(-.18, .18, length.out = 8), pcm_traits[1:8]),
                           setNames(seq(-.14, .14, length.out = 8), pcm_traits[9:16]))

pop <- expand.grid(
  species = species,
  population = seq_len(n_populations),
  KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE
)
pop$unit_id <- sprintf("%s_pop_%02d", pop$species, pop$population)
pop$record_id <- pop$unit_id
pop$elevation <- rep(seq(-1.25, 1.25, length.out = n_populations), each = n_species) +
  stats::rnorm(nrow(pop), sd = 0.08)

## Matrix-normal phylogenetic species intercepts across measured trait columns.
Sigma_trait <- diag(rep(0.45, length(pcm_traits))) + 0.25
U <- t(chol(A)) %*% matrix(rnorm(n_species * length(pcm_traits)), n_species) %*% chol(Sigma_trait)
pcm_rows <- lapply(seq_along(pcm_traits), function(j) {
  trait_name <- pcm_traits[[j]]
  species_index <- match(pop$species, species)
  data.frame(
    unit_id = pop$unit_id,
    record_id = pop$record_id,
    species = factor(pop$species, levels = species),
    population = factor(pop$population),
    elevation = pop$elevation,
    trait = factor(trait_name, levels = pcm_traits),
    column_domain = factor(column_domain[[trait_name]], levels = c("morphology", "life_history")),
      value_z = domain_slope[[column_domain[[trait_name]]]] * pop$elevation +
      trait_slope_deviation[[trait_name]] * pop$elevation + U[species_index, j] +
      stats::rnorm(nrow(pop), sd = 0.45),
    stringsAsFactors = FALSE
  )
})
pcm_data <- do.call(rbind, pcm_rows)
rownames(pcm_data) <- NULL

site <- data.frame(
  unit_id = sprintf("site_%02d", seq_len(n_sites)),
  elevation = seq(-1.5, 1.5, length.out = n_sites) + stats::rnorm(n_sites, sd = 0.06),
  forest_cover = scale(stats::rnorm(n_sites) + seq(-0.8, 0.8, length.out = n_sites))[, 1L]
)
site$site_id <- site$unit_id
guild <- rep(c("alpine_insectivore", "forest_insectivore", "granivore", "omnivore"), length.out = n_species)
guild_elevation <- c(alpine_insectivore = 1.05, forest_insectivore = 0.35,
                     granivore = -0.15, omnivore = 0.55)
guild_forest <- c(alpine_insectivore = -0.55, forest_insectivore = 0.80,
                  granivore = 0.15, omnivore = 0.30)
species_metadata <- data.frame(
  species = species,
  guild = factor(guild, levels = unique(guild)),
  stringsAsFactors = FALSE
)

## Each column receives non-zero, phylogenetically structured deviations for
## both predictors.  This is the target of phylo_slope(... | trait).
elevation_deviation <- draw_phylo(0.65)
forest_deviation <- draw_phylo(0.45)
species_intercept <- draw_phylo(0.8)
community_rows <- lapply(seq_along(species), function(i) {
  data.frame(
    unit_id = site$unit_id,
    site_id = site$site_id,
    site = factor(site$unit_id, levels = site$unit_id),
    trait = factor(species[[i]], levels = species),
    species = factor(species[[i]], levels = species),
    guild = species_metadata$guild[[i]],
    elevation = site$elevation,
    forest_cover = site$forest_cover,
    value = 0.35 + species_intercept[[i]] +
      (guild_elevation[[as.character(species_metadata$guild[[i]])]] + elevation_deviation[[i]]) * site$elevation +
      (guild_forest[[as.character(species_metadata$guild[[i]])]] + forest_deviation[[i]]) * site$forest_cover +
      stats::rnorm(n_sites, sd = 0.45),
    stringsAsFactors = FALSE
  )
})
community_data <- do.call(rbind, community_rows)
rownames(community_data) <- NULL

## Three Poisson-log sources.  The observation columns are deliberately normal
## R predictors, with the intercept/reference coding left to isdm_source().
isdm_species <- species[seq_len(3L)]
isdm_sites <- site[unique(round(seq(1L, nrow(site), length.out = 12L))), , drop = FALSE]
access_design <- seq(-1, 1, length.out = nrow(isdm_sites))
popdens_design <- scale(sin(seq(0, 2 * pi, length.out = nrow(isdm_sites))))[, 1L]
observer_design <- rep(c("A", "B"), each = nrow(isdm_sites) / 2L)
method_design <- rep(c("point", "transect"), length.out = nrow(isdm_sites))
source_intercept <- c(gbif = 0.20, inat = -0.25, survey = 0)
isdm_data <- do.call(rbind, lapply(c("gbif", "inat", "survey"), function(source) {
  do.call(rbind, lapply(isdm_species, function(sp) {
    ecological_eta <- -0.2 + 0.55 * isdm_sites$elevation +
      if (sp == isdm_species[[2L]]) 0.25 else 0
    observation_eta <- source_intercept[[source]] + if (source %in% c("gbif", "inat")) {
      0.35 * access_design - 0.20 * popdens_design
    } else {
      0.30 * (observer_design == "B") - 0.25 * (method_design == "transect")
    }
    data.frame(
      unit_id = sprintf("%s_%s", isdm_sites$unit_id, source),
      trait = factor(sp, levels = isdm_species),
      isdm_source = factor(source, levels = c("gbif", "inat", "survey")),
      elevation = isdm_sites$elevation,
      access = if (source %in% c("gbif", "inat")) access_design else 0,
      popdens = if (source %in% c("gbif", "inat")) popdens_design else 0,
      observer = factor(if (source == "survey") observer_design else "A"),
      method = factor(if (source == "survey") method_design else "point"),
      ecological_intensity = exp(ecological_eta),
      expected_recorded_intensity = exp(ecological_eta + observation_eta),
      value = stats::rpois(nrow(isdm_sites), exp(ecological_eta + observation_eta)),
      stringsAsFactors = FALSE
    )
  }))
}))
rownames(isdm_data) <- NULL

bridge <- list(
  pcm = list(
    data = pcm_data,
    tree = tree,
    formula = value_z ~ 0 + trait + column_domain:elevation +
      slope(elevation | trait) +
      phylo_latent(0 + trait | species, tree = tree, d = 2, unique = TRUE),
    fit_args = list(trait = "trait", unit = "record_id", family = stats::gaussian()),
    truth = list(domain_mean_slope = domain_slope,
      trait_slope_deviation = trait_slope_deviation,
      Sigma_phy = Sigma_trait),
    metadata = list(n_species = n_species, populations_per_species = n_populations,
                    response_columns = pcm_traits, column_domain = column_domain)
  ),
  column = list(
    data = community_data,
    tree = tree,
    formula = value ~ 0 + trait + guild:elevation + guild:forest_cover +
      phylo_slope(elevation + forest_cover | trait, tree = tree),
    fit_args = list(trait = "trait", unit = "site_id", family = stats::gaussian()),
    truth = list(elevation_slope_deviation = stats::setNames(elevation_deviation, species),
                 forest_cover_slope_deviation = stats::setNames(forest_deviation, species),
                 species_intercept = stats::setNames(species_intercept, species)),
    metadata = list(n_species = n_species, n_sites = n_sites,
                    species_metadata = species_metadata)
  ),
  isdm = list(
    data = isdm_data,
    formula = value ~ 0 + trait + trait:elevation,
    family = gllvmTMB::isdm_sources(
      gbif = gllvmTMB::isdm_source(stats::poisson(link = "log"), observation = ~ access + popdens),
      inat = gllvmTMB::isdm_source(stats::poisson(link = "log"), observation = ~ access + popdens),
      survey = gllvmTMB::isdm_source(stats::poisson(link = "log"), observation = ~ observer + method)
    ),
    fit_args = list(trait = "trait", unit = "unit_id"),
    truth = list(source_intercept = source_intercept,
      ecological_elevation_slope = 0.55,
      access_effect = 0.35, popdens_effect = -0.20,
      observer_B_effect = 0.30, transect_effect = -0.25),
    metadata = list(purpose = "small source-current isdm_sources() declaration gate")
  ),
  metadata = list(seed = seed, story = "Montane birds: trait axes bridge PCM and community models")
)

dir.create(dirname(out_path), recursive = TRUE, showWarnings = FALSE)
saveRDS(bridge, out_path, version = 3)
message("Wrote ", out_path)
