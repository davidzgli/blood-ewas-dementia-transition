#' Find Contour Center Using ggdensity HDR
#'
#' Uses ggdensity's get_hdr() to compute a stable center for each category by
#' averaging all grid points within a high-density region. Returns one row per
#' category with x_mean/y_mean columns for compatibility with plot_density_evolution().
#'
#' This function provides more stable center detection compared to using a single
#' maximum density point, which can be sensitive to noise. By averaging all points
#' within the innermost HDR contour (controlled by center_prob), the center
#' represents a robust estimate of the density mode region.
#'
#' @param .data Data frame with x/y coordinates
#' @param dim_cols Character vector of length 2 for x/y column names.
#'   Default: c("PCA1", "PCA2")
#' @param category_col Column name for categorical grouping. Default: "demcat"
#' @param method Density estimation method for get_hdr(). Options include "kde"
#'   (kernel density estimation), "mvnorm" (multivariate normal), "mvnorm_mle",
#'   "histogram", "freqpoly". Default: "kde"
#' @param probs HDR probability levels used by get_hdr().
#'   Default: c(0.2, 0.5, 0.8, 0.95)
#' @param center_prob HDR probability level for selecting points to compute center.
#'   Points with hdr <= center_prob are included. Lower values select smaller,
#'   denser regions. Default: 0.2 (innermost 20% HDR region)
#' @param grid_resolution Grid resolution for density estimation (n parameter for
#'   get_hdr). Default: 100
#' @param min_points Minimum points per category required to perform density
#'   estimation. Categories with fewer points will be skipped. Default: 10
#'
#' @return Tibble with one row per category containing:
#'   \item{category_col}{Category identifier (column named as per category_col argument)}
#'   \item{x_mean}{X coordinate of HDR region center (mean of points in HDR)}
#'   \item{y_mean}{Y coordinate of HDR region center (mean of points in HDR)}
#'   \item{mean_density}{Mean density value of points in HDR region}
#'   \item{n_hdr_points}{Number of grid points within the HDR region}
#'   \item{n_points_in_category}{Point count in original data}
#'   \item{group}{"trajectory_evolution" for compatibility with plot_density_evolution()}
#'
#' @details
#' The function performs the following steps:
#' 1. Splits the input data by the specified categorical variable
#' 2. For each category, prepares data with columns named x and y (required by ggdensity)
#' 3. Computes HDR using ggdensity::get_hdr()
#' 4. Selects all grid points within the specified HDR probability level (hdr <= center_prob)
#' 5. Computes the mean x and y coordinates of those points as the center
#' 6. Returns a tibble with one row per category containing center coordinates
#'
#' This approach provides a more stable center estimate compared to using the
#' single maximum density point, especially when the density surface has multiple
#' local maxima or is noisy.
#'
#' @examples
#' \dontrun{
#' # Basic usage
#' contour_centers <- find_contour_center(data, dim_cols = c("vae_1", "vae_2"))
#'
#' # Custom configuration with tighter HDR region for center
#' contour_centers <- find_contour_center(
#'   data,
#'   dim_cols = c("PCA1", "PCA2"),
#'   category_col = "cluster",
#'   method = "kde",
#'   center_prob = 0.1,
#'   grid_resolution = 150
#' )
#'
#' # Use directly with plot_density_evolution()
#' contour_centers |>
#'   plot_density_evolution(dim_cols = c("vae_1", "vae_2"), statistic = "mean")
#' }
#'
#' @author Generated for trajectory analysis workflow
#' @seealso \code{\link[ggdensity]{get_hdr}} for underlying HDR computation
#' @export
find_contour_center <- function(.data,
                                dim_cols = c("PCA1", "PCA2"),
                                category_col = "demcat",
                                method = "kde",
                                probs = c(0.2, 0.5, 0.8, 0.95),
                                center_prob = 0.2,
                                grid_resolution = 100,
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

  if (!is.numeric(grid_resolution) || grid_resolution < 10) {
    stop("'grid_resolution' must be a numeric value >= 10")
  }

  if (!is.numeric(min_points) || min_points < 1) {
    stop("'min_points' must be a positive integer")
  }

  if (!is.numeric(center_prob) || center_prob <= 0 || center_prob > 1) {
    stop("'center_prob' must be a numeric value between 0 (exclusive) and 1 (inclusive)")
  }

  # Ensure center_prob is included in probs for HDR computation
  if (!center_prob %in% probs) {
    probs <- sort(unique(c(center_prob, probs)))
  }

  # Check for required packages
  if (!requireNamespace("ggdensity", quietly = TRUE)) {
    stop("Package 'ggdensity' is required but not installed")
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

  # Compute contour center for each category
  center_results <- sufficient_data |>
    purrr::imap(function(category_data, category_name) {

      # Prepare data with x, y columns as required by ggdensity::get_hdr()
      prep_data <- tibble::tibble(
        x = category_data[[dim_cols[1]]],
        y = category_data[[dim_cols[2]]]
      )

      # Compute HDR using ggdensity
      hdr_result <- tryCatch({
        ggdensity::get_hdr(prep_data, method = method, probs = probs, n = grid_resolution)
      }, error = function(e) {
        warning("HDR computation failed for category '", category_name, "': ", e$message)
        return(NULL)
      })

      if (is.null(hdr_result)) {
        return(tibble::tibble(
          !!category_col := character(0),
          x_mean = numeric(0),
          y_mean = numeric(0),
          mean_density = numeric(0),
          n_hdr_points = integer(0),
          n_points_in_category = integer(0),
          group = character(0)
        ))
      }

      # Select points within the specified HDR probability level
      # Points with hdr <= center_prob are in the densest region
      hdr_points <- hdr_result$df_est |>
        dplyr::filter(hdr <= center_prob)

      # Fallback to single peak if no points found in HDR region
      if (nrow(hdr_points) == 0) {
        warning("No points found in HDR region for category '", category_name,
                "'. Using single maximum density point.")
        peak_idx <- which.max(hdr_result$df_est$fhat)
        hdr_points <- hdr_result$df_est[peak_idx, , drop = FALSE]
      }

      # Compute center as mean of HDR region points
      tibble::tibble(
        !!category_col := category_name,
        x_mean = mean(hdr_points$x),
        y_mean = mean(hdr_points$y),
        mean_density = mean(hdr_points$fhat),
        n_hdr_points = nrow(hdr_points),
        n_points_in_category = nrow(category_data),
        group = "trajectory_evolution"
      )
    })

  # Combine results
  final_result <- center_results |>
    purrr::list_rbind()

  # Add metadata as attributes
  attr(final_result, "parameters") <- list(
    dim_cols = dim_cols,
    category_col = category_col,
    method = method,
    probs = probs,
    center_prob = center_prob,
    grid_resolution = grid_resolution,
    min_points = min_points,
    n_categories_processed = length(sufficient_data),
    n_categories_skipped = length(filtered_categories),
    total_input_points = nrow(.data),
    total_complete_points = nrow(complete_data)
  )

  return(final_result)
}
