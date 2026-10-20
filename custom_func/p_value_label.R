#' P values in the manuscript's house style
#'
#' Added 2026-10-08 so that figures and tables print P the way the text does
#' (the house style for P values):
#'
#' - three significant figures, trailing zeros kept (0.0500, 2.50 x 10^-5);
#' - a decimal at P >= 0.01, scientific notation below 0.01;
#' - 0, which here means below double precision, as the bound "< 1.0 x 10^-300".
#'
#' The value is rounded to three significant figures before the format is chosen, so 0.009996
#' prints as 0.0100, not 1.00 x 10^-2. Permutation P values are not formatted here: they are
#' printed at the resolution of the permutation count (three decimals for 1,000 permutations,
#' "< 0.001" when no permutation reached the observed value).
#'
#' @param p Numeric vector of P values.
#' @param style "plotmath" for `geom_text(parse = TRUE)`, "text" for plain strings with
#'   Unicode superscripts (gt, flextable, Excel), or "html" for gt cells and notes that take
#'   HTML.
#' @return `format_p_value()`: the number alone, with "< " for an underflow ("0.0147",
#'   "8.40 × 10⁻⁴", "< 1.0 × 10⁻³⁰⁰"); its plotmath style is for panels that print the number
#'   without "P =" to save space. `p_value_label()`: the whole label, with an italic P and the
#'   relation.
#'
#' @examples
#' format_p_value(c(0.0147, 8.4e-4, 0.05, 0.009996, 0))
#' p_value_label(c(3.12e-126, 0.113, 0))

p_value_parts <- function(p) {
  p3 <- signif(p, 3)
  sci <- formatC(p3, format = "e", digits = 2)
  # Parsed for every element; only the scientific branch uses it, so NA elsewhere is expected
  sci_exponent <- suppressWarnings(as.integer(sub("^.*e", "", sci)))
  tibble::tibble(
    missing = is.na(p),
    underflow = !is.na(p) & p == 0,
    decimal = !is.na(p) & p3 >= 0.01,
    number = dplyr::case_when(
      is.na(p) ~ NA_character_,
      p == 0 ~ "1.0",
      p3 >= 0.01 ~ formatC(p3, format = "fg", digits = 3, flag = "#"),
      .default = sub("e.*$", "", sci)
    ),
    exponent = dplyr::case_when(
      is.na(p) ~ NA_integer_,
      p == 0 ~ -300L,
      p3 >= 0.01 ~ NA_integer_,
      .default = sci_exponent
    )
  )
}

superscript_digits <- function(x) {
  chartr("-0123456789", "⁻⁰¹²³⁴⁵⁶⁷⁸⁹", x)
}

format_p_value <- function(p, style = c("text", "html", "plotmath")) {
  style <- match.arg(style)
  parts <- p_value_parts(p)
  if (style == "plotmath") {
    value <- dplyr::if_else(
      parts$decimal,
      paste0('"', parts$number, '"'),
      paste0('"', parts$number, ' \u00d7 "*10^', parts$exponent)
    )
    value <- dplyr::if_else(parts$underflow, paste0('"<"~', value), value)
    return(dplyr::if_else(parts$missing, NA_character_, value))
  }
  power <- if (style == "html") {
    paste0("10<sup>", sub("-", "−", parts$exponent), "</sup>")
  } else {
    paste0("10", superscript_digits(as.character(parts$exponent)))
  }
  dplyr::case_when(
    parts$missing ~ NA_character_,
    parts$decimal ~ parts$number,
    parts$underflow ~ paste0("< ", parts$number, " × ", power),
    .default = paste0(parts$number, " × ", power)
  )
}

p_value_label <- function(p, style = c("plotmath", "text", "html")) {
  style <- match.arg(style)
  parts <- p_value_parts(p)
  if (style == "plotmath") {
    # The number is quoted, or plotmath would print 0.0500 as 0.05 and 2.50 as 2.5. The
    # multiplication sign is a character inside the quotes, not plotmath's %*%, which the ragg
    # device draws as a centred dot (Figure 5, before 2026-10-08)
    relation <- dplyr::if_else(parts$underflow, "<", "==")
    value <- dplyr::if_else(
      parts$decimal,
      paste0('~"', parts$number, '"'),
      paste0('~"', parts$number, ' \u00d7 "*10^', parts$exponent)
    )
    return(dplyr::if_else(parts$missing, NA_character_, paste0("italic(P) ", relation, value)))
  }
  italic_p <- if (style == "html") "<i>P</i>" else "P"
  number <- format_p_value(p, style = style)
  dplyr::case_when(
    parts$missing ~ NA_character_,
    parts$underflow ~ paste(italic_p, number),
    .default = paste(italic_p, "=", number)
  )
}
