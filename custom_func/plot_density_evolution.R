#' Plot Density Evolution with Trajectory Arrows
#' 
#' This function creates a visualization showing the evolution of high-density regions
#' across dementia trajectories. It plots trajectory centroids with directional arrows
#' and highlights stable_normal as a reference point (star).
#'
#' @param .data A data frame containing trajectory data with density information
#' @param dim_cols Character vector of length 2 specifying the column names for x and y dimensions
#' @param statistic Character string specifying which statistic to use for trajectory centroids.
#'   Must be either "mean" (default) or "median"
#' @param threshold Numeric value representing the density threshold (used in plot titles)
#' @param trajectory_colors Named character vector of colors for each trajectory category.
#'   If NULL, uses default color palette
#' @param reference_category Character string specifying which category to display as reference (star).
#'   Default is "stable_normal"
#' @param arrow_size Numeric value for arrow line width. Default is 1.5
#' @param point_size Numeric value for trajectory point size. Default is 4
#' @param star_size Numeric value for reference star size. Default is 6
#' @param text_size Numeric value for label text size. Default is 4
#'
#' @return A ggplot object showing trajectory evolution with arrows
#'
#' @details
#' The function expects input data with columns:
#' - demcat: factor with trajectory categories
#' - x_mean/x_median and y_mean/y_median: centroids for each trajectory
#' - group: grouping variable (typically "trajectory_evolution")
#'
#' The stable_normal category (or specified reference_category) is displayed as a star
#' and excluded from the arrow path. Other trajectories are connected with arrows
#' showing progression through dementia states.
#'
#' @examples
#' \dontrun{
#' # Example with mean centroids
#' density_data |>
#'   plot_density_evolution(
#'     dim_cols = c("PCA1", "PCA2"),
#'     statistic = "mean",
#'     threshold = 7
#'   )
#'
#' # Example with median centroids and custom colors
#' density_data |>
#'   plot_density_evolution(
#'     dim_cols = c("AE_Dim1", "AE_Dim2"),
#'     statistic = "median",
#'     threshold = 5,
#'     trajectory_colors = c("stable_normal" = "blue", "normal2mci" = "red")
#'   )
#' }
#'
#' @import ggplot2
#' @import dplyr
#' @import glue
#' @importFrom ggrepel geom_text_repel
#' @export
plot_density_evolution <- function(.data, 
                                   dim_cols = c("PCA1", "PCA2"), 
                                   statistic = "mean",
                                   threshold = NULL,
                                   trajectory_colors = NULL,
                                   reference_category = "stable_normal",
                                   arrow_size = 1.5,
                                   point_size = 4,
                                   star_size = 6,
                                   text_size = 4) {
  
  # Validate inputs
  if (!statistic %in% c("mean", "median")) {
    stop("statistic must be either 'mean' or 'median'")
  }
  
  if (length(dim_cols) != 2) {
    stop("dim_cols must be a character vector of length 2")
  }
  
  # Construct column names based on statistic
  x_col <- paste0("x_", statistic)
  y_col <- paste0("y_", statistic)
  
  # Check if required columns exist
  required_cols <- c("demcat", x_col, y_col)
  missing_cols <- setdiff(required_cols, names(.data))
  if (length(missing_cols) > 0) {
    stop("Missing required columns: ", paste(missing_cols, collapse = ", "))
  }
  
  # Default trajectory colors
  if (is.null(trajectory_colors)) {
    trajectory_colors <- c(
      "stable_normal" = "#1f77b4",      # blue
      "normal2mci" = "#ff7f0e",         # orange  
      "stable_mci" = "#2ca02c",         # green
      "normal2incid" = "#d62728",       # red
      "mci2incid" = "#9467bd",          # purple
      "prev_dementia" = "#8c564b"       # brown
    )
  }
  
  # Filter and prepare trajectory data (excluding reference category from path)
  trajectory_data <- .data |> 
    filter(demcat != reference_category) |>
    mutate(demcat = forcats::fct_relevel(demcat, "normal2mci", "stable_mci", "normal2incid", "mci2incid", "prev_dementia")) |> 
    arrange(demcat)
  
  # Get reference category data separately for special display
  reference_data <- .data |> 
    filter(demcat == reference_category)
  
  # Create base plot
  p <- .data |> 
    ggplot(aes(x = !!sym(x_col), y = !!sym(y_col), color = demcat)) +
    # Plot trajectory points and path (excluding reference category)
    geom_point(data = trajectory_data, size = point_size) +
    ggrepel::geom_text_repel(data = trajectory_data, 
                aes(label = demcat), 
                size = text_size, 
                box.padding = 0.5) +
    geom_path(data = trajectory_data, 
              aes(group = group), 
              arrow = arrow(angle = 15, ends = "last", type = "closed"), 
              linewidth = arrow_size) +
    # Plot reference category as a star
    geom_point(data = reference_data, 
               aes(x = !!sym(x_col), y = !!sym(y_col)), 
               shape = 8, 
               size = star_size, 
               stroke = 2) +
    ggrepel::geom_text_repel(data = reference_data, 
                aes(x = !!sym(x_col), y = !!sym(y_col), label = demcat), 
                size = text_size, 
                box.padding = 0.5, 
                fontface = "bold") +
    scale_color_manual(values = trajectory_colors) +
    theme(
      legend.position = "bottom",
      plot.title = element_text(face = "bold"),
      legend.title = element_text(face = "bold")
    )
  
  # Create titles based on available information
  if (is.null(threshold)) {
    title_text <- "Trajectory Evolution of High-Density Regions"
  } else {
    title_text <- glue::glue("Trajectory Evolution of High-Density Regions (Threshold ≥ {threshold})")
  }
  
  subtitle_text <- glue::glue("Arrows show progression through dementia states ({statistic} centroids); star indicates {reference_category} reference")
  
  # Add labels
  p <- p + labs(
    x = dim_cols[1], 
    y = dim_cols[2],
    title = title_text,
    subtitle = subtitle_text,
    color = "Dementia Trajectory"
  )
  
  return(p)
}
