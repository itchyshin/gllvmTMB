args <- commandArgs(TRUE)
stopifnot(length(args)==1L)
root <- normalizePath(args[1],mustWork=TRUE)
.libPaths(unique(c(file.path(root,'library'),path.expand('~/R/lib'),.libPaths())))
Sys.setenv(OPENBLAS_NUM_THREADS='1',OMP_NUM_THREADS='1',MKL_NUM_THREADS='1',MAKEFLAGS='-j2')
stopifnot(rmarkdown::pandoc_available())
cat('PANDOC', as.character(rmarkdown::pandoc_version()), '\n')
cat('CHECK_PID',Sys.getpid(),'STARTED_UTC',format(Sys.time(),tz='UTC',usetz=TRUE),'\n');flush.console()
started <- Sys.time()
result <- devtools::check(pkg=file.path(root,'source','gllvmTMB'),document=FALSE,
  args='--no-manual',quiet=TRUE,error_on='never',check_dir=file.path(root,'check'))
saveRDS(result,file.path(root,'check-result.rds'))
receipt <- list(errors=result$errors,warnings=result$warnings,notes=result$notes,
  error_n=length(result$errors),warning_n=length(result$warnings),note_n=length(result$notes),
  elapsed_seconds=as.numeric(difftime(Sys.time(),started,units='secs')),
  completed_utc=format(Sys.time(),tz='UTC',usetz=TRUE),R=R.version.string,
  input_sha256=readLines(file.path(root,'input.sha256')))
jsonlite::write_json(receipt,file.path(root,'check-receipt.json'),pretty=TRUE,auto_unbox=TRUE)
print(receipt);flush.console()
quit(status=if(length(result$errors)||length(result$warnings))1L else 0L)
