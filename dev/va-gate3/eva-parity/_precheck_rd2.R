db <- tools::Rd_db("gllvm")
rd <- db[["gllvm.Rd"]]
out <- capture.output(tools::Rd2txt(rd))
writeLines(out, "/private/tmp/gllvmtmb-va-in-06/dev/va-gate3/eva-parity/gllvm_Rd_full.txt")
cat(length(out), "lines written\n")
