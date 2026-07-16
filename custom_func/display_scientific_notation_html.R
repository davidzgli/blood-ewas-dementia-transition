#' Format numbers in scientific notation for HTML display
#'
#' @param x A numeric vector to be formatted in scientific notation with HTML formatting
#' @param digits Number of significant digits to display (default: 3)
#'
#' @return A character vector with HTML-formatted scientific notation
#' @export
#'
#' @examples
#' display_scientific_notation_html(1e-8)
#' display_scientific_notation_html(0.3864971)
#' display_scientific_notation_html(c(1e-8, 0.3864971, 0))
#' display_scientific_notation_html(1e-8, digits = 4)

display_scientific_notation_html <- function(x, digits = 3) {
  # Vectorized approach using ifelse
  ifelse(
    x == 0,
    "0",
    # Format the number in scientific notation
    format(x, scientific = TRUE, digits = digits) |>
      # Replace "e" with HTML superscript formatting
      stringr::str_replace("e", " × 10<sup>") |>
      # Add closing HTML tag
      stringr::str_replace("$", "</sup>")
  )
} 