# Compile a copied TMB fixture from its own directory.  On Windows, passing an
# absolute temporary path to `TMB::compile()` can lose path separators in the
# Rtools command line.  The DLL remains beside the fixture in either case.
#
# On Linux with GCC, fixtures are built with -fno-gnu-unique (refs #1833).
# GCC emits the static locals of inline/template code as STB_GNU_UNIQUE
# (CppAD's atomic-function registry `atomic_base<>::class_object()::list_`,
# TMB's `afunD_lgamma` and friends, and their guard variables), and glibc
# coalesces those once per process even under dyn.load()'s RTLD_LOCAL. On
# PR #1833 (R-CMD-check run 44637491417, shard 3, 10/10 attempts) the order
# test-fix-1365-free-p.R (loads gllvmTMB_va_r3) -> test-isdm-developer-fit.R
# (fixture DLL, then on.exit(dyn.unload())) -> test-va-mixed-family.R
# segfaulted with "memory not mapped" in the next VA MakeADFun. Locally the
# fault is in CppAD::atomic_base<double>::operator() under lgamma() in
# gllvmTMB_va_r3.so, after the fixture image is gone from the process maps:
# most likely a shared atomic object the fixture initialised, still pointing
# into the unloaded fixture. The flag stops GNU-unique coalescing of the
# fixture's definitions, so unloading it no longer breaks the VA DLL (same
# three files: segfault without it, 255 pass with it). The fixtures' code and
# every assertion are unchanged. The flag is added only when a compile probe
# with R's configured C++ compiler accepts it, so other toolchains build the
# fixtures exactly as before.
.tmb_fixture_isolation_flags <- function() {
  if (!identical(Sys.info()[["sysname"]], "Linux")) return("")
  cxx <- tryCatch(
    suppressWarnings(system2(file.path(R.home("bin"), "R"),
                             c("CMD", "config", "CXX"),
                             stdout = TRUE, stderr = FALSE)),
    error = function(e) character(0)
  )
  cxx <- strsplit(trimws(paste(cxx, collapse = " ")), "[[:space:]]+")[[1L]]
  if (length(cxx) == 0L || !nzchar(cxx[[1L]])) return("")
  probe <- tempfile("tmb-fixture-probe-")
  dir.create(probe)
  on.exit(unlink(probe, recursive = TRUE), add = TRUE)
  src <- file.path(probe, "probe.cpp")
  writeLines(c("inline int &gllvm_probe() { static int x = 0; return x; }",
               "int gllvm_probe_use() { return gllvm_probe(); }"), src)
  status <- tryCatch(
    suppressWarnings(system2(cxx[[1L]],
                             c(cxx[-1L], "-fno-gnu-unique", "-Werror", "-c",
                               shQuote(src), "-o",
                               shQuote(file.path(probe, "probe.o"))),
                             stdout = FALSE, stderr = FALSE)),
    error = function(e) 1L
  )
  if (identical(as.integer(status), 0L)) "-fno-gnu-unique" else ""
}

.compile_tmb_fixture <- function(cpp) {
  old_wd <- getwd()
  on.exit(setwd(old_wd), add = TRUE)
  setwd(dirname(cpp))
  TMB::compile(basename(cpp), flags = .tmb_fixture_isolation_flags())
}
