# Sharding must never silently drop a test file. These check the two properties
# that guarantee it: the N shards PARTITION the file list (disjoint AND
# complete), and a malformed spec is an error rather than a silent no-op.
# The helper is loaded automatically (helper-shard-util.R).

test_that("N shards partition seq_len(len) exactly", {
  for (len in c(0L, 1L, 7L, 61L, 376L)) {
    for (n in c(1L, 3L, 4L, 7L)) {
      shards <- lapply(seq_len(n), function(k) gllvm_shard_indices(len, k, n))
      expect_equal(sort(unlist(shards)), seq_len(len), info = paste(len, n))
      for (a in seq_len(n - 1L)) {
        for (b in seq(a + 1L, n)) {
          expect_length(intersect(shards[[a]], shards[[b]]), 0L)
        }
      }
    }
  }
})

test_that("gllvm_parse_shard_spec accepts well-formed specs", {
  expect_equal(gllvm_parse_shard_spec("1/4"), c(k = 1L, n = 4L))
  expect_equal(gllvm_parse_shard_spec("4/4"), c(k = 4L, n = 4L))
  expect_equal(gllvm_parse_shard_spec("1/1"), c(k = 1L, n = 1L))
})

test_that("gllvm_parse_shard_spec rejects malformed or out-of-range specs", {
  for (bad in c("0/4", "5/4", "a/b", "1/0", "1", "1/2/3", "")) {
    expect_error(gllvm_parse_shard_spec(bad))
  }
})

test_that("an unset shard spec means no filtering", {
  expect_null(gllvm_shard_filter(".", ""))
})

test_that("the filter selects each file exactly once across shards", {
  files <- sort(list.files(".", pattern = "^test-.*\\.[Rr]$"), method = "radix")
  skip_if(length(files) == 0L, "no test files visible from the working directory")
  stripped <- sub("\\.[Rr]$", "", sub("^test-", "", files))
  n <- 4L
  sel <- lapply(seq_len(n), function(k) {
    stripped[grepl(gllvm_shard_filter(".", paste0(k, "/", n)), stripped)]
  })
  expect_equal(sort(unlist(sel)), sort(stripped))
  for (a in seq_len(n - 1L)) {
    for (b in seq(a + 1L, n)) {
      expect_length(intersect(sel[[a]], sel[[b]]), 0L)
    }
  }
})
