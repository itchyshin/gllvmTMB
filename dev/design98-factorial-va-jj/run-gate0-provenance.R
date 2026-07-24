#!/usr/bin/env Rscript

design_root <- file.path("dev", "design98-factorial-va-jj")
source(file.path(design_root, "R", "provenance.R"))
source(file.path(design_root, "R", "fixture.R"))
source(file.path(design_root, "R", "oracle.R"))

if (file.exists(file.path(design_root, "results", "REAL_RUN.json"))) {
  stop(
    "Design-98 real-run registry already exists; Gate 0 must not create or replace it"
  )
}

prior_baseline <- d98_prior_design_inventory()
prior_final <- d98_prior_design_inventory()
d98_assert_same_inventory(prior_baseline, prior_final)

fixture_a <- d98_nested_fixture()
fixture_b <- d98_nested_fixture()
stopifnot(
  identical(fixture_a$low$y, fixture_b$low$y),
  identical(fixture_a$high$y, fixture_b$high$y),
  identical(
    fixture_a$low$y,
    fixture_a$high$y[seq_len(fixture_a$truth$n_low), , drop = FALSE]
  )
)
d98_assert_fixture_hashes(fixture_a)

gh_checksums <- d98_gh_checksums(gh_rule = d98_gh)
metadata <- d98_manifest_metadata(
  uuid = "GATE0_NO_REAL_RUN",
  source_paths = d98_design98_source_paths(),
  gh_checksums = gh_checksums
)
stopifnot(
  identical(metadata$uuid, "GATE0_NO_REAL_RUN"),
  identical(metadata$base_commit, "7a725c5e"),
  is.character(metadata$source_head),
  nchar(metadata$source_head) == 40L,
  is.character(metadata$contract_sha256),
  nchar(metadata$contract_sha256) == 64L,
  identical(names(metadata$gh_checksums), c("31", "41", "61")),
  all(vapply(
    metadata$gh_checksums,
    function(x) abs(x$weight_sum - 1) < 1e-12,
    logical(1)
  ))
)

cat(
  "Design 98 Gate 0 provenance and nested-fixture checks: PASS (no run root created)\n"
)
