seed_contract <- testthat::test_path(
  "..",
  "..",
  "dev",
  "interval-calibration",
  "seed-registry-contract.R"
)
registry_path <- testthat::test_path(
  "..",
  "..",
  "docs",
  "dev-log",
  "artifacts",
  "interval-calibration",
  "seed-registry.csv"
)
.interval_seed_sources_available <- all(file.exists(c(
  seed_contract,
  registry_path
)))

if (.interval_seed_sources_available) {
  source(seed_contract, local = TRUE)

test_that("the frozen programme expands to 175000 pairwise-disjoint seeds", {
  registry <- ic_read_seed_registry(registry_path)
  expanded <- ic_expand_seed_registry(registry)
  verdict <- ic_validate_seed_registry(registry, expanded)

  expect_equal(nrow(expanded), 175000L)
  expect_equal(length(unique(expanded$seed)), 175000L)
  expect_true(verdict$disjoint)
  counts <- table(expanded$packet)
  expected <- c(
    `CI09` = 30000L,
    `CI10` = 90000L,
    `CI13` = 20000L,
    `CI14` = 10000L,
    `CI15` = 20000L,
    `PVT-02` = 5000L
  )
  expect_equal(names(counts), names(expected))
  expect_equal(as.integer(counts), unname(expected))
})

test_that("registry bounds and formulas fail closed when altered", {
  registry <- ic_read_seed_registry(registry_path)

  bad_bounds <- registry
  bad_bounds$max_seed[bad_bounds$packet == "CI09"] <- 1L
  expect_error(
    ic_validate_seed_registry(bad_bounds, ic_expand_seed_registry(bad_bounds)),
    "bounds"
  )

  overlap <- registry
  overlap$seed_base[overlap$packet == "CI13"] <-
    overlap$seed_base[overlap$packet == "CI09"]
  overlap$seed_formula[overlap$packet == "CI13"] <-
    "seed = 90000000 + cell_id * 10000 + local_rep"
  expect_error(
    ic_validate_seed_registry(overlap, ic_expand_seed_registry(overlap)),
    "collision"
  )
})

test_that("the new PVT mapping avoids the known old realised-seed collision", {
  historical <- data.frame(
    seed = c(152002L, 152003L, 550001L),
    source = "historical-fixture.csv",
    stringsAsFactors = FALSE
  )
  old <- data.frame(
    packet = "PVT-02-old",
    seed = 152002:157001,
    stringsAsFactors = FALSE
  )
  registry <- ic_read_seed_registry(registry_path)
  current <- ic_expand_seed_registry(registry)

  expect_gt(nrow(ic_historical_seed_collisions(old, historical)), 0L)
  expect_equal(nrow(ic_historical_seed_collisions(current, historical)), 0L)
})

test_that("historical seed collection reads only seed-valued columns", {
  td <- tempfile("seed-history-")
  dir.create(td)
  good <- file.path(td, "good.csv")
  write.csv(
    data.frame(seed = c(41L, 42L), seed_base = 900L, value = 1:2),
    good,
    row.names = FALSE
  )
  noise <- file.path(td, "noise.csv")
  write.csv(data.frame(value = 1:2), noise, row.names = FALSE)

  out <- ic_collect_historical_seeds(c(good, noise))
  expect_equal(sort(out$seed), c(41L, 42L))
  expect_false(900L %in% out$seed)
  expect_true(all(out$source == good))
})

test_that("current programme evidence is not reclassified as seed history", {
  td <- tempfile("seed-current-evidence-")
  dir.create(td)
  historical <- file.path(td, "historical.csv")
  current <- file.path(td, "current-programme.csv")
  write.csv(data.frame(seed = 18065153L), historical, row.names = FALSE)
  write.csv(data.frame(seed = 800050001L), current, row.names = FALSE)

  out <- ic_collect_historical_seeds(
    c(historical, current),
    exclude_paths = current
  )

  expect_equal(out$seed, 18065153L)
  expect_equal(out$source, historical)
})
} else {
  test_that("interval seed registry checks are source-checkout only", {
    skip("dev/interval-calibration and docs/ are absent from the built package")
  })
}
