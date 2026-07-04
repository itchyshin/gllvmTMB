# pedigree_to_A(): selfing inbreeding (#623) and referenced-but-absent
# parents (#607).

test_that("pedigree_to_A() gives selfed offspring the correct inbreeding (#623)", {
  ped <- data.frame(
    id = c("p", "c"),
    sire = c(NA, "p"),
    dam = c(NA, "p"),
    stringsAsFactors = FALSE
  )
  A <- pedigree_to_A(ped)
  # Selfed offspring of a non-inbred founder: F = 0.5, A_cc = 1.5, A_pc = 1.
  expect_equal(unname(A["p", "p"]), 1)
  expect_equal(unname(A["c", "c"]), 1.5)
  expect_equal(unname(A["p", "c"]), 1)
})

test_that("pedigree_to_A() leaves outcrossed pedigrees unchanged (#623 guard)", {
  ped <- data.frame(
    id = c("a", "b", "o"),
    sire = c(NA, NA, "a"),
    dam = c(NA, NA, "b"),
    stringsAsFactors = FALSE
  )
  A <- pedigree_to_A(ped)
  expect_equal(unname(A["o", "o"]), 1) # non-inbred
  expect_equal(unname(A["a", "o"]), 0.5) # standard parent-offspring
  expect_equal(unname(A["a", "b"]), 0) # unrelated founders
})

test_that("pedigree_to_A() warns on a parent absent from the id column (#607)", {
  ped <- data.frame(
    id = c("a", "o"),
    sire = c(NA, "a"),
    dam = c(NA, "MISSING"),
    stringsAsFactors = FALSE
  )
  expect_warning(pedigree_to_A(ped), regexp = "absent from the")
})
