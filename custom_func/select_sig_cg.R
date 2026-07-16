


## Function for selecting cg sites
# label: func-select-sig-cg

# Create a function to select significant CpG sites based on the p value cutoff.

# Make the function
select_sig_cg <- function(asso, sig_cutoff) {
  # Filter the significant CpG sites
  dmp_sig <- asso |>
    # Calculate the number of dementia category for each CpG site
    mutate(n_sig = rowSums(pick(starts_with("nlog10_p_value_")) >= sig_cutoff)) |>
    # Only keep the CpG sites that are significant for at least one dementia category
    dplyr::filter(n_sig > 0)
  
  return(dmp_sig)
}

# Test the function
#select_sig_cg(asso, 6) |> 
#  glimpse() 


