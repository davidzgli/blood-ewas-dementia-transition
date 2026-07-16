## Function for selecting the top CpG sites of a dementia category

# Select the top `n` CpG sites for one dementia category, ranked by its
# -log10(p value). Operates on the annotated association table
# (`annotated_asso_wide.rds`) and returns the same columns as the legacy
# `{demcat}_top{n}.rds` files.

select_top_cg <- function(annot, demcat, n) {
  annot |>
    arrange(desc(.data[[glue("nlog10_p_value_{demcat}")]])) |>
    dplyr::slice(1:n)
}
