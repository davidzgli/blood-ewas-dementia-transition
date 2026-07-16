# Cross-method Analysis (VAE + UMAP)

This directory compares the VAE and UMAP latent spaces and composes most of the figures the
manuscript embeds. All eight `.qmd` here are rendered by `render.sh`, which
`manage_project/render_manuscript.sh` invokes.

## Structure

```
01_dimension_anova.qmd          \
02_dps_visualization.qmd         >  read VAE/lite/ + UMAP/lite/  ->  output/*.rds + *.png
03_permutation_visualization.qmd/
                                          |
patch_figures/{01a,01b,02a,02b,02c}_*.qmd  reads output/*.rds + the lite fig_tbl objects
                                          |
                                  patch_figures/output/*.png  ->  ms/fig_tbl/ floats
```

Inputs come only from `VAE/lite/`, `UMAP/lite/`, and `custom_func/theme_main_fig.R`.
Only the `.qmd` and `render.sh` are tracked; every `.png`, `.rds`, and `.html` is gitignored.

## Which outputs are actually used

**`patch_figures/output/` — 14 PNGs are manuscript floats.** `fig_vae_boxplots.png` and
`fig_scatter_peak.png` are Figures 2 and 3 (`ms/fig_tbl/main_figures.qmd:22,28`); the twelve
`fig_suppl_*` files listed in `ms/fig_tbl/supplementary_figures.qmd:59-125` are supplementary
figures.

**Five PNGs here are regenerated dead ends — not used by any manuscript float:**

- `fig_suppl_anova_heatmap.png`
- `fig_suppl_dps_line.png`
- `fig_suppl_umap_scatter_t7.png`
- `fig_suppl_vae_scatter_t7.png`
- `fig_suppl_vae_scatter_t8_part2.png` (note the *UMAP* `_part2` **is** used; the VAE one is not)

They are still written on every render by `02a`/`02b`. Do not assume a file in this directory is
a figure just because it is named `fig_suppl_*`.

**Three `.rds` in `output/` are read by the patch step** — `fig_anova_heatmap.rds` (by `02a`),
`fig_dps_line.rds` (`02b`), `fig_perm_pvalue_heatmap.rds` (`02c`).
The remaining `.rds` (`anova_all`, `dps_all`, `pvalues_all`, `fig_anova_barplot`,
`fig_anova_lineplot`, `fig_dps_bar`, `fig_dps_heatmap`, `fig_perm_null_hist`,
`fig_perm_summary_boxplot`) are write-only: nothing in the repository reads them. Figure 2 lost
its ANOVA lineplot panel during revision, so `01a_patch_main_boxplots.qmd` now reads only the two
`lite` `boxplot_list_threshold_8.rds` objects plus `custom_func/theme_main_fig.R` — verify with
`grep -n "read_rds\|source(" patch_figures/01a_patch_main_boxplots.qmd`.

## Provenance of the figure numbers

The p-values printed on the boxplot panels are baked into the saved plot objects, not recomputed
at composition time. To read the authoritative values behind Figure 2, load
`VAE/lite/latent_coordinates/output/fig_tbl/boxplot_list_threshold_8.rds` and inspect
`p$layers[[2]]$data`. The corresponding UMAP objects live under `UMAP/lite/latent_coordinates/`.

Latent dimension indices are **not** comparable across training runs — see `VAE/README.md`.
