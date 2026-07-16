# VAE Analysis

## Directory Structure

`lite/` is the manuscript pipeline.

| Directory | Description |
|-----------|-------------|
| `lite/` | Trains a 6-dimensional VAE (beta=0.001, 5-fold CV, average ensemble) at thresholds 8 and 7, then derives latent-coordinate boxplots, DPS, permutation tests, and scatter/contour plots |

## Pipeline (`lite/`)

`lite/01_vae_embedding.qmd` trains the VAE and writes `lite/output/embedding_threshold_{7,8}.rds`.
Its only external input is
`data/collaborator_only/adjusted_meth/adjusted_methylation_scaled_nlog10p_gte_{threshold}.rds`,
which requires a Data Use Agreement (see the top-level README). This step needs Python and
TensorFlow; see "Python / TensorFlow" in the top-level README. The embedding step itself sources
nothing from `custom_func/`; the downstream DPS, scatter and permutation steps do.

Downstream steps consume that embedding:

- `lite/latent_coordinates/` — boxplots and ANOVA across dementia categories
- `lite/DPS/` — density peaks, dementia progression score
- `lite/permutation/` — label-permutation null distributions for DPS
- `lite/scatter/` — faceted scatter and contour plots
- `lite/VAE_graph/` — architecture and cross-validation diagrams

### Data Flow

```
data/collaborator_only/adjusted_meth/*.rds
            |
    lite/01_vae_embedding.qmd
    writes -> lite/output/embedding_threshold_{7,8}.rds
            |
    +-------+-------+-------+--------+
    |       |       |       |        |
latent_   DPS/   permu-  scatter/  VAE_graph/
coords/          tation/
            |
    VAE_UMAP_comb/patch_figures/  -> ms/fig_tbl/ floats
```

Figure composition happens in `VAE_UMAP_comb/patch_figures/`, not in this directory.

## Reproducibility note

The VAE fixes its seeds and calls `enable_op_determinism()`, so re-running on the same hardware
reproduces the fit bit-for-bit. A different GPU, CUDA, or TensorFlow build — or a CPU run — does
**not**: it yields the same latent structure on a different basis. `vae_N` therefore does not
denote the same axis across training runs, so never compare dimension indices, rankings, or
p-values between one fit and another.
