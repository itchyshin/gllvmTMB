db <- tools::Rd_db("gllvm")
nm <- grep("^gllvm[.]Rd$", names(db), value = TRUE)
print(nm)
