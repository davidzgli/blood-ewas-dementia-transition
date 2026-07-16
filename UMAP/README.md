# UMAP Analysis

## Directory Structure

`lite/` is the manuscript pipeline.

| Directory | Description |
|-----------|-------------|
| `lite/` | Computes 6-component UMAP embeddings (n_neighbors=10, min_dist=0.5, seed-averaged over 5 seeds) at thresholds 8 and 7, then derives latent-coordinate boxplots, DPS, permutation tests, and scatter/contour plots |

`path2d_dps_explanation.md` stays at this level: it documents `custom_func/compute_spatial_dps.R`,
which both `UMAP/lite/DPS/02_dps_path2d.qmd` and `UMAP/lite/permutation/01_permutation_dps.qmd`
use (as do their `VAE/lite/` counterparts).

## Pipeline (`lite/`)

`lite/01_umap_embedding.qmd` computes the embeddings and writes
`lite/output/embedding_threshold_{7,8}.rds`. Its only external inputs are
`data/collaborator_only/adjusted_meth/adjusted_methylation_scaled_nlog10p_gte_{threshold}.rds`,
which require a Data Use Agreement (see the top-level README). The embedding step itself sources
nothing from `custom_func/` — only the downstream DPS and permutation steps do.

Downstream steps consume that embedding:

- `lite/latent_coordinates/` — boxplots and ANOVA across dementia categories
- `lite/DPS/` — density peaks, dementia progression score (Path2D)
- `lite/permutation/` — label-permutation null distributions for DPS
- `lite/scatter/` — faceted scatter and contour plots

### Data Flow

```
data/collaborator_only/adjusted_meth/*.rds
            |
    lite/01_umap_embedding.qmd
    writes -> lite/output/embedding_threshold_{7,8}.rds
            |
    +-------+-------+--------+
    |       |       |        |
latent_   DPS/   permu-   scatter/
coords/          tation/
            |
    VAE_UMAP_comb/patch_figures/  -> ms/fig_tbl/ floats
```

Figure composition happens in `VAE_UMAP_comb/patch_figures/`, not in this directory.
`lite/output/` is also read directly by `APOE/*.qmd`.

## Reproducibility note

The `n_neighbors=10, min_dist=0.5` configuration was selected as the best Path2D DPS
configuration by a parameter sweep. The sweep itself is not part of this release.

UMAP dimension indices (`umap_N`) are **not** comparable across runs with different parameters or
seeds: a different fit yields the same structure on a different basis.
