#' Format numbers in scientific notation
#'
#' @param x A numeric vector to be formatted in scientific notation
#'
#' @return A character vector with formatted scientific notation
#' @export
#'
#' @examples
#' display_scientific_notation(1e-8)
#' display_scientific_notation(0.3864971)
#' display_scientific_notation(c(1e-8, 0.3864971, 0))

display_scientific_notation <- function(x) {
  # Vectorized approach using ifelse
  ifelse(
    x == 0,
    "0",
    format(x, scientific = TRUE, digits = 3) |>
      stringr::str_replace_all(c("e" = " %*% 10^", "\\$" = ""))
  )
}



