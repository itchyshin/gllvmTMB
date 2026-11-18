# Run from the package root in a clean R session with a single BLAS thread.
# Do not claim exact-source evidence if any pre/post identity differs.
files <- c('R/fit-multi.R', 'R/gllvmTMB.R', 'src/gllvmTMB.cpp',
           'dev/two-kernel-gaussian/oracle.R',
           'dev/two-kernel-gaussian/check-native.R',
           'dev/two-kernel-gaussian/run-native.R')
hash <- function(paths) {
  x <- system2('shasum', c('-a', '256', shQuote(paths)), stdout=TRUE, stderr=TRUE)
  if (!is.null(attr(x, 'status'))) stop(paste(x, collapse='\n'))
  x
}
before <- hash(files)
head <- system2('git', c('rev-parse', 'HEAD'), stdout=TRUE)
staged_library <- Sys.getenv('TWO_KERNEL_STAGED_LIBRARY', unset = '')
if (nzchar(staged_library)) {
  staged_library <- normalizePath(staged_library, mustWork = TRUE)
  .libPaths(c(staged_library, .libPaths()))
  library('gllvmTMB', character.only = TRUE, lib.loc = staged_library)
  actual_package <- normalizePath(find.package('gllvmTMB'), mustWork = TRUE)
  stopifnot(identical(actual_package,
                      normalizePath(file.path(staged_library, 'gllvmTMB'), mustWork = TRUE)))
  cat('PACKAGE_MODE staged\nPACKAGE_PATH', actual_package, '\n')
} else {
  pkgload::load_all('.', quiet=TRUE)
  cat('PACKAGE_MODE pkgload_provisional\n')
}
dll <- getLoadedDLLs()[['gllvmTMB']][['path']]
dll_before <- hash(dll)
cat('GIT_HEAD',head,'\nR_VERSION',R.version.string,'\n')
cat('PRE_SOURCE_SHA256\n',paste(before,collapse='\n'),'\nDLL_SHA256\n',
    paste(dll_before,collapse='\n'),'\n')
source('dev/two-kernel-gaussian/check-native.R')
after <- hash(files); dll_after <- hash(dll)
stopifnot(identical(before, after), identical(dll_before, dll_after),
          identical(head, system2('git', c('rev-parse','HEAD'), stdout=TRUE)))
cat('IDENTITY_UNCHANGED\n')
cat('TMB_VERSION',as.character(utils::packageVersion('TMB')),
    'PKGLOAD_VERSION',as.character(utils::packageVersion('pkgload')),'\n')
