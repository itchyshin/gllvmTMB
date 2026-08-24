# Compile a copied TMB fixture from its own directory.  On Windows, passing an
# absolute temporary path to `TMB::compile()` can lose path separators in the
# Rtools command line.  The DLL remains beside the fixture in either case.
.compile_tmb_fixture <- function(cpp) {
  old_wd <- getwd()
  on.exit(setwd(old_wd), add = TRUE)
  setwd(dirname(cpp))
  TMB::compile(basename(cpp))
}
