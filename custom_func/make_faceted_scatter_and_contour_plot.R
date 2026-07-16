#' Create Faceted Scatter and Contour Plot for Trajectory Comparisons
#'
#' This function creates a faceted visualization comparing each dementia trajectory
#' against stable_normal, showing scatter points with density contours.
#'
#' @param .data A data frame with normal_repeated structure containing:
#'   - demcat_grand: trajectory category (faceting variable)
#'   - demcat_sub: simplified category ("stable_normal" or "demented")
#'   - Dimension columns specified by x_var and y_var
#' @param x_var Character string specifying the x-axis dimension column name
#' @param y_var Character string specifying the y-axis dimension column name
#' @param threshold Numeric threshold value for the plot title
#' @param adjust Numeric vector of length 2 for density contour bandwidth adjustment.
#'   Default is c(1.0, 1.0). Lower values create more detailed contours.
#'
#' @return A ggplot2 object with faceted scatter and contour plots
#'
#' @details
#' The function creates a faceted plot where:
#' - Each facet represents a dementia trajectory compared to stable_normal
#' - Points are colored by demcat_sub (stable_normal vs demented)
#' - Density contours show the distribution of each group
#' - Blue represents stable_normal, orange represents demented
#'
#' @examples
#' \dontrun{
#' # Create faceted plot for two autoencoder dimensions
#' make_faceted_scatter_and_contour_plot(
#'   normal_repeated,
#'   x_var = "ae_1",
#'   y_var = "ae_2",
#'   threshold = 7,
#'   adjust = c(1.0, 1.0)
#' )
#' }
#'
#' @import ggplot2
#' @import dplyr
#' @import glue
#' @export
make_faceted_scatter_and_contour_plot <- function(.data,
                                                   x_var,
                                                   y_var,
                                                   threshold,
                                                   adjust = c(1.0, 1.0)) {

  # Validate inputs
  if (!x_var %in% names(.data)) {
    stop("x_var '", x_var, "' not found in data")
  }
  if (!y_var %in% names(.data)) {
    stop("y_var '", y_var, "' not found in data")
  }

  required_cols <- c("demcat_grand", "demcat_sub")
  missing_cols <- setdiff(required_cols, names(.data))
  if (length(missing_cols) > 0) {
    stop("Missing required columns: ", paste(missing_cols, collapse = ", "))
  }

  # Create plot title
  plot_title <- glue::glue("Autoencoder Dimensions ({x_var} vs {y_var}): Each Trajectory vs Stable Normal (Threshold ≥ {threshold})")

  # Create the faceted plot
  p <- .data |>
    ggplot(aes(x = !!sym(x_var), y = !!sym(y_var), color = demcat_sub)) +
    geom_point(size = 0.3, alpha = 0.3) +
    geom_density_2d(linewidth = 0.8, n = 200, adjust = adjust, contour_var = "density") +
    scale_color_manual(
      values = c("stable_normal" = "#1f77b4", "demented" = "#ff7f0e"),
      labels = c("stable_normal" = "Stable Normal", "demented" = "Demented")
    ) +
    facet_wrap(vars(demcat_grand), nrow = 1) +
    labs(
      x = x_var,
      y = y_var,
      title = plot_title,
      color = "Dementia Status"
    ) +
    theme(
      legend.position = "top",
      strip.text = element_text(size = 12, face = "bold"),
      plot.title = element_text(face = "bold", size = 14)
    )

  return(p)
}