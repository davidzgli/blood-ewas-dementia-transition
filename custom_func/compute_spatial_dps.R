# Spatial DPS (Dementia Progression Score) Functions
#
# Five 2D spatial metrics that capture centroid separation quality,
# complementing the existing ordering-based DPS metrics.
# Signed metrics (path2d, separation, overlap, directed_step) return [-1, 1].
# Unsigned metric (spread) returns [0, 1].

#' Spread DPS: convex hull area of centroids / bounding area
#'
#' Measures whether centroids occupy the 2D embedding space.
#' High score = centroids spread out; low score = centroids clustered together.
#'
#' @param x_coords Numeric vector of x centroid positions (ordered by progression)
#' @param y_coords Numeric vector of y centroid positions (ordered by progression)
#' @param bounding_area Numeric scalar: total area of the embedding space (from plot limits)
#' @return Numeric [0, 1]
compute_spread_dps <- function(x_coords, y_coords, bounding_area) {
  n <- length(x_coords)
  if (n < 3 || bounding_area <= 0) return(0)

  # Convex hull area of centroids
  hull_idx <- grDevices::chull(x_coords, y_coords)
  hull_x <- x_coords[hull_idx]
  hull_y <- y_coords[hull_idx]

  # Shoelace formula for polygon area
  n_hull <- length(hull_idx)
  hull_area <- abs(sum(hull_x * c(hull_y[-1], hull_y[1]) -
                       c(hull_x[-1], hull_x[1]) * hull_y)) / 2

  min(hull_area / bounding_area, 1)
}

#' Path2D DPS: signed path efficiency
#'
#' Measures whether the 2D centroid path is efficient (no zigzag) and aligned
#' with the expected progression direction. The unsigned efficiency
#' (direct_dist / total_path) is multiplied by the mean directional cosine
#' of each step relative to the progression direction.
#'
#' @param x_coords Numeric vector of x centroid positions (ordered by progression)
#' @param y_coords Numeric vector of y centroid positions (ordered by progression)
#' @return Numeric [-1, 1]
compute_path2d_dps <- function(x_coords, y_coords) {
  n <- length(x_coords)
  if (n < 2) return(NA_real_)

  step_dx <- diff(x_coords)
  step_dy <- diff(y_coords)
  step_dists <- sqrt(step_dx^2 + step_dy^2)
  total_path <- sum(step_dists)
  direct_dist <- sqrt((x_coords[n] - x_coords[1])^2 +
                       (y_coords[n] - y_coords[1])^2)

  if (total_path == 0 || direct_dist == 0) return(0)

  # Progression direction (first -> last centroid)
  prog_unit <- c(x_coords[n] - x_coords[1],
                 y_coords[n] - y_coords[1]) / direct_dist

  # Directional cosine for each step
  projections <- step_dx * prog_unit[1] + step_dy * prog_unit[2]
  cos_angles <- ifelse(step_dists == 0, 0, projections / step_dists)

  # Signed path efficiency
  (direct_dist / total_path) * mean(cos_angles)
}

#' Separation DPS: signed evenness and magnitude of inter-centroid spacing
#'
#' Measures whether consecutive centroids are well-separated and evenly spaced,
#' signed by the mean directional cosine of steps relative to the progression
#' direction. Positive when steps mostly align with progression; negative when
#' mostly reversed.
#'
#' @param x_coords Numeric vector of x centroid positions (ordered by progression)
#' @param y_coords Numeric vector of y centroid positions (ordered by progression)
#' @param max_possible_dist Numeric scalar: diagonal of the bounding box
#' @return Numeric [-1, 1]
compute_separation_dps <- function(x_coords, y_coords, max_possible_dist) {
  n <- length(x_coords)
  if (n < 2 || max_possible_dist <= 0) return(0)

  step_dx <- diff(x_coords)
  step_dy <- diff(y_coords)
  step_dists <- sqrt(step_dx^2 + step_dy^2)
  mean_spacing <- mean(step_dists)
  sd_spacing <- sd(step_dists)

  # Magnitude: average spacing relative to max possible distance
  magnitude <- min(mean_spacing / (max_possible_dist / (n - 1)), 1)

  # Evenness: 1 - coefficient of variation (capped at 0)
  if (is.na(sd_spacing) || mean_spacing == 0) {
    evenness <- 0
  } else {
    cv <- sd_spacing / mean_spacing
    evenness <- max(1 - cv, 0)
  }

  unsigned_score <- (magnitude + evenness) / 2

  # Direction factor via mean directional cosine
  direct_dist <- sqrt((x_coords[n] - x_coords[1])^2 +
                       (y_coords[n] - y_coords[1])^2)
  if (direct_dist == 0) return(0)

  prog_unit <- c(x_coords[n] - x_coords[1],
                 y_coords[n] - y_coords[1]) / direct_dist
  projections <- step_dx * prog_unit[1] + step_dy * prog_unit[2]
  cos_angles <- ifelse(step_dists == 0, 0, projections / step_dists)

  unsigned_score * mean(cos_angles)
}

#' Overlap DPS: signed inter-centroid distance vs spread radii
#'
#' Measures whether density regions are non-overlapping, signed per-step by
#' the directional cosine of each step relative to the progression direction.
#' Well-separated forward steps contribute positively; well-separated backward
#' steps contribute negatively.
#'
#' @param x_coords Numeric vector of x centroid positions (ordered by progression)
#' @param y_coords Numeric vector of y centroid positions (ordered by progression)
#' @param spread_radii Numeric vector of spread radii (sqrt(x_sd^2 + y_sd^2))
#' @return Numeric [-1, 1]
compute_overlap_dps <- function(x_coords, y_coords, spread_radii) {
  n <- length(x_coords)
  if (n < 2) return(NA_real_)

  step_dx <- diff(x_coords)
  step_dy <- diff(y_coords)
  step_dists <- sqrt(step_dx^2 + step_dy^2)

  # Sum of spread radii for consecutive pairs
  sum_radii <- spread_radii[-n] + spread_radii[-1]

  # For each pair: ratio of distance to combined spread (capped at 1)
  # If sum_radii is 0 (e.g. single-point categories), treat as perfectly separated
  unsigned_scores <- ifelse(
    sum_radii == 0,
    1,
    pmin(step_dists / sum_radii, 1)
  )

  # Direction factor per step
  direct_dist <- sqrt((x_coords[n] - x_coords[1])^2 +
                       (y_coords[n] - y_coords[1])^2)
  if (direct_dist == 0) return(0)

  prog_unit <- c(x_coords[n] - x_coords[1],
                 y_coords[n] - y_coords[1]) / direct_dist
  projections <- step_dx * prog_unit[1] + step_dy * prog_unit[2]
  cos_angles <- ifelse(step_dists == 0, 0, projections / step_dists)

  # Per-step signed score
  mean(cos_angles * unsigned_scores, na.rm = TRUE)
}

#' Directed Step DPS: signed alignment of steps with progression direction
#'
#' Measures whether consecutive centroid steps align with the overall
#' progression direction (first centroid -> last centroid). Steps that go
#' "forward" along the progression axis are positive; steps that go
#' "backward" are negative. Returns a value in [-1, 1].
#'
#' @param x_coords Numeric vector of x centroid positions (ordered by progression)
#' @param y_coords Numeric vector of y centroid positions (ordered by progression)
#' @param max_possible_dist Numeric scalar: diagonal of the bounding box
#' @return Numeric [-1, 1]
compute_directed_step_dps <- function(x_coords, y_coords, max_possible_dist) {
  n <- length(x_coords)
  if (n < 2 || max_possible_dist <= 0) return(0)

  # Overall progression direction: first centroid -> last centroid
  prog_vec <- c(x_coords[n] - x_coords[1], y_coords[n] - y_coords[1])
  prog_len <- sqrt(sum(prog_vec^2))

  if (prog_len == 0) return(0)

  # Unit vector along progression direction
  prog_unit <- prog_vec / prog_len

  # Reference distance per step (same as separation DPS)
  ref_dist <- max_possible_dist / (n - 1)

  # For each consecutive step, compute signed normalized distance
  step_dx <- diff(x_coords)
  step_dy <- diff(y_coords)
  step_mag <- sqrt(step_dx^2 + step_dy^2)

  # Projection of each step onto progression direction (dot product)
  projection <- step_dx * prog_unit[1] + step_dy * prog_unit[2]

  # Signed step = magnitude * sign(projection)
  signed_steps <- step_mag * sign(projection)

  # Normalize by reference distance and take mean
  normalized <- signed_steps / ref_dist

  # Clamp to [-1, 1]
  max(min(mean(normalized), 1), -1)
}

#' Compute all spatial DPS metrics
#'
#' Wrapper that calls all spatial DPS functions on a set of ordered centroids.
#'
#' @param centroid_data Data frame with columns: x_mean, y_mean, spread_radius,
#'   ordered by progression
#' @param bounding_area Numeric: area of the embedding space
#' @param max_possible_dist Numeric: diagonal of the bounding box
#' @return A single-row tibble with spread_dps, path2d_dps, separation_dps,
#'   overlap_dps, directed_step_dps
compute_all_spatial_dps <- function(centroid_data, bounding_area, max_possible_dist) {
  x <- centroid_data$x_mean
  y <- centroid_data$y_mean
  sr <- centroid_data$spread_radius

  tibble::tibble(
    spread_dps = compute_spread_dps(x, y, bounding_area),
    path2d_dps = compute_path2d_dps(x, y),
    separation_dps = compute_separation_dps(x, y, max_possible_dist),
    overlap_dps = compute_overlap_dps(x, y, sr),
    directed_step_dps = compute_directed_step_dps(x, y, max_possible_dist)
  )
}
