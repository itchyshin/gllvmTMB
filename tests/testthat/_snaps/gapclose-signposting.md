# indep(1 + x | trait) redirects to the response-column slope grammar

    Code
      gllvmTMB:::desugar_brms_sugar(value ~ 0 + trait + indep(1 + x | trait))
    Condition
      Error in `.assert_no_augmented_lhs()`:
      ! `indep()` augmented LHS is not yet supported.
      i You wrote `indep(1 + x | trait)`.
      x This wrapper accepts only intercept-only `0 + trait | g` or `1 | g` forms.
      > Use the response-column slope grammar instead: `slope()`, `phylo_slope()`, or `animal_slope()`, e.g. `phylo_slope(x | trait, tree = tree)`.

# indep(1 + x | site) redirects to latent()/unique(), not phylo_slope()

    Code
      gllvmTMB:::desugar_brms_sugar(value ~ 0 + trait + indep(1 + x | site))
    Condition
      Error in `.assert_no_augmented_lhs()`:
      ! `indep()` augmented LHS is not yet supported.
      i You wrote `indep(1 + x | site)`.
      x This wrapper accepts only intercept-only `0 + trait | g` or `1 | g` forms.
      > Use `latent(1 + x | site, d = K)` or `unique(1 + x | site)` instead -- `indep()` itself does not support a slope term.

# phylo_indep(0 + trait + trait:x | trait) redirects to the response-column slope grammar

    Code
      gllvmTMB:::desugar_brms_sugar(value ~ 0 + trait + phylo_indep(0 + trait + trait:
        x | trait))
    Condition
      Error in `rewrite()`:
      ! `phylo_indep()` LHS richer than `0 + trait` is not yet supported.
      i Got LHS: `0 + trait + trait:x`.
      > Use the response-column slope grammar instead: `slope()`, `phylo_slope()`, or `animal_slope()`, e.g. `phylo_slope(x | trait, tree = tree)`.

# phylo_indep(0 + trait + trait:x | species) redirects to the group-axis slope grammar

    Code
      gllvmTMB:::desugar_brms_sugar(value ~ 0 + trait + phylo_indep(0 + trait + trait:
        x | species))
    Condition
      Error in `rewrite()`:
      ! `phylo_indep()` LHS richer than `0 + trait` is not yet supported.
      i Got LHS: `0 + trait + trait:x`.
      > Use the group-axis slope grammar instead, e.g. `phylo_slope(x | species, tree = tree)`; `phylo_indep(0 + trait | species)` remains the per-trait phylogenetic variance fit.

# a grouping column value-identical to trait aborts naming the fixed/random collision

    Code
      gllvmTMB::gllvmTMB(value ~ 0 + trait + latent(0 + trait | trait_copy, d = 1),
      data = df, unit = "site")
    Condition
      Error in `gllvmTMB::gllvmTMB()`:
      ! A random-effect grouping column is identical to `trait = "trait"`.
      i trait_copy takes exactly the same values as `trait`, so its random effect collides with the fixed per-trait intercepts.
      > Use the response-column slope grammar instead (e.g. `slope(x | trait)`, `phylo_slope(x | trait, tree = tree)`), or group by a different column.

