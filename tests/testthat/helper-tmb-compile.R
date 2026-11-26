# Compile a copied TMB fixture from its own directory.  On Windows, passing an
# absolute temporary path to `TMB::compile()` can lose path separators in the
# Rtools command line.  The DLL remains beside the fixture in either case.
.compile_tmb_fixture <- function(cpp) {
  old_wd <- getwd()
  on.exit(setwd(old_wd), add = TRUE)
  setwd(dirname(cpp))
  TMB::compile(basename(cpp))
}

# Unload a compiled fixture DLL without leaving a live ADFun behind.  Calling
# `dyn.unload()` while the test's `obj` / `tmb_obj` still holds external
# pointers prints "N external pointers will be removed" and leaves the process
# heap in a state where a later MakeADFun can segfault (shard 3/4 of the suite,
# test-va-mixed-family.R).  Free the ADFun objects first, then collect, then
# unload.
.unload_tmb_fixture <- function(dll, env = parent.frame()) {
  for (nm in c("obj", "tmb_obj")) {
    if (exists(nm, envir = env, inherits = FALSE)) {
      o <- get(nm, envir = env, inherits = FALSE)
      if (is.list(o) && is.environment(o$env)) {
        try(TMB::FreeADFun(o), silent = TRUE)
      }
    }
  }
  invisible(gc(verbose = FALSE))
  dyn.unload(dll)
}
