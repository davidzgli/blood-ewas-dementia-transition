# The house-style formatter that spearman_p_label() delegates to
source(here::here("custom_func/p_value_label.R"))

#' Spearman correlation P values that are never printed as 0
#'
#' Added 2026-10-07 for reviewer points R1.5/R2.7 (ADJ-D-26-02882). R's default
#' Spearman test (`stats::cor.test(method = "spearman")`) computes P with the AS 89
#' Edgeworth series for n <= 1,290, which returns exactly 0 when the tail probability
#' is very small; for larger n it uses the t approximation, which underflows to 0 only
#' below the double-precision limit. `spearman_p_value()` keeps the default result and
#' re-runs the test with the asymptotic t approximation (`exact = FALSE`) only when the
#' default returns 0. If that is still 0, the value is below what a double can hold and
#' stays 0, which `spearman_p_label()` prints as "P < 1.0 x 10^-300".
#'
#' This is deliberately a new helper rather than a change to the shared
#' `display_scientific_notation()`, which other figures and the slide deck use.
#'
#' @param x,y Numeric vectors, as for `cor.test()`.
#' @return `spearman_p_value()`: a single P value (0 only for true underflow).
#'
#' @examples
#' spearman_p_value(1:50, (1:50) + rnorm(50))
#' spearman_p_label(c(3.12e-126, 0, 0.113))
spearman_p_value <- function(x, y) {
  p <- suppressWarnings(stats::cor.test(x, y, method = "spearman")$p.value)
  if (!is.na(p) && p == 0) {
    p <- suppressWarnings(stats::cor.test(x, y, method = "spearman", exact = FALSE)$p.value)
  }
  p
}

#' @param p Numeric vector of P values (from `spearman_p_value()`).
#' @param style "plotmath" for `geom_text(parse = TRUE)` labels, "text" for plain strings.
#' @return `spearman_p_label()`: the whole label, including the italic P and the relation,
#'   in the house style of `p_value_label()` (custom_func/p_value_label.R, since 2026-10-08):
#'   three significant figures with trailing zeros kept, a decimal at P >= 0.01 and scientific
#'   notation below, and 'italic(P) < ~"1.0" %*% 10^-300' for a true underflow.
spearman_p_label <- function(p, style = c("plotmath", "text")) {
  style <- match.arg(style)
  p_value_label(p, style = style)
}
