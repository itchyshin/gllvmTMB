## Regenerate inst/extdata/examples/trait-axis-bridge.rds.
##
## A deterministic, deliberately modest bridge between four-column
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

pcm_traits <- c("body_mass", "bill_length", "clutch_size", "lay_date")
column_domain <- c(
  body_mass = "morphology", bill_length = "morphology",
  clutch_size = "life_history", lay_date = "life_history"
)
trait_intercept <- c(body_mass = 36, bill_length = 21, clutch_size = 3.4, lay_date = 142)
domain_slope <- c(morphology = 2.6, life_history = -1.8)

pop <- expand.grid(
  species = species,
  population = seq_len(n_populations),
  KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE
)
pop$unit_id <- sprintf("%s_pop_%02d", pop$species, pop$population)
pop$record_id <- pop$unit_id
pop$elevation <- rep(seq(-1.25, 1.25, length.out = n_populations), each = n_species) +
  stats::rnorm(nrow(pop), sd = 0.08)

pcm_rows <- lapply(pcm_traits, function(trait_name) {
  intercept_deviation <- draw_phylo(if (column_domain[[trait_name]] == "morphology") 2.2 else 1.0)
  slope_deviation <- draw_phylo(if (column_domain[[trait_name]] == "morphology") 0.55 else 0.35)
  species_index <- match(pop$species, species)
  data.frame(
    unit_id = pop$unit_id,
    record_id = pop$record_id,
    species = factor(pop$species, levels = species),
    population = factor(pop$population),
    elevation = pop$elevation,
    trait = factor(trait_name, levels = pcm_traits),
    column_domain = factor(column_domain[[trait_name]], levels = c("morphology", "life_history")),
    value = trait_intercept[[trait_name]] +
      domain_slope[[column_domain[[trait_name]]]] * pop$elevation +
      intercept_deviation[species_index] + slope_deviation[species_index] * pop$elevation +
      stats::rnorm(nrow(pop), sd = if (trait_name == "lay_date") 1.8 else 0.7),
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
      (0.75 + elevation_deviation[[i]]) * site$elevation +
      (-0.40 + forest_deviation[[i]]) * site$forest_cover +
      stats::rnorm(n_sites, sd = 0.45),
    stringsAsFactors = FALSE
  )
})
community_data <- do.call(rbind, community_rows)
rownames(community_data) <- NULL

## A compact two-source declaration/data slice used only by the source-current
## iSDM gate.  It remains separate from the Gaussian community teaching data.
isdm_species <- species[seq_len(3L)]
isdm_sites <- site[seq_len(12L), , drop = FALSE]
isdm_data <- do.call(rbind, lapply(c("gbif", "survey"), function(source) {
  do.call(rbind, lapply(isdm_species, function(sp) {
    eta <- -0.2 + 0.55 * isdm_sites$elevation + if (sp == isdm_species[[2L]]) 0.25 else 0
    data.frame(
      unit_id = sprintf("%s_%s", isdm_sites$unit_id, source),
      trait = factor(sp, levels = isdm_species),
      isdm_source = factor(source, levels = c("gbif", "survey")),
      elevation = isdm_sites$elevation,
      access = if (source == "gbif") seq(0.1, 1, length.out = nrow(isdm_sites)) else 0,
      value = if (source == "gbif") stats::rpois(nrow(isdm_sites), exp(eta)) else
        stats::rbinom(nrow(isdm_sites), 1L, stats::plogis(eta)),
      stringsAsFactors = FALSE
    )
  }))
}))
rownames(isdm_data) <- NULL

bridge <- list(
  pcm = list(
    data = pcm_data,
    tree = tree,
    formula = value ~ 0 + trait + column_domain:elevation +
      phylo_indep(0 + trait | species, tree = tree) +
      phylo_slope(elevation | species, tree = tree),
    fit_args = list(trait = "trait", unit = "record_id", family = stats::gaussian()),
    metadata = list(n_species = n_species, populations_per_species = n_populations,
                    response_columns = pcm_traits, column_domain = column_domain)
  ),
  column = list(
    data = community_data,
    tree = tree,
    formula = value ~ 0 + trait + phylo_slope(elevation + forest_cover | trait, tree = tree),
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
      gbif = gllvmTMB::isdm_source(stats::poisson(), observation = ~ access),
      survey = gllvmTMB::isdm_source(stats::binomial(link = "cloglog"), observation = ~ 1)
    ),
    fit_args = list(trait = "trait", unit = "unit_id"),
    metadata = list(purpose = "small source-current isdm_sources() declaration gate")
  ),
  metadata = list(seed = seed, story = "Montane birds: trait axes bridge PCM and community models")
)

dir.create(dirname(out_path), recursive = TRUE, showWarnings = FALSE)
saveRDS(bridge, out_path, version = 3)
message("Wrote ", out_path)
