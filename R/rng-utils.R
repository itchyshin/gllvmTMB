## Seed the RNG for the duration of the calling function, then put the
## caller's global RNG state back (#1413).
##
## `set.seed(seed)` inside an exported function leaves the user's stream in
## the seed-derived state, so later `runif()` / `sample()` calls in their
## script repeat or depend on that seed. `stats::simulate()` methods and
## `residuals(type = "randomized_quantile", seed =)` restore the state; this
## helper gives the other `seed =` arguments the same behaviour.
##
## Call it once near the top of the function that owns `seed`; the restore is
## registered on that function's exit (`on.exit(add = TRUE)`), including on
## error. `seed = NULL` (or any zero-length value) is a no-op and the stream is left alone.
.gllvmTMB_local_seed <- function(seed, .envir = parent.frame()) {
  if (!length(seed)) {
    return(invisible(NULL))
  }
  genv <- globalenv()
  if (exists(".Random.seed", envir = genv, inherits = FALSE)) {
    old_seed <- get(".Random.seed", envir = genv, inherits = FALSE)
    restore <- bquote(assign(".Random.seed", .(old_seed), envir = globalenv()))
  } else {
    restore <- quote(
      suppressWarnings(rm(".Random.seed", envir = globalenv()))
    )
  }
  do.call(base::on.exit, list(restore, TRUE), envir = .envir)
  set.seed(seed)
  invisible(NULL)
}
