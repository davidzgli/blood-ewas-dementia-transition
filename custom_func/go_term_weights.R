#' GO term recount: duplicate parents (Rule 1) and specificity weights (Rule 2)
#'
#' Added 2026-10-09 for the reviewer round (ADJ-D-26-02882, R2.9). Both objects are written by
#' `pathway_analysis/06_go_hierarchy/03_go_term_weights.qmd`, which runs right after the GO
#' enrichment (Step 3b of `pathway_analysis/render.sh`); every later step reads them through
#' these helpers.
#'
#' - Rule 1: a significant parent term whose genes in the background set are identical to those of
#'   a significant child term is dropped, and the child is kept. Such a pair has the same test in
#'   every group, so the rule never changes which group a term is significant in.
#' - Rule 2 (redundancy-aware since 2026-10-13): a term significant in only one group gets the
#'   weight w = 1 - (immediate GO relatives significant in any group, its own or another / all
#'   immediate GO relatives). Counts of such terms per group and per functional category are sums
#'   of w, rounded half up.
#'
#' @param x Numeric vector to round.
#' @param top_n 1000 or 2000, the number of top-ranked CpG sites per group.
#' @return `round_half_up()`: integers, with halves rounded up (R's `round()` rounds half to even).
#'   `read_go_duplicate_parents()`: one row per dropped parent (`parent`, `child`, `relation`,
#'   descriptions). `read_go_term_weights()`: one row per term significant in only one group
#'   (`condition`, `ID`, `Description`, `n_relatives`, `n_relatives_same`, `n_relatives_other`,
#'   `n_relatives_significant`, `relatives_significant`, `relatives_same`, `relatives_other`, `w`).
#'
#' @examples
#' round_half_up(c(0.5, 1.5, 2.5, 8.6))
#' read_go_term_weights(1000)

round_half_up <- function(x) {
  floor(x + 0.5)
}

read_go_duplicate_parents <- function(top_n) {
  readr::read_rds(here::here(glue::glue(
    "pathway_analysis/06_go_hierarchy/output/top{top_n}_go_duplicate_parents.rds"
  )))
}

read_go_term_weights <- function(top_n) {
  readr::read_rds(here::here(glue::glue(
    "pathway_analysis/06_go_hierarchy/output/top{top_n}_go_term_weights.rds"
  )))
}
