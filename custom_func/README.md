# Density Analysis Helpers

**Scope: this file documents the density/DPS helpers only.** `custom_func/` holds the shared
helpers sourced across the analyses; the two documented below are the trajectory-analysis core.
The rest are unrelated and are **not** covered here: DMP selection (`select_sig_cg.R`,
`select_top_cg.R`, `build_dmp_long_effect_size.R`), GO categorisation
(`assign_biofunc_category.R`), the publication theme (`theme_main_fig.R` — the most-sourced
helper in the directory), the supplementary-data Excel builders, and the two number formatters.
The sibling density helpers `plot_density_evolution.R`, `find_contour_center.R`,
`make_faceted_scatter_and_contour_plot.R` and `compute_spatial_dps.R` are also undocumented here.

**To find where a helper is used:** `git grep -n "custom_func/<file>"`.

One caveat that bites: `theme_main_fig.R`'s `rescale_layer_params(size_scale = 0.6)`
must **not** be applied to the `stable_mci_focused/` plots — they are already authored at
`size = 6 / .pt` (6 pt, the journal floor) and would shrink to ~3.6 pt.

## Files

### `find_highest_density_points.R`
The main function file containing:
- `find_highest_density_points()`: Core function for identifying high-density regions
- `summarize_density_results()`: Helper function for generating summary statistics

### `example_density_analysis.R`
Comprehensive examples and workflows demonstrating function usage, including:
- Basic usage examples
- Custom parameter configurations
- Multi-dimensional analysis
- Visualization functions
- Complete workflow functions

## Function Overview

### `find_highest_density_points()`

**Purpose**: Identifies regions of highest density in 2D space for different categories using kernel density estimation (KDE).

**Key Features**:
- Flexible parameter configuration
- Multiple bandwidth selection methods
- Robust input validation
- Comprehensive error handling
- Detailed metadata preservation

**Parameters**:
- `.data`: Input data frame
- `dim_cols`: Column names for x/y dimensions (default: c("PCA1", "PCA2"))
- `category_col`: Grouping variable column (default: "demcat")
- `density_threshold`: Quantile threshold for high-density regions (default: 0.9)
- `grid_resolution`: KDE grid resolution (default: 200)
- `bandwidth`: Bandwidth selection method (default: "auto")
- `min_points`: Minimum points required per category (default: 10)

**Returns**: A tibble with high-density point coordinates, density values, and metadata.

### `summarize_density_results()`

**Purpose**: Generates summary statistics from density analysis results.

**Returns**: Summary statistics including centroids, ranges, and efficiency metrics.

## Usage Examples

### Basic Usage
```r
# Source the function
source("custom_func/find_highest_density_points.R")

# Basic analysis
results <- find_highest_density_points(data, c("ae_1", "ae_2"))

# Generate summary
summary_stats <- summarize_density_results(results)
```

### Custom Parameters
```r
# High-resolution analysis with strict threshold
results <- find_highest_density_points(
  data,
  dim_cols = c("ae_1", "ae_2"),
  density_threshold = 0.95,  # Top 5%
  grid_resolution = 300,     # Higher resolution
  bandwidth = "SJ"           # Sheather-Jones bandwidth
)
```

### Complete Workflow
```r
# Source examples
source("custom_func/example_density_analysis.R")

# Run complete analysis
analysis <- run_complete_density_analysis(threshold = 7, dims = c("ae_1", "ae_2"))

# Access results
density_points <- analysis$density_results
summary_stats <- analysis$summary_stats
plots <- analysis$plots
```

## Integration with Existing Workflow

The function is designed to integrate seamlessly with your current trajectory analysis workflow:

```r
# Your existing pattern
ae_cv_ensemble_all$threshold_7$best_ensemble |> 
  with(
    as_tibble(coordinates) %>%
      set_names(glue("ae_{1:6}")) %>%
      mutate(
        subject_ids = subject_ids,
        demcat = trajectory_labels,
        .before = 1
      )
  ) |> 
  find_highest_density_points(c("ae_1", "ae_2")) |> 
  summarise(
    n_high_density_points = n(),
    x_mean = mean(x_highest_densities),
    y_mean = mean(y_highest_densities),
    x_median = median(x_highest_densities),
    y_median = median(y_highest_densities),
    .by = demcat
  )
```

## Bandwidth Selection Methods

The function supports various bandwidth selection methods:
- `"auto"`: MASS::kde2d default
- `"nrd0"`, `"nrd"`: Normal reference distributions
- `"ucv"`, `"bcv"`: Cross-validation methods
- `"SJ"`: Sheather-Jones method
- Numeric vector: Manual specification c(h_x, h_y)

## Error Handling

The function includes comprehensive validation for:
- Input data format and completeness
- Column existence
- Parameter ranges
- Minimum data requirements
- Package dependencies

## Performance Considerations

- Higher `grid_resolution` increases accuracy but computation time
- More complex bandwidth methods (e.g., "SJ") are slower but potentially more accurate
- Large datasets may benefit from reduced `grid_resolution` or simplified bandwidth methods

## Dependencies

Required packages:
- `MASS` (for kde2d)
- `dplyr`
- `purrr`
- `tibble`

Optional packages (for examples):
- `ggplot2`
- `glue`