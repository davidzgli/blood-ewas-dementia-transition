#' Correlation coefficients in the manuscript's house style
#'
#' Added 2026-10-08, with custom_func/p_value_label.R (the same house style):
#' two decimals with trailing zeros kept (0.40, not 0.4; 0.00, not 0) and a true minus sign
#' (U+2212), as the text writes them. A value that rounds to zero prints as 0.00, never -0.00.
#'
#' The number is quoted in plotmath, or plotmath would print 0.40 as 0.4.
#'
#' @param r Numeric vector of correlation coefficients.
#' @param style "plotmath" for `geom_text(parse = TRUE)`, "text" for plain strings.
#' @return `format_r_value()`: the number alone ("0.40", "−0.48"). `r_value_label()`: the
#'   whole label with an italic r.
#'
#' @examples
#' format_r_value(c(0.4, -0.476, -0.004, NA))
#' r_value_label(c(0.4, -0.476))

format_r_value <- function(r) {
  x <- formatC(round(r, 2), format = "f", digits = 2)
  x <- sub("^-", "−", x)
  x[x == "−0.00"] <- "0.00"
  x[is.na(r)] <- NA_character_
  x
}

r_value_label <- function(r, style = c("plotmath", "text")) {
  style <- match.arg(style)
  number <- format_r_value(r)
  label <- if (style == "plotmath") paste0('italic(r) ==~"', number, '"') else paste("r =", number)
  label[is.na(r)] <- NA_character_
  label
}
