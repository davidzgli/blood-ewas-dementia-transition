## Function for building the long-format DMP effect-size table

# Build the long-format DMP effect-size table from the genome-wide significant
# (p < 1e-8) CpG set, reproducing the legacy `DMP_long_effect_size.rds`.
#
# CpGs are ranked by their mean -log10(p value) across dementia categories. The
# wide effect-size columns are kept (one per category) and also pivoted to a
# long `demcat`/`es` pair. `stable_mci_grp` flags "outlier" sites with a
# strongly negative stable-MCI effect size.

build_dmp_long_effect_size <- function(sig_cg) {
  demcats <- c("stable_mci", "normal2mci", "normal2incid", "mci2incid", "prev")

  wide_part <-
    sig_cg |>
    arrange(desc(rowMeans(pick(starts_with("nlog10_p_value_"))))) |>
    mutate(rank = row_number()) |>
    select(rank, cg, starts_with("estimate_")) |>
    rename_with(~ str_remove(.x, "^estimate_"), starts_with("estimate_")) |>
    mutate(stable_mci_grp = if_else(stable_mci < -0.2, "outlier", "main"))

  wide_part |>
    left_join(
      wide_part |>
        pivot_longer(all_of(demcats), names_to = "demcat", values_to = "es") |>
        select(cg, demcat, es),
      by = "cg"
    )
}
