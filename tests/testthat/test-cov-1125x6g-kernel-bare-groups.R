test_that(".gllvmTMB_lme4_bar_rhs extracts bare grouping symbols", {
  e1 <- call("|", quote(1 + x), quote(unit))
  expect_equal(.gllvmTMB_lme4_bar_rhs(e1), "unit")
  e2 <- call("|", quote(0), "site")
  expect_equal(.gllvmTMB_lme4_bar_rhs(e2), "site")
  expect_equal(.gllvmTMB_lme4_bar_rhs(quote(foo)), NA_character_)
  expect_equal(.gllvmTMB_lme4_bar_rhs(call("+", 1, 2)), NA_character_)
})

test_that(".gllvmTMB_kernel_fn_from_modes maps mode vectors", {
  expect_equal(.gllvmTMB_kernel_fn_from_modes("latent"), "kernel_latent")
  expect_equal(.gllvmTMB_kernel_fn_from_modes(c("indep", "unique")), "kernel_indep")
  expect_equal(.gllvmTMB_kernel_fn_from_modes("dep"), "kernel_dep")
  expect_equal(.gllvmTMB_kernel_fn_from_modes("scalar"), "kernel_scalar")
  expect_equal(.gllvmTMB_kernel_fn_from_modes("unique"), "kernel_unique")
  expect_equal(.gllvmTMB_kernel_fn_from_modes(NA), "kernel_indep")
  expect_equal(.gllvmTMB_kernel_fn_from_modes(character(0)), "kernel_indep")
})

test_that(".gllvmTMB_kernel_bare_groups finds kernel keywords in formulas", {
  f <- y ~ 1 + kernel_indep(unit, K = diag(2)) + kernel_latent(unit, K = diag(2))
  g <- .gllvmTMB_kernel_bare_groups(f)
  expect_equal(nrow(g), 2L)
  expect_setequal(g$fn, c("kernel_indep", "kernel_latent"))
  expect_true(all(g$group == "unit"))
  f2 <- y ~ 1 + latent(1 | unit, d = 2)
  expect_equal(nrow(.gllvmTMB_kernel_bare_groups(f2)), 0L)
})

test_that(".gllvmTMB_phylo_bare_groups collects species from bar syntax", {
  f <- y ~ phylo_indep(0 + trait | species, tree = tr) + phylo_latent(species)
  g <- .gllvmTMB_phylo_bare_groups(f)
  expect_true(any(g$fn == "phylo_latent" & g$group == "species"))
  expect_true(any(g$fn == "phylo_indep" & g$group == "species"))
})

test_that(".gllvmTMB_animal_bare_groups reads animal bar keywords", {
  f <- y ~ animal_dep(1 + x | id, pedigree = ped) + animal_latent(id, d = 2)
  g <- .gllvmTMB_animal_bare_groups(f)
  expect_true(any(g$group == "id"))
  expect_setequal(g$fn, c("animal_dep", "animal_latent"))
})

test_that("kernel keyword markers return invisibly without evaluation", {
  expect_invisible(kernel_latent(unit, K = diag(3)))
  expect_invisible(kernel_indep(unit, K = diag(2)))
  expect_invisible(kernel_dep(unit, K = diag(2)))
})