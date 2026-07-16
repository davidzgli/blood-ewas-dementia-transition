# Example Usage of find_highest_density_points Function
# This script demonstrates various ways to use the density analysis function

# Load required libraries
library(dplyr)
library(ggplot2)
library(purrr)
library(tibble)
library(MASS)

# Source the function
source("custom_func/find_highest_density_points.R")

# Example 1: Basic usage with the current workflow
example_basic_usage <- function() {
  # Using your existing data structure
  result <- ae_cv_ensemble_all$threshold_7$best_ensemble |> 
    with(
      as_tibble(coordinates) %>%
        set_names(glue::glue("ae_{1:6}")) %>%
        mutate(
          subject_ids = subject_ids,
          demcat = trajectory_labels,
          .before = 1
        )
    ) |> 
    find_highest_density_points(c("ae_1", "ae_2"))
  
  return(result)
}

# Example 2: Custom parameters
example_custom_parameters <- function() {
  # Using higher threshold and different bandwidth
  result <- ae_cv_ensemble_all$threshold_7$best_ensemble |> 
    with(
      as_tibble(coordinates) %>%
        set_names(glue::glue("ae_{1:6}")) %>%
        mutate(
          subject_ids = subject_ids,
          demcat = trajectory_labels,
          .before = 1
        )
    ) |> 
    find_highest_density_points(
      dim_cols = c("ae_1", "ae_2"),
      density_threshold = 0.95,  # Top 5% instead of 10%
      grid_resolution = 300,     # Higher resolution
      bandwidth = "SJ"           # Sheather-Jones bandwidth
    )
  
  return(result)
}

# Example 3: Analysis with different dimensions
example_different_dimensions <- function() {
  # Analyze different autoencoder dimensions
  results <- map(
    list(
      c("ae_1", "ae_2"),
      c("ae_3", "ae_4"),
      c("ae_5", "ae_6")
    ),
    function(dims) {
      ae_cv_ensemble_all$threshold_7$best_ensemble |> 
        with(
          as_tibble(coordinates) %>%
            set_names(glue::glue("ae_{1:6}")) %>%
            mutate(
              subject_ids = subject_ids,
              demcat = trajectory_labels,
              .before = 1
            )
        ) |> 
        find_highest_density_points(dims) |>
        mutate(dimension_pair = paste(dims, collapse = "_"))
    }
  ) |>
    list_rbind()
  
  return(results)
}

# Example 4: Generate summary statistics
example_summary_analysis <- function() {
  # Get density results
  density_results <- example_basic_usage()
  
  # Generate summary
  summary_stats <- summarize_density_results(density_results)
  
  # Create detailed analysis
  analysis_summary <- density_results |>
    group_by(demcat) |>
    summarise(
      n_high_density_points = n(),
      x_mean = mean(x_highest_densities),
      y_mean = mean(y_highest_densities),
      x_median = median(x_highest_densities),
      y_median = median(y_highest_densities),
      density_mean = mean(density_value),
      density_max = max(density_value),
      .groups = "drop"
    ) |>
    mutate(group = "trajectory_evolution")
  
  return(list(
    density_results = density_results,
    summary_stats = summary_stats,
    analysis_summary = analysis_summary
  ))
}

# Example 5: Visualization function
plot_density_regions <- function(original_data, density_results, dim_cols) {
  # Base scatter plot of original data
  p1 <- original_data |>
    ggplot(aes(x = !!sym(dim_cols[1]), y = !!sym(dim_cols[2]), color = demcat)) +
    geom_point(alpha = 0.6, size = 1) +
    scale_color_viridis_d() +
    labs(title = "Original Data Distribution") +
    theme_minimal()
  
  # Overlay high-density regions
  p2 <- p1 +
    geom_point(
      data = density_results,
      aes(x = x_highest_densities, y = y_highest_densities, color = demcat),
      size = 0.8,
      alpha = 0.8,
      shape = 17  # triangles for high-density points
    ) +
    labs(title = "High-Density Regions Overlay",
         subtitle = "Triangles indicate highest density regions")
  
  return(list(original = p1, overlay = p2))
}

# Example workflow function
run_complete_density_analysis <- function(threshold = 7, dims = c("ae_1", "ae_2")) {
  cat("Running complete density analysis workflow...\n")
  
  # Prepare data
  data <- ae_cv_ensemble_all[[paste0("threshold_", threshold)]]$best_ensemble |> 
    with(
      as_tibble(coordinates) %>%
        set_names(glue::glue("ae_{1:6}")) %>%
        mutate(
          subject_ids = subject_ids,
          demcat = trajectory_labels,
          .before = 1
        )
    )
  
  # Run density analysis
  density_results <- find_highest_density_points(
    data, 
    dim_cols = dims,
    density_threshold = 0.9,
    grid_resolution = 200
  )
  
  # Generate summary
  summary_stats <- summarize_density_results(density_results)
  
  # Create visualizations
  plots <- plot_density_regions(data, density_results, dims)
  
  # Print summary information
  cat("Analysis completed successfully!\n")
  cat("Dimensions analyzed:", paste(dims, collapse = " x "), "\n")
  cat("Categories processed:", length(unique(density_results$demcat)), "\n")
  cat("Total high-density points found:", nrow(density_results), "\n")
  
  return(list(
    data = data,
    density_results = density_results,
    summary_stats = summary_stats,
    plots = plots,
    parameters = attr(density_results, "parameters")
  ))
}

# Print usage instructions
cat("Density Analysis Functions Loaded!\n")
cat("Available functions:\n")
cat("- find_highest_density_points(): Main analysis function\n")
cat("- summarize_density_results(): Generate summary statistics\n")
cat("- example_basic_usage(): Basic example with current data\n")
cat("- example_custom_parameters(): Example with custom settings\n")
cat("- run_complete_density_analysis(): Complete workflow function\n")
cat("\nExample usage:\n")
cat("results <- run_complete_density_analysis(threshold = 7, dims = c('ae_1', 'ae_2'))\n")