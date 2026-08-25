# legacy non-trait phylo and animal slopes retain their scalar route

    Code
      list(use_phylo_slope = phy$tmb_data$use_phylo_slope, use_phylo_column_slope = phy$
        tmb_data$use_phylo_column_slope, use_phylo_slope_correlated = phy$tmb_data$
        use_phylo_slope_correlated, parameter_names = names(phy$opt$par), random = phy$
        random)
    Output
      $use_phylo_slope
      [1] 1
      
      $use_phylo_column_slope
      [1] 0
      
      $use_phylo_slope_correlated
      [1] 0
      
      $parameter_names
      [1] "b_fix"           "b_fix"           "b_fix"           "log_sigma_eps"  
      [5] "log_sigma_slope"
      
      $random
      [1] "b_phy_slope"
      

