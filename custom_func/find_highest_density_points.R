#' Find Highest Density Points in 2D Space
#'
#' This function identifies regions of highest density in a 2D space for different 
#' categories using kernel density estimation (KDE). It computes 2D density surfaces
#' for each category and returns points that fall within the highest density regions.
#'
#' @param .data A data frame containing the data points to analyze
#' @param dim_cols A character vector of length 2 specifying the column names 
#'   for the x and y dimensions. Default: c("PCA1", "PCA2")
#' @param category_col A character string specifying the column name that contains
#'   the categorical grouping variable. Default: "demcat"
#' @param density_threshold A numeric value between 0 and 1 specifying the quantile
#'   threshold for identifying high-density regions. Default: 0.9 (90th percentile)
#' @param grid_resolution An integer specifying the resolution of the density grid.
#'   Higher values provide more detailed density estimates but increase computation time.
#'   Default: 200
#' @param bandwidth A character string or numeric vector specifying the bandwidth
#'   for KDE. Options: "auto" (uses MASS::kde2d default), "nrd0", "nrd", "ucv", "bcv", "SJ",
#'   or a numeric vector of length 2 for manual bandwidth specification. Default: "auto"
#' @param min_points An integer specifying the minimum number of points required
#'   in a category to perform density estimation. Categories with fewer points
#'   will be skipped. Default: 10
#'
#' @return A tibble containing the highest density points with columns:
#'   \item{category_col}{The category/group identifier}
#'   \item{x_highest_densities}{X coordinates of highest density points}
#'   \item{y_highest_densities}{Y coordinates of highest density points}
#'   \item{density_value}{The density value at each point}
#'   \item{n_points_in_category}{Number of original points in each category}
#'   \item{n_high_density_points}{Number of high-density grid points found}
#'
#' @details
#' The function performs the following steps:
#' 1. Splits the input data by the specified categorical variable
#' 2. For each category, computes a 2D kernel density estimate using MASS::kde2d
#' 3. Identifies grid points where density exceeds the specified threshold
#' 4. Returns coordinates and metadata for these high-density regions
#'
#' The bandwidth parameter controls the smoothness of the density estimate:
#' - "auto": Uses MASS::kde2d default bandwidth selection
#' - "nrd0", "nrd", "ucv", "bcv", "SJ": Uses stats::bw.nrd0(), bw.nrd(), etc.
#' - Numeric vector: Manual bandwidth specification c(h_x, h_y)
#'
#' @examples
#' \dontrun{
#' # Basic usage with default parameters
#' high_density <- find_highest_density_points(data, c("PC1", "PC2"))
#'
#' # Custom threshold and resolution
#' high_density <- find_highest_density_points(
#'   data, 
#'   dim_cols = c("ae_1", "ae_2"),
#'   density_threshold = 0.95,
#'   grid_resolution = 300
#' )
#'
#' # Custom bandwidth selection
#' high_density <- find_highest_density_points(
#'   data,
#'   dim_cols = c("UMAP1", "UMAP2"),
#'   bandwidth = "SJ",
#'   category_col = "cluster"
#' )
#' }
#'
#' @author Generated for trajectory analysis workflow
#' @export
find_highest_density_points <- function(.data,
                                      dim_cols = c("PCA1", "PCA2"),
                                      category_col = "demcat",
                                      density_threshold = 0.9,
                                      grid_resolution = 200,
                                      bandwidth = "auto",
                                      min_points = 10) {
  
  # Input validation
  if (!is.data.frame(.data)) {
    stop("Input '.data' must be a data frame")
  }
  
  if (length(dim_cols) != 2) {
    stop("'dim_cols' must be a character vector of length 2")
  }
  
  if (!all(dim_cols %in% names(.data))) {
    missing_cols <- setdiff(dim_cols, names(.data))
    stop("Column(s) not found in data: ", paste(missing_cols, collapse = ", "))
  }
  
  if (!category_col %in% names(.data)) {
    stop("Category column '", category_col, "' not found in data")
  }
  
  if (!is.numeric(density_threshold) || density_threshold < 0 || density_threshold > 1) {
    stop("'density_threshold' must be a numeric value between 0 and 1")
  }
  
  if (!is.numeric(grid_resolution) || grid_resolution < 10) {
    stop("'grid_resolution' must be a numeric value >= 10")
  }
  
  if (!is.numeric(min_points) || min_points < 1) {
    stop("'min_points' must be a positive integer")
  }
  
  # Check for required packages
  if (!requireNamespace("MASS", quietly = TRUE)) {
    stop("Package 'MASS' is required but not installed")
  }
  
  # Remove rows with missing values in the specified columns
  complete_data <- .data[complete.cases(.data[c(dim_cols, category_col)]), ]
  
  if (nrow(complete_data) == 0) {
    stop("No complete cases found for the specified columns")
  }
  
  # Issue warning if data was removed
  n_removed <- nrow(.data) - nrow(complete_data)
  if (n_removed > 0) {
    warning("Removed ", n_removed, " rows with missing values")
  }
  
  # Split data by category
  split_data <- complete_data |>
    split(complete_data[[category_col]])
  
  # Filter categories with sufficient points
  sufficient_data <- split_data[sapply(split_data, nrow) >= min_points]
  
  # Warn about filtered categories
  filtered_categories <- names(split_data)[!names(split_data) %in% names(sufficient_data)]
  if (length(filtered_categories) > 0) {
    warning("Skipped categories with < ", min_points, " points: ", 
            paste(filtered_categories, collapse = ", "))
  }
  
  if (length(sufficient_data) == 0) {
    stop("No categories have sufficient points (>= ", min_points, ") for density estimation")
  }
  
  # Helper function to calculate bandwidth
  calculate_bandwidth <- function(x, y, method) {
    if (is.numeric(method)) {
      if (length(method) == 1) {
        return(c(method, method))
      } else if (length(method) == 2) {
        return(method)
      } else {
        stop("Numeric bandwidth must be of length 1 or 2")
      }
    }
    
    switch(method,
           "auto" = NULL,  # Let MASS::kde2d handle it
           "nrd0" = c(bw.nrd0(x), bw.nrd0(y)),
           "nrd" = c(bw.nrd(x), bw.nrd(y)),
           "ucv" = c(bw.ucv(x), bw.ucv(y)),
           "bcv" = c(bw.bcv(x), bw.bcv(y)),
           "SJ" = c(bw.SJ(x), bw.SJ(y)),
           stop("Unsupported bandwidth method: ", method))
  }
  
  # Compute density data for each category
  density_results <- sufficient_data |>
    purrr::imap(function(category_data, category_name) {
      
      x_vals <- category_data[[dim_cols[1]]]
      y_vals <- category_data[[dim_cols[2]]]
      
      # Calculate bandwidth
      bw <- calculate_bandwidth(x_vals, y_vals, bandwidth)
      
      # Compute 2D KDE
      if (is.null(bw)) {
        kde_result <- MASS::kde2d(x_vals, y_vals, n = grid_resolution)
      } else {
        kde_result <- MASS::kde2d(x_vals, y_vals, n = grid_resolution, h = bw)
      }
      
      # Find high-density indices
      density_threshold_value <- quantile(kde_result$z, probs = density_threshold)
      high_density_indices <- which(kde_result$z >= density_threshold_value, arr.ind = TRUE)
      
      if (nrow(high_density_indices) == 0) {
        warning("No high-density points found for category: ", category_name)
        return(tibble::tibble(
          !!category_col := character(0),
          x_highest_densities = numeric(0),
          y_highest_densities = numeric(0),
          density_value = numeric(0),
          n_points_in_category = integer(0),
          n_high_density_points = integer(0)
        ))
      }
      
      # Extract coordinates and density values
      row_indices <- high_density_indices[, "row"]
      col_indices <- high_density_indices[, "col"]
      
      result_data <- tibble::tibble(
        !!category_col := category_name,
        x_highest_densities = kde_result$x[row_indices],
        y_highest_densities = kde_result$y[col_indices],
        density_value = kde_result$z[high_density_indices],
        n_points_in_category = nrow(category_data),
        n_high_density_points = length(row_indices)
      )
      
      return(result_data)
    })
  
  # Combine results
  final_result <- density_results |>
    purrr::list_rbind()
  
  # Add metadata as attributes
  attr(final_result, "parameters") <- list(
    dim_cols = dim_cols,
    category_col = category_col,
    density_threshold = density_threshold,
    grid_resolution = grid_resolution,
    bandwidth = bandwidth,
    min_points = min_points,
    n_categories_processed = length(sufficient_data),
    n_categories_skipped = length(filtered_categories),
    total_input_points = nrow(.data),
    total_complete_points = nrow(complete_data)
  )
  
  return(final_result)
}

# Helper function to summarize density results
#' Summarize Density Analysis Results
#'
#' @param density_results Output from find_highest_density_points()
#' @return A summary tibble with key metrics per category
#' @export
summarize_density_results <- function(density_results) {
  params <- attr(density_results, "parameters")
  
  summary_stats <- density_results |>
    dplyr::group_by(!!dplyr::sym(params$category_col)) |>
    dplyr::summarise(
      n_high_density_points = dplyr::n(),
      mean_density = mean(density_value, na.rm = TRUE),
      max_density = max(density_value, na.rm = TRUE),
      x_centroid = mean(x_highest_densities, na.rm = TRUE),
      y_centroid = mean(y_highest_densities, na.rm = TRUE),
      x_range = max(x_highest_densities, na.rm = TRUE) - min(x_highest_densities, na.rm = TRUE),
      y_range = max(y_highest_densities, na.rm = TRUE) - min(y_highest_densities, na.rm = TRUE),
      n_points_in_category = dplyr::first(n_points_in_category),
      .groups = "drop"
    ) |>
    dplyr::mutate(
      density_efficiency = n_high_density_points / n_points_in_category,
      spread_metric = sqrt(x_range^2 + y_range^2)
    )
  
  return(summary_stats)
}