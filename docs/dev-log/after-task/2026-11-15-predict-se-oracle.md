# Check prediction SE arithmetic on the same fit

The old regression checks pinned four standard-error vectors produced by a seeded refit. Changes in the chosen optimization start changed those outputs even though the old and current route calculations agreed on the same fit.

The new dense oracle checks the quad and joint calculations and their prediction variance, with row-alignment and wrong-formula controls. It also checks the fitted objective against the historical result. This exchanges the exact historical SE-output guard for a same-fit arithmetic check; it does not establish interval coverage. The focused heavy file passed, while full and combined-source checks remain open.
